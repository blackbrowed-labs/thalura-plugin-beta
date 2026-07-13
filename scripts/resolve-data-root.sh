#!/usr/bin/env bash
# Resolve the Thalura teacher-workspace root (<WORKSPACE_ROOT>).
# Prints the absolute path on success, or a sentinel.
# See docs/issues/174-environment-path-resolution.spec.md §3.2,
# docs/issues/203-cowork-plugin-root-resolution.spec.md, and
# docs/issues/345-cowork-host-resolver.spec.md (Branch 2b).
# Portable to macOS bash 3.2 (no arrays) and Linux.
set -eu

# Testability overrides (unset in production):
#   THALURA_SESSION_DIR   overrides the cwd used for branch detection
#   THALURA_MNT_BASE      overrides the mnt/ base scanned in the VM Cowork branch
#   THALURA_FORCE_COWORK  =1 forces the VM Cowork branch (lets the cwd-strip be
#                         tested against a temp tree not under /sessions/)
session_dir="${THALURA_SESSION_DIR:-$PWD}"
# Cowork session root: strip /mnt/... so the mnt base is correct from ANY cwd
# (e.g. when the resolver is run from the discovered plugin dir). Unchanged if
# session_dir contains no /mnt/ segment.
session_root="${session_dir%%/mnt/*}"
mnt_base="${THALURA_MNT_BASE:-$session_root/mnt}"

# Branch 1: Claude Code — CLAUDE_PROJECT_DIR set and marks a Thalura workspace.
# The teacher-profile marker (not a bare data/ dir) is the workspace test, matching
# Branch 2 / 2b (the F2 marker discipline). A config-only seeded data/ (the host-
# Cowork outputs dir; a fresh un-onboarded CLI project) no longer satisfies it, so a
# host-Cowork cwd falls through to Branch 2b, which maps it to the connected
# workspace, and a fresh CLI project falls through to SETUP_NEEDED.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "${CLAUDE_PROJECT_DIR}/data/profiles/teacher-profile.json" ]; then
  printf '%s\n' "$CLAUDE_PROJECT_DIR"
  exit 0
fi

# Branch 2: Claude Cowork VM side — cwd under /sessions/ (or forced for tests)
is_cowork=0
case "$session_dir" in /sessions/*) is_cowork=1 ;; esac
[ "${THALURA_FORCE_COWORK:-0}" = "1" ] && is_cowork=1
if [ "$is_cowork" -eq 1 ]; then
  count=0; found=""; joined=""
  if [ -d "$mnt_base" ]; then
    for d in "$mnt_base"/*/; do
      [ -d "$d" ] || continue                                   # skip if glob did not expand
      name="$(basename "$d")"
      [ "$name" = ".remote-plugins" ] && continue               # never the plugins mount
      [ -f "${d}data/profiles/teacher-profile.json" ] || continue  # require the Thalura marker
      path="${d%/}"
      count=$((count + 1)); found="$path"
      if [ -z "$joined" ]; then joined="$path"; else joined="$joined,$path"; fi
    done
  fi
  if [ "$count" -eq 0 ]; then
    printf 'THALURA_SETUP_NEEDED\n'; exit 10
  elif [ "$count" -eq 1 ]; then
    printf '%s\n' "$found"; exit 0
  else
    printf 'THALURA_AMBIGUOUS:%s\n' "$joined"; exit 11
  fi
fi

# Branch 2b: Claude Cowork HOST side — host-executed hooks run with
# the event cwd inside the desktop app's per-session output tree (never under
# /sessions/). Structural invariant (spec §2): the session dir local_<id>/ (whose
# outputs/ is the event cwd) has a SIBLING metadata file local_<id>.json whose
# userSelectedFolders lists the HOST paths of the connected folder(s). Detection
# walks UP from the cwd; the deepest local_* component with a readable sibling
# .json wins. Every failure degrades to THALURA_SETUP_NEEDED (fail-open — the
# exact prior behaviour). Deliberately NOT keyed on platform directory names
# (local-agent-mode-sessions / Application Support): the local_<id> + sibling
# JSON pair is the cross-generation structural invariant; the teacher-profile
# marker still gates the final answer.
meta=""
p="$session_dir"
while [ -n "$p" ] && [ "$p" != "/" ] && [ "$p" != "." ]; do
  base="$(basename "$p")"
  parent="$(dirname "$p")"
  case "$base" in
    local_*)
      if [ -f "$parent/$base.json" ] && [ -r "$parent/$base.json" ]; then
        meta="$parent/$base.json"
        break
      fi
      ;;
  esac
  p="$parent"
done

if [ -n "$meta" ]; then
  # Extract absolute-path candidates, one per line. python3 (the hooks' existing
  # hard dependency) is the JSON reader; ANY failure — python3 absent, unreadable
  # or malformed JSON, missing key, wrong type — yields an empty list GRACEFULLY
  # (|| true guards set -e). The subprocess runs strictly in the FOREGROUND with
  # no run_cap / watchdog / background children: hooks/_resolve.sh reads this
  # script through a bare command substitution, and a background grandchild
  # would re-open the pipe-hold hazard. The work is a bounded local file
  # read (no network), so it needs no timeout; callers' outer timeouts bound it.
  candidates="$(python3 - "$meta" 2>/dev/null <<'PY' || true
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(0)
folders = d.get("userSelectedFolders") if isinstance(d, dict) else None
if not isinstance(folders, list):
    sys.exit(0)
for f in folders:
    if not isinstance(f, str):
        continue
    if "\n" in f or "\r" in f:
        continue                      # one path per output line — defensive
    f = f.rstrip("/")
    if not f.startswith("/"):
        continue                      # absolute paths only (spec §3.3)
    if f:
        print(f)
PY
)"
  count=0; found=""; joined=""
  if [ -n "$candidates" ]; then
    while IFS= read -r cand; do
      [ -n "$cand" ] || continue
      [ -f "$cand/data/profiles/teacher-profile.json" ] || continue  # the Thalura marker
      count=$((count + 1)); found="$cand"
      if [ -z "$joined" ]; then joined="$cand"; else joined="$joined,$cand"; fi
    done <<EOF
$candidates
EOF
  fi
  if [ "$count" -eq 1 ]; then
    printf '%s\n' "$found"; exit 0
  elif [ "$count" -gt 1 ]; then
    printf 'THALURA_AMBIGUOUS:%s\n' "$joined"; exit 11
  fi
  # Host-Cowork detected but no marked workspace (incl. the observed agent/ditto
  # empty-array layout) -> not set up.
  printf 'THALURA_SETUP_NEEDED\n'; exit 10
fi

# Branch 3: not set up
printf 'THALURA_SETUP_NEEDED\n'
exit 10
