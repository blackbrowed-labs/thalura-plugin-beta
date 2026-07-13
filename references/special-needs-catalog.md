# Special-Needs Catalog (Förderbedarfs-Katalog)

This catalog is the authoritative source for the recognized special learning needs (Förderbedarfe) a class may carry, their category codes, and the standard differentiation measures (Maßnahmen) the skills apply. It is read by the class-definition interview in the core skill, by differentiation (Differenzierung) when it adapts material, by material generation when it produces differentiated variants, and by the differentiation sections of unit and lesson plans.

The codes defined here are the authoritative vocabulary for the class-definition schema: the lowercase code is the `special_needs[].type` enum value, and the English accommodation keys listed per category are the `special_needs[].accommodations[]` vocabulary. The English keys are the stable identifiers; their localized display text (German and English) lives in the `special_needs_accommodations` block of `${CLAUDE_PLUGIN_ROOT}/references/localization.json` and is resolved at runtime to the active conversation language. The English description after each key in this catalog summarizes what the key means; it is not the display string the teacher sees. The differentiation and material skills' inline measure tables and the category table in `${CLAUDE_PLUGIN_ROOT}/references/glossary-de.md` are summaries of this catalog and stay consistent with it.

## Two kinds of measure

Two distinct kinds of measure appear in this catalog, and the distinction matters for how each is applied and justified:

- **Accommodations (Nachteilsausgleich)** — a legally defined accommodation that levels access to the task without lowering the standard or the cognitive demand. A student with a recognized need is given a different *route* to the same expectation (more time, a larger font, an oral alternative), never an easier expectation. The accommodation compensates for a disadvantage; it does not change what is assessed.
- **Support / internal differentiation (Förderung / Binnendifferenzierung)** — pedagogical differentiation within the lesson that adjusts depth, scaffolding, or enrichment for a learner. This is not compensation for a disadvantage but a teaching response — extension tasks for a gifted learner, language scaffolding for a second-language learner, a clearer structure for a learner who needs one.

Some categories draw on both: the accommodation levels access in assessment, while internal differentiation (Binnendifferenzierung) shapes the everyday lesson. Each category section names which kind(s) apply.

Hamburg's legal accommodation (Nachteilsausgleich) framework is set out in the official exam regulations: `${CLAUDE_PLUGIN_ROOT}/regulations/hamburg/shared/cross-subject/apo-ah.pdf` for Sek II and the Abitur, and `${CLAUDE_PLUGIN_ROOT}/regulations/hamburg/shared/cross-subject/apo-grundstgy.pdf` for Sek I. This catalog names the framework plainly; the skills do the regulation-level citation at audit time.

## Category index

| Code | Förderschwerpunkt (German category name) | English | One-line summary |
|------|------------------------------------------|---------|------------------|
| ADHS | Aufmerksamkeitsdefizit-Hyperaktivitätsstörung | attention-deficit/hyperactivity disorder | Shorter, clearly structured phases; visual markers; movement breaks |
| LRS  | Lese-Rechtschreib-Schwäche | reading and spelling difficulty | Larger font, reduced text density, extended time, oral alternatives |
| HB   | Hochbegabung | giftedness | Extension tasks, advanced sources, open research — enrichment, not compensation |
| DaZ  | Deutsch als Zweitsprache | German as a second language | Bilingual glossary, simplified instructions, visual scaffolding, sentence starters |
| ASS  | Autismus-Spektrum-Störung | autism spectrum disorder | Predictable structure, written instructions, defined roles, reduced sensory load |
| KB   | Körperliche Beeinträchtigung | physical impairment | Digital alternatives, flexible layout, extended time, barrier-free materials |
| SB   | Sehbeeinträchtigung | visual impairment | Large print, high contrast, verbal descriptions, accessible documents |
| AUD  | Auditive Beeinträchtigung (Hörbeeinträchtigung) | hearing impairment | Visual instructions, written task cards, reduced audio, transcripts |

The uppercase codes are the display forms used in conversation, in the glossary, and in the differentiated-file name suffix. The lowercase forms below are the `special_needs[].type` enum values stored in the class definition.

---

## Attention-Deficit/Hyperactivity Disorder (Aufmerksamkeitsdefizit-Hyperaktivitätsstörung, ADHS)

**Code (`special_needs[].type`):** `adhs` — lowercase form used in the class definition.
**What it is:** A recognized priority area of support (Förderschwerpunkt) affecting attention regulation, impulse control, and activity level. Concentration over long, undivided stretches is hard to sustain; clear structure and movement help the student engage.
**Kind of measure:** Accommodations (Nachteilsausgleich) in assessment (e.g. extended time) combined with internal differentiation (Binnendifferenzierung) in the everyday lesson.

**Differentiation measures (Maßnahmen):**
- Break tasks into short, self-contained blocks of roughly fifteen minutes, each with a single clear goal.
- Give a clear, predictable lesson structure with the sequence of steps visible in advance.
- Use visual phase markers and checklists so progress is trackable at a glance.
- Plan short movement breaks between blocks to release energy and re-focus.
- Reduce distracting elements in the material and on the page; keep the layout calm.
- Where a recognized accommodation applies, allow extended time in assessment without changing the task.

**Accommodation keys (`special_needs[].accommodations[]`):**
- `chunked_tasks` — tasks split into short, self-contained blocks (about 15 minutes) each with a single goal.
- `clear_structure` — a clear, predictable lesson structure with the sequence of steps visible in advance.
- `visual_markers` — visual phase markers and checklists for orientation.
- `movement_breaks` — short movement breaks between the work blocks.
- `extended_time` — extended working time in the assessment situation on the same task.

---

## Reading and Spelling Difficulty (Lese-Rechtschreib-Schwäche, LRS)

**Code (`special_needs[].type`):** `lrs` — lowercase form used in the class definition.
**What it is:** A recognized priority area of support (Förderschwerpunkt) affecting reading and spelling, while reasoning and comprehension are unaffected. The student needs the text made accessible, not the thinking made easier.
**Kind of measure:** Accommodations (Nachteilsausgleich) — access is levelled, the cognitive demand stays the same.

**Differentiation measures (Maßnahmen):**
- Allow extended time so reading and writing load do not crowd out the thinking task.
- Do not let spelling lower the mark where spelling is not the assessed competency, in line with the LRS rule.
- Use a larger font (at least 14 pt) and a clear, readable typeface.
- Reduce text density and give a generous, well-spaced layout.
- Offer an oral or audio alternative where the format allows, keeping the same task and demand.

**Accommodation keys (`special_needs[].accommodations[]`):**
- `extended_time` — extended working time for the reading and writing portions.
- `spell_check_allowed` — spelling is not factored into the mark where it is not the assessed competency.
- `larger_font` — a larger font (at least 14 pt) and a clearly readable typeface.
- `reduced_text_density` — lower text density and a generous, well-spaced layout.
- `oral_alternative` — an oral or audio alternative at the same task and the same demand.

---

## Giftedness (Hochbegabung, HB)

**Code (`special_needs[].type`):** `hb` — lowercase form used in the class definition.
**What it is:** A recognized priority area of support (Förderschwerpunkt) for a learner whose capacity clearly exceeds the standard expectation. The need is for depth and challenge, not for a disadvantage to be compensated.
**Kind of measure:** Support / internal differentiation (Förderung / Binnendifferenzierung) — enrichment on top of the core tasks, not an accommodation in the legal sense.

**Differentiation measures (Maßnahmen):**
- Add extension tasks at a higher cognitive-demand level on top of the core tasks, not instead of them.
- Provide advanced source texts that reward closer and more independent reading.
- Pose open-ended research or transfer questions that invite the student to go further.
- Favour depth and acceleration over more of the same volume.

**Accommodation keys (`special_needs[].accommodations[]`):**
- `extension_tasks` — extension tasks at a higher cognitive-demand level on top of the core tasks.
- `advanced_sources` — more demanding source texts for deeper, independent work.
- `open_research` — open-ended research or transfer questions for independent deepening.

---

## German as a Second Language (Deutsch als Zweitsprache, DaZ)

**Code (`special_needs[].type`):** `daz` — lowercase form used in the class definition.
**What it is:** A learner acquiring German as a second language alongside the subject content. Subject understanding may be ahead of the language available to express it, so the language is scaffolded while the demand is kept.
**Kind of measure:** Support / internal differentiation (Förderung / Binnendifferenzierung) — language-sensitive teaching (sprachsensibler Unterricht).

**Differentiation measures (Maßnahmen):**
- Provide a bilingual glossary for the key terms of the unit.
- Give simplified instructions alongside the original wording, not in place of it.
- Use visual scaffolding — pictures, diagrams, structuring aids — to carry meaning.
- Offer sentence starters and building blocks (Satzbausteine) to support written production.

**Accommodation keys (`special_needs[].accommodations[]`):**
- `bilingual_glossary` — a bilingual glossary for the unit's key terms.
- `simplified_instructions` — simplified instructions alongside the original wording.
- `visual_scaffolding` — visual aids (pictures, diagrams, structuring aids) to carry meaning.
- `sentence_starters` — sentence starters and building blocks (Satzbausteine) as a writing aid.

---

## Autism Spectrum Disorder (Autismus-Spektrum-Störung, ASS)

**Code (`special_needs[].type`):** `ass` — lowercase form used in the class definition.
**What it is:** A recognized priority area of support (Förderschwerpunkt) affecting social interaction, communication, and the processing of change and sensory input. Predictability and explicit expectations make the learning environment workable.
**Kind of measure:** Accommodations (Nachteilsausgleich) where a recognized accommodation applies, combined with internal differentiation (Binnendifferenzierung) in the everyday lesson.

**Differentiation measures (Maßnahmen):**
- Keep a predictable structure and signal any change to the routine in advance.
- Give written and explicit instructions; avoid relying on implicit or figurative wording.
- Structure group work with clearly defined roles, or offer a structured individual alternative.
- Reduce sensory load — noise, visual clutter, crowding — where the setting allows.

**Accommodation keys (`special_needs[].accommodations[]`):**
- `predictable_structure` — a predictable structure; changes are signalled in advance.
- `written_instructions` — written and explicit instructions without implicit or figurative wording.
- `structured_roles` — group work with clearly defined roles, or a structured individual alternative.
- `reduced_sensory_load` — reduced sensory load (noise, visual clutter, crowding).

---

## Physical Impairment (Körperliche Beeinträchtigung, KB)

**Code (`special_needs[].type`):** `kb` — lowercase form used in the class definition.
**What it is:** A recognized priority area of support (Förderschwerpunkt) for a physical impairment that affects mobility, fine motor control, or the handling of materials. The task stays the same; its physical handling is made accessible.
**Kind of measure:** Accommodations (Nachteilsausgleich) — access is levelled, the demand stays the same.

**Differentiation measures (Maßnahmen):**
- Offer a digital alternative format so the task can be completed without a physical barrier.
- Use a flexible layout that adapts to the student's working aids and seating.
- Allow extended time where handling the material takes longer.
- Ensure materials are barrier-free and compatible with any assistive tools in use.

**Accommodation keys (`special_needs[].accommodations[]`):**
- `digital_alternative` — a digital alternative format for barrier-free completion.
- `flexible_layout` — a flexible layout adapted to the student's working aids and seating.
- `extended_time` — extended working time when handling the materials takes longer.

---

## Visual Impairment (Sehbeeinträchtigung, SB)

**Code (`special_needs[].type`):** `sb` — lowercase form used in the class definition.
**What it is:** A recognized priority area of support (Förderschwerpunkt) for reduced vision. Material must be perceivable through enlargement, contrast, and non-visual description so the content remains fully accessible.
**Kind of measure:** Accommodations (Nachteilsausgleich) — access is levelled, the demand stays the same.

**Differentiation measures (Maßnahmen):**
- Provide large print sized to the student's need.
- Use high contrast between text and background.
- Give verbal descriptions of images, diagrams, and other visuals.
- Supply screen-reader-compatible, accessible documents; offer tactile or enlarged graphics where relevant.

**Accommodation keys (`special_needs[].accommodations[]`):**
- `large_print` — large print sized to the student's need.
- `high_contrast` — high contrast between text and background.
- `verbal_descriptions` — verbal descriptions of images, diagrams, and visualizations.
- `accessible_document` — a screen-reader-compatible, accessible document; tactile or enlarged graphics where needed.

---

## Hearing Impairment (Auditive Beeinträchtigung / Hörbeeinträchtigung, AUD)

**Code (`special_needs[].type`):** `aud` — lowercase form used in the class definition.
**What it is:** A recognized priority area of support (Förderschwerpunkt) for reduced hearing. Information carried by sound must be available in a visual or written form so nothing is lost.
**Kind of measure:** Accommodations (Nachteilsausgleich) — access is levelled, the demand stays the same.

**Differentiation measures (Maßnahmen):**
- Give instructions visually as well as orally.
- Provide written task cards so each instruction is permanently available.
- Reduce dependence on audio; offer a non-audio route to the same content.
- Supply transcripts or captions for audio-visual material; note seating and visibility so lip-reading and cues stay possible.

**Accommodation keys (`special_needs[].accommodations[]`):**
- `visual_instructions` — instructions given visually in addition to the oral form.
- `written_task_cards` — written task cards so each instruction stays permanently available.
- `reduced_audio` — reduced audio dependence; an alternative, non-audio route to the content.
- `transcripts` — transcripts or captions for audio-visual material; note seating and line of sight.

---

## Combining and conflicting measures

A class often carries several needs at once, and the measures interact:

- **Measures that combine cleanly** stack in one variant. A learner with both Lese-Rechtschreib-Schwäche (LRS) and Deutsch als Zweitsprache (DaZ) can receive larger font, reduced text density, a bilingual glossary, and sentence starters together — the access supports reinforce each other without conflict.
- **Measures that pull in opposite directions** call for separate variants rather than a forced compromise. Extension tasks for Hochbegabung (HB) and the shorter, chunked blocks for Aufmerksamkeitsdefizit-Hyperaktivitätsstörung (ADHS) work against each other in a single document; produce a distinct differentiated variant for each target need instead of merging them.

Throughout, the cognitive demand is held constant: differentiation (Differenzierung) adjusts access and depth, never the underlying expectation.

## Cross-references

- `${CLAUDE_PLUGIN_ROOT}/references/schemas/class-definition.md` — the `special_needs[].type` and `special_needs[].accommodations[]` fields this catalog is the vocabulary for.
- `${CLAUDE_PLUGIN_ROOT}/references/glossary-de.md` — the category table and the canonical English ↔ German term pairs.
- `${CLAUDE_PLUGIN_ROOT}/regulations/hamburg/shared/cross-subject/apo-ah.pdf` and `${CLAUDE_PLUGIN_ROOT}/regulations/hamburg/shared/cross-subject/apo-grundstgy.pdf` — the Hamburg accommodation (Nachteilsausgleich) framework for Sek II and Sek I.
