#!/usr/bin/env python3
"""Envelope parser for the put-side regulation-cache hook.

Reads a Claude Code hook event JSON from stdin, finds the digest-bearing string
(``tool_response`` on PostToolUse-on-Agent, ``last_assistant_message`` on
SubagentStop), extracts every ``<thalura-digest version="…">`` region, parses the
inner fenced ```json``` block, and — per resolved section — prints one TSV line:

    <section_key>\t<identity_tmpfile>\t<digest_tmpfile>

``section_key`` is computed via the sibling ``scripts/cache.py`` (single source of
the canonicalization, so the put-side dedup key matches what ``cache.py put``
writes). The identity/digest are written to temp files (caller cleans the temp
dir) so the bash hook hands ``cache.py`` real ``--identity``/``--digest`` paths
without re-serializing JSON in the shell.

Robust two-level parse (Constraint 1): the opening fence (```json) anchors the
JSON, but the block END is found by JSON STRUCTURE, not by the next ``` — so a
verbatim regulation quote containing a backtick, a literal ``` triple backtick,
or a literal ``</thalura-digest>`` inside ``cited_text`` cannot terminate the
block early. After the opening fence we locate the first ``{`` and consume
exactly one JSON value via ``json.JSONDecoder().raw_decode``; the trailing ```
(and anything after the JSON value) is then irrelevant to the parse.

Serialized-shape tolerance: ``tool_response`` may arrive as a structured (non-string)
object; we stringify it via ``json.dumps``, which represents embedded newlines as the
escaped two-char sequence ``\\n`` rather than a real newline. The block scan therefore
treats a real ``\n`` *or* an escaped ``\\n`` as the info-string terminator, and — when
the literal JSON value cannot be ``raw_decode``-d directly — falls back to
JSON-string-unescaping the post-fence remainder before decoding, so the envelope still
resolves in the serialized shape (escaped ``\\"`` / ``\\n``). Both the string path
(``tool_response`` / ``last_assistant_message``) and the serialized path go through the
same structure-delimited, collision-safe parse.

Malformed / no envelope -> prints nothing, exit 0 (the hook then no-ops).
Every failure is swallowed: this is fail-open enforcement infra, never a teacher
deliverable, and must never break the in-band answer.
"""
import json
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(os.path.dirname(HERE), "scripts")
if SCRIPTS not in sys.path:
    sys.path.insert(0, SCRIPTS)

try:
    import cache  # sibling scripts/cache.py — single source of section_key
except Exception:  # noqa: BLE001 — fail-open: no parser, no put
    cache = None

OPEN_TAG = "<thalura-digest"
FENCE = "```"


def _harvest_text(val):
    """Recover the LITERAL digest text from a structured tool_response without
    re-serializing. ``tool_response`` commonly arrives as ``{"content": [{"type":
    "text", "text": "<the real string>"}]}`` (or a bare list of such blocks); pulling
    the inner ``text`` out directly yields the SAME single-level string the string
    path sees — so the fence/JSON parse never has to cope with a doubly-escaped body.
    Concatenates every text leaf in document order. Returns ``""`` when no plain text
    leaf is reachable (caller then falls back to a defensive ``json.dumps``)."""
    if isinstance(val, str):
        return val
    if isinstance(val, list):
        return "\n".join(p for p in (_harvest_text(v) for v in val) if p)
    if isinstance(val, dict):
        # Prefer the canonical block shape ``{"type": "text", "text": "…"}``.
        t = val.get("text")
        if isinstance(t, str):
            return t
        inner = val.get("content")
        if inner is not None:
            return _harvest_text(inner)
    return ""


def _digest_text(event):
    """Return the digest-bearing string from whichever event shape arrived."""
    for key in ("tool_response", "last_assistant_message"):
        val = event.get(key)
        if isinstance(val, str) and OPEN_TAG in val:
            return val
        # tool_response can arrive structured. First try to recover the LITERAL text
        # (no re-escaping); only if that misses fall back to a defensive json.dumps
        # (the _decode_one serialized path then handles the escaped shape).
        if val is not None and not isinstance(val, str):
            harvested = _harvest_text(val)
            if OPEN_TAG in harvested:
                return harvested
            try:
                s = json.dumps(val, ensure_ascii=False)
            except Exception:  # noqa: BLE001
                s = ""
            if OPEN_TAG in s:
                return s
    return ""


def _find_newline(text, start):
    """Locate the info-string-terminating newline at/after ``start``, tolerating
    both a real ``\\n`` (string path) and the escaped two-char sequence ``\\n``
    produced when a structured tool_response is json.dumps-serialized. Returns
    ``(pos, width)`` of the earliest match (width 1 for a real newline, 2 for the
    escaped sequence), or ``(-1, 0)`` when neither is present."""
    real = text.find("\n", start)
    esc = text.find("\\n", start)  # backslash followed by 'n' — the serialized form
    if real == -1 and esc == -1:
        return -1, 0
    if esc == -1 or (real != -1 and real <= esc):
        return real, 1
    return esc, 2


_DECODER = json.JSONDecoder()


def _match_escaped_object(text, brace):
    """Return the index just past the closing ``}`` of the JSON object that begins at
    ``text[brace] == '{'`` in the json.dumps-SERIALIZED shape, where the object's own
    string delimiters appear as ``\\"`` and its in-string escapes as ``\\\\``.

    Brace-depth scan that tracks string state so a ``{`` / ``}`` / ``` ``` ```
    *inside* a ``cited_text`` string is not mistaken for structure. Returns ``-1`` if
    the object never closes (truncated)."""
    # In the serialized shape every quote of the inner object is written ``\"`` (a
    # backslash + a quote). A backslash that is part of the inner content is itself
    # doubled to ``\\`` first, so the disambiguation inside a string is:
    #   ``\"``  (backslash, then ``"``)            -> the string's CLOSE delimiter
    #   ``\\``  (backslash, then backslash)        -> an escaped char in content;
    #                                                 consume both + keep scanning
    n = len(text)
    i = brace
    depth = 0
    in_str = False
    while i < n:
        c = text[i]
        if in_str:
            if c == "\\" and i + 1 < n:
                nxt = text[i + 1]
                if nxt == '"':
                    in_str = False   # ``\"`` closes the serialized string
                    i += 2
                    continue
                # ``\\…`` — an escaped backslash in content; the next char is content.
                i += 2
                continue
            i += 1
            continue
        if c == "\\" and i + 1 < n and text[i + 1] == '"':
            in_str = True   # opening ``\"`` of a serialized JSON string
            i += 2
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return -1


def _decode_one(text, idx):
    """Decode exactly one JSON value starting at/after ``idx``, returning
    ``(obj, end)`` where ``end`` is the index just past the consumed value in
    ``text``.

    Tries the literal text first (the string path, where the JSON is verbatim) via
    ``raw_decode`` — which walks JSON string-escaping itself, so a literal ``` triple
    backtick, a single backtick, or a ``</thalura-digest>`` inside a ``cited_text``
    string is consumed as ordinary string content and CANNOT terminate the value
    early. On failure it falls back to the json.dumps-SERIALIZED shape (body escaped
    as ``\\"`` / ``\\n``): a brace-depth scan that respects the escaped string
    delimiters finds the object's end, and that bounded slice is JSON-string-
    unescaped and decoded — keeping the same collision-safety on the serialized path.
    Returns ``(None, -1)`` when no JSON value can be decoded at ``idx``."""
    # Skip ahead to the opening brace of the object (tolerate stray whitespace).
    brace = text.find("{", idx)
    if brace == -1:
        return None, -1
    try:
        return _DECODER.raw_decode(text, brace)
    except ValueError:
        pass
    # Serialized shape: bound the object by an escaped-string-aware brace scan, then
    # unescape exactly that slice (not the rest of the outer blob) before decoding.
    end = _match_escaped_object(text, brace)
    if end == -1:
        return None, -1
    try:
        unescaped = json.loads('"' + text[brace:end] + '"')
        obj, _ = _DECODER.raw_decode(unescaped, 0)
    except ValueError:
        return None, -1
    return obj, end


def _fenced_blocks(text):
    """Yield the parsed JSON object of each ```json fenced block that follows an
    opening <thalura-digest tag. The block END is found by JSON STRUCTURE (one
    ``raw_decode``-consumed value), NOT by the next ``` — so a backtick, a literal
    ``` triple backtick, or a literal </thalura-digest> inside a JSON string cannot
    break the block early. Tolerant of the json.dumps-serialized shape, where the
    body is escaped (``\\"`` / ``\\n``) — see ``_decode_one`` (module docstring)."""
    pos = 0
    while True:
        tag = text.find(OPEN_TAG, pos)
        if tag == -1:
            return
        # Find the opening json fence after this tag.
        fopen = text.find(FENCE, tag)
        if fopen == -1:
            return
        # Skip the fence marker and an optional "json" info string + newline,
        # accepting a real or an escaped (serialized) newline as the terminator.
        body_start = fopen + len(FENCE)
        nl, width = _find_newline(text, body_start)
        if nl == -1:
            return
        obj, end = _decode_one(text, nl + width)
        if obj is None:
            # Unparseable here — advance past this tag and keep scanning so a
            # single bad section never strands the rest (fail-open).
            pos = tag + len(OPEN_TAG)
            continue
        yield obj
        pos = end


def main():
    raw = sys.stdin.read()
    if cache is None:
        return 0
    try:
        event = json.loads(raw)
    except Exception:  # noqa: BLE001
        return 0
    if not isinstance(event, dict):
        return 0

    text = _digest_text(event)
    if not text:
        return 0

    # Temp dir is created lazily — only once a section is actually about to be
    # written — so the no-envelope / malformed / unparseable paths create (and thus
    # leave) no temp dir at all. The dir outlives this process (the consuming hook
    # reads the files after we exit), so the hook is responsible for removing it;
    # we keep it under a single per-firing parent so the hook can clean it by dirname.
    tmpdir = None
    n = 0
    for obj in _fenced_blocks(text):
        try:
            identity = obj["identity"]
            digest = obj["digest"]
            if not isinstance(identity, dict) or not isinstance(digest, dict):
                continue
            key = cache.section_key(identity)
        except Exception:  # noqa: BLE001 — skip a malformed section, keep the rest
            continue
        if tmpdir is None:
            tmpdir = tempfile.mkdtemp(prefix="thalura-env-")
        id_path = os.path.join(tmpdir, "id_%d.json" % n)
        dg_path = os.path.join(tmpdir, "dg_%d.json" % n)
        try:
            with open(id_path, "w", encoding="utf-8") as fh:
                json.dump(identity, fh, ensure_ascii=False)
            with open(dg_path, "w", encoding="utf-8") as fh:
                json.dump(digest, fh, ensure_ascii=False)
        except Exception:  # noqa: BLE001
            continue
        sys.stdout.write("%s\t%s\t%s\n" % (key, id_path, dg_path))
        n += 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
