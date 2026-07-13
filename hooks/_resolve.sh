#!/usr/bin/env bash
# Shared resolution for the Thalura hooks (the regulation digest-cache hooks and the
# setup-route gate).
# Sourced by put-digest.sh, get-digest.sh, and setup-route-gate.sh. Fail-open: a
# caller no-ops when thalura_cache_dir returns non-zero. (setup-route-gate.sh uses
# thalura_plugin_root() only and branches on the resolver's raw sentinel itself.)
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
  local here; here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local derived; derived="$(cd "$here/.." && pwd)"
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
