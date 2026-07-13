---
name: config
description: Konfiguration ändern. Use when the teacher wants to change existing configuration (Konfiguration) — profile, school details, naming conventions, branding, preferences, or the standard-supplies list (Standardmaterial).
when_to_use: |
  DE + EN: "Konfiguration ändern", "Einstellungen", "Profil bearbeiten", "Schule ändern", "Branding/Logo ändern", "Benennung anpassen", "Standardmaterial-Liste", "meine Materialien/Vorräte pflegen", "welches Standardmaterial ich habe", "available supplies", "standard materials list", "change settings", "edit profile/school", "configure". Edits an EXISTING workspace; NOT first-run (→ setup). Creating teaching materials ("Arbeitsblatt", "Material erstellen") stays with material-gen; the standard-supplies surface only edits the inventory list.
---

# /thalura:config — Configuration Editing

> Core protocols — startup, HiTL/draft lifecycle, preferences, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).
>
> **Note:** all six sub-commands — `profile`, `school`, `preferences`, `naming`, `behaviour`, and `supplies` — are implemented below.

Provides sub-commands for editing Thalura configuration, teacher profile, and school settings. Uses the two-tier config system: plugin defaults are immutable, teacher overrides take precedence.

---

## Sub-Commands

| Sub-Command | Scope | Edits | Status |
|-------------|-------|-------|--------|
| `/thalura:config profile` | Teacher profile | Name, abbreviation, email, subjects, language settings | Implemented |
| `/thalura:config school` | School config | School name, federal state, school type, lesson slots, website, branding, slide aspect ratio | Implemented |
| `/thalura:config preferences` | Teacher preferences | Validated preferences, slide accessibility settings | Implemented |
| `/thalura:config naming` | Naming conventions | File and folder naming patterns | Implemented |
| `/thalura:config behaviour` | Behaviour toggles | `internal_compliance_check`, `pdf_on_validation`, `generate_student_slides` | Implemented |
| `/thalura:config supplies` | Standard supplies (Standardmaterial) | The teacher's optional list of everyday classroom supplies actually on hand | Implemented |

## Core Protocols

All shared protocols are defined in `skills/core/SKILL.md`:

- **Two-tier config system** (`${CLAUDE_PLUGIN_ROOT}/references/config-system.md`) — plugin defaults overlaid with teacher overrides
- **Teacher preference system** (core skill *Two-Layer Teacher Preference System*) — direct editing of validated preferences

## Workflow

1. Read the teacher profile to determine `conversation_language`
2. Parse the sub-command from the teacher's request
3. Load the relevant config file(s) — both plugin default and teacher override
4. Present current values and ask what the teacher wants to change
5. Validate input against schema constraints
6. Write the updated file to `<WORKSPACE_ROOT>/data/config/` or `<WORKSPACE_ROOT>/data/profiles/`
7. Confirm changes in chat

## `/thalura:config school` — Branding Editing

When the teacher asks to edit school branding (e.g., "change school colors", "update logo", "add branding", "remove branding"), follow this workflow.

### Current State Display

Read `<WORKSPACE_ROOT>/data/profiles/school-config.json`. Present current branding status:

- **Branding present (object):** Show current palette (primary, secondary, accent), logo variants (on-primary path + exists?, on-white path + exists?), slide aspect ratio, whether auto-detected or manual.
- **Branding null (skipped):** "School branding is currently disabled. Would you like to set it up?"
- **Branding absent (legacy config from before branding was introduced):** "No branding has been configured yet. Would you like to set it up?"

### Editing Options

> **Scaffold from zero (never-branded workspace).** On a workspace where branding was skipped at setup (`branding: null`), neither `<WORKSPACE_ROOT>/data/assets/` nor `<WORKSPACE_ROOT>/data/templates/materials/` exists — setup creates them **only** when branding is configured (setup Phase 5.2 note; the scaffold-completion routine leaves them uncreated for a `null`/absent branding block by design). This add-later flow is the actor that configures branding, so it **must create those directories itself** before writing into them — the same explicit `Ensure … exists` mandate setup carries at Phase 2.5.2 (assets) and Phase 2.5.3a (templates), not an assumption that a prior phase made them. Each `Ensure … exists` step below is `mkdir -p` semantics: create only if missing, never fail or overwrite if present.

The teacher can:

1. **Re-run auto-detection** — provide a new or updated website URL. Follow the same auto-detection flow as setup Phase 2.5.2–2.5.3 (**Ensure `<WORKSPACE_ROOT>/data/assets/` exists** before the logo is acquired, exactly as setup Phase 2.5.2 step 4 does). Updates both `website` and `branding`.
2. **Change individual colors** — teacher specifies which color field and the new hex value. If `primary_color` changes, re-derive `secondary_color`, `accent_color` (with WCAG check), and `text_on_primary` (unless teacher explicitly set those too). Also regenerate `school-logo-on-white.png` if the original logo exists and primary changed. Set `confirmed_by_teacher: true`.
3. **Replace logo** — teacher provides a new file path or image. **Ensure `<WORKSPACE_ROOT>/data/assets/` exists** first (`mkdir -p` semantics — on a never-branded workspace it does not yet exist). Auto-crop and generate both color variants using the same process as setup Phase 2.5.2. Store the three files (`school-logo-original.png`, `school-logo-on-primary.png`, `school-logo-on-white.png`) in `<WORKSPACE_ROOT>/data/assets/`. Update `branding.logo_path_on_primary` and `branding.logo_path_on_white`.
4. **Remove logo** — delete all logo files (`school-logo-original.png`, `school-logo-on-primary.png`, `school-logo-on-white.png`) from `<WORKSPACE_ROOT>/data/assets/`. Remove `logo_path_on_primary` and `logo_path_on_white` from branding. Other branding fields remain.
5. **Clear all branding** — set `branding` to `null`. Delete all logo files and branded template from `<WORKSPACE_ROOT>/data/assets/` and `<WORKSPACE_ROOT>/data/templates/materials/` if present.
6. **Add website** — store URL in `website` field without running auto-detection.
7. **Change aspect ratio** — teacher specifies `"16:9"` or `"16:10"`. Update `branding.slide_aspect_ratio`. Triggers template regeneration.

### Slides Template Regeneration

**Trigger:** After any branding change (options 1–4, 7 above), the branded slides template **must** be regenerated. This is not optional — skipping regeneration would leave the template out of sync with the config.

**Steps:**

1. **Manual-change detection:** If `<WORKSPACE_ROOT>/data/templates/materials/template_slides.pptx` exists, compute its SHA-256 hash and compare against `branding.template_hash`. If hashes differ, warn the teacher: *"Your slides template has been modified since it was last generated. Regenerating will overwrite your changes. Continue?"* If the teacher declines, skip regeneration but warn that the template is now out of sync. If hashes match or no template exists, proceed silently.
2. **Regenerate** `<WORKSPACE_ROOT>/data/templates/materials/template_slides.pptx` with the **full current branding config** — all colors, logo variants, and `slide_aspect_ratio`. **Ensure `<WORKSPACE_ROOT>/data/templates/materials/` exists** first (`mkdir -p` semantics — on a never-branded workspace this directory does not yet exist; setup creates it only at Phase 2.5.3a, so this add-later flow must create it itself before writing the deck). Use the **same** generation path as first-run setup: the slide template is authored by the **official PPTX skill** per `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` (preferably via a runtime sub-agent — with the same inline fallback if the sub-agent does not return a usable deck; never a hand-rolled generator). This applies to all change types: color changes rebuild with new colors, aspect ratio changes rebuild with new dimensions, logo changes rebuild with new logo variants. If the official PPTX skill is unreachable in this environment, do not write the file — set `branding.template_hash` to `null`, keep the colors saved, tell the teacher the branded template could not be generated here and the neutral template will be used until it can, and stop the regeneration cleanly (no error).
   **Template-metadata gate:** the regenerated `template_slides.pptx` must carry neutral `docProps` — empty `dc:creator`, `cp:lastModifiedBy`, `dc:title`, `dc:subject`, and `Company`; `Application` = `Thalura` — per the Bundled-Template Metadata Policy in `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` (and ultimately `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md`). The authoring capability's default `Application` must not survive into the stored template.
3. **Update hash:** Compute SHA-256 hash of the new file and update `branding.template_hash`.
4. **Confirm:** Inform teacher what changed. Examples:
   - Color change: *"Slides template updated with new colors."*
   - Aspect ratio change: *"Slides template regenerated with 16:9 dimensions."*
   - Logo change: *"Slides template updated with new logo."*
   - Append: *"Note: slides you've already generated keep their old settings — only new materials will use the updated template."*
   - **Scope of branding — slides only (state this plainly so the teacher is not left wondering about their Word documents).** School branding (colors and logo) currently applies to **slide presentations only**, via the project-level `template_slides.pptx`. Word documents (worksheets, handouts, reading texts, unit plans, assessments) always use the neutral plugin-bundled templates and carry **no** school colors or logo — see the material generator's Template System (`${CLAUDE_PLUGIN_ROOT}/skills/material-gen/SKILL.md`: "Word templates always use the plugin version"). So configuring branding here changes **neither existing nor newly generated Word documents** — they stay neutral by design; only slides (new ones, from the regenerated template) pick up the branding. (The schema reserves `primary_color`→docx-header accent as a *future* capability — `${CLAUDE_PLUGIN_ROOT}/references/schemas/school-config.md`, "Future: document templates".) When the teacher asks whether adding branding will restyle their documents, tell them plainly it affects slides only.

After clearing all branding (option 5):

1. Delete `<WORKSPACE_ROOT>/data/templates/materials/template_slides.pptx` if it exists.
2. Inform teacher: *"Branded slides template removed. New slides will use the neutral default template."*

### Validation

- All hex colors validated as 7-character `#RRGGBB` format
- `logo_path_on_primary` and `logo_path_on_white` must point to files within `<WORKSPACE_ROOT>/`
- `slide_aspect_ratio` must be `"16:9"` or `"16:10"`
- After any change, set `confirmed_by_teacher: true`
- Write updated `school-config.json`
- Confirm changes in chat: show the updated palette summary

### Non-Branding Fields

The teacher can also edit the school's non-branding fields (e.g., "change the school name", "add a double period with a break", "I'm at a Stadtteilschule now"). These live in the same `<WORKSPACE_ROOT>/data/profiles/school-config.json`. Schema: `${CLAUDE_PLUGIN_ROOT}/references/schemas/school-config.md`. Read the teacher profile first and use its `conversation_language` for all prose; field labels resolve via `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `{conversation_language}.profile_fields` (e.g. `school_name` → Schulname, `federal_state` → Bundesland, `school_type` → Schulform, `lesson_slots` → Unterrichtszeiten). Keep all JSON keys and stored values as written in the schema. **Confirm before every write.**

#### School Name

Free-text edit of `school_name`. Must be a non-empty string (it is the authoritative source — the teacher profile holds only `school_id`).

#### Lesson Slots (Unterrichtszeiten)

Add, edit, or remove a lesson slot (Stundenraster), with the full segment-schema validation:

- Each slot has a non-empty `segments[]` (at least 1 segment); each segment is `{type ∈ {"lesson","break"}, minutes: positive integer}`.
- A slot **cannot start or end with a `break`** segment.
- Slot `id` is an English identifier and must be **unique** across the slots.
- **Custom** (teacher-added) slots carry a `label` for display, set in the teacher's language at creation time. Pre-configured slots (`single`, `double`) resolve their display name via `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `{conversation_language}.lesson_slots.{id}` instead of a stored label.
- Enforce the **floor: at least one slot must remain** — refuse a removal that would empty `lesson_slots`.
- On add or edit, surface the Derived Values back to the teacher for confirmation: teaching time = sum of `lesson` minutes, wall-clock time = sum of all segment minutes, and the break count = number of `break` segments (e.g. a 45/break5/45 slot shows teaching = 90, wall-clock = 95, breaks = 1).

#### Federal State (Bundesland) / School Type (Schulform)

`federal_state` and `school_type` are validated against the list compiled at runtime from `${CLAUDE_PLUGIN_ROOT}/references/education-system.json` — the valid `federal_state` values are exactly `federal_states[].id`, and the valid `school_type` values for a chosen state are exactly that state's `school_types[].id`. This is the same compiled list that backs setup selection, so both surfaces always agree on what is offered (today: Hamburg, with Gymnasium and Stadtteilschule).

Changing either field is **not** a standalone write — `school_id` embeds the lowercased `{federal_state}-{school_type}` prefix, and the schema requires `federal_state`/`school_type` to match the components embedded in `school_id`. So on every accepted change, run this clean re-derivation:

1. **Validate** the new value against the compiled list (`federal_state` ∈ `federal_states[].id`; `school_type` ∈ the chosen state's `school_types[].id`). On an invalid value, list the valid options for the chosen state — enumerated from `education-system.json` — and stop with no write.
2. **Re-derive `school_id`** by the setup formula: lowercase the new state and type for the prefix, **keep the existing slug**, and **preserve the existing short UID** so the human-readable identity stays stable (e.g. `hamburg-gymnasium-musterstadt-a3f7` → `hamburg-stadtteilschule-musterstadt-a3f7`).
3. **Write both files together, or neither.** Update `school-config.json` **and** the `school_id` reference in `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json` in the same operation — all-or-nothing — so the cross-file reference is never left dangling. If either write cannot complete, leave both files unchanged.
4. **Grade/semester boundaries and the school-year start follow automatically.** They are not stored in `school-config.json` — they are read live from `education-system.json` on the new `{federal_state, school_type}` pair at session startup. So they re-resolve on their own with no extra write.
5. **Regulation-coverage warning (before write).** Regulations are bundled per state under `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/…`, and the bundled corpus is currently Hamburg only. If the chosen state has no bundled regulations, warn the teacher plainly that regulatory grounding will be unavailable for that state until its regulations ship, and require explicit confirmation before proceeding. Keep this warning generalized ("a state without bundled regulations") so it still holds when further states are added. This mirrors the same warning shown at setup.

## `/thalura:config preferences` — Slide Accessibility Settings

When the teacher asks to edit slide settings (e.g., "change slide font", "turn off accessibility mode", "adjust slide font size"), manage the `slide_preferences` section in `teacher-preferences.json`.

> **Note:** The `internal_compliance_check` toggle has moved to `/thalura:config behaviour`. If the teacher asks to turn the compliance check on or off under `preferences`, redirect them there.

### Current State Display

Read `<WORKSPACE_ROOT>/data/profiles/teacher-preferences.json`. Present current slide settings: show the active defaults (Verdana, 20pt body, 1.3x spacing, bold-only emphasis, max 6 bullets) and note which fields have explicit overrides.

### Editing Options

The teacher can:

1. **Toggle accessibility mode** — `accessibility_mode: true/false`. Toggling off does not clear individual overrides.
2. **Override individual fields** — set `font`, `body_font_size`, `title_font_size`, `line_spacing`, or `max_bullets_per_slide`. Individual overrides always take precedence over both accessibility mode defaults and template-spec defaults.
3. **Reset individual fields** — set back to `null` to use the cascade default (accessibility mode default if enabled, otherwise template-spec default).
4. **Reset all slide preferences** — restore the section to defaults (`accessibility_mode: true`, all others `null`).

After any change, write the updated `teacher-preferences.json` and confirm in chat.

### Validated Preferences (Layer 2)

The teacher can also review and manage their validated preferences (e.g., "remove fishbowl from my liked methods", "I don't have a structure preference any more"). These live in the same `<WORKSPACE_ROOT>/data/profiles/teacher-preferences.json`, alongside the slide settings above. Schema: `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-preferences.md`. Read the teacher profile first and use its `conversation_language` for all prose. Method, social-form, and phase slugs stay English keys; display localized names only where a localization entry already exists. **Confirm before every write.**

#### View

Present the populated Layer 2 sections: `method_preferences` (`liked`, `rejected`, `notes`), `social_form_tendencies`, `lesson_structure_style`, `material_preferences`, `language_level_calibration`, `assessment_style`, `formatting_preferences`, `operator_usage`, `image_preferences`. Show empty sections as "no preference set".

#### Remove / Modify

The teacher can:

1. **Remove a liked or rejected method** — drop the slug from `method_preferences.liked` / `rejected` and delete its entry in `method_preferences.notes` if present.
2. **Clear a per-phase social-form tendency** — remove a phase key from `social_form_tendencies`.
3. **Reset a field to "no preference"** — set a `lesson_structure_style` / `material_preferences` / `assessment_style` / `formatting_preferences` / `operator_usage` field back to `null`.

#### Validation

Honor the schema's validation rules:

- `method_preferences.liked` and `method_preferences.rejected` must not share a slug (their intersection is empty).
- `social_form_tendencies` keys must be valid phase names: `einstieg`, `erarbeitung`, `sicherung`, `vertiefung`.
- `language_level_calibration` keys must match a subject ID in `${CLAUDE_PLUGIN_ROOT}/references/subjects.json`.

On any write, update `last_updated` to the current ISO-8601 timestamp, then write `teacher-preferences.json` and confirm in chat. Keep this management distinct from the slide-settings sub-section above — both coexist under the one `config preferences` heading.

## `/thalura:config profile` — Teacher Profile Editing

When the teacher asks to edit their profile (e.g., "change my name", "update my abbreviation", "add a subject", "I no longer teach Religion", "adjust the language for my materials"), follow this workflow. It edits `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json` — a project-only file that holds the teacher's identity, subjects, and per-subject language settings. School attributes (school name, federal state, school type, lesson slots, branding) live in `school-config.json` and are edited via `/thalura:config school`, not here.

> **Note:** The `generate_student_slides` toggle (student task deck on/off) has moved to `/thalura:config behaviour`. If the teacher asks to enable or disable the student task deck under `profile`, redirect them there.

### Current State Display

Read `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json`. Use its `conversation_language` for all prose. Present:

- `name`, `teacher_abbreviation`, and `email` (show `email` as "not set" when `null`).
- The current `subjects[]`, with display names resolved via `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `{conversation_language}.subjects.{id}`.
- For each language subject (one with a non-null `target_language`), its `content_language` table — one row per material type (worksheets, handouts, slides, assessments, unit plan tasks, assessment rubric (Erwartungshorizont)) and its language.

### Editing Options

The teacher can change:

1. **Name** — `name`.
2. **Abbreviation** — `teacher_abbreviation`.
3. **Email** — `email`; allow clearing to `null`.
4. **Subjects** — **add** and/or **remove** a subject (see the subject add/remove flow below — this is the load-bearing part a bare field edit cannot do safely).
5. **Per-subject content language** — adjust individual `content_language` fields for a language subject (e.g. switch worksheets back to German). This is the per-subject language editing the teacher profile owns; there is no separate `language` sub-command.
6. **Gendering (Gendern)** — edit `gendering.student_docs` and `gendering.teacher_docs`, the gender-inclusive language (geschlechtergerechte Sprache) preference for generated German documents (see the Gendering edit flow below). This is the **only** surface that shows the option tables — onboarding seeds the defaults silently and offers no choice.

After any change: validate (see Validation below), write `teacher-profile.json`, and confirm in chat — mirroring `school`/`preferences`.

### Subject Add/Remove Flow

**Adding a subject:**

- Offer the addable subjects = entries in `${CLAUDE_PLUGIN_ROOT}/references/subjects.json` that are **not** already in `subjects[]`. Resolve each display name via `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `{conversation_language}.subjects.{id}`. If every subject is already present, tell the teacher there is nothing to add.
- **Re-run the per-subject language derivation** that setup Phase 4.2/4.3 performs — do not skip it on a profile-side add:
  - **Language subject** (a subject with a non-null `target_language`, currently `english`): set `target_language` to the target language and auto-populate the `content_language` object — `worksheets`, `handouts`, `slides`, `assessments`, `unit_plan_tasks` = the target language; `assessment_rubric` = `"de"` (always German — Hamburg BSB convention). Then present the same confirmation table as setup Phase 4.3 (every material type and its language, flagging the assessment rubric (Erwartungshorizont) deviation) and let the teacher adjust before writing.
  - **Non-language subject** (philosophy, psychology, religion): `target_language: null`, no `content_language` object — all output follows `content_language_default`. No confirmation needed.
- **Scaffold the newly-added subject's folders** (mirror setup Phase 5.2 / 4.5; create only if missing, never overwrite):
  - the localized output folder `<WORKSPACE_ROOT>/{localized_subject_name}/{school_year}/` (name resolved from `localization.json`);
  - the school-internal curriculum (Schulinternes Curriculum) folder `<WORKSPACE_ROOT>/data/regulations/sic/{subject_id}/`;
  - the library skeleton `<WORKSPACE_ROOT>/data/library/{subject_id}.json` with contents `{ "subject": "{id}", "units": [] }`.
- **State that re-scoping is automatic, not a write.** Tell the teacher their newly-added subject's methods and regulations will now load automatically — Thalura reads them from the profile's `subjects[]` on the next request. Do **not** attempt any overlay or regulation write.
- **Optional regulation-presence note (informational only).** As setup does, you may note whether the new subject's bundled regulation PDFs are present, but **never block** on it — missing PDFs are a warning only.

**Removing a subject:**

- Require **explicit confirmation naming the subject** before removing it (e.g. "Remove Religion from your profile? This cannot be undone automatically.").
- Enforce the floor: **at least one subject must remain** — refuse a removal that would empty `subjects[]`.
- Remove the entry from `subjects[]` and write the profile. Re-scoping is again automatic — the subject's overlays and regulations simply stop loading on the next request.
- **Be explicit and non-destructive about the removed subject's data.** The teacher's generated output under `<WORKSPACE_ROOT>/{localized_subject_name}/…`, the school-internal curriculum (Schulinternes Curriculum) folder, and the library skeleton are the teacher's own work and are **NOT deleted**. Tell the teacher plainly: removing the subject stops Thalura from loading its overlays and regulations and from offering it in new planning, but **their existing files stay on disk**, and the subject can be re-added later (re-adding reuses the existing folders via the only-if-missing scaffolding above). Do **not** auto-delete subject output.

### Gendering edit flow

When the teacher picks the **Gendering (Gendern)** option, **before they choose**, build and render two worked-example tables so they see every option's effect. Resolve **all** cells — both chrome and example forms — from `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `{conversation_language}.gendering`. Do not inline any literal label or example form; read every cell by key.

Build the **`student_docs` table** with one row per value, in this order — `neutral` (the default), `paired`, `colon`, `star` — and the **`teacher_docs` table** with one row per value — `abbreviation` (the default), `full`. For each row, resolve the cells from `{conversation_language}.gendering`:

- **Column headers** from `column_headers` (`option`, `example`, `official_status`, `accessibility`).
- **Option label** from `student_docs_option_names.{value}` / `teacher_docs_option_names.{value}`. Mark the default row as the default in the teacher's `conversation_language`.
- **Example form** from `student_docs_examples.{value}` / `teacher_docs_examples.{value}` — shown **as-is** (these are the German document forms the teacher picks among; invariant across `conversation_language`).
- **Official status** from `official_status_flags.{within|outside}` — `neutral` and `paired` are `within`; `colon` and `star` are `outside`.
- **Accessibility** from `accessibility_notes.*` — `neutral` ⇒ `most_accessible`, `paired` ⇒ `fully_accessible`, `colon` ⇒ `weaker_colon`, `star` ⇒ `star_preferred` (the DBSV `*`-over-`:` note, surfaced at choice time).

The official-status and accessibility flags are cite-free teacher phrasing — no Hamburg/BSB citations in the table. After the teacher picks a value for either register, write `gendering.student_docs` / `gendering.teacher_docs` and confirm in chat.

### Validation

- `subjects[].id` must match a key in `${CLAUDE_PLUGIN_ROOT}/references/subjects.json`.
- All `content_language` values must be `"de"` or `"en"`.
- `subjects` must keep **at least one** entry.
- `gendering.student_docs` must be one of `{neutral, paired, colon, star}`; `gendering.teacher_docs` must be one of `{abbreviation, full}`. Reject any out-of-set value.
- After any change, write `teacher-profile.json` and confirm the change in chat.

## `/thalura:config naming` — Naming Conventions Editing

When the teacher asks to edit how files are named (e.g., "change the naming pattern for unit plans", "reset the worksheet naming", "rename my documents differently"), follow this workflow. It edits the teacher-override naming patterns (Benennung) in `<WORKSPACE_ROOT>/data/config/naming-conventions.json`. Read the teacher profile first and use its `conversation_language` for all prose.

### Two-Tier Read

Naming patterns follow the two-tier config system (see `${CLAUDE_PLUGIN_ROOT}/references/config-system.md`):

1. **Plugin default:** `${CLAUDE_PLUGIN_ROOT}/config-defaults/naming-conventions.json` — the immutable baseline.
2. **Teacher override:** `<WORKSPACE_ROOT>/data/config/naming-conventions.json` — created on first edit if absent.

The **effective** pattern for each key is the teacher override if present, otherwise the plugin default. The allowed variables for each pattern are documented in `${CLAUDE_PLUGIN_ROOT}/references/naming-conventions.md`.

### Current State Display

Read both files and merge them. For each `documents.*` key and `identifiers.image_id`, present the effective pattern and flag whether it is a **teacher override** or the **plugin default**. Resolve the document type's display name via `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `{conversation_language}.document_types` / `{conversation_language}.naming_labels` (not the raw English key — e.g. show "Einheitenplanung", not `unit_plan`). For a `documents.*` key with no entry in either map, show a readable paraphrase or the key itself rather than failing. All surrounding prose renders in `conversation_language`.

### Editing Options

The teacher can:

1. **Override one document pattern** — set a new pattern string for a single `documents.*` key (or `identifiers.image_id`). Validate before accepting (see Validation).
2. **Reset one pattern to default** — delete that key from the override file so the merge falls back to the plugin default.
3. **Reset all naming patterns** — remove the override file's `documents` and `identifiers` content so every pattern falls back to the plugin default.

### Pattern Strings Only — Not Label Values

This editor edits the **pattern strings** in `naming-conventions.json` only. It does **not** edit the `naming_labels` display values (`Einheitenplanung`/`UnitPlan`, `Verlaufsplan`/`LessonPlan`, …) — those are shipped in `localization.json`, are localized per `conversation_language`, and are not teacher-editable. A teacher who wants different label text embeds the literal text directly in the pattern string instead (e.g. replacing `{unit_plan_label}` with `Plan` in the pattern). The shipped `naming_labels` values stay untouched.

### Validation

A teacher-supplied pattern must satisfy all of these before it is written:

- **Allowed variables only.** Every `{…}` token in the pattern must come from the documented allowlist for that document type — the Context Variables and Label Variables tables in `${CLAUDE_PLUGIN_ROOT}/references/naming-conventions.md` (e.g. `{subject_abbr}`, `{grade}`, `{unit_title}`, `{lesson}`, `{seq}`, `{format}`, `{material_title}`, `{unit_plan_label}`, `{lesson_plan_label}`, `{assessment_student_label}`, `{assessment_rubric_label}`, `{reflection_label}`, `{materials_overview_label}`). Literal text between tokens is allowed.
- **Reject unknown tokens.** Any `{…}` token outside the allowlist is rejected with a message listing the allowed variables for that document type.
- **No path separators.** Reject patterns containing `/` or `\` — naming patterns produce a single filename segment, not a path.
- **No draft-suffix tokens.** The draft suffix (`_ENTWURF` / `_DRAFT`) is system-managed (see `naming-conventions.md`) — reject any attempt to embed it as a token.
- **Keys stay English.** Only pattern values change; the JSON keys (`unit_plan`, `lesson_plan`, …) are never renamed.

### Write

Write the override to `<WORKSPACE_ROOT>/data/config/naming-conventions.json` (create the file if absent). **Confirm before writing** — show the teacher the before/after effective pattern and a resolved-filename example, ask for confirmation, then write and confirm in chat.

## `/thalura:config behaviour` — Behaviour Toggles

When the teacher asks to change a behaviour toggle (e.g., "turn off the automatic compliance check", "disable the student task deck", "stop generating PDFs automatically", "set PDF to all"), follow this workflow. It edits the behaviour toggles in `<WORKSPACE_ROOT>/data/config/behaviour.json`. Read the teacher profile first and use its `conversation_language` for all prose.

### Two-Tier Read

Behaviour toggles follow the two-tier config system (see `${CLAUDE_PLUGIN_ROOT}/references/config-system.md`):

1. **Plugin default:** `${CLAUDE_PLUGIN_ROOT}/config-defaults/behaviour.json` — the immutable baseline.
2. **Teacher override:** `<WORKSPACE_ROOT>/data/config/behaviour.json` — created on first edit if absent (setup copies it from the plugin default, but the copy-if-missing may not have run yet on older setups).

The **effective** value for each key is the teacher override if the key is present, otherwise the plugin default. For the full schema and merge table see `${CLAUDE_PLUGIN_ROOT}/references/schemas/behaviour.md`.

### Current State Display

Read both files and merge them per the two-tier rule. Present the three effective toggle values in the teacher's `conversation_language`, flagging each as **teacher override** or **plugin default**:

- **Automatic compliance check** (`internal_compliance_check`): on / off (default: on). Controls whether the Sacred Texts (Heilige Texte) quick-check runs automatically before writing a draft.
- **Automatic PDF on validation** (`pdf_on_validation`): `student_facing` / `all` / `off` (default: `student_facing`). Controls which validated materials automatically receive a PDF.
- **Per-lesson student task deck** (`generate_student_slides`): on / off (default: on; absent or `null` ≡ on). Controls whether the student task deck (Aufgabenfolien) is proposed during lesson drafting and generated after validation.

### Editing Options

The teacher can:

1. **Toggle the automatic compliance check** — set `internal_compliance_check` to `true` (on) or `false` (off).
2. **Set the automatic PDF mode** — set `pdf_on_validation` to one of `student_facing` / `all` / `off`.
3. **Toggle the student task deck** — set `generate_student_slides` to `true` (on) or `false` (off). Setting it `false` stops both the lesson-draft proposal and the after-validation generation; `true` re-enables both. The deck's slide-accessibility settings are independent and edited under `/thalura:config preferences`.
4. **Reset a toggle to the plugin default** — remove the key from the teacher override file so the merge falls back to the plugin default.

### Validation

- `internal_compliance_check` must be a `boolean` (`true` or `false`).
- `generate_student_slides` must be a `boolean` or `null`; absent / `null` is equivalent to `true`.
- `pdf_on_validation` must be one of `"student_facing"`, `"all"`, `"off"`. Reject any out-of-set value.

Reject out-of-set values and explain the valid options in `conversation_language`.

### Write

Write changes to `<WORKSPACE_ROOT>/data/config/behaviour.json` **only** (create if absent, seeding from `${CLAUDE_PLUGIN_ROOT}/config-defaults/behaviour.json` if needed — never touch `config-defaults/`). **Confirm before writing** — show the teacher the current and new effective value and ask for confirmation, then write and confirm in chat.

## `/thalura:config supplies` — Standard Supplies (Standardmaterial)

When the teacher asks to edit their standard supplies (e.g., "add glue sticks to my standard supplies", "I don't have a laminator", "reset my Standardmaterial", "welches Standardmaterial habe ich"), follow this workflow. It edits the teacher's optional list of everyday classroom supplies (Standardmaterial) actually on hand in `<WORKSPACE_ROOT>/data/config/standard-supplies.json`. Read the teacher profile first and use its `conversation_language` for all prose.

The standard-supplies list is a **soft hint** that gently biases lesson-proposal standard-supplies content toward what the teacher actually has — it never hard-restricts proposals, never flags an item as unavailable, and never blocks planning. Editing it here only changes the list; it never changes how existing documents were generated.

### Two-Tier Read

Standard supplies (Standardmaterial) follow the two-tier config system (see `${CLAUDE_PLUGIN_ROOT}/references/config-system.md`):

1. **Plugin default:** `${CLAUDE_PLUGIN_ROOT}/config-defaults/standard-supplies.json` — the immutable baseline (a sensible everyday set).
2. **Teacher override:** `<WORKSPACE_ROOT>/data/config/standard-supplies.json` — created on first edit if absent.

The **effective** list is the teacher override's `standard_supplies` value **if the key is present, else the plugin default** — a whole-value replacement at the `standard_supplies` key, never an element-wise merge (for the shape and the empty/absent/unreadable semantics see `${CLAUDE_PLUGIN_ROOT}/references/schemas/standard-supplies.md`).

### Current State Display

Read both files and resolve the effective list per the two-tier rule. Present the effective standard-supplies list (Standardmaterial), flagging whether it comes from a **teacher override** or the **plugin default** (same presentation contract as the `naming` editor). All prose renders in `conversation_language`; the setting is named "standard supplies (Standardmaterial)" / „Standardmaterial".

### Editing Options

The teacher can (all free text):

1. **Add items** — append one or more supply strings to the effective list.
2. **Remove items** — drop one or more items from the list.
3. **Replace the whole list** — set a new list outright.
4. **Reset** — remove the override key/file so the plugin default applies again.

### Validation

Light validation only — free text is the contract, no vocabulary policing:

- Items are **non-empty strings**.
- **Reject control characters.**
- **Deduplicate exact duplicates** on write.
- **No path-separator ban** — supply strings are never used as paths, so `/` and `\` are legitimate input (e.g. `A4/A3-Papier`, `Kreide (weiß/farbig)`); do not reject them.

### Write

Write the override to `<WORKSPACE_ROOT>/data/config/standard-supplies.json` (create the file if absent; never touch `config-defaults/`). **Confirm before writing** — show the teacher the before/after effective list, ask for confirmation, then write and confirm in chat (mirroring the `naming` editor's confirm-before-write rule).

---

## Reference Files

| File | Used in | Purpose |
|------|---------|---------|
| `skills/core/SKILL.md` | Throughout | Core protocols and config system |
| `${CLAUDE_PLUGIN_ROOT}/references/config-system.md` | Step 3 | Two-tier merge rules |
| `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-profile.md` | Profile editing | Teacher profile schema (incl. the `gendering` object) |
| `${CLAUDE_PLUGIN_ROOT}/references/localization.json` | Profile editing (gendering tables) | Localized gendering option names, column headers, status/accessibility flags, and the German example forms |
| `${CLAUDE_PLUGIN_ROOT}/references/schemas/school-config.md` | School editing | School config schema |
| `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-preferences.md` | Preferences editing | Preferences schema |
| `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-observations.md` | Preferences editing | Observations schema |
| `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` | Branding editing | Slides template spec for regeneration |
| `${CLAUDE_PLUGIN_ROOT}/config-defaults/naming-conventions.json` | Naming editing | Default naming patterns — read as the merge baseline by `config naming` |
| `${CLAUDE_PLUGIN_ROOT}/references/naming-conventions.md` | Naming editing | Allowed pattern variables (Context + Label) |
| `${CLAUDE_PLUGIN_ROOT}/references/schemas/behaviour.md` | Behaviour editing | Behaviour-toggle schema — three toggles, two-tier merge table, validation rules |
