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
                                               exit 3 on schema-reject (nothing written)
Both: exit 2 on usage/IO error (stderr diagnostic).

Path: <WORKSPACE_ROOT>/data/.cache, where <WORKSPACE_ROOT> comes from
scripts/resolve-data-root.sh (never a guessed path). THALURA_CACHE_DIR overrides
the resolved cache dir for tests.
"""
import argparse
import hashlib
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


def _leading_token(s):
    parts = _norm(s).split(" ")
    return parts[0].lower() if parts and parts[0] else ""


def canonical_document_id(raw, registry_ids):
    """Map a freely-spelled document_id onto the registry's canonical id."""
    raw_n = _norm(raw)
    for rid in registry_ids:
        if _norm(rid).lower() == raw_n.lower():
            return rid
    best = None
    rl = raw_n.lower()
    for rid in registry_ids:
        ridl = _norm(rid).lower()
        if ridl in rl or rl in ridl:
            if best is None or len(ridl) > len(_norm(best).lower()):
                best = rid
    return best if best is not None else raw_n.lower()


def canonical_section_anchor(raw, page_map_sections):
    """Map a freely-spelled section_anchor onto the page-map's canonical anchor."""
    raw_n = _norm(raw)
    for anc in page_map_sections:
        if _norm(anc).lower() == raw_n.lower():
            return anc
    rtok = _leading_token(raw_n)
    best = None
    rl = raw_n.lower()
    for anc in page_map_sections:
        ancl = _norm(anc).lower()
        if rtok and _leading_token(anc) == rtok and (ancl in rl or rl in ancl):
            if best is None or len(ancl) > len(_norm(best).lower()):
                best = anc
    return best if best is not None else raw_n


def section_key(identity):
    """sha256 over the canonicalized (document_id, source_pdf_sha256, section_anchor) triple."""
    doc = canonical_document_id(identity["document_id"],
                                identity.get("registry_document_ids", []))
    anc = canonical_section_anchor(identity["section_anchor"],
                                   identity.get("page_map_sections", []))
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


def validate_digest(digest):
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
            if not isinstance(c.get("cited_text"), str):
                problems.append("claim %d missing cited_text" % i)
            if not isinstance(c.get("residual_flags"), list):
                problems.append("claim %d residual_flags must be a list" % i)
    hier = digest.get("hierarchy")
    if not isinstance(hier, dict) or not isinstance(hier.get("order"), list):
        problems.append("hierarchy.order must be a list")
    return problems


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
    fname = section_key(identity).split("sha256:")[-1] + ".json"
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


def cmd_put(identity, digest, cdir):
    problems = validate_digest(digest)
    if problems:
        sys.stderr.write("cache.py: reject — %s\n" % "; ".join(problems))
        return EXIT_REJECT
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
        sys.stdout.write(section_key(identity))
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


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
