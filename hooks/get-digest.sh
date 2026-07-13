#!/usr/bin/env bash
# Get-side regulation-cache hook. Best-effort optimization on
# PreToolUse-on-Agent (main-session firewall dispatch). On a derived-key HIT it
# ALLOWS the dispatch and rewrites the prompt via hookSpecificOutput.updatedInput
# to pre-load the cached digest ("return verbatim, do NOT open the PDF"). NEVER a
# deny (a deny risks a sandbox-boundary breach; and while a PreToolUse-on-Agent deny is
# now proven to veto in Cowork, that mechanism
# belongs to fanout-gate.sh, not to this cache optimizer). FAIL-OPEN:
# any miss / derivation failure / unresolved workspace / error -> emit {} (a normal
# read follows: one redundant read, NO correctness loss). The put-side carries
# correctness; this hook must never make things worse.
#
# Key discipline (Constraint 5): the section key is derived from the dispatch
# tool_input + the on-disk page-map/registry vocabulary and routed through
# cache.py's OWN canonicalization (derive-identity + get recompute the key from the
# section coordinates) — keyed on the SECTION, NEVER the teacher's query/topic.
# Keying on the query would shatter the cache (dev-9 relocated). The bash here never
# re-implements the sha256; cache.py is the single source.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_resolve.sh"

EVENT="$(cat)"                      # the PreToolUse event JSON from stdin
CAP="${THALURA_HOOK_TIMEOUT:-10}"   # script-level per-subprocess timeout (s)

allow() { printf '{}\n'; exit 0; }  # fail-open: allow, change nothing

PROOT="$(thalura_plugin_root)"
CACHE_PY="$PROOT/scripts/cache.py"
[ -f "$CACHE_PY" ] || allow

# Pull the dispatch cwd (python3 — robust to any payload shape).
event_cwd="$(printf '%s' "$EVENT" | python3 -c '
import json,sys
try: e=json.load(sys.stdin)
except Exception: print(""); sys.exit(0)
print(e.get("cwd","") if isinstance(e,dict) else "")' 2>/dev/null)"
[ -n "$event_cwd" ] || event_cwd="$PWD"

# Cache dir. THALURA_CACHE_DIR (tests/operator) is authoritative and is exactly what
# cache.py reads. Otherwise resolve via the unchanged resolver; unresolved ->
# no-op {} (never touch the sandbox — honors the sandbox-boundary and audit rules).
if [ -n "${THALURA_CACHE_DIR:-}" ]; then
  CDIR="$THALURA_CACHE_DIR"
else
  CDIR="$(thalura_cache_dir "$event_cwd")" || allow
  export THALURA_CACHE_DIR="$CDIR"
fi

# Page-map directory for the on-disk vocabulary. Test override THALURA_PAGEMAP_DIR;
# otherwise the shipped regulations tree under the plugin root.
PMDIR="${THALURA_PAGEMAP_DIR:-$PROOT/regulations}"

# Session id for the audit breadcrumb (python3 — robust to any payload shape).
SESSION="$(printf '%s' "$EVENT" | python3 -c '
import json,sys
try:
    e=json.load(sys.stdin); print(e.get("session_id","") if isinstance(e,dict) else "")
except Exception: print("")' 2>/dev/null)"
[ -n "$SESSION" ] || SESSION="nosession"

# One fail-open line per get-hook firing decision into the
# gitignored cache-dir .audit.log (internal-only, never teacher-visible),
# mirroring put-digest.sh's audit(). Records WHICH path fired so the live check
# reads the cause (get-hit / get-miss / mandate injected-or-not). The whole append
# runs in a subshell with stderr silenced, so an unwritable cache dir emits NOTHING.
AUDIT="$CDIR/.audit.log"
audit_get() {
  ( printf '%s session=%s get-hook %s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo now)" "$SESSION" "$*" \
      >> "$AUDIT" ) 2>/dev/null || true
}

# Portable per-subprocess timeout (timeout/gtimeout when present; else a watchdog —
# macOS bash 3.2 has neither). Returns the command's exit code, or 124 on timeout.
run_cap() {
  if command -v timeout >/dev/null 2>&1; then timeout "$CAP" "$@"; return $?; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$CAP" "$@"; return $?; fi
  "$@" &
  local cmd_pid=$!
  ( sleep "$CAP"; kill -TERM "$cmd_pid" 2>/dev/null; sleep 1; kill -KILL "$cmd_pid" 2>/dev/null ) &
  local wd_pid=$! rc=0
  wait "$cmd_pid" 2>/dev/null; rc=$?
  kill -TERM "$wd_pid" 2>/dev/null; wait "$wd_pid" 2>/dev/null || true
  return "$rc"
}

# --- Step 1: derive a complete --identity JSON from tool_input + on-disk page-maps.
# A miss/ambiguity prints NOTHING (-> fail-open). The key on the section is asserted
# here: the prompt's free text only selects WHICH (document, section) coordinates to
# look up; the query wording never enters the identity that cache.py hashes.
ID_FILE="$(mktemp 2>/dev/null)" || allow
EVENT_FILE="$(mktemp 2>/dev/null)" || { rm -f "$ID_FILE" 2>/dev/null; allow; }
printf '%s' "$EVENT" > "$EVENT_FILE" 2>/dev/null || { rm -f "$ID_FILE" "$EVENT_FILE" 2>/dev/null; allow; }
# The event is passed by FILE PATH (argv), not stdin: the heredoc IS this python's
# stdin (the script body). This derive step is NOT wrapped in run_cap — run_cap's
# watchdog fallback backgrounds the command, which severs the heredoc stdin a
# `python3 -` needs to read its script. The work here is bounded local file reads
# (a finite page-map glob + json.load), so it cannot hang on a network and needs no
# timeout. cache.py (which can in principle hang) stays under run_cap below.
python3 - "$PMDIR" "$EVENT_FILE" > "$ID_FILE" 2>/dev/null <<'PY'
import json, sys, os, glob

def norm(s):
    return " ".join(str(s).split()).strip()

# Read the PreToolUse event from the file path in argv; pull the dispatch prompt
# (the only free-text input).
try:
    ev = json.load(open(sys.argv[2], encoding="utf-8"))
except Exception:
    sys.exit(0)
if not isinstance(ev, dict):
    sys.exit(0)
ti = ev.get("tool_input") or {}
prompt = ti.get("prompt", "") if isinstance(ti, dict) else ""
if not isinstance(prompt, str) or not prompt.strip():
    sys.exit(0)
plow = prompt.lower()

pmdir = sys.argv[1]
files = sorted(glob.glob(os.path.join(pmdir, "**", "*.pagemap.json"), recursive=True))
if not files:
    sys.exit(0)

# Build the on-disk vocabulary: all document_ids (registry vocab) and, per page-map,
# its section anchors + freshness coordinates.
registry_ids = []
maps = []  # {document_id, sha, index_version, sections:[anchor,...]}
for f in files:
    try:
        d = json.load(open(f, encoding="utf-8"))
    except Exception:
        continue
    if not isinstance(d, dict):
        continue
    did = d.get("document_id")
    if not isinstance(did, str) or not did:
        continue
    sha = d.get("source_pdf_sha256")
    idxv = d.get("index_version")
    secs = []
    for s in (d.get("sections") or []):
        if isinstance(s, dict):
            a = s.get("section_anchor")
            if isinstance(a, str) and a.strip():
                secs.append(a)
    if did not in registry_ids:
        registry_ids.append(did)
    maps.append({"document_id": did, "sha": sha, "index_version": idxv, "sections": secs})

# Match the prompt to exactly one (document, section). A section anchor must appear
# (its leading token + the anchor's distinctive substring) in the prompt. Prefer the
# longest matching anchor (most specific). Document preference: a page-map whose
# document_id token appears in the prompt wins ties; otherwise the section match alone
# selects the map. Ambiguity across DIFFERENT (doc,section) coordinates -> bail (a
# normal read is safer than a wrong inject).
best = None  # (anchor_len, doc_token_match, document_id, anchor, sha, index_version)
ambiguous = False
for m in maps:
    did = m["document_id"]
    dtok_match = 1 if norm(did).lower() in plow else 0
    for anc in m["sections"]:
        al = norm(anc).lower()
        # Require the whole normalized anchor substring in the prompt for a confident
        # match (no fuzzy/partial — a wrong inject is worse than a redundant read).
        if al and al in plow:
            cand = (len(al), dtok_match, did, anc, m["sha"], m["index_version"])
            if best is None:
                best = cand
            else:
                # Same coordinates re-seen across maps -> not ambiguous.
                if (cand[2], cand[3]) == (best[2], best[3]):
                    pass
                elif cand[0] > best[0] or (cand[0] == best[0] and cand[1] > best[1]):
                    # A strictly better (longer / doc-confirmed) match supersedes.
                    if cand[0] == best[0] and cand[1] == best[1]:
                        ambiguous = True
                    best = cand
                elif cand[0] == best[0] and cand[1] == best[1]:
                    ambiguous = True

if best is None or ambiguous:
    sys.exit(0)
_, _, document_id, section_anchor, sha, index_version = best
if not isinstance(sha, str) or not sha or index_version is None:
    sys.exit(0)

# The page-map's source_pdf_sha256 is the freshness ground truth: in production the
# firewall reads this SAME sha (and index_version) from the page-map into the put-side
# identity, so the value carried here is byte-identical to what was stored, and
# cache.py's verbatim is_fresh compare holds. No prefix juggling — pass it through.
identity = {
    "key_components": {},
    "document_id": document_id,
    "section_anchor": section_anchor,
    "source_pdf_sha256": sha,
    "index_version": index_version,
    "registry_document_ids": registry_ids,
    "page_map_sections": sorted({a for m in maps for a in m["sections"]}),
}
sys.stdout.write(json.dumps(identity, ensure_ascii=False))
PY
derive_rc=$?
rm -f "$EVENT_FILE" 2>/dev/null
{ [ "$derive_rc" = 0 ] && [ -s "$ID_FILE" ]; } || { rm -f "$ID_FILE" 2>/dev/null; allow; }

# --- Step 2: route the key through cache.py (single source) — assert section-keying.
# derive-identity recomputes the sha over the section coordinates ONLY; if it can't,
# fail-open. (get also recomputes the key; deriving it here makes the section-key
# discipline explicit and guards against any future drift.)
run_cap python3 "$CACHE_PY" derive-identity --identity "$ID_FILE" >/dev/null 2>&1 \
  || { rm -f "$ID_FILE" 2>/dev/null; allow; }

# --- Step 3: cache.py get — exit 0 = HIT (+ entry on stdout) / 1 = MISS.
# Reaching here means the derive SUCCEEDED: the dispatch is firewall-shaped (it named
# a real (document, section) the page-map knows). That single fact splits the two
# spine paths below; a non-firewall / ambiguous dispatch already fail-opened above
# (the load-bearing false-positive guard — only a confident firewall-shape reaches here).
# The entry goes to a TEMP FILE and is read AFTER run_cap returns — NEVER through a
# command substitution: run_cap's no-`timeout`
# watchdog orphans a `sleep` that inherits a substitution pipe's write end and holds
# it open for ~CAP, stalling this hook ~10 s per dispatch on a host without
# timeout/gtimeout. Read via `cat` (a fresh child with no background grandchildren,
# so its substitution cannot be held); fail-open on any temp-file failure.
ENT_OUT="$(mktemp 2>/dev/null)" || { rm -f "$ID_FILE" 2>/dev/null; allow; }
run_cap python3 "$CACHE_PY" get --identity "$ID_FILE" >"$ENT_OUT" 2>/dev/null
get_rc=$?
ENTRY="$(cat "$ENT_OUT" 2>/dev/null)"
rm -f "$ENT_OUT" "$ID_FILE" 2>/dev/null

# The original dispatch prompt (the only free-text input) — used by both paths.
ORIG_PROMPT="$(printf '%s' "$EVENT" | python3 -c '
import json,sys
try: e=json.load(sys.stdin)
except Exception: print(""); sys.exit(0)
ti=e.get("tool_input") or {}
print(ti.get("prompt","") if isinstance(ti,dict) else "")' 2>/dev/null)"

# The FULL original tool_input as compact JSON. Both rewrite paths MERGE onto this
# so the Agent tool's REQUIRED params survive — above all `description`. The runtime
# validates updatedInput as the REPLACEMENT tool input, so a fresh {prompt:…} object
# drops `description` and the dispatch is rejected ("required parameter 'description'
# is missing"). Single-line (json.dumps escapes newlines) -> safe to pass as argv.
ORIG_TI="$(printf '%s' "$EVENT" | python3 -c '
import json,sys
try: e=json.load(sys.stdin)
except Exception: sys.stdout.write("{}"); sys.exit(0)
ti=e.get("tool_input")
sys.stdout.write(json.dumps(ti) if isinstance(ti,dict) else "{}")' 2>/dev/null)"
[ -n "$ORIG_TI" ] || ORIG_TI="{}"

if [ "$get_rc" = 0 ] && [ -n "$ENTRY" ]; then
  # --- Step 4a: HIT (unchanged cache-hit path) -> emit hookSpecificOutput.updatedInput.prompt.
  # The rewrite wraps the cached digest (the full entry, envelope-faithful) with an
  # explicit verbatim / do-NOT-open-the-PDF instruction and the original dispatch
  # intent, so the firewall (if it still runs) returns the digest without re-reading.
  audit_get "event=get-hit mandate=cache-digest"
  printf '%s' "$ENTRY" | python3 -c '
import json, sys
entry = sys.stdin.read()
orig = sys.argv[1] if len(sys.argv) > 1 else ""
try:
    ti = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    if not isinstance(ti, dict): ti = {}
except Exception:
    ti = {}
new_prompt = (
    "A cached, citation-verified regulation digest for the requested section is "
    "ALREADY available below. Return it VERBATIM as your digest. Do NOT open or read "
    "the PDF again — the cached digest is authoritative and freshness-checked.\n\n"
    "Original dispatch instruction (for context only — already satisfied by the cache):\n"
    + orig + "\n\n"
    "=== CACHED DIGEST (return verbatim) ===\n" + entry + "\n"
    "=== END CACHED DIGEST ===\n"
)
# Merge onto the original tool_input so required params (description) survive.
ui = dict(ti)
ui["prompt"] = new_prompt
out = {
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "updatedInput": ui,
    }
}
sys.stdout.write(json.dumps(out, ensure_ascii=False))
sys.stdout.write("\n")
' "$ORIG_PROMPT" "$ORIG_TI" 2>/dev/null || allow
  exit 0
fi

# --- Step 4b: firewall-shaped MISS (derive succeeded, no cached entry) -> THE SPINE.
# Inject the envelope MANDATE into the dispatch prompt via updatedInput.prompt,
# REGARDLESS of subagent_type. The mandate is the same literal G1 contract the named
# agent body carries; injecting it host-side closes emission even on the observed
# `general-purpose`-fallback path (the link that broke twice). Bonus (allowed to be
# ignored by the runtime): set subagent_type -> thalura:read-regulations. Idempotent:
# if the prompt ALREADY carries the mandate marker, do not prepend a second copy.
STATE_FILE="$(mktemp 2>/dev/null)" || { audit_get "event=get-miss mandate=mktemp-fail"; allow; }
HOOK_JSON="$(printf '%s' "$ORIG_PROMPT" | python3 -c '
import json, sys
orig = sys.stdin.read()
try:
    ti = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}
    if not isinstance(ti, dict): ti = {}
except Exception:
    ti = {}
MARKER = "<thalura-digest version=\"1\">"
if MARKER in orig:
    new_prompt = orig
    state = "already-present"
else:
    mandate = (
        "MANDATORY OUTPUT CONTRACT (non-skippable): Return your digest ONLY inside a "
        "<thalura-digest version=\"1\"> envelope, ONE envelope per resolved section, each "
        "wrapping exactly one fenced json block whose object is "
        "{ \"identity\": {…}, \"digest\": {…} }. The version lives on the tag attribute, "
        "never inside the digest JSON. identity carries the resolved per-section identity "
        "(key_components, document_id, section_anchor, source_pdf_sha256, index_version, "
        "plus the registry document_id list and the page-map section_anchor list). Emitting "
        "answer prose WITHOUT the per-section envelope is a pipeline violation of the same "
        "hard-gate weight as the firewall boundary itself.\n\n"
        "--- Original dispatch instruction ---\n"
    )
    new_prompt = mandate + orig
    state = "injected"
# Merge onto the original tool_input so required params (description) survive;
# override prompt + (bonus) subagent_type.
ui = dict(ti)
ui["prompt"] = new_prompt
ui["subagent_type"] = "thalura:read-regulations"
out = {
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "updatedInput": ui,
    },
}
# State -> stderr for the bash audit line; the hook JSON -> stdout.
sys.stderr.write(state)
sys.stdout.write(json.dumps(out, ensure_ascii=False)); sys.stdout.write("\n")
' "$ORIG_TI" 2> "$STATE_FILE")" || { rm -f "$STATE_FILE" 2>/dev/null; audit_get "event=get-miss mandate=emit-fail"; allow; }
STATE="$(cat "$STATE_FILE" 2>/dev/null || echo injected)"
rm -f "$STATE_FILE" 2>/dev/null
[ -n "$HOOK_JSON" ] || { audit_get "event=get-miss mandate=empty"; allow; }
audit_get "event=get-miss mandate=$STATE subagent_type=rewritten"
printf '%s\n' "$HOOK_JSON"
exit 0
