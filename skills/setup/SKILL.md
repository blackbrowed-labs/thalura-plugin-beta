---
name: setup
description: Thalura einrichten. Use for first-run onboarding / initializing the teacher's Thalura workspace (Einrichtung) — collecting school, profile, and subjects, and scaffolding the data folder. Also the target when startup reports the workspace is not set up.
when_to_use: |
  DE + EN: "einrichten", "Setup", "Thalura einrichten", "neu anfangen", "erstmalig einrichten", "set up", "get started", "onboard", "initialize". Also invoked when resolve-data-root reports THALURA_SETUP_NEEDED.
---

# /thalura:setup — First-Run Initialization

This command scaffolds the `<WORKSPACE_ROOT>/` project folder, collects teacher and school data via a structured interview, and writes all initial configuration files. It is the first command a new teacher runs.

**Workspace root:** `<WORKSPACE_ROOT>` is the teacher's Thalura folder that holds both `data/` and the subject output folders. In Claude Code it is the session's working directory; in Claude Cowork it is the mounted `mnt/<folder>/`. It is resolved once via `${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh`. All teacher-data and output paths in this command are under `<WORKSPACE_ROOT>/`; shipped plugin files use `${CLAUDE_PLUGIN_ROOT}/…`.

**Idempotency:** Running this command again after setup is complete does NOT destroy data. Directories are created only if missing, config files are copied only if missing, and if a teacher profile already exists, the command offers a scaffold check-and-complete (see Phase 0) instead of the interview.

---

## Interaction Style

For every selection with predefined options, present the choices through the environment's interactive selection mechanism (in Claude Code, the `AskUserQuestion` tool) — an option-pick dialog, not a request to type the answer — so the teacher picks rather than transcribes. Where no such dialog mechanism exists, fall back to a clearly enumerated chat prompt. This applies to:

| Phase | Question | AskUserQuestion config |
|-------|----------|----------------------|
| 0 | Repair offer (existing profile) | 2 options: Check and complete the scaffold, Leave everything as it is |
| 1 | Conversation language | 2 options: Deutsch, English |
| 2.1 | Federal state | Options from `education-system.json` |
| 2.2 | School type | Options filtered by selected state |
| 2.4 | Lesson slots | 2 options: Accept defaults (Recommended), Customize |
| 2.5 | Branding decision | 2 options: Set up branding, Skip |
| 2.5.3 | Branding confirmation | 4 options: Accept, Adjust color, Different logo, Skip |
| 3.4 | Content language default | 2 options: Deutsch (Recommended), English |
| 4.1 | Subject selection | `multiSelect: true`, options from `subjects.json` (currently: English, Philosophy, Psychology, Religion) |
| 4.5 | School-internal curriculum | 2 options: Yes (I have school-internal curricula), No (I don't have any) |
| 4.3 | Language content confirm | 2 options: Yes, Adjust |
| 5.1 | School year (if ambiguous) | 2 options: current year label, next year label |

For free-text inputs (school name, website URL, teacher name, abbreviation, email), ask conversationally — do not use AskUserQuestion.

When multiple questions in the same phase are independent, combine them into a single `AskUserQuestion` call with multiple questions (max 4 per call).

### Consolidation Rule

Grouping several questions into one form or widget (wherever the environment offers that) **replaces only the questions the teacher actually answers on it**. It is **never** a licence to default, infer, or harvest a mandatory item that the form did not collect. Every mandatory interview item for which the form did not obtain an explicit answer MUST still be asked individually — through whatever question mechanism the environment normally uses — **before its checkpoint**: the Phase 1–4.5 items before any directory is scaffolded (the completeness gate at the head of Phase 5), the school year within Phase 5.1 itself, and the class question before any Phase-6 file is written. A pre-filled value the teacher then confirms counts as answered; a value taken from ambient or account context — for example an account e-mail or an account display name — that the teacher has **not** confirmed does **not** count as answered, and must still be asked. This holds on every platform: where forms exist, it forces the remaining questions to be asked; where no form mechanism exists, questions are already asked one at a time, so the rule adds nothing and never blocks setup.

---

## Phase 0: Pre-flight Check

1. Check if `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json` exists.
2. If it **exists** — enter **repair mode** (never the interview):
   - Read `conversation_language` from the profile (default `"de"` if missing).
   - Present, via the environment's selection dialog per the Interaction Style convention, in the teacher's language, **two options**:
     - **„Grundgerüst prüfen und vervollständigen"** (EN: "Check and complete the workspace scaffold") — run the scaffold-completion routine at `${CLAUDE_PLUGIN_ROOT}/skills/setup/scaffold-completion.md`, passing the existing profile/config as the conditioning source (the workspace already carries the identity — this only completes the scaffold around it). Report what was created, what was verified present, and any flagged residual. Close with the pointer that profile and school settings are edited via `/thalura:config`:
       - DE: „Profil und Schuleinstellungen bearbeitest du mit `/thalura:config`."
       - EN: "Edit your profile and school settings with `/thalura:config`."
     - **„Nichts ändern"** (EN: "Leave everything as it is") — inform the teacher and stop, keeping the existing pointer prose:
       - DE: "Ein Lehrerprofil existiert bereits. Nutze `/thalura:config profile` um es zu bearbeiten."
       - EN: "A teacher profile already exists. Use `/thalura:config profile` to edit it."
   - Neither option runs the interview. **Never** proceed to Phase 1 when a profile exists.
3. If it **does not exist**: proceed to Phase 1.

---

## Phase 1: Conversation Language

Ask this question **in English**, regardless of the teacher's likely language:

> "Welcome to Thalura! Before we begin — which language would you like me to use during our conversations? English or German?"

- Store the answer as `conversation_language`: `"en"` or `"de"`.
- **All subsequent questions, explanations, and confirmations use the chosen language.**
- In chat, always use human-readable names ("English" / "German"), never raw codes ("en" / "de").

---

## Phase 2: School Information

Read `${CLAUDE_PLUGIN_ROOT}/references/education-system.json` before starting this phase.

### 2.1 Federal State

> "Thalura loads official regulation documents specific to your federal state. Which state does your school belong to?"

Present the available states by enumerating `education-system.json` → `federal_states[].id` at runtime — offer exactly the states the file currently defines (today: Hamburg), with no hard-coded list to maintain. The same compiled list backs the `/thalura:config school` validation, so setup and later editing always agree on what is offered.

Store the selected value as `federal_state` (capitalized official German name, e.g., `"Hamburg"`).

### 2.2 School Type

> "Different school types have different grade structures and exam rules. Which type applies?"

Filter `education-system.json` → `federal_states[selected].school_types[].id` and present the school types the file defines for the selected state (for Hamburg, the file currently lists `"Gymnasium"` and `"Stadtteilschule"`). The offered set is read from the file, not a fixed list.

Store the selected value as `school_type` (capitalized official German name, e.g., `"Gymnasium"`).

**Regulation-coverage check:** A `{federal_state, school_type}` combination is supported when `education-system.json` defines it (which is what the selection above already guarantees). Regulation grounding, however, is bundled per state under `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/…`, and the bundled corpus is currently Hamburg only. If the selected state has no bundled regulations, warn the teacher plainly:

> "Thalura currently bundles official regulations for Hamburg only. You can proceed with your selection, but regulation-grounded features (regulation verification, operator lists) will be limited until your state's regulations ship."

Do not block — the teacher may still want to use the planning and material generation features. This mirrors the same regulation-coverage warning shown when changing the state via `/thalura:config school`, so both surfaces speak with one voice.

### 2.3 School Name

> "What is the official name of your school?"

Store as `school_name`.

### 2.4 Lesson Slots

> "Thalura uses your lesson slot durations to plan lesson phases and time budgets. Most Hamburg schools use 45-minute single periods and 90-minute double periods — does that match yours?"

Present the pre-configured defaults:

| Slot | Duration | Display (DE) | Display (EN) |
|---|---|---|---|
| `single` | 1× lesson (45 min) | Einzelstunde | Single Period |
| `double` | 1× lesson (90 min) | Doppelstunde | Double Period |

Display names are resolved via `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `{conversation_language}.lesson_slots`.

**Slot management rules:**
- **Defaults are always present.** Start with the two pre-configured slots (`single`, `double`). These remain in the list at all times unless the teacher **explicitly** asks to remove one (e.g., "remove the single period" or "I don't need the Einzelstunde").
- If the teacher confirms the defaults → use them as-is.
- If the teacher wants to customize → they can **add** new slots or **modify** existing slot durations. Adding a new slot (e.g., a Doppelstunde with 5-min break) is always additive — it never replaces an existing slot.
- Custom slots need a `label` (in the teacher's language) and at least one segment.
- **Deletion requires explicit confirmation:** Only remove a slot if the teacher explicitly requests it. Before deleting, name the slot and ask for confirmation.
- **Stay in this topic** until the teacher explicitly confirms the final configuration. After each change, present the **complete list** of all configured slots (defaults + custom) and ask: add another, modify one, remove one, or confirm and continue?

Store the resulting `lesson_slots` array.

---

## Phase 2.5: School Branding (Optional)

Branding is entirely optional. The teacher can skip it at any point — the plugin functions fully without branding (the material generator always has a neutral plugin-bundled slide template to fall back on).

When the teacher does want branding, it is set up **eagerly during setup** (not deferred to a later step): colors and logo are confirmed inline in this conversation, and the branded slide template is generated before setup finishes. If the environment lacks the tooling for part of this (no image tool, or the official PPTX skill is unavailable), branding still completes at the best level the environment allows and the teacher is told plainly what was and was not generated — onboarding is never blocked by a branding-tooling gap.

> "Would you like to set up your school's colors and logo for slide presentations? If your school has a website, I can detect the colors automatically. You can also skip this step."

If the teacher says "skip", "no", or similar → set `branding` to `null`, do not store `website`, proceed to Phase 3.

### 2.5.1 Website URL

If the teacher wants to proceed:

> "What is your school's website URL?"

Store the URL as `website` in school-config. If the teacher provides a URL, proceed to auto-detection (2.5.2). If the teacher has no website but still wants branding, skip to manual entry (2.5.4).

### 2.5.2 Auto-Detection

When a website URL is provided, run color detection and logo handling. All of this runs **inline in the setup conversation** — it needs the teacher, and the selection dialog (`AskUserQuestion`) is only available here.

**Tool selection — use what is already present.** The image steps below (download, crop, recolor) name no fixed binary. At runtime, pick a tool that exists in this environment and write the command for it:

- **Download:** in Claude Code, `curl` if present, else `wget`, else a one-line `python3 -c "import urllib.request, sys; urllib.request.urlretrieve(sys.argv[1], sys.argv[2])"`. **In Claude Cowork raw-bash network is blocked and the page-fetch tool returns no image bytes, so there is no automatic logo download — acquisition is by guided manual placement (step 4).**
- **Crop / recolor:** ImageMagick (`magick`/`convert`, present in the Linux sandbox), else `sips` (macOS), else Pillow — `python3 -c "import PIL"` to check; if missing, `pip install pillow` on demand. ImageMagick is the most portable.

If none of the image tools is available and Pillow cannot be installed, skip the pixel step it was for and fall back as noted in that step. A missing tool **never** aborts setup — it only lowers the branding outcome.

**Environment-aware I/O.** Acquisition and preview adapt to the environment without hard-coding its name or a specific tool: reuse the Code/Cowork determination already made at startup, and at acquisition time treat a raw download that yields **0 bytes / a network error** as the signal to switch to guided manual placement (step 4). Fetch the page and preview images with whatever tools the environment exposes — name a tool only where there is a single verified mechanism with no alternative (`mcp__cowork__present_files` for previewing a local image file in Cowork).

1. **Fetch the website** using whatever web-page-fetch tool this environment exposes — let the runtime select it; do not assume a specific tool. From the HTML/CSS, extract:
   - CSS colors from `header`, `nav`, `a`, `button`, `.navbar`, `.header` elements
   - Look for `background-color`, `color`, `border-color` properties on prominent elements
   - Identify the most frequently occurring non-neutral color (not black, white, or grey) as candidate `primary_color`
   - If multiple candidate colors exist, note the top 2–3 for the teacher to choose from

2. **Collect all logo candidates** — do **not** stop at the first match. From the fetched page, gather **every** plausible candidate, each with its absolute source URL, then de-duplicate by URL:
   - `<link rel="icon">` / `<link rel="shortcut icon">` / `<link rel="apple-touch-icon">` (favicon — often low resolution)
   - `<meta property="og:image">` (Open Graph image)
   - schema.org `Organization.logo` (JSON-LD or microdata) — often the school's real crest
   - `<img>` inside `<header>` or an element with class/id containing "logo", in the masthead

3. **Present the candidates and let the teacher decide (validation step).** A school site often exposes more than one image — e.g. a pale wordmark that is invisible on white slides alongside the colored crest — so the teacher, not a "first match" rule, chooses:
   - In the surrounding message, list each candidate with a short descriptor, its filename, its source, and the **clickable absolute URL**. **In Claude Code**, also include an inline `![](url)` **thumbnail** so image-rendering UIs show a preview; a plain terminal degrades to the clickable link. **In Claude Cowork**, external-URL `![]()` does not render (it shows a "Show Image" placeholder), so do **not** emit it — present each web candidate as descriptor + clickable URL (the teacher opens it in their own browser), and once a logo file is placed locally (step 4) preview that **local** file with `mcp__cowork__present_files` to confirm the right file landed. Preview only the image file — never `plan.json` or any internal JSON (the plugin-wide presentation-hygiene rule in the core skill applies).
   - Then ask, via the interactive selection mechanism, what to do. The available actions are:
     - **use one of the detected logos** (one option per candidate);
     - **search again** — re-run detection, optionally against a different page URL the teacher provides;
     - **paste a URL** — the teacher gives a direct image URL to use;
     - **provide a file** — the teacher supplies a logo file: in Claude Code by uploading it (or giving its path); in Claude Cowork by **placing it in `<WORKSPACE_ROOT>/data/assets/` or giving an absolute path** (inline upload does not materialize a file in Cowork);
     - **skip the logo** — continue with **palette-only** branding (no logo variants, no logo on the deck).
   - The selection dialog allows at most four options per question. When the detected candidates plus actions exceed that, ask in two steps: first offer the detected logos plus a "none of these — provide my own / skip" option; if the teacher takes that, follow up with **paste a URL / provide a file / search again / skip**.
   - **Always confirm before proceeding:** show the chosen (or provided) logo back to the teacher. If exactly **1** candidate was detected, still present it for confirmation with the same alternatives — never silently accept it. If **0** candidates were detected, go straight to the **paste a URL / provide a file / search again / skip** choice.

4. **Acquire the chosen logo (environment-aware).** Ensure `<WORKSPACE_ROOT>/data/assets/` exists.
   - **Claude Code:** for a detected candidate or a pasted URL, download it with the download tool selected above to `<WORKSPACE_ROOT>/data/assets/school-logo-original.png`; for an attached file, copy it there. If the download/ingest fails (network blocked, 404, unsupported content type, unreadable file) → tell the teacher and re-offer the step-3 choices (paste a different URL / provide a file / search again / skip). If they skip → continue with **palette-only** branding. Never abort.
   - **Claude Cowork:** raw-bash network is blocked and the page-fetch tool returns no image bytes, so do **not** attempt an automatic byte download. Instead, ask the teacher in their `conversation_language` to **place the chosen logo file into `<WORKSPACE_ROOT>/data/assets/` (or give an absolute path the skill can read)** and to say when it is there. When the teacher confirms, check `<WORKSPACE_ROOT>/data/assets/` (or the given path) for the file; if it is not there yet, tell the teacher and ask again. On detection, save/copy it as `<WORKSPACE_ROOT>/data/assets/school-logo-original.png` and continue with crop/classify/variants exactly as below. Inline upload is **not** relied upon — in Cowork "provide a file" means "place it in `<WORKSPACE_ROOT>/data/assets/` / give me its path." If the teacher cannot place a file → continue with **palette-only** branding. Never abort.
   - As a corroborating signal, treat a raw download yielding **0 bytes / a network error** as the block that routes to manual placement — detecting the failed capability directly, so the flow self-corrects if an environment label is ever wrong.

5. **Auto-crop the logo.** Trim transparent and near-white pixels (RGB > 250 per channel), preserve a ~5px padding margin, and overwrite the working file. Use the crop tool selected above — e.g. ImageMagick `-fuzz 4% -trim +repage`, or `sips`, or Pillow `getbbox()` on an alpha/near-white mask. Show the cropped result back to the teacher for confirmation.
   - **If no image tool is available** (and Pillow cannot be installed): skip cropping and use the image as-is. An un-cropped logo is still usable — the safe-fallback rule in step 7 covers it.

6. **Classify the cropped logo (model-driven, no tool).** Inspect the logo and decide its type:
   - **Type A — Icon on transparent background:** significant transparent areas; visible pixels form a distinct shape (icon, wordmark, crest); most non-transparent pixels share one or two dominant colors.
   - **Type B — Icon on colored background:** a filled background shape (circle, rectangle, shield) with a contrasting icon/text on top; multiple distinct color regions, little or no transparency.

7. **Generate the two color variants** with the recolor tool selected above (ImageMagick `-fill`/`-colorize` with alpha preserved, or Pillow alpha-mask paint). Both variants are shown back to the teacher for confirmation:
   - `school-logo-on-white.png` — copy of the cropped original. Most logos contrast well on white. If the original is entirely white/near-white (Type A only), recolor non-transparent pixels to `primary_color`.
   - `school-logo-on-primary.png`:
     - **Type A:** recolor all non-transparent pixels to white (`#FFFFFF`), preserving the alpha channel.
     - **Type B:** use the original as-is — a logo with its own colored background already has enough internal contrast on any slide background, and recoloring would destroy its structure.
   - **If classification is uncertain, use the original for both variants — always safe.**
   - **If no image tool is available** (and Pillow cannot be installed): use the original for both variants. The deck still embeds a logo, just not background-optimized. If even the original cannot be processed at all, continue with **palette-only** branding.

8. **Analyze logo colors** — if a logo was downloaded and the website CSS did not yield a clear primary color, analyze the logo image for its dominant non-white/non-black color and propose that as `primary_color`.

9. **Derive the full palette** from `primary_color` (pure color math, model-driven — no tool, works wherever the model runs):
   - `secondary_color`: convert primary to HSL, reduce lightness by 20%, convert back to hex
   - `accent_color`: convert primary to HSL. Starting from the primary's own lightness, increase lightness in 1% steps and re-derive until the contrast ratio against `primary_color` is ≥ 3:1 (the accent is a decorative/highlight token on primary-coloured backgrounds — WCAG SC 1.4.11 / SC 1.4.3 large-text). Stop at the first lightness meeting 3:1; clamp the scan at 95% lightness; if 3:1 is not reached, use `neutral_dark` (`#333333`). Contrast vs `#FFFFFF` is not a constraint. The accent must not be used for body-size text (it clears 3:1, not the 4.5:1 body-text floor).
   - `neutral_dark`: `#333333` (fixed default)
   - `neutral_light`: `#F5F5F5` (fixed default)
   - `text_on_primary`: calculate relative luminance of primary; if contrast ratio with `#FFFFFF` ≥ 4.5:1, use `#FFFFFF`; otherwise `#000000`

10. **Determine the detection outcome** (used in 2.5.3 and 2.5.3a):
    - **Colors + logo:** full palette plus two logo variants ready to confirm.
    - **Colors, no usable logo** (none found and none pasted, download failed, or no image tool could even pass the original through): palette-only — present the palette and tell the teacher no logo could be prepared.
    - **No colors / fetch failed:** inform the teacher and offer the neutral education-blue palette (`#2B579A` as primary).

### 2.5.3 Teacher Confirmation

Present the proposed palette as a summary:

> "Based on your school website, I've identified these colors:
>
>   Primary:    #2958C3
>   Secondary:  #1A3A7F
>   Accent:     #9BB3EA
>   Text:       #FFFFFF on primary
>   Logo:       2 variants generated / not found
>
> These colors will be used in slide presentations. You can:
> 1. Accept as-is
> 2. Adjust any color (tell me which one and the new hex value)
> 3. Provide a different logo file
> 4. Skip branding entirely"

- **Accept:** Set `auto_detected: true`, `confirmed_by_teacher: true`, store all values.
- **Adjust:** Apply teacher's changes. If `primary_color` changes, re-derive `secondary_color`, `accent_color`, and `text_on_primary`. Set `confirmed_by_teacher: true`.
- **Different logo:** Teacher supplies a logo (paste a URL or provide a file). Auto-crop and generate both color variants the same way as in 2.5.2 (the auto-crop, classify, and variant-generation steps). Store in `<WORKSPACE_ROOT>/data/assets/`.
- **Skip:** Set `branding` to `null`. Delete any downloaded logo. Do not store `website`.

### 2.5.3a Generate Branded Slides Template

After branding is confirmed (accept, adjust, or manual entry — any outcome except skip), generate the branded slide template. This runs **eagerly, as part of setup** (not deferred). The slide template is a binary `.pptx` file that cannot be written as plain text — it is always authored by the **official PPTX skill**, never by a hand-written generator. There are two ways to run it; prefer the first.

1. **Create the output directory.** Ensure `<WORKSPACE_ROOT>/data/templates/materials/` exists.

2. **Preferred path — delegate out-of-band.** Dispatch the template authoring to a sub-agent (in Claude Code, via the sub-agent/`Task` mechanism) with a **self-contained delegation prompt**, so the verbose PPTX-skill output stays out of the interview. If no delegation mechanism is available, run the same work inline (the fallback path below). The sub-agent has fresh context and does no teacher interaction — no interactive selection dialog is available to it, and all confirmations already happened inline above. The delegation prompt must carry, as model-resolved absolute paths and literal values:
   - the confirmed palette — `primary_color`, `secondary_color`, `accent_color`, `text_on_primary` hex values;
   - the absolute paths of the two confirmed logo variants (`…/school-logo-on-white.png`, `…/school-logo-on-primary.png`), or an explicit note that no logo is available;
   - the `slide_aspect_ratio` (default `"16:10"`);
   - the absolute path of the slide template specification, `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` (the single source of truth for the 4 slide masters TITLE/CONTENT/SECTION/BLANK, EMU dimensions, and accessibility typography);
   - the absolute output path of `<WORKSPACE_ROOT>/data/templates/materials/template_slides.pptx`;
   - the instruction: **use the official PPTX skill** to author the deck per that specification (TITLE/SECTION carry the on-primary logo, CONTENT/BLANK carry the on-white logo; if no logo is available, author a logo-free template), write the file **atomically**, then compute its SHA-256 (use whichever of `sha256sum`, `shasum -a 256`, or a one-line `python3 -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())"` is present), and **return only** the report below.

   The sub-agent returns a single fenced JSON block:

   ```json
   {
     "branding_tier": "full | palette_only",
     "tier_reason": "ok | no_pptx_skill | skill_error | write_failed",
     "template": { "path": "<abs path | null>", "sha256": "<64-hex | null>" }
   }
   ```

3. **Fallback path — inline.** If the sub-agent does not return a usable deck (it could not be dispatched, the report is `palette_only`, the report is missing/unparseable, or `template.path` does not point to a written file), perform the **same** work **inline** here: invoke the **same official PPTX skill** with the same palette, logo variants, aspect ratio, specification path, and output path; write atomically; compute the SHA-256 the same way. The sub-agent is the preferred path because it keeps the verbose skill output out of the interview; inline is the fallback, not a coin-flip — never substitute a hand-rolled `.pptx` generator.

   **Template-metadata gate:** the generated `template_slides.pptx` must carry neutral `docProps` — empty `dc:creator`, `cp:lastModifiedBy`, `dc:title`, `dc:subject`, and `Company`; `Application` = `Thalura` — per the Bundled-Template Metadata Policy in `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` (and ultimately `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md`). The authoring capability's default `Application` must not survive into the stored template.

4. **The main flow writes `school-config.json` from the result** — the sub-agent never writes config, so a half-failed sub-agent cannot corrupt it:
   - **Full branding** — a `.pptx` was written and verified to exist: store the SHA-256 as `branding.template_hash` in `school-config.json`. Inform the teacher: *"Slides template generated with your school colors."*
   - **Palette-only** — the official PPTX skill is unreachable in **both** the sub-agent and inline (no PPTX skill installed, skill error, or write failure): do **not** write `template_slides.pptx`, set `branding.template_hash` to `null`, and keep the confirmed palette and any logo variants in `school-config.json`. The material generator then uses the neutral plugin-bundled `template_slides.pptx`. Tell the teacher in their `conversation_language`, in plain language, that this is a tooling limit and not a loss — e.g.:
     > "I've saved your school colors. I couldn't generate the branded slide template in this environment, so presentations will use the neutral template for now — your colors will be applied to the branded template automatically the next time you create slides, or you can run `/thalura:config school`."

If branding is skipped (`null`), do not generate anything here — the material generator falls back to the neutral plugin-bundled template.

### 2.5.4 Manual Entry (No Website)

If the teacher does not have a website URL but wants branding:

> "You can enter your school's primary color manually. Provide a hex code like #2B579A, or describe the color (e.g., 'dark blue') and I'll suggest a hex value."

Follow the same palette derivation as in 2.5.2 (the palette-derivation step) and confirmation flow (2.5.3), but with `auto_detected: false`.

### 2.5.5 Slide Accessibility Info

After branding is complete (whether configured or skipped), inform the teacher about the accessibility mode. Display in the teacher's `conversation_language`. This is informational only — no confirmation gate required. Proceed directly to Phase 3 without waiting for acknowledgment.

> "Accessibility mode is enabled by default for slide presentations. This uses a dyslexia-friendly font (Verdana), larger text, and wider line spacing for better readability on classroom screens. You can customize individual settings or turn it off anytime via `/thalura:config preferences`."

---

## Phase 3: Teacher Profile

### 3.1 Full Name

> "What is your full name? This is stored in your profile for reference only — it will not appear on any generated documents."

Store as `name`. The name is an **explicit teacher answer**: an account display name may be offered as a suggestion for the teacher to confirm, but it is **never stored unconfirmed**.

### 3.2 Teacher Abbreviation

> "Your official teacher abbreviation (Kürzel) — this appears in document headers, slide decks, and file names. For example: Wei. What is yours?"

Store as `teacher_abbreviation`.

### 3.3 Email (optional)

Use the selection dialog with 2 options:
- **Skip** (Recommended) — "No email needed"
- **Enter email** — "I want to store my email address"

If the teacher selects "Enter email", ask conversationally for a valid email address. The email is stored in the profile for reference only — it does not appear on any generated documents.

Store as `email`. If skipped, store `null`. The email is written **only** on an explicit teacher decision — a value entered, or Skip chosen (→ `null`). An ambient account e-mail may seed the "Enter email" suggestion, but absent an explicit enter-or-skip decision the field is **not** written from it.

### 3.4 Content Language Default

> "This controls the default language for student-facing materials like worksheets, handouts, and slides. You can override this per subject or per document later. English or German?"

Default: German. Store as `content_language_default` (`"en"` or `"de"`).

---

## Phase 4: Subject Selection & Content Language Confirmation

Read `${CLAUDE_PLUGIN_ROOT}/references/subjects.json` before starting this phase.

### 4.1 Subject Selection

> "Which subjects do you teach? Select all that apply."

Present the available subjects from `${CLAUDE_PLUGIN_ROOT}/references/subjects.json`, with localized display names from `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `{conversation_language}.subjects`:

- Read every entry in `subjects[]` from `${CLAUDE_PLUGIN_ROOT}/references/subjects.json` — this is the source of truth for which subjects exist and their `abbreviation`. Do **not** hard-code a subject list here; new subjects added to `subjects.json` must appear automatically.
- For each entry, resolve its display label from `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `{conversation_language}.subjects.{id}`.
- Present **all** of them as selection-dialog options, allowing multiple selections (in Claude Code, `multiSelect: true`).

The teacher must select at least one subject. Store as the `subjects` array.

### 4.2 Auto-Derive Language Settings

For each selected subject, auto-derive language settings based on subject type:

**Language subjects (English):**
- `target_language`: `"en"`
- `content_language`:
  - `worksheets`: `"en"`
  - `handouts`: `"en"`
  - `slides`: `"en"`
  - `assessments`: `"en"`
  - `unit_plan_tasks`: `"en"`
  - `assessment_rubric`: `"de"` (always German — Hamburg BSB convention)

**Non-language subjects (Philosophy, Religion):**
- `target_language`: `null`
- No `content_language` object — all output defaults to `content_language_default`

### 4.3 Confirm Content Language for Language Subjects

For each language subject, present the **complete content language configuration** as a table listing every material type and its language. Explicitly flag **all** entries that deviate from the target language. This gives the teacher full visibility before confirming.

**Example — German-speaking teacher with English as a subject:**

> "For English, here are the default content language settings:"
>
> | Material type | Language | Note |
> |---|---|---|
> | Worksheets | English | |
> | Handouts | English | |
> | Slides | English | |
> | Assessments | English | |
> | Unit plan tasks | English | |
> | Assessment rubric (Erwartungshorizont) | **German** | BSB Hamburg convention |
>
> "The assessment rubric is set to German because Hamburg BSB requires it. All other materials default to the target language (English). Would you like to adjust any of these?"

**Example — English-speaking teacher with English as a subject:**

Present the same table. Even though conversation language matches, the assessment rubric deviation still needs to be shown.

- If the teacher confirms → keep auto-derived defaults.
- If the teacher wants changes → adjust individual `content_language` fields.
- **Stay in this topic** until the teacher explicitly confirms the final configuration. After each change, present the updated table and ask if anything else needs adjusting or if the configuration is complete.
- Non-language subjects require no confirmation — they use `content_language_default`.

---

## Phase 4.5: School-Internal Curriculum (Schulinternes Curriculum)

After subject selection, ask the teacher whether they have school-internal curriculum (Schulinternes Curriculum) documents. Use the full term — not the abbreviation "SiC" — for clarity. The prompt below is in English; translate to `conversation_language` at runtime.

> "Do you have a school-internal curriculum (Schulinternes Curriculum) for your subjects? A school-internal curriculum is your school's binding topic sequence for each subject — it defines which topics are taught when. If you have one, Thalura can use it to enrich its planning alongside the official curriculum standards (Bildungsplan)."

Present via the selection dialog with 2 options:
- **Yes** — "Yes, I have school-internal curricula"
- **No** — "No, I don't have any"

**If "Yes":**
> "Great! During setup, Thalura will create folders for your school-internal curricula. After setup, place the PDF files in the corresponding subject folders:"
>
> `<WORKSPACE_ROOT>/data/regulations/sic/{subject_id}/`
>
> (List the subject subdirectories that will be created for the teacher's selected subjects, using localized subject names in the explanation but English IDs for the path.)
>
> "The files can have any name — Thalura will scan for all PDFs in each folder."

**If "No":**
> "No problem — Thalura will use the official curriculum standards (Bildungsplan) directly. You can always add school-internal curricula later by placing PDF files in `<WORKSPACE_ROOT>/data/regulations/sic/{subject}/`."

**This phase is informational only — setup continues regardless of the answer. The SiC directory structure is always created in Phase 5.2.**

---

## Phase 5: School Year & Directory Scaffolding

### Completeness gate — confirm before scaffolding

Before scaffolding any directory, verify that **every** mandatory interview item has an **explicit answer or an explicit decision** from the teacher. Any item that is still unanswered — because a consolidated form did not collect it, or because it was only pre-filled from ambient or account context — MUST be asked now, individually, before you continue. **Do not fall back to a default for an unanswered item at any checkpoint**: a default (for example the 45/90 lesson-slot (Stundenraster) default) is valid only once the teacher has been shown it and has confirmed it.

The mandatory items, each with what counts as answered:

1. **Conversation language** (Phase 1).
2. **Federal state (Bundesland)** (Phase 2.1).
3. **School type (Schulform)** (Phase 2.2).
4. **School name** (Phase 2.3).
5. **Lesson slots (Stundenraster)** (Phase 2.4) — the teacher **confirmed** the defaults or customized them, not silently defaulted.
6. **Branding decision** (Phase 2.5) — configured **or** explicitly skipped (Skip counts as answered).
7. **Teacher name** (Phase 3.1) — an explicit teacher answer, not a harvested account display name.
8. **Teacher abbreviation (Kürzel)** (Phase 3.2).
9. **Email decision** (Phase 3.3) — a value entered **or** Skip chosen (→ `null`); an ambient account e-mail alone is **not** a decision.
10. **Content-language default** (Phase 3.4).
11. **Subjects** (Phase 4.1) — at least one.
12. **Content-language confirmation** for any language subject (Phase 4.3); a run with no language subject legitimately skips this.
13. **School-internal curriculum (Schulinternes Curriculum) asked** (Phase 4.5) — Yes/No answered.
14. **School year** (Phase 5.1) — derived-and-announced, or asked in the ambiguity window.
15. **Classes asked** (Phase 5 continuation) — the fresh-year "which classes do you teach?" question was **presented**.

**Checkpoints — three stages, because two items are collected inside Phase 5:**

- **Before the first directory is created (here, at the head of Phase 5):** verify items **1–13** are answered-or-explicitly-decided. Ask any missing one now, before scaffolding.
- **Within Phase 5.1:** item **14** (school year) is satisfied by executing Phase 5.1 as written — derive-and-announce outside the June 1 – July 31 ambiguity window, ask inside it.
- **Before any Phase-6 file is written:** verify item **15** (classes asked) — the class question by design **follows** the `school-years/{school_year}/classes/` scaffold (see the continuation flow at the end of Phase 5.2), so it is checked at that later point, not here.

**Item 15 means the question was *presented*, not that class definitions were *written*.** Class creation stays teacher-confirmed — nothing is written until the teacher confirms, exactly as the continuation flow already specifies. This gate closes the hole where the class question was never asked in setup at all; it does not change the confirm-before-write discipline.

**Fresh-setup path only.** This gate sits on a first-run setup. Phase 0's repair mode never runs the interview and never edits the interview-collected profile or school-configuration values — a re-run on an initialized workspace therefore never reaches this gate; the gate remains a first-run-only checkpoint.

### 5.1 Derive School Year

Read the `school_year_start` (`{month, day}`) from `${CLAUDE_PLUGIN_ROOT}/references/education-system.json` for the selected `federal_state` and derive the active school year against that configured boundary. All current states use August 1, but the boundary is read from config rather than hardcoded, so a state with a different start date works without a code change (the same lookup the core startup uses).

**Standard derivation:**
- If current date >= August 1 → school year is `{current_year}-{next_year_short}` (e.g., `2026-27`)
- If current date < August 1 → school year is `{prev_year}-{current_year_short}` (e.g., `2025-26`)

**Setup ambiguity window (June 1 – July 31):**

If the current date falls between June 1 and July 31, ask the teacher instead of auto-deriving:

> "The new school year starts August 1st. Are you setting up for the current school year ({current_year_label}) or already for the upcoming one ({next_year_label})?"

This wider ambiguity window applies **only to `/thalura:setup`**. The core skill startup sequence (*Step 2: Derive School Year*) continues to use the strict August 1 rule for daily school year derivation.

Outside the ambiguity window, derive automatically and inform the teacher:

> "Active school year: {year} (derived from today's date and the August 1st boundary)."

Store as `school_year`.

### 5.2 Create Directory Structure

This directory tree and the Phase-6 file writes are the workspace scaffold contract; any change here must be mirrored in the scaffold detection script (`${CLAUDE_PLUGIN_ROOT}/scripts/scaffold-status.sh`) and the scaffold-completion satellite (`${CLAUDE_PLUGIN_ROOT}/skills/setup/scaffold-completion.md`), which derive from it.

Create all directories. Only create if missing (idempotent). Use `mkdir -p` semantics — never fail if the directory already exists.

```
<WORKSPACE_ROOT>/
  data/
    assets/                           ← school branding assets (created only if branding has a logo)
    templates/
      materials/                      ← branded slides template (created only if branding is configured)
    config/
    profiles/
    library/
      materials/
    school-years/
      {school_year}/
        classes/
    regulations/
      sic/
        {subject_id}/                 ← one per selected subject (e.g. english/, philosophy/, religion/, …)
    exam-formats/                     ← user-defined exam formats
  {localized_subject_name}/           ← one per selected subject, name from localization.json
    {school_year}/                    ← e.g., Englisch/2025-26/ or English/2025-26/
```

**Note:** `<WORKSPACE_ROOT>/data/assets/` is only created when Phase 2.5 downloads a school logo. If branding was skipped or no logo was found, this directory is not created. When a logo is found, three files are stored: `school-logo-original.png` (cropped original), `school-logo-on-primary.png` (white variant), `school-logo-on-white.png` (original-color variant).

**Localized subject folder names:** Resolve via `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `{conversation_language}.subjects.{subject_id}`. Examples:
- DE: `Englisch/`, `Philosophie/`, `Religion/`, …
- EN: `English/`, `Philosophy/`, `Religion/`, …

**Populate the first school year via core's continuation flow.** After scaffolding `school-years/{school_year}/classes/`, this phase is an **entry point** into `core`'s year detection + continuation-proposal flow — it does not re-implement that logic. Invoke the year-transition continuation proposal (see the Class Definition System in `skills/core/SKILL.md`) so first-run scaffolding can populate confirmed class continuations from a prior year rather than stopping at the empty `classes/` directory. On a genuinely fresh first run with no prior year, the flow simply asks which classes the teacher teaches and creates the confirmed definitions; nothing is written until the teacher confirms.

---

## Phase 6: Write Files

Write all files in this phase. For each file: if the file already exists, follow the rule in the "Overwrite" column. All Phase-6 writes (the version file, config copies, profiles) target the `<WORKSPACE_ROOT>` already resolved by the setup preamble.

### 6.0 Version Tracking

Write `<WORKSPACE_ROOT>/data/version.json`:

```json
{
  "plugin_version": "{version from .claude-plugin/plugin.json}",
  "updated_at": "{ISO-8601 timestamp}"
}
```

This file is plugin-managed. If it already exists, **overwrite** it (setup always records the current version). See `${CLAUDE_PLUGIN_ROOT}/references/versioning.md` for the version check mechanism.

### 6.1 Config Copy (Two-Tier System)

For each file in `config-defaults/`:
- If no corresponding file exists in `<WORKSPACE_ROOT>/data/config/` → copy it.
- If file already exists → **skip** (never overwrite — two-tier rule).

This step iterates **all** files in `config-defaults/` generically. Current files copied:
- `${CLAUDE_PLUGIN_ROOT}/config-defaults/naming-conventions.json` → `<WORKSPACE_ROOT>/data/config/naming-conventions.json`
- `${CLAUDE_PLUGIN_ROOT}/config-defaults/behaviour.json` → `<WORKSPACE_ROOT>/data/config/behaviour.json` (behaviour toggles including `generate_student_slides`, `internal_compliance_check`, `pdf_on_validation`)
- `${CLAUDE_PLUGIN_ROOT}/config-defaults/standard-supplies.json` → `<WORKSPACE_ROOT>/data/config/standard-supplies.json` (the teacher's optional standard-supplies list (Standardmaterial); the generic copy seeds it — no onboarding question)

### 6.1b Exam Format Template (Two-Tier System)

Copy the exam format template to the user-defined format directory:
- If `<WORKSPACE_ROOT>/data/exam-formats/_template.md` does not exist → copy `${CLAUDE_PLUGIN_ROOT}/references/exam-formats/_template.md`.
- If file already exists → **skip** (same two-tier rule as config).

This directory is where teachers can create custom exam format definitions. User-defined formats with the same filename as a plugin-bundled format take full precedence (no partial merge).

### 6.2 School Config

Write `<WORKSPACE_ROOT>/data/profiles/school-config.json`:

```json
{
  "school_id": "{generated}",
  "school_name": "{from Phase 2.3}",
  "federal_state": "{from Phase 2.1 — capitalized German name}",
  "school_type": "{from Phase 2.2 — capitalized German name}",
  "website": "{from Phase 2.5.1 — omit if not provided}",
  "branding": "{from Phase 2.5 — object if configured, null if skipped, omit if Phase 2.5 was skipped entirely. Includes logo_path_on_primary, logo_path_on_white, slide_aspect_ratio (default '16:10'), and template_hash (from 2.5.3a)}",
  "lesson_slots": [
    {
      "id": "single",
      "segments": [{ "type": "lesson", "minutes": 45 }]
    },
    {
      "id": "double",
      "segments": [{ "type": "lesson", "minutes": 90 }]
    }
  ],
  "created_at": "{ISO-8601 timestamp}"
}
```

**`school_id` generation**:

Format: `{federal_state}-{school_type}-{slug}-{short_uid}`

1. Lowercase the `federal_state` (e.g., `"Hamburg"` → `"hamburg"`)
2. Lowercase the `school_type` (e.g., `"Gymnasium"` → `"gymnasium"`)
3. Slugify the `school_name`: lowercase, ASCII only, hyphen-separated, strip the school type prefix if it's redundant (e.g., "Gymnasium Musterstadt" → `"musterstadt"`)
4. Generate the `short_uid`: 4 freshly sampled random hex characters (e.g., `"a3f7"`)
5. Combine: `hamburg-gymnasium-musterstadt-a3f7`

**VERIFY before writing (hard gate).** A generated value is not trusted until verified — generation can silently fall back to an ambient environment value (a user id, a fixed constant) without any error surfacing, and the wrong value then propagates identically into both files, where nothing downstream ever catches it. Before the id is written anywhere (`school-config.json` **and** the `school_id` reference in `teacher-profile.json`), confirm both gates:

- **Shape:** the full id matches `^[a-z0-9-]+-[0-9a-f]{4}$` — in particular the suffix is exactly 4 lowercase hex characters (`-[0-9a-f]{4}$`). See the id pattern in `${CLAUDE_PLUGIN_ROOT}/references/schemas/school-config.md`.
- **Freshness:** the generation actually samples randomness — invoking the **same** generation a second time MUST yield a **different** suffix. Identical outputs mean the method is echoing a fixed ambient value, not sampling, **even when the value happens to look hex-shaped**.

On any failed gate: **regenerate via a different method** and re-verify against both gates. **Never write an unverified or gate-failing id.** If no available method produces a verified value, stop and surface the failure to the teacher instead of writing a fallback.

### 6.3 Teacher Profile

Write `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json`:

```json
{
  "name": "{from Phase 3.1}",
  "teacher_abbreviation": "{from Phase 3.2}",
  "email": "{from Phase 3.3 — null if skipped}",
  "school_id": "{from 6.2 — references school-config.json}",
  "conversation_language": "{from Phase 1}",
  "content_language_default": "{from Phase 3.4}",
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
    }
  ],
  "created_at": "{ISO-8601 timestamp}"
}
```

The `subjects` array contains only the subjects selected in Phase 4. The `content_language` object is only present for language subjects with a `target_language`. The `gendering` object is written with the safe defaults (`student_docs: neutral`, `teacher_docs: abbreviation`) and is **not** asked during onboarding — the gender-inclusive language (geschlechtergerechte Sprache) preference is edited later via `/thalura:config profile`, which is the only surface that shows the option tables. See `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-profile.md` for the full schema.

The `generate_student_slides` toggle is **not** seeded here — it has moved to the two-tier behaviour config (`<WORKSPACE_ROOT>/data/config/behaviour.json`), where its default (`true`) ships in `${CLAUDE_PLUGIN_ROOT}/config-defaults/behaviour.json` and is copied into the teacher's workspace by the config copy step (§6.1) below. **No** onboarding question is asked for it — the teacher first meets the per-lesson student task deck as a lesson-draft proposal, a better teaching moment than an abstract setup yes/no. Do **not** add an AskUserQuestion for this field. It is editable later via `/thalura:config behaviour`.

### 6.4 Teacher Preferences (Empty)

Write `<WORKSPACE_ROOT>/data/profiles/teacher-preferences.json`:

```json
{
  "version": "1.0",
  "last_updated": null,
  "slide_preferences": {
    "accessibility_mode": true,
    "font": null,
    "body_font_size": null,
    "title_font_size": null,
    "line_spacing": null,
    "max_bullets_per_slide": null
  }
}
```

The `slide_preferences` section is pre-populated with `accessibility_mode: true`. All other preferences are populated through usage (Layer 2 of the two-layer preference system). See `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-preferences.md`.

### 6.5 Teacher Observations (Empty)

Write `<WORKSPACE_ROOT>/data/profiles/teacher-observations.json`:

```json
{
  "version": "1.0",
  "last_updated": null,
  "promotion_threshold": 3,
  "categories": {
    "method_acceptance": {},
    "method_rejection": {},
    "social_form_acceptance": {},
    "social_form_rejection": {},
    "format_preference": {},
    "style_preference": {},
    "assessment_format": {}
  }
}
```

This is an empty shell. Observations are recorded automatically during every session. See `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-observations.md`.

### 6.6 School Year Plan (Empty)

Write `<WORKSPACE_ROOT>/data/school-years/{school_year}/plan.json`:

```json
{
  "school_year": "{school_year}",
  "plans": []
}
```

See `${CLAUDE_PLUGIN_ROOT}/references/schemas/school-year-plan.md`. Class-level plan entries are added when the teacher starts planning for a class.

### 6.7 Library Skeletons

For each selected subject, write `<WORKSPACE_ROOT>/data/library/{subject_id}.json`:

```json
{
  "subject": "{subject_id}",
  "units": []
}
```

See `${CLAUDE_PLUGIN_ROOT}/references/schemas/library-subject.md`. Library units are added when the teacher shelves or imports a unit.

### 6.8 SiC README

Write `<WORKSPACE_ROOT>/data/regulations/sic/README.md`:

The README content must be written in the teacher's `conversation_language`. The English source template lives in `${CLAUDE_PLUGIN_ROOT}/skills/setup/sic-readme-template.md` — translate at runtime.

If the file already exists → **skip** (never overwrite).

### 6.9 Data Folder README

Write `<WORKSPACE_ROOT>/data/README.md` — the protective README telling the teacher that Thalura manages this folder, what happens if its contents are changed, and the two drop-zones where Thalura asks them to place files themselves.

The README content must be written in the teacher's `conversation_language`. The English source template lives in `${CLAUDE_PLUGIN_ROOT}/skills/setup/data-readme-template.md` — translate at runtime.

If the file already exists → **skip** (never overwrite).

### 6.10 Scaffold Self-Verification

After the Phase-6 writes, run the scaffold-completion routine's loop (`${CLAUDE_PLUGIN_ROOT}/skills/setup/scaffold-completion.md`): invoke `${CLAUDE_PLUGIN_ROOT}/scripts/scaffold-status.sh <PLUGIN_ROOT> <WORKSPACE_ROOT>` (both roots already resolved by the setup preamble), then act on whatever it reports.

On a healthy setup run this is a single `scaffold=complete` line — no teacher interaction, zero interview cost. Any token means a Phase 5.2/6 write was dropped: act on it per the satellite (create-only writes, localized content translated at write time), then re-run the script. Proceed to Phase 7 only per the satellite's completion gate — a re-run reporting `scaffold=complete`, or every remaining token an honestly flagged residual.

**Branding same-session exemption:** when Phase 2.5.3a already ran its branded-template generation attempt earlier in this session — whatever its outcome — a `template=` state is only **reported** here, never re-attempted. This self-verification never dispatches a second generation attempt for a template the branding phase already tried.

This phase verifies **presence** — that every folder and starter file is in place; the Phase 8 summary shows the **values** the teacher chose.

---

## Phase 7: Regulation Verification

**Skip this phase** if the selected `federal_state` has no bundled regulations (i.e., not Hamburg). Both Hamburg school types — Gymnasium **and** Stadtteilschule — have bundled regulations.

For Hamburg (both school types):

1. Read `${CLAUDE_PLUGIN_ROOT}/references/document-registry.md` routing matrix to inventory the expected regulation set for this setup phase (a one-time inventory read, distinct from the per-task routing-key resolution core performs once per session).
2. For each selected subject, enumerate the expected PDF files across all layers:
   - Layer 1: Always-loaded cross-subject files (`shared/cross-subject/`)
   - Layer 2: Sek I and Sek II level-specific cross-subject files (`{school_type}/cross-subject/` and `shared/cross-subject/`)
   - Layer 3: Subject-specific curriculum files for both levels (`{school_type}/{subject}/` and `shared/{subject}/`; note: Psychology Sek I lives in `shared/psychology/` for both school types — there is intentionally no `stadtteilschule/psychology/` directory)
   - Layer 4: Operator files for the subject (`shared/`)
   - Layer 5: A-Hefte (check available years)
   - Stadtteilschule only: ESA/MSA Musteraufgaben (`stadtteilschule/{subject}/`, where available)
3. Cross-reference each expected file against `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/{school_type}/` **and** `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/shared/` (most documents are shared between school types).
4. Report results:

**If all files present:**
> "All regulation documents for your subjects are bundled and ready."

**If files are missing:**
> "The following regulation documents are missing from the plugin bundle:"
> - `{path}` — {document name}
> "This does not block setup. Contact the plugin maintainer or add the files manually."

**This is a warning only. Do not block setup completion.**

---

## Phase 7.5: School-Internal Curriculum Status

Scan `<WORKSPACE_ROOT>/data/regulations/sic/` for PDF files in each subject subdirectory. Report which subjects have school-internal curriculum (Schulinternes Curriculum) files and which don't.

**Example output (translate to `conversation_language` at runtime):**

```
School-Internal Curriculum:
  ✅ English — 2 files (sic_englisch_seki.pdf, sic_englisch_sekii.pdf)
  ⚠️ Philosophy — no school-internal curriculum found (using curriculum standards directly)
  ✅ Religion — 1 file
```

**This is informational only. Missing SiC files never block setup or any operation.**

---

## Phase 8: Confirmation

**This summary is mandatory and non-skippable.** Print it after the last write and **before the session hands off to any task skill** (for example unit-planning) — it is the teacher's sole view of what was written to the workspace, and the last-line defence against a value that was silently defaulted or harvested. The summary MUST reflect the **actual stored values** (name, email decision, lesson slots, subjects, SiC, branding, school year), so a wrong harvested value or a wrong lesson-slot raster is visible here rather than hidden.

Print a setup summary in the teacher's `conversation_language`:

```
Setup complete!

  School:        {school_name} ({federal_state}, {school_type})
  Branding:      {branding status — see below}
  Teacher:       {name} ({teacher_abbreviation})
  Email:         {stored email address, or "skipped" (DE: "übersprungen") when email is null}
  Subjects:      {comma-separated localized subject names}
  Lesson slots:  {confirmed slot configuration, e.g. "45 min (Einzelstunde), 90 min (Doppelstunde)", localized}
  SiC:           {SiC status per subject — e.g., "English (2 files), Philosophy (not found)"}
  School Year:   {school_year}
  Language:      Conversations in {language_name}, materials default to {content_language_name}
  Data Folder:   <WORKSPACE_ROOT>/

  {regulation warnings from Phase 7, if any}

  Next steps:
  • Start planning with any task command (e.g., ask me to plan a unit)
  • Adjust settings anytime with /thalura:config
```

The **Email** line shows the stored address when one was entered, or the skipped marker (DE: "übersprungen" / EN: "skipped") when `email` is `null`. The **Lesson slots** line shows the confirmed slot configuration, using the same localized display-name mechanism as the rest of the summary. Both labels are localized into `conversation_language` like every other field above.

**Branding status line** (depending on Phase 2.5 outcome):
- Auto-detected, branded template generated: `"School colors detected and confirmed (primary: #2958C3) — branded slides template generated"`
- Neutral palette, branded template generated: `"Neutral color palette selected (primary: #2B579A) — branded slides template generated"`
- Manual entry, branded template generated: `"Custom school colors configured (primary: #XXXXXX) — branded slides template generated"`
- Palette saved, branded template deferred (tooling unavailable in this environment): `"School colors saved (primary: #2958C3) — branded slides template will be generated the next time you create slides (neutral template used for now)"`
- Skipped: `"Skipped (neutral default used for slides)"`

---

## Reference Files

This command reads the following plugin reference files during execution:

| File | Used in | Purpose |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}/references/education-system.json` | Phase 2, Phase 5 | Federal states, school types, grade arrays, school year start |
| `${CLAUDE_PLUGIN_ROOT}/references/subjects.json` | Phase 4 | Available subjects and abbreviations |
| `${CLAUDE_PLUGIN_ROOT}/references/localization.json` | Phases 2–9 | Display labels in teacher's language |
| `${CLAUDE_PLUGIN_ROOT}/references/document-registry.md` | Phase 7 | Expected regulation PDF inventory |
| `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-profile.md` | Phase 6.3 | Teacher profile JSON schema |
| `${CLAUDE_PLUGIN_ROOT}/references/schemas/school-config.md` | Phase 6.2 | School config JSON schema |
| `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-preferences.md` | Phase 6.4 | Preferences empty structure |
| `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-observations.md` | Phase 6.5 | Observations empty structure |
| `${CLAUDE_PLUGIN_ROOT}/references/schemas/school-year-plan.md` | Phase 6.6 | School year plan schema |
| `${CLAUDE_PLUGIN_ROOT}/references/schemas/library-subject.md` | Phase 6.7 | Library skeleton schema |
| `${CLAUDE_PLUGIN_ROOT}/references/config-system.md` | Phase 6.1 | Two-tier config copy rules |
| `${CLAUDE_PLUGIN_ROOT}/skills/setup/data-readme-template.md` | Phase 6.9 | English source for the protective data-folder README |
| `${CLAUDE_PLUGIN_ROOT}/skills/setup/sic-readme-template.md` | Phase 6.8 | English source for the SiC folder README |
| `${CLAUDE_PLUGIN_ROOT}/skills/setup/scaffold-completion.md` | Phase 0, Phase 6.10 | Shared scaffold check-and-complete routine |
| `${CLAUDE_PLUGIN_ROOT}/scripts/scaffold-status.sh` | Phase 6.10 | Deterministic scaffold detection |
| `${CLAUDE_PLUGIN_ROOT}/config-defaults/naming-conventions.json` | Phase 6.1 | Default naming config to copy |
| `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` | Phase 2.5.3a, 2.5.5 | Slides template design spec for branded generation and accessibility defaults |
| `${CLAUDE_PLUGIN_ROOT}/references/versioning.md` | Phase 6.0 | Version tracking mechanism |
| `.claude-plugin/plugin.json` | Phase 6.0 | Current plugin version |
