#!/usr/bin/env bash
# Put-side regulation-cache hook. Host-executed on the firewall's
# completion (PostToolUse-on-Agent primary + SubagentStop backup). Discriminates
# the firewall by the <thalura-digest> content envelope, forwards the
# firewall-echoed identity + digest to cache.py put — per resolved section.
# FAIL-OPEN: every error/non-firewall path exits 0 with nothing written. The
# firewall already returned its digest in-band before this fires, so no outcome
# here can retract the answer.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_resolve.sh"

EVENT="$(cat)"                      # the hook event JSON from stdin
CAP="${THALURA_HOOK_TIMEOUT:-10}"   # script-level per-subprocess timeout (s)

emit_noop() { printf '{}\n'; exit 0; }   # fail-open: allow, change nothing

PROOT="$(thalura_plugin_root)"
CACHE_PY="$PROOT/scripts/cache.py"
PARSER="$PROOT/hooks/parse_envelopes.py"
[ -f "$CACHE_PY" ] || emit_noop
[ -f "$PARSER" ]   || emit_noop

# Pull cwd + session_id (python3 — robust to any payload shape).
event_cwd="$(printf '%s' "$EVENT" | python3 -c '
import json,sys
try: e=json.load(sys.stdin)
except Exception: print(""); sys.exit(0)
print(e.get("cwd","") if isinstance(e,dict) else "")' 2>/dev/null)"
[ -n "$event_cwd" ] || event_cwd="$PWD"

# Cache dir. THALURA_CACHE_DIR (set by tests, or by an operator) is authoritative
# and is exactly what cache.py reads, so the hook's dedup/audit tree and cache.py's
# writes stay in lockstep. Otherwise resolve via the unchanged resolver and export
# the result so cache.py lands in the same resolved place.
if [ -n "${THALURA_CACHE_DIR:-}" ]; then
  CDIR="$THALURA_CACHE_DIR"
else
  CDIR="$(thalura_cache_dir "$event_cwd")" || emit_noop   # unresolved -> no-op
  export THALURA_CACHE_DIR="$CDIR"
fi

# --- The SHIPPED PACK is a read-only source (the long note lives in _resolve.sh), so
# a cache root inside it ends this firing here, before anything is created.
#
# ONE GUARD, THREE WRITES. This is the only hook that would write pack-SHAPED output:
# below it creates the dedup tree, appends the audit line, and hands cache.py a put
# that lands a <document_id>/<key>.json — an entry indistinguishable, by shape, from a
# generated one. A shape check downstream could never tell those apart, which is
# precisely why the refusal has to happen here rather than being left to one.
#
# FAIL-OPEN DIRECTION: toward a MISS. The digest is not persisted, so the next read of
# that section reads it again — one redundant read, never a wrong or missing answer.
# And nothing is retracted: as this file's header says, the firewall already returned
# its digest in-band before this hook fires, so no outcome here can reach the caller.
#
# It is the DEV-TIME GENERATOR, not this hook, that legitimately writes the pack, and
# it does so through cache.py directly. Guarding cache.py would break generation; the
# boundary is that the RUNTIME treats the pack as read-only.
if thalura_is_shipped_pack_path "$CDIR"; then emit_noop; fi

SESSION="$(printf '%s' "$EVENT" | python3 -c '
import json,sys
try:
    e=json.load(sys.stdin); print(e.get("session_id","") if isinstance(e,dict) else "")
except Exception: print("")' 2>/dev/null)"
[ -n "$SESSION" ] || SESSION="nosession"

# Extract every envelope -> one TSV line per section:
#   <section_key>\t<identity_tmpfile>\t<digest_tmpfile>
# The parser writes the per-section identity/digest temp files under a single
# per-firing temp dir (parse_envelopes.py mkdtemp). It cannot remove that dir
# itself (we read the files after it exits), so the hook owns the cleanup: capture
# the dir from the first emitted path and rm -rf it once the loop is done.
SECTIONS="$(printf '%s' "$EVENT" | python3 "$PARSER" 2>/dev/null)" || emit_noop
[ -n "$SECTIONS" ] || emit_noop   # no envelope -> not the firewall -> no-op

ENV_TMPDIR="$(printf '%s\n' "$SECTIONS" | head -n1 | cut -f2)"
ENV_TMPDIR="$(dirname "$ENV_TMPDIR" 2>/dev/null)"
cleanup_env_tmpdir() {
  case "$ENV_TMPDIR" in
    */thalura-env-*) rm -rf "$ENV_TMPDIR" 2>/dev/null || true ;;
  esac
}

DEDUP_DIR="$CDIR/.audit/dedup"
mkdir -p "$DEDUP_DIR" 2>/dev/null || true
AUDIT="$CDIR/.audit.log"

# Best-effort structured breadcrumb (one line per firing decision). The whole
# append runs in a subshell with stderr silenced, so a failed redirect-open (e.g.
# an unwritable cache dir) emits NOTHING to the teacher's view — fail-open.
audit() {
  ( printf '%s session=%s %s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo now)" "$SESSION" "$*" \
      >> "$AUDIT" ) 2>/dev/null || true
}

# Portable per-subprocess timeout. Uses timeout/gtimeout when present; otherwise a
# background-pid + watchdog (macOS bash 3.2 has neither). Returns the command's
# exit code, or 124 on timeout.
run_cap() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$CAP" "$@"; return $?
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$CAP" "$@"; return $?
  fi
  # Fallback watchdog: run in background, kill if it overruns the cap.
  "$@" &
  local cmd_pid=$!
  (
    sleep "$CAP"
    kill -TERM "$cmd_pid" 2>/dev/null
    sleep 1
    kill -KILL "$cmd_pid" 2>/dev/null
  ) &
  local wd_pid=$!
  local rc=0
  wait "$cmd_pid" 2>/dev/null; rc=$?
  kill -TERM "$wd_pid" 2>/dev/null
  wait "$wd_pid" 2>/dev/null || true
  return "$rc"
}

# Per-section loop. Every step swallows errors and continues; never exits non-zero.
printf '%s\n' "$SECTIONS" | while IFS="$(printf '\t')" read -r section_key id_file dg_file; do
  [ -n "$section_key" ] && [ -f "$id_file" ] && [ -f "$dg_file" ] || continue

  # Dedup on (session_id, section_key): the both-events overlap writes once.
  marker_name="$(printf '%s' "${SESSION}_${section_key}" | tr -c 'A-Za-z0-9_.-' '_')"
  marker="$DEDUP_DIR/$marker_name"
  if [ -e "$marker" ]; then
    audit "event=dedup key=$section_key"
    continue
  fi

  # Keep the REASON, not only the code. A schema rejection names the offending
  # field on stderr; discarding it leaves an audit line that says a write was
  # skipped without saying why, and the cost of a refused put recurs every
  # session. Bounded to one line and 200 chars: evidence, never a payload.
  put_err="$id_file.err"
  run_cap python3 "$CACHE_PY" put --identity "$id_file" --digest "$dg_file" \
    >/dev/null 2>"$put_err"
  put_rc=$?

  if [ "$put_rc" = 0 ]; then
    # Put-then-get self-confirm: catch a put that "succeeded" but landed un-gettable.
    run_cap python3 "$CACHE_PY" get --identity "$id_file" >/dev/null 2>&1
    get_rc=$?
    if [ "$get_rc" = 0 ]; then
      audit "event=put key=$section_key result=confirmed"
    else
      audit "event=put key=$section_key result=self-confirm-miss get_rc=$get_rc"
    fi
    : > "$marker" 2>/dev/null || true   # mark this (session, section) done
  else
    # put_rc 3 = schema reject (malformed backstop); 124/143 = timeout (timeout(1)
    # vs the SIGTERM watchdog fallback); other = error. Any non-zero -> no write.
    put_why="$(awk 'NR==1 { line=$0; sub(/^cache\.py: (reject)? *— */, "", line); print substr(line, 1, 200); exit }' \
                 "$put_err" 2>/dev/null)"
    if [ -n "$put_why" ]; then
      audit "event=skip key=$section_key put_rc=$put_rc reason=$put_why"
    else
      audit "event=skip key=$section_key put_rc=$put_rc"
    fi
    # No dedup marker on a failed put: a retry on the backup event may still succeed.
  fi
  rm -f "$put_err" 2>/dev/null || true
done

cleanup_env_tmpdir
emit_noop
