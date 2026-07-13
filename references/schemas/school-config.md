# School Config Schema

## File Path

```
<WORKSPACE_ROOT>/data/profiles/school-config.json
```

School-level configuration entity. Stores school identity, operational data (lesson duration slots), and optional school branding (colors + logo). Created during `/thalura:setup` alongside the teacher profile. One file per Thalura installation.

## Related Files

| File | Path | Description |
|---|---|---|
| Teacher profile | `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json` | References this config via `school_id` |
| Education system | `${CLAUDE_PLUGIN_ROOT}/references/education-system.json` | Source for `federal_state` and `school_type` validation |
| Localization | `${CLAUDE_PLUGIN_ROOT}/references/localization.json` | Display names for slot IDs and other English keys |
| Unit manifest | `{Subject}/{school_year}/{class_id}/{Unit_slug}/plan.json` | Lesson `duration` references slot IDs from this config |

## Annotated Example

```json
{
  "school_id": "hamburg-gymnasium-hansa-bergedorf-b2c9",
  "school_name": "Hansa-Gymnasium Bergedorf",
  "federal_state": "Hamburg",
  "school_type": "Gymnasium",
  "website": "https://www.hansa-gymnasium.de",
  "branding": {
    "primary_color": "#2958C3",
    "secondary_color": "#1A3A7F",
    "accent_color": "#9BB3EA",
    "neutral_dark": "#333333",
    "neutral_light": "#F5F5F5",
    "text_on_primary": "#FFFFFF",
    "logo_path_on_primary": "data/assets/school-logo-on-primary.png",
    "logo_path_on_white": "data/assets/school-logo-on-white.png",
    "slide_aspect_ratio": "16:10",
    "auto_detected": true,
    "confirmed_by_teacher": true,
    "template_hash": "a3f7e2..."
  },
  "lesson_slots": [
    {
      "id": "single",
      "segments": [
        { "type": "lesson", "minutes": 45 }
      ]
    },
    {
      "id": "double",
      "segments": [
        { "type": "lesson", "minutes": 90 }
      ]
    },
    {
      "id": "double_with_break",
      "segments": [
        { "type": "lesson", "minutes": 45 },
        { "type": "break", "minutes": 5 },
        { "type": "lesson", "minutes": 45 }
      ]
    }
  ],
  "created_at": "2026-02-20T10:00:00Z"
}
```

**Notes on the example:**
- `federal_state` and `school_type` are stored here as the authoritative source — the teacher profile only holds a `school_id` reference.
- `website` is the school's public URL — used as source for branding auto-detection during setup.
- `branding` contains the school's color palette and logo path. Auto-detected from the website and confirmed by the teacher. See `branding` Object section below.
- `single` (45min) and `double` (90min continuous) are pre-configured defaults for Hamburg schools. The teacher confirms or adjusts during setup.
- `double_with_break` is an example of a teacher-added custom slot — two 45min periods with a 5min break between them.
- Slot display names (`"Einzelstunde"`, `"Doppelstunde"`) are resolved via `localization.json`, not stored here. Custom slots store their own `label` (see below).

## Field Reference

### Root Level

| Field | Type | Required | Description |
|---|---|---|---|
| `school_id` | `string` | yes | Human-readable composite ID: `{federal_state}-{school_type}-{slug}-{short_uid}`. Auto-generated at setup. Referenced by `teacher-profile.json`. See ID format below. |
| `school_name` | `string` | yes | Official school name (German, as officially registered). Authoritative source — moved here from `teacher-profile.json`. |
| `federal_state` | `string` | yes | Must be a valid key in `education-system.json`. Determines available school types, grade boundaries, and school year calendar. Moved here from `teacher-profile.json`. |
| `school_type` | `string` | yes | Must be valid for the selected `federal_state` in `education-system.json`. Moved here from `teacher-profile.json`. |
| `website` | `string` | no | School's public website URL. Used as source for branding auto-detection. Stored when provided, regardless of branding outcome. |
| `branding` | `object \| null` | no | School branding palette and logo. `null` = teacher explicitly skipped branding. Omitted = branding never collected (backward compatibility with legacy configs from before branding was introduced). See `branding` Object below. |
| `lesson_slots` | `array` | yes | Available lesson slot configurations for this school. Minimum 1 entry. |
| `created_at` | `string` | yes | ISO-8601 timestamp of config creation. |

### `school_id` Format

```
{federal_state}-{school_type}-{slugified_school_name}-{short_uid}
```

| Component | Source | Example |
|---|---|---|
| `federal_state` | From teacher profile setup | `hamburg` |
| `school_type` | From teacher profile setup | `gymnasium` |
| `slugified_school_name` | Lowercase, ASCII, hyphenated | `musterstadt` (from "Gymnasium Musterstadt") |
| `short_uid` | Random 4 hex chars | `a3f7` |

**Full example:** `hamburg-gymnasium-musterstadt-a3f7`

The short UID (4 hex chars) ensures uniqueness when school names collide. The ID is human-readable — a developer or teacher can identify the school at a glance.

**Pattern (normative):** the full id must match `^[a-z0-9-]+-[0-9a-f]{4}$`; the `short_uid` is exactly the trailing 4 lowercase hex characters (`-[0-9a-f]{4}$`). All components are lowercase ASCII — non-ASCII letters are transliterated by the slug rules — so the id as a whole always matches the pattern. A generated id must be **verified against this pattern before it is first written**; a value that fails it (or that was not freshly sampled) must never be persisted.

### Lesson Slot Entry

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | `string` | yes | English slot identifier (e.g., `"single"`, `"double"`, `"double_with_break"`). Display names resolved via `localization.json` for pre-configured slots. |
| `segments` | `array` | yes | Ordered sequence of lesson and break segments. Minimum 1 segment. |
| `label` | `string` | no | Display name for custom (teacher-added) slots only. Pre-configured slots (`single`, `double`) use `localization.json` instead. |

### Segment Entry

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | `string` | yes | `"lesson"` or `"break"`. |
| `minutes` | `number` | yes | Duration of this segment in minutes. Positive integer. |

### Derived Values (computed, not stored)

| Value | Computation | Example (`double_with_break`) |
|---|---|---|
| Teaching time | Sum of all `"lesson"` segments | 90 min |
| Wall-clock time | Sum of all segments | 95 min |
| Break count | Count of `"break"` segments | 1 |

### `branding` Object

The branding object stores the school's visual identity — color palette and logo — for use in slide presentations and future document templates. All fields are optional except `primary_color` (required when the branding object is present).

| Field | Type | Required | Description |
|---|---|---|---|
| `primary_color` | `string` | yes | 7-character hex color (`#RRGGBB`). Slide title bars, header backgrounds, key accents. |
| `secondary_color` | `string` | no | Darker variant for footers, contrast elements. Default: primary darkened 20% in HSL. |
| `accent_color` | `string` | no | Highlights and interactive/graphical elements. Default: derived from `primary_color` to contrast ≥ 3:1 against it (decorative/large/UI use only — not for body-size text; see Color Derivation Rules). |
| `neutral_dark` | `string` | no | Body text, borders. Default: `#333333`. |
| `neutral_light` | `string` | no | Slide backgrounds, subtle fills. Default: `#F5F5F5`. |
| `text_on_primary` | `string` | no | Text color on primary backgrounds. Default: `#FFFFFF` if primary has sufficient contrast (WCAG ratio ≥ 4.5:1), otherwise `#000000`. |
| `logo_path_on_primary` | `string` | no | Path to white/light logo variant (transparent PNG) for dark slide backgrounds (TITLE, SECTION masters). Relative to `<WORKSPACE_ROOT>/`. If absent or file not found, no logo on dark-background slides. |
| `logo_path_on_white` | `string` | no | Path to primary-colored logo variant (transparent PNG) for white slide backgrounds (CONTENT, BLANK masters). Relative to `<WORKSPACE_ROOT>/`. If absent or file not found, no logo on white-background slides. |
| `slide_aspect_ratio` | `string` | no | Slide aspect ratio. Default: `"16:10"`. Allowed values: `"16:9"`, `"16:10"`. Not asked during setup — uses default silently. Configurable via `/thalura:config school`. |
| `auto_detected` | `boolean` | no | `true` if colors were extracted from the school website. `false` if entered manually. Default: `false`. |
| `confirmed_by_teacher` | `boolean` | no | `true` after the teacher has reviewed and accepted the palette. Auto-detected colors should not be used in outputs until confirmed. Default: `false`. |
| `template_hash` | `string \| null` | no | SHA-256 hash of the last generated `template_slides.pptx`. Used for manual-change detection before overwrites. `null` if no branded template has been generated. |

#### Color Field Roles

| Field | Role in Slides | Role in Documents |
|---|---|---|
| `primary_color` | Title bar backgrounds, header accents | Future: header accent color |
| `secondary_color` | Footer backgrounds, contrast elements | Future: footer accent |
| `accent_color` | Highlights, interactive/graphical elements | Future: link color (a future on-white link/text role would need a separate token contrasting ≥ 4.5:1 vs white — out of scope; the derived accent targets 3:1 vs the primary only) |
| `neutral_dark` | Body text, borders | Body text (already `#333333` by convention) |
| `neutral_light` | Slide backgrounds, subtle fills | Background fills |
| `text_on_primary` | Text on primary-colored backgrounds | Text on accent backgrounds |

#### Color Derivation Rules

When only `primary_color` is provided, the remaining colors are derived:

1. **`secondary_color`:** Convert primary to HSL, reduce lightness by 20%, convert back to hex.
2. **`accent_color`:** Convert primary to HSL. Starting from the primary's own lightness, increase lightness in 1% steps and re-derive the hex until the contrast ratio against `primary_color` is ≥ 3:1 (WCAG SC 1.4.11 Non-text Contrast / SC 1.4.3 large-text tier — the accent is a decorative/highlight token placed on primary-coloured backgrounds). Stop at the first lightness that meets 3:1. If lightness reaches 95% without meeting 3:1 (only near-white primaries), set `accent_color` to `neutral_dark` (`#333333`), which is guaranteed legible on a light primary background. The derivation is deterministic and reproducible; contrast against `#FFFFFF` is **not** a constraint — the accent is not placed on white in the current templates. The accent is for decorative / large / UI use only and **must not be used for body-size text** (it clears the 3:1 non-text/large-text floor, not the 4.5:1 body-text floor); a future on-white link/text accent role (see the `accent_color` field note) would need a **separate** derived token and is out of scope.
3. **`neutral_dark`:** Fixed default `#333333`.
4. **`neutral_light`:** Fixed default `#F5F5F5`.
5. **`text_on_primary`:** Calculate relative luminance of primary. If contrast ratio with `#FFFFFF` ≥ 4.5:1, use `#FFFFFF`. Otherwise use `#000000`.

#### Fallback Cascade

| Tier | Condition | `branding` value | Logo | Colors |
|---|---|---|---|---|
| 1 — Full detection | Website fetched, colors + logo found | Object with all fields, `auto_detected: true` | Auto-cropped, two transparent-background variants generated: `school-logo-on-primary.png`, `school-logo-on-white.png`; original kept as `school-logo-original.png` | Extracted from website CSS/logo |
| 2 — Partial detection | Website fetched, only primary color found | Object with `primary_color`, derived secondary/accent | None | Primary from website, rest derived |
| 3 — No detection | Website fetch failed or no website provided | Object with neutral defaults, `auto_detected: false` | None | Neutral education blue `#2B579A` + derived |
| 4 — Teacher skips | Teacher chooses to skip branding entirely | `null` | None | Consumers use hardcoded neutral palette |

**Tier 3 vs. Tier 4 distinction:** In Tier 3, the teacher actively chose a neutral palette (stored in `branding`). In Tier 4, the teacher skipped branding entirely (`branding: null`), and consumers fall back to their own hardcoded defaults. The visual result may be identical, but the intent differs — Tier 3 is a deliberate choice, Tier 4 is "I don't care about branding."

## Pre-Configured Defaults

During `/thalura:setup`, the following slots are pre-configured based on common Hamburg school patterns. The teacher confirms or adjusts.

| Slot ID | Segments | Teaching Time | Display Name (de) | Display Name (en) |
|---|---|---|---|---|
| `single` | 1× lesson (45min) | 45 min | Einzelstunde | Single Period |
| `double` | 1× lesson (90min) | 90 min | Doppelstunde | Double Period |

Display names for pre-configured slots are resolved via `localization.json` based on `conversation_language`. The teacher can add custom slots (e.g., `double_with_break`, `triple`) during setup or later via `/thalura:config school`.

### Custom Slot Example

```json
{
  "id": "double_with_break",
  "label": "Doppelstunde mit Pause",
  "segments": [
    { "type": "lesson", "minutes": 45 },
    { "type": "break", "minutes": 5 },
    { "type": "lesson", "minutes": 45 }
  ]
}
```

Custom slots include a `label` field because they are not in `localization.json`. The label is in the teacher's language (set at creation time).

## Validation Rules

- `school_id` must follow the `{federal_state}-{school_type}-{slug}-{short_uid}` format **and match `^[a-z0-9-]+-[0-9a-f]{4}$`** (suffix: exactly 4 lowercase hex chars)
- `federal_state` must be a valid key in `education-system.json`
- `school_type` must be valid for the selected `federal_state` in `education-system.json`
- `federal_state` and `school_type` must match the components embedded in `school_id`
- `website` must be a valid URL (`https://...`) if present
- `branding` must be either an object or `null` if present
- If `branding` is an object, `primary_color` is required
- All color fields (`primary_color`, `secondary_color`, `accent_color`, `neutral_dark`, `neutral_light`, `text_on_primary`) must be 7-character hex format (`#RRGGBB`) if present
- `logo_path_on_primary` must be a relative path within `<WORKSPACE_ROOT>/` if present (e.g., `<WORKSPACE_ROOT>/data/assets/school-logo-on-primary.png`)
- `logo_path_on_white` must be a relative path within `<WORKSPACE_ROOT>/` if present (e.g., `<WORKSPACE_ROOT>/data/assets/school-logo-on-white.png`)
- `slide_aspect_ratio` must be `"16:9"` or `"16:10"` if present
- `template_hash` must be a hex string or `null` if present
- `auto_detected` and `confirmed_by_teacher` must be boolean if present
- `lesson_slots` must contain at least 1 entry
- Each slot must have a unique `id`
- Each slot must have at least 1 segment
- All segment `minutes` values must be positive integers
- A slot cannot start or end with a `"break"` segment
- Custom slots (not in `localization.json`) must have a `label`

## Lifecycle

| Event | Trigger | Details |
|---|---|---|
| **Created** | `/thalura:setup` | Pre-configured defaults offered. Teacher confirms or adjusts. Custom slots can be added. Branding auto-detected or skipped (Phase 2.5). |
| **Read** | Session startup + lesson planning | Loaded to resolve `duration` slot IDs in `plan.json` to actual minutes. Branding read at slide/document generation time. |
| **Edited** | `/thalura:config school` | Teacher can modify school name, add/edit/remove lesson slots. Branding can be re-detected, adjusted, or cleared. |
| **Never overwritten** | Plugin updates | Project-only file. Plugin updates never touch it. |

### Field Sources (Setup)

| Field | Source | Set during |
|---|---|---|
| `school_id` | Auto-generated from `federal_state` + `school_type` + `school_name` + random UID | Setup completion |
| `school_name` | Teacher input | Setup Step 4 |
| `federal_state` | Dropdown from `education-system.json` | Setup Step 4 |
| `school_type` | Dropdown filtered by `federal_state` | Setup Step 4 |
| `website` | Teacher input (optional) | Setup Phase 2.5 |
| `branding` | Auto-detected from website + teacher confirmation, or `null` if skipped | Setup Phase 2.5 |
| `lesson_slots` | Pre-configured defaults + teacher adjustments | Setup Step 4 |
| `created_at` | Auto-generated | Setup completion |

## Consumed By

| Consumer | Fields used | Purpose |
|---|---|---|
| `teacher-profile.json` | `school_id` | Links teacher to school config |
| Unit manifest (`plan.json`) | `lesson_slots[].id` | Resolves lesson `duration` to actual minutes |
| Education system | `federal_state`, `school_type` | Determines grade boundaries, regulation paths, school year calendar |
| All generation commands | `lesson_slots` | Time validation and material scope hints |
| Slide template | `branding.*` (colors, `logo_path_on_primary`, `logo_path_on_white`, `slide_aspect_ratio`) | Slide master colors, logo variant placement, dimensions |
| Future: document templates | `branding.primary_color`, `logo_path_on_white` | Header accent color, logo in headers |

## Design Notes

- **School-level, not teacher-level.** The `school_id` enables future multi-teacher sharing — multiple teachers at the same school can reference the same config.
- **`school_name`, `federal_state`, `school_type` authoritative source.** School name moved here from `teacher-profile.json`. Federal state and school type moved here too. The teacher profile references the school via `school_id` only.
- **Segment-based model.** Supports arbitrary combinations: single period, double without break, double with break at any position, triple with multiple breaks. Total teaching time and wall-clock time are derived from segments.
- **Pre-configured defaults.** `single` (45min) and `double` (90min continuous) are offered at setup. Based on common Hamburg school patterns. Teacher confirms or adjusts.
- **Slot IDs are English**, display names localized via `localization.json`. Custom slots store their own `label` since they are not in the localization table.
- **No lesson timetable.** This config defines available slot types, not when they occur in the week. Timetable integration is out of scope for v1.0.
- **Branding is optional and skippable.** The plugin functions fully without branding. Schools without branding get clean, neutral documents.
- **`null` vs. omitted branding.** `null` means "teacher was asked and chose to skip." Omitted means "branding was never collected" (legacy configs from before branding was introduced). Both result in no branding, but the semantics differ for future re-prompting logic.
- **No fallback logo.** If `logo_path_on_primary`/`logo_path_on_white` are absent or the files do not exist, no logo appears. The plugin ships with no bundled logo. The original downloaded logo is kept as `school-logo-original.png` for re-derivation.
- **Slide aspect ratio silent default.** `slide_aspect_ratio` defaults to `"16:10"` without asking during setup. Teachers who skip branding get 16:10 from the plugin-bundled template. Configurable via `/thalura:config school`.
- **Manual-change detection.** `template_hash` enables detecting teacher modifications to the branded template before overwriting.
- **`auto_detected` flag.** Lets consumers know whether colors came from a real school website or were entered manually. Informational only — does not change behavior.
- **`confirmed_by_teacher` flag.** Quality gate — auto-detected colors should not be used in generated outputs until the teacher confirms. After confirmation, this is `true`.
