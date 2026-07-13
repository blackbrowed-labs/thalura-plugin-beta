---
name: image-prompts
description: Bild-Prompt erstellen. Use when the teacher wants a STANDALONE image prompt (Bild-Prompt) to paste into an image generator — not images embedded within a worksheet.
when_to_use: |
  DE + EN: "Bild-Prompt", "Prompt für ein Bild", "Bildbeschreibung erstellen", "image prompt", "illustration prompt". Standalone prompt only; images inside a material are produced by material-gen.
---

# Eleven's Vision (`generate_image_prompts`) — Image Generation Prompts

> Core protocols — startup, HiTL/draft lifecycle, preferences, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).
>
> Before writing the `_{draft_suffix}` to disk (Step 4), the internal compliance gate runs a Sacred Texts quick-check. Load `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` for the full 8-step flow at the draft/validation step.

Creates detailed natural-language prompts for Gemini's Nano Banana image generation models. When this task runs as part of material generation, the full English prompt is persisted in the material's `plan.json` image entry — the single source of truth for the prompt; any copy embedded in the document (a Word comment or slide note) is a convenience duplicate, not the source. When run on its own (a standalone image prompt with no material), the prompt is presented in chat and stored in the lesson file. When no image-generation tool is connected, the teacher generates images via the Gemini web interface at gemini.google.com.

---

## Required Inputs

| Parameter | Type | Required | Example |
|-----------|------|----------|---------|
| `context` | Object/File | yes | Lesson file, material file, or unit context (see Context Sources) |
| `image_purpose` | String | yes | "Illustration for worksheet on neighbourhood vocabulary" |
| `text_in_image` | String | no | Exact text to render in the image, in the applicable content language |
| `constraints` | String | no | "Age-appropriate for 10-year-olds" |
| `print_optimized` | Boolean | no | Default from `material_preferences.copier_safe` in teacher-preferences.json |

**Style** is not a teacher-provided input. Claude recommends the best style from the Style Catalog based on context. The teacher can override or request a specific style.

---

## Context Sources

The skill always needs to understand both *what the image shows* and *what output it's for* (to determine text language via the content language fallback chain).

| Invocation Path | Primary Context | Supporting Context | Output Type Source |
|---|---|---|---|
| From The Upside Down | Lesson file in `{lessons}/` | Unit plan ({unit_plan}), class definition | Material table in the lesson file (M01 = worksheet, etc.) |
| From The Playbook | Material being created **+ lesson file** | Unit plan ({unit_plan}) (unit scope, topic) | Known — the material's `asset_type`. **Programmatic path**: prompt is returned to material-gen, not presented separately. |
| From The Multiverse | Differentiated variant + source material | Lesson file, class definition (special needs) | Same as source material's type |
| Standalone — with file reference | Teacher-referenced file | Unit folder context (unit plan ({unit_plan}), lesson files) | Infer from referenced file, ask if ambiguous |
| Standalone — free text | Teacher's description | Current subject/grade from session | Ask the teacher |

**Key rule:** When invoked from The Playbook, always read BOTH the material context AND the lesson file it belongs to. The image must fit the pedagogical flow, not just the worksheet content.

**Programmatic invocation from The Playbook:** When The Playbook invokes Eleven's Vision internally for image-aware material generation, the workflow differs from standalone use:
- The teacher already approved the image description during The Playbook's proposal (Step 11) — no separate approval cycle within Eleven's Vision
- Eleven's Vision generates the full 10-component prompt from the approved description and returns it programmatically to material-gen
- The prompt is not presented as a separate chat proposal — it is embedded directly as a Word comment in the generated material
- All other rules apply: style selection, model recommendation, print optimization, content language resolution for text in images

**Special needs context:** When the class definition includes special needs (LRS, DaZ), consider: high contrast needs, vocabulary labels, simplified visuals, additional visual cues.

---

## Style Catalog

Claude recommends the best style based on pedagogical context, output purpose, subject, and grade level. The teacher can always override with any style or free-text description.

| Style | Best For | Example Prompt Opener |
|---|---|---|
| Photorealistic | Discussion starters, real-world scenarios, cultural contexts | "A photorealistic close-up of..." |
| Children's book illustration | Sek I worksheets, storytelling, vocabulary | "A warm digital illustration in a children's book style..." |
| Vector / flat design | Infographics, diagrams, process visualizations | "A clean vector infographic with..." |
| Watercolor | Creative writing prompts, poetry, atmospheric scenes | "A loose watercolor painting of..." |
| Comic / sequential art | Dialogue practice, narrative sequences, story prompts | "A comic panel in a clean ligne claire style..." |
| Minimalist / negative space | Text-heavy worksheets (leave space for text), icons | "A minimalist composition featuring..." |
| Oil painting / classical | Art history, philosophy (ethical dilemmas), religion | "An oil painting in the style of Dutch Golden Age masters..." |
| Collage / mixed media | Media analysis, cultural studies, creative projects | "A mixed-media collage combining..." |

**Selection factors:** purpose (worksheet vs slide vs discussion starter), subject (language vs philosophy vs religion), grade level (Sek I vs Sek II), print optimization needs (copier-safe → high contrast styles).

---

## Model Recommendation

When no image-generation tool is connected, images are generated via the **Gemini web interface** (gemini.google.com), not via API. Technical parameters like aspect ratio and resolution must be specified within the prompt text itself.

When a conforming image-generation tool is connected and the capability gate is open, image generation runs automatically during material generation — see `${CLAUDE_PLUGIN_ROOT}/references/image-generation-contract.md` for the contract. The prompt this skill produces is identical in both cases; it is never rewritten for the tool path.

| Model | Internal Name | Best For | Gemini Setting |
|---|---|---|---|
| **Nano Banana 2** (DEFAULT) | Gemini 3.1 Flash Image Preview | Standard illustrations, worksheets, text rendering, decorative images, style transfers | Tools → Create Images → **Fast** |
| **Nano Banana Pro** | Gemini 3 Pro Image Preview | Complex infographics, data visualizations, search grounding, 14+ reference images, character consistency across series | Tools → Create Images → **Pro** |

**Default: Always recommend Nano Banana 2.** Text rendering is accurate with this model — no escalation needed for text alone.

**Escalate to Nano Banana Pro only when:**
- Complex infographics or data visualizations requiring precise layout
- Factual accuracy via Google Search grounding (e.g., real-world data in the image)
- Complex multi-element scenes with many reference images (up to 14)
- Character consistency across multiple images in a series

---

## Resolution and Aspect Ratio

Both must be specified as explicit text instructions in the prompt (web interface cannot set them programmatically).

**Resolution:** Always include `"4K resolution."` in the prompt. Available tiers: 512px, 1K (default if omitted), 2K, 4K. Uppercase "K" required.

**Aspect ratio:** Always specify explicitly based on output purpose:

| Use Case | Aspect Ratio | Prompt Instruction |
|---|---|---|
| Worksheet / A4 print (portrait) | 3:4 | `"Aspect ratio 3:4 (portrait)."` |
| Worksheet / A4 print (landscape) | 4:3 | `"Aspect ratio 4:3 (landscape)."` |
| Presentation slides | 16:9 | `"Aspect ratio 16:9 (landscape)."` |
| Square (icons, thumbnails) | 1:1 | `"Aspect ratio 1:1 (square)."` |
| Vertical poster / mobile | 9:16 | `"Aspect ratio 9:16 (vertical)."` |
| Ultrawide banner | 21:9 | `"Aspect ratio 21:9 (ultrawide)."` |

**Note on slide aspect ratio:** The PPTX slide dimensions may be 16:10 (default, per `school-config.branding.slide_aspect_ratio`). However, image generation models do not support 16:10. Images for slides always use **16:9** — the closest supported ratio. The minor difference (16:10 = 1.6:1, 16:9 ≈ 1.78:1) means images will be slightly narrower than the full slide area. This is preferable to stretching or distortion.

**Supported aspect ratios:**
- Nano Banana 2: 1:1, 1:4, 1:8, 2:3, 3:2, 3:4, 4:1, 4:3, 4:5, 5:4, 8:1, 9:16, 16:9, 21:9
- Nano Banana Pro: 1:1, 2:3, 3:2, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9, 21:9

---

## Logic (Step by Step)

1. **Analyze the pedagogical context:**
   - Read the context source(s) per the Context Sources table
   - What is the lesson/material about? What specific content must the image convey?
   - What role does the image play (illustration, stimulus, discussion starter, decoration)?
   - Determine the output type (worksheet, slide, handout) for language resolution

2. **Select style** from the Style Catalog based on purpose, subject, grade, and print needs.

3. **Determine model recommendation** — Nano Banana 2 (default) unless infographics, search grounding, or character consistency is needed.

4. **Determine aspect ratio** from the output purpose (worksheet → 3:4 portrait, slide → 16:9, etc.).

5. **Generate the prompt** in natural language with all 10 mandatory components woven into descriptive narration. Describe the scene — don't just list keywords. But still be very specific about what objects are in the scene, what they look like, and where they are placed.

   Every prompt must contain ALL of these components:

   1. **Technical settings** (first line): Aspect ratio instruction + `"4K resolution."`
   2. **Style / medium**: Art style and visual approach from the Style Catalog selection.
   3. **Subject + action + appearance**: Who/what is the focus, what are they doing, what do they look like. Be specific: clothing, expression, posture, colors, textures.
   4. **Object inventory with placement**: List all important objects, describe their look (shape, color, material, size) and spatial position (foreground, background, left side, bottom-right, etc.).
   5. **Environment / context**: Setting, spatial layout, atmosphere, surrounding elements.
   6. **Composition / camera**: Viewpoint, framing, angle, depth of field. E.g., "Captured with an 85mm portrait lens, resulting in a soft, blurred background (bokeh)" or "A slightly elevated 45-degree shot."
   7. **Lighting**: Source, direction, color, mood. E.g., "Soft, golden hour light streaming through a window" or "Dramatic chiaroscuro lighting."
   8. **Color palette**: Dominant tones, or "High contrast, grayscale-safe palette" for print.
   9. **Text in image**: If needed — specify exact wording in the applicable content language (see Localization Rules), font style description, size, placement, color. If not needed — include `"No text in the image."` explicitly.
   10. **Exclusions**: Inline semantic negatives calibrated to the specific image (see Exclusion Calibration). E.g., "No visible logos or brand names. Avoid stereotypical representations. No additional text beyond the specified label."

6. **Apply print optimization** if `print_optimized = true` (see Print Optimization).

7. **Create the proposal** and present to the teacher in chat.

---

## No Pedagogical Intent in the Prompt

Image generation models cannot interpret abstract pedagogical instructions. Do NOT include:
- "The student should learn X from this image"
- "This supports competency Y"

Instead, translate intent into concrete visual elements:
- Instead of "supports vocabulary learning" → describe the specific objects that should be labeled or visible
- Instead of "stimulates discussion about justice" → describe a scene depicting an injustice scenario

---

## Exclusion Calibration

Exclusions are woven into the prompt as inline semantic negatives — not as a separate block. Calibrate to the specific image, not as a blanket list:

| Element | Exclude when... | Allow when... |
|---------|-----------------|---------------|
| National flags / insignia | The image is generic and flags would imply a specific political context | The scene depicts a real institution where flags are naturally present (e.g., UN, embassy) |
| Logos / emblems | They would constitute product placement or distract | They are part of the depicted institution's identity (e.g., UN emblem, Red Cross) |
| Readable text / slogans | Text would be garbled by the model or is not relevant | The scene depicts protests, signage, or classrooms where text is part of the reality |
| Real people (historical or public figures) | The style is photorealistic — could create misleading imagery | The style is clearly non-photographic (illustration, oil painting, etc.) |
| Graphic violence / gore | Always in educational contexts | — |

When in doubt, prefer authenticity over sanitization.

---

## Reference Prompts

Examples from official Google documentation, extended to demonstrate all 10 mandatory components. Use these as style reference when generating prompts.

### Photorealistic Scene

> **[1: Technical]** Aspect ratio 3:4 (portrait). 4K resolution. **[2: Style]** A photorealistic close-up portrait **[3: Subject]** of an elderly Japanese ceramicist with deep, sun-etched wrinkles and a warm, knowing smile. He is carefully inspecting a freshly glazed tea bowl. **[4: Objects]** The tea bowl is a deep indigo blue with a crackled glaze finish, held gently in both hands at chest height. His apron is a worn linen fabric with dried clay dust. **[5: Environment]** The setting is his rustic, sun-drenched workshop with pottery wheels and shelves of clay pots visible in the soft background. **[6: Camera]** Captured with an 85mm portrait lens, resulting in a soft, blurred background (bokeh). **[7: Lighting]** Soft, golden hour light streaming through a window, highlighting the fine texture of the clay and the fabric of his apron. **[8: Color palette]** Warm earth tones — ochre, terracotta, indigo, and cream. **[9: Text]** No text in the image. **[10: Exclusions]** No visible logos or brand names. Avoid stereotypical representations.

### Stylized Illustration

> **[1: Technical]** Aspect ratio 1:1 (square). 4K resolution. **[2: Style]** A kawaii-style sticker design with bold, clean outlines and simple cel-shading. **[3: Subject]** A happy red panda sitting upright, wearing a tiny bamboo hat. It is munching on a green bamboo leaf. **[4: Objects]** The bamboo hat is light green with a woven texture, tilted slightly to the right. The bamboo leaf extends from the panda's right paw to its mouth. Two small bamboo stalks frame the panda on left and right. **[5: Environment]** White background — no environment, sticker-style isolation. **[6: Camera]** Frontal view, centered composition, flat perspective (no depth). **[7: Lighting]** Even, flat lighting with no shadows — sticker aesthetic. **[8: Color palette]** Vibrant: red-orange panda fur, bright green bamboo, white background, black outlines. **[9: Text]** No text in the image. **[10: Exclusions]** No background elements. No extra characters.

### Product / Studio Shot

> **[1: Technical]** Aspect ratio 1:1 (square). 4K resolution. **[2: Style]** A high-resolution, studio-lit product photograph. **[3: Subject]** A minimalist ceramic coffee mug in matte black, presented on a polished concrete surface. Steam rises gently from the coffee inside. **[4: Objects]** The mug is cylindrical with clean lines and no handle, positioned center-frame. A single coffee bean rests on the concrete surface to the left of the mug. **[5: Environment]** Clean studio backdrop in neutral grey, polished concrete platform. **[6: Camera]** A slightly elevated 45-degree shot to showcase the mug's clean lines. Sharp focus on the steam and mug rim. **[7: Lighting]** A three-point softbox setup designed to create soft, diffused highlights and eliminate harsh shadows. **[8: Color palette]** Matte black, warm grey concrete, white steam, neutral grey backdrop. **[9: Text]** No text in the image. **[10: Exclusions]** No brand logos. No background distractions.

### Text-Heavy / Logo (use Nano Banana Pro)

> **[1: Technical]** Aspect ratio 1:1 (square). 4K resolution. **[2: Style]** A modern, minimalist logo design. **[3: Subject]** A logo for a coffee shop called "The Daily Grind." **[4: Objects]** The text "The Daily Grind" in a clean, bold, sans-serif font, placed inside a circle. A stylized coffee bean is integrated cleverly into the letter "D". **[5: Environment]** Plain white background. **[6: Camera]** Flat, frontal view — logo design perspective. **[7: Lighting]** Even, flat lighting — no shadows or depth effects. **[8: Color palette]** Black and white only — monochrome. **[9: Text]** The text reads "The Daily Grind" in bold sans-serif, approximately 40% of the circle diameter. **[10: Exclusions]** No gradients. No additional decorative elements outside the circle.

### Sequential Art / Comic (use Nano Banana Pro)

> **[1: Technical]** Aspect ratio 16:9 (landscape). 4K resolution. **[2: Style]** A 3-panel comic in a gritty, noir art style with high-contrast black and white inks. **[3: Subject]** A detective character in a trench coat, placed in a humorous scene discovering his coffee has been stolen. **[4: Objects]** Panel 1: the detective's desk with an empty coffee mug, a stack of case files, and a desk lamp. Panel 2: close-up of the detective's shocked face, one eyebrow raised. Panel 3: a cat sitting on the windowsill licking its paw, the coffee mug beside it. **[5: Environment]** A dimly lit detective office with venetian blinds casting striped shadows. **[6: Camera]** Panel 1: medium shot. Panel 2: close-up. Panel 3: wide shot with window framing. **[7: Lighting]** Dramatic film noir lighting — harsh desk lamp in panel 1, dramatic shadows across the face in panel 2, backlit window in panel 3. **[8: Color palette]** Pure black and white with grey halftone shading. **[9: Text]** No text in the image. **[10: Exclusions]** No color. No speech bubbles (teacher adds text separately).

### Minimalist / Negative Space

> **[1: Technical]** Aspect ratio 3:4 (portrait). 4K resolution. **[2: Style]** A minimalist composition with significant negative space. **[3: Subject]** A single, delicate red maple leaf. **[4: Objects]** The leaf is positioned in the bottom-right of the frame, slightly curled at the edges, with visible veins and a gradient from deep red at the stem to bright scarlet at the tips. **[5: Environment]** A vast, empty off-white canvas — no other elements, leaving space for text overlay. **[6: Camera]** Overhead macro shot, flat perspective. **[7: Lighting]** Soft, diffused lighting from the top left, casting a very subtle shadow to the bottom-right. **[8: Color palette]** Off-white background (#F5F5F0), deep red to scarlet leaf, warm grey shadow. **[9: Text]** No text in the image. **[10: Exclusions]** No additional objects. No background texture.

---

## Print Optimization

When `print_optimized = true`, include in the prompt:

> "High contrast with clear, bold lines. Use a grayscale-safe color palette — no fine color gradations or pastel tones. Optimized for black-and-white printing."

Default value is read from `material_preferences.copier_safe` in teacher-preferences.json.

---

## Localization Rules

| Element | Language | Source |
|---|---|---|
| **Prompt text** | Always English | Image models perform best with English prompts |
| **Text rendered in image** | Content language fallback chain | `content_language.{output_type}` → `target_language` → `content_language_default` → `conversation_language` (see `${CLAUDE_PLUGIN_ROOT}/skills/core/content-language-gendering.md`) |
| **Proposal format** | `conversation_language` | From teacher-profile.json |
| **Source citation block** | `conversation_language` | From teacher-profile.json |

### Content language fallback for text in images

Text rendered *inside* an image follows the canonical 4-step content-language fallback chain in the core satellite `${CLAUDE_PLUGIN_ROOT}/skills/core/content-language-gendering.md` (`content_language.{output_type}` → `target_language` → `content_language_default` → `conversation_language`). Determine the output type from context, then resolve via that chain. The **prompt text itself is always English** regardless of the resolved content language (image models perform best with English prompts).

The English prompt must specify the exact text to render in the resolved language. Example: if the resolved language is `"de"`, the prompt says: `"The label reads 'Nachbarschaft' in a clean, sans-serif font at the top of the image."`

---

## Proposal Format

```
Image prompt for: Lesson {lesson_number}, {context}
Purpose:          {image_purpose}
Print-optimized:  {yes/no}

━━━ Model Recommendation ━━━
Recommended model: Nano Banana 2 (Fast)
Rationale:         {rationale}
Gemini setting:    Tools → Create Images → Model: Fast

━━━ Prompt (English) ━━━
[Full prompt in natural language — begins with aspect ratio and resolution
instruction, followed by descriptive scene narration covering all 10 mandatory
components: style, subject, objects with placement, environment, camera,
lighting, color palette, text in image, and inline exclusions.
One continuous text block. Language: always English.
Text rendered in image: in the resolved content language.]

━━━ Technical Details ━━━
Aspect ratio:      {e.g., 3:4 (portrait)}
Resolution:        4K
Text language:     {resolved language or "no text"}
Print optimization:{details or "none"}

━━━ Source Citation (complete after image generation) ━━━
Model:           [Enter model used]
Provider:        Google (gemini.google.com)
Creation date:   [Enter date]
Prompt used:     "[Prompt]"
Label:           Created using AI
```

The proposal is output in `conversation_language`. The template above shows the English structure; localized labels are resolved via `localization.json`.

---

## Source Citation

Every proposal includes a source citation template for the teacher to complete after generating the image. This follows academic guidelines for AI-generated images.

### Citation Template (in `conversation_language`)

```
Source citation for AI-generated image:
─────────────────────────────────────────
Model:           [e.g., Nano Banana 2 (Gemini 3.1 Flash Image Preview)]
Provider:        Google (gemini.google.com)
Creation date:   [YYYY-MM-DD]
Prompt used:     "[Full English prompt]"
Purpose:         [e.g., "Illustration for neighbourhood vocabulary worksheet"]
Label:           Created using AI
```

Localized labels are resolved via `localization.json`.

### Citation Styles

```
APA 7:
  Google. ([Year]). Gemini ([Model version]) [AI image generator]. https://gemini.google.com

MLA 9:
  "[Prompt description]" Prompt. Gemini, [Model version], Google, [Date], gemini.google.com.

Chicago 18:
  Image created with Google's Gemini [Model version], [Date], using the prompt "[Prompt]."
```

**Sources for citation guidelines:**
- MLA Style Center: "How do I cite generative AI in MLA style?" (updated Aug. 2025)
- APA Style Blog: How to cite ChatGPT / AI-generated content
- Chicago Manual of Style, 18th edition: Citing AI-generated images

---

## Known Limitations

- **Factual accuracy:** Data-based visualizations (charts, infographics) must always be manually verified
- **Multilingual text:** Grammar errors or missing cultural nuances possible in non-English text
- **Character consistency:** Mostly reliable, but can vary across sequential edits
- **Complex edits:** Blending or lighting changes can produce unnatural artifacts
- **SynthID watermark:** All generated images contain an invisible SynthID watermark

---

## After Approval

1. **Store the prompt.** When invoked from material generation, return the full prompt so material-gen persists it into the material's `plan.json` image entry (the single source of truth) — and, as a convenience copy, into the document (Word comment / slide note). When invoked standalone (no material), store it in the lesson file and present it in chat.
2. **Update observations** (continuous): Style preferences, print optimization defaults

---

## Notes

- The prompt output language is always English (image models perform best with English prompts). Only text rendered *inside* the image uses the resolved content language.
- Eleven's Vision does not generate images — it generates prompts for the Gemini web interface at gemini.google.com.
- Multiple image prompts can be created per lesson.
- All generated images contain an invisible SynthID watermark identifying them as AI-generated.
