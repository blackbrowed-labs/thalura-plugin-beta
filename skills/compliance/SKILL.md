---
name: compliance
description: Auf Bildungsplan-Konformität prüfen. Use when the teacher asks to check an output for conformity with official regulations (Bildungsplan / BSB) — a compliance/correctness review, not a generic "check".
when_to_use: |
  DE + EN: "Compliance", "Bildungsplan-konform?", "ist das regelkonform?", "prüfe gegen den Bildungsplan", "is this compliant?", "check against the curriculum". Scope = regulatory/correctness checks; a bare "check this" with no regulatory intent should be clarified by the router, not auto-routed here.
---

# The Sacred Texts (`compliance_check`) — Compliance Validation

> Core protocols — startup, HiTL/draft lifecycle, preferences, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).

Validates that outputs comply with official BSB regulations. Operates in two modes: quick-check (automatic/internal) and full audit (on demand or mandatory for assessments).

---

## Invocation Modes

### Quick-Check (Automatic / Internal)
- Runs as part of the internal compliance gate (Step 4 of the 8-step HiTL flow — see `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md`) for document-producing tasks
- Also runs after every validation (Step 8) as a final check
- Checks 3-5 core compliance points
- Fast, focused, low-token
- Result shown inline or as compliance notes in chat

### Full Audit (Comprehensive)
- Runs on explicit teacher request: "Please run a full compliance check"
- Runs **automatically for ALL assessments** (Challenge Accepted) — this is mandatory
- Paragraph-level verification against specific regulation documents
- Produces a detailed compliance report in chat

---

## Quick-Check Checklist

For every output, verify:

1. **Competency domains (Kompetenzbereiche):** Are the listed competency domains (Kompetenzbereiche) actually defined in the curriculum standards (Bildungsplan) for this (subject, grade)?
2. **Topic scope:** Is the topic within the curriculum standards (Bildungsplan) content specifications for this (subject, grade)?
3. **Operator usage:** Are the operators used actually defined in the relevant operator list? Are they appropriate for the stated AB level?
4. **For assessments only:** Is the rough AB distribution within acceptable range?
5. **For Sek II only:** Is the gA/eA distinction correctly applied?

**Output format:**
```
Compliance Quick-Check:
[pass] Competency areas: [competencies] — BP [subject] [level], p. [page]
[pass] Topic: within curriculum standards (Bildungsplan) scope — BP [subject] [level], p. [page]
[warning] Operator "erörtern" in grade 7 — propedeutic (propädeutisch) use (Studienstufe operator)
```

The output is rendered in `conversation_language`. The template above shows the English structure; localized labels are resolved via `localization.json`.

---

## Full Audit Checklist

### For All Outputs

1. **Competency verification:**
   - Each listed competency domain (Kompetenzbereich) must exist in the curriculum standards (Bildungsplan) for (subject, grade)
   - Citation: BP [subject] [level], section/page

2. **Topic verification:**
   - Topic must be within the curriculum standards (Bildungsplan) content specifications
   - For SiC-overridden sequencing: verify SiC allows this topic at this point
   - Citation: BP [subject] [level], section/page

3. **Operator verification:**
   - Each operator used must be in the official operator list for the subject
   - Operator must match the intended AB level
   - For propedeutic use in Sek I: flag clearly but allow
   - Citation: Operator list [subject], page

### Additional Checks for Assessments

4. **AB distribution:**
   - Calculate exact percentage: AB I / AB II / AB III
   - Compare against regulation requirements (different for gA vs. eA)
   - Citation: ARL [subject], section on AB distribution

5. **Point allocation:**
   - Total points must be consistent
   - Points per task proportional to complexity and time
   - Citation: ARL [subject], point allocation guidance

6. **Grading rubric (Erwartungshorizont) completeness:**
   - Every task in the student version must have a corresponding model answer
   - Point distribution fully specified
   - Grading scale (Notenschlüssel) present and correct

7. **Duration compliance:**
   - Does the allocated duration match APO/ARL requirements?
   - Citation: APO [applicable], section on exam duration

8. **Format compliance (Abiturklausur only):**
   - Task types match ARL specifications
   - Text type and length per ARL
   - Structure matches ARL format exactly
   - Citation: ARL [subject], section on exam format

9. **gA/eA-specific requirements (Sek II only):**
   - Content depth appropriate for the course level (Anforderungsniveau)
   - AB distribution matches gA or eA requirements (they differ)
   - Task complexity aligned with course level
   - Citation: ARL [subject], gA/eA-specific sections

---

## Full Audit Output Format

```
Compliance Audit — [task type]
Subject: {subject} | Grade: {grade_level} | Level: {gA/eA or N/A}
Date: {date}

1. Competency Areas
   [pass] {competency}: BP {subject} {level}, p. {page}

2. Topic Scope
   [pass] {topic}: BP {subject} {level}, p. {page}

3. Operators
   [pass] {operator} (AB {level}): Operator list {subject}, p. {page}
   [warning] {operator}: propedeutic (propädeutisch) in grade {grade}

4. AB Distribution
   AB I:  {points} ({percentage}%) — Requirement: {requirement}%  [pass]
   AB II: {points} ({percentage}%) — Requirement: {requirement}%  [pass]
   AB III:{points} ({percentage}%) — Requirement: {requirement}%  [pass]
   Source: ARL {subject}, p. {page}

5. Point Distribution
   [pass] Total points consistent: {total}

6. Grading Rubric (Erwartungshorizont)
   [pass] All tasks with model answers
   [pass] Grading scale (Notenschlüssel) present

7. Duration
   [pass] {duration} min — APO {applicable}, §{section}

8. Format (Abitur exam)
   [pass] Task types per ARL

Result:
{count} passed | {count} warnings | {count} deviations
```

The output is rendered in `conversation_language`. The template above shows the English structure; localized labels are resolved via `localization.json`.

When the audit's findings are rendered onto a document surface (e.g. the grading rubric (Erwartungshorizont)), that write routes through the Output-Gate Runner (Step 5); do not present that rendered document until its gate-outcome report is produced. A chat-only audit reply has no document to gate.

Each regulation citation in the audit (the `BP … p. {page}`, `ARL … p. {page}`, operator-list, and APO/§ references — in both the full audit and the quick-check above) renders as a link to its official source per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Regulation-citation links* — best-effort in chat (a link where a source URL resolves, plain text otherwise). The citation text is unchanged.

---

## Result Categories

| Category | Meaning | Action Required |
|----------|---------|-----------------|
| **PASS** | Fully compliant with document reference | None |
| **WARNING** | Technically compliant but worth reviewing | Teacher should review |
| **DEVIATION** | Violation of regulation with exact paragraph citation | Must be fixed |

---

## Notes

- The Sacred Texts never modifies outputs — it only reports
- For deviations, cite the exact paragraph of the regulation
- Quick-checks are fast and lightweight; if concerns arise, suggest a full audit
- The compliance check loads its own document set via the routing matrix. The audit then reads the **session digest cache** (`${CLAUDE_PLUGIN_ROOT}/references/schemas/digest-cache.md`) for that set and reuses a digest where it is version-stamp-valid (every bundled-PDF hash and page-map version still current), delegating a miss to the **regulation firewall** (`${CLAUDE_PLUGIN_ROOT}/skills/read-regulations/SKILL.md`) rather than re-reading the regulations from scratch on each assessment (per-document fan-out — one reader per document, one `document_id:` line per dispatch prompt; see the read-regulations firewall dispatch).
- When used as the internal compliance gate (Step 4), results are included as compliance notes alongside the draft delivery
