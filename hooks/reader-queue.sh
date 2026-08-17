#!/usr/bin/env bash
# reader-queue.sh — the concurrent-reader bound, built as a QUEUE, never as a refusal.
#
# One script, three event branches, discriminated on hook_event_name. TWO of them are
# bound by the manifest; the third is implemented and tested but deliberately NOT bound
# (see the compatibility note further down — binding it would disable every hook this
# plugin ships on older hosts):
#
#   PreToolUse (matcher Agent)  -> BOUND. Reap stale slots, then CLAIM one or DEFER.
#   SubagentStop (matcher-less) -> BOUND. RELEASE a slot; the reader is discriminated
#                                  inside this script rather than by a matcher.
#   SubagentStart               -> NOT BOUND, dormant. Would CONFIRM a provisional slot,
#                                  promoting it to live and stamping the reader's
#                                  agent_id. Kept working so that raising the minimum
#                                  supported host re-enables it by adding a binding and
#                                  changing no code.
#
# WHY A QUEUE AND NOT A CAP
# A fixed-window dispatch counter was tried in the fan-out gate and REVERTED. It had no
# completion signal, so a finished reader kept holding its slot and a legitimate
# follow-up wave — dispatched exactly as the previous deny reason had instructed — was
# itself denied; zero-cost cache hits burned slots too. A cap that can deny a NEEDED
# read is worse than no cap at all. What that revert established is not "no bound", but
# "no bound without a completion signal". The runtime now provides two: SubagentStart
# says a reader really started, SubagentStop says it finished. This file is the same
# bound rebuilt on top of them, and — the load-bearing difference — at capacity it does
# not refuse a document, it DEFERS it with an explicit instruction to re-dispatch it in
# the next wave. Nothing is ever dropped; a document waits, at worst, one wave.
#
# THE INVARIANT (the rule every choice here is measured against)
#   Every tuning error in this design must resolve toward MORE concurrency than
#   intended, never toward a read that does not happen.
# Concretely: a too-short TTL over-dispatches (that is today's shipped behaviour —
# survivable); a too-long TTL costs a wave round-trip (annoying, never lossy); a missed
# release costs a wave round-trip; a bad env value falls back to the default; every
# error path allows. There is no reachable state in which a needed document is refused
# rather than deferred. This is the fail-open doctrine of the other shipped hooks,
# restated for a hook that carries STATE.
#
# FAIL-OPEN, exhaustively: malformed stdin, absent tool_input, a missing or non-string
# prompt, a missing python3, a parse timeout, an unresolved workspace, an unwritable or
# uncreatable slot directory, a corrupt slot line, an unrecognised event — every one of
# them emits {} and claims nothing. The bound is only ever enforced on POSITIVE evidence
# that every slot is genuinely held: a create that fails while its slot file does not
# exist is read as an environment fault, not as capacity, and allows.
#
# WHY THE ALLOW IS BYTE-EXACTLY {} — DO NOT "CLEAN THIS UP"
# allow() emits {} and never permissionDecision:"allow". How the runtime aggregates
# conflicting decisions from hooks co-bound on ONE event is undocumented. The only shape
# evidenced in the hosted runtime is {} from one hook alongside a deny from its sibling
# yielding the deny — which is exactly what the digest-cache HIT veto and the fan-out
# deny rely on. An explicit "allow" is a DIFFERENT, untested aggregation, and if it were
# to win it would override the sibling HIT veto and resurrect the reader spawn that was
# removed precisely because it cost a full sub-agent lifecycle to echo a cached digest.
# The {} is a contract with the sibling hooks, not a style choice.
#
# AND THE DEFER IS A DENY, NOT permissionDecision:"defer"
# "defer" is a real documented value meaning "use the normal permission flow". It holds,
# delays and re-dispatches exactly nothing. There is no hook mechanism to suspend a tool
# call. The deferral here is SEMANTIC: a deny carrying a corrective, document-naming,
# next-wave-prescribing reason, in the same register as the fan-out gate's reasons.
#
# THE TWO-PHASE LEDGER
# <cache>/.readers/slot-1 … slot-N, where THE SET OF FILES IS THE COUNT. One line each:
#
#   prov <epoch> <session_id> <document_id> <fp>   claimed at PreToolUse; reader unseen
#   live <epoch> <session_id> <agent_id>           confirmed by SubagentStart
#
# <fp> is the DISPATCH FINGERPRINT: a hex digest of the session id plus the verbatim
# dispatch prompt, i.e. an identity for THIS dispatch that any hook seeing the same
# event derives identically without seeing any other hook's decision. It is what a
# sibling gate's tombstone names (see below). An absent document_id or fingerprint is
# written as `-`, never as an empty field: an empty middle field would collapse under
# whitespace splitting and shift the fingerprint into the document_id column.
#
# EVERY FIELD ON THESE LINES IS WHITESPACE-FREE BY CONSTRUCTION, and that is a parsing
# requirement, not tidiness. The line is whitespace-DELIMITED and read back with a fixed
# field count, so a value carrying an interior space (or tab, or newline) shifts every
# field after it: the session id would swallow the document id column, the fingerprint
# would land in the wrong field and stop being readable hex, and the slot could then
# neither be released by attribution nor matched by any tombstone — the gate would
# silently degrade to TTL-only release for the rest of that session. The parser therefore
# DELETES whitespace from every value it emits into these lines rather than collapsing it
# to a space, so a separator cannot survive inside a field at all.
#
# Both phases count toward the bound — provisional ones MUST, because a whole wave is
# dispatched as one tool batch, so all N PreToolUse hooks fire before any reader starts;
# a ledger that only counted started readers would read empty N times and bound nothing.
# Check-and-claim is therefore one kernel-atomic step in one invocation: ( set -C; … > f )
# is O_CREAT|O_EXCL, so the KERNEL picks the winner of a race, not this script.
#
# A VETOED dispatch falls out for free: it never spawns a subagent, so it never fires
# SubagentStart, so its provisional slot is never confirmed and expires on the short
# provisional TTL. Nothing here HAS to know a veto happened — the absence of a spawn IS
# the knowledge, for every deny from every gate, present and future. That correctness
# floor is untouched by everything below; the TOMBSTONE is a pure accelerator on top of
# it, because with a warm digest cache the veto is the COMMON case and a whole burst of
# them would otherwise hold phantom slots for the full provisional TTL and defer a
# genuinely free read by a wave.
#
# TOMBSTONES: <cache>/.readers/tomb-<fp>, written by the vetoing gate, honoured here.
# Neither hook can see the other's decision, so the handshake is entirely on disk and by
# NAME — both sides compute <fp> from the same event. See reap_tombstones() for the
# order-independence argument and the one-shot rule.
#
# Release is layered, strongest first, each layer a pure safety net for the one above:
#   1. SubagentStop, attributed by agent_id — the normal path.
#   2. Tombstone — a sibling gate vetoed the dispatch, so no reader will ever start.
#   3. Provisional TTL — the backstop for anything that never started (any deny),
#      including a veto whose tombstone never arrived. NOT weakened to compensate.
#   4. Live TTL — the crashed-reader backstop.
#
# Ledger scope is the WORKSPACE, not the session: the cache dir is per-workspace, so two
# sessions in one workspace share the bound. That is deliberate — the cost this bounds is
# account-wide, not per-conversation — and cross-session contention produces a deferral,
# never a refusal. session_id is recorded per slot for diagnostics and for matching a
# promotion to its own session.
#
# Every ambiguity resolves toward reaping: a zero-byte, unparseable or malformed slot is
# reaped ON SIGHT, not at TTL. Reaping a live slot early means over-dispatch, which is
# the status quo and safe; keeping a wedged slot means deferring a real read, which is
# the failure this file exists to prevent. (A zero-byte slot is reachable, not
# hypothetical: killing a claimer between the O_EXCL open and the write leaves a 0-byte
# file that returns EEXIST to every later claimant — a permanently wedged slot.)
#
# PORTABILITY (bash 3.2 / BSD / GNU — the owner's Mac is a first-class target)
# No flock (absent on macOS), no declare -A (absent in bash 3.2), no stat (GNU -c %Y vs
# BSD -f %m diverge), no find -delete / -printf (extensions), no mapfile, no grep -P, no
# jq, bare mktemp only (flagged forms diverge sharply), -exec … + over xargs so paths
# containing spaces survive.
#
# Env knobs (all optional; every invalid value falls back to the default):
#   THALURA_MAX_CONCURRENT_READERS  slots in the ledger                   (default 5)
#   THALURA_READER_LIVE_TTL         seconds a confirmed slot may live     (default 300)
#   THALURA_READER_PROV_TTL         seconds an unconfirmed slot may live  (default 300)
#
# WHY BOTH TTLs DEFAULT THE SAME, AND WHY THE CONFIRM STEP IS PRESENT BUT UNBOUND
# The SubagentStart branch below is fully implemented and exercised by the test suite,
# but the manifest does NOT bind it, and that is a deliberate compatibility decision
# rather than an oversight. Binding an event key the running host does not recognise
# makes that host register ZERO hooks from this plugin — not just the unknown one — and
# it does so SILENTLY. The start-side event is recent; older hosts that are otherwise
# perfectly capable of running this plugin do not know it. Binding it would therefore
# trade a bounded fan-out for the total, invisible loss of every gate this plugin has,
# the cache veto included, on exactly the installs least likely to notice.
#
# Consequence for the ledger: with nothing promoting slots, every slot stays provisional
# for its whole life, so the PROVISIONAL TTL — not the live one — is what has to outlast
# a real reader. It therefore defaults to the same 300s. The short provisional TTL only
# ever existed to clear phantom slots left by a vetoed dispatch quickly, and the TOMBSTONE
# now does that deterministically and at once, which is strictly better than a timeout.
# If a future minimum-supported host makes the start-side event safe to bind, adding the
# binding restores the two-phase distinction with no change to this file.
#   THALURA_HOOK_TIMEOUT            per-subprocess cap, seconds           (default 10)
#   THALURA_CACHE_DIR               authoritative cache dir override (tests / operator)
set -u

allow() { printf '{}\n'; exit 0; }  # fail-open: emit {}, change nothing. See above:
                                    # byte-exactly {}, NEVER permissionDecision:"allow".

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/_resolve.sh" ] || allow
# shellcheck source=/dev/null
. "$HERE/_resolve.sh"

EVENT="$(cat)"                      # the hook event JSON from stdin
CAP="${THALURA_HOOK_TIMEOUT:-10}"   # script-level per-subprocess timeout (s)

READER_AGENT="thalura:read-regulations"

# --- Deny channel. Mirrors the fan-out gate: both branches functional, ships as "json".
# NOTE the hard constraint enforced further down: this channel is legitimate ONLY on the
# PreToolUse path.
DENY_CHANNEL="json"                 # "json" | "exit2"

# --- The bound. An invalid or zero value falls back to the default rather than to a
# tighter bound: per the invariant, a tuning error must never cost a read. A bound of 0
# would deny every dispatch forever, so it is not reachable from a typo.
MAXR="${THALURA_MAX_CONCURRENT_READERS:-5}"
case "$MAXR" in ''|*[!0-9]*) MAXR=5 ;; esac
[ "$MAXR" -ge 1 ] || MAXR=5

# --- The two TTLs, in seconds, converted to whole minutes for the reaper. Minute
# granularity is the portable floor: sub-minute ageing needs a reference-file dance that
# diverges between GNU and BSD. Each is clamped to at least one minute, because a
# zero-minute age matches a slot created microseconds ago and would silently disable the
# bound entirely.
LIVE_TTL="${THALURA_READER_LIVE_TTL:-300}"
PROV_TTL="${THALURA_READER_PROV_TTL:-300}"
case "$LIVE_TTL" in ''|*[!0-9]*) LIVE_TTL=300 ;; esac
case "$PROV_TTL" in ''|*[!0-9]*) PROV_TTL=300 ;; esac
LIVE_MIN=$((LIVE_TTL / 60)); [ "$LIVE_MIN" -ge 1 ] || LIVE_MIN=1
PROV_MIN=$((PROV_TTL / 60)); [ "$PROV_MIN" -ge 1 ] || PROV_MIN=1

NOW="$(date +%s 2>/dev/null)"
case "$NOW" in ''|*[!0-9]*) NOW=0 ;; esac

# --- Portable per-subprocess timeout (timeout/gtimeout when present; else a watchdog —
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
#
# HARD CONSTRAINT: deny() is callable ONLY from the PreToolUse branch. On SubagentStop,
# exit code 2 does not mean "deny a tool call" — it PREVENTS THE SUBAGENT FROM STOPPING,
# i.e. it would wedge a live reader and hang the teacher's session, which is strictly
# worse than every failure this file exists to prevent. SubagentStart is observational
# only (context, no decision control). Both of those branches exit 0 on every path,
# including every error path, and must never reach this function or its exit-2 fallback.
# A later refactor "unifying the exit paths" is exactly how that constraint gets lost.
deny() {
  local reason="$1"
  if [ "$DENY_CHANNEL" = "exit2" ]; then
    printf '%s\n' "$reason" >&2
    exit 2
  fi
  # THE REASON IS A NON-ASCII PAYLOAD CARRIED THROUGH ARGV — the deferral reason
  # built below carries an em dash and names a German document id — and that is a
  # THIRD channel, covered by neither the -c source-ASCII guard (which scans the
  # SPAN; this sits in the ARGUMENT after it) nor the non-UTF-8 CI leg (which covers
  # STREAMS). CPython decodes argv with the LOCALE-DEPENDENT FILESYSTEM encoding:
  # macOS forces utf-8 there whatever the locale, so this is structurally invisible
  # on that platform, while a Linux host under LC_ALL=C gives fs=ascii and the reason
  # arrives SURROGATE-ESCAPED. json.dumps(ensure_ascii=True) serialises the lone
  # surrogates without complaint, so the emit succeeds at rc=0 with empty stderr and
  # the dispatcher is told to re-dispatch in a following wave in mangled text — the
  # deferral is only worth what its instruction is worth. os.fsencode() round-trips
  # surrogateescape back to the original bytes and the decode is then ours and
  # explicit; on macOS the line is a no-op. errors="replace" keeps the fail-open
  # direction: a smudged reason, never a raise on the deny path.
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

# --- Parse. The event is passed by FILE PATH (argv) and the parser is python3 -c code
# (argv, NOT a heredoc) so it survives run_cap's watchdog fallback, which backgrounds the
# command and would sever a heredoc's stdin. Output goes to a TEMP FILE read AFTER
# run_cap returns, NEVER through a command substitution around run_cap (that shape
# orphans the watchdog sleep and stalls the hook).
EVENT_FILE="$(mktemp 2>/dev/null)" || allow
printf '%s' "$EVENT" > "$EVENT_FILE" 2>/dev/null || { rm -f "$EVENT_FILE" 2>/dev/null; allow; }
OUT_FILE="$(mktemp 2>/dev/null)" || { rm -f "$EVENT_FILE" 2>/dev/null; allow; }

# Field discipline: every emitted field is length-capped and carries NO whitespace at all
# (flat() DELETES it rather than collapsing it), so no value can carry a newline and
# desync the line-by-line read below, and no value can carry an interior space and shift
# the field count of the whitespace-delimited ledger line it is written into. The one
# exception is the cwd, which is a filesystem path and may legitimately contain spaces:
# it gets flat_path(), which collapses whitespace runs to a single space and so still
# cannot carry a newline. Line 1 is a fixed numeric sentinel: any parse failure
# (malformed stdin, missing python3, timeout) leaves the file empty, the sentinel
# non-numeric, and the hook fail-opens through the guard after the read.
#
# LOCALE-INDEPENDENT, BYTE-FOR-BYTE. The event is read as BYTES and decoded UTF-8 with an
# explicit error handler, and the result is written back out as UTF-8 BYTES — never
# through the interpreter default, which follows the ambient locale. A hook inherits
# whatever locale the host process happens to run under; under a non-UTF-8 one the
# implicit path decodes the same event to a DIFFERENT string (and cannot even emit a
# German path or document id without raising), so a fingerprint derived through it would
# not match the sibling gates and every field here could vanish. The regulation prompts
# this gate exists for are German — section signs, umlauts and em dashes are the normal
# case, not an edge case — so the explicit codec is what makes the derivation reproducible
# at all, and every side of the handshake must spell it the same way.
#
# The document_id is taken from the FIRST line-anchored document_id: key, the same
# discipline the fan-out gate uses: a mid-line mention (hierarchy context naming other
# documents) is not a dispatch key.
#
# An absent / non-string prompt on a PreToolUse event is a MALFORMED PAYLOAD, never "an
# empty prompt": print nothing and exit 0, so the hook allows and claims nothing rather
# than claiming a slot for a dispatch it could not read.
#
# The DISPATCH FINGERPRINT is computed here, from the flattened session id and the
# VERBATIM prompt (not the flattened one — flattening is a display discipline for the
# fields below, and hashing the raw string is what makes the value reproducible by any
# other hook reading the same event). A sibling gate that vetoes this dispatch derives
# the identical value the identical way; that agreement is the whole tombstone contract,
# so this derivation must never be "tidied" on one side alone.
# (NB: this parser is a single-quoted shell string — no apostrophes, no backticks here.)
run_cap python3 -c '
import json, sys, re, hashlib
try:
    fh = open(sys.argv[1], "rb")
    raw = fh.read()
    fh.close()
    ev = json.loads(raw.decode("utf-8", "replace"))
except Exception:
    sys.exit(0)
if not isinstance(ev, dict):
    sys.exit(0)

def flat(v, n=200):
    if not isinstance(v, str):
        return ""
    return "".join(v.split())[:n]

def flat_path(v, n=200):
    if not isinstance(v, str):
        return ""
    return " ".join(v.split())[:n]

evname = flat(ev.get("hook_event_name"))
ti = ev.get("tool_input")
if not isinstance(ti, dict):
    ti = {}
# Dispatch events carry the type as tool_input.subagent_type; subagent lifecycle events
# carry it as a top-level agent_type. Accept either, prefer the dispatch shape.
st = flat(ti.get("subagent_type"))
if not st:
    st = flat(ev.get("agent_type"))
if not st:
    st = flat(ev.get("subagent_type"))
sess = flat(ev.get("session_id"))
aid = flat(ev.get("agent_id"))
cwd = flat_path(ev.get("cwd"), 4096)

docid = ""
fp = ""
if evname == "PreToolUse":
    prompt = ti.get("prompt", None)
    if not isinstance(prompt, str):
        sys.exit(0)
    pat = re.compile(r"\s*document_id:\s*(\S+)")
    for line in prompt.split("\n"):
        m = pat.match(line)
        if m:
            docid = flat(m.group(1), 120)
            break
    h = hashlib.sha256()
    h.update((sess or "nosession").encode("utf-8", "replace"))
    h.update(b"\n")
    h.update(prompt.encode("utf-8", "replace"))
    fp = h.hexdigest()[:32]

out = "1\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n" % (evname, st, sess, aid, docid, cwd, fp)
sys.stdout.buffer.write(out.encode("utf-8", "replace"))
' "$EVENT_FILE" > "$OUT_FILE" 2>/dev/null
rm -f "$EVENT_FILE" 2>/dev/null

OK=""; EVNAME=""; SUBAGENT=""; SESSION=""; AGENT_ID=""; DOCID=""; EVENT_CWD=""; DISPATCH_FP=""
{ read -r OK
  read -r EVNAME
  read -r SUBAGENT
  read -r SESSION
  read -r AGENT_ID
  read -r DOCID
  read -r EVENT_CWD
  read -r DISPATCH_FP
} < "$OUT_FILE" 2>/dev/null
rm -f "$OUT_FILE" 2>/dev/null

# Non-numeric / empty sentinel -> the parse did not complete -> allow (fail-open).
case "$OK" in
  ''|*[!0-9]*) allow ;;
esac

[ -n "$SESSION" ] || SESSION="nosession"

# --- Cache dir, resolved exactly as the sibling cache hooks resolve it. THALURA_CACHE_DIR
# (tests / operator) is authoritative; otherwise the shared resolver, fed the event cwd.
# An unresolved workspace is a no-op: never write outside a resolved data root.
[ -n "$EVENT_CWD" ] || EVENT_CWD="$PWD"
if [ -n "${THALURA_CACHE_DIR:-}" ]; then
  CDIR="$THALURA_CACHE_DIR"
else
  CDIR="$(thalura_cache_dir "$EVENT_CWD")" || allow
fi
[ -n "$CDIR" ] || allow
# The SHIPPED PACK is a read-only source (the long note lives in _resolve.sh): the
# slot ledger is runtime state and must never be written into a directory that gets
# published. Direction: `allow`, exactly as this file already answers a SLOTDIR it
# cannot create a few lines below — the dispatch proceeds unbounded, which is a
# concurrency cost and never a refused read. A queue that cannot keep a ledger must
# not be a queue that blocks.
#
# THIS SITS ABOVE THE EVENT SWITCH, so it short-circuits the promote and release legs
# too — and that is correct rather than merely tolerable: nothing was ever claimed under
# a contained root, so there is no slot to promote and none to free. It also emits the
# byte-exact {} those legs require; on the stop event an exit 2 would PREVENT THE
# SUBAGENT FROM STOPPING, which is the one outcome this hook may never produce.
if thalura_is_shipped_pack_path "$CDIR"; then allow; fi
SLOTDIR="$CDIR/.readers"

# --- Reap. Runs before every claim, never on the release paths (a release is already the
# strongest signal there is). Three sweeps, because ONE find cannot express two different
# ages plus a content class:
#
#   1. zero-byte on sight  — the wedged-slot shape; never wait for a TTL.
#   2. unparseable on sight — a slot whose text is neither a prov nor a live line is
#      abandoned by definition. grep -L lists the files that match NEITHER pattern.
#   3. aged, per phase — the age test and the phase test are combined by handing find's
#      age-filtered list to grep -l, which prints only the slots of that phase. An aged
#      provisional slot is reaped at the short TTL; an aged live slot at the long one.
#      (A provisional slot older than the live TTL is already caught by sweep 3a, since
#      the provisional TTL is the shorter of the two.)
#
# -exec … + rather than -delete (an extension) or xargs (which mangles paths containing
# spaces — a workspace path may well have one). The read loop takes the file list on
# stdin, so a space in the path survives. Every sweep swallows its own failure: a reaper
# that can error is a reaper that can block a claim, and the reaper must never do that.
reap() {
  find "$SLOTDIR" -type f -name 'slot-*' -size 0 -exec rm -f {} + 2>/dev/null

  find "$SLOTDIR" -type f -name 'slot-*' -exec grep -L -e '^prov ' -e '^live ' {} + 2>/dev/null |
    while IFS= read -r f; do
      [ -n "$f" ] && rm -f "$f" 2>/dev/null
    done

  find "$SLOTDIR" -type f -name 'slot-*' -mmin "+$PROV_MIN" -exec grep -l '^prov ' {} + 2>/dev/null |
    while IFS= read -r f; do
      [ -n "$f" ] && rm -f "$f" 2>/dev/null
    done

  find "$SLOTDIR" -type f -name 'slot-*' -mmin "+$LIVE_MIN" -exec grep -l '^live ' {} + 2>/dev/null |
    while IFS= read -r f; do
      [ -n "$f" ] && rm -f "$f" 2>/dev/null
    done
  return 0
}

# --- Read one slot file into the four ledger fields. Deliberately tolerant: field 4 is
# read as one field with a REST catch-all, so a slot line that grows a trailing field
# later still parses here instead of turning into a corrupt line. Returns non-zero on an
# empty/unreadable/kindless slot, which every caller treats as "not a slot".
S_KIND=""; S_TS=""; S_SESS=""; S_ID=""; S_REST=""
read_slot() {
  S_KIND=""; S_TS=""; S_SESS=""; S_ID=""; S_REST=""
  read -r S_KIND S_TS S_SESS S_ID S_REST < "$1" 2>/dev/null || true
  case "$S_KIND" in
    prov|live) ;;
    *) return 1 ;;
  esac
  case "$S_TS" in ''|*[!0-9]*) S_TS=0 ;; esac
  return 0
}

# --- Find this session's oldest slot of a given phase, by the epoch recorded IN the slot
# (never by mtime — stat is not portable, and find cannot rank). $1 = prov|live.
# Echoes the slot path, or nothing.
# NO SESSION FILTER HERE, DELIBERATELY — and this is a correctness requirement, not a
# relaxation. The ledger is WORKSPACE-scoped: a claim counts toward the bound whatever
# session made it. A release that matched only the releasing session's own slots would
# therefore count broadly and free narrowly, which is the one asymmetry that can wedge
# capacity shut.
#
# It is not hypothetical. With the confirm step unbound every slot stays provisional, so
# this fallback is the ONLY live release path, and nothing guarantees that the completion
# event carries the same session id as the dispatch that claimed the slot (a subagent may
# legitimately report its own). Filtered, a whole wave could complete and release nothing,
# and the next wave — dispatched exactly as the deferral instructed — would be denied.
# That is the precise failure that got the first version of this bound reverted.
#
# Unfiltered, the worst case is freeing a slot that belonged to another session in the
# same workspace: over-dispatch, which is the behaviour that ships today and which the
# governing invariant explicitly prefers. Freeing too many is survivable; freeing none is
# the failure this file exists to prevent. Session id stays recorded per slot for
# diagnostics — it is simply not a release precondition.
oldest_slot_of_phase() {
  local want="$1" best="" best_ts="" f
  for f in "$SLOTDIR"/slot-*; do
    [ -f "$f" ] || continue
    read_slot "$f" || continue
    [ "$S_KIND" = "$want" ] || continue
    if [ -z "$best" ] || [ "$S_TS" -lt "$best_ts" ]; then
      best="$f"; best_ts="$S_TS"
    fi
  done
  [ -n "$best" ] && printf '%s\n' "$best"
  return 0
}

# --- Honour tombstones. Runs immediately after reap(), i.e. before every claim, and
# never on a release path.
#
# WHY THIS EXISTS. A sibling gate co-bound on the SAME PreToolUse event can VETO the
# dispatch this hook just claimed a slot for — the digest cache answers a remembered
# section inline and stops the dispatch dead. The two hooks run concurrently and neither
# is shown the other's decision, so this hook claims a slot for a dispatch that will
# never spawn a reader, will never fire a start or a stop, and would therefore hold a
# phantom slot for the whole provisional TTL. With a warm cache the veto is the COMMON
# case, so a burst of them can hold every slot and defer a genuinely free read by a wave.
# The vetoing gate drops a tombstone named for the dispatch it stopped; this sweep frees
# the matching slot on the next pass instead of waiting the TTL out.
#
# ORDER-INDEPENDENT BY CONSTRUCTION — the crux, and the reason this is a disk handshake
# and not a message. Neither hook reads the other's state at decision time. The claim
# writes a slot carrying the fingerprint; the veto writes a tombstone named for the same
# fingerprint; NEITHER write is conditional on the other having happened. The match is
# made later, by a THIRD reader — this sweep, on a subsequent invocation — at which
# point both files are simply present or not. Claim-then-tombstone and
# tombstone-then-claim converge on the identical two files on disk, so they converge on
# the identical outcome. There is no window in which one write can invalidate the other,
# because neither write inspects anything.
#
# ONE-SHOT, and only ever a PROVISIONAL slot. A matched pair is deleted TOGETHER, so a
# tombstone can free at most one slot in its whole life — a tombstone written before its
# claim cannot free that slot AND some later slot too. Only `prov` slots are matchable:
# a `live` slot means a reader demonstrably started, which a vetoed dispatch never does
# (and promotion overwrites the fingerprint field anyway). A tombstone whose claim never
# came ages out on the provisional TTL — the same clock the slot it names would have
# used — so it cannot sit around waiting to free an unrelated future read. The residual
# is bounded and lands on the safe side of the invariant: the worst a stale tombstone
# can do is free one slot early, which over-dispatches, never refuses.
#
# The fingerprint is read off a FILE and used as a FILENAME, so it is accepted only as
# lowercase hex: a corrupt or hostile slot line can never name a path outside the ledger.
reap_tombstones() {
  local f t fp
  for f in "$SLOTDIR"/slot-*; do
    [ -f "$f" ] || continue
    read_slot "$f" || continue
    [ "$S_KIND" = "prov" ] || continue
    fp="$S_REST"
    case "$fp" in ''|*[!0-9a-f]*) continue ;; esac
    t="$SLOTDIR/tomb-$fp"
    [ -f "$t" ] || continue
    rm -f "$f" "$t" 2>/dev/null
  done

  # Age out anything unmatched, on the same portable primitives as the slot reaper
  # (no stat, no -delete, no -printf). A tombstone that is never collected is a slow
  # leak in the teacher's workspace, so this sweep is not optional.
  find "$SLOTDIR" -type f -name 'tomb-*' -mmin "+$PROV_MIN" -exec rm -f {} + 2>/dev/null
  return 0
}

case "$EVNAME" in

  # =====================================================================================
  # PreToolUse — reap, then claim or defer.
  # =====================================================================================
  PreToolUse)
    # Only the firewall reader's dispatches are in scope. Anything else — a
    # general-purpose subagent, any other agent type, a non-Agent tool — passes through
    # untouched and claims nothing.
    [ "$SUBAGENT" = "$READER_AGENT" ] || allow

    mkdir -p "$SLOTDIR" 2>/dev/null || allow
    [ -d "$SLOTDIR" ] || allow
    reap 2>/dev/null || true
    reap_tombstones 2>/dev/null || true

    # Ledger fields, both `-` when absent so the line always has the same field count
    # (an empty middle field vanishes under whitespace splitting and would shift the
    # fingerprint into the document_id column on read-back). The fingerprint is written
    # only when it is well-formed lowercase hex, since a slot fingerprint is later used
    # as a filename.
    DOC_FIELD="$DOCID"
    [ -n "$DOC_FIELD" ] || DOC_FIELD="-"
    FP_FIELD="$DISPATCH_FP"
    case "$FP_FIELD" in ''|*[!0-9a-f]*) FP_FIELD="-" ;; esac

    # The atomic core. set -C inside ( ) is O_CREAT|O_EXCL and does not leak to the
    # parent shell: the kernel, not this script, decides who wins a race between the N
    # hook invocations of one dispatch batch.
    claimed=""
    env_fault=""
    n=1
    while [ "$n" -le "$MAXR" ]; do
      slot="$SLOTDIR/slot-$n"
      if ( set -C; printf 'prov %s %s %s %s\n' "$NOW" "$SESSION" "$DOC_FIELD" "$FP_FIELD" > "$slot" ) 2>/dev/null; then
        claimed="$n"
        break
      fi
      # A create that failed while the slot file does NOT exist is an environment fault
      # (unwritable directory, vanished cache root) — not capacity. The bound is enforced
      # only on positive evidence that every slot is genuinely held.
      [ -e "$slot" ] || env_fault="1"
      n=$((n + 1))
    done

    # The claim side of the tombstone handshake — the other half of order-independence.
    # If the vetoing gate got here FIRST, the tombstone for this very dispatch was
    # already on disk while the sweep above ran too early to see a pair that did not
    # exist yet. Test it once more against the fingerprint just written, so that order
    # releases the slot immediately rather than on the next dispatch's sweep. Same
    # one-shot rule (both files go together), same safe residual (a stale tombstone
    # frees one slot early, which over-dispatches and never refuses).
    if [ -n "$claimed" ] && [ "$FP_FIELD" != "-" ] && [ -f "$SLOTDIR/tomb-$FP_FIELD" ]; then
      rm -f "$SLOTDIR/slot-$claimed" "$SLOTDIR/tomb-$FP_FIELD" 2>/dev/null
    fi

    [ -z "$claimed" ] || allow
    [ -z "$env_fault" ] || allow

    # At capacity -> DEFER. Corrective, document-naming, wave-prescribing, and free of
    # any internal mechanism (this reason is dispatcher-facing and is never surfaced to
    # the teacher verbatim). Built through json.dumps in deny() so backticks and dashes
    # escape correctly.
    if [ -n "$DOCID" ]; then
      WHICH="The document \`$DOCID\`"
    else
      # The document_id could not be read from this dispatch, so it cannot be named. The
      # deferral still stands — inventing an id would be worse than admitting the gap.
      WHICH='This document (its `document_id:` line could not be read from the dispatch prompt, so it cannot be named here)'
    fi
    # shellcheck disable=SC2016  # the backticks are literal markdown code-spans, NOT command substitution.
    deny "the concurrent-reader bound is reached — $MAXR regulation readers are already in flight, which is the maximum. $WHICH has NOT been dropped and NOTHING is lost: dispatch it again as its own \`$READER_AGENT\` Agent call in the NEXT wave, once the current wave has returned. Every deferred document is read in a following wave; none is left unread."
    ;;

  # =====================================================================================
  # SubagentStart — CONFIRM. Observational only: this event has no decision control at
  # all, so the branch exits 0 on every path and never emits a decision.
  #
  # It does not need to know which slot is "its own": provisional slots are
  # interchangeable for counting, so it promotes this session's OLDEST provisional slot
  # and stamps the agent_id onto it. Attribution only has to be right at release, and by
  # then the agent_id is written. That is what lets the design work even though
  # SubagentStart carries no document_id.
  #
  # Strict type match here, deliberately asymmetric with the release branch below:
  # promoting a slot LENGTHENS its life (short provisional TTL -> long live TTL), so a
  # promotion driven by the wrong event would push toward a deferral. When in doubt, do
  # not promote: the slot then simply expires at the short TTL, which over-dispatches —
  # the safe direction.
  # =====================================================================================
  SubagentStart)
    [ "$SUBAGENT" = "$READER_AGENT" ] || allow
    [ -d "$SLOTDIR" ] || allow
    [ -n "$AGENT_ID" ] || allow

    # Promote, then read back. If a concurrently-starting sibling won the same slot, the
    # read-back shows its agent_id and this invocation moves on to the next-oldest
    # provisional slot. Bounded by the slot count; giving up entirely is safe — the
    # reader then runs uncounted, which over-dispatches rather than deferring.
    tries=0
    while [ "$tries" -lt "$MAXR" ]; do
      tries=$((tries + 1))
      target="$(oldest_slot_of_phase prov 2>/dev/null)"
      [ -n "$target" ] || break
      printf 'live %s %s %s\n' "$NOW" "$SESSION" "$AGENT_ID" > "$target" 2>/dev/null || break
      if read_slot "$target" 2>/dev/null; then
        [ "$S_KIND" = "live" ] && [ "$S_ID" = "$AGENT_ID" ] && break
      fi
    done
    allow
    ;;

  # =====================================================================================
  # SubagentStop — RELEASE.
  #
  # EXIT 0 ON EVERY PATH, WITHOUT EXCEPTION. On SubagentStop, exit code 2 does not mean
  # "deny": it PREVENTS THE SUBAGENT FROM STOPPING. A release path that can exit 2 would
  # wedge a live reader and hang the teacher's session — strictly worse than any failure
  # this file exists to prevent. deny() is unreachable from here and must stay that way.
  #
  # Type match is permissive here, the mirror image of the confirm branch: releasing is
  # the direction that costs nothing if it fires too eagerly (an extra release
  # over-dispatches; a missed release defers a real read). So an event whose agent type
  # is absent still releases; only a positively-identified OTHER agent type is skipped.
  # =====================================================================================
  SubagentStop)
    if [ -n "$SUBAGENT" ] && [ "$SUBAGENT" != "$READER_AGENT" ]; then
      allow
    fi
    [ -d "$SLOTDIR" ] || allow

    released=""
    if [ -n "$AGENT_ID" ]; then
      for f in "$SLOTDIR"/slot-*; do
        [ -f "$f" ] || continue
        read_slot "$f" || continue
        [ "$S_KIND" = "live" ] || continue
        [ "$S_ID" = "$AGENT_ID" ] || continue
        rm -f "$f" 2>/dev/null && released="1"
        break
      done
    fi

    # No agent_id match (an older runtime, a lost promotion, a reaped slot): fall back to
    # this session's oldest live slot. Releasing one slot too many only ever
    # over-dispatches; releasing none too few would defer a real read.
    if [ -z "$released" ]; then
      target="$(oldest_slot_of_phase live 2>/dev/null)"
      [ -n "$target" ] && rm -f "$target" 2>/dev/null && released="1"
    fi

    # STILL nothing — and this is the case that matters most, because it is what a runtime
    # WITHOUT a start-side event looks like: every slot is stuck at `prov` because nothing
    # ever promoted it, so neither branch above can match and the ledger would hold the
    # bound for the whole provisional TTL even though a reader has demonstrably finished.
    # A stop event IS proof that a reader completed. Release this session's oldest
    # provisional slot rather than waiting the TTL out: freeing one too many merely
    # over-dispatches (the state that ships today), while freeing none defers a read that
    # is owed a slot — the one failure this file exists to prevent, and the failure that
    # got the first version of this bound reverted.
    if [ -z "$released" ]; then
      target="$(oldest_slot_of_phase prov 2>/dev/null)"
      [ -n "$target" ] && rm -f "$target" 2>/dev/null
    fi
    allow
    ;;

  # An unrecognised or absent event key: no-op. A hook that acts on an event it does not
  # understand is a hook that acts on a payload shape it has not seen.
  *)
    allow
    ;;
esac

allow
