#!/usr/bin/env python3
"""Output-Gate Verifier — machine-produced gate evidence for a generated deliverable.

Reads a single job file describing an artifact and the expected values a caller
cannot derive, then reports per-gate read-back evidence about that artifact. It
CHECKS and REPORTS; it NEVER edits the artifact. Fix-up (restamping metadata,
injecting hyperlinks, refilling the template) is the caller's escalation work,
followed by a re-verify.

The gates guarantee that a delivered document is checked as a machine-verifiable
property of the artifact — independent of which tool or route authored the file.
This is the reference mechanism of record: any equivalent evidence-producing
method (an official document skill's own inspection path, a direct unzip+read,
a future native tool) satisfies the same gate identically. When no python3 is
reachable on the artifact's side, a bash `unzip -p` + `grep -E` read-back is the
documented equivalent floor.

Dependency-free: python3 standard library only, no pip, portable to python3 >= 3.9.

CLI (the single, quoting-safe contract):

    python3 verify_output.py --spec <job.json>

`--spec` is the ONLY argument. The artifact path, expected values, template
fingerprint reference, and reference/citation lists all live inside the job
file, so nothing on the command line is ever data. See the frozen job-file
schema below.

Output:
  - one JSON evidence object on stdout (the `gates` sub-object is lifted verbatim
    into the manifest's `gates` record; `detail` and the envelope are diagnostics);
  - a compact human summary on stderr.

Exit contract (the JSON is authoritative for recording/flagging; the exit code is
the fast-path "do I run a fix loop?" signal):
  0  no fix loop needed  — every applicable gate is pass / n/a / terminal-flagged
  1  gate fail(s)        — >=1 applicable gate failed (policy -> escalate; integrity -> withhold)
  2  usage / IO          — malformed CLI, or a well-formed artifact_path that cannot be opened
  3  bad job spec        — missing/invalid --spec, unknown schema/kind, self-inconsistent spec

Frozen `--spec` job-file schema (verify_spec_schema = 1):

    {
      "verify_spec_schema": 1,
      "artifact_path": "<file to verify; absolute or CWD-relative>",
      "artifact_kind": "docx_worksheet",
      "expected": { "title": "...", "teacher_name": "...", "company": "..."? },
      "template": {
        "mode": "sidecar" | "workspace-override" | "absent-evidenced" | "none",
        "template_id": "template_worksheet",
        "fingerprint_path": "<template>.fingerprint.json",   # required for sidecar
        "override_template_path": "<live template binary>",  # required for workspace-override
        "listing_evidence": { "directory": "...", "entries": [...], "listed_at": "..." }  # required for absent-evidenced
      },
      "expected_references": [ { "label": "...", "target": "<relative path>" } ],
      "resolvable_citations": [ { "citation": "...", "url": "https://...", "page": 24 } ]
    }

Fingerprint sidecar schema (produced by the dev-side generator; canonical keys,
with lenient fallbacks for forward compatibility):

    {
      "fingerprint_schema": 1,
      "template_id": "template_worksheet",
      "family": "docx",
      "style_ids": ["Normal", "Heading1", ...],
      "header_footer_parts": ["word/header1.xml", "word/footer1.xml"],
      "signature_parts": ["ppt/slideMasters/slideMaster1.xml", ...],
      "application": "Thalura",
      "placeholders": ["{{MATERIAL_TITLE}}", "{{BODY_CONTENT}}"],
      "source_sha256": "..."
    }

Bridge / materialization (host/VM split — Cowork). The plugin tree (this script +
the fingerprint sidecars) is host-side only; generated artifacts live in the
VM-reachable shared workspace, run from `mcp__workspace__bash`; neither side
natively reaches BOTH the script and the artifact in one shell. Run the verifier
where both are reachable; when no single side reaches both, materialize this
script to the artifact's side (the VM workspace, the reachable-from-both bridge)
and integrity-check the materialized copy against the shipped checksum sidecar
before trusting its output — the same materialize-to-artifact-side precedent used
for the firewall render (host-side file tools reach the workspace; the VM shell
runs python3 there). Fingerprint sidecars ride the same bridge (small JSON,
readable host-side, inline-passable to the VM side). No-python floor: when
python3 is unreachable on the artifact's side, a bash `unzip -p` + `grep -E`
read-back qualifies as evidence "equivalent".

  Regenerate the checksum sidecar (trivial, no python needed on either side):
      shasum -a 256 scripts/verify_output.py > scripts/verify_output.py.sha256
  Verify a materialized copy before trusting it:
      shasum -a 256 -c scripts/verify_output.py.sha256
"""
import argparse
import datetime
import json
import os
import re
import sys
import urllib.parse
import zipfile
import zlib

EXIT_PASS = 0
EXIT_FAIL = 1
EXIT_USAGE = 2
EXIT_BADSPEC = 3

SPEC_SCHEMA = 1
OUTPUT_SCHEMA = 1

# Authoring-library fingerprints that must never survive into a delivered
# document's metadata (how-it-was-made leakage, not the honest converter/product
# identity). Matched case-insensitively.
LIBRARY_FINGERPRINTS = ("python-docx", "python-pptx", "pptxgenjs")
# python-docx's default OOXML Application string and default epoch timestamp.
LIBRARY_DEFAULT_APPLICATION = "Microsoft Macintosh Word"
LIBRARY_DEFAULT_EPOCH = "2013-12-23T23:15:00"
PRODUCT_APPLICATION = "Thalura"

# artifact_kind -> which gates are applicable. `template` is further driven by
# template.mode; `file_links` by the reference/hyperlink presence; `citation_links`
# by the resolvable-citation list (empty -> degrade PASS). A False here means the
# gate is structurally n/a for the kind.
KIND_GATES = {
    "docx_worksheet":        {"family": "docx", "metadata": True,  "template": True,  "file_links": True,  "citation_links": True},
    "docx_handout":          {"family": "docx", "metadata": True,  "template": True,  "file_links": True,  "citation_links": True},
    "docx_reading_text":     {"family": "docx", "metadata": True,  "template": True,  "file_links": True,  "citation_links": True},
    "docx_unit_plan":        {"family": "docx", "metadata": True,  "template": True,  "file_links": True,  "citation_links": True},
    "docx_lesson_plan":      {"family": "docx", "metadata": True,  "template": True,  "file_links": True,  "citation_links": True},
    "docx_material_overview":{"family": "docx", "metadata": True,  "template": True,  "file_links": True,  "citation_links": False},
    "docx_year_overview":    {"family": "docx", "metadata": True,  "template": True,  "file_links": True,  "citation_links": False},
    "docx_assessment_task":  {"family": "docx", "metadata": True,  "template": True,  "file_links": True,  "citation_links": True},
    "docx_assessment_rubric":{"family": "docx", "metadata": True,  "template": True,  "file_links": True,  "citation_links": True},
    "docx_reflection":       {"family": "docx", "metadata": True,  "template": True,  "file_links": True,  "citation_links": True},
    "pptx_slides":           {"family": "pptx", "metadata": True,  "template": True,  "file_links": True,  "citation_links": True},
    "pptx_task_deck":        {"family": "pptx", "metadata": True,  "template": True,  "file_links": True,  "citation_links": True},
    "pdf":                   {"family": "pdf",  "metadata": False, "template": False, "file_links": False, "citation_links": False},
}


class BadSpec(Exception):
    """Raised for a missing/invalid/self-inconsistent job spec (exit 3)."""


class ArtifactIO(Exception):
    """Raised when a well-formed artifact_path cannot be opened/read (exit 2)."""


# ---------------------------------------------------------------------------
# OOXML read-back helpers
# ---------------------------------------------------------------------------

def _zip_read_text(zf, name):
    # KeyError: member absent. BadZipFile/zlib.error/OSError: member present
    # but decompression-corrupt (partial write) -- degrade to None so the
    # evidence JSON is always produced; the integrity gate reports the damage.
    try:
        return zf.read(name).decode("utf-8", "replace")
    except (KeyError, zipfile.BadZipFile, zlib.error, OSError):
        return None


def _tag_text(xml, tag):
    """Inner text of the first <tag ...>...</tag>, or None. Empty element -> ''."""
    if xml is None:
        return None
    m = re.search(r"<%s\b[^>]*>(.*?)</%s>" % (re.escape(tag), re.escape(tag)), xml, re.S)
    if m:
        return m.group(1)
    # Self-closing / empty-value element (e.g. <dc:title/>).
    if re.search(r"<%s\b[^>]*/>" % re.escape(tag), xml):
        return ""
    return None


def read_docprops(zf):
    """Return the OOXML metadata read-back for a docx/pptx zip."""
    core = _zip_read_text(zf, "docProps/core.xml")
    app = _zip_read_text(zf, "docProps/app.xml")
    return {
        "creator": _tag_text(core, "dc:creator"),
        "last_modified_by": _tag_text(core, "cp:lastModifiedBy"),
        "title": _tag_text(core, "dc:title"),
        "description": _tag_text(core, "dc:description"),
        "created": _tag_text(core, "dcterms:created"),
        "modified": _tag_text(core, "dcterms:modified"),
        "application": _tag_text(app, "Application"),
        "company": _tag_text(app, "Company"),
    }


def style_ids(zf):
    """Named w:styleId set (docx). Empty for packages without word/styles.xml."""
    s = _zip_read_text(zf, "word/styles.xml")
    if s is None:
        return set()
    return set(re.findall(r'w:styleId="([^"]+)"', s))


def part_names(zf):
    return set(zf.namelist())


def hyperlink_targets(zf, family):
    """Return the list of hyperlink relationship targets across the document.

    Covers the main document part plus any relationship part (so pptx slide
    hyperlinks are seen too). Shape-only: no domain knowledge.
    """
    targets = []
    for name in zf.namelist():
        if not name.endswith(".rels"):
            continue
        rels = _zip_read_text(zf, name)
        if not rels:
            continue
        for m in re.finditer(r"<Relationship\b[^>]*>", rels):
            tag = m.group(0)
            if "/hyperlink" not in tag:
                continue
            t = re.search(r'Target="([^"]*)"', tag)
            if t:
                targets.append(t.group(1))
    return targets


# ---------------------------------------------------------------------------
# Minimal PDF /Info parser (bounds: classic xref + trailer + /Info dict).
# Object streams / xref streams / encrypted PDFs are out of bounds and report
# the reserved "unparseable" read-back value (never a false PASS/FAIL).
# ---------------------------------------------------------------------------

def _decode_pdf_string(raw):
    raw = raw.strip()
    if raw.startswith("<") and raw.endswith(">"):
        hexs = re.sub(r"\s", "", raw[1:-1])
        if len(hexs) % 2:
            hexs += "0"
        try:
            b = bytes.fromhex(hexs)
        except ValueError:
            return ""
        if b[:2] == b"\xfe\xff":  # UTF-16BE BOM (soffice emits this form)
            return b[2:].decode("utf-16-be", "replace")
        return b.decode("latin-1", "replace")
    if raw.startswith("(") and raw.endswith(")"):
        s = raw[1:-1]
        return s.replace(r"\(", "(").replace(r"\)", ")").replace(r"\\", "\\")
    return raw


def parse_pdf_info(data):
    """Return a dict of Info keys, or the string 'unparseable' for out-of-bounds PDFs."""
    if data[:5] != b"%PDF-":
        return "unparseable"
    if re.search(rb"/Encrypt\b", data):
        return "unparseable"
    trailer = None
    for m in re.finditer(rb"trailer\b", data):
        trailer = data[m.end():m.end() + 800]
    if trailer is None:
        return "unparseable"  # xref-stream PDF: no classic `trailer` keyword
    mi = re.search(rb"/Info\s+(\d+)\s+(\d+)\s+R", trailer)
    if not mi:
        return "unparseable"
    num = mi.group(1)
    obj = re.search(rb"(?:^|[^0-9])" + num + rb"\s+0\s+obj(.*?)endobj", data, re.S)
    if not obj:
        return "unparseable"  # Info lives in a compressed object stream
    body = obj.group(1).decode("latin-1", "replace")
    out = {}
    for key in ("Author", "Producer", "Creator", "Title"):
        m = re.search(r"/%s\s*(\([^)]*\)|<[0-9A-Fa-f\s]*>)" % key, body)
        out[key] = _decode_pdf_string(m.group(1)) if m else None
    return out


def _has_library_fingerprint(value):
    if not value:
        return False
    low = value.lower()
    return any(lib in low for lib in LIBRARY_FINGERPRINTS)


# ---------------------------------------------------------------------------
# Gate implementations. Each returns (outcome_token, detail_dict) and, where
# relevant, contributes read-back values.
# ---------------------------------------------------------------------------

def gate_metadata(props, expected):
    """docx/pptx metadata gate. Returns (outcome, detail)."""
    fingerprint = (
        _has_library_fingerprint(props.get("creator"))
        or _has_library_fingerprint(props.get("application"))
        or (props.get("application") or "") == LIBRARY_DEFAULT_APPLICATION
        or "generated by python-docx" in (props.get("description") or "").lower()
        or _has_library_fingerprint(props.get("description"))
    )
    created = props.get("created") or ""
    modified = props.get("modified") or ""
    if created and created == modified and created.startswith(LIBRARY_DEFAULT_EPOCH):
        fingerprint = True

    teacher = expected.get("teacher_name")
    title = expected.get("title")
    company = expected.get("company")

    mismatches = []
    if props.get("creator") != teacher:
        mismatches.append("creator")
    if props.get("last_modified_by") != teacher:
        mismatches.append("last_modified_by")
    if title is not None and props.get("title") != title:
        mismatches.append("title")
    if (props.get("application") or "") != PRODUCT_APPLICATION:
        mismatches.append("application")
    if company:  # empty/absent expected company is permitted by the contract
        if (props.get("company") or "") != company:
            mismatches.append("company")

    outcome = "pass" if (not fingerprint and not mismatches) else "fail"
    detail = {"authoring_library_fingerprint": fingerprint, "mismatches": mismatches}
    return outcome, detail


def _load_fingerprint_dict(fp):
    """Normalize a fingerprint sidecar dict to (styles:set, parts:set, application)."""
    styles = fp.get("style_ids") or fp.get("styles") or fp.get("named_style_ids") or []
    parts = []
    for key in ("header_footer_parts", "signature_parts", "parts", "lineage_parts"):
        val = fp.get(key)
        if val:
            parts.extend(val)
    return set(styles), set(parts), fp.get("application")


def _fingerprint_from_template(path):
    """Compute a live fingerprint (styles + signature parts) from a template binary."""
    with zipfile.ZipFile(path) as zf:
        styles = style_ids(zf)
        names = part_names(zf)
    parts = {n for n in names if re.search(r"/(header|footer)\d*\.xml$", n)}
    parts |= {n for n in names if re.search(r"/(slideMasters|slideLayouts)/[^/]+\.xml$", n)}
    return styles, parts


def gate_template(artifact_zf, template_spec):
    """Template-fidelity gate. Returns (outcome, detail) where outcome is a
    template id / workspace-override / absent-evidenced / n/a / fail."""
    mode = template_spec.get("mode")
    if mode == "none":
        return "n/a", {"matched": None, "missing_styles": [], "missing_parts": [], "source": "none"}
    if mode == "absent-evidenced":
        # Validity of listing_evidence is enforced at spec-load time (exit 3).
        return "absent-evidenced", {"matched": None, "missing_styles": [], "missing_parts": [],
                                     "source": "absent-evidenced"}

    if mode == "sidecar":
        fp_path = template_spec.get("fingerprint_path")
        try:
            with open(fp_path, "r", encoding="utf-8") as fh:
                fp = json.load(fh)
        except (OSError, json.JSONDecodeError, TypeError) as exc:
            raise BadSpec("sidecar fingerprint unreadable: %s" % exc)
        fp_styles, fp_parts, _ = _load_fingerprint_dict(fp)
        source = "sidecar"
        pass_value = template_spec.get("template_id")
    elif mode == "workspace-override":
        ov = template_spec.get("override_template_path")
        try:
            fp_styles, fp_parts = _fingerprint_from_template(ov)
        except (OSError, zipfile.BadZipFile, TypeError) as exc:
            raise BadSpec("override template unreadable: %s" % exc)
        source = "workspace-override"
        pass_value = "workspace-override"
    else:
        raise BadSpec("unknown template.mode: %r" % mode)

    art_styles = style_ids(artifact_zf)
    art_parts = part_names(artifact_zf)
    missing_styles = sorted(fp_styles - art_styles)
    missing_parts = sorted(fp_parts - art_parts)
    matched = not missing_styles and not missing_parts
    detail = {"matched": matched, "missing_styles": missing_styles,
              "missing_parts": missing_parts, "source": source}
    return (pass_value if matched else "fail"), detail


def _is_citation_url(target):
    return bool(re.match(r"^https?://", target, re.I))


def _is_absolute_target(target):
    return (
        target.startswith("/")
        or target.startswith("file:")
        or target.startswith("\\\\")
        or bool(re.match(r"^[A-Za-z]:[\\/]", target))
    )


def gate_file_links(targets, expected_references, artifact_dir):
    """Referenced-file hyperlink gate. Returns (outcome, detail).

    OPC relationship Target attributes are URIs, so non-ASCII characters and
    spaces arrive percent-encoded (e.g. "Arbeitsbl%C3%A4tter/M%2001.docx" for
    "Arbeitsblätter/M 01.docx"). Existence checks and norm_found membership use
    the percent-decoded form so that a correct relative link to a German-named
    folder is not reported as missing. Detail dicts (targets / missing_targets /
    absolute_targets) keep the raw artifact bytes for evidence fidelity.
    _is_citation_url is evaluated on the raw target. For the absolute-target
    check, either the raw or the decoded form matching _is_absolute_target is
    treated as absolute (fail-safe over-strict direction).
    """
    file_targets = [t for t in targets if not _is_citation_url(t)]
    absolute = [t for t in file_targets
                if _is_absolute_target(t) or _is_absolute_target(urllib.parse.unquote(t))]
    missing = []
    for t in file_targets:
        if _is_absolute_target(t) or _is_absolute_target(urllib.parse.unquote(t)):
            continue
        decoded = urllib.parse.unquote(t)
        if not os.path.exists(os.path.normpath(os.path.join(artifact_dir, decoded))):
            missing.append(t)  # raw target stays in missing_targets for evidence

    # Build norm_found from decoded targets so expected_references (plain paths)
    # are matched correctly against percent-encoded hyperlink targets.
    norm_found = {os.path.normpath(urllib.parse.unquote(t)) for t in file_targets}
    plaintext_rows = []
    for ref in expected_references:
        tgt = ref.get("target")
        if not tgt:
            continue
        exists = os.path.exists(os.path.normpath(os.path.join(artifact_dir, tgt)))
        linked = os.path.normpath(tgt) in norm_found
        if exists and not linked:
            plaintext_rows.append(tgt)

    applicable = bool(expected_references) or bool(file_targets)
    detail = {
        "found": len(file_targets),
        "targets": file_targets,
        "plaintext_rows_with_existing_target": plaintext_rows,
        "absolute_targets": absolute,
        "missing_targets": missing,
    }
    if not applicable:
        return "n/a", detail
    failed = absolute or missing or plaintext_rows
    verdict = "fail" if failed else "pass"
    return "%s:%d" % (verdict, len(file_targets)), detail


def gate_citation_links(targets, resolvable_citations):
    """Regulation-citation link gate (shape only). Returns (outcome, detail)."""
    citation_targets = [t for t in targets if _is_citation_url(t)]
    if not resolvable_citations:
        # Degrade branch: with no resolvable citations, plain-text citations pass.
        detail = {"resolvable_expected": 0, "linked": 0, "unresolved_plaintext": 0}
        return "pass:0", detail

    linked = 0
    for c in resolvable_citations:
        url = c.get("url")
        page = c.get("page")
        if not url:
            continue
        for t in citation_targets:
            if t.startswith(url) and (page is None or ("#page=%s" % page) in t):
                linked += 1
                break
    expected = len(resolvable_citations)
    detail = {"resolvable_expected": expected, "linked": linked,
              "unresolved_plaintext": expected - linked}
    verdict = "pass" if linked >= expected else "fail"
    return "%s:%d" % (verdict, linked), detail


def gate_pdf(data, expected):
    """PDF metadata gate. Returns (outcome, detail, read_back-additions)."""
    info = parse_pdf_info(data)
    if info == "unparseable":
        detail = {"author": None, "producer": None, "creator": None, "title": None,
                  "parse": "unparseable"}
        read_back = {"pdf_author": None, "pdf_producer": None, "pdf_creator": None,
                     "pdf_title": None, "pdf_parse": "unparseable"}
        return "flagged", detail, read_back

    author = info.get("Author")
    producer = info.get("Producer")
    creator = info.get("Creator")
    title = info.get("Title")
    read_back = {"pdf_author": author, "pdf_producer": producer,
                 "pdf_creator": creator, "pdf_title": title, "pdf_parse": "ok"}
    detail = {"author": author, "producer": producer, "creator": creator,
              "title": title, "parse": "ok"}

    teacher = expected.get("teacher_name")
    ok = True
    if not author:  # empty/absent /Author is the sole hard failure
        ok = False
    elif _has_library_fingerprint(author):
        ok = False
    elif author != teacher:
        ok = False
    # A carried authoring-library fingerprint in producer/creator is prohibited;
    # the honest converter's own identity (LibreOffice/Writer) is permitted.
    if _has_library_fingerprint(producer) or _has_library_fingerprint(creator):
        ok = False
    return ("pass" if ok else "fail"), detail, read_back


def gate_integrity(family, path, data):
    """Zip validity (docx/pptx) / PDF header sanity. Returns 'pass' | 'fail'."""
    if family == "pdf":
        return "pass" if data[:5] == b"%PDF-" else "fail"
    if not zipfile.is_zipfile(path):
        return "fail"
    try:
        with zipfile.ZipFile(path) as zf:
            if zf.testzip() is not None:
                return "fail"
            if "[Content_Types].xml" not in zf.namelist():
                return "fail"
    except (zipfile.BadZipFile, zlib.error, OSError):
        return "fail"
    return "pass"


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

def _now_iso():
    override = os.environ.get("THALURA_VERIFY_NOW")
    if override:
        return override
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _validate_spec(spec):
    """Structural validation of the job spec. Raises BadSpec on any violation."""
    if not isinstance(spec, dict):
        raise BadSpec("job spec is not a JSON object")
    if spec.get("verify_spec_schema") != SPEC_SCHEMA:
        raise BadSpec("unknown verify_spec_schema: %r" % spec.get("verify_spec_schema"))
    if not spec.get("artifact_path"):
        raise BadSpec("artifact_path is required")
    kind = spec.get("artifact_kind")
    if kind not in KIND_GATES:
        raise BadSpec("unknown artifact_kind: %r" % kind)

    expected = spec.get("expected") or {}
    if not expected.get("teacher_name"):
        raise BadSpec("expected.teacher_name is required")

    template = spec.get("template") or {}
    mode = template.get("mode")
    family = KIND_GATES[kind]["family"]
    if family != "pdf" and KIND_GATES[kind]["template"]:
        if mode not in ("sidecar", "workspace-override", "absent-evidenced", "none"):
            raise BadSpec("template.mode invalid or missing: %r" % mode)
        if mode == "sidecar" and not template.get("fingerprint_path"):
            raise BadSpec("template.mode 'sidecar' requires fingerprint_path")
        if mode == "workspace-override" and not template.get("override_template_path"):
            raise BadSpec("template.mode 'workspace-override' requires override_template_path")
        if mode == "absent-evidenced" and not template.get("listing_evidence"):
            # An unevidenced "no template" is a FAIL by construction — refuse to bless it.
            raise BadSpec("template.mode 'absent-evidenced' requires listing_evidence")


def verify(spec):
    """Run every applicable gate and return the stdout evidence object."""
    _validate_spec(spec)
    kind = spec["artifact_kind"]
    gates_applicable = KIND_GATES[kind]
    family = gates_applicable["family"]
    path = spec["artifact_path"]
    expected = spec.get("expected") or {}
    template_spec = spec.get("template") or {}
    expected_references = spec.get("expected_references") or []
    resolvable_citations = spec.get("resolvable_citations") or []
    artifact_dir = os.path.dirname(os.path.abspath(path))

    try:
        with open(path, "rb") as fh:
            data = fh.read()
    except OSError as exc:
        raise ArtifactIO("cannot open artifact_path: %s" % exc)

    gates = {"verified_at": _now_iso(), "evidence": "verifier"}
    read_back = {}
    detail = {}
    outcomes = {}  # gate -> outcome token (for overall/exit)

    if family in ("docx", "pptx"):
        try:
            artifact_zf = zipfile.ZipFile(path)
        except zipfile.BadZipFile:
            # A corrupt package: integrity fails; nothing else can be read.
            gates.update({"metadata": "n/a", "template": "n/a",
                          "file_links": "n/a", "citation_links": "n/a", "pdf": "n/a"})
            detail["integrity"] = "fail"
            return _finalize(spec, gates, read_back, detail, {"integrity": "fail"})
        with artifact_zf:
            props = read_docprops(artifact_zf)
            read_back.update({
                "creator": props.get("creator"),
                "last_modified_by": props.get("last_modified_by"),
                "title": props.get("title"),
                "application": props.get("application"),
                "company": props.get("company"),
            })
            if gates_applicable["metadata"]:
                outcome, dmeta = gate_metadata(props, expected)
                gates["metadata"] = outcome
                outcomes["metadata"] = outcome
                detail["metadata"] = dmeta
            else:
                gates["metadata"] = "n/a"

            if gates_applicable["template"]:
                outcome, dtmpl = gate_template(artifact_zf, template_spec)
                gates["template"] = outcome
                outcomes["template"] = outcome
                detail["template"] = dtmpl
            else:
                gates["template"] = "n/a"

            targets = hyperlink_targets(artifact_zf, family)

        if gates_applicable["file_links"]:
            outcome, dlinks = gate_file_links(targets, expected_references, artifact_dir)
            gates["file_links"] = outcome
            outcomes["file_links"] = outcome
            detail["file_links"] = dlinks
        else:
            gates["file_links"] = "n/a"

        if gates_applicable["citation_links"]:
            outcome, dcit = gate_citation_links(targets, resolvable_citations)
            gates["citation_links"] = outcome
            outcomes["citation_links"] = outcome
            detail["citation_links"] = dcit
        else:
            gates["citation_links"] = "n/a"

        gates["pdf"] = "n/a"

    elif family == "pdf":
        gates.update({"metadata": "n/a", "template": "n/a",
                      "file_links": "n/a", "citation_links": "n/a"})
        outcome, dpdf, pdf_read_back = gate_pdf(data, expected)
        gates["pdf"] = outcome
        outcomes["pdf"] = outcome
        detail["pdf"] = dpdf
        read_back.update(pdf_read_back)

    integrity = gate_integrity(family, path, data)
    detail["integrity"] = integrity
    outcomes["integrity"] = integrity

    return _finalize(spec, gates, read_back, detail, outcomes)


def _finalize(spec, gates, read_back, detail, outcomes):
    gates["read_back"] = read_back
    # `overall` fails on any gate `fail` (policy or integrity). A pdf `flagged`
    # (unparseable terminal) is deliverable and never a fail.
    failed = any(v == "fail" or (isinstance(v, str) and v.startswith("fail:"))
                 for v in outcomes.values())
    overall = "fail" if failed else "pass"
    return {
        "verify_output_schema": OUTPUT_SCHEMA,
        "artifact_path": spec.get("artifact_path"),
        "artifact_kind": spec.get("artifact_kind"),
        "overall": overall,
        "gates": gates,
        "detail": detail,
    }


def _summary_line(gate, outcome):
    return "  %-14s %s" % (gate, outcome)


def write_summary(result):
    g = result["gates"]
    lines = ["verify_output: %s  %s" % (result["artifact_kind"], result["artifact_path"])]
    for key in ("metadata", "template", "file_links", "citation_links", "pdf"):
        lines.append(_summary_line(key, g.get(key)))
    lines.append(_summary_line("integrity", result["detail"].get("integrity")))
    exit_code = EXIT_FAIL if result["overall"] == "fail" else EXIT_PASS
    lines.append("  => overall %s (exit %d)" % (result["overall"].upper(), exit_code))
    sys.stderr.write("\n".join(lines) + "\n")


def main(argv):
    parser = argparse.ArgumentParser(prog="verify_output.py", add_help=True)
    parser.add_argument("--spec", required=True, help="path to the job.json spec file")
    args = parser.parse_args(argv)

    try:
        with open(args.spec, "r", encoding="utf-8") as fh:
            spec = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write("verify_output: bad spec: %s\n" % exc)
        return EXIT_BADSPEC

    try:
        result = verify(spec)
    except BadSpec as exc:
        sys.stderr.write("verify_output: bad spec: %s\n" % exc)
        return EXIT_BADSPEC
    except ArtifactIO as exc:
        sys.stderr.write("verify_output: %s\n" % exc)
        return EXIT_USAGE

    sys.stdout.write(json.dumps(result, ensure_ascii=False))
    write_summary(result)
    return EXIT_FAIL if result["overall"] == "fail" else EXIT_PASS


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
