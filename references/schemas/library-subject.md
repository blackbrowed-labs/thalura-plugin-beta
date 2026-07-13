# Library Subject Schema

> This schema is the full definition of a library entry. It replaces the earlier skeleton: one reconciled shape serves three roles at once — it **is** the library entry stored per subject, it **is** the unit body carried inside a shared unit bundle, and it is the source a unit-assignment flow re-binds into a fresh class-bound unit manifest.

## File Path

```
<WORKSPACE_ROOT>/data/library/{subject_english}.json
```

One file per subject. Library materials (the frozen per-unit **snapshot**) live at `<WORKSPACE_ROOT>/data/library/materials/{unit_id}/`.

**Examples:** `english.json`, `philosophy.json`, `religion.json`

The library is **year-independent** — it sits outside the per-year tree because a unit shelved in one school year is available for assignment in any later year.

## Skeleton Example

```json
{
  "subject": "english",
  "units": []
}
```

A fresh subject file holds an empty `units[]` array; entries are appended as units are shelved or imported.

## Entry Field Table

Root of `{subject}.json`: `subject` (string, subject ID) + `units[]` (array of entries). Each entry:

| Field | Type | Required | Description |
|---|---|---|---|
| `unit_id` | `string` | yes | `lib_{slug}_{sequence}` (see **Identifier rules** below). Keys the snapshot folder, back-references, and dedup. Unique within the workspace (across all subject files and `materials/` folders). |
| `title` | `string` | yes | Unit display title. Teacher-facing, in the teacher's language. |
| `unit_slug` | `string` | yes | The shelve-time folder slug (capitalized kebab-case, e.g. `"Globalisation"`, `"Poetry-Unit"`). Stored so an assignment reuses the **same** slug the `unit_id` embeds instead of re-deriving one from the title (deterministic re-binding; de-duplicated against existing target folders on assign). |
| `subject` | `string` | yes | Subject ID (echoes the file's root `subject`; self-describing when the entry travels as a bundle body). |
| `grade_level` | `string` | yes | Single value (`"10"`, `"S2"`) **or band** (`"9/10"`, `"S1-S4"`) — see **Grade-level notation** below. |
| `sek_level` | `string` | yes | `"sek1"` or `"sek2"`. Derived from `grade_level`. |
| `course_level` | `string \| null` | yes | `"gA"`, `"eA"`, or `null`. Drives reuse-suitability warnings on assign. `null` where the education system defines no course level for the grade. |
| `competency_areas` | `array` | yes | Competency-area IDs (English backend keys) addressed by the unit, copied from the source school-year-plan entry at shelve time. Pre-seeds the target plan on assign. May be empty. |
| `planned_hours` | `number \| null` | yes | Planned teaching hours, copied from the source school-year-plan entry. `null` if unknown. |
| `source` | `string` | yes | `"self"` (shelved in this workspace) or `"external"` (imported from a bundle). |
| `creator` | `string` | yes | Display name of the authoring teacher (from the teacher profile at shelve time; carried verbatim on import). |
| `federal_state` | `string` | yes | Authoring workspace's federal-state ID (profile value). Provenance only. |
| `school_type` | `string` | yes | Authoring workspace's school-type ID (profile value). Provenance only. |
| `plugin_version` | `string` | yes | Plugin version that wrote the entry. |
| `format_version` | `number` | yes | Schema/envelope format version, `1`. |
| `shelved_at` | `string \| null` | yes | ISO-8601 timestamp of shelving. `null` on an imported entry. |
| `imported_at` | `string \| null` | yes | ISO-8601 timestamp of import. `null` on a shelved-here entry. |
| `source_class` | `string \| null` | yes | `{year}/{class_id}` the snapshot was taken from (e.g. `"2025-26/E10a"`). **Workspace-internal: stripped from a bundle body on export.** `null` on imported entries. |
| `archived` | `boolean` | yes | `true` hides the entry from assign listings without deleting anything. |
| `replaces` | `string \| null` | yes | `unit_id` of the entry this one replaced. `null` if none. |
| `replaced_by` | `string \| null` | yes | `unit_id` of the entry that replaced this one (set together with `archived: true`). `null` if current. |
| `version_note` | `string \| null` | no (absent ⇒ `null`) | Short, teacher-confirmed summary of what this version (Fassung) changed relative to its predecessor. Model-authored at shelve time. `null` on family roots, when the teacher declines a note, and on entries written before this field existed (an absent key reads as `null`). Class-neutral: never contains a class identifier. Travels verbatim in a unit bundle body. |
| `materials_path` | `string` | yes | Relative to `<WORKSPACE_ROOT>/data/library/`: `"materials/{unit_id}/"`. |
| `documents` | `object` | yes | Class-independent document inventory (see **The `documents` inventory** below) — the semantic metadata an assignment needs to regenerate a fresh unit manifest. |
| `draft_documents` | `object` | no (absent ⇒ none) | Parallel **draft (Entwurf)** document inventory (see **The `draft_documents` inventory** below). Optional; in v1 data present **only on imported (`source: "external"`) entries** — local shelving never writes it. Same shape family as `documents`, with class-neutral, draft-suffixed `filename`s that resolve under the snapshot's `drafts/` region. |

### Skeleton Example (one entry)

```json
{
  "subject": "english",
  "units": [
    {
      "unit_id": "lib_globalisation_001",
      "title": "Globalisation",
      "unit_slug": "Globalisation",
      "subject": "english",
      "grade_level": "10",
      "sek_level": "sek1",
      "course_level": null,
      "competency_areas": ["reading", "writing"],
      "planned_hours": 12,
      "source": "self",
      "creator": "A. Teacher",
      "federal_state": "hh",
      "school_type": "gym",
      "plugin_version": "0.2.1",
      "format_version": 1,
      "shelved_at": "2026-06-30T10:00:00Z",
      "imported_at": null,
      "source_class": "2025-26/E10a",
      "archived": false,
      "replaces": null,
      "replaced_by": null,
      "version_note": null,
      "materials_path": "materials/lib_globalisation_001/",
      "documents": { }
    }
  ]
}
```

## The `documents` inventory

The entry carries enough **semantic** (not lifecycle) document metadata that an assignment can regenerate a fresh unit manifest without re-asking the teacher. Shape:

```json
"documents": {
  "unit_plan": { "filename": "Globalisation - Einheitenplanung.docx" },
  "lessons": [
    { "number": 1, "title": "Introduction to Globalisation", "duration": "double",
      "filename": "Globalisation - Verlaufsplan 01.docx" }
  ],
  "materials": [
    { "id": "M01", "type": "worksheet", "linked_to": [1, 2],
      "filename": "Globalisation - M01 - Worksheet-Metaphors.docx" }
  ],
  "assessments": [
    { "number": 1, "type": "exam_sek1", "title": "Klausur: Globalisation Essay",
      "files": { "task": "Globalisation - Klausur - Aufgabe.docx",
                 "rubric": "Globalisation - Klausur - Erwartungshorizont.docx" },
      "linked_to": [1, 2, 3] }
  ]
}
```

Rules:

- **`filename`s are the class-neutral snapshot names.** Resolved document filenames open with the naming pattern's `{subject_abbr}{grade}` block — which **is** the `class_id` (`E10a - …`). Snapshot filenames have that class-identifying prefix **stripped**, so no filename in this inventory (or in the snapshot, or in a bundle payload built from it) carries the source class identity. The folder is implied by the array: `lessons[]` → `lessons/`, `materials[]` → `materials/`, `assessments[]` → `assessments/`, `unit_plan` → the snapshot root. Assessment subfolder structure (flat vs numbered) is preserved relative to the assessments key: a `files` value may carry a numbered-subfolder prefix (e.g. `"01-Vokabeltest/Globalisation - Klausur - Aufgabe.docx"`).
- **Lifecycle fields are deliberately absent** (`status`, `version`, `validated_at`, `unit_plan_version`, draft suffixes): everything in a snapshot is validated by construction, and the fresh manifest starts a new lifecycle (version 1, all validated). This rule governs the **validated channel** — the `documents` inventory and the canonical `lessons`/`materials`/`assessments` subtrees. Any draft (Entwurf) documents are carried separately, in the parallel `draft_documents` inventory and the `drafts/` region (below), never here.
- `duration` keeps the slot **ID** (`"single"`, `"double"`, …); the target workspace's school configuration resolves minutes. If the target config lacks the slot ID, the assignment flags it and asks the teacher to map it.
- Material image metadata is **not** carried — validated snapshot documents already embed their final images.

## The `draft_documents` inventory

An entry may **optionally** carry a parallel **draft (Entwurf)** inventory alongside `documents`, describing in-progress documents that travel through a separate draft channel. It has the **same shape family** as `documents` — `lessons[]`, `materials[]`, `assessments[]` with the same semantic fields (`number`/`title`/`duration` on a lesson; `id`/`type`/`linked_to` on a material; `number`/`type`/`title`/`files`/`linked_to` on an assessment). There is **no `unit_plan` key**: a unit plan is a validated document by construction and never appears as a draft. Shape:

```json
"draft_documents": {
  "lessons": [
    { "number": 4, "title": "Comparative Essay — Draft", "duration": "double",
      "filename": "Globalisation - Verlaufsplan 04_ENTWURF.docx" }
  ],
  "materials": [
    { "id": "M07", "type": "worksheet", "linked_to": [4],
      "filename": "Globalisation - M07 - Essay-Scaffold_ENTWURF.docx" }
  ],
  "assessments": []
}
```

Rules:

- **Optional, and in v1 data present only on imported (`source: "external"`) entries.** A `source: "self"` entry never carries `draft_documents`: local shelving never writes a draft, so a self-shelved entry has no `drafts/` region and no draft inventory (the live unit remains the home of the teacher's own drafts (Entwürfe)). An absent key reads as "no drafts".
- **`filename`s are derived, never copied verbatim.** The exporter derives each draft `filename` from the **staged, class-stripped member names of the snapshot's `drafts/` region** — never verbatim from a live unit manifest, whose draft filenames still open with the class-identifying `{subject_abbr}{grade}` block (the `class_id`). Because the region members are class-stripped before the inventory is built, every `draft_documents` `filename` is class-neutral **by construction** — the same invariant the `documents` inventory holds: no filename here contains the source `class_id`. Each `filename` also carries a **draft suffix** (some language's `system_labels.draft_suffix`, e.g. `_ENTWURF`).
- **Files resolve under the snapshot's `drafts/` region.** A `lessons[]` filename resolves to `materials/{unit_id}/drafts/lessons/…`, `materials[]` to `materials/{unit_id}/drafts/materials/…`, `assessments[]` to `materials/{unit_id}/drafts/assessments/…`. The `drafts/` prefix and its sub-keys are **canonical, never localized** — the same locale-neutral discipline as the three validated canonical keys; region membership is therefore a language-independent path-prefix test, with the localized draft suffix as the secondary within-region label check.
- **The region is draft-suffixed, immutable, and inert.** Region files land **visibly draft-suffixed**, are **immutable** exactly like every other snapshot material (no flow edits a file under `materials/{unit_id}/`, drafts included), and are **inert** — no flow treats a region file as a validated document. An assignment re-drafts them into the target class only on explicit opt-in (re-applying the target class prefix and re-localizing the suffix); nothing else reads the region.

## Grade-level notation

- **Single values** exactly as in the class definition: `"5"`–`"10"` and `"S1"`–`"S4"`. Numeric grades `"11"`–`"13"` are admitted by the shape gate as a deliberate extension — some school types carry numeric upper grades; which numeric values are *semantically* valid in a given workspace is decided by that workspace's education-system configuration, not by this schema.
- **Bands** are allowed in a library entry only (a reusable unit may span a band; class definitions stay single-value):
  - Slash form — **adjacent numeric pair only**: `"9/10"` (the curriculum-band convention); `n/m` requires `m = n + 1`.
  - ASCII-hyphen form — contiguous ascending range: `"5-6"`, `"S1-S2"`, `"S1-S4"` (never an en-dash — plain-ASCII data, robust to typing and matching).
  - **No cross-level bands:** both ends must be the same kind — both numeric or both `S`-codes. `"9-S2"` (any numeric/`S` mix) is invalid: `sek_level` would be underivable.
- **Shape gate (normative):** `^([5-9]|1[0-3]|S[1-4])([/-]([5-9]|1[0-3]|S[1-4]))?$` — rejects `"S0"`, `"S5"`, `"99"`, sub-5 grades, and malformed separators by construction. Semantic rules on top of the shape: `/` only for an adjacent numeric pair; `-` ranges ascending and same-kind at both ends; `sek_level` derives from the (band's) level.

## Identifier rules

`unit_id` follows the pattern registered in `naming-conventions.json` under `identifiers.unit_id`:

```
lib_{slug}_{sequence}
```

`{slug}` = the unit's `unit_slug` lowercased (kebab-case, `[a-z0-9-]+` — `"Poetry-Unit"` → `"poetry-unit"`); `{sequence}` = a zero-padded three-digit counter per slug within the workspace, starting `001`.

- **Shape (normative pattern):** a valid `unit_id` matches `^lib_[a-z0-9-]+_[0-9]{3}$`.
- **Uniqueness scope:** `unit_id` is unique **per workspace** — checked against **both** every existing entry in every `<WORKSPACE_ROOT>/data/library/*.json` **and** every existing `<WORKSPACE_ROOT>/data/library/materials/{unit_id}/` folder (the index and the filesystem can drift).
- **Cross-workspace collision:** two workspaces can independently mint `lib_globalisation_001`. On import, a colliding id from a *different* workspace is **re-sequenced locally** (mint the next free sequence, keep all provenance fields verbatim); identity dedup applies only when restoring a workspace's *own* ids, where a colliding id is the same frozen unit by construction.

The generation and verification contract (shape + uniqueness + freshness gates, verify-then-escalate-or-flag) is defined by the flow that mints the id; this schema fixes the pattern and the uniqueness scope.

## Read-only reconciliation

The **snapshot materials are immutable** — no flow ever edits a file under `materials/{unit_id}/`. The **entry's archival metadata is not**: `archived`, `replaces`, and `replaced_by` change when a newer snapshot replaces an older one, or when an archived entry is restored. This is the resolution of "the library is read-only" (materials) versus lifecycle bookkeeping (archival metadata).

## Class-neutral snapshot filenames

Every snapshot filename is stored **class-neutral**. Because a resolved document filename opens with the `{subject_abbr}{grade}` block — which is the source `class_id` — shelving **strips** that class-identifying prefix from every copied file; the verify invariant is that **no filename anywhere in the snapshot (or in the `documents` inventory) contains the source `class_id`**. An assignment re-applies the target class's prefix for the destination class, so an assigned copy carries the new class's identity, never the source's and never none.

## Version families (Fassungen)

A **version family** groups the entries that are revisions of one another — presented to the teacher as ONE unit with several versions (Fassungen). The family is **derived, never stored**:

- **Membership:** the connected component of entries under `replaces`/`replaced_by` links within one subject file, following the links in **both directions and from both fields** — a revision's `replaces` pointer alone keeps it in the family, even when its parent's single `replaced_by` names a different revision. An entry with no links is a 1-version family. There is no stored family identifier: nothing to migrate, nothing to normalize on export.
- **Timeline:** members are ordered by their acquisition timestamp — `shelved_at`, falling back to `imported_at` where `shelved_at` is `null` — never by link-walking (the chain may branch or dangle; the timestamp ordering is total regardless).
- **Default offered version(s):** the family's non-archived member(s) — `archived` is reused unchanged as the "which version is offered" selector; normally exactly one (the newest). Family display identity (title, grade, creator, …) comes from the newest non-archived member.
- **Branching is tolerated as a set:** two revisions may share one parent (both `replaces` naming it). A successor link (`replaced_by`), once set, is never overwritten; membership and ordering do not depend on it.
- **`version_note` is class-neutral** by the same invariant class as snapshot filenames: the note must never contain a class identifier; class context is displayed from `source_class` (workspace-internal) at presentation time.

## Design Notes

- The library is year-independent — a unit shelved in one school year is available for assignment in any later year.
- `archived: true` hides an entry from assign listings without deleting any data.
- `materials_path` is relative to `<WORKSPACE_ROOT>/data/library/`, not to `<WORKSPACE_ROOT>/`.
- Snapshot subfolders use **canonical (locale-neutral) keys** — `lessons/`, `materials/`, `assessments/` — never localized folder names; a workspace's localized names are mapped on shelve (localized → canonical) and on assign (canonical → target locale).
