---
name: status
description: Status und Überblick. Use when the teacher wants a status overview (Status / Überblick) — which units are planned, in progress, or validated, and competency-coverage gaps across the current school year.
when_to_use: |
  DE + EN: "Status", "Überblick", "wo stehe ich?", "was ist offen?", "welche Einheiten sind fertig?", "status", "overview", "what's pending?". Chat-only summary.
---

# /thalura:status — Project Status

> Core protocols — startup, HiTL/draft lifecycle, preferences, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).
>
> **Stub** — full status aggregation to be implemented.

Shows the current state of the teacher's Thalura project: active school year, classes, units in progress, competency coverage, and upcoming work.

---

## Core Protocols

All shared protocols are defined in `skills/core/SKILL.md`:

- **Startup sequence** (Steps 2–13) — loads profile, config, and school year data

## Workflow

1. Run the core startup sequence (Steps 2–6 only — no subject/grade identification needed)
2. Read `<WORKSPACE_ROOT>/data/school-years/{year}/plan.json` for all active school year plans
3. Read class definitions for active classes
4. Aggregate status: units by stored status (planned / active / completed) — a `completed` unit with a non-null `reflection` object is shown as "reflected", and an `active` unit with a non-null `modification_notes` is shown as "modified" (both derived/display labels, not stored statuses) — plus competency coverage gaps and draft documents awaiting validation. Render all status labels via `localization.json` → `unit_status_labels` (covering the three stored statuses and the two derived display labels "reflected" and "modified").
5. Present summary in chat. If the current-year year-overview file exists at `<WORKSPACE_ROOT>/` (resolved from `naming_labels.year_overview` + the current school year), name it in the summary (e.g. „die druckbare Übersicht liegt unter `Schuljahresübersicht 2025-26.docx`").

**Freshness sweep (touchpoint-local).** On reading a manifest you are about to rely on — a unit's `plan.json` (for its draft/validated documents) or the current school year's `plan.json` (for the year overview (Schuljahresübersicht)) — check the generated documents behind the summary: a generated-document entry with a missing or failing `gates` record, or a year overview whose freshness marker trails the current plan state (`rendered_rev` behind `content_rev`, or the `year_overview` record absent while `content_rev` ≥ 1), is a **detected deviation**, not a display gap. Run the verifier on the existing artifact now (the Output-Gate Verifier is the mechanism of record; any equivalent evidence-producing method conforms — backfill the record; escalate-or-flag per gate), regenerate the stale year overview through the Output-Gate Runner (`${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` Step 5) — status is chat-only, but a document regeneration still routes through the runner, never an inline write — and note the repair in the summary. Never silently proceed over a hole. Scope stays **touchpoint-local**: only the unit(s) and the year actually being read, no workspace-wide crawl. Past school years are exempt (read-only, never re-rendered). *(Honesty note: the sweep never re-opens artifacts whose `gates` records read as passing — in-product detection of a fabricated passing record is nil; that detection is probe-time only.)*

## Expected Outputs

| Output | Location | Format |
|--------|----------|--------|
| Status summary | Chat | Conversation |

## Reference Files

| File | Used in | Purpose |
|------|---------|---------|
| `skills/core/SKILL.md` | Startup | Core protocols |
| `${CLAUDE_PLUGIN_ROOT}/references/schemas/school-year-plan.md` | Step 3 | Plan schema for status aggregation |
| `${CLAUDE_PLUGIN_ROOT}/references/localization.json` | Step 4 | `unit_status_labels` — localized display of unit statuses |
