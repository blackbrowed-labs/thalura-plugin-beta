# Class Definition Schema

## File Path

```
<WORKSPACE_ROOT>/data/school-years/{YYYY-YY}/classes/{subject}_{grade_level}{section}.json
```

**Sek I examples:** `english_10a.json`, `philosophy_9b.json`, `religion_8a.json`
**Sek II examples:** `philosophy_S4.json`, `english_S2.json`, `religion_S1a.json` (rare parallel course)

## Annotated Example

### Sek I

```json
{
  "class_id": "E10a",
  "subject": "english",
  "grade_level": "10",
  "section": "a",
  "sek_level": "sek1",
  "course_level": null,
  "student_count": 28,
  "special_needs": [
    {
      "type": "lrs",
      "count": 2,
      "accommodations": ["extended_time", "spell_check_allowed"]
    }
  ],
  "differentiation_notes": "Three performance tiers; advanced group needs extension tasks",
  "prior_knowledge": "B1+ reading, weak formal essay structure, strong oral skills",
  "class_observations": "Highly engaged in group discussions, reluctant writers",
  "previous_year": "2024-25/E9a",
  "notes": "Strong in creative methods, weak in formal essay structure",
  "created_at": "2026-08-15T10:00:00Z"
}
```

### Sek II

```json
{
  "class_id": "PS4",
  "subject": "philosophy",
  "grade_level": "S4",
  "section": null,
  "sek_level": "sek2",
  "course_level": "gA",
  "student_count": 22,
  "special_needs": [],
  "differentiation_notes": null,
  "prior_knowledge": null,
  "class_observations": null,
  "previous_year": "2025-26/PS3",
  "notes": "Kein Schueler schreibt Abitur in Philosophie.",
  "created_at": "2026-02-20T00:00:00Z"
}
```

## Auto-Generated Fields

| Field | Source | Rule |
|---|---|---|
| `class_id` | `subject` + `grade_level` + `section` | Abbreviation from `${CLAUDE_PLUGIN_ROOT}/references/subjects.json` + grade_level + section (if present). Sek I: `E10a`. Sek II: `PS4`. |
| `sek_level` | `grade_level` | If grade_level starts with `"S"` → `"sek2"`. Otherwise derived from `education-system.json` boundaries. |

## Teacher-Provided Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `subject` | `string` | yes | Subject ID: `"english"`, `"philosophy"`, `"psychology"`, `"religion"` |
| `grade_level` | `string` | yes | Sek I: `"5"` through `"10"`. Sek II: `"S1"`, `"S2"`, `"S3"`, `"S4"`. |
| `section` | `string \| null` | Sek I: yes, Sek II: no | Lowercase letter (`"a"`, `"b"`, `"c"`). Required for Sek I, `null` for Sek II by default. Rare Sek II parallel courses may set it. |
| `course_level` | `string \| null` | Sek II: yes | `"gA"` (grundlegendes Anforderungsniveau) or `"eA"` (erhoehtes Anforderungsniveau). Official BSB abbreviations. Required for Sek II, `null` for Sek I. Critical for exam format selection and regulation routing. |
| `student_count` | `number` | yes | Number of students in the class. |
| `special_needs` | `array` | no | Structured list of Foerderbedarfe. Each entry: `{ "type": string, "count": number, "accommodations": string[] }`. Both `type` and the `accommodations[]` tokens reference `${CLAUDE_PLUGIN_ROOT}/references/special-needs-catalog.md` — the catalog is the authoritative vocabulary for the `type` enum and the English accommodation keys. |
| `differentiation_notes` | `string \| null` | no | Free-text notes on differentiation within this class. Informs The Multiverse. |
| `prior_knowledge` | `string \| null` | no | Summary of class's prior knowledge and skill levels. Informs unit planning (The Holocron). |
| `class_observations` | `string \| null` | no | Running observations about class dynamics and behavior. Informs method selection (The Playbook). |
| `previous_year` | `string \| null` | no | Relative path to prior year's class: `{year}/{class_id}` (e.g., `"2024-25/E9a"`, `"2025-26/PS3"`). Set during school year transition or manually. |
| `notes` | `string \| null` | no | General notes about this class. |
| `created_at` | `string` | auto | ISO-8601 timestamp, set on creation. |

## Validation Rules

- `subject` must be one of: `"english"`, `"philosophy"`, `"psychology"`, `"religion"`
- `grade_level` must be a string: `"5"` through `"10"` (Sek I) or `"S1"` through `"S4"` (Sek II)
- `section` must be a single lowercase letter when present; required for Sek I, typically `null` for Sek II
- `course_level` is required when `sek_level` is `"sek2"`, must be `null` for `"sek1"`
- `class_id` is auto-generated — never set manually by the teacher
- `sek_level` is auto-derived — never set manually
- There is **no** `school_year` field — the school year is derived from the folder path `<WORKSPACE_ROOT>/data/school-years/{year}/`
- `special_needs[].type` must reference a valid type from `${CLAUDE_PLUGIN_ROOT}/references/special-needs-catalog.md`; `special_needs[].accommodations[]` tokens are the English accommodation keys defined in that same catalog

## Notes for Commands

- When creating a class, prompt for: `subject`, `grade_level`, `section` (Sek I) or skip (Sek II), `course_level` (Sek II only), `student_count`
- All other fields are optional and can be populated over time
- `previous_year` is set during school year transition or manually by the teacher
- `previous_year` forms a **continuity chain** that planning and reflection may traverse read-only for prior-year context. The chain reads the **school-year `plan.json`** `reflection` object (`strengths` / `improvements` / `reuse_recommendation` — the rich pedagogical prose) for prior-year reflections, **not** the per-unit manifest's `reflection` field (which is a document tracker only), plus the prior class definition's `class_observations` / `prior_knowledge` / `notes`.
- `class_id` is used in document filenames and conversation
- When displaying the class to the teacher, always use `class_id` (e.g., "E10a", "PS4") — it is the primary human-readable identifier
