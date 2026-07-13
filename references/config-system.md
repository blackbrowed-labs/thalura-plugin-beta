# Two-Tier Config System

Configuration files exist in two locations. At runtime, Claude reads **both** and merges them: the project config overrides the plugin defaults. This overlay model means the teacher's file is never modified by plugin updates.

---

## Architecture

### Tier 1 — Plugin Defaults (base layer)

```
config-defaults/
  naming-conventions.json
```

- **Immutable** — shipped with the plugin, updated via plugin updates
- Teachers never edit these files
- Source of truth for default values and new keys added in updates

### Tier 2 — Project Config (override layer)

```
<WORKSPACE_ROOT>/data/config/
  naming-conventions.json
```

- **Mutable** — owned by the teacher
- Created during `/thalura:setup` by copying from plugin defaults
- **Never modified by plugin updates** — teacher's customizations are always safe
- Edited via `/thalura:config`

### Precedence Rule

At runtime, Claude reads both files and applies this merge:

1. Start with plugin defaults (all keys)
2. Override with any keys present in the project config

The teacher's value always wins for keys they've customized. For keys missing from the project config (e.g., added in a plugin update), the plugin default applies automatically.

---

## Config File Inventory

### Two-Tier (defaults → project)

| File | Purpose | Default location | Project location |
|---|---|---|---|
| `naming-conventions.json` | Document and folder naming patterns | `${CLAUDE_PLUGIN_ROOT}/config-defaults/` | `<WORKSPACE_ROOT>/data/config/` |
| `behaviour.json` | Per-teacher behaviour toggles — should this automatic step run? (`internal_compliance_check`, `pdf_on_validation`, `generate_student_slides`) | `${CLAUDE_PLUGIN_ROOT}/config-defaults/` | `<WORKSPACE_ROOT>/data/config/` |
| `standard-supplies.json` | The teacher's optional list of everyday classroom supplies (Standardmaterial) actually on hand — a soft hint biasing lesson-proposal standard-supplies content. See `${CLAUDE_PLUGIN_ROOT}/references/schemas/standard-supplies.md`. | `${CLAUDE_PLUGIN_ROOT}/config-defaults/` | `<WORKSPACE_ROOT>/data/config/` |

**`behaviour.json` migration note:** The three toggles (`internal_compliance_check`, `pdf_on_validation`, `generate_student_slides`) were previously root-level keys in the project-only profile files (`teacher-preferences.json` and `teacher-profile.json`). They were moved into the two-tier system to enable update-safe defaults and clean new-key merges. The `version-migrate.sh` update migration (Step 4d) carries existing teacher values from both legacy files into the new location automatically on the first update after the move ships. See `${CLAUDE_PLUGIN_ROOT}/references/schemas/behaviour.md` for the full schema.

### Project-Only (no plugin default)

| File | Location | Reason |
|---|---|---|
| `teacher-profile.json` | `<WORKSPACE_ROOT>/data/profiles/` | Personal identity data — no sensible default |
| `school-config.json` | `<WORKSPACE_ROOT>/data/profiles/` | School-specific data — no sensible default |
| `teacher-preferences.json` | `<WORKSPACE_ROOT>/data/profiles/` | Validated teaching preferences — learned from usage |
| `teacher-observations.json` | `<WORKSPACE_ROOT>/data/profiles/` | Tracked patterns, not yet validated — learned from usage |
| `version.json` | `<WORKSPACE_ROOT>/data/` | Last-seen plugin version — written by setup, updated by Step 1 version check |

### Removed

| File | Reason |
|---|---|
| `output-language.json` | Language configuration moved into `teacher-profile.json` per-subject `content_language` |

---

## Lifecycle

### Initial Setup (`/thalura:setup`)

1. Check if `<WORKSPACE_ROOT>/data/config/` exists; create if not
2. For each file in `config-defaults/`:
   - If no corresponding file exists in `<WORKSPACE_ROOT>/data/config/` → copy it
   - If file already exists → skip (never overwrite)
3. Teacher can customize project config files immediately after setup

### Plugin Update

1. For each file in `config-defaults/`:
   - If file does **not** exist in `<WORKSPACE_ROOT>/data/config/` → copy new default
   - If file **does** exist → **do nothing** (teacher's file is never touched)
2. New keys added to plugin defaults are automatically available at runtime via the overlay merge — no file patching needed
3. The teacher's project config may have fewer keys than the current defaults. This is expected and safe.

### Config Editing (`/thalura:config`)

- Reads the **effective config** (merged view: defaults + project overrides)
- Writes changes to `<WORKSPACE_ROOT>/data/config/` only
- Never touches `config-defaults/`
- Highlights new options the teacher hasn't customized yet
- Sub-commands: `/thalura:config naming` for naming patterns; `/thalura:config behaviour` for behaviour toggles

### How Missing Keys Work

When the project config is missing a key that exists in the plugin default:

- Claude uses the plugin default value automatically (overlay merge)
- The teacher's file is **not** patched — missing keys are filled from defaults at read time
- This means older project configs work seamlessly with newer plugin versions

---

## JSON Key Convention

All JSON keys use **English identifiers**. Values use template variables — including `{*_label}` variables that resolve to localized strings at runtime:

```json
{
  "documents": {
    "unit_plan": "{subject_abbr}{grade} - {unit_title} - {unit_plan_label}"
  }
}
```

Here `unit_plan` (key) is English; `{unit_plan_label}` resolves to `Einheitenplanung` (DE) or `UnitPlan` (EN) via `localization.json` → `naming_labels` based on `conversation_language`. See `naming-conventions.md` for the full variable reference.

---

## Adding a New Config File

To add a new two-tier config file:

1. Create the default in `${CLAUDE_PLUGIN_ROOT}/config-defaults/{filename}.json`
2. Add an entry to the inventory table above
3. `/thalura:setup` will automatically copy it on first run (it iterates all files in `config-defaults/`)
4. Plugin updates will copy it for existing installations that don't have it yet
5. Add a `/thalura:config` sub-command for editing

To add a project-only file (no default):

1. Create it during setup or at runtime as needed
2. Add an entry to the project-only inventory table above
3. No entry in `config-defaults/`
