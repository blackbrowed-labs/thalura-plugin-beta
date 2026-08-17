#!/usr/bin/env bash
# seed-digest-cache.sh — create-only seeding of the shipped pre-read regulation
# digest pack into a teacher workspace cache.
#
# PURPOSE
#   The plugin ships a pre-generated digest pack under digests/cache/ — one
#   directory per regulation document, one JSON entry per resolved section, laid
#   out EXACTLY as the runtime cache expects (see scripts/cache.py, which owns the
#   layout <WORKSPACE_ROOT>/data/.cache/<document_id>/<section-key>.json). This
#   script copies that payload into the workspace so a teacher's first planning
#   request finds the covered passages already read instead of reading every PDF
#   from scratch. It is invoked from the setup flow (new workspace) and from
#   scripts/version-migrate.sh (existing workspace, on a version change or a
#   first-run stamp).
#
# ARG CONTRACT (positional)
#   seed-digest-cache.sh <PLUGIN_ROOT> <WORKSPACE_ROOT>
#     $1 PLUGIN_ROOT    — the shipped plugin root (holds digests/cache/). The
#                         caller already bound this. Passed in, NEVER
#                         self-discovered here.
#     $2 WORKSPACE_ROOT — the teacher workspace root (holds data/). The caller
#                         already RESOLVED this. The resolver
#                         (scripts/resolve-data-root.sh) is NOT run here: every
#                         caller invokes this script only after it already landed
#                         a real workspace path, and re-resolving would break the
#                         passed-in-never-self-discovered contract that both
#                         callers rely on. The seed target is composed literally
#                         as "$WORKSPACE_ROOT/data/.cache".
#
# BEHAVIOUR
#   1. Iterate every document directory under $PLUGIN_ROOT/digests/cache/.
#   2. Iterate every entry inside it and copy it to
#      $WORKSPACE_ROOT/data/.cache/<document_id>/<entry>, creating the cache root
#      and the per-document directory if missing.
#   3. CREATE-ONLY, PER ENTRY FILE — KERNEL-ENFORCED. Each entry is written with
#      `( set -C; cat "$entry" > "$dest" )`. `set -C` (noclobber) makes the
#      redirect an O_CREAT|O_EXCL open, so the KERNEL refuses the write whenever
#      ANY node already sits at the destination. THAT is the whole never-overwrite
#      guarantee. Because the existence check and the write are the SAME syscall,
#      it holds in two cases a checked-then-write cannot cover:
#        - A CONCURRENT writer. A stat followed by a separate copy is a TOCTOU
#          window: a runtime `cache.py put` landing in between is truncated by the
#          copy. This is not academic — the section key is derived from
#          (document_id, source_pdf_sha256, section_anchor) and ignores
#          key_components, so a runtime-written entry and a pack entry collide on
#          exactly the same filename; the pack entry is fresh, so it would then
#          HIT and permanently serve in place of what the runtime just produced.
#          An O_EXCL open fails with EEXIST instead, and the runtime entry stands.
#        - A SYMLINKED destination. `[ -e ]` FOLLOWS symlinks and is therefore
#          FALSE for a dangling one. BSD/macOS `cp` — the platform this actually
#          ships to — has no dangling-symlink check and opens the destination
#          O_WRONLY|O_CREAT|O_TRUNC, following the link and CREATING its target,
#          i.e. writing to an arbitrary absolute path. (GNU `cp` refuses, which is
#          why Linux CI would never have shown this.) An O_EXCL open returns
#          EEXIST for any existing node, dangling symlink included, so nothing is
#          written and no link target is created.
#      The guarantee is deliberately PER ENTRY rather than per directory: a
#      directory-level copy would clobber entries the runtime itself wrote, which
#      are always newer and always authoritative.
#      The preceding `[ -e "$dest" ] && continue` is ONLY a cheap fast path, and
#      carries no part of the guarantee: it avoids a fork per already-present
#      entry on the warm re-run — the common case, since every version change
#      re-runs this over a fully seeded cache. `-e`, not `-f`, so ANY node
#      (including a 0-byte file left behind by an interrupted write) short-circuits
#      there; anything `-e` misses is caught by O_EXCL a line later.
#      A plain redirect rather than `cp -R`: the redirect is what makes the O_EXCL
#      open available at all, and dropping recursion costs nothing because every
#      pack entry is a regular file (606/606 `.json`, zero subdirectories).
#
# SUMMARY FORMAT (stdout; stable + greppable — the tests assert on it)
#   ONE line per document directory that actually received at least one entry:
#     seeded=abiturrichtlinie entries=18
#     seeded=praeambel entries=7
#   One line per document — NOT a comma-joined list — so a document id that itself
#   contains a comma is never mis-parsed. A document whose entries were all
#   already present emits NOTHING (an absent line is the "nothing to do" signal,
#   the same convention scripts/version-migrate.sh uses for its copied= tokens).
#   Nothing at all on stdout means nothing was seeded, for any reason.
#
# FAIL-OPEN GUARANTEE (constitutional)
#   set -u, NOT set -e — seeding is an optimization, never a precondition. A
#   workspace that is not seeded is still fully correct: the runtime simply reads
#   the regulation instead of finding it pre-read. So EVERY failure path (missing
#   arguments, missing pack payload, missing workspace data/, an unwritable cache
#   root, a failing mkdir, a refused or failing entry write) is a silent no-op
#   that exits 0 with NO teacher-visible warning; a `seed=noop reason=<why>`
#   diagnostic goes to stderr only. Every mkdir and every entry write is guarded
#   with 2>/dev/null — including the noclobber refusal, which is an expected
#   outcome and not an error. The script NEVER writes outside
#   $WORKSPACE_ROOT/data/.cache/ and NEVER overwrites an existing entry (see
#   BEHAVIOUR 3: that second half is enforced by the kernel, not by a check).
#
# Portable to macOS bash 3.2 and BSD userland: no arrays, no mapfile, no
# associative arrays, no jq, no `${var,,}`, no `find -printf`, no `cp -a`
# (GNU-only). `set -C` + a redirect is POSIX and behaves identically on BSD.
# Path components are split with `${var##*/}` rather than `basename` — pure
# parameter expansion, no fork: this runs before the teacher's first request in
# the first session after every version change, and 619 `basename` forks cost
# ~1.2 s of pure process overhead there even when nothing needs copying.
set -u

# --- args --------------------------------------------------------------------
PLUGIN_ROOT="${1:-}"
WORKSPACE_ROOT="${2:-}"

# Fail-open on a missing arg — write nothing, say nothing on stdout.
[ -n "$PLUGIN_ROOT" ]    || { echo "seed=noop reason=no-plugin-root" >&2; exit 0; }
[ -n "$WORKSPACE_ROOT" ] || { echo "seed=noop reason=no-workspace-root" >&2; exit 0; }

pack_root="$PLUGIN_ROOT/digests/cache"
data_dir="$WORKSPACE_ROOT/data"
cache_root="$data_dir/.cache"

# --- preconditions (each one a silent no-op) ---------------------------------
# No shipped payload: an install without the pack is a supported install.
[ -d "$pack_root" ] || { echo "seed=noop reason=no-pack" >&2; exit 0; }
# No workspace data/: this script never creates the workspace scaffold itself —
# writing data/.cache into a directory that is not a set-up workspace would leave
# a stray tree behind. The scaffold is the caller's job.
[ -d "$data_dir" ]  || { echo "seed=noop reason=no-workspace-data" >&2; exit 0; }

# The cache root. mkdir -p is a no-op when it already exists; the -d re-check
# catches an unwritable data/ on shells whose mkdir reports success oddly.
mkdir -p "$cache_root" 2>/dev/null
[ -d "$cache_root" ] || { echo "seed=noop reason=cache-root-unwritable" >&2; exit 0; }

# --- copy, create-only, one document directory at a time ---------------------
for doc in "$pack_root"/*; do
  [ -d "$doc" ] || continue                  # empty-glob guard + skip stray files
  doc_id="${doc##*/}"                        # parameter expansion, never a fork
  dest_dir="$cache_root/$doc_id"
  seeded=0
  for entry in "$doc"/*; do
    # Empty-glob guard, and REGULAR FILES ONLY. `-f`, not `-e`, because a redirect
    # creates $dest BEFORE `cat` runs: a non-regular source (a directory) would
    # leave a 0-byte residue at $dest that the fast path then protects forever.
    # `cp -R` used to absorb that shape by recursing. Every pack entry is a regular
    # file (592/592 `.json`), so this only ever skips a malformed pack.
    [ -f "$entry" ] || continue
    base="${entry##*/}"                      # parameter expansion, never a fork
    dest="$dest_dir/$base"
    [ -e "$dest" ] && continue               # cheap fast path (NOT the guarantee)
    mkdir -p "$dest_dir" 2>/dev/null || continue
    # set -C => O_CREAT|O_EXCL: the KERNEL enforces create-only, so a concurrent
    # writer and a (dangling) symlink at $dest are both refused with EEXIST.
    if ( set -C; cat "$entry" > "$dest" ) 2>/dev/null; then
      seeded=$((seeded + 1))
    fi
  done
  # One token per document directory, emitted only when something landed.
  if [ "$seeded" -gt 0 ]; then
    printf 'seeded=%s entries=%s\n' "$doc_id" "$seeded"
  fi
done

exit 0
