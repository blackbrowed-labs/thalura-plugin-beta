---
name: unit-planning
description: Unterrichtseinheit planen. Use when the teacher wants to plan a teaching unit (Unterrichtseinheit) — a unit outline or lesson sequence for a topic. Not for detailing a single lesson (that is lesson-detail).
when_to_use: |
  DE + EN: "Unterrichtseinheit planen", "eine (neue) Einheit planen", "UE zu <Thema>", "plan a unit", "unit planning", "plan a teaching unit on <topic>". NOT "Stunde planen"/"plan a lesson" → lesson-detail.
---

# The Holocron (`plan_unit`) — Unit Planning

> Core protocols — startup, HiTL/draft lifecycle, preferences, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).
>
> Before writing the `_{draft_suffix}` file to disk (Step 4), the internal compliance gate runs a Sacred Texts quick-check. Load `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` for the full 8-step flow at the draft/validation step.

Creates a structured unit outline for a teaching unit. This is the starting point for every unit and produces `{unit_plan}.docx` in the unit folder.

The unit outline and proposals use `conversation_language`. Task descriptions within the plan that will appear in student-facing materials resolve language via the content language fallback chain (core skill satellite `${CLAUDE_PLUGIN_ROOT}/skills/core/content-language-gendering.md`, *Content Language Resolution*).

---

## Three Modes

### Mode A — New Unit (default)
Runs the structured interview (see core skill), then plans from scratch.

### Mode B — Revision
The teacher says: "Two lessons were cancelled, adjust the plan."
The skill reads the existing `{unit_plan}.docx`, asks what was already taught and what falls away, redistributes content, marks dropped items as "dropped" (not deleted — preserved for documentation). If assessments (Challenge Accepted) are affected, the skill flags this:
> "The exam in double period 4 relied on content from double period 3. Should I adjust the exam?"

The unit's `modification_notes` are recorded in the school year plan (it stays `active`; shown as "modified").

### Mode C — Continue from School Year Plan
The teacher says: "Plan the next unit according to the school year plan."
The skill reads The Map (`<WORKSPACE_ROOT>/data/school-years/{year}/plan.json`), identifies the next planned unit, and pre-fills known parameters. Teacher confirms or adjusts.

---

## Required Inputs (Collected via Structured Interview — Mode A)

| Parameter | Type | Required | Source |
|-----------|------|----------|--------|
| `subject` | String | yes | Interview Q1 |
| `grade_level` | String | yes | Interview Q2 |
| `course_level` | Enum | **HARD BLOCK (Sek II)** | Interview Q3 |
| `topic` | String | yes | Interview Q4 |
| `total_lessons` | Integer | yes | Interview Q5 |
| `lesson_structure` | String | yes | Interview Q6 |
| `teacher_ideas` | String | no | Interview Q7 |
| `prior_knowledge` | String | no | Interview Q8 / class definition / school year plan |
| `class_id` | String | auto | Auto-resolved or created via Q9-Q11 |
| `sic_available` | Boolean | auto | Auto-detected from `<WORKSPACE_ROOT>/data/regulations/sic/{subject}/` |

**If any required input is missing, ask the teacher.** Present all interview questions together. The teacher may answer partially — follow up on missing answers.

---

## Logic (Step by Step)

1. **Run structured interview** (Mode A) or read existing data (Mode B/C) — collect all inputs

2. **HARD BLOCK — Class definition:** Verify class definition exists. If not, create via interview Q9-Q11. See core skill.

3. **HARD BLOCK — gA/eA (Sek II):** Verify course level is specified. See core skill.

4. **HARD BLOCK — School year plan:** Verify plan exists. If not, auto-create and inform teacher.

5. **Read school year plan:** What was already taught? What's planned next? Which competency areas are underrepresented?

> **Manifest sweep (touchpoint-local).** On reading a manifest (`plan.json`), check the generated documents you are about to rely on: a document entry with a missing or failing `gates` record — or a year overview (Schuljahresübersicht) whose freshness marker (`rendered_rev`) trails the current plan state (`content_rev`) — is a **detected deviation**, not a fact to accept. Produce gate evidence for the existing artifact now (the Output-Gate Verifier is the mechanism of record; any equivalent evidence-producing method conforms), backfill the record and escalate-or-flag per gate, regenerate a stale year overview through the runner, and note the repair in chat. Never silently proceed over a hole. *(Honesty note: entries whose `gates` records already read as passing are never re-opened — in-product detection of a fabricated passing record is nil; that is a probe-time concern only.)* Sweep only the unit/year actually being read — no workspace-wide crawl — and repair records and derivatives, never content.

> **Adaptation reminder (library-assigned units).** When the unit being planned has a manifest (`plan.json`) whose `library_ref.adaptation_complete` is `false`, remind the teacher **once per session** that this unit was assigned from the library (Bibliothek) and its documents are validated but not yet adapted to this class. Offer to mark it adapted when the teacher confirms ("die Einheit ist angepasst") — set `library_ref.adaptation_complete: true`. If the flag is absent or already `true`, say nothing.

6. **Use the document set already resolved by core Step 11** for this routing key (resolved once per session; do not re-open `${CLAUDE_PLUGIN_ROOT}/references/document-registry.md`). Consume the resolved INCLUDE set + `Read scope` cells:
   - Load Layer 1 (always) + Layer 2 (by level) + Layer 3 (by subject + level)
   - Load Layer 4 (operators) — operator awareness informs activity design
   - **For S3/S4 (Sek II) only:** load Layer 5 (Schwerpunktthemen for the computed Abitur year — see `${CLAUDE_PLUGIN_ROOT}/references/temporal-logic.md`). Not loaded for Sek I.
   - Load Layer 6: scan `<WORKSPACE_ROOT>/data/regulations/sic/{subject}/` for PDF files. If PDFs exist, load them as school-internal curriculum (Schulinternes Curriculum) enrichment. If no PDFs found, skip Layer 6 — graceful fallback to curriculum standards (Bildungsplan) only. If the teacher has opted out for this unit, skip Layer 6.
   - Load Layer 7 (methodologies) — 2-3 relevant method files

7. **Load teacher preferences** from `<WORKSPACE_ROOT>/data/profiles/teacher-preferences.json`

8. **Load class definition** — including prior_knowledge, class observations, special needs. **Cross-year continuity:** if the class definition's `previous_year` is set, also read back across the continuity chain for prior-year context. **By default read only the immediate prior year**: that year's structured `reflection` from `<WORKSPACE_ROOT>/data/school-years/{prior_year}/plan.json` (`strengths` / `improvements` / `reuse_recommendation` — the rich pedagogical prose, not the per-unit manifest's doc-tracker field) **plus** the prior class definition's continuity notes (`class_observations` / `prior_knowledge` / `notes`). Walk the **full multi-year chain only on explicit teacher request** (e.g. "how has this group developed since Klasse 8?"). Fold what you find — prior-year reflections, method-effectiveness patterns, recurring strengths/gaps — into the planning context (the same "consider … from the class definition" spirit, extended across years), and where relevant into the unit plan's prose (e.g. "this group struggled with Textanalyse last year").

   Guard rails for the cross-year read: **read-only** — never write to prior-year files. **Degrade silently** — an absent/`null` `previous_year` means no chain (behave exactly as today); a link to a missing definition or year folder is **skipped silently** and never blocks planning; bound the walk against cycles at **8 hops** (a Gymnasium spans grades 5–12, so 8 is the longest legitimate chain). **Surface pedagogical prose only** — read the prior-year `plan.json` / class-definition JSON internally; never present the raw internal `data/` JSON to the teacher. **Scope boundary** — read pedagogical notes only; do not read, aggregate, or compute over grades (there are none) and do not run trend/prediction analytics; decline multi-year grade-trend or analytics requests as out of scope.

9. **Read relevant curriculum standards (Bildungsplan) sections:** the page-accurate citations in the Curriculum Anchoring (Bildungsplan-Verankerung) block are produced by the regulation firewall's digest (`${CLAUDE_PLUGIN_ROOT}/skills/read-regulations/SKILL.md`) and served from the session digest cache (`${CLAUDE_PLUGIN_ROOT}/references/schemas/digest-cache.md`) on a version-stamp-valid hit, with a miss delegated back to the firewall (per-document fan-out — one reader per document, one `document_id:` line per dispatch prompt; see the read-regulations firewall dispatch). This block is the generalised proto-digest — **the output format below is unchanged; only the *source* of the citations is the digest** rather than an inline re-read.
   - Competency areas for this subject + level
   - Requirements/standards
   - Content specifications for the topic
   - If school-internal curriculum (Schulinternes Curriculum) loaded (Layer 6): read the SiC to identify the expected topic sequence for the current grade/semester. Check alignment:
     - If match: note the SiC alignment in the proposal
     - If mismatch: generate an advisory warning — e.g., "The school-internal curriculum (Schulinternes Curriculum) assigns this topic to grade {grade}/semester {semester}. The planned topic deviates from this sequence. This is permitted but should be coordinated with the department (Fachschaft)."
     - For S3/S4: if SiC conflicts with A-Heft Schwerpunktthemen, follow the A-Heft (binding) and flag the discrepancy
   - Identify applicable guiding perspectives (Leitperspektiven) from `allgemeiner-teil.pdf` § 3 — which of W, BNE, D connect to the unit topic?
   - If Sek I (Grades 5–10 or Vorstufe): identify applicable cross-curricular task areas (Aufgabengebiete) from `sek1-aufgabengebiete.pdf`
   - Compile curriculum anchoring (Bildungsplan-Verankerung) data: required module, Schwerpunktthema (if S3/S4), applicable guiding perspectives (Leitperspektiven), applicable cross-curricular task areas (Aufgabengebiete) (if Sek I), cross-references (Querbezüge), core competency domains (Kompetenzbereiche) — with page-accurate APA citations
   - Identify specific competency indicators (abbreviation + description) per topic area for use in per-lesson curriculum references (Bildungsplan-Bezug)

10. **Load methodology references** (Yoda's Wisdom):
    - Read method index from `skills/methodology/SKILL.md`
    - Read 2-3 core category files from `${CLAUDE_PLUGIN_ROOT}/references/methods/core/{category}.md`
    - Read subject overlays from `${CLAUDE_PLUGIN_ROOT}/references/methods/overlays/{subject}/{category}.md` — merge per overlay algorithm (see core skill *Overlay Merge Logic*)

11. **For S3/S4 units:** Cross-reference with Schwerpunktthemen + Abitur countdown awareness

12. **Distribute content across the lesson structure:**
    - Formulate a guiding question (Leitfrage) for the unit when pedagogically appropriate
    - Assign a theme/focus for each lesson
    - Identify key terms (Fachbegriffe) per lesson — subject-specific vocabulary introduced or reinforced
    - Map competency areas to lessons
    - Map guiding perspectives (Leitperspektiven) to lessons — identify which of W, BNE, D are genuinely addressed and in which lessons
    - If Sek I: map applicable cross-curricular task areas (Aufgabengebiete) to lessons
    - Select methods for each lesson (considering teacher preferences, class observations, and SiC competency focuses if loaded — SiC may prioritize certain competency domains for a given unit, informing method selection)
    - Plan specific texts and materials (author, work, focus passage)
    - Consider differentiation needs from class definition
    - Assign time allocations per phase within each lesson — when a time buffer (Zeitpuffer) is configured in teacher preferences (`time_buffer_minutes`), subtract the buffer per lesson segment from the plannable time
    - Formulate phase guiding questions (Phasen-Leitfragen) where pedagogically appropriate — scoped to specific phases
    - Assign per-lesson curriculum references (Bildungsplan-Bezug) — specific competency indicators with abbreviations (document-level citations are in the curriculum anchoring section)

13. **Cross-topic knowledge check:** If the topic requires knowledge from outside the curriculum, flag and plan scaffolding

14. **Apply operator propedeutics:** Use operators in activity descriptions where age-appropriate

15. **Create the unit outline proposal** and present to the teacher in chat

---

## Proposal Format — REQUIRED LEVEL OF DETAIL

The unit outline must follow this structure. The template shows both double periods and single periods. The proposal is output in `conversation_language`. The template below shows the English structure; localized labels are resolved via `localization.json`. The `{APA citation …}` placeholders in the Curriculum Anchoring (Bildungsplan-Verankerung) block below render in the canonical form defined at `${CLAUDE_PLUGIN_ROOT}/references/regulation-naming.md` → *Teacher-Facing Citation Format*.

```
Teaching Unit: {topic}
Subject: {subject} | Grade: {grade_level} | Level: {gA/eA}
Scope: {total_lessons} lessons ({lesson_structure})
Class: {class_id} ({class_size} students)
Guiding Question (Leitfrage): "{overarching question}" (optional — omit if not pedagogically appropriate)

--- Curriculum Anchoring (Bildungsplan-Verankerung) ---
- Required module: {module name}
  {APA citation with page numbers}
- School-internal curriculum (Schulinternes Curriculum): {SiC topic assignment for this grade/semester} (only when SiC loaded — omit otherwise)
  Source: {filename(s)}
- Schwerpunktthema: {focus topic} (S3/S4 only — omit otherwise)
  {APA citation}
- Guiding perspectives (Leitperspektiven): {W, BNE, D — whichever apply}
  {APA citation referencing allgemeiner-teil.pdf § 3}
- Cross-curricular task areas (Aufgabengebiete): {applicable areas} (Sek I only — omit for Sek II)
  {APA citation referencing sek1-aufgabengebiete.pdf}
- Cross-references (Querbezüge): {optional module connections} (if applicable — omit otherwise)
- Core competency domains (Kompetenzbereiche): {list}
  {APA citation with page numbers}

--- Didactic Concept ---
[250-400 words covering: overarching unit dramaturgy (red thread, narrative arc),
 focus areas and rationale (course profile, learning group), progression logic,
 key methodological decisions with didactic framing, cross-references (Querbezüge)
 to optional modules (if applicable), connection to prior/subsequent units,
 prospective reflection on Bildungsplan coverage and scope limitations.]

--- Double Period 1: "{title}" (90 min) ---
Topic: {detailed theme}
Goal: {what students should be able to do after this lesson}

* Opening ({X} min): "{activity_name}"
  Method: {method}. Activity: {detailed description of what students do}.
  Materials: {specific materials needed}

* Main Phase ({Y} min): "{activity_name}"
  Method: {method}. Materials: {specific texts — author, work, focus passage}.
  Activity: {what students do, using operators where appropriate}.

* Deepening/Transfer ({Z} min): "{activity_name}"
  Method: {method}. Activity: {detailed student activity}.
  *Guiding question (Leitfrage): "{phase guiding question}"* (where pedagogically appropriate)

Key Terms (Fachbegriffe): {comma-separated subject-specific vocabulary}
Curriculum Reference (Bildungsplan-Bezug): {competency abbreviations — e.g., F2 (Intuitionen hinterfragen), D4 (Argumentationsstrukturen herausarbeiten)}

[... all lessons ...]

--- Reflection ---
[How does this plan address the teacher's requirements? Which competency areas
 are covered? How does this unit fit in the school year context?]

Competency Areas: {list with curriculum references}
Guiding Perspectives (Leitperspektiven): {which of W, BNE, D are addressed, with per-lesson mapping}
Cross-Curricular Task Areas (Aufgabengebiete): {list with per-lesson mapping — Sek I only; omit for Sek II}
Operators: {list of key operators used, with AB levels}
```

---

## Curriculum Reference Format

The `Curriculum Reference` field per lesson **must** include:
- **Document name** (as listed in `document-registry.md`, e.g., "Bildungsplan Englisch Gymnasium Sek II")
- **Page numbers**, in the canonical form defined at `${CLAUDE_PLUGIN_ROOT}/references/regulation-naming.md` → *Teacher-Facing Citation Format*
- **Specific competencies** referenced

This structured format enables targeted regulatory loading in downstream skills (e.g., The Upside Down loads only the relevant pages instead of the full document stack).

Each regulation citation in the Curriculum Anchoring (Bildungsplan-Verankerung) block — and every per-lesson Curriculum Reference (Bildungsplan-Bezug) — renders as a link to its official source per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Regulation-citation links* (best-effort page anchor; degrades to plain text where no source URL resolves). The citation prose is unchanged; only the link affordance is layered on.

---

## Key Requirements for the Unit Outline

- Every lesson has **phases with time allocations** (Opening X min, Main Phase Y min, etc.)
- Time allocations must add up to the lesson duration (45 min for single period, 90 min for double period) — or the buffer-adjusted plannable time when a time buffer (Zeitpuffer) is configured
- **Concrete methods** per phase (not generic "text work" but specific method names with details)
- **Specific texts and materials** (author, work, focus passage/concept)
- **Student activities described in detail** (what do students DO?)
- **Operators used** where students engage with content
- **Key terms (Fachbegriffe)** per lesson — subject-specific vocabulary
- **Curriculum Reference (Bildungsplan-Bezug)** per lesson — competency abbreviations (document-level APA citations are in the curriculum anchoring section)
- **Phase guiding questions (Phasen-Leitfragen)** inline where pedagogically appropriate
- **Curriculum Anchoring** (Bildungsplan-Verankerung) with page-accurate APA citations
- **Didactic Concept** section (250–400 words: dramaturgy, focus, progression, methodology, cross-references, prospective reflection)
- **Reflection** at the end (why this plan fulfills the teacher's requirements)

---

## After Approval (Steps 4-8 of the HiTL Flow)

1. **Internal compliance gate** (Step 4): Sacred Texts quick-check runs automatically on the generated content before writing to disk.

2. **Create unit folder + draft** (Step 5):
   - Create the unit folder at `<WORKSPACE_ROOT>/{Subject}/{school_year}/{class_id}/{Unit_slug}/`
   - Write `{unit_plan}_{draft_suffix}.docx` using `${CLAUDE_PLUGIN_ROOT}/templates/planning/template_unit_plan.docx` (see `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` — Planning Document Templates). The Lesson Overview's material and lesson references render as relative-path hyperlinks per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Referenced-file hyperlinks*.
   - Write `{material_overview}.docx` using `${CLAUDE_PLUGIN_ROOT}/templates/planning/template_material_overview.docx` (no draft suffix — the overview is an auto-generated derivative outside the draft cycle). Its rows render as relative-path hyperlinks per the same gate.
   - Run the Output-Gate Runner (`${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` Step 5) on the written output; do not present until its gate-outcome report is produced.
   - Create `plan.json` manifest in the unit folder
   - File naming from `naming-conventions.json` (two-tier merge)

3. **Register in the school year plan** (The Map):
   - Set status to `active`
   - Record competency areas, time period, total lessons
   - Set `output_path` to the unit folder
   - Regenerate the year overview (Schuljahresübersicht) for the current school year through the Output-Gate Runner (The Map owns the contract; `${CLAUDE_PLUGIN_ROOT}/skills/year-planning/SKILL.md` → *Year Overview Document*)
   - This registration is a content-mutating write: it increments the year plan's `content_rev` (the schema owns the rule — `${CLAUDE_PLUGIN_ROOT}/references/schemas/school-year-plan.md`); the overview regeneration above then restores freshness (`rendered_rev = content_rev`).

4. **Update observations** (continuous): Log acceptances/rejections for methods, formats, styles

5. **Teacher reviews and validates** (Steps 6-8): Standard `_{draft_suffix}` revision cycle. Downstream tasks (lesson detail, materials) blocked until `{unit_plan}.docx` is validated.

---

## Mode B — Revision Details

When the teacher requests revision of an existing unit:

1. **Read the existing `{unit_plan}.docx`** from the unit folder
2. **Ask:** "Which lessons were cancelled?" and "What has already been taught?"
3. **Redistribute content** from dropped lessons into remaining lessons
4. **Mark dropped items** as "dropped" in the plan — do not delete them
5. **Check assessment impact:** If any assessment in `{assessments}/` relied on dropped content, flag it
6. **Update `{unit_plan}.docx`** with the revised plan (creates new `_{draft_suffix}` version)
7. **Update `plan.json`** and the school year plan: write `modification_notes` (the unit stays `active`)
8. **Regenerate the year overview** for the current school year through the Output-Gate Runner (current-year scope only; The Map owns the contract: `${CLAUDE_PLUGIN_ROOT}/skills/year-planning/SKILL.md` → *Year Overview Document*)
   - This revision write is content-mutating: it increments the year plan's `content_rev` (the schema owns the rule — `${CLAUDE_PLUGIN_ROOT}/references/schemas/school-year-plan.md`); the overview regeneration above then restores freshness (`rendered_rev = content_rev`).

---

## Notes

- The Holocron only creates the unit plan document. Detailed lesson plans are added later by The Upside Down.
- The unit outline is the input for all subsequent tasks (lesson detail, assets, assessments).
- The structured interview is presented once at the start, not question by question.
- For Mode C: the school year plan provides topic and lesson count; the skill runs a shortened interview to fill in remaining details.
- The proposal is output in `conversation_language`. The template above shows the English structure; localized labels resolved via `localization.json`.
- When a school-internal curriculum (Schulinternes Curriculum) is present, The Holocron references it in the Curriculum Anchoring (Bildungsplan-Verankerung) section and uses it for topic sequencing validation. Deviation warnings are advisory — the teacher has the final say. For S3/S4, A-Heft Schwerpunktthemen always take precedence over SiC.
