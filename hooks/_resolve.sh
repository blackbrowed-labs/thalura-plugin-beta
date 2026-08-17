#!/usr/bin/env bash
# Shared resolution for the Thalura hooks (the regulation digest-cache hooks and the
# setup-route gate).
# Sourced by put-digest.sh, get-digest.sh, reader-queue.sh and setup-route-gate.sh at
# file scope, and by fanout-gate.sh inside its tombstone subshell only — that gate keeps
# no sourced siblings on any decision path, and an absent resolver costs it a tombstone
# rather than a decision. Fail-open: a caller no-ops when thalura_cache_dir returns
# non-zero. (setup-route-gate.sh uses thalura_plugin_root() only, and branches on the
# resolver's raw sentinel itself; it never touches a cache root.)
#
# All five consumers also honour thalura_is_shipped_pack_path() where they write: the
# shipped digest pack is a read-only source. See the long note at that function.
#
# Plugin root: the hook's own path is ALWAYS under the plugin (the host launches
# it from <plugin>/hooks/), so BASH_SOURCE resolves even when CLAUDE_PLUGIN_ROOT
# is unset (the Cowork condition). Test override: THALURA_PLUGIN_ROOT.
# Cache dir: the shared resolve-data-root.sh, fed the event cwd as
# THALURA_SESSION_DIR. Any sentinel (SETUP_NEEDED/AMBIGUOUS/error) -> rc 1 (no-op).

thalura_plugin_root() {
  if [ -n "${THALURA_PLUGIN_ROOT:-}" ]; then
    printf '%s\n' "$THALURA_PLUGIN_ROOT"; return 0
  fi
  # _resolve.sh lives at <plugin>/hooks/_resolve.sh
  #
  # Both `cd`s silence stderr. This function is now reachable from fanout-gate.sh's
  # tombstone subshell on the THALURA_CACHE_DIR arm, which sits immediately above that
  # gate's `printf '%s\n' "$reason" >&2; exit 2` deny channel — so an unreadable
  # <plugin>/hooks would have prepended a shell error to the corrective reason the caller
  # is meant to read. Suppressing it changes no return value on any path.
  local here; here="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  local derived; derived="$(cd "$here/.." 2>/dev/null && pwd)"
  if [ -d "$derived/scripts" ]; then
    printf '%s\n' "$derived"; return 0
  fi
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT"; return 0
  fi
  printf '%s\n' "$derived"
}

thalura_cache_dir() {
  local event_cwd="${1:-$PWD}"
  local proot resolver root
  proot="$(thalura_plugin_root)"
  resolver="$proot/scripts/resolve-data-root.sh"
  [ -f "$resolver" ] || return 1
  root="$(THALURA_SESSION_DIR="$event_cwd" bash "$resolver" 2>/dev/null)" || return 1
  case "$root" in ""|THALURA_*) return 1 ;; esac
  printf '%s\n' "$root/data/.cache"
}

# --- THE SHIPPED DIGEST PACK IS A READ-ONLY SOURCE.
#
# The plugin carries a pre-generated digest pack under <plugin>/digests/. Everything
# in the plugin READS from it: the seeder copies entries out of it into a workspace's
# own cache, the scaffold detector inspects it. Nothing points a LIVE cache root at
# it — thalura_cache_dir above can only ever return <workspace>/data/.cache — so a
# cache root landing inside that tree is a misconfiguration (an operator or a probe
# overriding THALURA_CACHE_DIR), never a designed mode.
#
# IT MATTERS BECAUSE THAT DIRECTORY IS PUBLISHED. The pack's payload is copied
# verbatim into the public distribution tree at release time, and a recursive copy
# takes dot-entries. So runtime state written there — an audit breadcrumb carrying
# the live session id, a reader tombstone, a dedup marker, or an entry the runtime
# wrote itself — would be published. Every mechanical check over the pack either
# filters *.json or skips names beginning with a dot, so not one of them can see it:
# the failure is silent by construction on every side.
#
# So the hooks refuse. A cache root that resolves inside <plugin>/digests/ is one
# they write NOTHING into. THE REFUSAL IS A SKIPPED WRITE AND NEVER A DENY: a caller
# that cannot cache pays a redundant read, which is this hook family's standing
# fail-open direction. Nothing here can block, delay or reverse a dispatch.
#
# The guarded path is the PARENT digests/, not the payload digests/cache/. The
# payload is what ships, but the whole tree is the pack, and a stray write beside the
# payload is repo litter either way. One path, strictly containing the shipped
# surface.

# _thalura_physical_path <path> — the physical path for <path>, with every symlink and
# every `..` resolved, tolerating a TAIL THAT DOES NOT EXIST YET (a cache root is
# routinely created on first use, so the check must work before it is there).
#
# `cd ... && pwd -P` is the resolution primitive on purpose: realpath(1) and
# `readlink -f` are both GNU-only, and the oldest shell this plugin supports carries
# neither.
#
# The walk strips trailing components until what remains is a directory and resolves
# THAT once — one subshell, not one per component, because this runs on every dispatch.
# The remainder is then replayed component by component with `.` dropped and `..`
# applied, and re-resolved through `cd -P` whenever the accumulated path becomes an
# existing directory again.
#
# THE REPLAY IS NOT TIDINESS, IT IS THE `..` CASE. Re-appending the remainder verbatim
# would leave a `..` in it unapplied, and a `..` in the remainder is REACHABLE: a path
# like <root>/absent/../plug/digests/cache stops the upward walk at <root>, so the whole
# `absent/../plug/...` tail stays textual — and `mkdir -p` on that path lands squarely
# inside the pack while a textual compare sees no match. Applying `..` here is what makes
# the answer agree with where a write would actually go. The re-resolution after each
# step is the other half: a `..` can walk back into existing territory, and only there
# can a symlink hide again.
#
# The `[ -d ]` test is a builtin, so the common case — a remainder that does not exist —
# still costs exactly the one subshell above.
#
# Returns 1 on an empty argument, or on a head that cannot be entered. The caller
# treats that as "not the pack" — see the direction note on the predicate below.
_thalura_physical_path() {
  local p="${1:-}" ptail="" head rest comp
  [ -n "$p" ] || return 1
  case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  head="$p"
  while [ ! -d "$head" ]; do
    case "$head" in
      */?*) ptail="/${head##*/}$ptail"; head="${head%/*}"; [ -n "$head" ] || head="/" ;;
      *) return 1 ;;
    esac
  done
  head="$(cd "$head" 2>/dev/null && pwd -P)" || return 1
  head="${head%/}"
  # Split the remainder with parameter expansion only: no `set --` (which would need a
  # glob guard around it) and no subprocess.
  rest="$ptail"
  while [ -n "$rest" ]; do
    rest="${rest#/}"
    case "$rest" in
      */*) comp="${rest%%/*}"; rest="${rest#*/}" ;;
      *)   comp="$rest";       rest="" ;;
    esac
    case "$comp" in
      ''|'.') continue ;;
      '..')   head="${head%/*}" ;;
      *)      head="$head/$comp" ;;
    esac
    # `..` off the root leaves $head empty, which is the root: the `${head:-/}` below
    # turns it back into `/` and `cd -P` re-normalizes from there.
    if [ -d "$head" ] || [ -z "$head" ]; then
      head="$(cd "${head:-/}" 2>/dev/null && pwd -P)" || return 1
      head="${head%/}"
    fi
  done
  printf '%s\n' "${head:-/}"
}

# thalura_is_shipped_pack_path <path>
#   rc 0 -> <path> IS, or is inside, the plugin's own digests/ tree. Write nothing.
#   rc 1 -> it is not. The ordinary case.
#
# rc 1 is ALSO the answer on every resolution failure, and that direction is the safe
# one in both shapes it can take: a head that cannot be entered is a path the caller
# could not have written into either, and a plugin whose own root will not resolve is
# one where no path can be shown to be inside it.
#
# COMPARED AS RESOLVED PHYSICAL PATHS, NEVER AS STRINGS. A prefix test on raw text
# would call <plugin>/digests-scratch a pack path — and would be walked straight out
# of by a symlink or a `..`, which is exactly the shape an override takes when someone
# is pointing a tool at a tree by hand.
#
# AND A STRING COMPARE ALONE IS NOT ENOUGH, ON THE ONE MACHINE WHERE THIS MATTERS MOST.
# `cd X && pwd -P` resolves symlinks but does NOT canonicalize component CASE, so on a
# case-insensitive filesystem — the macOS default, i.e. the machine an operator probe
# runs on — an override typed as <plugin>/DIGESTS/cache resolves to itself, matches no
# string, and is waved through. Measured. On Linux the same spelling simply names a path
# that does not exist, so the class is case-insensitive-filesystem-only, and it is one
# hand-typed override away.
#
# It is also the WORST class to miss. A put under a mis-cased root lands an ENTRY-SHAPED
# <document_id>/<key>.json, which the release-time shape assertion counts as a legitimate
# entry by construction — this containment is that class's only defence.
#
# So the string compare is backed by an IDENTITY WALK. `-ef` compares device + inode, is
# a shell BUILTIN (no fork; the walk is bounded by path depth), and answers the case
# question exactly right in both directions: on a case-insensitive filesystem the
# mis-cased directory IS the same inode, and on a case-sensitive one it is a different
# path that does not exist. The string compare stays ahead of it because it answers the
# common case without touching the filesystem at all, and because it still holds for a
# tail that does not exist yet — which no inode test can see.
thalura_is_shipped_pack_path() {
  local target="${1:-}" proot pack t
  [ -n "$target" ] || return 1
  proot="$(thalura_plugin_root)" || return 1
  [ -n "$proot" ] || return 1
  # Resolved through the same walker as the target, so an ABSENT digests/ is still
  # answered (derived from the resolved parent) rather than treated as "no pack to
  # protect" — a hole that would open exactly when the tree is being created.
  pack="$(_thalura_physical_path "$proot/digests")" || return 1
  target="$(_thalura_physical_path "$target")" || return 1
  # Both arms quoted so a path holding a glob metacharacter is matched literally; the
  # trailing `/*` is the only pattern, and it is what keeps `digests-scratch` out.
  case "$target" in
    "$pack") return 0 ;;
    "$pack"/*) return 0 ;;
  esac
  # The identity walk. Builtins only. A component that does not exist tests false and the
  # walk simply continues upward, so a not-yet-existing tail costs nothing here — it is
  # already answered by the string compare above.
  t="$target"
  while [ -n "$t" ]; do
    [ "$t" -ef "$pack" ] 2>/dev/null && return 0
    case "$t" in
      */?*) t="${t%/*}" ;;
      *) break ;;
    esac
  done
  return 1
}
