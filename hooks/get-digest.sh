#!/usr/bin/env bash
# Get-side regulation-cache hook on PreToolUse-on-Agent (main-session firewall
# dispatch).
#
# On a derived-key HIT it DENIES the dispatch and delivers the cached digest inline
# in permissionDecisionReason. The reader sub-agent never spawns: a HIT costs one
# hook invocation instead of a full sub-agent lifecycle.
#
# DELIBERATE REVERSAL of this file's former "NEVER a deny" doctrine. That doctrine
# rested on a sandbox-boundary-breach fear which its own sibling hook has since
# falsified: fanout-gate.sh ships a PreToolUse-on-Agent deny that is evidenced to
# veto cleanly in the hosted runtime. Under the old doctrine a HIT still ALLOWED the
# dispatch and merely pre-loaded the digest into the prompt, so the reader still
# spawned and still paid its whole lifecycle just to echo a digest this hook already
# held. That was the single largest measured cost defect in the read path.
#
# The deny moves no boundary. What it delivers is a DIGEST — the citation-verified
# object the reader is already permitted to hand back across the firewall. Serving it
# from cache changes WHO hands it over, never WHAT crosses. Nothing derived here
# opens a PDF: the identity is assembled from dispatch metadata plus the page-map
# sidecars (JSON metadata the main session may already read).
#
# THE DENY IS RECOVERABLE BY THE CALLER. A cached entry can be wrong for the request, or
# honestly too thin to answer it, and without a way back the deny makes that permanent:
# the entry is rebuilt only by the reader, the reader is reached only through a dispatch,
# and the dispatch is exactly what the entry vetoes. So a dispatch may carry a whole-line
# `cache: force-reread` key, which this hook parses BEFORE it decides: the cache lookup
# is skipped, the dispatch takes the MISS spine (mandate + rewrite, so the fresh read
# still reaches the cache writer), and the rewritten prompt additionally carries a
# directive telling the reader to skip ITS OWN first-step cache lookup — the second gate,
# without which the fix would be inert and cost a reader for nothing. Two preconditions
# guard it, both mandatory: the derive must have succeeded, and the dispatch must already
# be firewall-shaped. A dispatch carrying no such line is untouched, byte for byte.
#
# NOTE THE ASYMMETRY OF "FAIL-OPEN" HERE. For the deny gate, fail-open means ALLOW, which
# is safe. For the OVERRIDE it means "override not applied" — which serves the stale entry
# again, i.e. the very defect. Every added path is annotated with which direction it takes
# and why that is the tolerable one; the only path that lands in the unhelpful direction
# is a failed side-channel write, and it is not silent, because the deny reason the caller
# then receives names the exact key spelling.
#
# FAIL-OPEN, unchanged and sacred: ONLY a confident derived-key HIT denies. Any
# miss / derivation failure / ambiguity / unresolved workspace / missing python3 /
# timeout / malformed event -> emit {} (a normal read follows: one redundant read,
# NO correctness loss). A deny can therefore only ever REMOVE a provably unnecessary
# reader; it can never prevent a needed read. Worst case on any bug here is the old
# behaviour, never a blocked session.
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

# Pull the dispatch cwd (python3 — robust to any payload shape). Read and written as
# explicit UTF-8 bytes: a workspace path with an umlaut in it must resolve to the same
# cache dir on every host, and the interpreter default follows the ambient locale.
event_cwd="$(printf '%s' "$EVENT" | python3 -c '
import json,sys
def emit(s): sys.stdout.buffer.write((s + "\n").encode("utf-8", "replace"))
try: e=json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
except Exception: emit(""); sys.exit(0)
emit(e.get("cwd","") if isinstance(e,dict) and isinstance(e.get("cwd"),str) else "")' 2>/dev/null)"
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

# --- Is that cache root the SHIPPED PACK? See the long note in _resolve.sh: the pack
# is a read-only source, and a cache root pointed inside it is a misconfiguration
# whose only reachable effect is to write runtime state into a directory that gets
# published.
#
# Resolved ONCE, here, rather than at each write site: the predicate forks, this hook
# runs on every dispatch, and both writes below want the same answer.
#
# FAIL-OPEN DIRECTION, identical on both sites this flag governs. Neither write is a
# precondition for anything: the audit line is a breadcrumb whose result nothing
# reads, and the tombstone only lets a sibling release a slot early. With the flag
# set, this hook's HIT/MISS decision, its deny, its mandate injection and its
# subagent_type rewrite are all BYTE-IDENTICAL to a run without it. What is lost is a
# breadcrumb, and one wave round-trip of latency — never a read, never a decision.
PACK_RO=""
if thalura_is_shipped_pack_path "$CDIR"; then PACK_RO=1; fi

# Page-map directory for the on-disk vocabulary. Test override THALURA_PAGEMAP_DIR;
# otherwise the shipped regulations tree under the plugin root.
PMDIR="${THALURA_PAGEMAP_DIR:-$PROOT/regulations}"

# --- The teacher's school type — the ONLY correct discriminator between two page-maps
# that share a document_id. Six document_ids (bildungsplan-sek1-{english,philosophy,
# religion}, sek1-teil-c, sek1-aufgabengebiete, rahmenvorgaben-sprachbildung) exist in
# BOTH school-type trees as genuinely DIFFERENT PDFs with DIFFERENT source_pdf_sha256.
# Letting a dict overwrite pick one alphabetically is not a tie-break, it is a silent
# wrong-document choice: at best the wrong sha keys a permanent MISS, at worst a HIT
# hands a Gymnasium teacher another school type's regulation content marked
# authoritative. The plugin's whole promise is traceability to the CORRECT document.
#
# Read from the workspace's school-config.json (data/profiles/school-config.json —
# the authoritative home of school_type), via the same resolver the cache dir uses,
# and lowercased to match the regulations/<state>/<school-type>/ path segment.
# Unresolvable (no workspace / no config / malformed / no python3) -> empty, and the
# derive step below then fails OPEN on any document that needs disambiguation. Never
# a guess. Documents under shared/ carry no school-type segment and stay resolvable
# either way (they are single-candidate).
SCHOOL_TYPE=""
WSROOT="$(THALURA_SESSION_DIR="$event_cwd" bash "$PROOT/scripts/resolve-data-root.sh" 2>/dev/null)" || WSROOT=""
case "$WSROOT" in ""|THALURA_*) WSROOT="" ;; esac
if [ -n "$WSROOT" ] && [ -f "$WSROOT/data/profiles/school-config.json" ]; then
  SCHOOL_TYPE="$(python3 - "$WSROOT/data/profiles/school-config.json" 2>/dev/null <<'PY'
import json, sys
# `errors` SPELLED OUT, never inherited from the codec default. STRICT is the right end
# here and is deliberate: a school-config that is not valid UTF-8 must not be half-read
# into a school type that then SELECTS AN EDITION. The raise lands on the give-up below,
# which is the toward-miss direction the identity path takes everywhere in this file.
try:
    d = json.load(open(sys.argv[1], encoding="utf-8", errors="strict"))
except Exception:
    sys.exit(0)
st = d.get("school_type") if isinstance(d, dict) else None
if isinstance(st, str):
    # BYTES, explicitly, exactly like every other emit in this file. This was a plain
    # `sys.stdout.write` onto a TEXT stdout, which encodes with the AMBIENT LOCALE codec:
    # a school type carrying an umlaut raised UnicodeEncodeError on a non-UTF-8 host, the
    # traceback went to a stderr the caller discards, and the value came back EMPTY.
    #
    # EMPTY IS NOT NEUTRAL. An empty school type is the school-type-unknown give-up, so
    # EVERY multi-edition document became a PERMANENT MISS -- a total, silent cache defeat
    # on precisely the documents this validation exists for, with the hook still looking
    # perfectly healthy. The direction is toward miss (safe, never a wrong edition served),
    # which is exactly why nothing would ever have reported it.
    sys.stdout.buffer.write(" ".join(st.split()).strip().lower().encode("utf-8", "replace"))
PY
)" || SCHOOL_TYPE=""
fi

# Session id for the audit breadcrumb (python3 — robust to any payload shape), read and
# written as explicit UTF-8 bytes so a non-ASCII id cannot raise on emit and cost the
# breadcrumb its identity.
SESSION="$(printf '%s' "$EVENT" | python3 -c '
import json,sys
def emit(s): sys.stdout.buffer.write((s + "\n").encode("utf-8", "replace"))
try:
    e=json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
    emit(e.get("session_id","") if isinstance(e,dict) and isinstance(e.get("session_id"),str) else "")
except Exception: emit("")' 2>/dev/null)"
[ -n "$SESSION" ] || SESSION="nosession"

# One fail-open line per get-hook firing decision into the
# gitignored cache-dir .audit.log (internal-only, never teacher-visible),
# mirroring put-digest.sh's audit(). Records WHICH path fired so the live check
# reads the cause (get-hit / get-miss / mandate injected-or-not). The whole append
# runs in a subshell with stderr silenced, so an unwritable cache dir emits NOTHING.
AUDIT="$CDIR/.audit.log"
audit_get() {
  # The shipped pack takes no breadcrumb. Nothing downstream reads this line, so the
  # skip is invisible to every decision this hook makes.
  [ -z "$PACK_RO" ] || return 0
  ( printf '%s session=%s get-hook %s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo now)" "$SESSION" "$*" \
      >> "$AUDIT" ) 2>/dev/null || true
}

# --- Reader-slot tombstone. Written on the HIT-deny path, and NEVER a precondition
# for that deny.
#
# A sibling hook bounds how many regulation readers run at once by claiming a
# provisional slot on this SAME PreToolUse event. The two hooks run concurrently and
# neither is shown the other's decision, so when a HIT vetoes the dispatch here, the
# sibling has claimed (or is about to claim) a slot for a reader that will now never
# spawn: no subagent starts, none stops, and the slot sits phantom until its short TTL
# expires. With a warm digest cache the veto is the COMMON case, so a burst of them can
# hold every slot and defer a genuinely free read by a whole wave. A tombstone naming
# the dispatch just vetoed lets the sibling release that slot on its next pass.
#
# The name is a fingerprint of the dispatch — the flattened session id plus the verbatim
# dispatch prompt — derived here EXACTLY as the sibling derives it from the same event.
# That shared derivation is the entire contract: the two hooks agree on a name without
# either observing the other. Hook ORDER is therefore irrelevant. Neither the tombstone
# write nor the slot claim inspects the other; whichever lands second simply completes
# the pair on disk, and the sibling matches them on a later pass (and, when the
# tombstone lands first, at the moment of its own claim). Both orders converge on the
# same two files, hence on the same outcome. This derivation must never be "tidied" on
# one side alone.
#
# FAIL-OPEN, absolutely — this file's doctrine, restated for a side effect: the whole
# body runs in a subshell whose every failure and every byte of output is swallowed, and
# nothing downstream tests its result. There is no path on which a failed tombstone
# write changes, delays, weakens or blocks the deny; the slot simply falls back to
# expiring at its TTL, which is exactly the behaviour that shipped before this existed.
reader_tombstone() {
  # The shipped pack takes no tombstone. The fallback is the one the paragraph above
  # already names as tolerable: the sibling's slot ages out at its TTL instead of
  # being released early. Costs a wave round-trip, never a read, never the deny.
  [ -z "$PACK_RO" ] || return 0
  ( [ -n "${CDIR:-}" ] || exit 0
    tdir="$CDIR/.readers"

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
    # leak in the teacher's workspace, so this sweep runs on every write — the sibling
    # sweeps too, and either alone is sufficient.
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
        "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo now)" "$SESSION" \
        > "$tdir/tomb-$fp" ) 2>/dev/null
    exit 0
  ) >/dev/null 2>&1 || true
  return 0
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
#
# EVERY GIVE-UP CARRIES ITS REASON OUT IN ITS EXIT CODE (10..23), which bash maps to one
# ASCII token in the `case` block below. Before that, all fourteen give-up shapes -- and
# the true cold miss, i.e. this hook working correctly -- left the byte-identical audit
# line, so the school-type validation REFUSING to serve a teacher the other school type's
# edition was indistinguishable from a cache that was merely cold. The codes change no
# decision: the identity guard below requires exit 0 AND a non-empty identity file, and
# every give-up leaves that file empty, so a give-up was already the no-deny outcome and
# still is. `0` stays reserved for a resolved coordinate.
ID_FILE="$(mktemp 2>/dev/null)" || allow
EVENT_FILE="$(mktemp 2>/dev/null)" || { rm -f "$ID_FILE" 2>/dev/null; allow; }
# SIDE_FILE is the derive's side channel back to bash (see Step 1b below): three lines
# carrying the override verdict plus the coordinate the derive resolved. NOT stderr —
# the derive's stderr is discarded a few lines down, and re-opening that redirect would
# mix interpreter warnings into a control signal.
# Fail-open direction on a failed mktemp: `allow`, exactly like its two siblings. That
# is the SAFE direction for BOTH readings of this hook — the dispatch proceeds and a
# real reader runs, which is what an override asks for anyway.
SIDE_FILE="$(mktemp 2>/dev/null)" || { rm -f "$ID_FILE" "$EVENT_FILE" 2>/dev/null; allow; }
printf '%s' "$EVENT" > "$EVENT_FILE" 2>/dev/null || { rm -f "$ID_FILE" "$EVENT_FILE" "$SIDE_FILE" 2>/dev/null; allow; }
# The event is passed by FILE PATH (argv), not stdin: the heredoc IS this python's
# stdin (the script body). This derive step is NOT wrapped in run_cap — run_cap's
# watchdog fallback backgrounds the command, which severs the heredoc stdin a
# `python3 -` needs to read its script. The work here is bounded local file reads
# (a finite page-map glob + json.load), so it cannot hang on a network and needs no
# timeout. cache.py (which can in principle hang) stays under run_cap below.
python3 - "$PMDIR" "$EVENT_FILE" "$SCHOOL_TYPE" "$SIDE_FILE" > "$ID_FILE" 2>/dev/null <<'PY'
import json, sys, os, glob, re

def norm(s):
    return " ".join(str(s).split()).strip()

# Comparison form for a section anchor: whitespace-collapsed, lowercased, and with
# typographic punctuation folded to its ASCII shape.
#
# WHICH RE-TYPINGS THIS RESCUES, AND WHICH IT DOES NOT. The table below covers exactly ONE
# class: the typographic punctuation a model normalizes when it RE-TYPES an anchor instead
# of copying it -- em/en dash and minus, ellipsis, no-break space, curly quotes -- plus
# case and whitespace. Measured over the 992 anchor rows in the 43 shipped sidecars: 172
# carry a character this table folds.
#
# IT DOES NOT COVER THE GERMAN LETTERS, AND THEY ARE THE LARGER CLASS: 332 of those same
# rows carry an umlaut, an eszett or a section sign, and NONE of them is folded. `.lower()`
# is deliberate and NOT `.casefold()` -- casefold maps eszett to `ss`, which would change
# what can collide and would require the zero-collision measurement below to be redone --
# so a dispatch that types `Massnahmen` for `Maßnahmen`, or `Foerderung` for `Förderung`,
# MISSES. That is the tolerable direction (fail open: a redundant read, never a wrong
# section) but it is NOT a near miss this rescues, and reading the fold as "it rescues the
# re-typings" would over-promise on the class that is nearly twice as common.
#
# WHAT IT DOES GUARANTEE is that it can never select a DIFFERENT section: measured over the
# corpus at both grains -- 659 distinct anchor strings, 889 distinct (document_id, anchor)
# pairs -- ZERO pairs collide under this folding.
#
# EVERY CHARACTER BELOW IS WRITTEN AS AN ESCAPE, NEVER AS A LITERAL BYTE -- belt and
# braces HERE, though the same rule is load-bearing elsewhere in this file, and the
# boundary is worth stating exactly. It binds the `python3 -c` blocks below: a `-c` source
# reaches CPython through argv and is decoded with the AMBIENT LOCALE CODEC, so one
# non-ASCII byte there raises SyntaxError under a non-UTF-8 locale, and the hook would take
# its parse-failure path and, being fail-open by design, silently ALLOW every dispatch
# while looking perfectly healthy. THIS span is not one of those: a `python3 - <<'PY'`
# heredoc is read as a FILE, which CPython decodes as UTF-8 by default whatever the locale
# says (PEP 263) -- and this very heredoc already carries literal em dashes and section
# signs in its comments and runs clean under LC_ALL=C. dev-scripts/check-python-c-ascii.sh
# scans the `-c` spans ONLY, by design, so its OK says nothing about these lines. The
# escapes stay anyway: they cost nothing, they keep the span trivially safe if it is ever
# moved into a `-c` block, and the runtime strings are identical either way.
_FOLD = (
    ("\u2014", "-"), ("\u2013", "-"), ("\u2212", "-"),   # em dash, en dash, minus
    ("\u2026", "..."),                                     # horizontal ellipsis
    ("\u00a0", " "),                                       # no-break space
    ("\u201c", '"'), ("\u201d", '"'), ("\u201e", '"'),   # curly double quotes
    ("\u2018", "'"), ("\u2019", "'"),                      # curly single quotes
)

def fold(s):
    t = norm(s).lower()
    for a, b in _FOLD:
        t = t.replace(a, b)
    return " ".join(t.split())

# Read the PreToolUse event from the file path in argv; pull the dispatch prompt
# (the only free-text input). BYTES + an explicit UTF-8 decode, never the interpreter
# default, which follows whatever locale this hook inherited: the same event must
# resolve to the same string on every host, and this hook's inputs are German.
#
# STRICT -- AND IT IS THE ONLY STRICT DECODE OF A STREAM OR AN ARGV PAYLOAD IN THIS FILE.
# Every OTHER stream/argv decode here is errors="replace", because every one of those feeds
# a DISPLAY path: an audit breadcrumb, a deny reason, a prompt being forwarded to a reader.
# There a U+FFFD is an acceptable loss and a raised decode would be a fail-CLOSED crash in
# a hook that is fail-open by design.
#
# THE TWO FILE READS ARE STRICT AS WELL, AND CORRECTLY SO -- DO NOT "FIX" THEM INTO
# LENIENCY. Both `json.load(open(..., encoding="utf-8", errors="strict"))` sites -- the
# school-config read near the top of this file and the page-map sidecar read below --
# spell `errors` explicitly and take the same strict end this decode does, and for the same
# reason: those two inputs pick the EDITION and the anchor vocabulary, so half-reading
# either into a coordinate is the failure. Do not read the paragraph above as "everything
# else in this file is lenient" and relax them; the sentence is about streams and argv
# payloads, and the split is by PATH, never by file.
#
# THIS decode is different in kind from the display ones. The prompt it produces is the SELECTOR
# that picks which (document, section) coordinate the identity below is assembled from --
# and a HIT is a DENY THAT SERVES the cached digest. `replace` is lossy
# AND NON-INJECTIVE: every invalid byte sequence collapses onto the same U+FFFD, so an
# event this hook cannot decode would still resolve a coordinate, out of a string that is
# NOT the one the caller sent, and the teacher would be handed THAT section's remembered
# content under a deny.
#
# Nothing between the runtime and this read validates the bytes, so the input is not
# runtime-guaranteed valid UTF-8 and `replace` here could NOT be annotated as dead code:
# it is live, and what it buys is a confident resolution out of input the hook has
# already failed to understand. Strict turns that into a give-up instead -- the derive
# exits, the dispatch takes the MISS spine with its mandate intact, a reader runs, and
# the section is read for real.
#
# "MANDATE INTACT" IS TRUE AND IS NOT THE WHOLE STORY, because this give-up is EARLY. It
# exits before the side-channel write at the very end of this script, so bash reads no
# verdict, and a whole-line `cache: force-reread` riding the same dispatch is SILENTLY
# DROPPED. The caller still gets the MISS spine -- which is what an override wants on this
# path anyway, since no HIT can follow a give-up -- but NOT the reader directive that the
# forced path adds, the one telling the reader to skip ITS OWN first-step cache lookup. So
# the second gate never opens and the "forced" re-read can still be answered from the
# reader's own memory. Unhelpful, never unsafe, and it takes an undecodable event to reach.
#
# DIRECTION: TOWARD MISS. A miss costs one redundant read;
# a mis-selected coordinate costs correctness, which is exactly the class CHANGELOG.md
# already promises teachers is closed. Asserted by the suite's H10.
#
# The other input on this path, argv[3]'s school type, needs no such treatment and gets
# none: it is decoded with the filesystem codec, and a school type that arrives mangled
# matches no page-map path segment, so it fails through the school-type validation below
# to a give-up. That channel already points toward miss.
try:
    with open(sys.argv[2], "rb") as _evfh:
        ev = json.loads(_evfh.read().decode("utf-8", "strict"))
except Exception:
    sys.exit(10)
if not isinstance(ev, dict):
    sys.exit(11)
ti = ev.get("tool_input") or {}
prompt = ti.get("prompt", "") if isinstance(ti, dict) else ""
if not isinstance(prompt, str) or not prompt.strip():
    sys.exit(12)

# The dispatch's declared sub-agent handle — one of the TWO signals that decide whether
# this dispatch is firewall-shaped (the other is a line-anchored document_id: key, parsed
# below). Read only AFTER the prompt guard above and behind its own isinstance check:
# `ti` comes from `ev.get("tool_input") or {}`, which is not itself type-asserted, and a
# non-dict tool_input must not raise here — a raised derive is a fail-open ALLOW, which
# on a cached section costs a whole redundant reader.
subagent_type = ti.get("subagent_type", "") if isinstance(ti, dict) else ""
if not isinstance(subagent_type, str):
    subagent_type = ""

pmdir = sys.argv[1]
school_type = norm(sys.argv[3]).lower() if len(sys.argv) > 3 else ""

# The dispatch contract puts a line `document_id: <id>` at the top of every firewall
# dispatch prompt. Parse it with the SAME line-anchored discipline fanout-gate.sh uses,
# so a mid-line `document_id` mention (hierarchy context naming other documents) is not
# read as a key. Zero keys -> no scoping (the pre-contract fallback: corpus-wide, still
# gated by the exactly-one-distinct-match precondition below). Two or more DISTINCT keys
# -> the dispatch is ambiguous about which document it wants -> fail open.
#
# The CACHE OVERRIDE key rides the same channel and is parsed in the same pass, with the
# same discipline. A caller that has been handed a cached digest which does not answer
# the question it asked has, without it, no way back to the document at all: the entry is
# rebuilt only by the reader, the reader is reached only through a dispatch, and the
# dispatch is what the entry vetoes. Whole-line anchoring is what keeps the key from
# being a footgun — a mid-line mention (hierarchy context, a warning, this hook's own
# deny reason quoted back) is prose, not a key, exactly as for document_id above.
# Exactly one accepted value: any other token on a `cache:` line is NOT an error path, it
# simply falls through to normal gate behaviour, as does an absent key.
# The DECLARED READ SCOPE rides the same channel, parsed in the same pass, with the
# same discipline. It is what the gate matches on, and it replaced a scan of the whole
# free-text prompt for any page-map anchor occurring as a SUBSTRING. That scan had no
# notion of REQUEST versus MENTION: an anchor named in a warning, in hierarchy context,
# or in an explicit PROHIBITION scored exactly like one being asked for -- so a dispatch
# requesting nine sections was served the one section its own warning told the reader not
# to substitute, as a citation-verified HIT. Whole-line anchoring is again what makes the
# key safe to print; a mid-line mention is prose, exactly as for document_id above.
#
# Repeatable: one line per section in scope. A `full` read scope declares NOTHING -- a
# whole-document read cannot be answered from one section entry, so enumerating its
# anchors would only trip the arity rule below at the cost of the tokens to write them.
docpat = re.compile(r"\s*document_id:\s*(\S+)\s*$")
forcepat = re.compile(r"\s*cache:\s*(\S+)\s*$")
# NOT (\S+): a section anchor contains spaces, and 106 anchors in this corpus contain a
# colon, so the value is everything after the first `section_anchor:` to end of line.
#
# `(.*)$`, NOT `(.+?)\s*$`, AND THAT IS A COST BOUND, NOT A TIDY-UP. The lazy group plus a
# trailing `\s*` makes the engine try every split point between the value and the padding,
# so a line carrying one long internal whitespace run backtracks QUADRATICALLY: measured at
# 8.8 s for a single 60 000-character line. The derive is deliberately NOT wrapped in
# run_cap (its work is bounded local file reads, and the watchdog would sever the heredoc
# stdin), so nothing downstream would cut that short -- one hostile-shaped prompt line
# would stall every dispatch. The trailing `\s*` was redundant in any case: fold() below
# collapses and strips, which is also what strips the `\r` off a CRLF line and what turns a
# whitespace-only value into the empty string that yields no key.
secpat = re.compile(r"\s*section_anchor:\s*(.*)$")
doc_keys = []
sec_keys = []
force_asked = False
for line in prompt.split("\n"):
    m = docpat.match(line)
    if m:
        v = m.group(1).strip()
        if v and v not in doc_keys:
            doc_keys.append(v)
    fm = forcepat.match(line)
    if fm and fm.group(1) == "force-reread":
        force_asked = True
    sm = secpat.match(line)
    if sm:
        v = fold(sm.group(1))
        # Deduplicated on the FOLDED form: the same section declared twice (a dispatch
        # assembled from two sources) is one section, not an ambiguous pair, and must not
        # trip the arity rule below.
        if v and v not in sec_keys:
            sec_keys.append(v)
if len(doc_keys) > 1:
    sys.exit(13)
want_doc = doc_keys[0] if doc_keys else ""

# PRECONDITION 2 on the override (precondition 1 — that the derive SUCCEEDED — is
# enforced structurally, by writing the verdict only at the very end of this script).
# The key is honoured ONLY on a dispatch that is already firewall-shaped: it names the
# reader handle, or it carries a line-anchored document_id: key. Without this, ANY agent
# whose prompt merely QUOTES the key — from a changelog, from documentation, from the
# deny reason this hook itself prints — would be silently rewritten into a regulation
# reader and never do the job it was dispatched for. That failure is fail-CLOSED (the
# intended agent never runs), which is the one direction this file does not tolerate,
# so the guard is not optional. Ignoring the key on a non-firewall dispatch costs
# nothing: that dispatch then behaves byte-identically to how it behaves today.
firewall_shaped = (subagent_type == "thalura:read-regulations") or bool(doc_keys)

files = sorted(glob.glob(os.path.join(pmdir, "**", "*.pagemap.json"), recursive=True))
if not files:
    sys.exit(14)

# Build the on-disk vocabulary: all document_ids (registry vocab) and, per page-map,
# its section anchors + freshness coordinates. `parts` is the page-map's path segments
# relative to the page-map root, lowercased — the regulations tree is
# <state>/<school-type-or-shared>/<subject>/<stem>.pagemap.json, so the teacher's
# school type appears there verbatim on a school-type-scoped document.
registry_ids = []
maps = []  # {document_id, sha, index_version, sections:[anchor,...], parts:[...]}
sidecar_unreadable = False
for f in files:
    try:
        # `errors` spelled out, and STRICT on purpose — see the key-path decode comment
        # above. A sidecar that is not valid UTF-8 must land in the branch below, which
        # disables the school-type validation loudly, rather than be half-read into an
        # anchor vocabulary that then resolves a coordinate.
        d = json.load(open(f, encoding="utf-8", errors="strict"))
    except Exception:
        # A sidecar that will not parse is NOT neutral any more. The school-type
        # validation below decides whether a document has two editions by counting the
        # distinct freshness coordinates carried by the page-maps of that document_id --
        # so dropping one edition on the floor makes a SPLIT document look single-edition
        # and silently switches that safety rule off for exactly the document whose
        # metadata is broken. Record it and suppress the HIT path wholesale below.
        # Direction: fail-open (a normal read follows). A corrupt sidecar is a broken
        # install; it should cost a read, never a wrong-edition serve.
        sidecar_unreadable = True
        continue
    if not isinstance(d, dict):
        sidecar_unreadable = True
        continue
    # A sidecar that PARSES but is structurally malformed is the same hazard as one that
    # does not parse at all, and it used to be waved through with a bare `continue`. That
    # dropped the edition on the floor exactly as a parse failure does -- so a SPLIT
    # document looked single-edition, split_editions below computed False, the school-type
    # validation never fired, and a teacher of one school type was handed the other
    # edition's digest marked authoritative. Measured on a two-edition document with the
    # gymnasium sidecar's `document_id` key deleted: the gate DENIED and served the
    # stadtteilschule text. Rule 5's own comment above describes this hazard; the guard
    # simply has to take the same exit as the parse failure does.
    did = d.get("document_id")
    if not isinstance(did, str) or not did:
        sidecar_unreadable = True
        continue
    # The freshness coordinate is type-checked in the SAME pass and for the same reason,
    # with one extra edge: split_editions builds a SET of (sha, index_version), so a value
    # of a mutable type (a JSON array or object reaching either field) raises
    # `TypeError: unhashable type` and kills the whole derive. That one fails OPEN, so it
    # costs a read rather than a wrong serve -- but it is the same class, and the same
    # exit answers both. A missing sha stays legal here (None is hashable and is rejected
    # later, at the point where it would actually be used); a sha of any other scalar type
    # is a broken install and takes the unreadable exit.
    sha = d.get("source_pdf_sha256")
    idxv = d.get("index_version")
    if not isinstance(sha, (str, type(None))) or isinstance(idxv, (list, dict)):
        sidecar_unreadable = True
        continue
    secs = []
    for s in (d.get("sections") or []):
        if isinstance(s, dict):
            a = s.get("section_anchor")
            if isinstance(a, str) and a.strip():
                secs.append(a)
    try:
        rel = os.path.relpath(f, pmdir)
    except Exception:
        rel = f
    parts = [p.lower() for p in rel.split(os.sep) if p not in ("", ".", "..")]
    if did not in registry_ids:
        registry_ids.append(did)
    maps.append({"document_id": did, "sha": sha, "index_version": idxv,
                 "sections": secs, "parts": parts})

# Match the DECLARED section to a (document, section) coordinate. The prompt's free text
# is no longer read for anchors at all: a section is served only if the dispatch named it
# on a `section_anchor:` line of its own, and only on fold-normalized EQUALITY with a
# page-map anchor. The rule this replaced tested whether any anchor occurred as a
# SUBSTRING of the whole prompt, which could not tell a request from a mention.
#
# DOCUMENT-SCOPED (load-bearing). Section headings REPEAT across the corpus: "2.2
# Fachliche Kompetenzen" is a section of eight different Bildungsplan documents, and
# 103 of the 659 distinct anchors appear in >=2 documents — precisely the most common
# curriculum-anchoring targets. A corpus-wide anchor search therefore collects N>1
# coordinates on exactly the reads that matter, trips the exactly-one precondition, and
# fails open every time: the veto becomes a no-op in its most common case. The dispatch
# prompt's own `document_id:` key resolves this for free — scope the anchor search to the
# document the dispatch actually named, and the eight candidates collapse to one.
#
# EXACTLY-ONE-DISTINCT-MATCH precondition (load-bearing, fail-open). A HIT here DENIES
# the whole Agent dispatch, but a reader dispatch is per DOCUMENT and its Read scope
# routinely spans SEVERAL sections. So a "longest anchor wins" pick would let a dispatch
# needing §2 AND §4 resolve to the one of them that happens to be cached, deny the whole
# dispatch, and silently lose the other section. Therefore: resolve ONLY when the prompt
# matches exactly ONE distinct (document_id, section_anchor) coordinate. Two or more
# DISTINCT coordinates -> fail open (a normal read follows; the reader still runs its own
# per-section cache get, so the already-remembered sections are still not re-read — a
# cheaper read, never a lost one).
matches = {}  # (document_id, section_anchor) -> [page-map, ...] (the SAME coordinate can
              # legitimately live in several page-maps — see the school-type split below)
# PRECONDITION 0: a complete on-disk vocabulary. See sidecar_unreadable above.
if sidecar_unreadable:
    sys.exit(15)
# EXACTLY ONE DECLARED SECTION, or nothing is served. Zero declarations is the ordinary
# case for a `full` or legacy-shaped dispatch and is NOT an error -- the gate simply has
# no coordinate, the dispatch falls through to the MISS spine below, and a reader runs.
# Two or more is the well-formed multi-section dispatch: a deny turns back the WHOLE
# dispatch, so answering one of the sections asked for would silently lose the rest.
if len(sec_keys) != 1:
    sys.exit(16 if not sec_keys else 17)
want_sec = sec_keys[0]
# The document key is compared CASE-INSENSITIVELY, because the sibling canonicalizer that
# actually builds the key lowercases the document_id: a dispatch that spells it
# `Bildungsplan-Sek1-Philosophy` keys the very same entry, so a byte-exact compare here
# would refuse to serve an entry that a reader on the other side of the same dispatch
# would find. Fail-open either way -- this only widens LEGITIMATE hits -- and the page-map's
# own spelling is still what is carried into the identity (see below).
want_doc_cmp = want_doc.lower()
for m in maps:
    did = m["document_id"]
    if want_doc_cmp and did.lower() != want_doc_cmp:
        continue
    for anc in m["sections"]:
        # EQUALITY, NEVER CONTAINMENT. Containment is how the sibling canonicalizer
        # re-points an abbreviated anchor onto a neighbouring section of the same
        # document; admitting it here would rebuild this issue's defect out of the very
        # key that exists to close it. A declared anchor that is a strict prefix of a
        # real one therefore matches NOTHING and fails open, which is the correct answer:
        # the gate cannot tell which section a partial name meant.
        if fold(anc) == want_sec:
            matches.setdefault((did, anc), []).append(m)

if len(matches) != 1:
    sys.exit(18 if not matches else 19)
# The anchor carried forward is the PAGE-MAP's verbatim spelling, never the caller's:
# cache.py hashes this string into the key, so a folded or re-cased value would name a
# file that was never written and turn every entry into a miss.
(document_id, section_anchor), cands = list(matches.items())[0]

# SCHOOL-TYPE DISAMBIGUATION (never a dict overwrite). One document_id can name two
# genuinely different PDFs — one per school-type tree, with different source_pdf_sha256.
# Collapsing them into a dict let the alphabetically-later tree (stadtteilschule) silently
# overwrite the earlier (gymnasium), so a Gymnasium teacher's read derived the WRONG sha:
# a permanent miss at best, and — if the other school type's entry were ever cached — a
# HIT serving that school type's regulation content back as authoritative. Freshness
# coordinates that agree collapse harmlessly; coordinates that DISAGREE are resolved ONLY
# by the teacher's own school type, and by nothing else. No school type, or still not
# exactly one candidate -> fail open (a normal read follows; nothing is guessed).
#
# IT IS A VALIDATION, NOT A TIE-BREAK, AND THAT DISTINCTION IS THE WHOLE FIX HERE. The
# check used to run only when the matched anchor produced MORE THAN ONE candidate. An
# anchor that exists in only one edition's page-map yields a single candidate, skipped
# the check entirely, and was served with no comparison at all -- so a teacher of one
# school type was handed the other school type's edition, marked authoritative. The two
# worst members of that class are a matched pair: "3b) Klassenarbeiten ... des
# Gymnasiums" against "3b) ... der Stadtteilschule".
#
# Making the match EXACT (above) does not fix this on its own; it makes it WORSE. Of the
# 44 pack-present anchors unique to one edition, 11 are today protected only by accident
# -- a shorter sibling anchor of the same document is a substring of the declared one, so
# the old scan collected two coordinates and fell open. Exact matching removes that
# accident along with the protection, taking the reachable surface from 33 entries to 44.
# The declared-scope key and this validation are one change, not two.
#
# The predicate is FRESHNESS-COORDINATE distinctness, not path multiplicity: two trees
# holding the byte-identical PDF are one edition sitting in two places, and gating them
# would cost hits to prevent nothing.
# The editions are grouped case-insensitively, for the same reason the document key is
# compared that way above and as a direct consequence of it: a case-variant sidecar now
# reaches `matches`, so grouping the editions byte-exactly would count one edition where
# two exist and switch this validation off -- the same hazard the malformed-sidecar guard
# above closes, arriving through a spelling difference instead of a broken file.
_did_cmp = document_id.lower()
split_editions = len({(m["sha"], m["index_version"])
                      for m in maps if m["document_id"].lower() == _did_cmp}) > 1
if split_editions:
    cands = [c for c in cands if school_type and school_type in c["parts"]]
coords = []
for c in cands:
    coord = (c["sha"], c["index_version"])
    if coord not in coords:
        coords.append(coord)
if len(coords) != 1:
    sys.exit(20 if (split_editions and not school_type)
             else (21 if (split_editions and not coords) else 22))
sha, index_version = coords[0]
if not isinstance(sha, str) or not sha or index_version is None:
    sys.exit(23)

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
# --- Step 1b: the side channel back to bash. THREE lines, in this order:
#       force | noforce
#       <document_id>
#       <section_anchor>
#
# Written HERE and nowhere else — at the very end, on the same path that emits the
# identity, AFTER anchor resolution and after every GIVE-UP EXIT above. Those are no longer
# a bare zero: each carries its own reason out in its exit code (10..23), which bash maps to
# one ASCII token. That placement IS
# precondition 1: a derive that gives up early writes nothing, the side file stays empty,
# and bash's existing identity guard sends the dispatch to `allow`. Nothing downstream
# can act on an override the derive was never confident enough to authorise.
#
# Lines 2 and 3 are whitespace-normalized before writing. document_id is only ever
# type-checked, never shape-checked, so a newline inside either value would desynchronise
# a three-line protocol that bash reads with three plain `read` calls — line 3 would then
# be read as line 2 and the coordinate reported to the caller would be a lie.
#
# UTF-8 bytes explicitly, same discipline as the identity emit above and for the same
# reason: a section anchor is German.
#
# FAIL-OPEN DIRECTION, and this is the ONE new path that fails in the unhelpful
# direction. If this write fails, bash reads no verdict, the override is simply NOT
# applied, and a requested re-read is denied exactly as it is today. That is bounded and,
# crucially, NOT silent: the caller receives the deny reason, which names the exact key
# spelling and invites one more attempt.
try:
    with open(sys.argv[4], "wb") as _sfh:
        _sfh.write(b"force\n" if (force_asked and firewall_shaped) else b"noforce\n")
        _sfh.write((norm(document_id) + "\n").encode("utf-8", "replace"))
        _sfh.write((norm(section_anchor) + "\n").encode("utf-8", "replace"))
except Exception:
    pass

# UTF-8 BYTES, explicitly. A section anchor is German (a section sign, an umlaut), and
# emitting it through the interpreter default raises under a non-UTF-8 locale — which
# would leave the identity file empty and silently fail-open EVERY cached dispatch on
# such a host. cache.py reads this file as UTF-8 on the other side.
sys.stdout.buffer.write(json.dumps(identity, ensure_ascii=False).encode("utf-8", "replace"))
PY
derive_rc=$?
rm -f "$EVENT_FILE" 2>/dev/null

# --- Did the derive produce a cache COORDINATE? This used to be the same question as
# "should this hook do anything at all", and conflating the two was a latent trap that
# only sprang once the coordinate got stricter.
#
# The MISS spine below does two things that have NOTHING to do with the cache: it injects
# the envelope MANDATE and it rewrites subagent_type to the reader handle. Both were
# gated on the derive having resolved a (document, section) coordinate, purely because
# one derive happened to compute both. With the coordinate now requiring a DECLARED
# section, every dispatch that declares none -- a `full` read scope, a multi-section read,
# a legacy-shaped prompt -- would have lost the mandate and the rewrite silently. On the
# observed general-purpose fallback path that is the worse half: without the rewrite the
# reader body never loads, so the reader-side half of the cache override never binds
# either, and a caller asking for a fresh read would get the remembered one back.
#
# So the two verdicts are separated. The coordinate governs the DENY; the dispatch's
# SHAPE governs the spine, and the spine tests that for itself below.
HAVE_ID=""
{ [ "$derive_rc" = 0 ] && [ -s "$ID_FILE" ]; } && HAVE_ID=1

# --- THE DERIVE'S VERDICT, AS ONE ASCII TOKEN. The channel is the derive's EXIT CODE,
# which bash already read one line above: no new file, no new descriptor, no new cleanup
# path in a hook that must never fail closed, and nothing decoded, so the token is
# identical under every locale.
#
# WHY THIS EXISTS. Fourteen distinct give-up shapes are reachable here, and every one of
# them -- plus the true cold miss, which is the normal correct outcome -- used to emit the
# byte-identical `event=get-miss mandate=injected subagent_type=rewritten`. A safety rule
# FIRING left the same trace as the system working, so the audit log could not answer the
# one question it exists for.
#
# The `*)` arm is TOTAL and that is load-bearing twice over: `set -u` is in force, so an
# unset $DERIVE at any emitter below would abort this hook with an unbound-variable error
# and emit NOTHING AT ALL -- not {}, not a deny -- which is outside every fail-open path
# this file promises. And an unmapped code (a raise -> 1, a signal -> 128+n, a missing
# interpreter -> 127) is genuinely `derive-failed`, which is a true statement about all
# of them rather than a guess at which.
#
# Fail-open direction: none. This is a `case` over an integer -- builtins only, no
# subprocess -- and the token is consumed ONLY inside audit_get, which is best-effort by
# construction and whose result nothing tests.
case "$derive_rc" in
  0)  DERIVE=resolved ;;
  10) DERIVE=event-unreadable ;;    11) DERIVE=event-not-dict ;;
  12) DERIVE=no-prompt ;;           13) DERIVE=document-arity ;;
  14) DERIVE=no-pagemaps ;;         15) DERIVE=sidecar-unreadable ;;
  16) DERIVE=no-declaration ;;      17) DERIVE=declaration-arity ;;
  18) DERIVE=anchor-unknown ;;      19) DERIVE=anchor-arity ;;
  20) DERIVE=school-type-unknown ;; 21) DERIVE=school-type-mismatch ;;
  22) DERIVE=edition-ambiguous ;;   23) DERIVE=identity-incomplete ;;
  *)  DERIVE=derive-failed ;;
esac
# rc 0 with an EMPTY identity file is its own outcome and must not be reported as
# `resolved`: the derive claimed success and produced no coordinate.
[ -n "$HAVE_ID" ] || [ "$DERIVE" != resolved ] || DERIVE=empty-identity

# --- Read the derive's side channel. Builtins only: no sed, no cut (never run either
# over text that can hold an em dash or an umlaut), no subprocess.
#
# ALL FOUR VARIABLES ARE PRE-INITIALIZED, and that is not tidiness. `set -u` is in force
# at the top of this file. If the side file is absent, the redirect fails, the group
# never runs, `_fl` is never assigned, and the test below aborts the whole script with
# an unbound-variable error — at which point this hook emits NOTHING AT ALL: not {}, not
# a deny. That is outside every fail-open path this file's header promises, so the
# pre-init is what keeps the promise.
#
# `2>/dev/null` comes BEFORE `< "$SIDE_FILE"`: redirections apply left to right, and with
# the stderr redirect second a missing file's error reaches the real stderr.
#
# `|| true` absorbs the exit code — including the benign non-zero from a missing trailing
# newline on line 3, which still assigns the partial line correctly — but it absorbs only
# the code, never the unbound reference. Both are needed.
#
# Fail-open direction: anything unreadable here leaves FORCED empty, so the gate behaves
# exactly as it does today. For an override that is the unhelpful direction (the stale
# entry is served again) but never the unsafe one, and the deny reason names the key so
# the caller can try once more.
FORCED=""; _fl=""; HIT_DOC=""; HIT_ANCHOR=""
{ IFS= read -r _fl; IFS= read -r HIT_DOC; IFS= read -r HIT_ANCHOR; } 2>/dev/null < "$SIDE_FILE" || true
[ "$_fl" = "force" ] && FORCED=1
rm -f "$SIDE_FILE" 2>/dev/null

if [ -z "$HAVE_ID" ]; then
  # --- No cache coordinate. NOT an exit any more (see HAVE_ID above). Fake a MISS exactly
  # as the force arm does and fall through to the spine, which applies its own
  # firewall-shape test and emits nothing for a dispatch that is not one.
  #
  # THE CAUSES, ENUMERATED — because this arm now carries traffic that used to leave as a
  # bare {}, and a two-item list invited the reading that it is only about a `full` scope:
  #   * the dispatch declared NO section (a `full` Read scope, a legacy-shaped prompt);
  #   * it declared TWO OR MORE distinct sections (the arity rule — a deny would turn back
  #     the whole dispatch and silently lose the sections it did not answer);
  #   * it declared one the page-maps do not know (invented, shortened, stale, or re-typed
  #     across a fold this table does not cover — see the fold comment above);
  #   * it named TWO OR MORE distinct document_id: keys, so which document it wants is
  #     ambiguous;
  #   * ANY page-map sidecar in the tree is unreadable or structurally malformed (rule 5:
  #     a partial vocabulary silently disables the school-type validation);
  #   * THE SCHOOL-TYPE VALIDATION FAILED — a multi-edition document whose candidates do
  #     not include the teacher's own school type, or a teacher whose school type is not
  #     resolvable at all. Worth naming first among the safety cases: this dispatch is
  #     firewall-shaped and WILL now receive the mandate and the subagent_type rewrite
  #     where it used to receive a bare {}, so a wrong-edition read that the gate refused
  #     to serve from cache still goes on to be read properly, with the envelope contract
  #     attached;
  #   * the resolved candidates disagree on their freshness coordinate, or the one they
  #     agree on is unusable (no sha, or no index_version);
  #   * there are no page-maps at all, the event was malformed, or the prompt was empty;
  #   * the derive raised, timed out, or its identity file came back empty.
  #
  # Fail-open direction: unchanged from before in every respect that can produce a deny --
  # no identity still means no HIT and no deny, ever. What changed is only that a
  # firewall-shaped dispatch now still receives the envelope mandate on its way through.
  get_rc=1
  ENTRY=""
  rm -f "$ID_FILE" 2>/dev/null
elif [ -n "$FORCED" ]; then
  # --- The override, granted. Steps 2 and 3 are SKIPPED outright: no derive-identity,
  # no cache.py get. Faking a MISS (get_rc=1, empty entry) rather than jumping straight
  # to `allow` is the whole point — a bare allow would send the dispatch on WITHOUT the
  # envelope mandate and without the subagent_type rewrite, so the forced read would
  # produce no envelope and never reach the cache writer, and the caller would be left
  # with the same broken entry after paying for a full read.
  #
  # Verified about the variables this arm fakes: neither is read anywhere before the HIT
  # test below, and the entry is read nowhere after it, so this is a complete and local
  # falsification of the deny branch — the branch itself is not touched.
  #
  # Fail-open direction: there is no failure path here to speak of. The audit append is
  # best-effort by construction (see audit_get) and nothing tests its result.
  audit_get "event=get-force action=cache-bypassed resolution=declared document_id=$HIT_DOC section_anchor=$HIT_ANCHOR"
  get_rc=1
  ENTRY=""
  rm -f "$ID_FILE" 2>/dev/null
else
  # --- No override asked for (the overwhelmingly common case): Steps 2 and 3 exactly as
  # they have always been, byte for byte. A dispatch carrying no whole-line key never
  # reaches the arm above, so nothing about its outcome can have moved.

  # --- Step 2: route the key through cache.py (single source) — assert section-keying.
  # derive-identity recomputes the sha over the section coordinates ONLY; if it can't,
  # fail-open. (get also recomputes the key; deriving it here makes the section-key
  # discipline explicit and guards against any future drift.)
  # PYTHONIOENCODING pins cache.py's OWN streams to UTF-8. This hook reads and writes
  # every byte it handles through an explicit codec, but cache.py is a separate script
  # that prints German digest text through python's locale-derived stdout: on a non-UTF-8
  # host that raises, the get below returns non-zero, and EVERY cached entry silently
  # turns into a MISS. The pin is exactly the default on a UTF-8 host, so it changes
  # nothing there and makes every other host behave the same way.
  # The audit line is NEW: this was one of the two paths that emitted nothing at all, so
  # a dispatch that reached the cache layer and was turned away by it left no artifact
  # anywhere and could not be told from a hook that never ran. audit_get stays
  # best-effort by construction, so adding it changes no outcome — the `allow` is
  # unchanged and unconditional.
  run_cap env PYTHONIOENCODING=utf-8 python3 "$CACHE_PY" derive-identity --identity "$ID_FILE" >/dev/null 2>&1 \
    || { rm -f "$ID_FILE" 2>/dev/null; audit_get "event=get-miss derive=$DERIVE mandate=derive-identity-failed"; allow; }

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
  # Second of the two formerly silent give-ups — same reasoning as the one above.
  ENT_OUT="$(mktemp 2>/dev/null)" || { rm -f "$ID_FILE" 2>/dev/null; audit_get "event=get-miss derive=$DERIVE mandate=entry-mktemp-fail"; allow; }
  run_cap env PYTHONIOENCODING=utf-8 python3 "$CACHE_PY" get --identity "$ID_FILE" >"$ENT_OUT" 2>/dev/null
  get_rc=$?
  ENTRY="$(cat "$ENT_OUT" 2>/dev/null)"
  rm -f "$ENT_OUT" "$ID_FILE" 2>/dev/null
fi

# --- Step 4a: HIT -> DENY, delivering the cached digest in the deny reason.
# The dispatch never runs; the main session reads the digest straight out of the
# reason. Deny emitter shape copied from fanout-gate.sh: python3-built for correct
# escaping, degrading to the exit-2/stderr channel if that emit fails (still a deny
# that CARRIES the digest — never a silent allow that would re-spawn the reader).
# Reaching here means the derive SUCCEEDED and cache.py returned a fresh entry: the
# ONLY path in this hook that is allowed to deny.
if [ "$get_rc" = 0 ] && [ -n "$ENTRY" ]; then
  # The served coordinate rides the audit line too. Without it a wrong-section HIT leaves
  # no artifact anywhere: the log said a deny happened, never WHICH section was handed
  # over instead of the one asked for, so the failure could not be reconstructed after
  # the fact from a session export. Both values can legitimately be empty, and an empty
  # `key=` token is a perfectly readable log line. audit_get passes "$*" as a printf
  # ARGUMENT to %s, never as a format string, so a percent sign inside an anchor is safe.
  audit_get "event=get-hit action=deny mandate=cache-digest-delivered resolution=declared document_id=$HIT_DOC section_anchor=$HIT_ANCHOR"
  # Best-effort side effect, deliberately BEFORE the emit and deliberately unchecked:
  # the vetoed dispatch's reader slot is released early rather than at its TTL. Every
  # failure inside is swallowed; nothing below depends on it. See reader_tombstone().
  reader_tombstone
  # --- The served coordinate, and the sentence that names it.
  #
  # Taken from the identity THIS hook derived in Step 1 and carried in bash variables.
  # NEVER parsed out of "$ENTRY", and that restriction is the whole design of this block:
  # a new parse on this one branch could fail and leave the reason EMPTY, and the emitter
  # below would then deliver a deny with no reason and no digest — strictly worse than
  # the stale serve this change exists to make recoverable. The derived identity cannot
  # fail here; it is also the coordinate whose wrongness the caller has to notice.
  #
  # Both variables can legitimately be empty (a side-channel write that did not land).
  # The sentence is then simply omitted and every other part of the reason still emits —
  # a reason WITHOUT the coordinate, never an absent reason. Pure bash interpolation, no
  # extra process, for exactly the same reason.
  HIT_COORD=""
  if [ -n "$HIT_DOC" ] && [ -n "$HIT_ANCHOR" ]; then
    HIT_COORD="What was served: document_id $HIT_DOC, section_anchor $HIT_ANCHOR. Check
that this really is the section the question is about.
"
  fi
  # The reason states what is true and stops there. It used to close every door — the PDF
  # "must not be opened again", "do not re-dispatch it" — and that shut the one action
  # that recovers from a wrong or too-thin serve. It now scopes the instruction to the
  # case it was right about (an UNCHANGED re-dispatch, which returns this same digest) and
  # names the way out for the case it was wrong about.
  #
  # The escape hatch is spelled out literally, because a caller cannot guess it: the key
  # is one exact token, and every plausible-looking alternative is inert by design. It is
  # named INLINE, inside a sentence, never as a line of its own — the key is whole-line
  # anchored, so a standalone line here would make this very text a key the moment a model
  # quoted it into a later prompt.
  HIT_REASON="A cached, citation-verified regulation digest for the requested section
is delivered inline below. It is freshness-checked against the source document, so
NO reader sub-agent is needed for it and the source PDF need not be opened again for
this section — this dispatch has been stopped before any read cost. Use the digest
below directly as the result of this read.
${HIT_COORD}Do not re-dispatch this read unchanged: unchanged, it returns this same
digest. If — and only if — the section served does not answer the question that was
asked, because it is the wrong section or was read too narrowly the first time, then
re-dispatch this read ONCE with one added line reading exactly: cache: force-reread
(a whole line of its own, nothing else on it). That makes the cache step aside and
the document be read afresh.

=== CACHED DIGEST (authoritative — use verbatim) ===
$ENTRY
=== END CACHED DIGEST ==="
  # Explicit UTF-8 on BOTH streams. The reason carries a cached German digest, so reading
  # it through the interpreter default (the ambient locale) would decode it to a different
  # string, and writing it back through the default would raise outright on a non-UTF-8
  # host - turning the digest delivery into the stderr fallback for no reason.
  DENY_JSON="$(printf '%s' "$HIT_REASON" | python3 -c '
import json, sys
reason = sys.stdin.buffer.read().decode("utf-8", "replace")
out = {"hookSpecificOutput": {"hookEventName": "PreToolUse",
                              "permissionDecision": "deny",
                              "permissionDecisionReason": reason}}
sys.stdout.buffer.write((json.dumps(out, ensure_ascii=False) + "\n").encode("utf-8", "replace"))
' 2>/dev/null)" || DENY_JSON=""
  if [ -n "$DENY_JSON" ]; then
    printf '%s\n' "$DENY_JSON"
    exit 0
  fi
  # json emit failed (e.g. python3 vanished mid-run) -> the exit-2 deny channel.
  printf '%s\n' "$HIT_REASON" >&2
  exit 2
fi

# --- Everything below is the MISS spine (Step 4b).
# The original dispatch prompt (the only free-text input).
#
# BOTH ENDS PINNED, AND THIS ONE WAS THE WHOLE OF THE RESIDUAL. `json.load(sys.stdin)`
# decoded the event with the ambient locale codec: under a non-UTF-8 one a German prompt
# raised UnicodeDecodeError, the bare `except Exception` swallowed it, ORIG_PROMPT came
# back EMPTY, every field derived from it came back empty, and the hook exited 0 with an
# empty stderr — so the reader-mandate spine silently stopped being injected for
# EVERY dispatch on such a host while the hook looked perfectly healthy. That is the same
# swallowed-decode failure the envelope parser carries, reproduced verbatim in another file.
#
# THE DECODE IS NOW OUTSIDE THE `try`, deliberately: with errors="replace" it cannot
# raise at all, so the except below is structurally incapable of swallowing a decode
# failure into an empty string. What remains inside is only the JSON parse, which is the
# one thing that failure branch was ever meant to catch.
#
# `replace`, not `strict`: this is the DISPLAY path (the prompt is forwarded to a reader),
# where a U+FFFD is an acceptable loss and a raised decode would be a fail-CLOSED crash.
# The strict rule applies to the identity/key path only — see the derive above.
#
# THE `prompt` VALUE IS isinstance-GUARDED, exactly like the `cwd` and `session_id` reads
# at the top of this file and the same check the sibling gates carry. `ti.get("prompt","")`
# returns the DEFAULT only on an ABSENT key: a present-but-null `"prompt": null` returns
# None, `None + "\n"` raises TypeError, the traceback is swallowed by `2>/dev/null`, and
# ORIG_PROMPT comes back empty — at which point the spine below prepends the mandate to
# nothing and the dispatch prompt BECOMES THE MANDATE ALONE, its actual instruction gone.
# The guard turns that into an ordinary empty prompt, which the spine already handles.
ORIG_PROMPT="$(printf '%s' "$EVENT" | python3 -c '
import json,sys
def emit(s): sys.stdout.buffer.write((s + "\n").encode("utf-8", "replace"))
raw=sys.stdin.buffer.read().decode("utf-8", "replace")
try: e=json.loads(raw)
except Exception: emit(""); sys.exit(0)
if not isinstance(e,dict): emit(""); sys.exit(0)
ti=e.get("tool_input") or {}
p=ti.get("prompt") if isinstance(ti,dict) else None
emit(p if isinstance(p,str) else "")' 2>/dev/null)"

# The FULL original tool_input as compact JSON. The MISS rewrite MERGES onto this
# so the Agent tool's REQUIRED params survive — above all `description`. The runtime
# validates updatedInput as the REPLACEMENT tool input, so a fresh {prompt:…} object
# drops `description` and the dispatch is rejected ("required parameter 'description'
# is missing"). Single-line (json.dumps escapes newlines) -> safe to pass as argv.
# Both ends pinned, same reasoning as ORIG_PROMPT above and the same structure: the
# decode sits outside the `try` because errors="replace" cannot raise.
#
# `json.dumps(ti)` KEEPS its default ensure_ascii=True, and that is not an oversight.
# The result is handed to the next interpreter as an ARGV PAYLOAD, and argv is decoded
# with the locale's FILESYSTEM encoding (ascii under LC_ALL=C on Linux) — the third
# channel neither the -c source scan nor the stream pins cover. Escaping every non-ASCII
# character here keeps that payload pure ASCII, so the value survives the crossing
# byte-exactly whatever the locale; emitting real UTF-8 bytes into argv is precisely the
# defect recorded for the two sibling hooks.
ORIG_TI="$(printf '%s' "$EVENT" | python3 -c '
import json,sys
raw=sys.stdin.buffer.read().decode("utf-8", "replace")
def emit(s): sys.stdout.buffer.write(s.encode("utf-8", "replace"))
try: e=json.loads(raw)
except Exception: emit("{}"); sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
emit(json.dumps(ti) if isinstance(ti,dict) else "{}")' 2>/dev/null)"
[ -n "$ORIG_TI" ] || ORIG_TI="{}"

# --- Step 4b: firewall-shaped MISS (derive succeeded, no cached entry) -> THE SPINE.
# Inject the envelope MANDATE into the dispatch prompt via updatedInput.prompt,
# REGARDLESS of subagent_type. The mandate is the same literal G1 contract the named
# agent body carries; injecting it host-side closes emission even on the observed
# `general-purpose`-fallback path (the link that broke twice). Bonus (allowed to be
# ignored by the runtime): set subagent_type -> thalura:read-regulations. Idempotent:
# if the prompt ALREADY carries the mandate marker, do not prepend a second copy.
STATE_FILE="$(mktemp 2>/dev/null)" || { audit_get "event=get-miss derive=$DERIVE mandate=mktemp-fail"; allow; }
HOOK_JSON="$(printf '%s' "$ORIG_PROMPT" | python3 -c '
import json, os, re, sys
orig = sys.stdin.buffer.read().decode("utf-8", "replace")
try:
    ti = json.loads(os.fsencode(sys.argv[1]).decode("utf-8", "replace")) if len(sys.argv) > 1 else {}
    if not isinstance(ti, dict): ti = {}
except Exception:
    ti = {}

# --- IS THIS DISPATCH FIREWALL-SHAPED? The spine tests it here, for itself, rather than
# inheriting the answer from whether a cache coordinate resolved (see HAVE_ID in the
# bash above). Same test the derive applies, on the same two signals: the reader handle,
# or a line-anchored document_id: key.
#
# A DECLARED SECTION ANCHOR IS DELIBERATELY NOT A THIRD SIGNAL. Every dispatch key on
# this surface gets printed somewhere -- in a deny reason, in a contract, in a changelog
# -- and any agent whose prompt merely QUOTES one must not be silently converted into a
# regulation reader and never do the job it was dispatched for. That failure is
# fail-CLOSED, the one direction this file does not tolerate.
#
# WHAT ACTUALLY CHANGED, STATED HONESTLY. These two signals did NOT already carry that
# guarantee on their own: until the spine was re-gated, it ran only where the derive had
# resolved a (document, section) COORDINATE, so a prompt merely quoting a bare
# `document_id:` line reached the rewrite only if that line also named a real document AND
# the prompt declared a section the page-maps knew. The coordinate was doing the work, as
# a side effect of a verdict that was about the cache. Gating on shape is the correct
# rule -- neither job of the spine has anything to do with the cache -- but it does WIDEN
# the rewritten set to every prompt carrying a well-formed `document_id:` line, so the
# guard above is now the only thing standing between that line and a converted dispatch.
#
# THE RESIDUAL, RECORDED RATHER THAN IMPLIED: the OWN output of this hook re-emits the
# `document_id:` line it was handed, inside updatedInput.prompt. A model that later quotes
# that rewritten prompt into an unrelated dispatch -- a summary, a bug report, a hand-off
# -- hands that dispatch the very key that makes it firewall-shaped, and it is converted
# into a regulation reader. The mandate and the reader handle are both visible in the
# result, so it is loud rather than silent, and no path here can turn such a dispatch into
# a DENY. Narrowing it would mean this hook stripping the document key out of the prompt it
# is forwarding, which costs the reader the coordinate it was dispatched with.
#
# Emitting NOTHING here is how a non-firewall dispatch is left alone: bash sees an empty
# hook payload and falls through to allow, byte-identically to today.
docpat = re.compile(r"\s*document_id:\s*(\S+)\s*$")
has_doc_key = any(docpat.match(ln) for ln in orig.split("\n"))
st = ti.get("subagent_type")
if not isinstance(st, str):
    st = ""
if not (st == "thalura:read-regulations" or has_doc_key):
    # Explicit bytes on the way out, exactly like the identity emit and the state emit
    # below. The value is ASCII today, so this raises on no host -- and that is the
    # point: the shape of the write is what stops a later edit from putting a German
    # word here and silently turning this branch into a traceback whose only visible
    # effect is that the whole hook fail-opens.
    sys.stderr.buffer.write(b"not-firewall-shaped")
    sys.exit(0)

# --- THE DECLARED ANCHOR, REWRITTEN TO THE SPELLING THE PAGE-MAP USES (argv[3]: the
# verbatim anchor the derive resolved, handed over the same side channel the deny reason
# is built from).
#
# WHY THE GATE HAS TO DO THIS, AND WHY IT CANNOT BE LEFT TO THE EMITTER. This gate matches
# a declared anchor FOLD-NORMALIZED, so a RE-TYPED one -- ASCII punctuation for the corpus
# typography, the wrong case -- resolves and is served. The WRITER has no such tolerance:
# the reader keys its own PUT off the declaration it was handed verbatim, and the sibling
# canonicalizer repairs a near miss only by case-insensitive equality and leading-token
# containment, never by this fold. So on a cache-COLD section the re-typed declaration
# would travel this spine unchanged, the reader would store the entry under the RE-TYPED
# string, and the next identical dispatch would derive the string the page-map uses and
# miss again -- forever, leaving two entries on disk for one section and an ordinary
# `event=get-miss` in the log that is indistinguishable from a genuinely cold cache. The
# fold would then have bought nothing at all: every anchor it rescues on the read side it
# would strand on the write side. Normalizing here closes that structurally, on the side
# that already resolved the coordinate, instead of requiring a model to be byte-perfect.
#
# THE GUARD, AND ITS DIRECTION. Rewrite ONLY when the derive resolved an anchor (a
# non-empty argv[3] -- which is also the confidence signal of the derive itself, written
# at the very end of a successful resolution and nowhere else) AND the declaration lines
# in the prompt agree on exactly one value. Anything else -- no coordinate, or two
# different declared spellings -- leaves the prompt BYTE-IDENTICAL. That is the fail-open
# direction for a rewrite: the worst case is the miss-forever this exists to close, never
# a dispatch that asks for a section other than the one it named.
#
# ASCII ONLY in this block, exactly like the mandate below and for the same reason: this
# is a `python3 -c` source. The anchor is German and arrives as runtime DATA through argv
# (decoded from its own bytes, never through the locale codec), never as a literal here.
# NO APOSTROPHE ANYWHERE IN THIS SPAN either, for a second reason on the same channel: the
# source is a single-quoted shell word, which has no escape mechanism, so one apostrophe
# closes it and the rest of the program becomes shell.
hit_anchor = ""
if len(sys.argv) > 3:
    hit_anchor = " ".join(os.fsencode(sys.argv[3]).decode("utf-8", "replace").split())
if hit_anchor:
    _secpat = re.compile(r"\s*section_anchor:\s*(.*)$")
    _declared = []
    for ln in orig.split("\n"):
        _sm = _secpat.match(ln)
        if _sm:
            _v = " ".join(_sm.group(1).split())
            if _v and _v not in _declared:
                _declared.append(_v)
    if len(_declared) == 1 and _declared[0] != hit_anchor:
        _out = []
        for ln in orig.split("\n"):
            _sm = _secpat.match(ln)
            if _sm and " ".join(_sm.group(1).split()):
                _out.append("section_anchor: " + hit_anchor + ("\r" if ln.endswith("\r") else ""))
            else:
                _out.append(ln)
        orig = "\n".join(_out)

MARKER = "<thalura-digest version=\"1\">"
if MARKER in orig:
    new_prompt = orig
    state = "already-present"
else:
    mandate = (
        "MANDATORY OUTPUT CONTRACT (non-skippable): Return your digest ONLY inside a "
        "<thalura-digest version=\"1\"> envelope, ONE envelope per resolved section, each "
        "wrapping exactly one fenced json block whose object is "
        # The ellipsis is written as an ESCAPE, never as a literal byte: python decodes a
        # -c argument with the ambient locale codec, so one non-ASCII character anywhere
        # in this source raises a SyntaxError under a non-UTF-8 locale and this whole
        # mandate injection would silently stop happening on such a host. The runtime
        # string is identical either way.
        "{ \"identity\": {\u2026}, \"digest\": {\u2026} }. The version lives on the tag attribute, "
        "never inside the digest JSON. identity carries the resolved per-section identity "
        "(key_components, document_id, section_anchor, source_pdf_sha256, index_version, "
        "plus the registry document_id list and the page-map section_anchor list). Emitting "
        "answer prose WITHOUT the per-section envelope is a pipeline violation of the same "
        "hard-gate weight as the firewall boundary itself.\n\n"
        "--- Original dispatch instruction ---\n"
    )
    new_prompt = mandate + orig
    state = "injected"

# --- The reader directive, on a forced dispatch only.
#
# DELIBERATELY OUTSIDE the if/else above, and therefore on BOTH of its arms. This gate is
# not the only one on the path to a re-read: the reader itself runs its own cache lookup
# as its first step and stops there on a hit. Opening only this gate would be WORSE than
# denying: a whole reader lifecycle gets paid and the same stale digest comes back.
#
# The already-present arm is a real path, not a theoretical one: a sibling hook defers a
# dispatch when the reader ledger is full, and the caller re-issues it with the key still
# attached and, by then, the mandate already in the prompt. Computing the directive
# inside the else arm would hand exactly that re-issue an updatedInput with NO directive.
#
# Its own sentinel, tested exactly the way the mandate marker is, so a second pass over
# an already-directed prompt does not stack a second copy.
#
# The key is named INLINE, inside a sentence, and never as a line of its own. The key is
# whole-line anchored, so a standalone line here would turn this very text into a key the
# moment a model quotes it into some later prompt.
#
# ASCII ONLY in this block, as the mandate comment above explains at length: this is a
# `python3 -c` source, decoded with the ambient locale codec.
#
# Fail-open direction: if the flag never arrives (argv short, or the side channel failed
# upstream) the directive is simply not added and the dispatch is an ordinary
# cache-miss read. That costs a re-read of a section whose entry may still be wrong,
# which is the same place the caller already was.
forced = (len(sys.argv) > 2 and sys.argv[2] == "1")
DIRECTIVE = "[CACHE OVERRIDE]"
if forced and DIRECTIVE not in new_prompt:
    directive = (
        "[CACHE OVERRIDE] The caller asked for this section to be read AFRESH, because "
        "the remembered digest did not answer the question that was asked. For THIS "
        "dispatch only: skip your own step-0 cache lookup for the section(s) named "
        "below, open the source document, and store what you read exactly as you would "
        "on any normal cache-miss read -- the stored result replaces what was remembered "
        "before. The caller signalled this by adding a line reading exactly: cache: "
        "force-reread (a whole line of its own, nothing else on it). Treat a request "
        "WITHOUT that line as an ordinary read, where the remembered digest stands.\n\n"
    )
    new_prompt = directive + new_prompt

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
#
# EXPLICIT UTF-8 BYTES ON BOTH. The stdout write is the one that mattered: `out` carries
# the dispatch prompt, which is German, and `json.dumps(..., ensure_ascii=False)` onto a
# TEXT stdout hands those characters to the ambient locale codec, which raises under a
# non-UTF-8 one. The command substitution in bash then took its `||` branch and the hook
# logged `mandate=emit-fail` and fail-opened -- so on such a host the mandate and the
# subagent_type rewrite were simply gone, for every dispatch. ensure_ascii=False is KEPT:
# the goal is to emit real UTF-8 bytes, and the encode below is what makes that true
# regardless of locale.
sys.stderr.buffer.write(state.encode("utf-8", "replace"))
sys.stdout.buffer.write((json.dumps(out, ensure_ascii=False) + "\n").encode("utf-8", "replace"))
' "$ORIG_TI" "$FORCED" "$HIT_ANCHOR" 2> "$STATE_FILE")" || { rm -f "$STATE_FILE" 2>/dev/null; audit_get "event=get-miss derive=$DERIVE mandate=emit-fail"; allow; }
STATE="$(cat "$STATE_FILE" 2>/dev/null || echo injected)"
rm -f "$STATE_FILE" 2>/dev/null
# An empty payload is the spine declining a dispatch that is not firewall-shaped, or a
# genuinely empty emit. $STATE distinguishes them in the log, so the two never have to be
# told apart by guesswork after the fact. Either way: allow, unchanged.
[ -n "$HOOK_JSON" ] || { audit_get "event=get-miss derive=$DERIVE mandate=${STATE:-empty}"; allow; }
audit_get "event=get-miss derive=$DERIVE mandate=$STATE subagent_type=rewritten"
printf '%s\n' "$HOOK_JSON"
exit 0
