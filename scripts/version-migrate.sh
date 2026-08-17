#!/usr/bin/env bash
# version-migrate.sh — deterministic plugin version-migration at session startup.
#
# PURPOSE
#   Promotes the version-check "Update Flow" (references/versioning.md +
#   skills/core/SKILL.md) from model-executed prose into a single deterministic
#   script call. On a plugin version change it additively copies net-new config
#   defaults into the teacher's data/config/ (never overwriting a teacher file),
#   atomically stamps data/version.json, and prints a machine-readable summary the
#   model uses to render a localized changelog notice. The core skill runs it at
#   startup Step 0d, right after the workspace root is bound.
#
# ARG CONTRACT (positional)
#   version-migrate.sh <PLUGIN_ROOT> <WORKSPACE_ROOT>
#     $1 PLUGIN_ROOT    — the shipped plugin root (holds .claude-plugin/plugin.json
#                         and config-defaults/). The caller already bound this
#                         (SKILL.md Step 0a). Passed in, NEVER self-discovered here.
#     $2 WORKSPACE_ROOT — the teacher workspace root (holds data/). The caller
#                         already RESOLVED this (SKILL.md Step 0b). The resolver
#                         (scripts/resolve-data-root.sh) is NOT run here — Step 0d
#                         only invokes this script after Step 0b landed a real path;
#                         on a resolver sentinel Step 0b routes to setup and Step 0d
#                         never runs.
#
# BEHAVIOUR (mirrors dev-scripts/test_version_check.sh's version_check() contract)
#   1. current = plugin.json "version".
#   2. data/version.json ABSENT -> create it at current + timestamp; DO NOT run the
#      update flow (no config copy). Prints a first-run summary. The ONE thing this
#      branch does besides the stamp is seed the shipped pre-read digest pack
#      (create-only) — a deliberate, reasoned exception, see "WHY THE SEED ALSO
#      FIRES ON BRANCH 2" below.
#   3. current == last_seen -> strict no-op: exit 0, STDOUT EMPTY (a "noop" line may
#      go to stderr only). This idempotency short-circuit makes a Step-1 backstop
#      reach after a completed Step 0d harmless.
#   4. current != last_seen -> update flow, UNCONDITIONAL on changelog content:
#      a. copy net-new config-defaults/* into data/config/ (skip if the dest exists
#         — never overwrite/delete/read a protected file; skip .gitkeep).
#      e. seed the shipped pre-read digest pack into data/.cache/ (create-only per
#         entry file, delegated to scripts/seed-digest-cache.sh). Runs AFTER 4a/4d,
#         BEFORE 4b's stamp, so a stamp failure never claims a migration that did
#         not land — and so the seed is already on disk when the stamp does land.
#      b. atomically stamp data/version.json {plugin_version, updated_at} via
#         temp-file + `mv -f` (a rename failure is tolerated as a no-op — the copy
#         already happened; the stamp retries next session).
#      c. print the state-delta summary (below).
#
# WHY THE SEED ALSO FIRES ON BRANCH 2 (branch 2's one exception to "no update flow")
#   Branch 2 stamps the workspace at the CURRENT version, after which every later
#   run takes branch 3 (the strict no-op). So a workspace that reaches branch 2 on a
#   build that ships the pack would be stamped current and become PERMANENTLY
#   unseedable by any later path. Seeding here is exactly what makes leaving branch 3
#   alone safe: every route into branch 3 has already passed through branch 2 or
#   branch 4, where the seed was offered.
#   It does not conflict with the no-update-flow rule either, because that rule is
#   about CONFIG semantics — never retro-apply shipped defaults over a teacher's
#   possibly deliberate config. An absent cache entry carries no teacher intent (the
#   cache is regenerable by contract, and the seed is create-only per entry file, so
#   an entry the runtime itself wrote is never replaced). There is nothing to
#   preserve, hence nothing the rule protects.
#   Branch 3 is deliberately NOT touched — no seed, no stat, no check: its
#   empty-stdout no-op is a stated contract AND a per-session hot path.
#
# SUMMARY FORMAT (stdout; stable + greppable — the tests assert on it)
#   A block of `key=value` lines, one per line, e.g.:
#     migrate=update
#     old_version=0.2.0
#     new_version=0.2.1
#     major=false
#     readme=missing                # ONLY when data/README.md is absent (see below)
#     copied=foo.json               # ONE copied= line PER copied file
#     copied=bar.json               # (no copied= line at all when nothing copied)
#     migrated=internal_compliance_check   # ONE migrated= line PER carried toggle
#     migrated=pdf_on_validation           # (no migrated= line when nothing carried)
#     seeded=abiturrichtlinie entries=18   # ONE seeded= line PER seeded document
#     seeded=praeambel entries=7           # (no seeded= line when nothing seeded)
#   The `seeded=<document_id> entries=<n>` line(s) — one per pack document directory
#   that received at least one net-new cache entry in step 4e — appear LAST, after
#   the `migrated=` block, one line per document (comma-safe, same convention as
#   `copied=`). They are passed through verbatim from scripts/seed-digest-cache.sh,
#   whose stderr is suppressed here so the migration's own no-stderr-leak guarantee
#   is unaffected. No `seeded=` line at all when nothing was seeded (the pack is
#   absent, or every entry was already present) — an absent line is the
#   "nothing to do" signal, same convention as `copied=`. On the first-run branch
#   the same lines follow `new_version=`.
#   The `migrated=<key>` line(s) — one per behaviour toggle carried forward from a
#   legacy profile file into data/config/behaviour.json by Step 4d — appear
#   AFTER the `copied=` block, one line per key (comma-safe, same convention as
#   `copied=`), so the caller can render a "your existing settings were carried
#   over" notice. No `migrated=` line at all when nothing was carried.
#   The `readme=missing` line appears — after `major=`, before any `copied=` line —
#   ONLY on the update path and ONLY when $WORKSPACE_ROOT/data/README.md does not
#   exist, giving the caller a deterministic trigger to re-seed the protective
#   data-root README. There is no `readme=present` token: an absent line means the
#   README exists and nothing is to be done (same convention as `copied=`). The
#   script only REPORTS the fact — it never writes the (localized) README itself.
#   One `copied=` line per file — not a comma-joined list — so a filename that
#   itself contains a comma is never mis-parsed.
#   For the first-run (absent version.json) branch:
#     migrate=first-run
#     new_version=0.2.1
#   For the equal-versions branch: NOTHING on stdout (a `migrate=noop` line goes to
#   stderr only). Likewise a stamp that could not be written (unwritable data/) emits
#   NOTHING on stdout and a `migrate=noop reason=stamp-failed` line to stderr — the
#   stdout summary always matches what actually reached disk. `major` is `true` when
#   the leading X of X.Y.Z differs old->new. NO changelog text is pulled into the
#   payload (the script ships — cite-ban); the model renders the localized changelog
#   summary from CHANGELOG.md itself.
#
# FAIL-OPEN GUARANTEE (constitutional)
#   set -u, NOT set -e — a non-fatal mid-flow error must not abort the flow
#   non-fail-open. Every failure path (missing/unreadable plugin.json, missing or
#   unwritable WORKSPACE_ROOT, empty current version, cp failure, rename failure) is
#   a no-op that exits 0 with NO teacher-visible warning. The script NEVER writes
#   outside $WORKSPACE_ROOT/data/ and NEVER overwrites a protected file (the
#   `[ -e "$dest" ]` guard is the whole Protected-Files guarantee).
#   The digest-pack seed inherits this: it is an optimization, never a
#   precondition, so a missing seed script, a missing pack or a failing copy leaves
#   the migration untouched — the stamp is still written and the summary still
#   printed. Its stderr is discarded here (the seeder's own diagnostics are for
#   direct invocation; this script's stderr is a fixed, asserted token set).
#
# Portable to macOS bash 3.2 and Linux (no arrays, no jq).
set -u

# --- args --------------------------------------------------------------------
PLUGIN_ROOT="${1:-}"
WORKSPACE_ROOT="${2:-}"

# Fail-open on a missing arg — behave as today, write nothing.
[ -n "$PLUGIN_ROOT" ]    || { echo "migrate=noop reason=no-plugin-root" >&2; exit 0; }
[ -n "$WORKSPACE_ROOT" ] || { echo "migrate=noop reason=no-workspace-root" >&2; exit 0; }

plugin_json="$PLUGIN_ROOT/.claude-plugin/plugin.json"
config_defaults="$PLUGIN_ROOT/config-defaults"
version_file="$WORKSPACE_ROOT/data/version.json"
config_dir="$WORKSPACE_ROOT/data/config"

# --- helpers -----------------------------------------------------------------
now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Read a top-level "key": "value" string field from a flat JSON file (bash 3.2, no
# jq). Returns the value without quotes, or empty if absent.
json_str() {
  # $1 = file, $2 = key
  sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$1" 2>/dev/null | head -1
}

# Leading X of an X.Y.Z[-…] version string (the major component).
major_of() {
  # $1 = version — strip everything from the first '.' onward.
  printf '%s' "${1%%.*}"
}

# Atomically write $2 (content) to $1 (path) via temp-file + mv -f.
# Returns 0 when the write landed, 1 when it did not (unwritable dir, failed
# redirect-open, or a failed rename). The caller keeps the summary consistent
# with what actually reached disk. Fail-open: NO stderr leak on any path — the
# redirect-open failure is captured by the brace-group `{ …; } 2>/dev/null` wrap
# (a bare `cmd > f 2>/dev/null` still leaks a shell redirect-open error on bash
# 3.2; the brace group suppresses it).
atomic_write() {
  # $1 = dest path, $2 = content
  _dir="$(dirname "$1")"
  mkdir -p "$_dir" 2>/dev/null || return 1
  _tmp="$1.tmp.$$"
  { printf '%s' "$2" > "$_tmp"; } 2>/dev/null || { rm -f "$_tmp" 2>/dev/null; return 1; }
  mv -f "$_tmp" "$1" 2>/dev/null || { rm -f "$_tmp" 2>/dev/null; return 1; }
  return 0
}

version_json_body() {
  # $1 = version, $2 = timestamp
  printf '{\n  "plugin_version": "%s",\n  "updated_at": "%s"\n}\n' "$1" "$2"
}

# Seed the shipped pre-read digest pack into $WORKSPACE_ROOT/data/.cache/, printing
# whatever `seeded=<document_id> entries=<n>` lines the seeder emitted (empty when
# nothing was seeded). Both roots are the ones this script was HANDED — nothing is
# re-resolved (the passed-in-never-self-discovered contract; the seeder composes its
# target literally as "$WORKSPACE_ROOT/data/.cache" for the same reason).
# Fail-open on every path: an absent seeder is a supported install (older plugin
# tree, or a tree without the pack), so it is a silent no-op; the seeder itself
# exits 0 on every failure. Its stderr is discarded — this script's stderr carries
# only its own fixed `migrate=noop reason=…` tokens. `return 0` keeps a non-zero
# from the child (which the seeder's contract forbids, but never assume it) from
# becoming this function's status — and because both call sites CAPTURE this function
# in a command substitution, even an `exit` here could only leave that subshell, so
# the seed is structurally incapable of aborting the migration.
seed_digest_pack() {
  _seed_sh="$PLUGIN_ROOT/scripts/seed-digest-cache.sh"
  [ -f "$_seed_sh" ] || return 0
  bash "$_seed_sh" "$PLUGIN_ROOT" "$WORKSPACE_ROOT" 2>/dev/null
  return 0
}

# --- behaviour-toggle migration helpers --------------------------------------
# json_has_key FILE KEY -> exit 0 if the flat top-level key is present, else 1.
# bash 3.2, no jq: grep for a top-level "key": token (scalar values —
# boolean/enum/number/null — always sit after a colon). The [ -f ] guard first
# keeps a missing legacy file a clean "no key" (fail-open: nothing to migrate).
json_has_key() {
  # $1 = file, $2 = key
  [ -f "$1" ] || return 1
  grep -Eq "\"$2\"[[:space:]]*:" "$1" 2>/dev/null
}

# json_bool FILE KEY -> print the raw scalar token (true/false/null) for a flat
# top-level boolean/null key, or empty if absent. Used as the no-python fallback
# READER for the two boolean toggles. Uses `grep -Eo` (ERE alternation) — NOT a
# `sed \(a\|b\)` alternation, which BSD/macOS sed does NOT support (GNU-only). ERE
# `(true|false|null)` works identically on macOS BSD grep and GNU grep, keeping the
# reader bash-3.2 + Linux portable.
json_bool() {
  # $1 = file, $2 = key
  grep -Eo "\"$2\"[[:space:]]*:[[:space:]]*(true|false|null)" "$1" 2>/dev/null \
    | head -1 | grep -Eo '(true|false|null)$'
}

# The shipped default per behaviour toggle (mirrors config-defaults/behaviour.json).
# The python3 divergence guard reads the default from this table for its
# default-equality check, so a teacher edit away from the default is never
# clobbered. The python3-absent fallback does NOT use this table — it applies the
# weaker "key present in dest -> skip" rule, which also never clobbers a set value.
behaviour_default() {
  # $1 = key -> prints the shipped default scalar (no surrounding quotes)
  case "$1" in
    internal_compliance_check) printf 'true' ;;
    pdf_on_validation)         printf 'student_facing' ;;
    generate_student_slides)   printf 'true' ;;
    *)                         printf '' ;;
  esac
}

# migrate_toggle DEST LEGACY KEY IS_STRING
#   Copy-forward ONE behaviour toggle from LEGACY into DEST, then delete it from
#   LEGACY. Prints `migrated=<key>` on stdout iff the value was carried forward.
#   FIX 1 (research §"The ordering fix"): the trigger is the PRESENCE OF THE KEY
#   IN THE LEGACY FILE (the unambiguous "not yet migrated" signal, self-clearing
#   on delete) — NOT "absent from DEST" (Step 4a already seeded DEST with the
#   default, so that guard never fires and would silently lose the teacher value).
#   Fully fail-open: every failure path is a silent no-op; python3 is preferred
#   for the JSON rewrites but is NEVER hard-required (a bash-only fallback rebuilds
#   our own small flat DEST, and a failed/absent-python3 delete leaves the legacy
#   key in place — inert, since no consumer reads it any more).
migrate_toggle() {
  # $1 = dest (data/config/behaviour.json), $2 = legacy file, $3 = key,
  # $4 = is_string (1 = quoted string value, 0 = bare boolean/number)
  _mt_dest="$1"; _mt_legacy="$2"; _mt_key="$3"; _mt_is_string="$4"
  # Reset per-toggle state so a value from a prior unrolled call never lingers
  # into this one (these are script-globals in bash 3.2 — no `local`). The
  # python3 guard always reassigns _mt_decision before reading it; this reset
  # makes the bash-fallback path deterministic regardless.
  _mt_decision=""; _mt_wrote=0; _mt_legacy_is_null=0

  # (1) TRIGGER: only if the legacy file still carries the key (un-migrated flag).
  json_has_key "$_mt_legacy" "$_mt_key" || return 0

  # generate_student_slides: an explicit legacy `null` is treated as UNSET ->
  # import nothing (DEST keeps its default `true`), but still attempt the delete
  # so the inert null does not linger. A non-null value carries forward normally.
  _mt_legacy_is_null=0
  if [ "$_mt_is_string" = 0 ]; then
    _mt_bool="$(json_bool "$_mt_legacy" "$_mt_key")"
    [ "$_mt_bool" = "null" ] && _mt_legacy_is_null=1
  fi

  # (2) DIVERGENCE GUARD: skip the import if the teacher already changed DEST away
  #     from the shipped default (covers the leave-in-place fallback across
  #     re-runs so a later /thalura:config edit is never clobbered). python3 does a
  #     robust default-equality check; when python3 is absent, the weaker-but-safe
  #     fallback is "key present in DEST -> skip" (never clobbers a migrated value).
  _mt_default="$(behaviour_default "$_mt_key")"
  if command -v python3 >/dev/null 2>&1; then
    # diverged -> print DIVERGED and skip; equals-default -> print IMPORT; missing
    # key or unreadable dest -> IMPORT (treat as still-default). Fail-open: any
    # python3 error prints nothing -> we fall through to the bash guard below.
    _mt_decision="$(python3 - "$_mt_dest" "$_mt_key" "$_mt_default" "$_mt_is_string" <<'PY' 2>/dev/null
import json, sys
dest, key, default, is_string = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
try:
    with open(dest) as f:
        d = json.load(f)
except Exception:
    print("IMPORT"); sys.exit(0)
if key not in d:
    print("IMPORT"); sys.exit(0)
cur = d[key]
if is_string == "1":
    exp = default
else:
    if default == "true": exp = True
    elif default == "false": exp = False
    else: exp = default
print("DIVERGED" if cur != exp else "IMPORT")
PY
)"
    if [ "$_mt_decision" = "DIVERGED" ]; then
      return 0
    fi
    # empty decision (python3 blew up) -> fall through to the bash guard.
  fi
  if [ -z "${_mt_decision:-}" ]; then
    # python3 absent OR errored: weaker-but-safe guard. Because Step 4a seeds DEST
    # with the default, "key present" is almost always true here; but a key that is
    # the shipped default is safe to re-import (idempotent), and a diverged value is
    # protected because copy-forward below only runs when we DON'T skip. To never
    # clobber a teacher edit without python3, skip when the DEST value already
    # differs from the shipped default.
    _mt_cur="$(json_bool "$_mt_dest" "$_mt_key")"
    [ "$_mt_is_string" = 1 ] && _mt_cur="$(json_str "$_mt_dest" "$_mt_key")"
    if [ -n "$_mt_cur" ] && [ "$_mt_cur" != "$_mt_default" ]; then
      return 0
    fi
  fi

  # (3) COPY-FORWARD (correctness-bearing): read the legacy value and atomically
  #     write it into DEST. Skip the write when the legacy value is an explicit
  #     null (generate_student_slides UNSET semantics) — DEST keeps its default.
  _mt_wrote=0
  if [ "$_mt_legacy_is_null" = 0 ]; then
    if command -v python3 >/dev/null 2>&1; then
      # python3 parse DEST -> set DEST[key] = legacy[key] -> os.replace (atomic,
      # indent=2, ensure_ascii=False so German notes survive).
      if python3 - "$_mt_dest" "$_mt_legacy" "$_mt_key" <<'PY' >/dev/null 2>&1
import json, os, sys
dest, legacy, key = sys.argv[1], sys.argv[2], sys.argv[3]
with open(legacy) as f:
    lv = json.load(f)
if key not in lv or lv[key] is None:
    sys.exit(1)   # nothing to carry (guarded by caller, but re-check)
try:
    with open(dest) as f:
        d = json.load(f)
    if not isinstance(d, dict):
        d = {}
except Exception:
    d = {}
d[key] = lv[key]
tmp = dest + ".tmp." + str(os.getpid())
with open(tmp, "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, dest)
PY
      then
        _mt_wrote=1
      fi
    fi
    if [ "$_mt_wrote" = 0 ]; then
      # Bash-only fallback: DEST is OUR OWN small flat file, so rebuild it
      # key-by-key from the three known toggles, substituting the carried value.
      # Read the three current DEST values (fall back to shipped defaults), then
      # override the carried key with the legacy value, then atomic_write the whole
      # file. Reading a scalar legacy value is low-risk (a mis-read = no override).
      if [ "$_mt_is_string" = 1 ]; then
        _mt_val="$(json_str "$_mt_legacy" "$_mt_key")"
      else
        _mt_val="$(json_bool "$_mt_legacy" "$_mt_key")"
      fi
      if [ -n "$_mt_val" ]; then
        # current DEST values (default when unreadable/absent)
        _bd_icc="$(json_bool "$_mt_dest" internal_compliance_check)"; [ -n "$_bd_icc" ] || _bd_icc="true"
        _bd_pov="$(json_str  "$_mt_dest" pdf_on_validation)";         [ -n "$_bd_pov" ] || _bd_pov="student_facing"
        _bd_gss="$(json_bool "$_mt_dest" generate_student_slides)";   [ -n "$_bd_gss" ] || _bd_gss="true"
        # a stored null in DEST is not a valid effective override here -> default
        [ "$_bd_icc" = "null" ] && _bd_icc="true"
        [ "$_bd_gss" = "null" ] && _bd_gss="true"
        case "$_mt_key" in
          internal_compliance_check) _bd_icc="$_mt_val" ;;
          pdf_on_validation)         _bd_pov="$_mt_val" ;;
          generate_student_slides)   _bd_gss="$_mt_val" ;;
        esac
        # Build with a trailing newline (the trailing \n survives because it is
        # NOT stripped by $() — atomic_write writes content verbatim via printf %s,
        # so we append the newline through the format and a sentinel non-newline
        # char is unnecessary; instead assemble without command substitution).
        _mt_body="{
  \"internal_compliance_check\": $_bd_icc,
  \"pdf_on_validation\": \"$_bd_pov\",
  \"generate_student_slides\": $_bd_gss
}
"
        if atomic_write "$_mt_dest" "$_mt_body"; then
          _mt_wrote=1
        fi
      fi
    fi
  fi

  # (4) DELETE the legacy key (hygiene only): python3 parse -> pop -> os.replace.
  #     FAIL-OPEN: python3 absent OR the delete fails for ANY reason -> LEAVE the
  #     key in place (inert; nothing reads it; the divergence guard prevents a
  #     re-import over a teacher edit). NEVER structurally rewrite a teacher's rich
  #     legacy JSON with raw sed.
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$_mt_legacy" "$_mt_key" <<'PY' >/dev/null 2>&1 || true
import json, os, sys
legacy, key = sys.argv[1], sys.argv[2]
try:
    with open(legacy) as f:
        d = json.load(f)
except Exception:
    sys.exit(0)   # unreadable/malformed -> leave byte-identical (fail-open)
if key in d:
    del d[key]
    tmp = legacy + ".tmp." + str(os.getpid())
    with open(tmp, "w") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, legacy)
PY
  fi

  # Emit the migrated=<key> summary token iff the value was carried forward.
  [ "$_mt_wrote" = 1 ] && printf 'migrated=%s\n' "$_mt_key"
  return 0
}

# --- 1. current version ------------------------------------------------------
[ -f "$plugin_json" ] || { echo "migrate=noop reason=no-plugin-json" >&2; exit 0; }
current_version="$(json_str "$plugin_json" version)"
[ -n "$current_version" ] || { echo "migrate=noop reason=no-current-version" >&2; exit 0; }

# --- 2. version.json ABSENT -> first-run create, NO update flow --------------
# NO config copy here — that rule is unchanged and deliberate. The ONE additive step
# this branch does run is 2a, the digest-pack seed: without it a workspace that
# reaches this branch on a pack-shipping build is stamped current and can never be
# seeded by any later path (every later run takes branch 3). See "WHY THE SEED ALSO
# FIRES ON BRANCH 2" in the header for why that does not conflict with the
# no-update-flow rule. Deliberate, not an accident — do not "restore" this branch by
# deleting the seed.
if [ ! -f "$version_file" ]; then
  # 2a. seed BEFORE the stamp, for the same reason 4e precedes 4b: if the stamp
  #     lands and the seed did not, the workspace is silently stamped as done; if
  #     the seed lands and the stamp does not, the next run re-enters this branch and
  #     the create-only seed is a cheap no-op. Seed-first is the safe order.
  seeded="$(seed_digest_pack)
"
  atomic_write "$version_file" "$(version_json_body "$current_version" "$(now_utc)")"
  # first-run summary (only if the stamp actually landed; else stay silent no-op)
  if [ -f "$version_file" ]; then
    printf 'migrate=first-run\n'
    printf 'new_version=%s\n' "$current_version"
    # one `seeded=<document_id> entries=<n>` line per seeded document (none when
    # nothing was seeded). Emitted only inside this successful-stamp branch, mirroring
    # the readme=/copied= convention: the stdout summary matches a landed stamp.
    printf '%s' "$seeded" | while IFS= read -r sline; do
      [ -n "$sline" ] && printf '%s\n' "$sline"
    done
  fi
  exit 0
fi

last_seen="$(json_str "$version_file" plugin_version)"

# --- 3. EQUAL -> strict no-op, STDOUT EMPTY ----------------------------------
if [ "$current_version" = "$last_seen" ]; then
  echo "migrate=noop reason=versions-equal" >&2
  exit 0
fi

# --- 4. DIFFER -> update flow (UNCONDITIONAL on changelog content) -----------

# 4a. copy net-new config defaults (never overwrite; skip .gitkeep; empty-glob guard).
# Collect copied leaves NEWLINE-separated (not comma-joined): a filename may itself
# contain a comma, which a single comma-joined line would mis-parse. The summary
# emits one `copied=<name>` line per file, so the model greps each line safely.
copied=""
if [ -d "$config_defaults" ]; then
  mkdir -p "$config_dir" 2>/dev/null || true
  for f in "$config_defaults"/*; do
    [ -e "$f" ] || continue                 # empty-glob guard
    base="$(basename "$f")"
    [ "$base" = ".gitkeep" ] && continue
    dest="$config_dir/$base"
    [ -e "$dest" ] && continue              # Protected-Files: never overwrite
    if cp "$f" "$dest" 2>/dev/null; then
      copied="${copied}${base}
"
    fi
  done
fi

# 4d. migrate the behaviour toggles into data/config/behaviour.json.
# Runs AFTER 4a's copy loop, BEFORE 4b's stamp. Carries each teacher's existing
# toggle value from its legacy profile file into the new two-tier config location,
# safely and idempotently (copy-forward-then-guarded-delete, FIX 1). The migrated=
# summary lines are CAPTURED here and emitted AFTER the copied= block (below), so
# the summary order stays copied= ... then migrated= ... . All work is fail-open:
# a per-toggle failure is a silent no-op; the outer flow is never aborted.
migrated=""
behaviour_dest="$config_dir/behaviour.json"
prefs="$WORKSPACE_ROOT/data/profiles/teacher-preferences.json"
profile="$WORKSPACE_ROOT/data/profiles/teacher-profile.json"
# Defensive: 4a normally seeded behaviour.json; recreate from the shipped default
# if a teacher deleted it, so Step 4d can overlay onto a real file.
if [ ! -e "$behaviour_dest" ] && [ -f "$config_defaults/behaviour.json" ]; then
  cp "$config_defaults/behaviour.json" "$behaviour_dest" 2>/dev/null || true
fi
# Only proceed if the dest is now a real file (fail-open otherwise).
if [ -f "$behaviour_dest" ]; then
  # Three UNROLLED calls (no arrays): two toggles from teacher-preferences.json,
  # one from teacher-profile.json. IS_STRING: pdf_on_validation is a quoted enum (1);
  # the two booleans are bare (0).
  migrated="${migrated}$(migrate_toggle "$behaviour_dest" "$prefs"    internal_compliance_check 0)
"
  migrated="${migrated}$(migrate_toggle "$behaviour_dest" "$prefs"    pdf_on_validation         1)
"
  migrated="${migrated}$(migrate_toggle "$behaviour_dest" "$profile"  generate_student_slides   0)
"
fi

# 4e. seed the shipped pre-read digest pack into data/.cache/ (create-only per entry
# file; the copy itself lives in scripts/seed-digest-cache.sh, one implementation for
# both callers). Runs AFTER 4a's copy loop and 4d's toggle migration, BEFORE 4b's
# stamp — the same ordering convention 4d states, and for the same reason: a stamp
# failure must never claim a migration that did not land. The `seeded=` lines are
# CAPTURED here and emitted after the migrated= block (below), so the summary order
# stays copied= ... migrated= ... seeded= . Fail-open: a seed failure is a silent
# no-op that neither aborts the flow nor suppresses the stamp.
seeded="$(seed_digest_pack)
"

# 4b. atomically stamp version.json to the current version + fresh timestamp.
# If the stamp did NOT land (unwritable data/), report a failure summary that
# matches disk state — do NOT claim migrate=update when nothing was stamped.
if atomic_write "$version_file" "$(version_json_body "$current_version" "$(now_utc)")"; then
  # 4c. state-delta summary (stdout). MAJOR = leading X differs old->new.
  if [ "$(major_of "$current_version")" != "$(major_of "$last_seen")" ]; then
    major="true"
  else
    major="false"
  fi
  printf 'migrate=update\n'
  printf 'old_version=%s\n' "$last_seen"
  printf 'new_version=%s\n' "$current_version"
  printf 'major=%s\n' "$major"
  # protective data-root README cue: report — do NOT write — that the README is
  # absent, so the caller has a deterministic trigger to re-seed it. `-e` treats any
  # node (including a teacher-emptied 0-byte file) as present, matching the
  # never-overwrite existence-check-only contract. Emitted ONLY inside this
  # successful-stamp branch, so the cue never claims a re-seed obligation for a
  # migration that did not reach disk. No token when the README exists (its absence
  # is the "present, do nothing" signal — same convention as `copied=`).
  [ ! -e "$WORKSPACE_ROOT/data/README.md" ] && printf 'readme=missing\n'
  # one `copied=<name>` line per file (empty when nothing was copied -> no lines).
  printf '%s' "$copied" | while IFS= read -r name; do
    [ -n "$name" ] && printf 'copied=%s\n' "$name"
  done
  # one `migrated=<key>` line per behaviour toggle carried forward by Step 4d
  # (empty when nothing was carried -> no lines). Emitted AFTER the copied= block,
  # so the summary order is copied= ... then migrated= ... . The migrate_toggle
  # calls already produced each `migrated=<key>` line; re-print them verbatim here.
  printf '%s' "$migrated" | while IFS= read -r mline; do
    [ -n "$mline" ] && printf '%s\n' "$mline"
  done
  # one `seeded=<document_id> entries=<n>` line per pack document that received
  # net-new entries in Step 4e (empty when nothing was seeded -> no lines). Emitted
  # LAST, and only inside this successful-stamp branch, so the summary never reports
  # a seed for a migration that did not reach disk — the same discipline the
  # copied=/readme= tokens follow.
  printf '%s' "$seeded" | while IFS= read -r sline; do
    [ -n "$sline" ] && printf '%s\n' "$sline"
  done
else
  # Stamp did not land: fail-open, no teacher-visible warning, summary to stderr.
  echo "migrate=noop reason=stamp-failed" >&2
fi

exit 0
