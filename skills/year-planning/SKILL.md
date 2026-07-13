---
name: year-planning
description: Schuljahr planen. Use when the teacher wants to plan or review the school-year plan (Jahresplanung / Schuljahresübersicht) — which units run across the year, what has been taught, competency coverage.
when_to_use: |
  DE + EN: "Jahresplanung", "Schuljahr planen", "Jahresübersicht", "was habe ich dieses Jahr unterrichtet?", "plan the school year", "year overview". Whole-year scope; NOT a single unit (→ unit-planning).
---

# The Map (`plan_school_year`) — School Year Planning

> Core protocols — startup, HiTL/draft lifecycle, preferences, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).

Creates and maintains a school year plan for a (subject, grade/course, school year) combination. Serves as the "memory" across sessions and units.

---

## Purpose

The school year plan tracks all units (past, current, and planned) for one course. It enables:
- Context awareness: the skill knows what was already taught when planning a new unit
- Competency coverage tracking: highlights gaps and overlaps
- Continuity: teachers can pick up where they left off, even in a new session
- Abitur countdown integration for S3/S4 (or Q3/Q4)

**Cross-year continuity.** When the class for this school year plan has a `previous_year` link, prior years' experience with the same group is available as planning context. By default draw on the immediate prior year — that year's `reflection` from `<WORKSPACE_ROOT>/data/school-years/{prior_year}/plan.json` (`strengths` / `improvements` / `reuse_recommendation`) and the prior class definition's continuity notes — so the year plan can build on what worked with this group before and avoid what did not; walk the full chain only on explicit request. This read is **read-only** (never writes prior-year files), **degrades silently** on a missing/broken link and is bounded at **8 hops** against cycles, surfaces **pedagogical prose only** (never the raw internal `data/` JSON), and stays within scope — pedagogical notes only, no grades and no multi-year analytics.

---

## Auto-Creation Rule

If the teacher starts planning a unit (The Holocron) and no school year plan exists for the relevant (subject, grade, school year):

1. Create an empty school year plan file (see `${CLAUDE_PLUGIN_ROOT}/references/schemas/school-year-plan.md`)
2. Inform the teacher that a plan has been created and that they can add previously completed or planned units at any time
3. Continue with the unit planning

This is a **HARD BLOCK** in the startup sequence — the skill always ensures a school year plan exists before unit planning.

**First contact with a new school year.** When this new-year `plan.json` creation is the **first contact** with a not-yet-existing school year (its `<WORKSPACE_ROOT>/data/school-years/{new_year}/` folder does not exist yet), this skill is an **entry point** into `core`'s transition logic — invoke the year-transition detection + continuation-proposal flow (see the Class Definition System in `skills/core/SKILL.md`) so the continuation proposal fires regardless of which surface the teacher reaches the new year from. This is a pointer into `core`; the detection and progression logic are not duplicated here.

---

## Two Modes for Adding Units

### Mode A — Thalura-Planned Units
When a unit is planned via The Holocron and approved, it is **automatically** registered in the school year plan. Entry includes: topic, time period, competency domains (Kompetenzbereiche) covered, status, `output_path` to the unit folder.

### Mode B — Externally Planned Units
The teacher manually enters a unit that was planned without Thalura. Entry includes: topic, approximate time period, competency domains (Kompetenzbereiche) (if known), brief notes. No `output_path`.

---

## Data Structure

File location: `<WORKSPACE_ROOT>/data/school-years/{year}/plan.json`

See `${CLAUDE_PLUGIN_ROOT}/references/schemas/school-year-plan.md` for the full schema.

---

## Unit Status Values

These are the **stored** status values:

| Status | Meaning |
|--------|---------|
| `planned` | Not yet started |
| `active` | Currently being taught |
| `completed` | Finished teaching |

**Derived label — "reflected".** There is no stored `reflected` status. A `completed` unit that also carries a non-null `reflection` object (written by The Holocron Log) is **shown** as "reflected" — a derived/display label computed from those two facts, not a value stored in `status`.

**Derived label — "modified".** There is no stored `modified` status. An `active` unit that also carries a non-null `modification_notes` (written by The Holocron on revision) is **shown** as "modified" — a derived/display label computed from those two facts, not a value stored in `status` (exactly parallel to "reflected"). The `active` conjunct is load-bearing: `modification_notes` can also sit on a `completed` unit, so the "modified-in-progress" signal specifically requires the `active` conjunct.

---

## Competency Coverage Tracking

The school year plan tracks which competency domain (Kompetenzbereich) is covered by which unit. This enables:

- **Gap detection:** Highlight competency domains (Kompetenzbereiche) not yet covered
- **Planning support:** When planning a new unit (The Holocron), identify underrepresented competencies and suggest addressing them
- **Year-end review:** Show full coverage map with BP references

---

## Abitur Countdown Awareness

**For S3/S4 (or Q3/Q4) — Sek II only:** the skill calculates weeks remaining until Abitur via `${CLAUDE_PLUGIN_ROOT}/references/temporal-logic.md`. Not used for Sek I.

**When active:**
- Warns if insufficient time remains for planned units
- Suggests revision/preparation blocks
- For late S3 or S4 units, suggests integration of exam preparation and Abitur focus topics (Schwerpunktthemen) review

---

## Standalone Use

The teacher can interact with The Map directly:
- "Show me the school year plan for Philosophy S4"
- "Add a unit: Utilitarianism, September to October, 6 lessons"
- "Which competencies are not yet covered?"
- "Change the status of unit 1 to 'completed'"

Example triggers shown in English. Claude matches semantically — the teacher's actual input may be in any `conversation_language`.

---

## Integration with Other Tasks

| Task | How it uses The Map |
|------|---------------------|
| **The Holocron** | Reads context (what was taught), writes new unit entry |
| **The Holocron (Mode C)** | Reads next planned unit, pre-fills parameters |
| **The Holocron (Revision)** | Writes `modification_notes` (the unit stays `active`; shown as "modified") |
| **The Holocron Log** | Sets status to `completed` and writes the `reflection` object |
| **Challenge Accepted** | Reads for multi-unit scope, checks for modified units |

---

## Notes

- One school year plan per (subject, grade, school year) combination
- The school year plan **data** is JSON (no `_{draft_suffix}` cycle applies to it); The Map additionally renders the derived year overview (Schuljahresübersicht) `.docx` — see *Year Overview Document* below
- Units are numbered sequentially within the school year
- The plan persists across sessions — it is the primary cross-session bridge
- If the teacher starts a new school year for the same subject/grade, a new file is created

---

## Year Overview Document (Schuljahresübersicht)

- **Ownership + generation:** The Map generates and regenerates the year overview — a pure derivative rendered from the current school year's `plan.json` (plus the class definitions), placed at the `<WORKSPACE_ROOT>/` root, its filename resolved via `naming-conventions.json` `documents.year_overview` (= `{year_overview_label} {school_year}`). No `_{draft_suffix}` cycle applies and it is never hand-edited — a teacher edit would be overwritten on the next regeneration.
- **Scope:** The year overview covers the current school year only.
- **Regeneration trigger + past-year exclusion:** the overview is regenerated on every content-mutating write to the current school year's `plan.json`; A content-mutating write to a past school year's `plan.json` never regenerates the overview.
- **Freshness check (read-side trigger):** on reading the current school year's `plan.json`, the overview is **fresh iff `rendered_rev == content_rev`** — the `year_overview` record's `rendered_rev` compared against the plan's monotonic `content_rev`. The normative freshness invariant is owned by the schema (`${CLAUDE_PLUGIN_ROOT}/references/schemas/school-year-plan.md` → *Freshness State*); this is its read-side trigger. A `rendered_rev` trailing `content_rev`, **or** an absent `year_overview` record while `content_rev` ≥ 1 (content-mutating writes happened but no overview was ever rendered), means the overview is **stale** → regenerate it through the Output-Gate Runner and note the repair. Past school years are exempt: a past year's `content_rev` is frozen and read-only, so a `rendered_rev` trailing it there is never a repair trigger.
- **Hyperlink emission:** every unit row links to that unit's unit plan (Einheitenplanung) per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Referenced-file hyperlinks* (the validated file preferred, `_{draft_suffix}` fallback, each exists-checked before emission; manual/no-file rows stay plain text).
- **Runner per regeneration:** every regeneration writes a document → it runs through the Output-Gate Runner (`${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` Step 5), emitting its gate-outcome lines (metadata + referenced-file-hyperlink gates) before the overview is presented or relied on.
- **Canonical class order:** `subjects.json` array index → grade band (Sek I numeric ascending, then Sek II semester-designated courses) → `section` (nulls last) → `class_id` tiebreak; **locale-invariant** (no display-label sorting), so two regenerations from identical data produce identical section order in any locale.
