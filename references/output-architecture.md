# Thalura — Output Architecture

> **Path convention (two-root model):** Unit-scoped generated documents live under the Tier-2 root `<WORKSPACE_ROOT>/{Subject}/…`, the same root that holds `<WORKSPACE_ROOT>/data/…`; the one workspace-wide exception, the year overview (Schuljahresübersicht), sits at the `<WORKSPACE_ROOT>/` root itself (see § Year Overview). `<WORKSPACE_ROOT>` is model-resolved at startup (see `${CLAUDE_PLUGIN_ROOT}/references/storage-architecture.md`) and is prose-only. Shipped plugin files use `${CLAUDE_PLUGIN_ROOT}/…`.

All unit-scoped generated documents live in `<WORKSPACE_ROOT>/{Subject}/...`, alongside `data/`; the workspace-wide year overview (Schuljahresübersicht) is the sole root-level generated document (see § Year Overview). This directory structure is the teacher-facing output side of the plugin — separate from the data-side storage in `data/` (see `storage-architecture.md`).

## Architecture Principle

**Single-file architecture:** Each command produces its own standalone `.docx` file. There is no combined compendium or grow-pattern document. Claude Cowork generates all documents using its docx skill, based on structural specifications provided by the plugin.

## Output Location

```
<WORKSPACE_ROOT>/{Subject}/{school_year}/{class_id}/{Unit_slug}/
```

Subject folders sit at the root level of the Thalura project folder, alongside `data/`.

### Path Components

| Component | Format | Example | Notes |
|---|---|---|---|
| `{Subject}` | Localized subject name | `Englisch/`, `English/` | Resolved via `localization.json` based on `conversation_language`. Backend JSON stays lowercase (`"english"`). |
| `{school_year}` | `YYYY-YY` | `2025-26` | Unchanged format. |
| `{class_id}` | Auto-generated | `E10a`, `PS4` | From class definition. |
| `{Unit_slug}` | Capitalized kebab-case | `Globalisation/`, `Poetry-Unit/` | Human-readable unit identifier. |

### Example

```
<WORKSPACE_ROOT>/
├── data/                              ← Plugin-internal (config, profiles, library)
├── Englisch/ (English/)               ← Subject at root level (localized)
│   └── 2025-26/
│       ├── E10a/
│       │   ├── Globalisation/         ← Unit folder
│       │   └── Poetry-Unit/
│       └── E10b/
│           └── Shakespeare/
├── Philosophy/
│   └── 2025-26/
│       └── PS4/
│           └── Existenzialismus/
└── Religion/
    └── ...
```

## Unit Folder Structure

Each unit folder contains a manifest, root-level documents, and functional subfolders. All filenames and folder names are localized based on `conversation_language` via `localization.json`. German examples shown below; English equivalents in parentheses.

```
English/2025-26/E10a/Globalisation/
│
├── plan.json                                         ← Manifest (always plan.json, language-independent)
├── Einheitenplanung.docx  (UnitPlan.docx)            ← Living document (versioned in plan.json)
├── Materialübersicht.docx (MaterialOverview.docx)    ← Auto-regenerated on material-set changes
├── Reflexion.docx         (Reflection.docx)          ← Optional, from chat interview
│
├── Stunden/ (Lessons/)
│   ├── 01-Introduction_ENTWURF.docx (_DRAFT.docx)   ← Draft (not yet validated)
│   ├── 02-Close-Reading.docx                         ← Validated (may include reflection section)
│   └── 03-Analysis.docx
│
├── Materialien/ (Materials/)
│   ├── M01-Worksheet-Metaphors.docx
│   └── M02-Handout-Poetry-Terms.docx
│
└── Lernkontrollen/ (Assessments/)                    ← Single assessment: flat
    ├── Aufgabe.docx       (Task.docx)
    ├── Erwartungshorizont.docx (Rubric.docx)
    └── Abgaben/ (Submissions/)                       ← Excluded from backup + export
        └── (student submissions)
```

## Root-Level Files

### `plan.json`

Plugin-managed manifest. Schema defined in `schemas/unit-manifest.md`. Always named `plan.json` regardless of `conversation_language`.

- Tracks all documents, their status, versions, and cross-references
- Robust against manual file edits (consistency check on open — see below)
- Never manually edited by the teacher
- **Not** part of the draft workflow — auto-maintained

### `Einheitenplanung.docx` / `UnitPlan.docx`

Living unit plan document, overwritten when updated during lesson planning.

- Starts as `Einheitenplanung_ENTWURF.docx` / `UnitPlan_DRAFT.docx`
- After first validation: permanently `Einheitenplanung.docx` / `UnitPlan.docx`
- Version tracked in `plan.json` (integer + timestamp)
- Lesson detailing (the `lesson-detail` skill) refuses to run if still in draft status

### `Materialübersicht.docx` / `MaterialOverview.docx`

Auto-generated index of all unit materials.

- Lists ALL generated materials tracked in `plan.json` `materials[]` — validated AND draft — (with hyperlinks) AND standard supplies (Post-Its, markers, etc.) from lesson plans
- A draft material's entry shows its current draft filename (hyperlink to the `_{draft_suffix}` file) with the localized draft marker ({draft_marker} — de „(Entwurf)", en "(Draft)", resolved via `localization.json`); on validation the entry updates to the final filename and the marker is dropped
- Auto-regenerated on every event that changes the material set — a material draft landing (creation), a revision that renames a material file, a variant landing (differentiation), and validation — so the overview never looks stale next to the visible contents of `{materials}/`
- `.docx` format for teacher accessibility — no Markdown in output
- **Not** part of the draft workflow — auto-generated derivative, no draft suffix of its own

### `Schuljahresübersicht.docx` / `YearOverview.docx`

Auto-generated workspace-wide index of the current school year — one class block per class in the school-year plan, each listing that class's competency coverage (Kompetenzabdeckung) and units (Einheiten).

- Placed at the **workspace root** (`<WORKSPACE_ROOT>/`), not under a subject folder: the document spans **all** subjects, so no single subject folder can own it, and `data/` is plugin-internal and never surfaces teacher documents. The workspace root is the one folder the teacher always sees.
- **Current school year only.** One file per school year; the `{school_year}` suffix in the filename keeps a frozen previous-year file collision-free.
- Auto-regenerated on every content-mutating write to the current school year's `plan.json` — a unit registered, a status change, a revision, a reflection, a class plan entry added, a library assignment landing — so the overview never looks stale next to the year's actual state. A content-mutating write to a **past** school year's `plan.json` never regenerates it.
- **Not** part of the draft workflow — auto-generated derivative, no draft suffix of its own; never hand-edited (a teacher edit would be overwritten on the next regeneration).
- `.docx` format for teacher accessibility — no Markdown in output.

### `Reflexion.docx` / `Reflection.docx`

Optional unit-level reflection, created through structured chat interview.

- Standard `_ENTWURF`/`_DRAFT` → validation cycle applies
- Placed at root level (not in a subfolder)
- Always optional — no reminders, no enforcement

## Subfolder Conventions

### `Stunden/` / `Lessons/`

One file per lesson, sequentially numbered.

| Convention | Detail |
|---|---|
| Naming pattern | `{number}-{Topic}.docx` or `{number}-{Topic}_ENTWURF.docx` / `_DRAFT.docx` |
| Numbering | Sequential, matching the Einheitenplanung |
| Lesson reflection | Optional — appended as a section at the end of the lesson file |
| Draft cycle | Standard `_ENTWURF`/`_DRAFT` → validation |

**Example:** `01-Introduction_ENTWURF.docx` → `01-Introduction.docx`

### `Materialien/` / `Materials/`

Unit-scoped material numbering (M01, M02, …) per the naming convention.

| Convention | Detail |
|---|---|
| Naming pattern | `M{number}-{Type}-{Topic}.docx` |
| Numbering | Unit-scoped: M01, M02, … (resets per unit) |
| Draft cycle | Standard `_ENTWURF`/`_DRAFT` → validation |

**Example:** `M01-Worksheet-Metaphors_ENTWURF.docx` → `M01-Worksheet-Metaphors.docx`

> **Note on naming patterns:** The short patterns shown in folder tree examples above (e.g., `M01-Worksheet-Metaphors.docx`) are simplified illustrations. The actual filenames are produced by the configurable patterns in `naming-conventions.json`, which include the subject abbreviation, grade, and unit title prefix (e.g., `E10a - Globalisation - M01 - Worksheet-Metaphors.docx`). See `naming-conventions.md` for the full template variable reference and resolved examples.

### `Lernkontrollen/` / `Assessments/`

Progressive structure: flat for a single assessment, numbered subfolders when multiple assessments exist.

#### Single Assessment (flat)

```
Lernkontrollen/
├── Aufgabe.docx           (Task.docx)
├── Erwartungshorizont.docx (Rubric.docx)
└── Abgaben/               (Submissions/)
    └── (student submissions)
```

#### Multiple Assessments (numbered subfolders)

When a second assessment is created, the plugin restructures: existing flat files are moved into a numbered subfolder. **The teacher is warned before restructuring.**

```
Lernkontrollen/
├── 01-Vokabeltest/
│   ├── Aufgabe.docx           (Task.docx)
│   ├── Erwartungshorizont.docx (Rubric.docx)
│   └── Abgaben/               (Submissions/)
│       └── (student submissions)
└── 02-Klausur-Poetry-Analysis/
    ├── Aufgabe.docx           (Task.docx)
    ├── Erwartungshorizont.docx (Rubric.docx)
    └── Abgaben/               (Submissions/)
        └── (student submissions)
```

- Assessment subfolder naming: `{number}-{Title}/`
- Each assessment contains `Aufgabe.docx`/`Task.docx` + `Erwartungshorizont.docx`/`Rubric.docx`
- `plan.json` paths update on restructuring

### `Abgaben/` / `Submissions/`

Student submission folders, nested inside `Lernkontrollen/`/`Assessments/`.

- Created lazily (only when first submission is added)
- **Excluded** from backup and library snapshots by resolving the localized folder name from the source workspace's `conversation_language` via `localization.json` (`folder_names.submissions`), at any depth, with an any-language sweep — never a hardcoded name
- Student submissions never leave the local machine

## Draft Workflow

All generated documents follow this lifecycle. The draft suffix and filenames are fully localized in v1.0.

```
1. Generate → {Name}_ENTWURF.docx (de) / {Name}_DRAFT.docx (en)
2. Teacher reviews in Word, optionally adds comments
3. Teacher says "Überarbeite" / "Revise" → Claude reads comments, generates updated draft
4. Teacher says "Validiert" / "Validated" → Claude renames to {Name}.docx, updates plan.json
```

### Draft Suffix

| `conversation_language` | Suffix |
|---|---|
| `"de"` | `_ENTWURF` |
| `"en"` | `_DRAFT` |

### Exceptions (no draft cycle)

- `plan.json` — auto-maintained manifest
- `Materialübersicht.docx` / `MaterialOverview.docx` — auto-generated derivative

### Localized Filenames

| English key | German filename | English filename |
|---|---|---|
| `unit_plan` | `Einheitenplanung.docx` | `UnitPlan.docx` |
| `material_overview` | `Materialübersicht.docx` | `MaterialOverview.docx` |
| `reflection` | `Reflexion.docx` | `Reflection.docx` |
| `task` | `Aufgabe.docx` | `Task.docx` |
| `rubric` | `Erwartungshorizont.docx` | `Rubric.docx` |
| `year_overview` | `Schuljahresübersicht 2025-26.docx` | `YearOverview 2025-26.docx` |

All localized names resolved via `localization.json` based on `conversation_language` in teacher profile.

### Localized Folder Names

| English key | German folder | English folder |
|---|---|---|
| `lessons` | `Stunden/` | `Lessons/` |
| `materials` | `Materialien/` | `Materials/` |
| `assessments` | `Lernkontrollen/` | `Assessments/` |
| `submissions` | `Abgaben/` | `Submissions/` |

## Folder Creation

**Lazy:** Subfolders are created on first write, not pre-created at setup or unit creation.

- The unit folder itself is created when the first document is generated (typically the Einheitenplanung)
- `Stunden/`/`Lessons/` is created when the first lesson plan is generated
- `Materialien/`/`Materials/` is created when the first material is generated
- `Lernkontrollen/`/`Assessments/` is created when the first assessment is generated
- `Abgaben/`/`Submissions/` is created when the first submission is added

Subject and school year folders are created by `/thalura:setup` for selected subjects only.

## Consistency Checking

On unit open (any command targeting a unit), the plugin compares `plan.json` against actual folder contents.

### Check Rules

1. **Missing files:** File referenced in `plan.json` doesn't exist on disk → report to teacher
2. **Untracked files:** File in a managed subfolder not listed in `plan.json` → report to teacher
3. **Name mismatch:** File exists but with different name (e.g., manual rename) → report to teacher
4. **Status inconsistency:** `plan.json` says validated but file has `_ENTWURF`/`_DRAFT` suffix (or vice versa) → report to teacher

### Behavior

- Discrepancies are reported to the teacher with a summary
- **Corrections only after teacher confirmation** — the plugin never auto-fixes
- The check is lightweight: file existence + name matching, not content hashing
- After corrections, `plan.json` is updated to reflect the actual state

## Localization in v1.0

All user-facing names depend on `conversation_language` via `localization.json`:

- **Folder names:** `Stunden/` ↔ `Lessons/`, `Materialien/` ↔ `Materials/`, `Lernkontrollen/` ↔ `Assessments/`, `Abgaben/` ↔ `Submissions/`
- **Document filenames:** `Einheitenplanung.docx` ↔ `UnitPlan.docx`, `Reflexion.docx` ↔ `Reflection.docx`
- **Draft suffix:** `_ENTWURF` ↔ `_DRAFT`
- **Assessment filenames:** `Aufgabe.docx` ↔ `Task.docx`, `Erwartungshorizont.docx` ↔ `Rubric.docx`

**Language-independent:** `plan.json` — always English keys and values.

## Quick Reference

| I need... | Path |
|---|---|
| Unit manifest | `{Subject}/{school_year}/{class_id}/{Unit_slug}/plan.json` |
| Unit plan document | `{Subject}/{school_year}/{class_id}/{Unit_slug}/Einheitenplanung.docx` |
| Material overview | `{Subject}/{school_year}/{class_id}/{Unit_slug}/Materialübersicht.docx` |
| Lesson 3 | `{Subject}/{school_year}/{class_id}/{Unit_slug}/Stunden/03-{Topic}.docx` |
| Material M02 | `{Subject}/{school_year}/{class_id}/{Unit_slug}/Materialien/M02-{Type}-{Topic}.docx` |
| Assessment task | `{Subject}/{school_year}/{class_id}/{Unit_slug}/Lernkontrollen/Aufgabe.docx` |
| Assessment rubric | `{Subject}/{school_year}/{class_id}/{Unit_slug}/Lernkontrollen/Erwartungshorizont.docx` |
| Year overview | `Schuljahresübersicht {school_year}.docx` (workspace root) |

## Related Files

| File | Description |
|---|---|
| `storage-architecture.md` | Data-side storage (`data/` directory) |
| `schemas/unit-manifest.md` | `plan.json` schema (unit-level manifest) |
| `schemas/school-config.md` | School configuration (lesson slots) |
| `schemas/teacher-profile.md` | Teacher profile (includes `school_id` reference) |
| `schemas/school-year-plan.md` | School year plan (includes `output_path` to unit folders) |

## Key Design Decisions

- **Single-file architecture:** No combined compendium. Each command → one `.docx`.
- **Capitalized output paths:** `Englisch/2025-26/E10a/Globalisation/` — backend JSON stays lowercase.
- **Full v1.0 localization:** Folder names (including subject folders), filenames, draft suffix all localized.
- **`Lernkontrollen/` not `leistung/`:** Better assessment folder name.
- **Progressive assessment structure:** Flat → subfolders on second assessment.
- **Lazy folder creation:** Subfolders on first write, not pre-created. (Acceptance Criterion)
- **Consistency checking:** `plan.json` vs. filesystem on unit open.
- **Word comments as input:** Teachers comment in Word, Claude processes on revision.
- **`Abgaben/`/`Submissions/` exclusion:** Resolved from the source workspace's `conversation_language` via `localization.json` (`folder_names.submissions`), excluded at any depth with an any-language sweep — never a hardcoded name.
