# Template — Design Specification

This document is the single source of truth for all Word and PowerPoint templates used for material types. Both the neutral plugin-bundled fallback and school-branded project-level templates are generated following this spec.

The header, footer, and page setup are shared across Word material types; only the content section and specific section properties differ.

Layout values for generated planning and material documents — colours, fonts, sizes, spacing, borders, and per-table column widths — are defined in `${CLAUDE_PLUGIN_ROOT}/references/design-tokens.json`. This specification binds those tokens to each document surface and named style; it references token values by key and never restates them inline. The planning content tables are bound under [Content-table styling](#content-table-styling).

---

## Design Decisions

1. **Named styles**: Templates define 5 paragraph styles — `Normal`, `Titel`, `Aufgabe`, `Kopfzeile`, `Fußzeile`. All formatting flows through these styles rather than being inlined on every run. This protects design consistency when teachers edit generated materials.

2. **Clean XML policy**: Templates are generated with `docx-js`. No RSIDs, no `latentStyles`, no theme files. Only the styles actually used are defined in `styles.xml`.

3. **Spell-check language**: `{{LANGUAGE}}` (`de-DE` or `en-GB`) is set via `w:lang` in `docDefaults` at generation time, ensuring Word applies the correct proofing dictionary.

4. **Line numbering**: The reading text template enables section-level line numbering (`w:lnNumType w:countBy="5" w:restart="newPage"`). Non-source-text paragraphs (title, info boxes, task headings) use `w:suppressLineNumbers`. The teacher controls per-paragraph suppression at material creation time.

5. **Slides template**: A `.pptx` template with school branding (colors, logo). 4 slide masters: TITLE, CONTENT, SECTION, BLANK. Branding is resolved from `school-config.json`.

6. **Dynamic generation:** The plugin ships a neutral fallback `template_slides.pptx` (education blue `#2B579A`, no logo). When branding is configured — during `/thalura:setup` or via `/thalura:config school` — a school-branded version is generated and stored in the project data folder (`<WORKSPACE_ROOT>/data/templates/materials/template_slides.pptx`). The material generator checks the project path first, then falls back to the plugin bundle.

---

## Word Templates

### Template files

| File | Material type | Difference from worksheet |
|---|---|---|
| `template_worksheet.docx` | Arbeitsblatt | Base template |
| `template_handout.docx` | Handout | Identical copy (differences are in generated content, not template chrome) |
| `template_reading_text.docx` | Lesetext | Worksheet + section-level line numbering (every 5th line) |

### Named styles

| Style ID | `w:name` | Purpose | Key properties |
|---|---|---|---|
| `Normal` | Normal | Body text default | Arial 11pt, spacing after 160, line 278 |
| `Titel` | Titel | Material title | Arial 14pt bold centered, spacing after 360, line 240, letter-spacing -10, kern 28 |
| `Aufgabe` | Aufgabe | Task heading | Arial 11pt bold, spacing before 160, keepNext |
| `Kopfzeile` | Kopfzeile | Header text | Arial 8pt, spacing after 0, line 240 |
| `Fußzeile` | Fußzeile | Footer text | Arial 8pt, spacing after 0, line 240 |

**Built-in vs custom styles:** `Normal` is a built-in style (Word recognizes `w:name="Normal"` regardless of UI language). `Titel` maps to Word's built-in "Title" style in German locales. `Kopfzeile` and `Fußzeile` map to Word's built-in "Header" and "Footer" styles. `Aufgabe` is a custom style (`w:customStyle="1"`) — it has no built-in equivalent and keeps its name in all locales.

### Page setup

| Property | Value |
|---|---|
| Paper size | A4: 11906 × 16838 DXA |
| Margin top | 1417 DXA (~2.5 cm) |
| Margin bottom | 1134 DXA (~2.0 cm) |
| Margin left | 1417 DXA (~2.5 cm) |
| Margin right | 1417 DXA (~2.5 cm) |
| Header distance | 567 DXA (~1 cm) from top edge |
| Footer distance | 567 DXA (~1 cm) from bottom edge |
| Gutter | 0 |
| Content width | 9072 DXA (page width minus left and right margins) |

### Header

2-column table (8572 / 500 DXA) with bottom rule, followed by 1pt spacer paragraph.

| Cell | Content | Style |
|---|---|---|
| Left | `{{SUBJECT}}  \|  {{COURSE}}  \|  {{TEACHER_ABBR}}  \|  {{UNIT_TITLE}}` | Kopfzeile |
| Right | `{{MATERIAL_NO}}` | Kopfzeile (right-aligned) |

### Footer

2-column borderless table (8572 / 500 DXA) followed by 1pt spacer paragraph.

| Cell | Content | Style |
|---|---|---|
| Left | `{{DIFFERENTIATION}}` | Fußzeile |
| Right | PAGE / NUMPAGES (e.g. `1/2`) | Fußzeile (right-aligned) |

### Content elements

All content elements: Title, Name/Date line, Info box, Task heading, Task instruction, Comparison table, Writing lines, Image placeholder with APA7 footnotes. Task heading uses `style: "Aufgabe"`, Title uses `style: "Titel"`.

The generated document content is injected at the `{{BODY_CONTENT}}` placeholder — the single content-body injection point present in every material template (and every planning template). The generator replaces `{{BODY_CONTENT}}` with the assembled content elements above.

### Line numbering (reading text only)

The `template_reading_text.docx` template adds section-level line numbering:

```xml
<w:lnNumType w:countBy="5" w:restart="newPage"/>
```

Paragraphs that should NOT show line numbers (title, info boxes, task headings, task instructions) use:

```xml
<w:pPr>
  <w:suppressLineNumbers/>
</w:pPr>
```

The material generator controls `suppressLineNumbers` per paragraph based on teacher input during material creation. By default, only source text (the reading passage) has line numbers active.

---

## Planning Document Templates

Planning documents (unit plan, lesson plan, material overview, reflection) use `.docx` templates with `{{DOUBLE_BRACES}}` placeholders, following the same pattern as material templates.

### Template files

| File | Document type | Notes |
|---|---|---|
| `template_unit_plan.docx` | Unit plan (Einheitenplanung) | Two-section layout: cover page + content |
| `template_lesson_plan.docx` | Lesson plan (Verlaufsplan) | Single section |
| `template_reflection.docx` | Reflection (Reflexion) | Single section |
| `template_material_overview.docx` | Material overview (Materialübersicht) | Single section |
| `template_year_overview.docx` | Year overview (Schuljahresübersicht) | Single section; workspace-root placement |

All planning templates are located in `${CLAUDE_PLUGIN_ROOT}/templates/planning/`.

### Placeholders

Each planning template carries per-document title and cover-page placeholders that the generator fills at generation time, plus the shared `{{BODY_CONTENT}}` content-body injection point (the section-2 content described under [Unit plan two-section layout](#unit-plan-two-section-layout)) and the AI-notice placeholders (see [AI generation notice](#ai-generation-notice-erstellungshinweis)).

| Placeholder | Template | Fills |
|---|---|---|
| `{{BODY_CONTENT}}` | All planning documents | Generated content body (section-2 content) |
| `{{LESSON_TITLE}}` | Lesson plan | Lesson-plan document title |
| `{{REFLECTION_TITLE}}` | Reflection | Reflection (Reflexion) document title |
| `{{MATERIAL_OVERVIEW_TITLE}}` | Material overview | Material-overview document title |
| `{{YEAR_OVERVIEW_TITLE}}` | Year overview | Year-overview document title |
| `{{SCHOOL_YEAR}}` | Year overview | Header school year (the year plan's `YYYY-YY` value) |
| `{{RAHMENTHEMA}}` | Unit plan | Cover-page overarching theme (Rahmenthema) |
| `{{SCHWERPUNKTTHEMA}}` | Unit plan | Cover-page focus theme (Schwerpunktthema) |
| `{{SEMESTER}}` | Unit plan | Cover-page semester (Semester) |
| `{{DURATION}}` | Unit plan | Cover-page unit duration |
| `{{TEACHER_NAME}}` | Unit plan | Cover-page teacher name (full, not the header abbreviation) |

The unit plan's own document title reuses `{{UNIT_TITLE}}`; the `{{RAHMENTHEMA}}`, `{{SCHWERPUNKTTHEMA}}`, `{{SEMESTER}}`, `{{DURATION}}`, and `{{TEACHER_NAME}}` placeholders are the additional cover-page fields (see [Unit plan two-section layout](#unit-plan-two-section-layout)).

### Named styles

Planning templates share base styles with material templates but add heading styles for generated content. No `Aufgabe` style is used in planning documents.

| Style ID | `w:name` | Purpose | Key properties |
|---|---|---|---|
| `Normal` | Normal | Body text default | Arial 11pt, spacing after 160, line 278 |
| `Titel` | Titel | Document title | Arial 14pt bold centered, spacing after 360, line 240, letter-spacing -10, kern 28 |
| `Heading2` | Heading 2 | Section heading | Arial 13pt bold, keepNext, keepLines |
| `Heading3` | Heading 3 | Subsection heading | Arial 11pt bold, keepNext, keepLines |
| `Kopfzeile` | Kopfzeile | Header text | Arial 8pt, spacing after 0, line 240 |
| `Fußzeile` | Fußzeile | Footer text | Arial 8pt, spacing after 0, line 240 |

**Style deduplication:** docx-js injects default heading styles (Heading1–6) with blue colors before custom definitions. Validated templates already have clean styles. If templates are ever regenerated, the build script must post-process with `cleanDocx()` via JSZip to remove duplicate defaults. `keepNext` and `keepLines` must be set both in the style definition and inline on each heading paragraph.

### Page setup

Same as material templates: A4 (11906 × 16838 DXA), margins 1417/1134/1417/1417, content width 9072, header/footer distance 567.

### Header (planning documents)

2-column table (8572 / 500 DXA) with bottom rule, followed by 1pt spacer paragraph. Layout differs from material templates:

| Cell | Content | Style |
|---|---|---|
| Left | `{{SUBJECT}}  \|  {{GRADE}}  \|  {{TEACHER_ABBR}}` | Kopfzeile |
| Right | `{{GENERATION_DATE}}` | Kopfzeile (right-aligned) |

### Footer (planning documents)

2-column borderless table (8572 / 500 DXA) followed by 1pt spacer paragraph.

| Cell | Content | Style |
|---|---|---|
| Left | *(empty)* | Fußzeile |
| Right | PAGE / NUMPAGES (e.g. `1/2`) | Fußzeile (right-aligned) |

### AI generation notice (Erstellungshinweis)

Placed at the end of every planning document. The teacher can delete this block if desired.

1. **Separator:** Empty paragraph with 1pt `#CCCCCC` bottom border, spacing before 480
2. **Heading:** `{{AI_GENERATION_NOTICE_HEADING}}` — filled from the `ai_generation_notice_heading` localization key — Arial 8pt italic `#999999`
3. **Body:** `{{AI_GENERATION_NOTICE}}` — filled from the `ai_generation_notice` localization key — Arial 8pt italic `#999999`

No references to "Thalura", "Claude", or "Anthropic" in the notice text.

### Unit plan two-section layout

The unit plan template uses two OOXML sections:

| Section | Content | vAlign | Header/Footer |
|---|---|---|---|
| Section 1 | Cover page: `{{UNIT_TITLE}}`, `{{SUBJECT}}`, `{{GRADE}}`, `{{TEACHER_NAME}}`, `{{RAHMENTHEMA}}`, `{{SCHWERPUNKTTHEMA}}`, `{{SEMESTER}}`, `{{DURATION}}` | `center` | None (empty) |
| Section 2 | Content pages (competency overview, lesson overview, etc.) — injected at `{{BODY_CONTENT}}` | `top` | Standard planning header/footer |

Using `titlePg` in a single section does not work because `vAlign` applies to the entire section in Word. All other planning templates use a single section.

The cover-page section's `vAlign: center` (the first row of the table above) is the layout home for cover-page vertical centering: the content specification (`document-specifications.md`) records only that the cover page is the first page without header or footer, while its vertical placement is owned here.

### Content-table styling

The generated planning content tables — the competency overview (Kompetenzübersicht), the unit lesson overview, the lesson-plan phase table (Verlaufsplan), the two material-overview (Materialübersicht) tables, and the method-effectiveness table — are styled from `${CLAUDE_PLUGIN_ROOT}/references/design-tokens.json`. The content specification (`document-specifications.md`) owns only each table's semantic column identity (name and what it holds); every measurement, colour, and weight below is bound here by token key and never restated numerically.

**Shared table styling.** Every content table draws its header fill, header-row minimum height, bold and vertically-centered header cells, cell borders, horizontal cell padding, and body font and size from `tables.shared`. That block resolves through the `semantic` tier down to the `primitive` colour, spacing, border, and font values — so a single token edit restyles all content tables at once.

**Per-table column widths.** Each table's column widths (in twips, summing to the page content width) are carried under `tables.<id>.cols`:

| Content table | Token |
|---|---|
| Competency overview (Kompetenzübersicht) | `tables.competency_overview.cols` |
| Unit lesson overview | `tables.unit_lesson_overview.cols` |
| Lesson-plan phase table (Verlaufsplan) | `tables.verlaufsplan.cols` |
| Material overview (Materialübersicht) — generated materials | `tables.material_overview_generated.cols` |
| Material overview (Materialübersicht) — supplies | `tables.material_overview_supplies.cols` |
| Method effectiveness | `tables.method_effectiveness.cols` |
| Year overview — competency coverage (Kompetenzabdeckung) | `tables.year_overview_coverage.cols` |
| Year overview — units (Einheiten) | `tables.year_overview_units.cols` |

**Headings.** Generated section and subsection headings are realized by the named styles `Titel`, `Heading2`, and `Heading3` (defined for planning documents under *Named styles* above). Their point sizes derive from `primitive.size_word_halfpt` (keys `title` / `h2` / `h3`) and are not restated in the content specification, which keeps only the semantic heading level (document title, section, subsection).

**Content-emphasis conventions.** The following content-emphasis cues are realized here from the tokens' `emphasis` block, so the content specification states only the semantic intent:

| Convention | Where it applies | Token |
|---|---|---|
| Italic block quote | Unit objective and its guiding question (Leitfrage), rendered as an indented block quote | `emphasis.block_quote` |
| Italic guiding question | Phase guiding question (Phasen-Leitfrage) in the phase tables | `emphasis.guiding_question` |
| Sub-phase indent | Sub-phase (Sub-Phase) rows indented within their parent phase | `emphasis.sub_phase_indent_prefix` |
| Bold group-header row | Competency-overview (Kompetenzübersicht) group-header rows | `emphasis.group_header_row` |

`design-tokens.json` is the single value source for every binding in this section; downstream generators and templates read these tokens rather than inlining a colour, size, or width.

---

## Slides Template

### Template file

`template_slides.pptx` — a presentation with school branding (or neutral fallback).

### Branding

The plugin ships a neutral fallback template (education blue `#2B579A`, no logo). When branding is configured, Claude generates a school-branded version stored in the project data folder (`<WORKSPACE_ROOT>/data/templates/materials/template_slides.pptx`).

Colors and logo are resolved from `school-config.json` branding fields:

| Token | Neutral fallback | Source |
|---|---|---|
| `primary` | `#2B579A` | `school-config.branding.primary_color` |
| `secondary` | `#1A3259` | `school-config.branding.secondary_color` (or auto-derived: primary darkened 20%) |
| `accent` | `#8AABDE` | `school-config.branding.accent_color` (or auto-derived per the accent derivation rule) |
| `dark` | `#333333` | Hardcoded neutral |
| `light` | `#F5F5F5` | Hardcoded neutral |
| `logo_on_primary` | *(none)* | `school-config.branding.logo_path_on_primary` — white/light variant (transparent PNG) for dark backgrounds |
| `logo_on_white` | *(none)* | `school-config.branding.logo_path_on_white` — primary-colored variant (transparent PNG) for white backgrounds |

### Slide Dimensions

| Aspect Ratio | Width | Height | EMU Width | EMU Height | Notes |
|---|---|---|---|---|---|
| 16:10 (default) | 10" (25.4 cm) | 6.25" (15.875 cm) | 9144000 | 5715000 | Standard PowerPoint "Widescreen 16:10". Matches German school interactive whiteboards. |
| 16:9 | 13.333" (33.867 cm) | 7.5" (19.05 cm) | 12192000 | 6858000 | Standard PowerPoint "Widescreen". |

The active dimensions are resolved from `school-config.branding.slide_aspect_ratio` (default: `"16:10"`). The plugin-bundled neutral fallback uses 16:10. Not asked during setup — configurable via `/thalura:config school`.

### Bundled-Template Metadata Policy

Every bundled or freshly-generated `template_slides.pptx` (neutral fallback and per-school branded) MUST carry **neutral** `docProps` — regardless of which capability authored it:

| Field | Required value | Reason |
|---|---|---|
| `dc:creator` / `cp:lastModifiedBy` | **empty** | The output document sets the teacher name; a template must never pre-seed a real person's name. |
| `dc:title` / `dc:subject` | **empty** | The output document sets the real presentation title; kills any foreign-product title (e.g. a capability's default presentation name). |
| `app.xml` `Application` | **`Thalura`** | Mirrors the output contract's `Application` value as a safety net: a gate-miss on the output inherits the correct value rather than a library name. |
| `app.xml` `Company` | **empty** | The output document sets the school name; a template must never pre-seed a tool or library name. |

A freshly-built branded template must be born clean per this policy. The authoring capability's default `Application` (e.g. a library name) must not survive into the template binary. After generation, verify that `docProps/app.xml` and `docProps/core.xml` satisfy every row above; if the capability left a library fingerprint, correct the OOXML parts directly before storing the file.

See `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` for the full output-document contract.

### Manual-Change Detection

Before regenerating `template_slides.pptx` (triggered by branding or aspect ratio changes via `/thalura:config school`):

1. Compute the SHA-256 hash of the existing `<WORKSPACE_ROOT>/data/templates/materials/template_slides.pptx`
2. Compare against `school-config.branding.template_hash`
3. **Hashes match** (or no template exists): proceed with regeneration silently
4. **Hashes differ**: the teacher has manually modified the template — warn and ask for confirmation before overwriting
5. After regeneration, update `template_hash` with the new file's hash

This check does not apply during initial setup (Phase 2.5.3a) — only on subsequent config changes.

### Slide masters

| Master | Background | Logo | Logo variant | Footer | Use |
|---|---|---|---|---|---|
| TITLE | Primary color | Centered, large | `logo_on_primary` | School name bar (secondary) | Title slide |
| CONTENT | White | Top-right, small | `logo_on_white` | Subject \| Course + slide number (`{{SLIDE_NUMBER}}`) | Standard content |
| SECTION | Primary color | Top-right, small | `logo_on_primary` | None | Section dividers |
| BLANK | White | Top-right, small | `logo_on_white` | Slide number only (`{{SLIDE_NUMBER}}`) | Flexible layout |

If neither logo variant is configured, the logo position is left empty on all masters.

### Template slides

The template contains 4 slides (one per master) with placeholder text:

1. **TITLE**: `{{MATERIAL_TITLE}}`, `{{SUBJECT}} | {{COURSE}} | {{TEACHER_ABBR}}`
2. **SECTION**: `{{SECTION_NUMBER}}`, `{{SECTION_TITLE}}`, `{{SECTION_SUBTITLE}}`
3. **CONTENT**: `{{SLIDE_TITLE}}`, `{{SLIDE_CONTENT}}`
4. **BLANK**: `{{SLIDE_TITLE}}`, `{{SLIDE_CONTENT}}`

### Typography

| Element | Font | Size | Weight | Color | Accessibility mode override |
|---|---|---|---|---|---|
| Slide title | Arial | 28pt | Bold | `dark` (#333333) | Verdana 28pt |
| Slide body | Arial | 18pt | Normal | `dark` (#333333) | Verdana 20pt, line spacing 1.3x, paragraph spacing 8pt after |
| Title slide heading | Arial | 36pt | Bold | White | Verdana 36pt |
| Title slide subtitle | Arial | 16pt | Normal | White | Verdana 16pt |
| Section number | Arial | 48pt | Normal | `secondary` | Verdana 48pt |
| Section heading | Arial | 32pt | Bold | White | Verdana 32pt |
| Footer text | Arial | 9pt | Normal | `#AAAAAA` | Verdana 9pt |

The title-slide subtitle uses White (not `accent`): the accent colour is a decorative/large/UI token and must not carry body-size text — a 16pt-Normal subtitle is body-size and needs guaranteed contrast, which White provides on the primary-coloured title background.

### Slide Content Accessibility

When `slide_preferences.accessibility_mode` is `true` in `teacher-preferences.json` (default for all new setups), the following rules apply to all generated slide content:

| Rule | Accessibility default | Standard default |
|---|---|---|
| Font | Verdana | Arial |
| Body font size | ≥ 20pt | 18pt |
| Line spacing | ≥ 1.3x | unspecified (single) |
| Paragraph spacing | 8pt space after | unspecified |
| Emphasis style | Bold only (no italics) | unspecified |
| Max bullets per slide | 6 | unspecified |
| Text alignment | Left-aligned (no justified) | unspecified |

**Rationale:** Verdana has wider letter spacing and open letterforms, improving readability for students with dyslexia on classroom screens. Larger body text (20pt+) and wider line spacing (1.3x+) reduce visual crowding on interactive whiteboards.

**Cascade resolution:** The material generator resolves typography settings in this order: explicit teacher override in `slide_preferences` → accessibility mode defaults (if enabled) → template-spec defaults above.

Individual teacher overrides are always respected. For example, `accessibility_mode: true` + `body_font_size: 24` → 24pt wins.

### Student Task Deck layout

The student task deck (`asset_type: "student_task_deck"`) is a **persistent during-work projection display**: each slide is the standing instruction for one work phase, kept on the classroom screen for the whole duration of that activity so a student glancing up mid-task gets the full instruction without the teacher re-explaining. It reuses the existing masters with task-shaped content — **no new master is introduced**:

- **Master usage.** Uses the **CONTENT** master (white background, `{{SLIDE_TITLE}}` + `{{SLIDE_CONTENT}}`) for each task slide; optionally a TITLE slide for the lesson title and SECTION dividers between phases.
- **One slide per work phase / coherent task-set — *not* one task per slide.** Instructions that belong to the **same activity** sit **together on one slide**. Worked example: "work on the worksheet, then discuss with your right-hand neighbour" is **one** slide (one work phase, two coupled steps) — students do them as a single stretch of work. Split onto a new slide only when the lesson moves to a genuinely **new** work phase (a different activity, or a switch in social form that starts a new stretch of work). The rule is explicitly **not** "one task per slide".
- **Slide anatomy.** Slide title = the work-phase / activity name; body = the coupled instruction step(s) as a short bullet sequence; social form and timing as a footer-style line (timing included when the lesson phase has it, omitted cleanly when absent).
- **Operator-disciplined instructions.** Each task instruction uses the standardized Hamburg task operators (Operatoren) where didactically applicable — the same convention worksheet tasks already follow (the operator source is the subject's `document-registry.md` Layer 4 file). "Where didactically applicable" — a plain organisational instruction ("Form pairs") needs no operator; a cognitive task ("*Analyse* the cartoon's message") does.
- **Distraction-free.** No decorative imagery; large type; high contrast on white; left-aligned.
- **Accessibility honored.** The Slide Content Accessibility cascade above applies unchanged — the deck is a slide artifact, so `slide_preferences` (Verdana / ≥20pt / 1.3x / ≤6 bullets / bold-only / left-aligned) apply verbatim. The ≤6-bullet ceiling reinforces the phase-grouping rule: a coherent task-set exceeding six steps is a sign it should be split into its actual work phases.

---

## Output-Document Metadata

OOXML metadata (`dc:creator`, `cp:lastModifiedBy`, `dc:title`, `Application`, `Company`, timestamps) is governed by `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md`. It is set on the **output** document at write time — never inherited from the template that supplied the chrome. Templates carry only neutral placeholder values (see "Bundled-Template Metadata Policy" in the Slides Template section below); the full teacher-name and product-attribution contract applies to the output alone.

---

## Clean XML Policy

Templates generated with `docx-js` follow these rules:

1. **No RSIDs** — `w:rsidR`, `w:rsidRPr`, `w:rsidRDefault`, etc. are not generated (docx-js does not emit them)
2. **No latentStyles** — only actually-used styles appear in `styles.xml`
3. **No theme files** — no `theme1.xml` dependency; colors are hardcoded hex values
4. **Minimal `[Content_Types].xml`** — only entries for parts that exist
5. **No unnecessary namespaces** — though docx-js includes a standard set, no custom extensions are added

This policy ensures templates are human-readable when unpacked and maintainable without Word-specific tooling.
