#!/usr/bin/env python3
"""Deterministic digest-cache helper for the regulation firewall.

Owns the digest cache KEY, SCHEMA, GRANULARITY, and LOOKUP as code, so a
same-section follow-up HITs the persisted digest instead of re-reading the PDF.

Layout (hybrid, OQ-1c): data/.cache/<document_id>/<section-key>.json
  - one file per resolved section, grouped under a per-document directory.

Subcommands:
  get  --identity <id.json>                 -> exit 0 + entry on stdout if HIT
                                               exit 1 (empty stdout) on MISS
  put  --identity <id.json> --digest <d>    -> exit 0 on write
                                               exit 3 on reject (nothing written), for a
                                               digest that is not canonical OR a coordinate
                                               this helper cannot resolve (:validate_identity)
  derive-identity --identity <id.json>      -> exit 0 + the section key on stdout
                                               exit 1 (empty stdout) when the coordinate
                                               does not resolve — the get hook reads any
                                               non-zero as "not firewall-shaped" and fails
                                               open, which is the correct answer here
All: exit 2 on usage/IO error (stderr diagnostic).

THE COORDINATE IS RESOLVED, NEVER GUESSED. Both canonicalizers map a freely-spelled
value onto the vocabulary the caller supplied, by exact or fold-normalized equality,
and return :UNRESOLVED when neither matches. They never fall back to a containment
match and never accept an unrecognised spelling — see :_resolve for what those two
removed branches cost.

Path: <WORKSPACE_ROOT>/data/.cache, where <WORKSPACE_ROOT> comes from
scripts/resolve-data-root.sh (never a guessed path). THALURA_CACHE_DIR overrides
the resolved cache dir for tests.
"""
import argparse
import hashlib
import io
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))

EXIT_HIT = 0
EXIT_MISS = 1
EXIT_USAGE = 2
EXIT_REJECT = 3


def _pin_utf8(stream):
    """Return ``stream`` pinned to UTF-8, whatever the process locale says.

    THE TWO BUGS THIS CLOSES. Under a non-UTF-8 locale (``LC_ALL=C``) CPython
    gives ``sys.stdout`` and ``sys.stderr`` the **ascii** codec. Every byte this
    helper moves is German regulation text, so:

      - :cmd_get's HIT write raised ``UnicodeEncodeError`` on the first umlaut.
        That is a ``ValueError``, and :main's handler catches only
        ``(OSError, json.JSONDecodeError)`` — so it escaped as a traceback, the
        interpreter exited **1**, and 1 is ``EXIT_MISS``. A genuine HIT was
        served to every caller as a MISS. On such a host the digest cache is
        permanently inert for the only content it holds, and the sole symptom is
        that every section re-reads its PDF forever.
      - :cmd_put's two reject lines survived (stderr defaults to
        ``backslashreplace``) but their em dashes degraded to the literal six
        characters ``\\u2014``. That misinforms the human reading the diagnostic
        AND defeats the put hook's first-line reason extractor, whose pattern
        carries a literal em dash — so the rejection reason never reaches the
        audit log and a refused put looks like a bare exit code.

    Pinning HERE rather than exporting ``PYTHONIOENCODING`` at each call site is
    the deliberate choice: the caller-side form already shipped for two of this
    file's callers and left every other one unprotected, and a fix that must be
    repeated at each new call site decays by construction.

    The error handler is never strict — a raise on the way out is precisely the
    failure this function removes, and it must not be traded for a different one.
    Which non-strict handler differs per stream, deliberately:

      - **stdout gets ``replace``.** What it carries is a JSON entry whose every
        value was decoded from a strict-UTF-8 file by :load_json, so no lone
        surrogate can reach it and the handler never fires.
      - **stderr gets ``backslashreplace``**, matching CPython's own default for
        that stream. :main writes ``"cache.py: %s" % exc`` for an ``OSError``,
        whose ``filename`` comes from argv — and on Linux under ``LC_ALL=C``
        argv is decoded ascii + ``surrogateescape``, so a non-ASCII path arrives
        as lone surrogates. ``replace`` would render those ``?`` and destroy the
        one thing the diagnostic exists to carry: which path failed.
        ``backslashreplace`` keeps them legible and recoverable. Under UTF-8 the
        two handlers are indistinguishable, because nothing is unencodable.

    Inert when the stream is already UTF-8 — under a UTF-8 locale, and when a
    caller has already exported ``PYTHONIOENCODING=utf-8`` (two of them do).
    Degrades to a no-op rather than raising when the stream is not a
    reconfigurable text stream, e.g. a harness replaced it with an
    ``io.StringIO``. CPython >= 3.7 for ``reconfigure``; the floor here is 3.9.
    """
    try:
        stream.reconfigure(encoding="utf-8", errors="replace")
        return stream
    except (AttributeError, ValueError, OSError):
        pass
    buf = getattr(stream, "buffer", None)
    if buf is None:
        return stream
    try:
        # The replaced wrapper stays reachable via sys.__stdout__/__stderr__, so
        # it is not finalized out from under the buffer we just took over.
        return io.TextIOWrapper(buf, encoding="utf-8", errors="replace",
                                line_buffering=getattr(stream, "line_buffering", False))
    except (AttributeError, ValueError, OSError):
        return stream


def cache_dir():
    """Return the canonical <WORKSPACE_ROOT>/data/.cache directory.

    THALURA_CACHE_DIR overrides for tests; otherwise resolve-data-root.sh.
    """
    override = os.environ.get("THALURA_CACHE_DIR")
    if override:
        return override
    resolver = os.path.join(HERE, "resolve-data-root.sh")
    proc = subprocess.run(["bash", resolver], capture_output=True, text=True)
    root = proc.stdout.strip()
    if proc.returncode != 0 or not root or root.startswith("THALURA_"):
        raise RuntimeError("workspace root unresolved: %r (rc=%d)" % (root, proc.returncode))
    return os.path.join(root, "data", ".cache")


def load_json(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _norm(s):
    return " ".join(str(s).split()).strip()


# The comparison form for BOTH axes: whitespace-collapsed, lowercased, and with the
# typographic punctuation a model normalizes when it RE-TYPES a value instead of copying
# it folded to its ASCII shape.
#
# THIS TABLE IS A SECOND COPY OF `fold()` IN hooks/get-digest.sh (its `_FOLD` tuple and
# `fold` function). The two MUST agree character for character, and a drift is not
# symmetric in cost: get-digest.sh folds before it decides which section a dispatch names,
# so a PUT canonicalizer that folds LESS than the GET gate refuses coordinates the gate
# would have served, and the cache goes cold for exactly the spellings the fold exists to
# rescue. Change one only together with the other, and only with the parity test green.
#
# EVERY CHARACTER IN THE TABLE IS WRITTEN AS AN ESCAPE, NEVER AS A LITERAL BYTE. CPython
# decodes a .py FILE as UTF-8 whatever the locale says (PEP 263), so a literal would run
# correctly here -- but this table is the one span most likely to be lifted into a
# `python3 -c` argument or a shell heredoc while chasing the parity above, and there a
# literal is decoded with the AMBIENT LOCALE CODEC and raises SyntaxError under LC_ALL=C.
# Its sibling copy in hooks/get-digest.sh keeps the same discipline for that reason. The
# runtime strings are identical either way, so the escapes cost nothing.
#
# `.lower()` deliberately, NOT `.casefold()`: casefold maps eszett to `ss`, which would
# change what can collide and invalidate the zero-collision measurement this fold rests on.
# The German letters are NOT folded -- a re-typed ASCII transliteration of an umlaut or an
# eszett does not resolve, and that is the tolerable direction (a refusal, never a wrong
# section). That class is the larger one: of the 992 shipped anchor rows, 172 carry a
# character this table folds and 307 carry an umlaut or an eszett it does not (332 if the
# section sign is counted too, but that is not a letter and the sentence above means one).
_FOLD = (
    ("\u2014", "-"), ("\u2013", "-"), ("\u2212", "-"),   # em dash, en dash, minus
    ("\u2026", "..."),                                     # horizontal ellipsis
    ("\u00a0", " "),                                       # no-break space
    ("\u201c", '"'), ("\u201d", '"'), ("\u201e", '"'),   # curly double quotes
    ("\u2018", "'"), ("\u2019", "'"),                      # curly single quotes
)


def _fold(s):
    t = _norm(s).lower()
    for a, b in _FOLD:
        t = t.replace(a, b)
    return " ".join(t.split())


# The value both canonicalizers return when the supplied vocabulary does not contain the
# value being resolved. A VALUE, never an exception: EXIT_MISS is 1 and an uncaught raise
# also exits 1, so a raising canonicalizer would report "this coordinate is not in the
# cache" and "this coordinate is nonsense" through the same byte, and the put hook's
# first-line extractor would lift `Traceback (most recent call last):` as the audit reason.
UNRESOLVED = None

# Prefix of the section key :section_key returns for an unresolvable coordinate. The key
# is UNIQUE PER IDENTITY -- a sha over the whole raw identity, so the same unplaceable
# anchor keys differently when the supplied vocabulary differs (a reader emits a
# document-scoped list, the get hook emits the corpus-wide union). Per-identity, NOT
# per-coordinate: do not rely on it to correlate recurrences of one bad anchor.
#
# WHY NOT A SHARED CONSTANT, stated correctly because an earlier draft of this comment
# got it wrong and a wrong rationale is the kind that gets trusted: it is NOT that the put
# hook would dedup the second refusal away. That hook writes its dedup marker only on a
# SUCCESSFUL put, so no marker is ever created under an `unresolved-` name and the dedup
# test cannot fire on this path at all -- a shared constant was measured to lose nothing,
# and a repeated bad section was measured NOT to dedup. The real reason is audit
# legibility: each refusal stays individually identifiable in the log instead of N lines
# sharing one opaque key, and a future hook that did mark failures would inherit correct
# behaviour rather than silently collapsing them.
UNRESOLVED_KEY_PREFIX = "unresolved-"


def is_unresolved_key(key):
    """True for a key :section_key produced for a coordinate it could not resolve."""
    return isinstance(key, str) and key.startswith(UNRESOLVED_KEY_PREFIX)


class UnresolvedCoordinate(Exception):
    """Raised by :entry_path if it is reached with an unresolvable coordinate.

    A BACKSTOP, not the contract. Every caller inside this file resolves first and refuses
    (put) or misses (get) before a path is ever built, so this cannot fire on any path that
    exists today. It exists so a future caller that forgets the guard fails with a named
    diagnostic and EXIT_USAGE, instead of the TypeError that `os.path.join(cdir, None)`
    would raise -- which the interpreter reports as exit 1, and 1 is EXIT_MISS.
    """


def _resolve(raw, vocabulary):
    """Return the vocabulary's spelling of ``raw``, or :UNRESOLVED.

    TWO STEPS AND NO THIRD, and the missing third step is the whole of the fix:

      1. exact match (whitespace-normalized, case-insensitive) -> that entry, verbatim;
      2. else fold-equal match (:_fold) -> the vocabulary's spelling;
      3. else UNRESOLVED.

    WHAT WAS DELETED HERE AND WHY. Step 3 used to be two more branches -- a longest
    CONTAINMENT match behind a leading-token guard, then a fall-through that accepted the
    caller's own spelling. Each produced a confident wrong answer of a different shape:

      - CONTAINMENT wrote a digest under a section it never read. Measured on the shipped
        page-maps: `APO-GrundStGy` (the document's own name, not one of its sections)
        resolved to `APO-GrundStGy Abschnitt 2 <em dash> Leistungsbewertung ...`, and
        `Thema: Ikonen (gA) - II` resolved to the `III` sibling, because `- II` is a
        substring of `- III`. A later read of the REAL section then HIT that entry and was
        served the wrong section's text, with nothing in any log to say so.
      - THE FALL-THROUGH wrote an entry under a coordinate no reader can ever ask for. The
        get side supplies a page-map anchor verbatim, so a non-page-map anchor is written,
        self-confirmed by the put-then-get check, and never served again.

    Neither failure is observable from the outside, which is why refusing is strictly
    better than either: a refusal costs a re-read (exactly what the unreachable entry
    already cost) and buys a named diagnostic.

    Step 2 is NOT optional and NOT the same as "exact". The GET gate folds before it
    decides which section a dispatch names, so an exact-only PUT canonicalizer would be
    stricter than the gate it has to agree with, and would refuse the realistic drift class
    the gate happily resolves. Measured over the corpus: applying a single dash/ellipsis
    mangle to every real anchor, fold-normalized resolution recovers 172/172 correctly,
    with zero wrong resolutions and zero ambiguities.

    AMBIGUITY IS UNRESOLVABLE, not a coin toss. If more than one DISTINCT vocabulary entry
    is fold-equal to ``raw`` there is no fact of the matter about which was meant, and
    picking one is the guessing this function exists to stop. Measured intra-document fold
    collisions across the shipped page-maps: 0 -- so this is a guard against a future
    page-map, not a behaviour anything relies on today.
    """
    if not isinstance(vocabulary, (list, tuple)):
        return UNRESOLVED
    raw_n = _norm(raw)
    for entry in vocabulary:
        if _norm(entry).lower() == raw_n.lower():
            return entry
    target = _fold(raw)
    hits = []
    for entry in vocabulary:
        if _fold(entry) == target and entry not in hits:
            hits.append(entry)
    return hits[0] if len(hits) == 1 else UNRESOLVED


def canonical_document_id(raw, registry_ids):
    """Map a freely-spelled document_id onto the registry's canonical id, or :UNRESOLVED.

    The vocabulary is CALLER-SUPPLIED, and that is a recorded residual: a writer who is
    wrong about the id is by construction wrong about the dictionary that would catch it.
    Membership plus the citation cross-check in :validate_identity closes the observed
    failure; reading the registry from disk here would close the rest.
    """
    return _resolve(raw, registry_ids)


def canonical_section_anchor(raw, page_map_sections):
    """Map a freely-spelled section_anchor onto the page-map's anchor, or :UNRESOLVED."""
    return _resolve(raw, page_map_sections)


def resolve_coordinate(identity):
    """Return the (document_id, section_anchor) pair this identity keys on.

    Either element may be :UNRESOLVED; the three callers answer that differently and
    deliberately -- see :cmd_put (reject), :cmd_get (miss) and :main's derive-identity arm
    (non-zero, which the get hook reads as fail-open).
    """
    doc = canonical_document_id(identity.get("document_id"),
                                identity.get("registry_document_ids", []))
    anc = canonical_section_anchor(identity.get("section_anchor"),
                                   identity.get("page_map_sections", []))
    return doc, anc


def _unresolved_key(identity):
    """A per-coordinate sentinel key. See :UNRESOLVED_KEY_PREFIX for why it is not shared."""
    try:
        canonical = json.dumps(identity, sort_keys=True, ensure_ascii=False,
                               separators=(",", ":"), default=str)
    except (TypeError, ValueError):
        canonical = repr(identity)
    return UNRESOLVED_KEY_PREFIX + hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def section_key(identity):
    """sha256 over the canonicalized (document_id, source_pdf_sha256, section_anchor) triple.

    Returns a key beginning ``unresolved-`` (test it with :is_unresolved_key) when either
    coordinate axis does not resolve. IT NEVER RAISES for that case, and the reason is the
    exit-code table: this function is called from :main's derive-identity arm and, through
    hooks/parse_envelopes.py, from the put hook. A raise in the first exits 1, which is
    EXIT_MISS; a raise in the second is swallowed by that module's ``except Exception:
    continue``, which drops the section before any line is emitted -- no entry, no
    diagnostic, no audit line, exit 0, byte-identical to "nothing happened here".
    """
    doc, anc = resolve_coordinate(identity)
    if doc is UNRESOLVED or anc is UNRESOLVED:
        return _unresolved_key(identity)
    triple = "\n".join([doc, identity["source_pdf_sha256"], anc])
    return "sha256:" + hashlib.sha256(triple.encode("utf-8")).hexdigest()


def is_fresh(entry, identity):
    fresh = entry.get("freshness")
    if not isinstance(fresh, list) or not fresh:
        return False
    for el in fresh:
        if el.get("source_pdf_sha256") != identity["source_pdf_sha256"]:
            return False
        if el.get("index_version") != identity["index_version"]:
            return False
    return True


def cmd_get(identity, cdir):
    # An unresolvable coordinate is a CLEAN MISS, and that is the whole answer: this
    # helper stores one file per resolved section, so a coordinate that names no section
    # genuinely has no entry. Returning EXIT_MISS here rather than letting :entry_path
    # build a path out of :UNRESOLVED keeps the two things the get hook depends on --
    # no traceback on stderr, and exit 1 -- and costs the caller exactly one real read,
    # which is what a miss always costs. Deliberately BEFORE :entry_path.
    doc, anc = resolve_coordinate(identity)
    if doc is UNRESOLVED or anc is UNRESOLVED:
        return EXIT_MISS
    path = entry_path(identity, cdir)
    if not os.path.exists(path):
        return EXIT_MISS
    try:
        entry = load_json(path)
    except (OSError, json.JSONDecodeError):
        return EXIT_MISS
    # Backward-compat: a non-canonical-shaped file reads as a miss.
    if not isinstance(entry, dict) or validate_digest(entry.get("digest")):
        return EXIT_MISS
    if is_fresh(entry, identity):
        sys.stdout.write(json.dumps(entry, ensure_ascii=False))
        return EXIT_HIT
    return EXIT_MISS


def _brief(value, limit=60):
    """repr(), bounded. An offending value is evidence in a diagnostic, not a payload.

    Rejections are read by an agent and appended to an audit log, so an unbounded
    repr of a multi-kilobyte value would be copied into both.
    """
    text = repr(value)
    return text if len(text) <= limit else text[:limit] + "...(truncated)"


def _is_page(value):
    """A page number: a positive integer.

    `bool` is a subclass of `int` in Python and `True >= 1` holds, so `True` would
    otherwise pass as page 1 — it is excluded explicitly.
    """
    return isinstance(value, int) and not isinstance(value, bool) and value >= 1


def validate_digest(digest):
    """Return a list of schema problems; an empty list means the digest is canonical.

    ONE validator, TWO call sites — cmd_get (:cmd_get) and cmd_put (:cmd_put) — and
    every rule here takes effect on both at once, deliberately. A rule enforced on
    put alone would leave an entry already on disk being served forever by the one
    path that could refuse it; a rule enforced on get alone is a silent permanent
    re-read loop (get misses without a diagnostic, the reader pays a full read, put
    accepts the same shape, repeat). Together a bad write fails loudly with a named
    reason, and a bad entry already on disk falls out as a miss that self-heals on
    the next read plus its following put — which is what the get-side call exists
    for. Do not fork this function into a strict schema for writes and a lax one
    for reads: that parks the weaker rule on the path that decides what a reader is
    served.

    The page fields are a SHAPE floor, never a truth one — it says a claim names a
    place in a document, not that the place it names is the right one.
    """
    problems = []
    if not isinstance(digest, dict):
        return ["digest is not an object"]
    if "schema" in digest or "schema_version" in digest:
        problems.append("non-canonical schema marker present")
    claims = digest.get("claims")
    if not isinstance(claims, list) or not claims:
        problems.append("claims must be a non-empty list")
    else:
        for i, c in enumerate(claims):
            if not isinstance(c, dict):
                problems.append("claim %d not an object" % i); continue
            if not isinstance(c.get("content"), str):
                problems.append("claim %d missing content" % i)
            cit = c.get("citation")
            if not isinstance(cit, dict) or "document_id" not in cit or "section_anchor" not in cit:
                problems.append("claim %d citation missing document_id/section_anchor" % i)
            else:
                # printed_page / physical_page are what a reader opens. A citation
                # without them names a document, not a place in it — and both
                # writers (the pre-generated pack and a live read) are bound to
                # emit them, so this floor only refuses a shape neither is
                # permitted to produce.
                for field in ("printed_page", "physical_page"):
                    if not _is_page(cit.get(field)):
                        problems.append("claim %d citation.%s must be a positive integer, got %s"
                                        % (i, field, _brief(cit.get(field))))
                # printed_page_end is optional: its ABSENCE means the quotation sits
                # on one page, which is complete rather than deficient. Present, it
                # is a page like any other. No ordering rule against printed_page —
                # printed numbering may restart, so "later page, larger number" does
                # not hold in general.
                if "printed_page_end" in cit and not _is_page(cit["printed_page_end"]):
                    problems.append(
                        "claim %d citation.printed_page_end, when present, must be a positive "
                        "integer, got %s" % (i, _brief(cit["printed_page_end"])))
            if not isinstance(c.get("cited_text"), str):
                problems.append("claim %d missing cited_text" % i)
            if not isinstance(c.get("residual_flags"), list):
                problems.append("claim %d residual_flags must be a list" % i)
    hier = digest.get("hierarchy")
    if not isinstance(hier, dict) or not isinstance(hier.get("order"), list):
        problems.append("hierarchy.order must be a list")
    return problems


def validate_identity(identity, digest):
    """Return a list of COORDINATE problems; an empty list means this entry may be filed.

    THE GAP THIS CLOSES. :validate_digest takes exactly one argument — the digest — so it
    is structurally incapable of looking at the coordinate the digest is about to be filed
    under, and no other check looked either. A put therefore validated the *content* of an
    entry and nothing at all about *where* it was going, which is how a digest came to be
    persisted under a section it was never about.

    PUT-SIDE ONLY, and unlike :validate_digest that asymmetry is not a fork of one rule
    into a strict and a lax copy — it is a different question asked of a different object.
    :validate_digest asks "is this entry's content canonical?", and the answer must be the
    same on the way in and the way out. This function asks "does this coordinate exist?",
    and the get side already answers that question its own way: :cmd_get resolves the same
    two axes and returns a MISS when either does not resolve, which is what "no entry
    under a coordinate that names nothing" means for a reader. There is no weaker rule
    parked on the read path.

    THE THREE CHECKS, and what each is worth:

      - `document_id` resolves against the supplied `registry_document_ids`;
      - `section_anchor` resolves against the supplied `page_map_sections`;
      - every `claims[].citation.document_id` canonicalizes to the SAME id the identity
        claims. Measured over the 606 shipped pack entries: 0 violations, so this costs
        nothing today, and it would have caught all 8 of the entries that motivated it.

    WHAT THE THIRD CHECK DOES NOT COVER, stated because assuming otherwise is the trap:
    it does NOT cover the section_anchor axis. A reader that mis-spells an anchor emits
    the SAME mis-spelling in the identity and in every citation, so the two agree
    perfectly and the cross-check passes — the wrong-section write was never a
    disagreement between the identity and the claims, it happened inside this file's
    resolution. Only the second check above stands between that write and the disk.
    """
    if not isinstance(identity, dict):
        return ["identity is not an object"]
    registry = identity.get("registry_document_ids", [])
    doc = canonical_document_id(identity.get("document_id"), registry)
    anc = canonical_section_anchor(identity.get("section_anchor"),
                                   identity.get("page_map_sections", []))
    problems = []
    if doc is UNRESOLVED:
        problems.append("document_id unresolvable against registry_document_ids: %s"
                        % _brief(identity.get("document_id")))
    if anc is UNRESOLVED:
        problems.append("section_anchor unresolvable against page_map_sections: %s"
                        % _brief(identity.get("section_anchor")))
    if doc is UNRESOLVED:
        # Nothing to compare the citations against; reporting N further "mismatches"
        # against an unresolved id would bury the one problem that has to be fixed first.
        return problems
    # The resolved id becomes a DIRECTORY NAME in :entry_path, and :_atomic_write creates
    # it with makedirs. Vocabulary membership is not containment: that vocabulary arrives
    # in the same model-authored envelope as the id, from a reader whose input is
    # quarantined regulation text, so a member id of `../../x` satisfies both checks above
    # and lands the write OUTSIDE the cache root. Measured before this guard, on this tree
    # and on the pre-fix one: `put rc=0`, entry written outside the cache dir. The
    # basename is a sha256, so it is a containment escape rather than a targeted
    # overwrite -- but a firewall component must not create directories of the quarantine
    # side's choosing at all.
    if os.sep in doc or (os.altsep and os.altsep in doc) or os.path.isabs(doc) \
            or doc in (os.curdir, os.pardir):
        problems.append("document_id is not a single path component: %s" % _brief(doc))
    claims = digest.get("claims") if isinstance(digest, dict) else None
    if not isinstance(claims, list):
        return problems         # a shape :validate_digest has already refused
    for i, c in enumerate(claims):
        if not isinstance(c, dict):
            continue
        cit = c.get("citation")
        if not isinstance(cit, dict):
            continue
        cited = cit.get("document_id")
        if canonical_document_id(cited, registry) != doc:
            problems.append("document_id mismatch: claim %d cites %s, identity says %s"
                            % (i, _brief(cited, 40), _brief(identity.get("document_id"), 40)))
    return problems


# The first line of a rejection is MACHINE-READ: hooks/put-digest.sh lifts the audit
# reason from it with a FIRST-LINE-ONLY awk whose pattern carries this exact prefix, em
# dash included, and truncates what it lifts to a fixed width. Both constants below are
# therefore wire format, not formatting choices -- change either and a refused put stops
# carrying its reason into the audit log and degrades to a bare exit code. The em dash is
# written as an escape whose runtime string is byte-identical to the literal it replaces:
# the dash must be there, the source byte need not be. See :_reject_line for the budget.
_REJECT_PREFIX = "cache.py: reject \u2014 "
_REASON_LIMIT = 200


def _reject_line(problems):
    """Assemble line 1 of a rejection, bounded so the extractor never has to truncate it.

    THE BUDGET IS 200 AND IT IS NOT OURS TO EXCEED. The put hook prints
    ``substr(line, 1, 200)`` of what it lifts, so anything past that is discarded — and
    `substr` counts BYTES under a C locale, which is where the German text this helper
    handles lives, so the bound below is enforced on both characters and encoded bytes.

    WHAT SURVIVES A SQUEEZE, in order. An IDENTITY reason begins with the AXIS it is about
    (`document_id …`, `section_anchor …`), because that is the one token the reader of an
    audit line cannot reconstruct from anything else. (Not every reason does: this helper is
    also handed :validate_digest's problems, which begin `digest is not an object`,
    `claim 0 missing content`, `hierarchy.order must be a list`. The squeeze below keeps
    whole reasons either way — only the axis-first guarantee is identity-specific.)
    So when the assembled reasons do not
    fit, whole trailing reasons are dropped and replaced by a `(+N more)` counter rather
    than the line being cut mid-reason: a truncated tail would silently amputate the
    second axis's name, and an audit line that says a write was refused without saying
    over WHICH axis is the failure this whole path exists to prevent. Only a single reason
    that overruns on its own is cut, and it is cut from the END, where its axis is not.
    """
    def fits(line):
        return len(line) <= _REASON_LIMIT and len(line.encode("utf-8")) <= _REASON_LIMIT

    kept = list(problems)
    while kept:
        dropped = len(problems) - len(kept)
        line = _REJECT_PREFIX + "; ".join(kept) + (" (+%d more)" % dropped if dropped else "")
        if fits(line):
            return line
        kept.pop()
    line = _REJECT_PREFIX + (problems[0] if problems else "rejected")
    while not fits(line):
        line = line[:-1]
    return line


def build_entry(identity, digest):
    kc = dict(identity["key_components"])
    kc["read_scope_identity"] = section_key(identity)
    doc = canonical_document_id(identity["document_id"],
                                identity.get("registry_document_ids", []))
    return {
        "key_components": kc,
        "freshness": [{
            "document_id": doc,
            "source_pdf_sha256": identity["source_pdf_sha256"],
            "index_version": identity["index_version"],
        }],
        "digest": digest,
    }


def entry_path(identity, cdir):
    doc = canonical_document_id(identity["document_id"],
                                identity.get("registry_document_ids", []))
    key = section_key(identity)
    if doc is UNRESOLVED or is_unresolved_key(key):
        # Unreachable from :cmd_get and :cmd_put, which both resolve and answer first.
        # See :UnresolvedCoordinate for why this is a named raise and not a `join(None)`.
        raise UnresolvedCoordinate(
            "no path for an unresolvable coordinate: document_id=%s section_anchor=%s"
            % (_brief(identity.get("document_id")), _brief(identity.get("section_anchor"))))
    fname = key.split("sha256:")[-1] + ".json"
    return os.path.join(cdir, doc, fname)


def _atomic_write(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(obj, fh, ensure_ascii=False, indent=2)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _reject(problems):
    """Emit the TWO-LINE rejection and return EXIT_REJECT. Nothing is written to disk."""
    sys.stderr.write(_reject_line(problems) + "\n")
    # A SECOND LINE, NEVER APPENDED TO THE FIRST — a design constraint, not a
    # style choice. The rejection above says WHAT is wrong but not WHERE the
    # correct shape is written down, so a rejected writer reverse-engineers
    # the schema out of this file's source instead of reading the schema doc.
    # The pointer closes that, but it may not ride on line 1: the put hook
    # lifts the audit reason with a FIRST-LINE-ONLY extractor and truncates
    # what it lifts to a fixed width, so an appended clause would be swallowed
    # into the audit reason and could cut the field name off the end of it —
    # destroying the one thing that rejection exists to carry. On its own line
    # the pointer is invisible to that extractor and legible to every human
    # and agent reading stderr. Do not merge these two writes.
    sys.stderr.write("cache.py: canonical digest shape — references/schemas/digest-cache.md\n")
    return EXIT_REJECT


def cmd_put(identity, digest, cdir):
    """Persist one section's digest, or refuse — never write under a guessed coordinate.

    TWO GATES, IN THIS ORDER, and the order is load-bearing: the digest's shape first,
    because :validate_identity's citation cross-check reads `claims[].citation`, and asking
    it to reason about a `claims` that is not even a list would report a coordinate problem
    for what is really a malformed digest. Each gate returns on its first failure, so one
    put reports one class of problem, which is what the single-line audit reason can carry.
    """
    problems = validate_digest(digest)
    if problems:
        return _reject(problems)
    # THE COORDINATE, validated at last. Until this call the identity was checked by
    # nothing, anywhere — see :validate_identity. A refusal here is not a lost digest in
    # any sense worth mourning: the entry it replaces would have been either WRONG (filed
    # under a section it is not about, and served for that section forever) or UNREACHABLE
    # (filed under a coordinate no get can ask for, so the section is re-read every time
    # anyway). Refusing writes neither, costs exactly what the unreachable entry already
    # cost, and leaves a named reason in the audit log where there was silence.
    problems = validate_identity(identity, digest)
    if problems:
        return _reject(problems)
    _atomic_write(entry_path(identity, cdir), build_entry(identity, digest))
    return EXIT_HIT


def main(argv):
    parser = argparse.ArgumentParser(prog="cache.py")
    sub = parser.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("get")
    g.add_argument("--identity", required=True)
    p = sub.add_parser("put")
    p.add_argument("--identity", required=True)
    p.add_argument("--digest", required=True)
    d = sub.add_parser("derive-identity")
    d.add_argument("--identity", required=True)
    args = parser.parse_args(argv)

    # derive-identity only computes the section key (the get-side single source); it does
    # NOT need a resolvable cache dir, so it runs before/independently of cache_dir().
    if args.cmd == "derive-identity":
        try:
            identity = load_json(args.identity)
        except (OSError, json.JSONDecodeError) as exc:
            sys.stderr.write("cache.py: %s\n" % exc)
            return EXIT_USAGE
        key = section_key(identity)
        if is_unresolved_key(key):
            # NON-ZERO AND SILENT ON STDOUT, which is exactly what the caller needs.
            # hooks/get-digest.sh runs this derive and treats ANY non-zero as "this
            # dispatch is not firewall-shaped" -> it fails OPEN and lets the real read
            # happen. That is the right answer for a coordinate this helper cannot place:
            # no entry can exist under it (put refuses to create one), so there is nothing
            # to serve, and the reader must run. EXIT_MISS rather than EXIT_USAGE because
            # this is not a malformed invocation — the file parsed, the coordinate simply
            # names no section. Nothing on stdout: the hook only ever reads a key from a
            # successful derive, and a partial one would be worse than none.
            return EXIT_MISS
        sys.stdout.write(key)
        return EXIT_HIT

    try:
        cdir = cache_dir()
    except Exception as exc:  # noqa: BLE001 — surface as a usage error
        sys.stderr.write("cache.py: %s\n" % exc)
        return EXIT_USAGE

    try:
        identity = load_json(args.identity)
        if args.cmd == "get":
            return cmd_get(identity, cdir)
        digest = load_json(args.digest)
        return cmd_put(identity, digest, cdir)
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write("cache.py: %s\n" % exc)
        return EXIT_USAGE
    except UnresolvedCoordinate as exc:
        # The backstop, caught HERE so it can never leave as a traceback: an uncaught
        # raise exits 1, and 1 is EXIT_MISS — a nonsense coordinate would then be
        # reported to a caller as "no entry cached", which is the exact confusion the
        # whole value-not-exception design of :section_key exists to prevent. Unreachable
        # today; see :UnresolvedCoordinate.
        sys.stderr.write("cache.py: %s\n" % exc)
        return EXIT_USAGE


if __name__ == "__main__":
    # Pin BOTH output streams before the first write. Deliberately NOT at import
    # time: this module is also imported (hooks/parse_envelopes.py uses
    # :section_key), and a module that rewires the interpreter's streams on
    # import is a hidden side effect on its importer. It is the PROCESS boundary
    # that needs the pin, so the process entry point is where it goes.
    sys.stdout = _pin_utf8(sys.stdout)
    sys.stderr = _pin_utf8(sys.stderr)
    sys.exit(main(sys.argv[1:]))
