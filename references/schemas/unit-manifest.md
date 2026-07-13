# Unit Manifest Schema (`plan.json`)

## File Path

```
<WORKSPACE_ROOT>/{Subject}/{school_year}/{class_id}/{Unit_slug}/plan.json
```

Plugin-managed manifest inside each unit folder. Tracks all documents, their status, versions, and cross-references. One file per unit.

**Example:** `English/2025-26/E10a/Globalisation/plan.json`

## Related Files

| File | Path | Description |
|---|---|---|
| Output architecture | `${CLAUDE_PLUGIN_ROOT}/references/output-architecture.md` | Folder structure, draft workflow, consistency checking |
| School year plan | `<WORKSPACE_ROOT>/data/school-years/{year}/plan.json` | Year-level plan with `output_path` linking to this unit |
| School config | `<WORKSPACE_ROOT>/data/profiles/school-config.json` | Lesson slot definitions referenced by `duration` field |
| Teacher profile | `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json` | `conversation_language` determines localized filenames |
| Localization | `${CLAUDE_PLUGIN_ROOT}/references/localization.json` | Resolves localized folder/file names |

## Annotated Example

```json
{
  "subject": "english",
  "class_id": "E10a",
  "unit_title": "Globalisation",
  "unit_slug": "Globalisation",
  "created_at": "2026-03-01T09:00:00Z",

  "unit_plan": {
    "path": "Einheitenplanung.docx",
    "version": 3,
    "status": "validated",
    "updated_at": "2026-03-15T14:00:00Z",
    "last_trigger": "lesson_validation",
    "gates": {
      "verified_at": "2026-03-15T14:00:05Z",
      "evidence": "verifier",
      "metadata": "pass",
      "template": "template_unit_plan",
      "file_links": "pass:5",
      "citation_links": "pass:2",
      "pdf": "n/a",
      "compliance": "ran:0",
      "read_back": { "creator": "Anna Weiser", "last_modified_by": "Anna Weiser", "title": "Globalisation", "application": "Thalura" }
    }
  },

  "material_overview": {
    "path": "Materialübersicht.docx",
    "updated_at": "2026-03-20T10:00:00Z",
    "gates": {
      "verified_at": "2026-03-20T10:00:04Z",
      "evidence": "verifier",
      "metadata": "pass",
      "template": "template_material_overview",
      "file_links": "pass:3",
      "citation_links": "n/a",
      "pdf": "n/a",
      "compliance": "n/a",
      "read_back": { "creator": "Anna Weiser", "application": "Thalura" }
    }
  },

  "reflection": null,

  "lessons": [
    {
      "number": 1,
      "title": "Introduction to Globalisation",
      "duration": "double",
      "path": "Stunden/E10a - Globalisation - Verlaufsplan 01_ENTWURF.docx",
      "status": "draft",
      "validated_at": null,
      "unit_plan_version": 3,
      "has_reflection": false,
      "gates": {
        "verified_at": "2026-03-14T11:00:00Z",
        "evidence": "verifier",
        "metadata": "fixed",
        "template": "template_lesson_plan",
        "file_links": "pass:2",
        "citation_links": "flagged:1",
        "pdf": "n/a",
        "compliance": "ran:0",
        "read_back": { "creator": "Anna Weiser", "application": "Thalura" }
      }
    },
    {
      "number": 2,
      "title": "Close Reading: Global Trade",
      "duration": "single",
      "path": "Stunden/02-Close-Reading.docx",
      "status": "validated",
      "validated_at": "2026-03-18T16:00:00Z",
      "unit_plan_version": 2,
      "has_reflection": true,
      "gates": {
        "verified_at": "2026-03-18T16:00:03Z",
        "evidence": "verifier",
        "metadata": "pass",
        "template": "template_lesson_plan",
        "file_links": "pass:1",
        "citation_links": "pass:1",
        "pdf": "n/a",
        "compliance": "n/a",
        "read_back": { "creator": "Anna Weiser", "application": "Thalura" }
      }
    },
    {
      "number": 3,
      "title": "Analysis: Cultural Impact",
      "duration": "double",
      "path": "Stunden/03-Analysis.docx",
      "status": "validated",
      "validated_at": "2026-03-20T10:00:00Z",
      "unit_plan_version": 3,
      "has_reflection": false,
      "gates": {
        "verified_at": "2026-03-20T10:00:02Z",
        "evidence": "equivalent",
        "metadata": "pass",
        "template": "template_lesson_plan",
        "file_links": "pass:1",
        "citation_links": "n/a",
        "pdf": "n/a",
        "compliance": "n/a",
        "read_back": { "creator": "Anna Weiser", "application": "Thalura" }
      }
    }
  ],

  "materials": [
    {
      "id": "M01",
      "path": "Materialien/E10a - Globalisation - M01 - Worksheet-Metaphors.docx",
      "pdf_path": "Materialien/E10a - Globalisation - M01 - Worksheet-Metaphors.pdf",
      "type": "worksheet",
      "status": "validated",
      "linked_to": [1, 2],
      "images": [
        {
          "id": "IMG-01",
          "description": "A colourful neighbourhood street scene with labelled buildings",
          "aspect_ratio": "3:4",
          "width": "full",
          "style": "Children's book illustration",
          "model": "recommended-model-label",
          "prompt": "Aspect ratio 3:4 (portrait). 4K resolution. A warm digital illustration in a children's book style showing a colourful neighbourhood street scene with labelled buildings...",
          "print_optimized": false,
          "status": "placeholder"
        }
      ],
      "gates": {
        "verified_at": "2026-03-19T09:30:00Z",
        "evidence": "verifier",
        "metadata": "pass",
        "template": "template_worksheet",
        "file_links": "n/a",
        "citation_links": "pass:1",
        "pdf": "pass",
        "compliance": "ran:0",
        "read_back": { "creator": "Anna Weiser", "application": "Thalura", "pdf_author": "Anna Weiser", "pdf_parse": "ok" }
      }
    },
    {
      "id": "M02",
      "path": "Materialien/E10a - Globalisation - M02 - Handout-Poetry-Terms_ENTWURF.docx",
      "type": "handout",
      "status": "draft",
      "linked_to": [3],
      "gates": {
        "verified_at": "2026-03-20T12:00:00Z",
        "evidence": "verifier",
        "metadata": "pass",
        "template": "template_worksheet",
        "file_links": "n/a",
        "citation_links": "n/a",
        "pdf": "n/a",
        "compliance": "n/a",
        "read_back": { "creator": "Anna Weiser", "application": "Thalura" }
      }
    },
    {
      "id": "student_task_deck-L3",
      "path": "Materialien/E10a - Globalisation - Verlaufsplan 03 - Aufgabenfolien_ENTWURF.pptx",
      "type": "student_task_deck",
      "status": "draft",
      "linked_to": [3],
      "gates": {
        "verified_at": "2026-03-20T12:05:00Z",
        "evidence": "verifier",
        "metadata": "pass",
        "template": "workspace-override",
        "file_links": "n/a",
        "citation_links": "n/a",
        "pdf": "n/a",
        "compliance": "n/a",
        "read_back": { "creator": "Anna Weiser", "application": "Thalura" }
      }
    }
  ],

  "assessments": [
    {
      "number": 1,
      "type": "exam_sek1",
      "title": "Klausur: Globalisation Essay",
      "path": "Lernkontrollen/",
      "task": {
        "status": "validated",
        "path": "Lernkontrollen/Aufgabe.docx",
        "gates": {
          "verified_at": "2026-03-21T08:00:00Z",
          "evidence": "verifier",
          "metadata": "pass",
          "template": "n/a",
          "file_links": "pass:1",
          "citation_links": "pass:3",
          "pdf": "n/a",
          "compliance": "ran:0",
          "read_back": { "creator": "Anna Weiser", "application": "Thalura" }
        }
      },
      "rubric": {
        "status": "draft",
        "path": "Lernkontrollen/Erwartungshorizont_ENTWURF.docx",
        "gates": {
          "verified_at": "2026-03-21T08:05:00Z",
          "evidence": "verifier",
          "metadata": "pass",
          "template": "n/a",
          "file_links": "pass:1",
          "citation_links": "pass:2",
          "pdf": "n/a",
          "compliance": "late-ran:0",
          "read_back": { "creator": "Anna Weiser", "application": "Thalura" }
        }
      },
      "linked_to": [1, 2, 3]
    }
  ]
}
```

**Notes on the example:**
- All JSON keys and values are English. File paths reference localized filenames (German in this case, based on `conversation_language`).
- M01's `images` array shows one placeholder image. The `prompt` is truncated in the example — the actual value contains the full 10-component English prompt from Eleven's Vision. `status: "placeholder"` means the teacher has not yet replaced the grey rectangle with the generated image.
- The `prompt` field is the single source of truth for the image prompt: any copy embedded in the material document (a Word comment or a slide note) is a derivative convenience copy, not the authoritative source.
- `unit_plan_version` per lesson enables consistency warnings: lesson 2 was planned against v2, but the unit plan is now at v3.
- `duration` references a slot ID from `school-config.json`. `"double"` resolves to 90min via the school config.
- Single assessment → flat paths inside `Lernkontrollen/`. With multiple assessments, paths would include numbered subfolders (e.g., `Lernkontrollen/01-Vokabeltest/Aufgabe.docx`).
- `reflection` is `null` — no unit reflection has been created yet. Once created, it would contain `{ "path": "Reflexion.docx", "status": "validated", "completed_at": "...", "gates": { … } }`.
- Every generated-or-revised document entry carries a `gates` object recording the output-gate evidence for that document (see the **`gates` Object** section). The example shows the range: `unit_plan`/`lesson 2` are clean passes; `lesson 1` was auto-repaired on one gate (`metadata: "fixed"`) and carries an unfixable, delivered-with-flag residual on another (`citation_links: "flagged:1"`); `lesson 3` was verified by an equivalent method (`evidence: "equivalent"`); `M01`'s validated PDF sibling was checked by the separate PDF-verify pass (`pdf: "pass"`, plus the `pdf_*` read-back keys); the `student_task_deck` matched a live workspace-override template (`template: "workspace-override"`); assessment files have no shipped template (`template: "n/a"`) and record the mandatory audit (`compliance: "ran:0"` / `"late-ran:0"`).

## Field Reference

### Root Level

| Field | Type | Required | Description |
|---|---|---|---|
| `subject` | `string` | yes | Subject ID: `"english"`, `"philosophy"`, `"psychology"`, `"religion"`. Matches `school-year-plan.json` entry. |
| `class_id` | `string` | yes | Class identifier (e.g., `"E10a"`, `"PS4"`). Matches class definition. |
| `unit_title` | `string` | yes | Human-readable unit title. Teacher-facing, in the teacher's language. |
| `unit_slug` | `string` | yes | Capitalized kebab-case folder name (e.g., `"Globalisation"`, `"Poetry-Unit"`). |
| `created_at` | `string` | yes | ISO-8601 timestamp of unit creation. |
| `unit_plan` | `object` | yes | Unit plan document tracking. |
| `material_overview` | `object \| null` | no | Material overview document tracking. `null` until first generation. |
| `reflection` | `object \| null` | no | Unit reflection tracking. `null` if not yet created. |
| `lessons` | `array` | yes | Lesson entries. Empty array until first lesson is planned. |
| `materials` | `array` | yes | Material entries. Empty array until first material is generated. |
| `assessments` | `array` | yes | Assessment entries. Empty array until first assessment is created. |
| `library_ref` | `object \| null` | no | Present only on a unit **assigned from the library**: `{ "unit_id": "<library entry id>", "assigned_at": "<ISO-8601>", "adaptation_complete": <boolean> }`. Absent or `null` on a unit planned from scratch. |

### `library_ref` Object

Written when a unit is assigned from the library (Bibliothek). It links the class-bound unit back to its source library entry and tracks whether the teacher has adapted the reused material to the new class.

| Field | Type | Required | Description |
|---|---|---|---|
| `unit_id` | `string` | yes | The source library entry's `unit_id`. **Validation:** must resolve to an existing entry in `<WORKSPACE_ROOT>/data/library/{subject}.json`. |
| `assigned_at` | `string` | yes | ISO-8601 timestamp of the assignment. |
| `adaptation_complete` | `boolean` | yes | `false` on assignment. While `false`, the unit-planning and lesson-detail flows remind (once per session) that the unit was assigned from the library and not yet adapted; flipped to `true` on the teacher's explicit confirmation. |

### `unit_plan` Object

| Field | Type | Description |
|---|---|---|
| `path` | `string` | Current filename (localized, e.g., `"Einheitenplanung.docx"` or `"Einheitenplanung_ENTWURF.docx"`). |
| `version` | `number` | Integer, incremented on each update. Starts at 1. |
| `status` | `string` | `"draft"` or `"validated"`. |
| `updated_at` | `string` | ISO-8601 timestamp of last update. |
| `last_trigger` | `string` | What caused the last update: `"plan_unit"`, `"lesson_validation"`, `"teacher_edit"`. |
| `gates` | `object` | Output-gate evidence record for this document. Required on every generated-or-revised entry. See the **`gates` Object** section. |

### `material_overview` Object

| Field | Type | Description |
|---|---|---|
| `path` | `string` | Current filename (localized, e.g., `"Materialübersicht.docx"`). |
| `updated_at` | `string` | ISO-8601 timestamp of last regeneration. |
| `gates` | `object` | Output-gate evidence record for this document. Required on every generated-or-revised entry. See the **`gates` Object** section. |

### `reflection` Object

| Field | Type | Description |
|---|---|---|
| `path` | `string` | Current filename (localized, e.g., `"Reflexion.docx"` or `"Reflexion_ENTWURF.docx"`). |
| `status` | `string` | `"draft"` or `"validated"`. |
| `completed_at` | `string \| null` | ISO-8601 timestamp of validation. `null` while in draft. |
| `gates` | `object` | Output-gate evidence record for this document. Required on every generated-or-revised entry. See the **`gates` Object** section. |

### Lesson Entry

| Field | Type | Required | Description |
|---|---|---|---|
| `number` | `number` | yes | Sequential lesson number (1, 2, 3, …). Matches Einheitenplanung. |
| `title` | `string` | yes | Lesson title. Teacher-facing. |
| `duration` | `string` | yes | Lesson slot ID from `school-config.json` (e.g., `"single"`, `"double"`, `"double_with_break"`). Actual minutes resolved from school config. |
| `path` | `string` | yes | Current filename relative to unit folder (e.g., `"Stunden/E10a - Globalisation - Verlaufsplan 01_ENTWURF.docx"`). Includes draft suffix when in draft status. |
| `status` | `string` | yes | `"draft"` or `"validated"`. |
| `validated_at` | `string \| null` | no | ISO-8601 timestamp of validation. `null` while in draft. |
| `unit_plan_version` | `number` | yes | Which unit plan version this lesson was planned against. Enables consistency warnings. |
| `has_reflection` | `boolean` | yes | Whether a reflection section has been appended to the lesson file. Default `false`. |
| `gates` | `object` | yes* | Output-gate evidence record for this document. Required on every generated-or-revised entry (`*` a pre-existing entry may lack it — a backfill trigger, not corruption; see the **`gates` Object** section). |

### Material Entry

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | `string` | yes | Material ID: `"M01"`, `"M02"`, … Unit-scoped numbering. **Exception:** the `student_task_deck` type is **not** numbered `M{seq}` — its id is `student_task_deck-L{n}` (lesson-keyed). See the note below. |
| `path` | `string` | yes | Current filename relative to unit folder (e.g., `"Materialien/E10a - Globalisation - M01 - Worksheet-Metaphors.docx"`). |
| `type` | `string` | yes | Material type: `"worksheet"`, `"handout"`, `"slides"`, `"reading_text"`, `"student_task_deck"`. |
| `status` | `string` | yes | `"draft"` or `"validated"`. |
| `linked_to` | `array` | yes | Lesson numbers this material is used in (e.g., `[1, 2]`). |
| `gates` | `object` | yes* | Output-gate evidence record for this document. Required on every generated-or-revised entry (`*` see the pre-existing-entry note under the **`gates` Object** section). When the entry has a `pdf_path`, the separate PDF-verify pass fills `gates.pdf` (and the `pdf_*` read-back keys) for that PDF sibling. |
| `images` | `array` | no | Image entries for placeholder images embedded in this material. Empty array or omitted if no images. |
| `pdf_path` | `string` | no | Relative path (from unit folder root) to the validated PDF sibling of this material's source file (e.g., `"Materialien/E10a - Globalisation - M01 - Worksheet-Metaphors.pdf"`). Present only when a validated PDF exists — that is, the material is validated, in scope per `pdf_on_validation` (read from `<WORKSPACE_ROOT>/data/config/behaviour.json` via the two-tier overlay), and `pdf_on_validation` is not `"off"`. **Absent** for draft materials and when no PDF exists. Set on validation; regenerated and overwritten on re-validation. Registered here so inventory-driven unit exports can include the PDF as a `contents[]` member. |

**`student_task_deck` — the per-lesson student task deck.** A projection-ready slide deck of the lesson's student tasks, generated by The Playbook after the lesson is validated. Its `id` is **not** an `M{seq}` — it is `student_task_deck-L{n}`, lesson-keyed (`L3` = lesson 3's deck), keeping it out of the material-number sequence so it never intermingles with teacher-curated materials. **Exactly one deck per lesson**, identified by its single `linked_to` lesson. The id uses the English key form (`plan.json` is all-English — see Design Notes); the localized `Aufgabenfolien` tag appears only in the filename `path`. The Material Entry shape is otherwise unchanged — this is a `type`-enum and id-rule addition, not a new manifest object.

### Image Entry

Each image entry tracks a placeholder image embedded in a material document.

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | `string` | yes | Image ID: `"IMG-01"`, `"IMG-02"`. Sequential within the material, zero-padded two digits. Pattern from `naming-conventions.json` → `identifiers.image_id`. |
| `description` | `string` | yes | What the image shows — used as alt-text (`wp:docPr[@descr]`). |
| `aspect_ratio` | `string` | yes | Aspect ratio (e.g., `"3:4"`, `"16:9"`). Must be supported by the selected model. |
| `width` | `string` | yes | `"full"` (content width) or `"half"` (half content width). |
| `style` | `string` | yes | Style Catalog entry from Eleven's Vision (e.g., `"Children's book illustration"`). |
| `model` | `string` | yes | On the tool-present path, the served model id from the generation tool's result metadata — authoritative for the AI-image citation footnote. On the manual (no-tool) path, the recommended model label selected during image proposal. |
| `prompt` | `string` | yes | Full English prompt with all 10 mandatory components. |
| `print_optimized` | `boolean` | yes | Whether print optimization was applied to the prompt. |
| `status` | `string` | yes | `"placeholder"` (grey rectangle with comments) or `"replaced"` (teacher has inserted final image). |
| `provider` | `string` | no | Provider identifier from the generation tool's result metadata, recorded when the image was produced by a connected image-generation tool. Absent on the manual (no-tool) path. |
| `watermark` | `string` or `array of string` | no | Watermark tag(s) returned by the generation tool — a tool may report more than one — recorded opaquely for labeling and for the embed step's survival check. Absent when not returned or on the manual (no-tool) path. |

**Compatibility note.** `provider` and `watermark` are both optional; absent means the image was produced on the manual (no-tool) path. Every existing manifest remains valid with no migration required. `status` semantics are unchanged (`"placeholder"` / `"replaced"`); the flip to `"replaced"` is the embed step's success signal, owned by the auto-embed issue.

### Assessment Entry

| Field | Type | Required | Description |
|---|---|---|---|
| `number` | `number` | yes | Sequential assessment number (1, 2, …). |
| `type` | `string` | yes | Assessment type in English: `"short_test"`, `"exam_sek1"`, `"exam_sek2_ga"`, `"exam_sek2_ea"`, `"abitur_exam"`, `"oral_abitur_exam"`, `"presentation"`, `"vocabulary_test"`, `"portfolio"`. Types with format files (`short_test` through `presentation`) resolve to `${CLAUDE_PLUGIN_ROOT}/references/exam-formats/{type with _ → -}.md`. Display names localized via `localization.json` → `assessment_types`. |
| `title` | `string` | yes | Assessment title. Teacher-facing. |
| `path` | `string` | yes | Path to assessment location relative to unit folder. Flat: `"Lernkontrollen/"`. Subfolder: `"Lernkontrollen/01-Vokabeltest/"`. |
| `task` | `object` | yes | `{ "status": "draft"\|"validated", "path": "Lernkontrollen/Aufgabe.docx" }`. The task paper (Aufgabe) is student-facing; on validation an optional `pdf_path` field may be added: `{ "status": "validated", "path": "Lernkontrollen/Aufgabe.docx", "pdf_path": "Lernkontrollen/Aufgabe.pdf" }`. `pdf_path` is absent for draft task entries and when no validated PDF exists. Each assessment file — `task` and `rubric` — carries its **own** `gates` object (assessments have no shipped template, so `gates.template` is `"n/a"`); see the **`gates` Object** section. |
| `rubric` | `object` | yes | `{ "status": "draft"\|"validated", "path": "Lernkontrollen/Erwartungshorizont.docx" }`. Carries its own `gates` object (see the `task` row and the **`gates` Object** section). |
| `linked_to` | `array` | yes | Lesson numbers this assessment covers (e.g., `[1, 2, 3]`). |

### `gates` Object

Every generated-or-revised document entry — `unit_plan`, `material_overview`, each `lessons[]` entry, each `materials[]` entry (including the PDF sibling named by its `pdf_path`), both assessment files (`task` and `rubric`), and `reflection` — carries a compact `gates` object. It records the **output-gate evidence** for that one document: the outcome of each applicable gate, when it was verified, how the evidence was produced, and a small set of concrete, falsifiable read-back values (actual metadata strings, link counts, the matched template id). Because the record stores read-back values and not just verdicts, any later session — or any review — can refute a fabricated record by simply opening the artifact.

All keys and values are English, per the manifest language rule. Fields:

| Field | Type | Description |
|---|---|---|
| `verified_at` | `string` | ISO-8601 (UTC) timestamp of the verification run that produced this record. |
| `evidence` | `string` | How the evidence was produced: `"verifier"` (the shipped output-gate verifier), `"equivalent"` (an equivalent evidence-producing method used when the verifier could not run on the artifact's side), or `"imported"` (a fresh copy-path stub — see **Copy-path semantics** below). |
| `metadata` | `string` | Document-property gate outcome. One of `"pass"`, `"fixed"`, `"flagged"`, `"n/a"`. |
| `template` | `string` | Template-fidelity gate — an **identity-or-status** field: a matched **template id** string (e.g. `"template_worksheet"`) *is* the pass marker; `"workspace-override"` = passed against a live-fingerprinted workspace-override template; `"absent-evidenced"` = no template, backed by recorded directory-listing evidence; `"n/a"` = no shipped template for this document kind (e.g. assessments); `"flagged"` = an unfixable fidelity residual delivered with a flag. |
| `file_links` | `string` | Internal-reference-link gate: `"<outcome>:<count>"` where `<outcome>` ∈ `pass \| fixed \| flagged` and `<count>` is the number of links found (e.g. `"pass:3"`); the bare string `"n/a"` when the gate does not apply. |
| `citation_links` | `string` | Citation-link gate, same `"<outcome>:<count>"` grammar as `file_links`; `"n/a"` when not applicable. |
| `pdf` | `string` | PDF-metadata gate outcome, filled by the separate PDF-verify pass when a validated PDF sibling exists. One of `"pass"`, `"fixed"`, `"flagged"`, `"n/a"`. |
| `compliance` | `string` | Compliance-check outcome: `"ran:<findings>"`, `"late-ran:<findings>"` (audit ran after the fact), `"skipped-config"` (disabled by configuration), or `"n/a"`; `<findings>` is an integer. |
| `read_back` | `object` | Flat object of the concrete values read back from the artifact. The entry keeps whichever keys are relevant to the document kind (see key set below). |

**Outcome namespace (record layer).** A recorded gate outcome is one of `pass \| fixed \| flagged \| n/a`:

- `pass` — the gate passed on read-back.
- `fixed` — the gate first failed, the artifact was repaired, and a **re-read** then passed (a `fixed` always requires a passing re-verification, never the fix's own claim).
- `flagged` — an unfixable policy-gate residual; the document is delivered together with a localized flag naming the deficiency.
- `n/a` — the gate does not apply to this document kind.

(There is no recorded raw "fail": a failing gate is always resolved to `fixed` or `flagged` before the record lands.)

**`read_back` key set (store the relevant subset):**

| Key | Meaning |
|---|---|
| `creator` | Document author property. |
| `last_modified_by` | Last-modified-by property. |
| `title` | Document title property. |
| `application` | Authoring-application property. |
| `company` | Organization/company property (may be legitimately empty). |
| `pdf_author` | PDF author property (PDF-verify pass). |
| `pdf_producer` | PDF producer property. |
| `pdf_creator` | PDF creator property. |
| `pdf_title` | PDF title property. |
| `pdf_parse` | PDF parse status: `"ok"`, `"not_applicable"`, or the reserved `"unparseable"` value. A PDF beyond the parser's bounds records `read_back.pdf_parse: "unparseable"` and forces `gates.pdf: "flagged"` — an honest, terminal, deliverable outcome (no re-verify loop), never a false pass or fail. |

**Pre-existing entries — backfill, not corruption.** An older document entry that predates this record and therefore has **no** `gates` object is **not** an error and **not** corruption. A missing `gates` block is a repair trigger for the touchpoint sweep: the next skill that reads the manifest and relies on that document verifies the existing artifact then, backfills the record, and notes the repair — no schema migration script is involved; the sweep itself performs the repair on next touch. Every manifest written before this record was introduced therefore remains valid.

**Copy-path semantics.** Two distinct behaviours govern how `gates` records travel when a unit is copied or imported:

- **Backup / restore** carries the `gates` record **verbatim** inside the copied `plan.json` — no fabrication, no re-run. The record is data like any other field and survives the round-trip unchanged.
- **Library assign and unit-exchange import** do not carry records verbatim (a fresh manifest is generated on landing). An entry landed by a **library assign or unit-exchange import** instead receives a **fresh stub** — `{ "evidence": "imported", "verified_at": "<assign time>" }` with no read-back values — which is re-verification-exempt; a later revision or teacher validation of that document writes a real record.

## Validation Rules

### Status Transitions

- `"draft"` → `"validated"`: On teacher validation (rename removes draft suffix)
- `"validated"` → `"draft"`: On retroactive changes when unit plan update affects a validated lesson. File is re-created with draft suffix.

### Version Rules

- `unit_plan.version` only increments, never decrements
- `unit_plan_version` per lesson records which version was current when the lesson was planned
- Consistency warning when `lesson.unit_plan_version < unit_plan.version`

### Path Rules

- File paths must match actual filesystem (verified by consistency check)
- Paths are relative to the unit folder root
- Paths include the localized subfolder name (e.g., `Stunden/` or `Lessons/`)
- Draft suffix in path must match `status` field
- **Recorded-ref locale invariant.** Tracked-document `path` values are recorded in the workspace's own `conversation_language` — the leading document-subfolder segment (e.g. `Stunden/` vs `Lessons/`) matches the on-disk folder. A cross-locale restore keeps this invariant: it rewrites the leading subfolder segment of every tracked-doc path on land, including the nested assessment `task.path` and `rubric.path`, while filenames are unchanged (the recorded filename always equals the landed filename). Recorded refs therefore always resolve literally in the workspace's own language; no locale mapping is needed at read time.

## Consistency Checking

On unit open, the plugin compares this manifest against actual folder contents.

### Checks Performed

1. **Missing files:** Every `path` in the manifest must exist on disk
2. **Untracked files:** `.docx` files in managed subfolders (`Stunden/`, `Materialien/`, `Lernkontrollen/`) not listed in the manifest are reported
3. **Status mismatch:** `status: "draft"` but filename has no draft suffix (or vice versa)
4. **Assessment restructuring:** Single-assessment paths but multiple assessments in manifest (or vice versa)

### Resolution

- All discrepancies are reported to the teacher
- Corrections applied only after teacher confirmation
- After correction, manifest is updated to reflect actual state

## Lifecycle

| Event | Trigger | Details |
|---|---|---|
| **Created** | Unit planning (the `unit-planning` skill) | Initialized with root fields, empty arrays, `unit_plan` in draft status. |
| **Updated** | Every document operation | Status changes, new entries, path updates, version increments. |
| **Read** | Every unit task | Loaded to determine current state. Consistency check on first read per session. |
| **Never manually edited** | — | Plugin-managed only. Teacher edits documents, not the manifest. |

## Design Notes

- All keys and values are English. No German in `plan.json`. Localized filenames appear only in `path` values (they reference actual files on disk).
- `Materialübersicht.docx`/`MaterialOverview.docx` and `plan.json` are exceptions to the `_ENTWURF`/`_DRAFT` cycle — they are auto-generated derivatives.
- `number` (not `nr`) for all sequential fields.
- `duration` references slot IDs from `school-config.json`, not raw minutes. This enables time validation and material scope hints.
- Assessment `path` changes when progressive restructuring occurs (flat → subfolders on second assessment).
