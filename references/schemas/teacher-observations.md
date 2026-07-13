# Teacher Observations Schema (Layer 1)

## File Path

```
<WORKSPACE_ROOT>/data/profiles/teacher-observations.json
```

Layer 1 of the two-layer preference system. Tracks implicit patterns from the teacher's accept/reject decisions **continuously** during every session. When a pattern reaches the promotion threshold, it is proposed for promotion to Layer 2 (teacher-preferences.json).

This is a project-only file (not part of the two-tier config system). It is never shipped with the plugin, never overwritten by updates, and has no plugin-side default.

## Related Files

| File | Path | Description |
|---|---|---|
| Teacher preferences | `<WORKSPACE_ROOT>/data/profiles/teacher-preferences.json` | Layer 2: validated preferences. Promotion target for observations that reach threshold. |
| Teacher profile | `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json` | Teacher identity and language config |
| Class definitions | `<WORKSPACE_ROOT>/data/school-years/{year}/classes/*.json` | Class-specific observations go here, NOT in this file |
| Core skill | `skills/core/SKILL.md` | Defines the two-layer system (*Two-Layer Teacher Preference System*) and observation tracking rules |

## Annotated Example

```json
{
  "version": "1.0",
  "last_updated": "2026-10-12T09:15:00Z",
  "promotion_threshold": 3,
  "categories": {
    "method_acceptance": {
      "fishbowl": {
        "count": 2,
        "contexts": [
          "Philosophie S2 — Erarbeitung zum Thema Gerechtigkeit",
          "Religion 9a — Sicherung interreligiöser Dialog"
        ],
        "first_seen": "2026-09-20T10:00:00Z",
        "last_seen": "2026-10-12T09:15:00Z",
        "promoted": false,
        "promotion_denied": false
      }
    },
    "method_rejection": {
      "kugellager": {
        "count": 3,
        "contexts": [
          "Englisch 8a — zu laut",
          "Englisch 10b — Klasse zu gross",
          "Philosophie S2 — dauert zu lange"
        ],
        "first_seen": "2026-09-15T08:30:00Z",
        "last_seen": "2026-10-10T14:00:00Z",
        "promoted": true,
        "promotion_denied": false
      }
    },
    "social_form_acceptance": {},
    "social_form_rejection": {},
    "format_preference": {
      "copier_safe": {
        "count": 2,
        "contexts": [
          "Arbeitsblatt Englisch 8a — explizit schwarz-weiss gewünscht",
          "Arbeitsblatt Religion 9a — Kopierer kann kein Grau"
        ],
        "first_seen": "2026-09-22T11:00:00Z",
        "last_seen": "2026-10-05T13:00:00Z",
        "promoted": false,
        "promotion_denied": false
      }
    },
    "style_preference": {},
    "assessment_format": {}
  }
}
```

**Notes on the example:**
- `kugellager` reached the threshold (count = 3) and was promoted to Layer 2. The entry stays with `promoted: true` as a record.
- `fishbowl` has count 2 — one more acceptance will trigger a promotion proposal.
- `copier_safe` tracks a format preference pattern, not a method pattern.

## Field Reference

### Root Level

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `version` | `string` | yes | `"1.0"` | Schema version. |
| `last_updated` | `string \| null` | yes | `null` | ISO-8601 timestamp of last modification. `null` when freshly created. |
| `promotion_threshold` | `number` | yes | `3` | Number of occurrences required before proposing promotion to Layer 2. |

### categories

Top-level object containing observation category buckets. Each bucket is an object keyed by the observed item's slug.

| Category | Tracks | Promotion Target |
|---|---|---|
| `method_acceptance` | Methods the teacher accepted/chose | `teacher-preferences.json` → `method_preferences.liked` |
| `method_rejection` | Methods the teacher rejected/declined | `teacher-preferences.json` → `method_preferences.rejected` |
| `social_form_acceptance` | Preferred social forms per phase | `teacher-preferences.json` → `social_form_tendencies` |
| `social_form_rejection` | Rejected social forms per phase | `teacher-preferences.json` → `social_form_tendencies` (inverse) |
| `format_preference` | Material/document format preferences | `teacher-preferences.json` → `material_preferences` or `formatting_preferences` |
| `style_preference` | Lesson structure and style patterns | `teacher-preferences.json` → `lesson_structure_style` |
| `assessment_format` | Assessment format patterns | `teacher-preferences.json` → `assessment_style` |

### Observation Entry

Each entry within a category bucket is keyed by the observed item's slug (e.g., `"kugellager"`, `"copier_safe"`, `"group_work_erarbeitung"`).

| Field | Type | Required | Description |
|---|---|---|---|
| `count` | `number` | yes | Number of times this pattern has been observed. Incremented on each occurrence. |
| `contexts` | `string[]` | yes | Human-readable context for each occurrence. Format: `"{Subject} {grade} — {brief reason}"`. Helps the teacher understand why promotion is proposed. |
| `first_seen` | `string` | yes | ISO-8601 timestamp of the first observation. |
| `last_seen` | `string` | yes | ISO-8601 timestamp of the most recent observation. |
| `promoted` | `boolean` | yes | `true` if this observation was promoted to Layer 2. Entry is kept as a record. |
| `promotion_denied` | `boolean` | yes | `true` if the teacher denied promotion when threshold was reached. Counter is reset to `0` on denial, but the entry persists so it can track again. |

## Promotion Lifecycle

### Step 1: Observation Recorded

When the teacher accepts or rejects a method, format, style, or approach during any task:

1. Identify the category and item slug
2. If entry exists → increment `count`, append to `contexts`, update `last_seen`
3. If entry does not exist → create with `count: 1`
4. **Immediately** check if `count >= promotion_threshold`

### Step 2: Threshold Reached

When an observation reaches the promotion threshold:

1. Present the promotion proposal to the teacher in the current conversation:
   ```
   I've noticed that you have {accepted/rejected} {item} {count} times:
   - {context 1}
   - {context 2}
   - {context 3}
   Should I save this as a permanent preference?
   ```
   The proposal is output in `conversation_language`. The template above shows the English structure; localized labels are resolved via `localization.json`.
2. Wait for teacher response.

### Step 3a: Promotion Confirmed

1. Add the item to the appropriate field in `teacher-preferences.json`
2. Set `promoted: true` in the observation entry
3. The observation entry stays as a historical record

### Step 3b: Promotion Denied

1. Set `promotion_denied: true`
2. Reset `count` to `0`
3. Clear `contexts` array
4. The entry persists — future occurrences will begin tracking again from 0
5. On the next threshold reach, propose promotion again (teachers change their minds)

### Explicit Statement Bypass

If the teacher directly states a preference (e.g., "I don't like using Kugellager"), skip Layer 1 entirely:

1. Claude confirms: "Should I remember this?"
2. If confirmed → write directly to `teacher-preferences.json` (Layer 2)
3. No observation entry needed — the preference is already validated

## Validation Rules

- `version` must be a non-empty string
- `promotion_threshold` must be a positive integer (minimum 1)
- `categories` keys must be one of the defined category names
- Each observation entry must have all required fields (`count`, `contexts`, `first_seen`, `last_seen`, `promoted`, `promotion_denied`)
- `contexts` array length should match `count` (unless reset after denial)
- An entry cannot have both `promoted: true` and `promotion_denied: true`

## Lifecycle

| Event | Trigger | Details |
|---|---|---|
| **Created** | `/thalura:setup` | Empty structure with `version`, `last_updated: null`, `promotion_threshold: 3`, empty category buckets. |
| **Written** | Every accept/reject during any task | Claude writes immediately after each teacher decision. No batching. |
| **Read** | Every session startup | Loaded in startup Step 6. Checked for patterns at or near threshold. |
| **Promotion check** | Startup + every write | If any observation is at threshold on startup, propose promotion before starting the task. |
| **Edited** | `/thalura:config preferences` | Teacher can view tracked observations, adjust threshold, or manually promote/dismiss. |
| **Never overwritten** | Plugin updates | Project-only file. |

## Consumed By

| Consumer | Purpose |
|---|---|
| Core skill (startup Step 6) | Check for pending promotions before starting any task |
| All task skills | Write observations on every accept/reject decision |
| The Holocron Log (reflection) | Method feedback from reflection interview feeds into observations |
| `/thalura:config preferences` | View and manage tracked observations |

## Design Notes

- **Immediate writes:** Observations are written to disk immediately after each teacher decision, not batched at end of session. This prevents data loss if the session ends unexpectedly.
- **Class-specific observations go elsewhere:** "E10a doesn't work well with group work" is a class observation → goes into the class definition. "I don't like Kugellager" is a cross-class preference → tracked here.
- **Context strings are human-readable:** They help the teacher understand why a promotion is being proposed. They are not structured data — Claude generates them as brief, informative descriptions.
- **Reset on denial preserves the entry:** The entry structure stays so future occurrences track again. This handles the case where a teacher initially says "no, that's not a pattern" but later develops the pattern more clearly.
- **Promotion threshold is configurable:** Default is 3, but the teacher can adjust via `/thalura:config preferences`. A lower threshold makes the system learn faster; a higher threshold requires more evidence.

## Migration Notes

The old skill's `profiles/teacher-observations.json` maps directly:

| Old field | New field | Notes |
|---|---|---|
| `observations.method_acceptance` | `categories.method_acceptance` | Renamed parent key from `observations` to `categories` |
| `observations.method_rejection` | `categories.method_rejection` | Same |
| `observations.social_form_acceptance` | `categories.social_form_acceptance` | Same |
| `observations.social_form_rejection` | `categories.social_form_rejection` | Same |
| `observations.format_preference` | `categories.format_preference` | Same |
| `observations.style_preference` | `categories.style_preference` | Same |
| `observations.assessment_format` | `categories.assessment_format` | Same |
| `_rules.promotion_threshold` | `promotion_threshold` | Moved to root level |
| `_observation_entry_schema` | — | Dropped. Schema is now documented here. |
| `_rules` | — | Dropped. Rules are now in core skill + this schema. |
| `_description` | — | Dropped. Documentation is now here. |
