#!/usr/bin/env bash
# Advisory UserPromptSubmit setup-route gate. Re-asserts the workspace resolver's
# setup-vs-task routing decision on every prompt. On THALURA_SETUP_NEEDED it injects
# a SELF-VERIFYING routing directive (resolve the workspace first; route to setup
# only if genuinely un-onboarded) via hookSpecificOutput.additionalContext; on
# THALURA_AMBIGUOUS it injects the candidate folder leaves. On a resolved workspace
# it emits nothing (the load-bearing no-op-on-success).
#
# To keep the gate's own trace clean under the first-turn Branch-2b readiness
# race — the resolver can return SETUP_NEEDED on the very first host event of an
# already-set-up Cowork session (the sibling local_<id>.json is not yet written) —
# the SETUP_NEEDED arm performs ONE bounded, directory-triggered retry: iff the
# event cwd has an ancestor local_<id>/ DIRECTORY (the in-host-Cowork signal), it
# does a foreground sleep (D=1.0s) and re-runs the resolver once. If the retry now
# resolves, the gate no-ops; if it still returns SETUP_NEEDED it falls through to
# the self-verifying directive as before. With NO local_* ancestor dir (a genuine
# un-onboarded VM/CLI project) there is NO retry and NO added latency.
#
# This is an INJECTION, not a write: the model consumes the injected context in the
# same turn, so there is no host/VM disk round-trip and the host-hook-write-non-
# persistence finding does not bind it. The hook only READS (runs the resolver) and
# ADVISES; it never writes and never persists anything.
#
# Advisory only: it NEVER blocks the turn and NEVER exits non-zero-blocking (a block
# on this event would erase the teacher's submitted prompt). Fail-open: every failure
# mode — missing resolver, unreadable stdin, unresolved plugin root, resolver error —
# collapses to a no-op and exit 0. The retained startup prose is the backstop; this
# hook only raises the floor, never lowers it. Branches on the resolver's sentinel
# contract; names no read/render tool; carries no issuer/authority/school-type name.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/_resolve.sh"

EVENT="$(cat)"                      # the UserPromptSubmit event JSON from stdin
CAP="${THALURA_HOOK_TIMEOUT:-10}"   # script-level per-subprocess timeout (s)

emit_noop() { printf '{}\n'; exit 0; }   # fail-open: no-op, change nothing

# Empty / unreadable stdin carries no event and no cwd -> fail-open no-op. Do NOT
# fall back to the hook's own $PWD here: in the sandbox $PWD is the ephemeral working
# dir, and re-asserting routing against it is exactly what this gate warns against.
[ -n "$(printf '%s' "$EVENT" | tr -d '[:space:]')" ] || emit_noop

PROOT="$(thalura_plugin_root)"
# Resolver path is overridable for tests via THALURA_RESOLVER (a stub); otherwise
# the shipped resolver. Mirrors the sibling hooks' resolver-override convention.
RESOLVER="${THALURA_RESOLVER:-$PROOT/scripts/resolve-data-root.sh}"
[ -f "$RESOLVER" ] || emit_noop

# Pull the event cwd (python3 — robust to any payload shape). In Cowork the hook's
# own $PWD is the ephemeral outputs/ dir, not the teacher workspace, so the stdin
# cwd is the load-bearing input the resolver keys on.
#
# LOCALE-INDEPENDENT, BOTH ENDS. The event arrives as BYTES and is decoded
# UTF-8 with an EXPLICIT error handler, and the cwd is written back out as UTF-8
# BYTES — never through the interpreter default, which follows whatever locale the
# host process happens to run under. Under a non-UTF-8 one the implicit path cannot
# even emit a workspace path carrying an umlaut without raising, and this gate would
# then resolve against its own ephemeral $PWD instead of the teacher's folder while
# still looking healthy. errors="replace" is the display-path direction: a
# smudged path costs a no-op, never a block.
event_cwd="$(printf '%s' "$EVENT" | python3 -c '
import json,sys
def emit(s): sys.stdout.buffer.write((s + "\n").encode("utf-8", "replace"))
try: e=json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
except Exception: emit(""); sys.exit(0)
emit(e.get("cwd","") if isinstance(e,dict) and isinstance(e.get("cwd"),str) else "")' 2>/dev/null)"
[ -n "$event_cwd" ] || event_cwd="$PWD"

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

# Run the resolver, capturing its raw stdout regardless of its non-zero sentinel
# exit (SETUP_NEEDED -> exit 10, AMBIGUOUS -> exit 11, resolved path -> exit 0). The
# hook branches on the stdout line, never on the exit code, so the resolver's exit
# must not abort this hook.
#
# The resolver's stdout goes to a TEMP FILE and is read AFTER run_cap returns —
# NEVER through a command substitution. run_cap's
# no-`timeout` watchdog backgrounds `( sleep "$CAP"; kill ... ) &`, and killing the
# watchdog subshell does NOT kill its already-running `sleep` child. Inside `$(...)`
# that orphaned sleep inherits the substitution pipe's write end and holds it open
# until it exits (~CAP): the resolver answers in milliseconds, yet the directive
# would be assembled only AT the hooks.json timeout and the host would kill the hook
# before delivery — on every prompt, on any host without timeout/gtimeout. Writing
# to a file and reading it after return makes CAP the true wall-clock bound.
# Fail-open: no usable temp file -> no-op.
RES_OUT="$(mktemp 2>/dev/null)" || emit_noop
[ -n "$RES_OUT" ] || emit_noop
run_cap env THALURA_SESSION_DIR="$event_cwd" bash "$RESOLVER" >"$RES_OUT" 2>/dev/null
# First line only (the sentinel/path line — guards against a chatty resolver), via
# the bash builtin `read` (no forked reader; a builtin cannot be pipe-held).
ROOT=""
IFS= read -r ROOT < "$RES_OUT" 2>/dev/null || true
rm -f "$RES_OUT" 2>/dev/null || true

# Branch on the raw sentinel line; fail-open default is a no-op.
case "$ROOT" in
  THALURA_SETUP_NEEDED)
    # Defence-in-depth: the first-turn Branch-2b readiness
    # race means the resolver can return SETUP_NEEDED on the very first host event
    # of a set-up Cowork session (the sibling local_<id>.json is not yet written).
    # If the event cwd is demonstrably inside a host-Cowork session — an ancestor
    # path component local_<id>/ is a real DIRECTORY (the Branch-2b walk-up target,
    # resolve-data-root.sh, keyed on the DIR not the sibling .json which may be
    # absent on the racy turn-1 event, OQ-2) — perform ONE bounded retry: sleep D
    # then re-run the resolver once via the same temp-file + read-after-return
    # pattern (C2 pipe-hold discipline: foreground sleep, a SECOND mktemp, read
    # AFTER run_cap returns — never VAR="$(run_cap …)"). If the retry resolves,
    # fall through to the resolved-path no-op; if it still returns SETUP_NEEDED
    # (or ambiguous), emit the directive as today. With NO local_* ancestor dir we
    # are not in a host-Cowork session (a genuine un-onboarded VM/CLI project) ->
    # NO retry, NO added latency. The broad local_* glob may
    # over-fire on a look-alike dir; harmless — the re-run yields the same answer
    # and Option 2's self-verifying directive backstops any leaked advisory.
    found_local_dir=0
    p="$event_cwd"
    while [ -n "$p" ] && [ "$p" != "/" ] && [ "$p" != "." ]; do
      base="$(basename "$p")"
      parent="$(dirname "$p")"
      case "$base" in
        local_*)
          if [ -d "$p" ]; then found_local_dir=1; break; fi
          ;;
      esac
      p="$parent"
    done
    if [ "$found_local_dir" = 1 ]; then
      sleep 1.0
      RES_OUT2="$(mktemp 2>/dev/null)" || emit_noop
      [ -n "$RES_OUT2" ] || emit_noop
      run_cap env THALURA_SESSION_DIR="$event_cwd" bash "$RESOLVER" >"$RES_OUT2" 2>/dev/null
      ROOT2=""
      IFS= read -r ROOT2 < "$RES_OUT2" 2>/dev/null || true
      rm -f "$RES_OUT2" 2>/dev/null || true
      case "$ROOT2" in
        /*) emit_noop ;;   # retry resolved to a path -> the load-bearing no-op
      esac
    fi
    DIRECTIVE="Resolve the Thalura workspace before treating this request as a task. If it resolves to an initialized teacher workspace, proceed with the request. If it does not — the workspace is genuinely un-onboarded — route to the setup flow to onboard the teacher, or, when the teacher is restoring a workspace backup, to the restore flow, whose direct-initialization path may initialize the workspace from the backup. Never treat the session sandbox as the workspace or write into it."
    # Both ends pinned: stdin read as BYTES and decoded UTF-8 explicitly, the
    # payload emitted as UTF-8 BYTES. ensure_ascii=False is RETAINED deliberately —
    # the contract is real UTF-8 bytes on the wire, not \uXXXX-escaped ASCII — which
    # is only safe once the write goes through the buffer instead of an ascii-coded
    # text stdout that would raise and cost this gate its whole injection.
    printf '%s' "$DIRECTIVE" | python3 -c '
import json, sys
text = sys.stdin.buffer.read().decode("utf-8", "replace")
out = {"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": text}}
sys.stdout.buffer.write((json.dumps(out, ensure_ascii=False) + "\n").encode("utf-8", "replace"))
' 2>/dev/null || emit_noop
    exit 0
    ;;
  THALURA_AMBIGUOUS:*)
    # Split the comma list after the prefix; basename each candidate path to a folder
    # leaf. Carry the leaves ONLY — never internal profile data.
    CANDIDATES="${ROOT#THALURA_AMBIGUOUS:}"
    LEAVES=""
    OLDIFS="$IFS"; IFS=','
    for cand in $CANDIDATES; do
      [ -n "$cand" ] || continue
      leaf="$(basename "$cand")"
      if [ -z "$LEAVES" ]; then LEAVES="$leaf"; else LEAVES="$LEAVES, $leaf"; fi
    done
    IFS="$OLDIFS"
    [ -n "$LEAVES" ] || emit_noop
    # THREE ends here, not two — and the third is the one no guard covers. The folder
    # leaves are a NON-ASCII PAYLOAD PASSED THROUGH ARGV (a teacher folder called
    # "Schule Nord Ost" or "Ünïcode-Schule" is the normal case), and CPython decodes
    # argv with the LOCALE-DEPENDENT FILESYSTEM encoding: macOS forces utf-8 there
    # regardless of locale, but a Linux host under LC_ALL=C gives fs=ascii and the
    # leaf arrives surrogate-escaped. json.dumps then serialises the lone surrogates
    # without complaint, so the emit succeeds at rc=0 with empty stderr and the model
    # is handed a CORRUPTED folder name to ask the teacher about. os.fsencode()
    # round-trips surrogateescape back to the original bytes; the decode is then ours
    # and explicit. The source-ASCII guard scans the -c SPAN and the CI leg covers
    # STREAMS, so nothing but this line covers this channel.
    python3 -c '
import json, os, sys
leaves = os.fsencode(sys.argv[1]).decode("utf-8", "replace")
text = (
    "More than one mounted folder looks like a Thalura workspace. Before proceeding "
    "with this request, ask the teacher which folder is theirs and bind that one. "
    "Candidate folders: " + leaves + ". "
    "Offer a \"None of these\" choice that routes to setup."
)
out = {"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": text}}
sys.stdout.buffer.write((json.dumps(out, ensure_ascii=False) + "\n").encode("utf-8", "replace"))
' "$LEAVES" 2>/dev/null || emit_noop
    exit 0
    ;;
  /*)
    # Resolved absolute path -> no-op (the load-bearing no-op-on-success).
    emit_noop
    ;;
  *)
    # Empty / anything else -> fail-open no-op.
    emit_noop
    ;;
esac
