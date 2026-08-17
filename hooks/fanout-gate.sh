#!/usr/bin/env bash
# fanout-gate.sh — the firewall-dispatch DENY gate. BOUND (a PreToolUse-on-Agent deny
# is proven to veto in Cowork).
#
# This is the structurally-guaranteed enforcement layer for the dispatcher-side
# contract on a PreToolUse-on-Agent firewall dispatch (subagent_type
# thalura:read-regulations). ONE deny condition, returning a corrective,
# re-dispatch-prescribing reason BEFORE any read cost is paid:
#
#   1. FAN-OUT   — one reader handed MORE THAN ONE document (>=2 first-line
#                  `document_id:` keys in the dispatch prompt).
#
# THIS FILE holds no concurrency/wave state, and never has. A fixed-window dispatch
# counter was tried here once and dropped: with no completion signal to decrement it, a
# finished reader still held its slot, so a legitimate follow-up wave — dispatched
# exactly as the deny reason instructed — was itself denied, and zero-cost cache hits
# burned slots. A cap that can deny a NEEDED read is worse than no cap. A correct one
# needs a completion signal (a SubagentStart/SubagentStop-driven decrement) plus a
# stale-slot reaper — bookkeeping this file was never built to carry. That bound now
# lives in a sibling hook, which claims a slot per dispatch and, at capacity, defers a
# dispatch to a following wave rather than denying it outright. Nothing below counts how
# many readers are in flight; the deny condition this file checks is unrelated to that
# count and unchanged by whatever the sibling hook decides.
#
# NO CONSENT GATE LIVES HERE. An earlier revision also denied any dispatch that did not
# carry a `confirmed: yes` key — a structural "the teacher agreed to this read" check.
# That gate is GONE: regulations are read without asking first. What survives is
# TRANSPARENCY, not consent — the dispatcher still names each document it is about to
# read in teacher-recognizable terms and still records per-document progress, but that is
# announcement prose, not a dispatch-shape key, and nothing here checks for one. Do not
# reintroduce a confirmation key check in this file.
#
# BOUND in hooks/hooks.json (PreToolUse-on-Agent, co-bound with get-digest.sh), only
# after a Cowork-evidenced veto proved the deny lands (dispatch stopped twice). Both
# deny channels are functional; DENY_CHANNEL ships as "json" per that evidence. The
# co-bound hooks run independently on the same event: get-digest.sh denies the dispatch
# on a cache HIT and hands the digest straight back, so no PDF is reopened and no reader
# ever spawns.
#
# FAIL-OPEN doctrine (shipped hooks.json): EVERY error path — malformed stdin, missing
# fields, missing python3, timeout, parse failure, an unusable state file — is a no-op
# ({} exit 0). A misbehaving gate never blocks, stalls, or degrades a teacher session;
# the reader's read-all/drop-none/flag degrade rule remains the correctness backstop.
# Equally active/harmless on the CLI runtime.
set -u

# --- Deny channel (RQ-4). A single top-of-script constant; both branches are
# functional. Ships as "json" (primary: PreToolUse hookSpecificOutput +
# permissionDecision:"deny" + reason). A follow-up may flip this to "exit2"
# (stderr + exit 2) if that proves the channel that vetoes-and-delivers.
DENY_CHANNEL="json"                 # "json" | "exit2"

# The corrective reason. Single-quoted: the backticks and the em-dashes are
# literal. json.dumps escapes them correctly for the json channel.
# shellcheck disable=SC2016  # the backticks are literal markdown code-spans, NOT command substitution — single-quoting is intentional.
REASON='one document per reader — re-dispatch as N parallel `thalura:read-regulations` Agent calls in ONE message, one `document_id:` line per call.'

EVENT="$(cat)"                      # the PreToolUse event JSON from stdin
CAP="${THALURA_HOOK_TIMEOUT:-10}"   # script-level per-subprocess timeout (s)

allow() { printf '{}\n'; exit 0; }  # fail-open: allow, change nothing

# --- Reader-slot tombstone. Written on this gate's deny path — on EITHER deny channel,
# because the write sits in deny() ahead of the channel branch — and NEVER a precondition
# for it.
#
# A sibling hook bounds how many regulation readers run at once by claiming a
# provisional slot on this SAME PreToolUse event. The hooks run concurrently and none is
# shown another's decision, so when this gate vetoes a dispatch, the sibling has claimed
# (or is about to claim) a slot for a reader that will now never spawn: no subagent
# starts, none stops, and the slot sits phantom until its TTL expires. A tombstone naming
# the dispatch just vetoed lets the sibling release that slot on its next pass.
#
# It matters MORE here than on a cache veto. A fan-out-shaped deny is answered by the
# dispatcher re-sending the same documents correctly, as N separate calls — which claim N
# MORE slots. Without a tombstone one malformed wave can hold the entire ledger and then
# defer its own corrected, legitimate re-dispatch for a full TTL: exactly the "a needed
# read is refused" failure the bound exists to prevent, arriving from behind.
#
# The name is a fingerprint of the dispatch — the flattened session id plus the verbatim
# dispatch prompt — derived here EXACTLY as the sibling hooks derive it from the same
# event. That shared derivation is the entire contract: the hooks agree on a name without
# any of them observing another. Hook ORDER is therefore irrelevant; neither the tombstone
# write nor the slot claim inspects the other, and whichever lands second simply completes
# the pair on disk. This derivation must never be "tidied" on one side alone.
#
# FAIL-OPEN, absolutely — this file's doctrine, restated for a side effect: the whole body
# runs in a subshell whose every failure and every byte of output is swallowed, and
# nothing downstream tests its result. There is NO path on which a failed, skipped or
# impossible tombstone write changes, delays, weakens or blocks a deny — the deny that
# follows is byte-identical either way. An unresolved workspace simply means no tombstone,
# and the slot falls back to expiring at its TTL, which is exactly the behaviour that
# shipped before this existed.
reader_tombstone() {
  ( # Cache dir, resolved exactly as the sibling hooks resolve it. THALURA_CACHE_DIR
    # (tests / operator) is authoritative; otherwise the shared resolver, fed the event
    # cwd. The resolver is sourced HERE, inside the subshell, so this gate keeps its
    # no-sourced-siblings property on every other path: an absent resolver costs a
    # tombstone, never a decision. Never write outside a resolved data root.
    #
    # SOURCED ABOVE THE BRANCH, not inside the `else` arm where it used to sit. The
    # pack check below needs the helper on BOTH arms — and the override arm is the one
    # that can actually name the pack, so guarding only the resolver arm would guard
    # the path that cannot reach it and leave the path that can. The property the
    # comment above states is untouched: the source is still inside this subshell, on
    # the tombstone path only, and an absent resolver still costs a tombstone rather
    # than a decision. The one behaviour that moves is that an override with no
    # resolver present now writes no tombstone either — the same tolerable cost,
    # reached one way further along.
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 0
    [ -f "$here/_resolve.sh" ] || exit 0
    # shellcheck source=/dev/null
    . "$here/_resolve.sh" || exit 0
    if [ -n "${THALURA_CACHE_DIR:-}" ]; then
      cdir="$THALURA_CACHE_DIR"
    else
      ecwd="$(printf '%s' "$EVENT" | python3 -c '
import json,sys
def emit(s): sys.stdout.buffer.write((s + "\n").encode("utf-8", "replace"))
try: e=json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
except Exception: emit(""); sys.exit(0)
emit(e.get("cwd","") if isinstance(e,dict) and isinstance(e.get("cwd"),str) else "")' 2>/dev/null)"
      [ -n "$ecwd" ] || ecwd="$PWD"
      cdir="$(thalura_cache_dir "$ecwd")" || exit 0
    fi
    [ -n "$cdir" ] || exit 0
    # The SHIPPED PACK is a read-only source (the long note lives in _resolve.sh) and
    # takes no tombstone. Direction: exactly the one the paragraph above this function
    # already fixes for every other way the tombstone can be skipped — the slot falls
    # back to expiring at its TTL, and the deny that follows is byte-identical.
    if thalura_is_shipped_pack_path "$cdir"; then exit 0; fi
    tdir="$cdir/.readers"

    # Session id for the breadcrumb line only — it is NOT what names the file. Read and
    # written as explicit UTF-8 bytes, so an umlaut in the id cannot raise on emit under
    # a non-UTF-8 locale and cost this gate its marker.
    sess_id="$(printf '%s' "$EVENT" | python3 -c '
import json,sys
def emit(s): sys.stdout.buffer.write((s + "\n").encode("utf-8", "replace"))
try:
    e=json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
    emit(e.get("session_id","") if isinstance(e,dict) and isinstance(e.get("session_id"),str) else "")
except Exception: emit("")' 2>/dev/null)"
    [ -n "$sess_id" ] || sess_id="nosession"

    # Same normalization on every side: whitespace-STRIPPED, length-capped session id with
    # the same absent-value fallback, then the prompt verbatim.
    #
    # LOCALE-INDEPENDENT, BYTE-FOR-BYTE, AND IDENTICAL ON EVERY SIDE. The event arrives as
    # bytes and is decoded UTF-8 with an explicit error handler — never through the
    # interpreter default, which follows the ambient locale a hook happens to inherit.
    # Under a non-UTF-8 one the implicit path decodes the very same event into a DIFFERENT
    # string, so the digest below would differ from the one the queue derives from the
    # same bytes and the marker written here could never be matched — the handshake would
    # go inert while every hook still looked correct. The prompts this gate sees are German
    # regulation text, so section signs, umlauts and em dashes are the normal case.
    fp="$(printf '%s' "$EVENT" | python3 -c '
import json, sys, hashlib
try:
    ev = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
except Exception:
    sys.exit(0)
if not isinstance(ev, dict):
    sys.exit(0)
ti = ev.get("tool_input")
if not isinstance(ti, dict):
    sys.exit(0)
prompt = ti.get("prompt")
if not isinstance(prompt, str):
    sys.exit(0)
def flat(v, n=200):
    if not isinstance(v, str):
        return ""
    return "".join(v.split())[:n]
sess = flat(ev.get("session_id")) or "nosession"
h = hashlib.sha256()
h.update(sess.encode("utf-8", "replace"))
h.update(b"\n")
h.update(prompt.encode("utf-8", "replace"))
sys.stdout.write(h.hexdigest()[:32])
' 2>/dev/null)" || fp=""
    # Lowercase hex only — the value becomes a filename.
    case "$fp" in ''|*[!0-9a-f]*) exit 0 ;; esac

    mkdir -p "$tdir" 2>/dev/null || exit 0
    [ -d "$tdir" ] || exit 0

    # Age out any tombstone the sibling never consumed, on the same clock the slot it
    # names would have used and on the same portable primitives the sibling reaps with
    # (no stat, no -delete, no -printf). A tombstone that is never collected is a slow
    # leak in the teacher's workspace, so this sweep runs on every write — the siblings
    # sweep too, and any one of them alone is sufficient.
    # Defaults to the SAME value the slot ledger uses for a provisional slot. A tombstone
    # must outlive the slot it exists to free: sweep it sooner and a quiet session
    # collects the marker before any claim has swept the pair, so the slot falls back to
    # ageing out and the fast path is silently lost. Equal is the floor, not a coincidence.
    ptl="${THALURA_READER_PROV_TTL:-300}"
    case "$ptl" in ''|*[!0-9]*) ptl=300 ;; esac
    pmin=$((ptl / 60)); [ "$pmin" -ge 1 ] || pmin=1
    find "$tdir" -type f -name 'tomb-*' -mmin "+$pmin" -exec rm -f {} + 2>/dev/null

    # Exclusive create: a tombstone already standing for this dispatch IS the outcome
    # wanted, so EEXIST is success and not an error worth a second thought.
    ( set -C; printf 'tomb %s session=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo now)" "$sess_id" \
        > "$tdir/tomb-$fp" ) 2>/dev/null
    exit 0
  ) >/dev/null 2>&1 || true
  return 0
}

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

# --- Emit a deny on the configured channel, then exit. $1 = the corrective reason.
# json channel builds the decision object via python3 for correct escaping; on any
# failure it degrades to the exit-2/stderr channel (still a deny, never a silent allow
# once a deny condition has been positively established).
deny() {
  local reason="$1"
  # Best-effort side effect, deliberately BEFORE the emit and deliberately unchecked: the
  # vetoed dispatch's reader slot is released early rather than at its TTL. This function
  # is reached ONLY from the positively-established deny condition below, and the write
  # sits AHEAD of the channel branch, so every deny — json or exit2 — gets a tombstone and
  # no allow path can ever write one. Every failure inside is swallowed; nothing after it
  # depends on it, and the emitted reason is unchanged either way. See reader_tombstone().
  reader_tombstone
  if [ "$DENY_CHANNEL" = "exit2" ]; then
    printf '%s\n' "$reason" >&2
    exit 2
  fi
  # THE REASON IS A NON-ASCII PAYLOAD CARRIED THROUGH ARGV, and that is a THIRD
  # channel — neither the -c source-ASCII guard (which scans the SPAN, and the em
  # dash sits in the ARGUMENT after it) nor the non-UTF-8 CI leg (which covers
  # STREAMS) looks at it. CPython decodes argv with the LOCALE-DEPENDENT FILESYSTEM
  # encoding: macOS forces utf-8 there whatever the locale, so this is structurally
  # invisible on that platform, but a Linux host under LC_ALL=C gives fs=ascii and
  # $REASON's em dash arrives SURROGATE-ESCAPED. json.dumps(ensure_ascii=True) then
  # serialises the lone surrogates happily -- the emit succeeds at rc=0 with empty
  # stderr and the dispatcher is handed a corrupted deny reason, i.e. the corrective
  # instruction this gate exists to deliver, mangled, with nothing anywhere reporting
  # a fault. os.fsencode() round-trips surrogateescape back to the original bytes and
  # the decode is then ours and explicit; on macOS the whole line is a no-op.
  # errors="replace" keeps the fail-open direction: a smudged reason, never a raise.
  python3 -c '
import json, os, sys
reason = os.fsencode(sys.argv[1]).decode("utf-8", "replace")
out = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}}
sys.stdout.write(json.dumps(out))
sys.stdout.write("\n")
' "$reason" 2>/dev/null && exit 0
  # json emit failed (e.g. python3 vanished mid-run) -> fall back to the exit-2 channel.
  printf '%s\n' "$reason" >&2
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
    fh = open(sys.argv[1], "rb")
    raw = fh.read()
    fh.close()
    ev = json.loads(raw.decode("utf-8", "replace"))
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
# An absent / non-string prompt is a MALFORMED PAYLOAD, never "an empty prompt".
# Coercing it to "" would let a runtime payload-shape change (a prompt arriving as a
# structured block list, say) be scored as a well-formed dispatch this parser had simply
# read as empty, which is exactly the guessing the fail-open doctrine forbids. Print
# nothing and exit 0 instead; the bash then reads an empty COUNT and fail-opens through
# the non-numeric guard below.
# (NB: this parser is a single-quoted shell string: no apostrophes and no backticks here.
# ASCII ONLY, INCLUDING THE COMMENTS. Python decodes a -c argument with the ambient
# locale codec, so one non-ASCII character anywhere in this source raises a SyntaxError
# under a non-UTF-8 locale, the parser writes nothing, and this gate fail-opens EVERY
# dispatch on such a host while still looking correct. Write the character as an escape
# in a string literal when it is genuinely needed; never as a literal byte.)
prompt = ti.get("prompt", None)
if not isinstance(prompt, str):
    sys.exit(0)
pat = re.compile(r"\s*document_id:\s*\S")
n = 0
for line in prompt.split("\n"):
    if pat.match(line):
        n += 1
out = "%d\n%s\n" % (n, st)
sys.stdout.buffer.write(out.encode("utf-8", "replace"))
' "$EVENT_FILE" > "$OUT_FILE" 2>/dev/null
rm -f "$EVENT_FILE" 2>/dev/null

# Read the parser result: line 1 = key count, line 2 = subagent_type. The validated
# NUMERIC field comes FIRST so a hypothetical newline-bearing subagent_type desyncs the
# reads toward the numeric guard below (non-numeric -> allow, fail-open) instead of ever
# inflating the count into a spurious deny. Any parse failure (empty output on malformed
# stdin / missing fields / missing python3 / timeout) leaves these empty -> fail-open
# allow.
SUBAGENT=""; COUNT=""
{ read -r COUNT; read -r SUBAGENT; } < "$OUT_FILE" 2>/dev/null
rm -f "$OUT_FILE" 2>/dev/null

# Non-numeric / empty count -> parse error -> allow (fail-open).
case "$COUNT" in
  ''|*[!0-9]*) allow ;;
esac

# Only the firewall reader's dispatches are in scope; anything else -> allow.
[ "$SUBAGENT" = "thalura:read-regulations" ] || allow

# --- Deny 1 (fan-out) — and the ONLY deny in this file. The conservative, unambiguous
# signal: >=2 first-line document_id: keys = one reader handed many documents -> DENY.
# Count 0 or 1 -> fall through (RQ-1: a zero-key dispatch falls back to the reader's
# provenance assertion; no fuzzy-prose deny).
if [ "$COUNT" -ge 2 ]; then
  deny "$REASON"
fi

# No further gate IN THIS FILE. A single-document dispatch that clears the deny above is
# allowed here, whatever else is in flight — this file tracks no concurrency and is not
# where that question is answered. A sibling hook may still turn the same dispatch back
# for a later wave at its own bound; that is its decision to make, not this gate's, and
# does not change what this file allows.
allow
