# Thalura — Persistent Storage Architecture

> **Path convention (two-root model):** Shipped plugin files are addressed `${CLAUDE_PLUGIN_ROOT}/…` (a runtime-substituted environment variable in Claude Code; in Claude Cowork it is unset and the startup sequence binds it once). Teacher data and generated output share the Tier-2 root `<WORKSPACE_ROOT>/…`, resolved once at startup via `${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh`. `<WORKSPACE_ROOT>` is prose-only — never put it in a shell command; pass the resolved absolute path instead. All `data/…` paths below are under `<WORKSPACE_ROOT>/`.

All mutable user data lives in `<WORKSPACE_ROOT>/data/`. This directory is created by `/thalura:setup` and managed by the plugin at runtime. It is separate from the plugin bundle and from the output folders (`<WORKSPACE_ROOT>/{Subject}/...`). For the output-side architecture, see `output-architecture.md`.

## Directory Tree

```
data/
  README.md                            — protective README: Thalura manages this folder; written in conversation_language
  assets/
    school-logo-original.png            — cropped original logo (kept for re-derivation)
    school-logo-on-primary.png          — white variant for dark slide backgrounds
    school-logo-on-white.png            — original-color variant for white slide backgrounds
  config/
    naming-conventions.json            — document and folder naming patterns
  profiles/
    teacher-profile.json               — teacher identity, subjects, language
    school-config.json                 — school identity, lesson slots
    teacher-preferences.json           — validated teaching preferences (Layer 2)
    teacher-observations.json          — tracked patterns, not yet validated (Layer 1)
  library/
    english.json                       — shelved and imported units for English
    philosophy.json                    — shelved and imported units for Philosophy
    religion.json                      — shelved and imported units for Religion
    materials/                         — snapshot materials for Library units, by unit_id
      lib_globalisation_001/
        Globalisation - Einheitenplanung.docx     — snapshot root: unit plan document
        lessons/                                   — CANONICAL keys (locale-neutral)
        materials/
        assessments/                               — flat, or numbered subfolders preserved
      lib_shakespeare_001/
        Shakespeare-Sonnets - Einheitenplanung.docx
        lessons/
        materials/
        assessments/
  school-years/
    2025-26/
      plan.json                        — school year plan with unit data per class
      classes/
        english_10a.json               — class definition (E10a)
        english_10b.json               — parallel class (E10b)
        philosophy_S4.json             — Sek II class (PS4)
        religion_8a.json               — class definition (R8a)
    2026-27/
      plan.json
      classes/
        english_S1.json                — previous_year links to 2025-26/E10a
        philosophy_S1.json
  regulations/
    sic/
      README.md                        — explains expected format and usage, written in conversation_language
      english/                         — school-internal curriculum
      philosophy/
      psychology/
      religion/
```

**Note:** The Library (`<WORKSPACE_ROOT>/data/library/`) is year-independent. It sits outside `school-years/` because Library units span all school years.

## Naming Conventions

### Directory names

English, lowercase throughout: `school-years/`, `classes/`, `profiles/`, `library/`, `config/`, `regulations/`.

### File names

| Entity | Pattern | Sek I Example | Sek II Example |
|---|---|---|---|
| Class definition | `{subject}_{grade_level}{section}.json` | `english_10a.json` | `philosophy_S4.json` |
| Library file | `{subject}.json` | `english.json` | — |
| Library materials | `materials/{unit_id}/` | `materials/lib_globalisation_001/` | — |

- `{subject}` is the English subject name: `english`, `philosophy`, `religion` (mapped from subject ID via `${CLAUDE_PLUGIN_ROOT}/references/subjects.json`)
- `{grade_level}` is `5`–`10` for Sek I or `S1`–`S4` for Sek II
- `{section}` is a lowercase letter (`a`, `b`, `c`); omitted for Sek II classes that have no section
- School year folder format: `YYYY-YY` (e.g., `2025-26`)

## class_id Convention

The `class_id` is auto-generated from the class definition fields. The teacher never types it manually.

**Formula:** `{subject_abbreviation}{grade_level}{section?}`

| Subject | Abbreviation | Sek I Example | Sek II Example |
|---|---|---|---|
| Englisch | `E` | `E10a`, `E5b` | `ES2`, `ES4a` (rare) |
| Philosophie | `P` | `P10a`, `P9b` | `PS4`, `PS1` |
| Psychologie | `Psy` | `Psy10a`, `Psy9b` | `PsyS4`, `PsyS1` |
| Religion | `R` | `R8a`, `R10a` | `RS3` |

Subject abbreviations are defined in `${CLAUDE_PLUGIN_ROOT}/references/subjects.json`.

The `class_id` is a display identifier used in document filenames and conversation. The file path `<WORKSPACE_ROOT>/data/school-years/{year}/classes/{subject}_{grade_level}{section}.json` provides global uniqueness across school years.

## Quick Reference

| I need... | Path |
|---|---|
| Teacher profile | `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json` |
| School config | `<WORKSPACE_ROOT>/data/profiles/school-config.json` |
| Teacher preferences | `<WORKSPACE_ROOT>/data/profiles/teacher-preferences.json` |
| Class definition for E10a in 2025-26 | `<WORKSPACE_ROOT>/data/school-years/2025-26/classes/english_10a.json` |
| Class definition for PS4 in 2025-26 | `<WORKSPACE_ROOT>/data/school-years/2025-26/classes/philosophy_S4.json` |
| Current school year plan | `<WORKSPACE_ROOT>/data/school-years/{current-year}/plan.json` |
| Library units for Philosophy | `<WORKSPACE_ROOT>/data/library/philosophy.json` |
| Library materials for a unit | `<WORKSPACE_ROOT>/data/library/materials/{unit_id}/` |
| School-internal curriculum for English | `<WORKSPACE_ROOT>/data/regulations/sic/english/` |
| School logo (original) | `<WORKSPACE_ROOT>/data/assets/school-logo-original.png` |
| School logo (on-primary) | `<WORKSPACE_ROOT>/data/assets/school-logo-on-primary.png` |
| School logo (on-white) | `<WORKSPACE_ROOT>/data/assets/school-logo-on-white.png` |
| Naming config overrides | `<WORKSPACE_ROOT>/data/config/naming-conventions.json` |

## Key Design Decisions

- **School year from folder path:** No `school_year` field in class definitions. Derived from `<WORKSPACE_ROOT>/data/school-years/{year}/`. Cross-year references use `{year}/{class_id}` format.
- **class_id auto-generated:** `{abbr}{grade_level}{section?}` — abbreviations from `${CLAUDE_PLUGIN_ROOT}/references/subjects.json`. Teacher provides subject, grade_level, and section; class_id is derived.
- **grade_level as string:** Accommodates both Sek I integers (`"5"`–`"10"`) and Sek II semester codes (`"S1"`–`"S4"`). Hamburg Sek II semesters are legally distinct units that independently contribute to Abitur grades.
- **section optional for Sek II:** Sek II classes typically have no parallel sections. `section` is `null` by default for Sek II.
- **course_level uses regulatory abbreviations:** `"gA"` and `"eA"` are official BSB Hamburg terms, kept as-is.
- **Library year-independent:** `<WORKSPACE_ROOT>/data/library/` sits outside `school-years/`. Units span all years.
- **SiC at user level:** School-internal curriculum in project folder, not plugin bundle.
- **School config separate from teacher profile:** `school-config.json` stores school identity (`school_name`) and operational data (`lesson_slots`). Teacher profile references via `school_id`.
- **Outputs separate from data:** `data/` is plugin-internal; outputs live at `<WORKSPACE_ROOT>/{Subject}/...` with capitalized paths. See `output-architecture.md`.
- **Single-file architecture:** Each command produces standalone files. No combined compendium.
- **Branding assets in `<WORKSPACE_ROOT>/data/assets/`:** School logo stored alongside other mutable data. Directory created only when branding includes a logo. No fallback logo in plugin bundle.

## Schema Files

| Schema | File | Status |
|---|---|---|
| Class definition | `schemas/class-definition.md` | Complete |
| School year plan | `schemas/school-year-plan.md` | Complete |
| Library subject | `schemas/library-subject.md` | Full reconciled schema (library entry = unit bundle body) |
| Teacher profile | `schemas/teacher-profile.md` | Complete |
| School config | `schemas/school-config.md` | Complete |
| Unit manifest (`plan.json`) | `schemas/unit-manifest.md` | Complete |

## Migration Transformation Rules

These rules document how the plugin's data format was derived from the legacy
skill it replaced. The migration is complete; this section is kept as
historical reference for understanding field-by-field equivalences.

### Class Definition Migration

| Old Field | Old Example | Transformation | New Field |
|---|---|---|---|
| `metadata.subject` | `"Philosophie"` | Map to English ID: Englisch→`"english"`, Philosophie→`"philosophy"`, Religion→`"religion"` | `subject` |
| `metadata.grade` | `"S4"` | Keep as string. Sek II: stays `"S4"`. Sek I integers: convert to string (`10` → `"10"`). | `grade_level` |
| `metadata.school_year` | `"2025-2026"` | **Discard.** School year is derived from folder path. Folder format: `2025-26` (truncate second year to 2 digits). | — |
| `metadata.anforderungsniveau` | `"gA"` | Keep as-is (official BSB format) | `course_level` |
| `metadata.class_id` | `"PS4_2025-2026"` | **Regenerate** from `{abbr}{grade_level}{section?}` | `class_id` (`"PS4"`) |
| `class_size` | `22` | Direct copy | `student_count` |
| `special_needs` | `[]` (flat array) | Structure into `[{ "type": ..., "count": ..., "accommodations": [...] }]` | `special_needs` |
| `differentiation_notes` | `"Keine..."` | Direct copy | `differentiation_notes` |
| `prior_knowledge` | `null` | Direct copy | `prior_knowledge` |
| `class_observations` | `{ "positive": [], "negative": [] }` | Merge arrays into single string. If both empty: `null`. | `class_observations` |
| `notes` | `["Kein Schueler..."]` | Join array into single string with newlines. If empty array: `null`. | `notes` |
| `continuity_link` | `null` | If set: convert to `{year}/{class_id}` format | `previous_year` |
| `last_updated` | `"2026-02-20"` | Convert to ISO-8601 | `created_at` |
| — (missing) | — | Default: `null` for Sek II, `"a"` for Sek I | `section` |

### School Year Plan Migration

| Old Field | Transformation | New Field |
|---|---|---|
| `metadata.subject` | Map to English ID | `plans[].subject` |
| `metadata.grade` + section | Derive class_id | `plans[].class_id` |
| `units[]` | Map to new unit schema | `plans[].units[]` |
| `competencies_covered[]` | Map to `competency_coverage` ratios (approximate, or `{}` if no data) | `plans[].competency_coverage` |
| `metadata.anforderungsniveau` | Not stored in plan — only in class definition | — |

### Files to Discard

| Old File | Reason |
|---|---|
| `config/asset-counters.json` | Replaced by folder-derived material numbering (M1, M2, ...) |
| `config/output-language.json` | Migrated into teacher profile language settings |

### Structural Changes

- Old school year files use `"2025-2026"` format → new folders use `"2025-26"`
- Old class files encode subject + grade + year in filename → new files use `{subject}_{grade_level}{section}.json`
- Old `class_observations` is a structured object → new is a flat string
- Old `notes` is an array → new is a flat string
- Old `class_id` embeds year → new `class_id` is year-independent (year from folder path)

## Acceptance Criteria Checklist

- [x] All JSON schemas defined with English keys
- [x] Hierarchical structure: `<WORKSPACE_ROOT>/data/school-years/{year}/classes/{subject}_{grade_level}{section}.json`
- [x] `class_id` auto-generated from subject abbreviation + grade_level + section
- [x] `section` field in class definition (required Sek I, optional Sek II)
- [x] No `school_year` field in class definition — derived from folder path
- [x] Class filenames use English subject names (`english`, `philosophy`, `religion`)
- [x] No flat `classes/` top-level directory
- [x] Library at `<WORKSPACE_ROOT>/data/library/` — year-independent, one JSON per subject
- [x] Library materials at `<WORKSPACE_ROOT>/data/library/materials/{unit_id}/`
- [x] Class definition includes `course_level`, `special_needs`, `differentiation_notes`, `prior_knowledge`, `class_observations`
- [x] School year plan unit schema includes `source`, `competency_areas`, `output_path`, `modified_at`, `modification_notes`, `reflection`
- [x] No `unit_compendium_path` — replaced by `output_path` pointing to unit folder
- [x] `competency_coverage` aggregation at class level in school year plan
- [x] `previous_year` linking via `{year}/{class_id}`
- [x] SiC directory structure with per-subject subdirectories in English
- [x] All file paths documented with `data/` prefix
- [x] Backward compatibility with skill version data assessed
- [x] Migration transformation rules documented (including section default)
- [x] No German terms in JSON keys
