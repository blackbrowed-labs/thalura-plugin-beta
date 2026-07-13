# Teacher Preferences Schema (Layer 2)

## File Path

```
<WORKSPACE_ROOT>/data/profiles/teacher-preferences.json
```

Layer 2 of the two-layer preference system. Contains only preferences the teacher has **explicitly confirmed** — either promoted from observations (Layer 1) after reaching the threshold, or stated directly by the teacher.

This is a project-only file (not part of the two-tier config system). It is never shipped with the plugin, never overwritten by updates, and has no plugin-side default.

## Related Files

| File | Path | Description |
|---|---|---|
| Teacher observations | `<WORKSPACE_ROOT>/data/profiles/teacher-observations.json` | Layer 1: tracked patterns, not yet validated. Feeds into this file via promotion. |
| Teacher profile | `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json` | Teacher identity and language config |
| Class definitions | `<WORKSPACE_ROOT>/data/school-years/{year}/classes/*.json` | Class-specific feedback goes here, NOT in preferences |
| Core skill | `skills/core/SKILL.md` | Defines the two-layer system (*Two-Layer Teacher Preference System*) and compliance gate (core skill satellite `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md`, Step 4) |

## Annotated Example

```json
{
  "version": "1.0",
  "last_updated": "2026-10-15T14:30:00Z",
  "method_preferences": {
    "liked": ["think_pair_share", "placemat", "fishbowl"],
    "rejected": ["kugellager"],
    "notes": {
      "kugellager": "Zu laut und chaotisch bei grossen Klassen",
      "think_pair_share": "Funktioniert besonders gut als Einstieg"
    }
  },
  "social_form_tendencies": {
    "einstieg": "partner_work",
    "erarbeitung": "group_work",
    "sicherung": "plenary"
  },
  "lesson_structure_style": {
    "preferred_phase_count": 4,
    "prefers_warm_up": true,
    "prefers_buffer_activity": false,
    "time_buffer_minutes": 5
  },
  "material_preferences": {
    "copier_safe": true,
    "max_pages": 2,
    "prefers_visual_heavy": true,
    "font_size_minimum": 11
  },
  "language_level_calibration": {
    "english": {
      "worksheet_complexity": "B1+",
      "notes": "Avoid subjunctive in Sek I worksheets"
    }
  },
  "assessment_style": {
    "prefers_point_based": true,
    "default_notenschluessel": "apo_standard",
    "notes": "Immer Erwartungshorizont mit Alternativantworten"
  },
  "formatting_preferences": {
    "header_includes_date": true,
    "header_includes_class_id": true,
    "line_spacing": 1.15
  },
  "operator_usage": {
    "prefers_propedeutic_sek1": true,
    "notes": "Ab Klasse 8 propädeutisch einfuehren"
  },
  "slide_preferences": {
    "accessibility_mode": true,
    "font": null,
    "body_font_size": null,
    "title_font_size": null,
    "line_spacing": null,
    "max_bullets_per_slide": null
  },
  "image_preferences": {
    "ai_citation_footnote": true
  }
}
```

## Field Reference

### Root Level

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `version` | `string` | yes | `"1.0"` | Schema version. |
| `last_updated` | `string \| null` | yes | `null` | ISO-8601 timestamp of last modification. `null` when freshly created. |

### method_preferences

Validated method likes and dislikes. Methods are identified by their English slug from the core method files (e.g., `think_pair_share`, `kugellager`, `fishbowl`).

| Field | Type | Default | Description |
|---|---|---|---|
| `liked` | `string[]` | `[]` | Method slugs the teacher has confirmed as preferred. These are prioritized in Yoda's Wisdom suggestions. |
| `rejected` | `string[]` | `[]` | Method slugs the teacher has confirmed as disliked. These are deprioritized but NOT hidden — the Preference Override rule (core skill *Preference Override — CRITICAL RULE*) still allows suggesting them when didactically necessary. |
| `notes` | `object` | `{}` | Free-text notes keyed by method slug. Captures WHY the teacher likes or rejects a method. Informs override justifications. |

### social_form_tendencies

Preferred social forms per lesson phase. Values are social form identifiers: `individual_work`, `partner_work`, `group_work`, `plenary`.

| Field | Type | Default | Description |
|---|---|---|---|
| `{phase}` | `string \| null` | — | Preferred social form for a given phase. Phase keys: `einstieg`, `erarbeitung`, `sicherung`, `vertiefung`. |

All fields are optional. Missing phases have no preference — Claude chooses based on didactic fit.

### lesson_structure_style

| Field | Type | Default | Description |
|---|---|---|---|
| `preferred_phase_count` | `number \| null` | `null` | How many phases the teacher typically prefers (3–5). `null` = no preference. |
| `prefers_warm_up` | `boolean \| null` | `null` | Whether the teacher likes starting with a warm-up/energizer. |
| `prefers_buffer_activity` | `boolean \| null` | `null` | Whether the teacher likes having a buffer activity for fast finishers. |
| `time_buffer_minutes` | `number \| null` | `null` | Minutes reserved per lesson segment as transition/settling time. Applied per segment: a continuous double period loses one buffer; a double-with-break loses one buffer per teaching segment. `null` or `0` = no buffer. |

### material_preferences

| Field | Type | Default | Description |
|---|---|---|---|
| `copier_safe` | `boolean \| null` | `null` | Prefer copier-safe design (high contrast, no color gradients). |
| `max_pages` | `number \| null` | `null` | Preferred maximum page count for worksheets. |
| `prefers_visual_heavy` | `boolean \| null` | `null` | Prefers image-rich materials over text-heavy ones. |
| `font_size_minimum` | `number \| null` | `null` | Minimum font size for student-facing materials. |

### language_level_calibration

Per-subject language complexity preferences. Only relevant for language subjects.

| Field | Type | Default | Description |
|---|---|---|---|
| `{subject_id}` | `object` | — | Keyed by subject ID (e.g., `"english"`). |
| `{subject_id}.worksheet_complexity` | `string \| null` | `null` | CEFR level for worksheet language (e.g., `"B1+"`, `"A2"`). |
| `{subject_id}.notes` | `string \| null` | `null` | Free-text calibration notes. |

### assessment_style

| Field | Type | Default | Description |
|---|---|---|---|
| `prefers_point_based` | `boolean \| null` | `null` | Prefers point-based over percentage-based grading. |
| `default_notenschluessel` | `string \| null` | `null` | Default grading scale: `"apo_standard"`, `"sic"`, or `null` (always ask). |
| `notes` | `string \| null` | `null` | Free-text notes on assessment preferences. |

### formatting_preferences

| Field | Type | Default | Description |
|---|---|---|---|
| `header_includes_date` | `boolean \| null` | `null` | Include date in document headers. |
| `header_includes_class_id` | `boolean \| null` | `null` | Include class ID in document headers. |
| `line_spacing` | `number \| null` | `null` | Preferred line spacing for documents (e.g., `1.0`, `1.15`, `1.5`). |

### operator_usage

| Field | Type | Default | Description |
|---|---|---|---|
| `prefers_propedeutic_sek1` | `boolean \| null` | `null` | Prefers introducing Sek II operators propedeutically in upper Sek I. |
| `notes` | `string \| null` | `null` | Free-text notes on operator usage preferences. |

### slide_preferences

Slide presentation defaults. When `accessibility_mode` is `true`, the accessibility defaults apply unless explicitly overridden by individual fields.

| Field | Type | Default | Description |
|---|---|---|---|
| `accessibility_mode` | `boolean` | `true` | Bundles readability best practices for slides: dyslexia-friendly font (Verdana), ≥ 20pt body text, ≥ 1.3x line spacing, bold-only emphasis, max 6 bullets per slide. Individual fields below override accessibility mode defaults when set. |
| `font` | `string \| null` | `null` | Slide font override. Accessibility mode default: `"Verdana"`. Template-spec default: `"Arial"`. |
| `body_font_size` | `number \| null` | `null` | Slide body font size in pt. Accessibility mode default: `20`. Template-spec default: `18`. |
| `title_font_size` | `number \| null` | `null` | Slide title font size in pt. `null` = use template-spec default (`28`). |
| `line_spacing` | `number \| null` | `null` | Slide line spacing multiplier. Accessibility mode default: `1.3`. Template-spec default: unspecified (single). |
| `max_bullets_per_slide` | `number \| null` | `null` | Maximum bullet points per content slide. Accessibility mode default: `6`. No template-spec default. |

**Cascade resolution:** explicit teacher field → accessibility mode default (if `accessibility_mode: true`) → template-spec default.

### image_preferences

| Field | Type | Default | Description |
|---|---|---|---|
| `ai_citation_footnote` | `boolean \| null` | `true` | Include APA 7 citation footnote on placeholder images in generated materials. Default `true`. The footnote cites the AI model, prompt (truncated to ~50 words), and provider URL. |

## Validation Rules

- `version` must be a non-empty string
- `method_preferences.liked` and `method_preferences.rejected` must not contain the same method slug
- `social_form_tendencies` keys must be valid phase names: `einstieg`, `erarbeitung`, `sicherung`, `vertiefung`
- `language_level_calibration` keys must match a subject ID from `${CLAUDE_PLUGIN_ROOT}/references/subjects.json`
- All `null` fields indicate "no preference" — Claude decides based on didactic fit

## Lifecycle

| Event | Trigger | Details |
|---|---|---|
| **Created** | `/thalura:setup` | Empty structure with `version`, `last_updated: null`, and `slide_preferences.accessibility_mode: true`. All other preferences empty. |
| **Written — promotion** | Observation threshold reached | Layer 1 observation hits 3 occurrences → Claude proposes promotion → teacher confirms → entry added here, removed from observations. |
| **Written — explicit** | Teacher states preference directly | "I don't like using Kugellager" → Claude confirms ("Should I remember this?") → teacher confirms → entry added directly. |
| **Read** | Every session startup | Loaded in startup Step 5. Applied to all proposals and suggestions. |
| **Edited** | `/thalura:config preferences` | Teacher can review, modify, or remove preferences. |
| **Never overwritten** | Plugin updates | Project-only file. |

## Consumed By

| Consumer | Fields Used | Purpose |
|---|---|---|
| Yoda's Wisdom (methodology) | `method_preferences`, `social_form_tendencies` | Prioritize liked methods, deprioritize rejected |
| The Holocron (unit planning) | `method_preferences`, `lesson_structure_style` | Method suggestions in Grobplanung |
| The Upside Down (lesson detail) | `social_form_tendencies`, `lesson_structure_style` | Phase structure and social form defaults |
| The Playbook (material gen) | `material_preferences`, `formatting_preferences`, `slide_preferences`, `image_preferences.ai_citation_footnote` | Design, formatting defaults, slide accessibility, image citation |
| Challenge Accepted (assessment) | `assessment_style`, `operator_usage` | Grading scale, operator preferences |
| The Multiverse (differentiation) | `material_preferences` | Base material formatting inherited |
| Eleven's Vision (image prompts) | `material_preferences.copier_safe` | Print optimization default |

## Design Notes

- **Not two-tier:** This file has no plugin-side default. It starts empty and fills up through usage. The two-tier system is only for config files where plugin defaults make sense.
- **Class-specific feedback goes elsewhere:** Observations about a specific class (e.g., "E10a doesn't work well with group work") go into the class definition, not here. Preferences are cross-class patterns.
- **Preference Override:** Preferences never create blind spots. The core skill's *Preference Override — CRITICAL RULE* ensures that rejected methods can still be suggested when didactically necessary, with transparent justification.
- **All fields nullable:** Except for `version` and `last_updated`, every preference field can be `null` to indicate "no preference established yet." Claude fills the gap with didactic judgment.

## Migration Notes

The old skill's `profiles/teacher-preferences.json` maps directly:

| Old field | New field | Notes |
|---|---|---|
| `method_preferences` | `method_preferences` | Same structure |
| `social_form_tendencies` | `social_form_tendencies` | Same structure |
| `lesson_structure_style` | `lesson_structure_style` | Same structure |
| `material_preferences` | `material_preferences` | Same structure |
| `language_level_calibration` | `language_level_calibration` | Same structure |
| `assessment_style` | `assessment_style` | Same structure |
| `formatting_preferences` | `formatting_preferences` | Same structure |
| `operator_usage` | `operator_usage` | Same structure |
| — | `internal_compliance_check` | New field. Set to `true` during migration. |
| `internal_compliance_check`, `pdf_on_validation` | → moved to `config/behaviour.json` | see `${CLAUDE_PLUGIN_ROOT}/references/schemas/behaviour.md` |
