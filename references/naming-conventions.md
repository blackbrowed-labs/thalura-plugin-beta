# Thalura — Naming Conventions Reference

This document specifies the template variable system used in `naming-conventions.json` for generating document filenames.

## Two-Tier Override

Naming patterns follow the two-tier config system (see `config-system.md`):

1. **Plugin defaults:** `${CLAUDE_PLUGIN_ROOT}/config-defaults/naming-conventions.json`
2. **Teacher overrides:** `<WORKSPACE_ROOT>/data/config/naming-conventions.json`

At runtime, teacher values override plugin defaults. Missing keys fall back to defaults. Teachers customize patterns via `/thalura:config naming`.

---

## Template Variables

### Context Variables

Resolved from the current unit, class, and subject context.

| Variable | Source | Example | Notes |
|---|---|---|---|
| `{subject_abbr}` | `subjects.json` → abbreviation | `E`, `P`, `Psy`, `R` | Subject abbreviation |
| `{grade}` | Class definition | `10a`, `S4` | Grade level + section |
| `{unit_title}` | Unit plan | `Globalisation` | Slug-formatted (see Slug Rules below) |
| `{lesson}` | Lesson sequence | `01`, `02` | Zero-padded, matches unit plan sequence |
| `{seq}` | Material sequence | `01`, `02` | Unit-scoped sequential (see Material Numbering) |
| `{group}` | Differentiation group | `A`, `B`, `C` | Neutral group letter (see Differentiation Naming) |
| `{access}` | Access level | `1`, `2`, `3` | Numeric access level within a group |
| `{format}` | Assessment format | `Klausur`, `Kurztest` | Localized assessment type name from `assessment_types` |
| `{material_title}` | Material description | `Worksheet-Metaphors` | Slug-formatted (see Slug Rules below) |
| `{school_year}` | School year plan | `2025-26` | Workspace-wide year overview (Schuljahresübersicht) only; the plan's `YYYY-YY` string. No subject/grade prefix. |

### Label Variables

Resolved via `localization.json` → `{conversation_language}.naming_labels`. These replace what was previously hardcoded German in the pattern values.

| Variable | Localization Key | DE | EN |
|---|---|---|---|
| `{unit_plan_label}` | `naming_labels.unit_plan` | Einheitenplanung | UnitPlan |
| `{lesson_plan_label}` | `naming_labels.lesson_plan` | Verlaufsplan | LessonPlan |
| `{assessment_student_label}` | `naming_labels.assessment_student` | Aufgabe | Task |
| `{assessment_rubric_label}` | `naming_labels.assessment_rubric` | Erwartungshorizont | Rubric |
| `{reflection_label}` | `naming_labels.reflection` | Reflexion | Reflection |
| `{materials_overview_label}` | `naming_labels.materials_overview` | Materialübersicht | MaterialOverview |
| `{year_overview_label}` | `naming_labels.year_overview` | Schuljahresübersicht | YearOverview |

---

## Slug Rules

Title variables (`{unit_title}`, `{material_title}`) are converted to filename-safe slugs:

1. **Preserve spaces** — `.docx` files support spaces in filenames
2. **Preserve umlauts** — `ä`, `ö`, `ü`, `Ä`, `Ö`, `Ü`, `ß` are kept as-is
3. **Strip special characters** — keep only `A-Za-z0-9äöüÄÖÜß -` (letters, digits, spaces, hyphens)
4. **Truncate** — max 80 characters for `{unit_title}` and `{material_title}`
5. **No trailing spaces or hyphens** — trim after truncation

---

## Draft Suffix

The draft suffix (`_ENTWURF` / `_DRAFT`) is **not** part of the configurable naming patterns. It is system-managed:

- Appended automatically when a document enters draft state
- Removed automatically upon validation
- Localized via `localization.json` → `{conversation_language}.system_labels.draft_suffix`
- Inserted before the file extension: `E10a - Globalisation - Einheitenplanung_ENTWURF.docx`

See `output-architecture.md` for the full 8-step draft workflow.

---

## Material Numbering

Material numbers are **unit-scoped sequential** IDs:

- Format: `M{seq}` where `{seq}` is zero-padded two digits (`M01`, `M02`, `M03`, ...)
- Resets per unit — each unit starts at M01
- The current highest number is read from `plan.json` and incremented
- No global asset counter across units

---

## Differentiation Naming

Differentiated materials use a **three-level neutral suffix** system:

| Level | Pattern | Example | Meaning |
|---|---|---|---|
| Base material | `M{seq}` | `M02` | Original, undifferentiated |
| Group variant | `M{seq}-{group}` | `M02-A` | Variant for group A |
| Access level | `M{seq}-{group}-{access}` | `M02-A-1` | Access level 1 within group A |

- Group letters (`A`, `B`, `C`) are neutral — they do not encode difficulty or ability
- The mapping of groups to support needs is documented in `plan.json`, not in the filename
- Access levels within a group provide graduated scaffolding (e.g., additional hints, simplified language)

The naming pattern for differentiated materials uses the `material_group` and `material_group_access` patterns from `naming-conventions.json`.

---

## Image Numbering

Image IDs are **material-scoped sequential** IDs, defined in `naming-conventions.json` under `identifiers.image_id`:

- Format: `IMG-{seq}` where `{seq}` is zero-padded two digits (`IMG-01`, `IMG-02`, `IMG-03`, ...)
- Resets per material — each material starts at IMG-01
- Image IDs are used for alt-text naming (`wp:docPr[@name]`), `plan.json` tracking, and proposal references
- Pattern is configurable via the two-tier system (teacher override in `<WORKSPACE_ROOT>/data/config/naming-conventions.json`)

---

## Unit Identifiers (Library)

Library units carry a workspace-unique identifier, defined in `naming-conventions.json` under `identifiers.unit_id`:

- Format: `lib_{slug}_{sequence}` (e.g. `lib_globalisation_001`)
- `{slug}` = the unit's `unit_slug` lowercased kebab-case (`[a-z0-9-]+`; `"Poetry-Unit"` → `"poetry-unit"`)
- `{sequence}` = a zero-padded **three-digit** counter **per slug** within the workspace, starting `001` (`lib_globalisation_001`, `lib_globalisation_002`, ...)
- Keys the library snapshot folder (`<WORKSPACE_ROOT>/data/library/materials/{unit_id}/`) and back-references from an assigned unit's manifest
- Pattern is configurable via the two-tier system (teacher override in `<WORKSPACE_ROOT>/data/config/naming-conventions.json`)

---

## Example: Resolved Filenames

Given: subject=English (abbr: E), grade=10a, unit="Globalisation", conversation_language=de

| Pattern Key | Resolved Filename |
|---|---|
| `unit_plan` | `E10a - Globalisation - Einheitenplanung.docx` |
| `lesson_plan` (lesson 01) | `E10a - Globalisation - Verlaufsplan 01.docx` |
| `material` (M01) | `E10a - Globalisation - M01 - Worksheet-Metaphors.docx` |
| `material_group` (M02-A) | `E10a - Globalisation - M02-A - Reading-Text.docx` |
| `assessment_student` | `E10a - Globalisation - Klausur - Aufgabe.docx` |
| `assessment_rubric` | `E10a - Globalisation - Klausur - Erwartungshorizont.docx` |
| `reflection` | `E10a - Globalisation - Reflexion.docx` |
| `materials_overview` | `E10a - Globalisation - Materialübersicht.docx` |

Same unit with conversation_language=en:

| Pattern Key | Resolved Filename |
|---|---|
| `unit_plan` | `E10a - Globalisation - UnitPlan.docx` |
| `lesson_plan` (lesson 01) | `E10a - Globalisation - LessonPlan 01.docx` |
| `assessment_student` | `E10a - Globalisation - Klausur - Task.docx` |
| `assessment_rubric` | `E10a - Globalisation - Klausur - Rubric.docx` |
| `reflection` | `E10a - Globalisation - Reflection.docx` |
| `materials_overview` | `E10a - Globalisation - MaterialOverview.docx` |
