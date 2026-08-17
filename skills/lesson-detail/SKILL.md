---
name: lesson-detail
description: Stunde ausarbeiten. Use when the teacher wants to detail ONE lesson of an existing, validated unit (Stundenentwurf / Verlaufsplan) — timed phases for a single lesson.
when_to_use: |
  DE + EN: "Stunde planen", "Stundenentwurf", "Verlaufsplan", "Stunde 3 ausarbeiten", "plan a lesson", "lesson detail", "expand lesson N". A SINGLE lesson within an existing unit; NOT a new unit outline (→ unit-planning).
---

# The Upside Down (`plan_lesson_detail`) — Detailed Lesson Planning

> Core protocols — startup, HiTL/draft lifecycle, preferences, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).
>
> Before writing the `_{draft_suffix}` file to disk (Step 4), the internal compliance gate runs a Sacred Texts quick-check. Load `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` for the full 8-step flow at the draft/validation step.

Expands a single lesson from the unit plan into a detailed lesson plan. Creates `{number}-{Topic}_{draft_suffix}.docx` in `{lessons}/`.

---

## Required Inputs

| Parameter | Type | Required | Example |
|-----------|------|----------|---------|
| `unit_folder` | Path | yes | Path to the unit folder containing the unit plan document |
| `lesson_number` | Integer | yes | 2 |

---

## Pre-conditions

1. **HARD BLOCK — Unit plan validated:**
   Read `plan.json` in the unit folder. If `unit_plan.status` is `"draft"`, refuse to proceed:
   > "The unit plan is still a draft. Please validate it first before we detail a lesson."

2. **Warning — Previous lesson still draft:**
   If lesson N-1 exists in `plan.json` with `status: "draft"`, warn the teacher:
   > "The lesson plan for lesson {N-1} has not been validated yet. Should I proceed anyway?"
   Proceed only after teacher confirmation. This is a warning, not a hard block.

All teacher-facing messages are output in `conversation_language`.

---

## Logic (Step by Step)

### Context Loading (Steps 1-5)

1. **Read `plan.json`**

   Read the unit manifest. Extract:
   - `unit_plan.version` (current unit plan version)
   - `unit_plan.status` (pre-condition check — already enforced in Pre-conditions)
   - `unit_plan.path` (actual file path — already localized in the manifest)
   - Lesson status map (which lessons exist, their `path`, `status`, and `unit_plan_version`)
   - Unit goal from `unit_title`

   > **Manifest sweep (touchpoint-local).** On reading a manifest (`plan.json`), check the generated documents you are about to rely on: a document entry with a missing or failing `gates` record — or a year overview (Schuljahresübersicht) whose freshness marker (`rendered_rev`) trails the current plan state (`content_rev`) — is a **detected deviation**, not a fact to accept. Produce gate evidence for the existing artifact now (the Output-Gate Verifier is the mechanism of record; any equivalent evidence-producing method conforms), backfill the record and escalate-or-flag per gate, regenerate a stale year overview through the runner, and note the repair in chat. Never silently proceed over a hole. *(Honesty note: entries whose `gates` records already read as passing are never re-opened — in-product detection of a fabricated passing record is nil; that is a probe-time concern only.)* Sweep only the unit/year actually being read — no workspace-wide crawl — and repair records and derivatives, never content.

2. **Load default context**

   Always load these files (paths read from `plan.json`):

   | Source | Purpose |
   |---|---|
   | Unit plan document (`unit_plan.path`) | Unit goal, lesson overview (all lessons), competency overview, differentiation concept |
   | Lesson plan N-1 (`lessons[N-2].path`, validated, if exists) | Transition awareness — how did the previous lesson end, what was achieved |
   | School year plan (`<WORKSPACE_ROOT>/data/school-years/{year}/plan.json`) | Broader context: taught/planned units, competency coverage |

   Extract the row for the requested lesson number from the unit plan. Present the derived context (subject, grade, topic focus, competencies, planned activities, methods) to the teacher and wait for confirmation.

3. **Load regulatory context for this lesson**

   Extract the `Curriculum Reference` from the unit plan's row for the requested lesson. This field contains the document name, page numbers, and specific competencies. Each targeted load below reads the **session digest cache** (`${CLAUDE_PLUGIN_ROOT}/references/schemas/digest-cache.md`) first and reuses a version-stamp-valid entry; only a miss is **delegated to the regulation firewall** (`${CLAUDE_PLUGIN_ROOT}/skills/read-regulations/SKILL.md`), which reads behind the context boundary and returns the digest (per-document fan-out — one reader per document, one `document_id:` line per dispatch prompt; see the read-regulations firewall dispatch). Because these targeted loads recur once per lesson across a unit, the cache hit is the dominant saving here. Load:

   1. **Targeted regulatory sections:** Only the pages/sections referenced in this lesson's `Curriculum Reference`. The unit plan has already been validated against the full regulatory stack; the lesson skill loads only what's directly relevant.
   2. **Operators:** Use the Layer 4 operator source for the subject from the document set core Step 11 already resolved (do not re-open the registry), reusing the dedicated `{subject}_operators` cache entry rather than re-reading the operator list. Operators are needed because student activity descriptions in the lesson plan must use age-appropriate operators (step 11).

   If the `Curriculum Reference` is too vague to extract specific pages, load the full subject curriculum standards (Bildungsplan) for the relevant level (Layer 3) as a fallback.

4. **Adaptive context expansion**

   Evaluate whether the default context is sufficient based on the unit plan content. Load additional files when:

   - **Thematic dependency:** Lesson N builds on a topic from an earlier lesson (not N-1) — load that lesson file (path from `plan.json`)
   - **Material reference:** Lesson N reuses or references a material from an earlier lesson — load the material file (path from `plan.json`)
   - **Teacher request:** Teacher explicitly asks to consider another lesson — load that file

   The decision is Claude's, based on the lesson overview in the unit plan.

5. **Consistency check**

   For each loaded lesson file, compare `lesson.unit_plan_version` against `unit_plan.version`:

   - If `lesson.unit_plan_version < unit_plan.version`, note informally:
     > "Lesson {M} was planned against an older unit plan version (v{old}, current is v{current}). The unit plan has been updated since."
   - This is **informational only** — Claude does NOT automatically suggest revisions unless the teacher asks.

> **Adaptation reminder (library-assigned units).** When the unit's manifest (`plan.json`) has `library_ref.adaptation_complete` set to `false`, remind the teacher **once per session** that this unit was assigned from the library (Bibliothek) and its documents are validated but not yet adapted to this class. Offer to mark it adapted when the teacher confirms ("die Einheit ist angepasst") — set `library_ref.adaptation_complete: true`. If the flag is absent or already `true`, say nothing.

### Lesson Design (Steps 6-17)

6. **Load teacher preferences** — especially: lesson structure style, social form tendencies, method preferences

7. **Load class definition** if available:
   - Check for special needs (differentiation)
   - Check class observations (what works/doesn't work in this class)
   - Consider prior_knowledge for scaffolding decisions

8. **Structure the lesson** using Hamburg-compatible didactic phases:
   - **Opening** — activate prior knowledge, motivate, set goals
   - **Main Phase** — explore new content, practice skills
   - **Consolidation** — reflect, summarize, check understanding
   - For **double periods** (90 min): include **Deepening** and/or **Buffer** activity
   - For complex phases (especially in double periods), split into sub-phases (Sub-Phasen) with individual time allocations. Sub-phase times must add up to the parent phase time.
   - Read `time_buffer_minutes` from teacher preferences. Subtract the buffer per lesson segment from the plannable time. For a continuous 90-min double period with 5-min buffer: plan for 85 min. For a double-with-break (45+break+45) with 5-min buffer: plan for 40+40 = 80 min.
   - Carry over phase guiding questions (Phasen-Leitfragen) from the validated unit outline (Grobplanung) into the corresponding phases of the lesson plan. These are not independently generated — they must match the unit outline exactly.

9. **Select methods** from Yoda's Wisdom:
   - Read relevant core category files from `${CLAUDE_PLUGIN_ROOT}/references/methods/core/{category}.md`
   - Read subject overlays — merge per overlay algorithm (see core skill *Overlay Merge Logic*)
   - Filter by teacher preferences and class observations
   - **Preference Override (CRITICAL):** If a rejected method is the only appropriate choice, explain why and suggest it

10. **Cross-topic knowledge check:**
    - Identify any concepts the lesson references that students may not know
    - If found: suggest scaffolding (info box on worksheet, brief opening explanation, pre-reading)
    - Document the result as the prerequisite knowledge check (Vorwissen-Check) section in the lesson plan — visible even when no scaffolding is needed

11. **Use operators** in all student-facing activity descriptions where age-appropriate:
    - For Sek I: use simpler operators and gradually introduce complex ones (propedeutic)
    - For Sek II: use full operator range from the relevant ARL
    - The lesson plan's "Student Activity" column should use operators

12. **Write the didactic-methodological commentary:**
    - Language: resolved via the content language fallback chain (core skill satellite `${CLAUDE_PLUGIN_ROOT}/skills/core/content-language-gendering.md`, *Content Language Resolution*)
    - Length: 150-300 words
    - Content: justify key didactic decisions, explain method choices, note differentiation measures, reference regulatory basis

13. **Identify assets and image prompts needed:**
    - For each phase, note what materials are required (worksheet, handout, slides, etc.)
    - These will be created later by The Playbook and Eleven's Vision
    - Note differentiation needs for The Multiverse

    **Propose the student task deck content (Phase A):**
    - **Gate on the toggle.** Read `generate_student_slides` from the two-tier behaviour config: read `<WORKSPACE_ROOT>/data/config/behaviour.json` (teacher override) overlaid on `${CLAUDE_PLUGIN_ROOT}/config-defaults/behaviour.json` (plugin default); effective value = teacher override if the key is present, else plugin default. If the effective value is `false`, skip this proposal entirely (no deck row, no content block). Absent or `null` is treated as `true` (the default) — proceed.
    - When not disabled, assemble a **Student Task Deck** proposal block — the slide-by-slide content the deck *would* carry, so the teacher reviews it while reviewing the lesson. Build it from the phase table's Student-Activity column: **one slide per work phase / coherent task-set** — instructions that belong to the same activity stay **together on one slide** (e.g. "work on the worksheet, then discuss with your right-hand neighbour" is one slide, not two), split only at a genuinely new work phase. Each slide carries the operator-led instruction(s) (reuse the Step-11 operator discipline — operators where didactically applicable), the social form, and the timing (when the phase has it). This is the same phase-grouping rule the projection layout uses (see `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` → "Student Task Deck layout"). The rule is explicitly **not** "one task per slide".
    - **No separate gate, no file written.** The deck content is reviewed **inside the same lesson approval gate** as the rest of the proposal — there is no extra approval step and no `.pptx` is produced here. This is a proposal of *content*, persisted as part of the lesson plan so the teacher sees exactly what the deck will contain. The Playbook generates the actual file after the lesson is validated.

14. **Cite sources for text materials:**
    - For every material based on an external text (reading text, excerpt, primary source, secondary literature), the source must be listed in the material table.
    - Source as clickable link: URL (website, online PDF) or `computer://` path (local file).
    - When no external source exists (e.g., self-created worksheets): "Original creation".

15. **Separate materials into two categories in the material table:**
    - **Materials to create** (numbered M01, M02, M03...): All materials that must be created — worksheets, reading texts, slides, observation sheets, image sets, etc. Unit-scoped sequential numbering. Once written to the lesson document, each M-number reference renders as a relative-path hyperlink to the material file (from the lesson's `{lessons}/` location → `../{materials}/…`) per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Referenced-file hyperlinks*.
    - **Standard supplies** (unnumbered): Everyday classroom supplies (Post-its, tape, pens, etc.) — listed as a brief comma-separated line beneath the main table. Resolve the teacher's effective standard-supplies list (Standardmaterial) via the two-tier read — `<WORKSPACE_ROOT>/data/config/standard-supplies.json` overlaid on `${CLAUDE_PLUGIN_ROOT}/config-defaults/standard-supplies.json`, whole-value at the `standard_supplies` key (see `${CLAUDE_PLUGIN_ROOT}/references/schemas/standard-supplies.md`). When that list is non-empty, standard-supplies proposals are **biased toward** the listed items: where pedagogically equivalent supply choices exist, prefer a listed item over an unlisted one, and treat listed non-standard items as live planning vocabulary — while an unlisted item stays proposable whenever the lesson design genuinely calls for it. This is a soft hint only: never hard-restrict proposals to the list, never flag or warn that a proposed item is "not on the list" or unavailable, never ask the teacher to confirm availability, and never weaken a pedagogical choice to fit the declared inventory. If the effective list is empty, absent, or unreadable, propose exactly as today (the assumed everyday set), with no error surfaced.
    - **"Pages" column**: For each material, note the target page count. The Playbook uses this as page limit.

16. **Create rubric (expected outcomes) for every material:**
    - Every material gets a rubric (Erwartungshorizont) — no exceptions. For materials without explicit tasks (slides, image sets, reading texts), the rubric documents expected learning outcomes or usage success criteria.
    - Include a brief rubric in the proposal (table format, 3-6 rows per material).
    - **Consistency check (CRITICAL):** Every expected performance in the rubric must be achievable through the material. If the rubric requires something the material doesn't enable, fix either the rubric or the material.
    - For each rubric, evaluate whether an assessment note (Bewertungshinweis) is needed. Include one when the assessment requires pedagogical context not self-evident from the rubric rows (e.g., intentionally ambiguous tasks, weighting guidance, process-vs-product emphasis).

17. **Create the proposal** and present to the teacher in chat

---

## Proposal Format

Present in the configured `conversation_language`. The template below shows the English structure; localized labels are resolved via `localization.json`.

```
Lesson {lesson_number}: {topic_focus}
Type: {Single/Double} | Duration: {duration} min
Time Budget: {t1} + {t2} + {t3} + ... = {total} Min (Time Buffer: {n} × {buffer} Min — if configured)

Prerequisite Knowledge Check:
[2-4 sentences: what prior knowledge students need. If scaffolding needed, state what and how.]

| Phase         | Time    | Teacher Activity       | Student Activity            | Social Form | Media/Materials     | Competency Ref |
|---------------|---------|------------------------|-----------------------------|-------------|---------------------|----------------|
| Opening       | 10 min  | [teacher action]       | [student action + operator] | PL          | [media/materials]   | [competency]   |
| Main Phase    | 25 min  | [teacher action]       | [student action + operator]. *Guiding question (Leitfrage): "{phase guiding question}"* | PA/GA       | [media/materials]   | [competency]   |
| Deepening     | 20 min  | [teacher action]       | [student action + operator] | PL          | [media/materials]   | [competency]   |
| → Sub-phase 1 |  5 min  | [teacher action]       | [student action]            | EA          | [media/materials]   | [competency]   |
| → Sub-phase 2 | 15 min  | [teacher action]       | [student action]            | GA          | [media/materials]   | [competency]   |
| Consolidation | 10 min  | [teacher action]       | [student action + operator] | PL          | [media/materials]   | [competency]   |

Didactic-Methodological Commentary:
[150-300 words justifying didactic decisions]

Materials Required:
| No. | Material | Description   | Source                           | Pages       | Creation |
| M01 | [name]   | [description] | [URL/path or "Original creation"]| [e.g. 1, 2] | The Playbook / Eleven's Vision / The Multiverse |
| M02 | [name]   | [description] | [...]                            | [...]        | ... |
| —   | Student task deck | Projection deck of this lesson's student tasks | Original creation | — | The Playbook (after lesson validation) |

(The student task deck row carries a "—" in the No. column, not an M{seq}: it is auto/triggered and lesson-scoped, so it never consumes a material number. Its id will be `student_task_deck-L{n}` keyed to this lesson. Include the row only when the effective `generate_student_slides` from `data/config/behaviour.json` is not `false` — absent or `null` counts as `true`.)

Student Task Deck (proposed content — reviewed in this same gate, no file written yet):
Slide 1 — {work-phase / activity name}
  - [operator-led instruction(s) for this phase, coupled steps together]
  Social form: {…} | Timing: {…} (omit timing when the phase has none)
Slide 2 — {next work phase}
  - [...]
(One slide per work phase / coherent task-set — not one task per slide.)

Standard Supplies: [comma-separated list biased toward the teacher's effective standard-supplies list (Standardmaterial) when set; else the assumed everyday set — e.g. Post-its (3 colours), tape, pens]

Rubric M01:
| [Criterion/Task]    | [Expected Performance] |
| ...                  | ...                    |

Rubric M02:
| [Criterion/Task]    | [Expected Performance] |
| ...                  | ...                    |
Assessment Note: [optional — didactic hints for evaluation, if needed]

(Every material gets a rubric. Consistency check: every expected performance must be achievable through the material.)

Curriculum Reference: [document name, page reference, specific competencies]
```

The `Curriculum Reference` (Bildungsplan-Bezug) page reference is written in the canonical form defined at `${CLAUDE_PLUGIN_ROOT}/references/regulation-naming.md` → *Teacher-Facing Citation Format*. The citation renders as a link to its official source per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Regulation-citation links* (best-effort page anchor; degrades to plain text where no source URL resolves). The citation text is unchanged.

---

## After Approval (Steps 4-8 of the HiTL Flow)

1. **Internal compliance gate** (Step 4): Sacred Texts quick-check on the generated content.

2. **Create lesson file** (Step 5 of HiTL):
   - Write `{number}-{Topic}_{draft_suffix}.docx` in `{lessons}/` using `${CLAUDE_PLUGIN_ROOT}/templates/planning/template_lesson_plan.docx` (see `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` — Planning Document Templates)
   - Run the Output-Gate Runner (`${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` Step 5) on the written output; do not present until its gate-outcome report is produced.
   - Leave placeholders for asset links (filled in by The Playbook), differentiated variant links (The Multiverse), and image prompts (Eleven's Vision)
   - Update `plan.json`: add lesson entry with `unit_plan_version` set to current `unit_plan.version`

3. **Update observations** (continuous): Log acceptances/rejections for methods, formats, social forms

4. **Teacher reviews and validates** (Steps 6-8): Standard `_{draft_suffix}` revision cycle.

5. **Post-validation: Evaluate unit plan**

   After the teacher validates the lesson, Claude evaluates whether the unit plan needs adjustment. Changes are proposed ONLY:
   - After the current lesson plan is validated (never during planning)
   - When truly necessary (not cosmetic — e.g., the lesson revealed that the lesson overview timing was unrealistic, or a topic shift emerged)
   - With specific change descriptions

   If changes are needed:
   1. Claude lists the specific proposed changes to the unit plan
   2. Teacher confirms, provides feedback, or declines
   3. Only after confirmation: unit plan is updated, `unit_plan.version` incremented in `plan.json`

6. **Retroactive change warning**

   If the proposed unit plan change affects an already-validated lesson:
   1. Claude warns explicitly:
      > "The proposed change also affects lesson {M}, which is already validated."
   2. Offers to revise the affected lesson — new draft cycle:
      - Validated file renamed back to `{Name}_{draft_suffix}.docx`
      - `plan.json` status reverts to `"draft"` for that lesson
   3. Teacher can accept the revision offer or decline (keeping the old validated version)

   **Student task deck staleness (regenerate only on a task change).** When a validated lesson is revised this way and it has an existing student task deck (a `materials[]` entry of `type: "student_task_deck"`), flag the deck stale and **offer regeneration only if the revision touched the part the deck draws from — the tasks** (the Student-Activity descriptions, operators, phase task-sets, social forms, or timing). Edits to lesson parts the deck does **not** render — the teacher-only activity column, internal differentiation notes, the competency mapping — do **not** flag the deck and do **not** offer regeneration. Never auto-overwrite an existing deck: surface the staleness, offer to regenerate via The Playbook, and let the teacher decide.

---

## Notes

- The Upside Down is called once per lesson in the unit. A 6-lesson unit = up to 6 calls.
- Each call follows the context loading sequence (Steps 1-5): default context (unit plan + lesson N-1), targeted regulatory loading, plus adaptive expansion when needed. File paths are read from `plan.json` (already localized). See `plan.json` for the lesson status map and version tracking.
- The teacher can revise any lesson plan after approval — a new `_{draft_suffix}` version is created.
- Time allocations in the lesson plan must add up to the lesson duration (or the buffer-adjusted plannable time when a time buffer (Zeitpuffer) is configured).
- Phase guiding questions (Phasen-Leitfragen) are carried over from the unit outline — they are validated there and must not be altered in the lesson plan.
