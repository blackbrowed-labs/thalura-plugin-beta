# Behaviour-Toggle Config Schema

## File Path

### Tier 1 — Plugin Default (base layer)

```
${CLAUDE_PLUGIN_ROOT}/config-defaults/behaviour.json
```

### Tier 2 — Teacher Override (project layer)

```
<WORKSPACE_ROOT>/data/config/behaviour.json
```

**Two-Tier:** This is a two-tier config file. The plugin default ships the base values; the teacher's project-level override wins for any key present in it. For the full overlay mechanism, see `${CLAUDE_PLUGIN_ROOT}/references/config-system.md`.

At read time the effective value for each toggle is:

```
effective(key) = teacher override value  [if key is present in data/config/behaviour.json]
              else  plugin default value  [from config-defaults/behaviour.json]
```

The teacher's file is **never patched** at read time — missing keys are filled from the plugin default on the fly.

## Related Files

| File | Path | Description |
|---|---|---|
| Config system reference | `${CLAUDE_PLUGIN_ROOT}/references/config-system.md` | Two-tier overlay machinery, lifecycle, and inventory |
| Teacher preferences | `<WORKSPACE_ROOT>/data/profiles/teacher-preferences.json` | Validated teaching preferences (slide_preferences and other style settings remain here) |
| Teacher profile | `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json` | Teacher identity and language configuration |
| HiTL lifecycle | `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` | 8-step human-in-the-loop flow; Steps 4 and 8 read from this file |
| Config editor | `${CLAUDE_PLUGIN_ROOT}/skills/config/SKILL.md` | `/thalura:config behaviour` sub-command |

## Annotated Example

```json
{
  "internal_compliance_check": true,
  "pdf_on_validation": "student_facing",
  "generate_student_slides": true
}
```

All three keys are flat top-level scalars. The plugin default (`${CLAUDE_PLUGIN_ROOT}/config-defaults/behaviour.json`) ships all three as concrete values (no `null`). The teacher override file may omit keys or carry `null` for `generate_student_slides` — see the Merge/Resolution section below.

## Field Reference

### internal_compliance_check

| Field | Type | Default | Description |
|---|---|---|---|
| `internal_compliance_check` | `boolean` | `true` | Enable/disable the automatic Sacred Texts quick-check that runs before writing any `_ENTWURF` to disk (Step 4 of the 8-step HiTL flow). Applies to document-producing tasks: Holocron, Upside Down, Playbook, Multiverse, Challenge Accepted, Eleven's Vision. Also re-runs on every revision (Step 7); the canonical 8-step HiTL flow and the Step 4 compliance gate live in the core satellite `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md`. |

### pdf_on_validation

| Field | Type | Default | Description |
|---|---|---|---|
| `pdf_on_validation` | `string` | `"student_facing"` | Controls whether a validated material automatically gets a PDF, and for which audience. `"student_facing"` (default) — only student-facing materials get a PDF on validation: worksheets (Arbeitsblatt), handouts (Handout), reading texts (Lesetext), slides (Folien), student task decks (Aufgabenfolien), and the assessment task paper (Aufgabe); differentiated variants of any of these inherit student-facing status. `"all"` — also generates PDFs for teacher-facing documents (grading rubric (Erwartungshorizont), unit plan (Einheitenplanung), lesson plans (Verlaufsplan/Stundenentwurf), year plan, reflection (Reflexion)). `"off"` — no automatic PDF is generated; any existing PDFs are left untouched. This is an **advanced setting** — it is **not** asked during onboarding or setup. |

### generate_student_slides

| Field | Type | Default | Description |
|---|---|---|---|
| `generate_student_slides` | `boolean \| null` | `true` | Whether the per-lesson student task deck is produced. When `true` (or absent / `null` → default `true`), the deck is proposed during the lesson draft (The Upside Down) and generated after the lesson is validated (The Playbook); `false` disables both. The deck's slide-accessibility settings are independent and live in `teacher-preferences.json → slide_preferences`. |

## Merge/Resolution

At read time, for each key:

| Key | Absent from teacher file | `null` in teacher file | Concrete value in teacher file |
|---|---|---|---|
| `internal_compliance_check` | → plugin default (`true`) | — (not a valid teacher value) | teacher value wins |
| `pdf_on_validation` | → plugin default (`"student_facing"`) | — (not a valid teacher value) | teacher value wins |
| `generate_student_slides` | → plugin default (`true`) | → treated as `true` (same as absent) | teacher value wins |

**Plugin default values are concrete scalars** — the base layer never carries `null` or absent keys for these toggles. Only the teacher layer may carry `null` or absent values.

**Absent/null semantics (preserved from the legacy homes):**
- `generate_student_slides` absent or `null` ≡ `true`
- `pdf_on_validation` absent ≡ `"student_facing"`
- `internal_compliance_check` absent ≡ `true`

## Validation Rules

- `internal_compliance_check` must be a `boolean` (`true` or `false`); absent ≡ `true`
- `generate_student_slides` must be `boolean` or `null` (or absent); absent / `null` ≡ `true`
- `pdf_on_validation` must be one of `"student_facing"`, `"all"`, `"off"`; absent ≡ `"student_facing"`
- The file must be valid JSON; unknown top-level keys are ignored (forward-compatibility)

## Lifecycle

| Event | Trigger | Details |
|---|---|---|
| **Created (teacher file)** | `/thalura:setup` | The setup step copies `${CLAUDE_PLUGIN_ROOT}/config-defaults/behaviour.json` to `<WORKSPACE_ROOT>/data/config/behaviour.json` if the file does not already exist (copy-if-missing). The teacher is not asked about these settings during onboarding — the defaults apply. |
| **Updated (teacher file)** | Plugin update | `version-migrate.sh` Step 4a: if the teacher file does not yet exist, it is seeded from `${CLAUDE_PLUGIN_ROOT}/config-defaults/behaviour.json` (same copy-if-missing). If it already exists, it is **never overwritten**. New keys added in future plugin versions become available at read time via the overlay — no file patching is needed. |
| **Migrated** | First update after the move ships | `version-migrate.sh` Step 4d: existing toggle values in `<WORKSPACE_ROOT>/data/profiles/teacher-preferences.json` (`internal_compliance_check`, `pdf_on_validation`) and `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json` (`generate_student_slides`) are carried forward into `<WORKSPACE_ROOT>/data/config/behaviour.json`. The new location always wins — legacy values are never imported if the teacher has already set a value here. Migration is idempotent (safe to run twice). See `${CLAUDE_PLUGIN_ROOT}/scripts/version-migrate.sh` §Step 4d. |
| **Edited** | `/thalura:config behaviour` | Reads the effective config (merged view), shows current values (highlighting teacher overrides vs. defaults), and writes changes only to `<WORKSPACE_ROOT>/data/config/behaviour.json`. |
| **Read** | Every document-producing task | Step 4 (compliance gate) reads `internal_compliance_check`; Step 8 (post-validation PDF) reads `pdf_on_validation`; lesson-detail (The Upside Down) and material-gen (The Playbook) read `generate_student_slides`. All reads apply the two-tier overlay. |
| **Never overwritten by updates** | Plugin updates | The teacher's override file is project-owned. Plugin updates never modify it. |

## Consumed By

| Consumer | Field | Purpose |
|---|---|---|
| Core compliance gate (`hitl-lifecycle.md` Step 4) | `internal_compliance_check` | Whether to run the automatic Sacred Texts quick-check before writing any `_ENTWURF`; re-runs on revision (Step 7) |
| Validation / document-producing tasks (`hitl-lifecycle.md` Step 8: Holocron, Upside Down, Playbook, Multiverse, Challenge Accepted, Eleven's Vision) | `pdf_on_validation` | Whether and for which audience to generate a PDF automatically on material validation |
| The Upside Down (`lesson-detail`) | `generate_student_slides` | Whether to propose the per-lesson student task deck (Aufgabenfolien) during the lesson draft |
| The Playbook (`material-gen`) | `generate_student_slides` | Whether to generate the per-lesson student task deck after lesson validation |

## Design Notes

- **Behaviour toggles only.** This file holds "should this automatic step run?" switches. Style, formatting, and pedagogy preferences remain in `teacher-preferences.json`; teacher identity and language settings remain in `teacher-profile.json`. The slide-accessibility settings (`slide_preferences`) in particular are **not** in this file — they stay in `teacher-preferences.json` alongside the rest of the slide-presentation style settings. The on/off `generate_student_slides` toggle (this file) and the slide-accessibility settings (`teacher-preferences.json → slide_preferences`) are cleanly separated by design.
- **Flat top-level keys.** The three toggles are independent scalar switches with no natural sub-namespace. Flat layout mirrors the legacy homes and keeps the bash-3.2-safe migration logic simple.
- **State-agnostic.** No issuer, authority, school type, or federal-state name appears in this schema or in `${CLAUDE_PLUGIN_ROOT}/config-defaults/behaviour.json`. The toggles are generic "should this automatic step run?" controls that apply across any deployment context.
- **No onboarding question.** These are advanced settings. The defaults apply silently at setup; teachers discover them via `/thalura:config behaviour`.

## Migration Notes

The three toggles previously lived in the project-only profile files:

| Toggle | Old home | New home |
|---|---|---|
| `internal_compliance_check` | `<WORKSPACE_ROOT>/data/profiles/teacher-preferences.json` (root-level key) | `<WORKSPACE_ROOT>/data/config/behaviour.json` |
| `pdf_on_validation` | `<WORKSPACE_ROOT>/data/profiles/teacher-preferences.json` (root-level key) | `<WORKSPACE_ROOT>/data/config/behaviour.json` |
| `generate_student_slides` | `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json` (root-level key) | `<WORKSPACE_ROOT>/data/config/behaviour.json` |

The `version-migrate.sh` Step 4d migration carries existing teacher values forward on the first update after the move ships. No teacher data is lost. See `${CLAUDE_PLUGIN_ROOT}/references/config-system.md` for the two-tier system details.
