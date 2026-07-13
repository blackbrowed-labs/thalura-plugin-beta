#!/usr/bin/env bash
# fanout-gate.sh — the fan-out DENY gate. BOUND (a PreToolUse-on-Agent deny is proven
# to veto in Cowork).
#
# This is the structurally-guaranteed enforcement layer for the dispatcher-side
# fan-out contract: on a PreToolUse-on-Agent firewall dispatch that hands MORE THAN
# ONE document to a single thalura:read-regulations reader (>=2 first-line
# `document_id:` keys in the dispatch prompt), it DENIES the tool call and returns
# a corrective, re-dispatch-prescribing reason — the veto lands BEFORE any read cost
# is paid, and the exact correct fan-out shape travels in the rejection.
#
# BOUND in hooks/hooks.json (PreToolUse-on-Agent, co-bound with get-digest.sh), only
# after a Cowork-evidenced veto proved the deny lands (dispatch stopped twice). Both
# deny channels are functional; DENY_CHANNEL ships as "json" per that evidence.
#
# FAIL-OPEN doctrine (shipped hooks.json): EVERY error path — malformed stdin, missing
# fields, missing python3, timeout, parse failure — is a no-op ({} exit 0). A
# misbehaving gate never blocks, stalls, or degrades a teacher session; the reader's
# read-all/drop-none/flag degrade rule remains the correctness backstop. This gate is
# a pure PERFORMANCE guard (it converts a serial degrade into a corrected fan-out).
# Equally active/harmless on the CLI runtime.
set -u

# --- Deny channel (RQ-4). A single top-of-script constant; both branches are
# functional. Ships as "json" (primary: PreToolUse hookSpecificOutput +
# permissionDecision:"deny" + reason). A follow-up may flip this to "exit2"
# (stderr + exit 2) if that proves the channel that vetoes-and-delivers.
DENY_CHANNEL="json"                 # "json" | "exit2"

# The spec-verbatim corrective reason. Single-quoted: the backticks and
# the em-dash are literal. json.dumps escapes it correctly for the json channel.
# shellcheck disable=SC2016  # the backticks are literal markdown code-spans, NOT command substitution — single-quoting is intentional.
REASON='one document per reader — re-dispatch as N parallel `thalura:read-regulations` Agent calls in ONE message, one `document_id:` line per call.'

EVENT="$(cat)"                      # the PreToolUse event JSON from stdin
CAP="${THALURA_HOOK_TIMEOUT:-10}"   # script-level per-subprocess timeout (s)

allow() { printf '{}\n'; exit 0; }  # fail-open: allow, change nothing

# Portable per-subprocess timeout (timeout/gtimeout when present; else a watchdog —
# macOS bash 3.2 has neither). Returns the command's exit code, or non-zero on kill.
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

# --- Emit a deny on the configured channel, then exit. json channel builds the
# decision object via python3 for correct escaping; on any failure it degrades to the
# exit-2/stderr channel (still a deny, never a silent allow on the >=2-key path).
deny() {
  if [ "$DENY_CHANNEL" = "exit2" ]; then
    printf '%s\n' "$REASON" >&2
    exit 2
  fi
  python3 -c '
import json, sys
reason = sys.argv[1]
out = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}}
sys.stdout.write(json.dumps(out))
sys.stdout.write("\n")
' "$REASON" 2>/dev/null && exit 0
  # json emit failed (e.g. python3 vanished mid-run) -> fall back to the exit-2 channel.
  printf '%s\n' "$REASON" >&2
  exit 2
}

# --- Parse: extract subagent_type + count first-line document_id: keys. The event is
# passed by FILE PATH (argv), and the parser is `python3 -c` code (argv, NOT a heredoc)
# so it survives run_cap's watchdog fallback, which backgrounds the command and would
# sever a heredoc's stdin. Output goes to a TEMP FILE read AFTER run_cap returns, NEVER
# through a command substitution around run_cap (avoids the orphaned-sleep stall).
EVENT_FILE="$(mktemp 2>/dev/null)" || allow
printf '%s' "$EVENT" > "$EVENT_FILE" 2>/dev/null || { rm -f "$EVENT_FILE" 2>/dev/null; allow; }
OUT_FILE="$(mktemp 2>/dev/null)" || { rm -f "$EVENT_FILE" 2>/dev/null; allow; }

# Line-anchored count (^[[:space:]]*document_id:[[:space:]]*[^[:space:]]): a mid-line
# `document_id` mention (hierarchy context naming other documents) does NOT count (RQ-2).
run_cap python3 -c '
import json, sys, re
try:
    ev = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(0)
if not isinstance(ev, dict):
    sys.exit(0)
ti = ev.get("tool_input")
if not isinstance(ti, dict):
    ti = {}
st = ti.get("subagent_type", "")
if not isinstance(st, str):
    st = ""
prompt = ti.get("prompt", "")
if not isinstance(prompt, str):
    prompt = ""
pat = re.compile(r"\s*document_id:\s*\S")
n = 0
for line in prompt.split("\n"):
    if pat.match(line):
        n += 1
sys.stdout.write("%d\n%s\n" % (n, st))
' "$EVENT_FILE" > "$OUT_FILE" 2>/dev/null
rm -f "$EVENT_FILE" 2>/dev/null

# Read the parser result: line 1 = key count, line 2 = subagent_type. The validated
# NUMERIC field comes FIRST so a hypothetical newline-bearing subagent_type desyncs
# the reads toward the numeric guard below (non-numeric -> allow, fail-open) instead
# of ever inflating the count into a spurious deny. Any parse failure (empty output
# on malformed stdin / missing fields / missing python3 / timeout) leaves these
# empty -> fail-open allow.
SUBAGENT=""; COUNT=""
{ read -r COUNT; read -r SUBAGENT; } < "$OUT_FILE" 2>/dev/null
rm -f "$OUT_FILE" 2>/dev/null

# Non-numeric / empty count -> parse error -> allow (fail-open).
case "$COUNT" in
  ''|*[!0-9]*) allow ;;
esac

# Only the firewall reader's dispatches are in scope; anything else -> allow.
[ "$SUBAGENT" = "thalura:read-regulations" ] || allow

# The conservative, unambiguous signal: >=2 first-line document_id: keys = one reader
# handed many documents -> DENY. Count 0 or 1 -> allow (RQ-1: a zero-key dispatch falls
# back to the reader's provenance assertion; no fuzzy-prose deny).
if [ "$COUNT" -ge 2 ]; then
  deny
fi
allow
