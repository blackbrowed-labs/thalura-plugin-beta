---
name: material-gen
description: Material erstellen. Use when the teacher wants to create teaching materials (Materialien) — worksheets (Arbeitsblätter), slides (Folien), handouts, reading texts.
when_to_use: |
  DE + EN: "Arbeitsblatt", "Material erstellen", "Folien/Präsentation", "Handout", "Lesetext", "worksheet", "slides", "handout", "reading text". Images embedded in a material are handled HERE (not image-prompts).
---

# The Playbook (`generate_assets`) — Asset Creation

> Core protocols — startup, HiTL/draft lifecycle, preferences, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).
>
> Before writing the `_{draft_suffix}` to disk (Step 4), the internal compliance gate runs a Sacred Texts quick-check. Load `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` for the full 8-step flow at the draft/validation step.

Creates teaching materials derived from the lesson plan: worksheets, slides, handouts, reading texts.

---

## Required Inputs

| Parameter | Type | Required | Example |
|-----------|------|----------|---------|
| `lesson_file` | Path | yes | Lesson file from `{lessons}/` in the unit folder |
| `asset_type` | Enum | yes | "worksheet" / "slides" / "reading_text" / "handout" / "student_task_deck" |
| `target_phase` | String | no | "Main Phase" |
| `differentiation` | Enum | no | "standard" / "scaffold" / "extension" |
| `format` | Enum | no | "docx" (default) / "pptx" / "pdf" |

---

## Logic (Step by Step)

**Student task deck — precondition and trigger (`asset_type: "student_task_deck"`).** This type is the per-lesson student task deck (a projection-ready slide deck of the lesson's student tasks). It is **gated by the behaviour toggle**: read `generate_student_slides` from the two-tier behaviour config (`<WORKSPACE_ROOT>/data/config/behaviour.json` teacher override overlaid on `${CLAUDE_PLUGIN_ROOT}/config-defaults/behaviour.json` plugin default); if the effective value is `false`, do not generate it (absent / `null` ≡ the default `true`). It is generated **on demand after the lesson is validated** — never before: read `plan.json` and confirm the `linked_to` lesson's `status` is `"validated"` (this mirrors the hard block in The Upside Down, which requires a validated unit before detailing a lesson). Generation is triggered by the teacher or offered after validation, and the deck content follows the slide-by-slide proposal already reviewed during the lesson draft (Phase A). When generating this type, follow the deck-specific notes called out in the steps below.

1. **Read the lesson file** from `{lessons}/`:
   - Extract the relevant phase(s) and context
   - Present the derived context to the teacher — confirm before proceeding

2. **Determine language** via the content language fallback chain (core skill satellite `${CLAUDE_PLUGIN_ROOT}/skills/core/content-language-gendering.md`, *Content Language Resolution*):
   - Resolve content language for this subject and asset type
   - Apply the resolved language to the asset content

3. **Match level and complexity to grade:**
   - For Sek I: simpler language, more scaffolding, visual elements
   - For Sek II gA: intermediate level
   - For Sek II eA: advanced level, higher cognitive demands

4. **Use operators in task formulations** where age-appropriate:
   - Every task/question should begin with an operator where didactically appropriate
   - For Sek I: introduce propedeutically (simpler operators first)
   - For Sek II: full operator range per ARL
   - Operators must match the intended AB level of the task

5. **Cross-topic knowledge check:**
   - If the material references concepts outside the students' expected knowledge base, add scaffolding
   - Format: "Infobox: [concept] — [brief explanation]" in a visually distinct box

6. **Differentiation** (if requested or if class definition indicates needs):
   - **scaffold:** Simplified language, sentence starters, vocabulary aids, visual supports, larger font (LRS)
   - **extension:** Additional challenges, deeper questions, open-ended tasks (HB)
   - **standard:** Default level for the grade
   - Reference `${CLAUDE_PLUGIN_ROOT}/references/special-needs-catalog.md` for detailed measures per need type
   - For full differentiated variants: suggest The Multiverse

7. **Assign material number** — unit-scoped sequential: M01, M02, M03... Read the current highest number from `plan.json` and increment.
   - **`student_task_deck` exception:** do **not** assign an `M{seq}`. The deck is auto/triggered and lesson-scoped, so it stays out of the material-number sequence. Its `materials[]` id is `student_task_deck-L{n}` (the lesson it is `linked_to`); exactly one deck per lesson.
   - **Touchpoint sweep (on this `plan.json` read).** When you open the unit manifest here, check the generated documents you are about to rely on: a generated-document entry with a **missing or failing `gates` record** (`${CLAUDE_PLUGIN_ROOT}/references/schemas/unit-manifest.md` → **`gates` Object**), or a year overview whose freshness marker `rendered_rev` trails the plan's `content_rev`, is a **detected deviation** — run the output-gate verifier (Ausgabe-Prüfung) on the existing artifact now to backfill the record (escalate-or-flag per gate; the shipped verifier is the reference mechanism, and any equivalent evidence-producing method conforms), regenerate a stale year overview through the Output-Gate Runner, and **note the repair in chat**. Never silently proceed over a hole. The sweep is **touchpoint-local** — only the unit you are reading — and it repairs **records and derivatives, never content**. *(Honesty note: the sweep never re-opens an artifact whose record already reads as passing — in-product detection of a fabricated passing record is nil; that is a probe-time concern only.)*

8. **Apply naming conventions** from `naming-conventions.json` (two-tier merge):
   - Pattern: `M{number}-{Type}-{Topic}.docx`
   - Example: `M01-Worksheet-Metaphors.docx`
   - **`student_task_deck`:** use the `student_task_deck` document pattern (not the `M{seq}` material pattern) → e.g. resolves to `{subject_abbr}{grade} - {unit_title} - {lesson_plan_label} {lesson} - {student_task_deck_label}.pptx`. The `{student_task_deck_label}` resolves at runtime from `localization.json` → `naming_labels.student_task_deck` to `conversation_language` (no language token is hard-coded here). The `_{draft_suffix}` is appended by the standard draft lifecycle as for every document.

9. **Output format:**
   - Default: .docx for worksheets/handouts/reading texts, .pptx for slides
   - PDF export available on request
   - Check `templates/` in the workspace for a matching template (see Template System below)
   - **For slides:** apply slide preferences from `teacher-preferences.json` → `slide_preferences` using the cascade: explicit teacher field → accessibility mode defaults (if `accessibility_mode: true`) → template-spec defaults. See `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` → "Slide Content Accessibility" section for the full rule set.
   - **For `student_task_deck`:** a `.pptx` like `slides`. Lay the content out **projection-first** per the "Student Task Deck layout" section of `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` — CONTENT master, **one slide per work phase / coherent task-set** (coupled steps together, **not** one task per slide), operator-led instructions where didactically applicable (Step 4 operator convention), social form + timing as a footer line. Resolve language as for `slides` (the deck is student-facing). Apply the same `slide_preferences` cascade verbatim (it is a slide artifact). Resolve the branded template via the existing two-tier `template_slides.pptx` resolution (see Template System).

10. **Page limit check:**
    - Read the **Pages** column from the material table in the lesson file.
    - If a value is present: use it as the page limit — do **not** ask the teacher.
    - If the field is empty or missing: ask the teacher for the desired page count.
    - Apply the page limit during content generation.

11. **Create the proposal** and present to the teacher in chat

---

## Proposal Format

Present the proposed content structure in the configured conversation language before generating the actual file:

```
Material: {asset_type} for lesson {lesson_number}, phase: {target_phase}
Material no.: M{number}
Language: {language}
Differentiation: {differentiation_level}

Content:
1. [section/task description with operators]
2. [section/task description with operators]
3. ...

Operators used: [list operators and their AB level]
Curriculum reference: [specific competency references]

━━━ {image_section_header} ━━━
[Only include this section if images/infographics would enhance the material]

IMG-01: [description of what the image shows]
  Position:  after task [n] / top of page / ...
  Style:     [Style Catalog entry, e.g., "Children's book illustration"]
  Size:      full width / half width
  Ratio:     [aspect ratio, e.g., 3:4 (portrait)]
  Model:     Nano Banana 2 (Fast) — [rationale]

IMG-02: [description]
  Position:  ...
  Style:     ...
  Size:      ...
  Ratio:     ...
  Model:     ...
```

The `{image_section_header}` resolves via `localization.json` → `image_labels.image_section_header`.

**Image-generation gate (proposal wording).** Evaluate once, cheaply, at proposal time against `${CLAUDE_PLUGIN_ROOT}/references/image-generation-contract.md`: is a conforming image-generation tool (Bildgenerierungs-Werkzeug) available **and** does that contract reference declare `embed_capability: present`? (Both conditions are defined in the contract file's availability gate and Capabilities block — do not restate the gate rules here.)
- **Both true (tool-present wording):** replace each per-image `Model:` line with the localized `auto_generated_marker` label (`localization.json` → `image_labels`), and place one sentence using `auto_generation_notice` above the image list. Approval of the proposal **is** the generation consent (one approval gate — no second confirmation, no per-image cost prompt).
- **Otherwise (no conforming tool, or the capability reads `absent`):** the proposal format below is byte-for-byte today's, including the hard-coded `Model:` line.

**Image proposal rules:**
- Only propose images when they add genuine pedagogical value (illustration, stimulus, infographic) — not for decoration
- Claude selects model, style, and aspect ratio based on Eleven's Vision guidelines (see `skills/image-prompts/SKILL.md`)
- Print optimization is applied automatically when `material_preferences.copier_safe` is `true`
- The teacher can remove, modify, or add images during the feedback phase (Steps 1-3 of HiTL)
- One approval gate covers both content and images

The proposal is output in `conversation_language`. The template above shows the English structure; localized labels are resolved via `localization.json`.

---

## After Approval (Steps 4-8 of the HiTL Flow)

1. **Internal compliance gate** (Step 4): Sacred Texts quick-check on the generated content.

2. **Generate the material file** (Step 5):
   - Write `M{number}-{Type}-{Topic}_{draft_suffix}.docx` in `{materials}/`
   - If a template exists for this asset_type, apply it (see Template System below)
   - Run the Output-Gate Runner (`${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` Step 5) on the written output; do not present until its gate-outcome report is produced.
   - **Out-of-band option** (see `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` → *Out-of-band execution*). This template-fill-and-write MAY run out-of-band. The delegate receives, as literal values and model-resolved absolute paths: the approved content (**semantic layer only** — no layout values); the **already-resolved** template path (the template-lookup gate runs main-session so its verify-then-escalate loop stays observable — the delegate receives the resolved path, not the lookup); the resolved output path and naming values; the content-language result; and the Step-4 **`compliance_quickcheck`** outcome resolved main-session before dispatch (`ran (N findings)` / `skipped (internal_compliance_check=false)`). It reads `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` + `${CLAUDE_PLUGIN_ROOT}/references/design-tokens.json` in its own context, fills the template, writes the draft, runs the Output-Gate Runner, and returns the written path plus the per-gate outcome lines — **echoing `compliance_quickcheck` verbatim** as the Step-4 compliance line (it relays, never re-runs, that check). A missing or unusable return is failed verification: run this step inline. The compliance quick-check (step 1 above) stays main-session and ahead of this write.

3. **Generate or place images** (if images were approved):
   These per-approved-image generations are independent — the out-of-band fan-out of `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` → *Out-of-band execution* applies (each delegate receives the approved image description + a pointer to the image-prompt guidelines and returns the full generated prompt text, which the main session embeds and records in `plan.json`; no document is written, so verification is prompt-present-and-complete per approved image). No separate approval cycle is introduced.
   For each approved image in the proposal, first author its prompt (a, shared), then take the tool-present path (3-A) or the placeholder path (3-B):
   a. **Invoke Eleven's Vision** internally (programmatic path — see `skills/image-prompts/SKILL.md`). Eleven's Vision generates the full 10-component English prompt from the approved image description. No separate approval cycle. This authored prompt — stored in `plan.json` (Step 4) as the single source of truth — feeds **both** branches below.

   **Branch selection (per image).** Take the **tool-present path (3-A)** only when a conforming image-generation tool (Bildgenerierungs-Werkzeug) is detected at call time **and** `${CLAUDE_PLUGIN_ROOT}/references/image-generation-contract.md` declares `embed_capability: present` — the same combined predicate as the Step 11 proposal gate. Otherwise take the **placeholder path (3-B)**. Selection is per image: any 3-A failure of any kind drops **that** image to 3-B, siblings unaffected.

   **3-A — tool-present path.**
   - **Re-verify the gate at call time** (`${CLAUDE_PLUGIN_ROOT}/references/image-generation-contract.md` → availability gate). Divergence: the proposal said manual but a conforming tool + a `present` capability now hold → generate anyway and note it in the confirmation; the proposal said automatic but the tool is gone at call time → **all** images take 3-B plus one flag line, never a hard error.
   - **Call the tool per the contract** (`${CLAUDE_PLUGIN_ROOT}/references/image-generation-contract.md`): pass the stored prompt **verbatim from `plan.json`** (never rewritten), the stored aspect ratio as an explicit argument, and the print flag; omit the optional provider/model/size arguments unless config supplies them; pass the reserved reference slot only when supplied. The authoritative argument list lives in the contract file — do not restate it here.
   - **Consume the result per the contract's consumption rules:** write the returned bytes to a session-scoped transient location immediately (never a teacher-visible output folder), verify a non-empty PNG with a readable header and `mime: image/png`, and read the actual dimensions from the PNG header.
   - **Record to the `plan.json` image entry:** `model` = the served model id, plus `provider` and `watermark` from the result metadata. `status` stays `"placeholder"` (the embed's success flips it).
   - **Hand off to the embed seam** (the auto-embed flow): this step ends at a verified PNG on disk plus the recorded metadata; the byte-swap into the document and the model-aware citation are the embed step's concern.
   - **Per-image failure of any kind** — call rejected, error class returned, failed PNG verification, or an embed-seam failure — drops **that** image to **3-B verbatim** plus one localized `generation_failed_fallback` flag line in chat (`image_labels`): never a stack trace, never a raw provider error string, never token or secret material. Sibling images proceed independently; **no plugin-side retry**; the material always completes.

   **3-B — placeholder path.**
   b. **Insert placeholder image** at the specified position in the material file. Use the 1×1px placeholder PNG (`${CLAUDE_PLUGIN_ROOT}/assets/placeholder.png`) scaled to target EMU dimensions. See `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` for full formatting rules:
      - Centered paragraph, inline (not floating), body-text-default spacing
      - Alt-text (`wp:docPr[@descr]`): the image description from the proposal
      - Image name (`wp:docPr[@name]`): `IMG-{nn}` per `naming-conventions.json` → `identifiers.image_id`
      - No `keepNext` on the preceding element (large images would force page breaks)
   c. **Attach two Word comments** per placeholder:
      - Comment 1 (on image paragraph): localized replacement instructions from `image_labels` + metadata line (model, aspect ratio, resolution)
      - Comment 2 (on zero-width space `\u200B` run after image, font 1pt): full English Gemini prompt — ready to copy-paste
      - Author: `Thalura`
   d. **Add APA 7 citation footnote** per placeholder — if `image_preferences.ai_citation_footnote` is `true` (default):
      - Single-paragraph footnote — font and size from `${CLAUDE_PLUGIN_ROOT}/references/design-tokens.json` (`primitive.font.primary`, `primitive.size_word_halfpt.footnote`)
      - Format: `Google. (YYYY). Gemini (Model) [AI-generated image from prompt "first ~50 words..."]. https://gemini.google.com`
      - Footnote reference in body: `primitive.font.primary` at `primitive.size_word_halfpt.body`, superscript (per `${CLAUDE_PLUGIN_ROOT}/references/design-tokens.json`)

   **Confirmation line.** Alongside the material write's Output-Gate Runner gate-outcome report (Step 5 / step 2 above — **not** a new runner gate), emit one localized `generation_summary` line (generated count / placeholder count) plus any `generation_failed_fallback` flag lines from 3-A. The Step 6 `{validation_prompt}` / `{images_pending}` conditionals are unchanged.

4. **Update `plan.json`** manifest:
   - Add the new material entry with `images` array
   - Each image entry: `id`, `description`, `aspect_ratio`, `width`, `style`, `model`, `prompt`, `print_optimized`, `status: "placeholder"`, and — recorded only on the tool-present path (3-A) — the optional `provider` and `watermark` fields. `status` initializes to `"placeholder"` in both branches; the flip to `"replaced"` is the embed's success signal.
   - The `plan.json` image entry is the single source of truth for the prompt — store the full `prompt` (with `width` and `print_optimized`) here for **every** material, whether the output is `.docx` or `.pptx`. The copy embedded in the document (Word comment for `.docx`, slide note for `.pptx`) is a convenience duplicate, never the source.
   - **`student_task_deck`:** add the entry as `{ "id": "student_task_deck-L{n}", "path": "{materials}/… - {student_task_deck_label}_{draft_suffix}.pptx", "type": "student_task_deck", "status": "draft", "linked_to": [n] }` — the id is the English-key form `student_task_deck-L{n}`, **not** an `M{seq}` and **not** the German tag (`plan.json` is all-English; the localized tag lives in the `path` only). One entry per lesson.
   - **Regenerate the material overview ({material_overview})** right after the manifest update — the new material's row appears immediately, showing its current draft filename with the localized draft marker ({draft_marker}); the overview never waits for validation. Each row also emits its editable-file hyperlink (`[DOCX]`/`[PPTX]` per material kind) plus `[PDF]` when a validated `pdf_path` exists, per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Referenced-file hyperlinks* (relative path, verify-exists-then-emit; a draft row links `[DOCX]` only; a planned-only row stays plain text). Because this regeneration writes a document, it runs through the Output-Gate Runner (`${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` Step 5) — metadata + referenced-file-hyperlink gates — and emits its own gate-outcome lines before the regenerated overview is presented or relied on.

5. **Update observations** (continuous): Log acceptances/rejections

6. **Teacher reviews and validates** (Steps 6-8): Standard `_{draft_suffix}` revision cycle. When revising a material the teacher has hand-edited (a replaced image, edited or added content, manual formatting), the existing file is edited in place — the manual edits, the branded header/footer, and the styles are preserved, never rebuilt from the template or from scratch (the revision branch lives in the 8-step flow, Step 7 — see `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md`). Content the `plan.json` manifest and the last generation do not account for — a replaced or re-saved embedded image, inserted or edited text, changed formatting — is **presumed a teacher edit** and is never removed, reverted, or "cleaned up" during a revision unless the teacher's instruction or a Word comment explicitly covers it; if such content obstructs the requested change, ask the teacher — don't decide. On validation:
   - If the material contains placeholder images, ask `{validation_prompt}` (from `image_labels`)
   - If yes → flip all image statuses to `"replaced"` in `plan.json`
   - If no → keep `_{draft_suffix}`, flag `{images_pending}` count in chat, keep `status: "placeholder"` in `plan.json`
   - When previewing a generated artifact to the teacher, present only the deliverable document or its images — never `plan.json` or any other internal JSON under `<WORKSPACE_ROOT>/data/`.
   - **`student_task_deck` — back-propagate a fundamental change to the lesson plan.** The deck runs its own `_{draft_suffix}` → validation cycle, separate from the lesson's. **But** the deck and the lesson's detail plan (Verlaufsplan / Stundenentwurf) must never silently diverge. So when the teacher makes a **fundamental** change during deck validation — a change to *what students are asked to do* (a different task, a changed operator, a re-scoped activity, a different social form or work phase), **not** cosmetic slide wording or layout — flag the divergence and **update the lesson's detail plan** (its Student-Activity / phase content) to match, re-entering the lesson's own `_{draft_suffix}` draft cycle so the change is reviewed (the lesson's `plan.json` status reverts to `"draft"`). Cosmetic deck-only edits (layout, phrasing that doesn't change the task) do **not** back-propagate.

---

## Template System

Templates define the visual structure (header, footer, page layout, typography) of generated assets. The content is generated dynamically by The Playbook.

### Template Location

| asset_type | Template file | Fallback |
|------------|--------------|----------|
| `worksheet` | `template_worksheet.docx` | — |
| `handout` | `template_handout.docx` | `template_worksheet.docx` |
| `reading_text` | `template_reading_text.docx` | `template_worksheet.docx` |
| `slides` | `template_slides.pptx` | clean default (no fallback) |

### Template Resolution Order

For each asset type, check these locations in order (first match wins):

1. **Project templates:** `<WORKSPACE_ROOT>/data/templates/materials/{template_file}` — school-branded versions generated during setup or config changes
2. **Plugin templates:** `${CLAUDE_PLUGIN_ROOT}/templates/materials/{template_file}` — neutral defaults shipped with the plugin

Currently only `template_slides.pptx` uses project-level overrides (generated when branding is configured via `/thalura:setup` Phase 2.5.3a or `/thalura:config school`). Word templates always use the plugin version.

The full template design specification is in `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md`.

### Template-lookup gate

A *verify-exists-before-declaring-fallback* gate hardens the **plugin-default** leg of the resolution order above; the existing order (project override → plugin default) is unchanged. You may not declare "no template" or fall back to library-authoring until (1) the plugin root is **bound** — `${CLAUDE_PLUGIN_ROOT}` is substituted, or the core skill's plugin-root self-discovery (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`, Step 0a) has bound it — **and** (2) you have **listed** `${CLAUDE_PLUGIN_ROOT}/templates/materials/` and confirmed the specific `{template_file}` is genuinely absent there. A "template not found" conclusion is valid only with a directory listing of the discovered plugin-root templates directory as its evidence.

**Escapability clause.** An **empty or erroring** listing at a bound plugin root is a **failed verification, never evidence of absence** — a host-side tool listing a sandboxed or remote plugin tree can return empty though the templates are present. On an empty or erroring listing, **escalate to another access method** — at minimum the mechanism that bound the plugin root in Step 0a (for example the environment's shell on the side where the plugin tree lives) — and re-list with whatever directory-listing capability the environment exposes. Absence is declarable **only** from a listing that demonstrably shows real directory contents (other entries alongside the missing `{template_file}`), **or** from a parent-directory listing proving the templates directory itself is absent.

### Template-fidelity evidence capture

The template-lookup gate above governs a *declaration* on the generation route; the output gate gives that declaration an **output-side record** so the outcome is captured, not merely narrated.

**Listing evidence is recorded.** Whatever the gate concludes is written into the document's `gates` record in `plan.json` (`${CLAUDE_PLUGIN_ROOT}/references/schemas/unit-manifest.md` → **`gates` Object**, the `template` field). A `template` outcome of `absent-evidenced` is valid **only** when it is accompanied by the recorded listing summary — the directory that was listed and the entries that were seen. An **unevidenced "no template" claim is a `flagged` (FAIL) outcome by construction**, never a pass: absence with no listing behind it does not satisfy the gate.

**Two-tier fingerprinting.** Template lineage is checked against a fingerprint (styles, header/footer parts, `Application = Thalura` lineage marker, placeholder inventory), and which fingerprint is used depends on which leg of the two-tier resolution the template came from:

- A **workspace-override** template (`<WORKSPACE_ROOT>/data/templates/…`, e.g. branded slides) sits on the artifact's side of the boundary — it is **fingerprinted live** from the override file itself (its record marks `template: "workspace-override"`).
- The shipped **fingerprint sidecars** (a `.fingerprint.json` file next to each shipped template binary under `${CLAUDE_PLUGIN_ROOT}/templates/` — e.g. `${CLAUDE_PLUGIN_ROOT}/templates/materials/template_worksheet.fingerprint.json`) serve the **plugin-default** leg, where the template binary itself may be unreachable from the artifact's side; the delivered document must carry that template's style/part lineage (its record marks the matched template id).

Filling the resolved template with **any** capability is fully conforming — the fidelity gate has no preferred tool, only the output property that the artifact carry its template's lineage.

### Placeholders

Templates contain placeholder strings in `{{DOUBLE_BRACES}}`:

| Placeholder | Source | Example (German default config) |
|-------------|--------|----------------------------------|
| `{{SUBJECT}}` | Subject name | "Philosophie" |
| `{{COURSE}}` | Grade/course | "S4" |
| `{{TEACHER_ABBR}}` | Teacher abbreviation | "Ws" |
| `{{UNIT_TITLE}}` | Unit title | "Brücken in eine friedliche Zukunft" |
| `{{MATERIAL_NO}}` | Material number | "M04" |
| `{{DIFFERENTIATION}}` | Differentiation label, or empty | "Variante A" or "" |
| `{{MATERIAL_TITLE}}` | Title of this material | "Positiver und negativer Frieden" |

Example values shown for German default config. Placeholders resolve via `localization.json` and teacher profile.

### Design rules (copier-safe)

- No color — all elements in black or grey, using the copier-safe palette in `${CLAUDE_PLUGIN_ROOT}/references/design-tokens.json` (`primitive.color.ink` for black, `primitive.color.rule_min` for the minimum grey that survives copying, `primitive.color.header_fill` for the medium grey table header)
- No alternating row shading — disappears on copiers
- All lines minimum grey per `${CLAUDE_PLUGIN_ROOT}/references/design-tokens.json` (`primitive.color.rule_min`) — lighter greys do not survive copying
- Table header background: `${CLAUDE_PLUGIN_ROOT}/references/design-tokens.json` → `primitive.color.header_fill` (medium grey) — visible after copying
- Writing lines in every student answer area — students need lines to write on

---

## Notes

- Multiple assets can be created for one lesson (e.g., a worksheet + a handout + slides).
- Each asset gets its own sequential material number within the unit.
- For differentiated variants: use The Multiverse rather than creating separate scaffold/extension versions here. The Playbook creates the standard version; The Multiverse creates differentiated variants based on it.
- The Playbook reads the lesson file for context but does not modify it.
