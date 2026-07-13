---
name: assessment
description: Lernkontrolle / Klausur erstellen. Use when the teacher wants to create an assessment (Lernkontrolle / Klausur) — a task paper (Aufgabe) plus grading rubric (Erwartungshorizont).
when_to_use: |
  DE + EN: "Klausur", "Lernkontrolle", "Test", "Klassenarbeit", "Abituraufgabe", "Prüfung erstellen", "exam", "quiz", "assessment". Produces Aufgabe + Erwartungshorizont with a mandatory compliance audit.
---

# Challenge Accepted (`create_assessment`) — Assessment Creation

> Core protocols — startup, HiTL/draft lifecycle, preferences, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).
>
> Before writing the `_{draft_suffix}` to disk (Step 4), the internal compliance gate runs a Sacred Texts quick-check. Load `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` for the full 8-step flow at the draft/validation step.

Generates tests and exams with a separate student version — exam paper (Aufgabe) — and teacher version — grading rubric (Erwartungshorizont). Always triggers a full compliance audit.

---

## Required Inputs

| Parameter | Type | Required | Example |
|-----------|------|----------|---------|
| `subject` | String | yes | "english" |
| `grade_level` | String | yes | "8" or "S2" |
| `unit_context` | Object/Path | yes | One or more unit folders, or manual topic description |
| `exam_type` | Enum | yes | `"short_test"` / `"exam_sek1"` / `"exam_sek2_ga"` / `"exam_sek2_ea"` / `"abitur_exam"` / `"oral_abitur_exam"` / `"presentation"` / `"oral_esa_exam"` / `"oral_msa_exam"`. Display localized names to the teacher via `localization.json` → `assessment_types` based on `conversation_language`; internally use the English ID. `oral_esa_exam` / `oral_msa_exam` are Stadtteilschule-only oral exit exams (Mündliche Prüfung): offer them only when `school_type = "Stadtteilschule"`; `oral_esa_exam` targets Grade 9 (ESA = Erster allgemeinbildender Schulabschluss), `oral_msa_exam` Grade 10 (MSA = Mittlerer Schulabschluss). BSB Musteraufgaben exist for Philosophy and Religion only — English ESA/MSA are centrally administered (zentrale Prüfung), so do not offer a school-level oral format for English (see each format file's "Subject-Specific Notes"). |
| `duration` | Integer | **yes** | Duration in minutes — always required |
| `course_level` | Enum | **HARD BLOCK (Sek II)** | "gA" / "eA" |
| `class_id` | String | no | "E8a" |

**All required inputs must be confirmed.** If the teacher says "Create an exam for S2 Philosophy" without specifying duration or gA/eA, ask.

**Multi-unit assessments:** The `unit_context` can reference multiple unit folders. Read the unit plan ({unit_plan}) from each to understand the full scope. The school year plan helps identify all relevant units.

**Revision awareness:** If a unit is being taught (status `active`) and carries a non-null `modification_notes` in the school year plan — the derived "modified" state — flag dropped content and ask if the assessment scope should be adjusted. (This is an in-progress signal; a `completed` unit's dropped content is recorded by the unit plan's persisted "dropped" markers, not the status.)

**Abitur countdown:** For S3/S4, warn if assessment timing conflicts with Abitur preparation needs.

---

## Logic (Step by Step)

1. **Use the document set already resolved by core Step 11** for this routing key (core resolves the registry once per session and holds the INCLUDE set + `Read scope` cells). Do not re-open `${CLAUDE_PLUGIN_ROOT}/references/document-registry.md`; consume the resolved set:
   - Load all standard layers (1-4)
   - Load Layer 5 (Schwerpunktthemen) if `exam_type = "abitur_exam"`
   - **For Sek II Abitur exams only:** compute the Abitur year via `${CLAUDE_PLUGIN_ROOT}/references/temporal-logic.md` (it selects the A-Heft page range — Layer 5 — which is Sek II-only). Skip for Sek I.

2. **Read unit context** from the unit plan ({unit_plan}) in the unit folder(s):
   - Extract topics, competency domains (Kompetenzbereiche), covered content
   - For multi-unit: combine the scope from all referenced units
   - Present the derived scope to the teacher and confirm
   - **If unit is modified:** Flag dropped content

3. **Read completed lesson files** from `{lessons}/` in the relevant unit folder(s):
   - For units where lessons have been taught, read all lesson files to understand what students actually covered
   - This provides better alignment with actual instruction, not just the planned unit outline
   - Cross-reference with the unit plan ({unit_plan}) to identify what was taught vs. what was only planned
   - **Out-of-band option (multi-unit)** — see `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` → *Out-of-band execution*. For a multi-unit assessment, the per-unit-folder reads of steps 2–3 MAY delegate **one reader per teaching-unit (Unterrichtseinheit) folder**. Each reader reads only that folder's unit plan ({unit_plan}) and completed lesson files from `{lessons}/` — **teacher documents only, never any official regulation content** (those regulatory loads are handled separately, ahead of this, on the mandatory-delegation correctness path) — and returns a compact content summary (topics, competencies, operators used, material references) for proposal grounding. An empty or unreadable folder is reported back as a **flag**, not silently skipped. This read-and-summarize is mechanical and delegable **pre-approval** because it feeds — never replaces — the main-session proposal judgment.

4. **Read the school year plan** (`<WORKSPACE_ROOT>/data/school-years/{year}/plan.json`) for context:
   - What other units have been covered?
   - Are there competency gaps that should be addressed?

   > **Manifest sweep (touchpoint-local).** On reading a manifest (`plan.json`), check the generated documents you are about to rely on: a document entry with a missing or failing `gates` record — or a year overview (Schuljahresübersicht) whose freshness marker (`rendered_rev`) trails the current plan state (`content_rev`) — is a **detected deviation**, not a fact to accept. Produce gate evidence for the existing artifact now (the Output-Gate Verifier is the mechanism of record; any equivalent evidence-producing method conforms), backfill the record and escalate-or-flag per gate, regenerate a stale year overview through the runner, and note the repair in chat. Never silently proceed over a hole. *(Honesty note: entries whose `gates` records already read as passing are never re-opened — in-product detection of a fabricated passing record is nil; that is a probe-time concern only.)* Sweep only the unit/year actually being read — no workspace-wide crawl — and repair records and derivatives, never content.

5. **Load exam format definition:**
   - Resolve filename: replace `_` with `-` in the `exam_type` value → `${CLAUDE_PLUGIN_ROOT}/references/exam-formats/{resolved}.md` (e.g., `"exam_sek2_ga"` → `exam-sek2-ga.md`)
   - Check user override first: `<WORKSPACE_ROOT>/data/exam-formats/{resolved}.md` — if present, use it instead (full replacement, no partial merge)
   - Read the format file for: structure, sections, AB distribution, task count/choice rules, permitted aids, regulatory references, and subject-specific notes
   - The regulatory loads that ground this format — the exam-format and AB-distribution rules, and the working-time (Bearbeitungszeit) invariant check (at least one niveau value; where exactly two are present, the higher-niveau value must be ≥ the lower-niveau value) — go through the **regulation firewall** (`${CLAUDE_PLUGIN_ROOT}/skills/read-regulations/SKILL.md`) and are served from the **session digest cache** (`${CLAUDE_PLUGIN_ROOT}/references/schemas/digest-cache.md`) on a version-stamp-valid hit, with a miss delegated to the firewall (per-document fan-out — one reader per document, one `document_id:` line per dispatch prompt; see the read-regulations firewall dispatch). The operator list is **referenced via the dedicated `{subject}_operators` cache entry rather than re-read** here.
   - Use the loaded format definition to inform all subsequent steps

6. **Apply assessment framework** from the loaded format file:
   - Structure, section layout, and task types per the format file's "Structure and Sections"
   - AB distribution targets per the format file's "Operator Requirements per Performance Level"
   - Task count and choice rules per the format file's "Number and Type of Tasks"
   - Subject-specific rules per the format file's "Subject-Specific Notes" section for the current subject

7. **Select and apply operators:**
   - Every task/question must begin with an operator
   - Map operators to AB levels
   - Propedeutic use in Sek I: flag in teacher version, not in student version

8. **AB distribution:**
   - Calculate percentage: AB I / AB II / AB III
   - Must comply with the targets from the loaded format file
   - Present the distribution transparently

9. **Grading scale (Notenschlüssel):**
   - Present three options: (a) APO standard, (b) SiC scale if available, (c) custom input
   - The teacher chooses. Always ask.

10. **Differentiation** (if class definition exists):
   - Consider accommodations (Nachteilsausgleich)
   - Note applicable accommodations in the teacher version
   - Suggest separate accommodations (Nachteilsausgleich) versions if needed

11. **Create the proposal** and present to the teacher in chat

---

## Proposal Format

```
{exam_type}: {subject}, {grade_level} {course_level}
Topic: {topic(s)}
Duration: {duration} min
Reference: {unit folder reference(s)}

Task Structure:
1. {operator} ... ({points} points, AB {level})
   a) {sub-task}
   b) {sub-task}
2. {operator} ... ({points} points, AB {level})
3. ...

Point Distribution:
- Total: {total} points
- AB I: {points} ({percentage}%)
- AB II: {points} ({percentage}%)
- AB III: {points} ({percentage}%)

Grading scale: [APO standard / SiC / custom — selection required]

Regulatory basis: {documents referenced}
```

The proposal is output in `conversation_language`. The template above shows the English structure; localized labels are resolved via `localization.json`.

---

## After Approval — Two Output Files

### Student Version — Exam Paper (Aufgabe)
- `Aufgabe_{draft_suffix}.docx` in `{assessments}/`
- Language: resolved via the content language fallback chain (core skill satellite `${CLAUDE_PLUGIN_ROOT}/skills/core/content-language-gendering.md`, *Content Language Resolution*) — output type `assessments`
- Uses template from `templates/` if available
- NO model answers, NO point values visible to students

### Teacher Version — Grading Rubric (Erwartungshorizont)
- `Erwartungshorizont_{draft_suffix}.docx` in `{assessments}/`
- Language: resolved via the content language fallback chain (core skill satellite `${CLAUDE_PLUGIN_ROOT}/skills/core/content-language-gendering.md`, *Content Language Resolution*) — output type `assessment_rubric`
- Contains: full model answers, point breakdown, AB distribution, grading scale (Notenschlüssel), propedeutic (propädeutisch) operator flags (Sek I), differentiation notes, link to student version

Both files follow the standard `_{draft_suffix}` revision cycle (Steps 6-8 of the HiTL flow).

Run the Output-Gate Runner (`${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` Step 5) on the written output; do not present until its gate-outcome report is produced.

**Template fidelity — structurally n/a for assessments.** No shipped default template exists for assessment documents (Aufgabe / Erwartungshorizont) yet — the shipped `${CLAUDE_PLUGIN_ROOT}/templates/assessments/` directory holds only a placeholder — so the template-fidelity gate is structurally not-applicable and the `gates` record carries `template: n/a`; the metadata gate and the referenced-file / regulation-citation link gates bind unchanged. (A workspace-override assessment template, if the teacher supplies one, is fingerprinted live and fidelity then applies.)

**Out-of-band option.** The exam-paper (Aufgabe) and grading-rubric (Erwartungshorizont) writes are the same delegable site pattern as material generation (see `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` → *Out-of-band execution* and the material-gen After-Approval step-2 clause): the delegate receives the approved content (semantic layer only), the resolved output paths and naming values, the content-language result, and the Step-4 `compliance_quickcheck` outcome resolved main-session before dispatch; it runs the Output-Gate Runner and returns the written path(s) plus per-gate outcome lines, echoing `compliance_quickcheck` verbatim. A missing or unusable return is failed verification: run the write inline.

The Erwartungshorizont ↔ Aufgabe cross-reference and any cited source material render as relative-path hyperlinks per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Referenced-file hyperlinks* (siblings in `{assessments}/` link with no `../`; a cited material in `{materials}/` links as `../{materials}/…`; from a numbered assessment subfolder as `../../{materials}/…`). Verify-exists-then-emit; otherwise plain text.

Each **regulation** citation in the grading rubric (Erwartungshorizont) and in the mandatory compliance audit (below) renders as a link to its official source per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Regulation-citation links* (best-effort page anchor; degrades to plain text where no source URL resolves). The citation text is unchanged.

---

## Mandatory: Full Compliance Audit

After generating the assessment, **always** run The Sacred Texts in **full audit mode**. This is not optional — every assessment must be fully audited.

See `skills/compliance/SKILL.md` for the full audit checklist.

---

## Notes

- Duration is always required — never generate an assessment without knowing the time allocation.
- For Abitur exams (Abiturklausuren): the format must match the ARL exactly.
- Multi-unit assessments are common for formal exams (Klausuren).
- The student version and teacher version are separate output files in `{assessments}/`.
- If the unit has been modified (Mode B of The Holocron), check which content was dropped before scoping the assessment.
- For progressive assessment folder structure (flat → numbered subfolders on second assessment), see `${CLAUDE_PLUGIN_ROOT}/references/output-architecture.md`.
