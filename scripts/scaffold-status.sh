#!/usr/bin/env bash
# scaffold-status.sh — deterministic scaffold-completeness detection for a
# Thalura teacher workspace. DETECTION ONLY: reads, never writes, never deletes.
#
# Usage:
#   scaffold-status.sh <PLUGIN_ROOT> <WORKSPACE_ROOT>
#     $1 PLUGIN_ROOT    — the shipped plugin root (holds config-defaults/,
#                         references/, .claude-plugin/). Passed in, NEVER
#                         self-discovered here.
#     $2 WORKSPACE_ROOT — the teacher workspace root (holds data/).
#
# stdout token contract (one line per item; deterministic order):
#   scaffold=complete | scaffold=incomplete | scaffold=unknown | scaffold=no-profile
#   dir=missing:<rel-path>            config_default=missing:<file>
#   exam_template=missing             library_index=missing:<subject_id>
#   sic_readme=missing                readme=missing
#   output_root=missing:<subject>:<year>   year_scaffold=missing:<year>
#   plan_skeleton=missing:<year>      profile_shell=missing:<file>
#   version_stamp=missing             school_config=missing
#   branding=configured logo=missing:<file>
#   branding=configured template=<absent|palette-only|modified|unstamped>
#
# Exit codes: 0 (complete / incomplete / unknown — detection is advisory),
#             10 (no-profile — the workspace is not set up).
# Fail-open: any internal error -> "scaffold=unknown", exit 0.
#
# Testability overrides (unset in production):
#   THALURA_SCAFFOLD_YEAR  overrides the derived current school year
set -u
[ "$#" -ge 2 ] || { echo "scaffold=unknown"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "scaffold=unknown"; exit 0; }
python3 - "$1" "$2" <<'PYEOF'
import json, os, sys, hashlib, datetime

def main():
    plug, ws = sys.argv[1], sys.argv[2]
    profile_p = os.path.join(ws, 'data/profiles/teacher-profile.json')
    if not os.path.isfile(profile_p):
        print("scaffold=no-profile"); return 10

    tokens = []
    profile = json.load(open(profile_p))
    lang = profile.get('conversation_language') or 'de'
    subjects = [s.get('id') for s in profile.get('subjects', [])
                if isinstance(s, dict) and s.get('id')]
    loc = json.load(open(os.path.join(plug, 'references/localization.json')))
    subj_names = (loc.get(lang) or {}).get('subjects') or {}

    # 1) Unconditional directories (setup Phase 5.2)
    for d in ('data/config', 'data/profiles', 'data/library',
              'data/library/materials', 'data/school-years',
              'data/regulations/sic', 'data/exam-formats'):
        if not os.path.isdir(os.path.join(ws, d)):
            tokens.append('dir=missing:%s' % d)

    # 2) Two-tier copies (setup Phase 6.1 / 6.1b); dotfiles skipped
    cfg_dir = os.path.join(plug, 'config-defaults')
    if os.path.isdir(cfg_dir):
        for f in sorted(os.listdir(cfg_dir)):
            if f.startswith('.'):
                continue
            if os.path.isfile(os.path.join(cfg_dir, f)) and \
               not os.path.isfile(os.path.join(ws, 'data/config', f)):
                tokens.append('config_default=missing:%s' % f)
    if not os.path.isfile(os.path.join(ws, 'data/exam-formats/_template.md')):
        tokens.append('exam_template=missing')

    # 3) Per-subject scaffold (setup Phases 5.2 / 6.7)
    for s in subjects:
        if not os.path.isdir(os.path.join(ws, 'data/regulations/sic', s)):
            tokens.append('dir=missing:data/regulations/sic/%s' % s)
        if not os.path.isfile(os.path.join(ws, 'data/library', s + '.json')):
            tokens.append('library_index=missing:%s' % s)

    # 4) Localized seed files (setup Phases 6.8 / 6.9)
    if not os.path.isfile(os.path.join(ws, 'data/regulations/sic/README.md')):
        tokens.append('sic_readme=missing')
    if not os.path.isfile(os.path.join(ws, 'data/README.md')):
        tokens.append('readme=missing')

    # 5) Year-scoped scaffold (setup Phases 5.2 / 6.6): years present on disk,
    #    else the derived current year (strict boundary; non-interactive).
    sy_dir = os.path.join(ws, 'data/school-years')
    years = []
    if os.path.isdir(sy_dir):
        years = sorted(y for y in os.listdir(sy_dir)
                       if os.path.isdir(os.path.join(sy_dir, y))
                       and not y.startswith('.'))
    if not years:
        cur = os.environ.get('THALURA_SCAFFOLD_YEAR')
        if not cur:
            month, day = 8, 1
            try:
                sc0 = json.load(open(os.path.join(
                    ws, 'data/profiles/school-config.json')))
                fs = sc0.get('federal_state')
                edu = json.load(open(os.path.join(
                    plug, 'references/education-system.json')))
                for st in edu.get('federal_states', []):
                    if st.get('id') == fs:
                        b = st.get('school_year_start') or {}
                        month = int(b.get('month', 8)); day = int(b.get('day', 1))
            except Exception:
                month, day = 8, 1
            t = datetime.date.today()
            if (t.month, t.day) >= (month, day):
                cur = '%d-%02d' % (t.year, (t.year + 1) % 100)
            else:
                cur = '%d-%02d' % (t.year - 1, t.year % 100)
        tokens.append('year_scaffold=missing:%s' % cur)
        years = [cur]
    for y in years:
        if not os.path.isdir(os.path.join(sy_dir, y, 'classes')):
            tokens.append('dir=missing:data/school-years/%s/classes' % y)
        if not os.path.isfile(os.path.join(sy_dir, y, 'plan.json')):
            tokens.append('plan_skeleton=missing:%s' % y)
        for s in subjects:
            name = subj_names.get(s)
            if not name:
                continue  # unlocalizable subject id: no output-root token derivable
            if not os.path.isdir(os.path.join(ws, name, y)):
                tokens.append('output_root=missing:%s:%s' % (s, y))

    # 6) Profile shells (setup Phases 6.4 / 6.5)
    for f in ('teacher-preferences.json', 'teacher-observations.json'):
        if not os.path.isfile(os.path.join(ws, 'data/profiles', f)):
            tokens.append('profile_shell=missing:%s' % f)

    # 7) Version stamp (setup Phase 6.0, create-only here)
    if not os.path.isfile(os.path.join(ws, 'data/version.json')):
        tokens.append('version_stamp=missing')

    # 8) School config / branding surface (setup Phases 2.5.3a / 5.2)
    sc_p = os.path.join(ws, 'data/profiles/school-config.json')
    if not os.path.isfile(sc_p):
        tokens.append('school_config=missing')
    else:
        sc = json.load(open(sc_p))
        br = sc.get('branding')
        if isinstance(br, dict):
            if not os.path.isdir(os.path.join(ws, 'data/templates/materials')):
                tokens.append('dir=missing:data/templates/materials')
            for key in ('logo_path_on_primary', 'logo_path_on_white'):
                p = br.get(key)
                if p:
                    fp = p if os.path.isabs(p) else os.path.join(ws, p)
                    if not os.path.isfile(fp):
                        tokens.append('branding=configured logo=missing:%s'
                                      % os.path.basename(p))
            tpl = os.path.join(ws, 'data/templates/materials/template_slides.pptx')
            h = br.get('template_hash')
            if os.path.isfile(tpl):
                actual = hashlib.sha256(open(tpl, 'rb').read()).hexdigest()
                state = 'unstamped' if h is None else ('ok' if actual == h
                                                       else 'modified')
            else:
                state = 'palette-only' if h is None else 'absent'
            if state != 'ok':
                tokens.append('branding=configured template=%s' % state)

    if tokens:
        print('scaffold=incomplete')
        for t in tokens:
            print(t)
    else:
        print('scaffold=complete')
    return 0

try:
    sys.exit(main())
except SystemExit:
    raise
except Exception:
    print('scaffold=unknown')
    sys.exit(0)
PYEOF
rc=$?
case "$rc" in
  0|10) exit "$rc" ;;
  *) echo "scaffold=unknown"; exit 0 ;;
esac
