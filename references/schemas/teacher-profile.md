# Teacher Profile Schema

## File Path

```
<WORKSPACE_ROOT>/data/profiles/teacher-profile.json
```

Central teacher identity and configuration entity. Stores name, school reference, subject selection, and per-subject language configuration. One file per Thalura installation.

## Related Files

| File | Path | Description |
|---|---|---|
| School config | `<WORKSPACE_ROOT>/data/profiles/school-config.json` | School identity and lesson slots, referenced via `school_id` |
| Teacher preferences | `<WORKSPACE_ROOT>/data/profiles/teacher-preferences.json` | Layer 2: validated teaching preferences |
| Teacher observations | `<WORKSPACE_ROOT>/data/profiles/teacher-observations.json` | Layer 1: tracked patterns, not yet validated |
| Education system | `${CLAUDE_PLUGIN_ROOT}/references/education-system.json` | Validates `federal_state` and `school_type` (via school config) |
| Localization | `${CLAUDE_PLUGIN_ROOT}/references/localization.json` | German display labels for all English keys |
| Subjects | `${CLAUDE_PLUGIN_ROOT}/references/subjects.json` | Valid subject IDs and metadata |

## Annotated Example

```json
{
  "name": "Lars Weiser",
  "teacher_abbreviation": "WEI",
  "email": "lars.weiser@example.de",
  "school_id": "hamburg-gymnasium-musterstadt-a3f7",
  "conversation_language": "de",
  "content_language_default": "de",
  "gendering": {
    "student_docs": "neutral",
    "teacher_docs": "abbreviation"
  },
  "subjects": [
    {
      "id": "english",
      "target_language": "en",
      "content_language": {
        "worksheets": "en",
        "handouts": "en",
        "slides": "en",
        "assessments": "en",
        "unit_plan_tasks": "en",
        "assessment_rubric": "de"
      }
    },
    {
      "id": "philosophy",
      "target_language": null
    },
    {
      "id": "religion",
      "target_language": null
    }
  ],
  "created_at": "2026-02-20T10:00:00Z"
}
```

**Notes on the example:**
- `school_id` references `school-config.json`. School name, federal state, and school type are all stored there, not here.
- Subject IDs use English throughout. German display labels are resolved via `localization.json` at runtime.
- `content_language_default` is `"de"` — this teacher's materials default to German. This is separate from `conversation_language` (which controls how Claude talks to the teacher). A teacher at an international school might set `conversation_language = "en"` and `content_language_default = "en"`.
- `content_language` is only present for English, where some output types use the target language. For Philosophy and Religion, all output defaults to German — the object is omitted entirely.
- `assessment_rubric` stays `"de"` even for English — the Erwartungshorizont is always in German per Hamburg BSB convention.
- `gendering` holds the gender-inclusive language (geschlechtergerechte Sprache) preference for generated German documents, split into two registers: `student_docs` (student-facing material) and `teacher_docs` (teacher-facing planning). It is seeded with the safe defaults at setup and changed only via `/thalura:config profile`. It acts only when the resolved content language is German; for English output it is a no-op.

## Field Reference

### Root Level

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | Teacher's full name. |
| `teacher_abbreviation` | `string` | yes | Official abbreviation (Kürzel), e.g., `"WEI"`. Used in document headers via `{teacher_abbreviation}` template variable. |
| `email` | `string \| null` | no | Contact email. `null` if not provided. |
| `school_id` | `string` | yes | References `school-config.json`. Human-readable composite: `{federal_state}-{school_type}-{slug}-{short_uid}`. School name, federal state, and school type are stored in `school-config.json`. |
| `conversation_language` | `string` | yes | Language Claude uses when communicating with the teacher. Default `"de"`. Allowed values: `"de"`, `"en"` (v1.0 scope). |
| `content_language_default` | `string` | yes | Default language for student-facing materials. Set during onboarding. Used as fallback when no subject-specific language applies (see core skill satellite `${CLAUDE_PLUGIN_ROOT}/skills/core/content-language-gendering.md`, *Content Language Resolution*). Default `"de"`. Allowed values: valid ISO 639-1 codes (`"de"`, `"en"`). |
| `gendering` | `object` | no | Gender-inclusive language (geschlechtergerechte Sprache) preference for generated German documents. Two registers — `student_docs`, `teacher_docs`. Seeded with defaults at setup; changed only via `/thalura:config profile`. Absent ⇒ defaults. |
| `subjects` | `array` | yes | List of subjects the teacher teaches. Minimum 1 entry. |
| `created_at` | `string` | yes | ISO-8601 timestamp of profile creation. |

### Subject Entry

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | `string` | yes | English subject ID: `"english"`, `"philosophy"`, `"psychology"`, `"religion"`. Must match a key in `${CLAUDE_PLUGIN_ROOT}/references/subjects.json`. |
| `target_language` | `string \| null` | yes | Target language code for language subjects (e.g., `"en"` for English). `null` for non-language subjects. Auto-set based on subject type. |
| `content_language` | `object` | no | Per-output-type language overrides. When absent, all output defaults to German. Only needed for subjects where some output should be in a non-German language. |

### content_language Object

All fields within `content_language` are optional. When a field is omitted, it defaults to `"de"`.

| Field | Type | Default | Description |
|---|---|---|---|
| `worksheets` | `string` | `"de"` | Language for worksheets (Arbeitsblätter). |
| `handouts` | `string` | `"de"` | Language for handouts. |
| `slides` | `string` | `"de"` | Language for presentation slides. |
| `assessments` | `string` | `"de"` | Language for student-facing assessment documents. |
| `unit_plan_tasks` | `string` | target language | Language for task instructions in Verlaufsplan. Defaults to the subject's target language (e.g., `"en"` for English). |
| `assessment_rubric` | `string` | `"de"` | Language for Erwartungshorizont. Typically `"de"` even for language subjects. |

**Default derivation:** When `target_language` is set, `/thalura:setup` auto-populates `worksheets`, `handouts`, `slides`, `assessments`, and `unit_plan_tasks` with the target language value. Only `assessment_rubric` defaults to `"de"` (Hamburg BSB convention). The teacher can customize these post-setup via `/thalura:config profile`.

### gendering Object

Controls the gender-inclusive language (geschlechtergerechte Sprache) style of generated **German** documents. Two independent registers; both sub-keys optional. The object acts only when the resolved content language is German — for English output it is a no-op.

| Field | Type | Default | Description |
|---|---|---|---|
| `student_docs` | `string` | `"neutral"` | Style for student-facing documents (Worksheets — Arbeitsblätter; Handouts; student-facing assessment paper — Aufgabe). |
| `teacher_docs` | `string` | `"abbreviation"` | Style for teacher-facing planning documents (Unit Plan — Einheitenplanung; Detailed Lesson Plan — Verlaufsplan; Grading Rubric — Erwartungshorizont; Reflection — Reflexion). |

**`student_docs` values:**

| `value` | Worked example | Official status (amtliches Regelwerk) | Accessibility |
|---|---|---|---|
| `neutral` *(default)* | "die Lernenden", "die Lehrkräfte" | Within the amtliches Regelwerk | Most accessible — no special characters |
| `paired` | "Schülerinnen und Schüler", "Lehrerinnen und Lehrer" | Within the amtliches Regelwerk (paired form — Beidnennung) | Fully accessible |
| `colon` | "Schüler:innen", "Lehrer:innen" | Outside the amtliches Regelwerk | Weaker — longer screen-reader pause |
| `star` | "Schüler\*innen", "Lehrer\*innen" | Outside the amtliches Regelwerk | Best of the special characters — `*` preferred over `:` |

No legacy short forms (`binnen_i`, `gap`, `schraegstrich`) are shipped — only these four values.

**`teacher_docs` values:**

| `value` | Worked example | Notes |
|---|---|---|
| `abbreviation` *(default)* | SuS / LuL / KuK | Standard professional shorthand for internal planning documents. |
| `full` | "Schülerinnen und Schüler", "Lehrerinnen und Lehrer" | Fully written out. |

**Per-term `neutral` fallback:** under `student_docs: neutral`, a term that has no clean neutral plural falls back to the paired form (Beidnennung — `paired`) **for that one term only**; every other term stays neutral. The fallback is per-term, never whole-document.

## Validation Rules

- `school_id` must reference an existing `school-config.json`
- `subjects[].id` must match a key in `${CLAUDE_PLUGIN_ROOT}/references/subjects.json`
- `conversation_language` must be `"de"` or `"en"` (v1.0 scope)
- `content_language_default` must be a valid ISO 639-1 code (`"de"`, `"en"`)
- `target_language` is auto-set for language subjects, `null` for non-language subjects
- All `content_language` values must be valid ISO 639-1 codes (`"de"`, `"en"`)
- `gendering` is an optional object; when absent, the defaults apply (no migration — existing profiles keep working)
- `gendering.student_docs` ∈ `{neutral, paired, colon, star}`; any other value (including the discouraged short forms `binnen_i` / `gap` / `schraegstrich`) is rejected; missing ⇒ `neutral`
- `gendering.teacher_docs` ∈ `{abbreviation, full}`; any other value is rejected; missing ⇒ `abbreviation`
- The two `gendering` sub-keys are independent — a teacher may set `abbreviation` for teacher docs and `star` for student docs
- No `school_year` field — the active school year is derived from the current date and school year boundaries in `education-system.json`

## Lifecycle

| Event | Trigger | Details |
|---|---|---|
| **Created** | `/thalura:setup` | Built via structured interview. Fields collected across setup steps 4–5. |
| **Read** | Every session startup | Loaded as part of the startup sequence (Step 4, after config loading). Injects teacher name and abbreviation into all document generation. |
| **Edited** | `/thalura:config profile` | Teacher can update name, email, subjects, and language settings. School data edited via `/thalura:config school`. |
| **Never overwritten** | Plugin updates | This is a project-only file — not part of the two-tier config system. Plugin updates never touch it. |

### Field Sources (Setup)

| Field | Source | Set during |
|---|---|---|
| `name` | Teacher input | Setup Step 5 |
| `teacher_abbreviation` | Teacher input | Setup Step 5 |
| `email` | Teacher input (optional) | Setup Step 5 |
| `school_id` | Auto-generated, references `school-config.json` | Setup Step 4 (created alongside school config) |
| `conversation_language` | Teacher choice, default `"de"` | Setup Step 5 |
| `content_language_default` | Teacher choice, default `"de"` | Setup Step 5 |
| `subjects` | Selection from available overlays | Setup Step 5 |
| `target_language` | Auto-set for language subjects, `null` otherwise | Setup Step 5 |
| `content_language` | Defaults from `target_language`, customizable post-setup | Post-setup via `/thalura:config profile` |
| `gendering` | Default-seeded (no onboarding question); edited via `/thalura:config profile` | Setup Phase 6 |
| `created_at` | Auto-generated | Setup completion |

## Consumed By

| Consumer | Fields used | Purpose |
|---|---|---|
| All generation commands | `name`, `teacher_abbreviation` | Document headers and footers |
| *Content Language Resolution* (core skill satellite `${CLAUDE_PLUGIN_ROOT}/skills/core/content-language-gendering.md`) | `content_language_default`, `target_language`, `content_language` | Canonical 4-step fallback chain for output language |
| Conversation language | `conversation_language` | Claude's communication language |
| Localization | `conversation_language` | Resolves German display labels for English keys |
| Subject overlays | `subjects` | Determines which overlays and regulations are loaded |
| Education system | `school_id` | Resolves to `federal_state`/`school_type` via school config for grade boundaries, regulation paths, school year calendar |
| Naming patterns | `teacher_abbreviation` | `{teacher_abbreviation}` template variable |
| Kompendium | `name`, `teacher_abbreviation` | Header injection |
| School config | `school_id` | Links to `school-config.json` for school name and lesson slots |

## Design Notes

- Not part of the two-tier config system. The profile is a project-only file that stores identity, not behavior. `teacher-preferences.json` and `teacher-observations.json` are separate files that track teaching style.
- **All school attributes moved to `school-config.json`**: `school_name`, `federal_state`, and `school_type`. The teacher profile holds only a `school_id` reference.
- No `label_de` in subject entries — German display labels are resolved via `localization.json` at runtime.
- **`content_language_default` vs `conversation_language`**: These are separate concerns. `conversation_language` controls how Claude communicates with the teacher. `content_language_default` controls the default language for student-facing materials. A teacher at a German Gymnasium typically sets both to `"de"`. A teacher at an international school might set `conversation_language = "en"` but `content_language_default` to match the school's instruction language.
- `content_language` defaults are derived from `target_language` during setup: when set, `worksheets`, `handouts`, `slides`, `assessments`, and `unit_plan_tasks` inherit the target language; only `assessment_rubric` stays `"de"` (Hamburg BSB convention).
- **`gendering` lives in the profile, not in preferences.** It is a deliberate, explicit identity/language-shape choice the teacher sets — the same class of setting as `content_language_default` / `conversation_language` — not a soft, model-overridable preference. Placing it here means it is **not** silently overridden per task (mixing forms within one document is the failure mode). It is seeded with defaults at setup (Phase 6 write — never asked during onboarding) and changed only via `/thalura:config profile`. It acts only when the resolved content language is German (English ⇒ no-op) and never touches `conversation_language`.
- No `school_year` field. The active school year is a temporal value derived from the current date and school year boundaries in `education-system.json`. On the first command of a new school year, Claude confirms with the teacher and scaffolds a new school year plan file.

## Migration Notes

The old skill has no `teacher-profile.json` — the profile is created fresh during `/thalura:setup`. However, the old `config/output-language.json` maps to the new per-subject `content_language`:

| Old field | New field | Notes |
|---|---|---|
| `interaction_language` | `conversation_language` | Renamed |
| `output_languages.{Subject}.worksheet` | `content_language.worksheets` | Pluralized |
| `output_languages.{Subject}.handout` | `content_language.handouts` | Pluralized |
| `output_languages.{Subject}.slides` | `content_language.slides` | Same |
| `output_languages.{Subject}.student_exam_version` | `content_language.assessments` | Broadened |
| `output_languages.{Subject}.grading_rubric` | `content_language.assessment_rubric` | Renamed |
| `output_languages.{Subject}.lesson_plan` | `content_language.unit_plan_tasks` | Narrowed to task instructions only |
| `output_languages.{Subject}.didactic_commentary` | — | Dropped: always German |
| `output_languages.{Subject}.reading_text` | — | Dropped: follows `target_language` |
| `output_languages.{Subject}.image_text` | — | Dropped: follows `slides` language |

Old subject keys use German names (`"Englisch"`, `"Philosophie"`); new schema uses English IDs (`"english"`, `"philosophy"`).

| `generate_student_slides` | → moved to `config/behaviour.json` | see `${CLAUDE_PLUGIN_ROOT}/references/schemas/behaviour.md`; the slide-accessibility settings (`slide_preferences`) remain in `teacher-preferences.json` |
