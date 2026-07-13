---
name: reflection
description: Einheit reflektieren. Use when the teacher wants to reflect on a finished teaching unit (Reflexion einer Unterrichtseinheit) — what worked, what to change next time.
when_to_use: |
  DE + EN: "Reflexion", "Einheit reflektieren", "was lief gut/schlecht?", "reflect on the unit", "what worked?". Post-unit reflection; NOT planning a new unit.
---

# The Holocron Log (`reflect_unit`) — Unit Reflection

> Core protocols — startup, HiTL/draft lifecycle, preferences, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).

Captures the teacher's reflection after completing a unit. Feeds back into future planning, observations, and class definitions.

---

## Purpose

After a unit is taught, the teacher reflects on what worked, what didn't, and what to change next time. This reflection:
- Is stored in the school year plan (the unit's `status` is set to `completed` and a non-null `reflection` object is written — a `completed` unit with a `reflection` object *is* the "reflected" state, a derived/display label rather than a stored status value)
- Creates `{reflection}.docx` in the unit folder (follows standard `_{draft_suffix}` cycle)
- Feeds method feedback into `<WORKSPACE_ROOT>/data/profiles/teacher-observations.json` (with immediate threshold check)
- Feeds class-specific feedback into the class definition

---

## Trigger

The skill suggests reflection when:
- A unit's status changes to `completed` in the school year plan
- The teacher explicitly initiates it: "I want to reflect on the unit"

---

## Questions Asked

Present all questions together. The teacher may answer in one or multiple steps.

| # | Question | Purpose |
|---|----------|---------|
| 1 | What worked particularly well? | Identify successful elements for reuse |
| 2 | What would you do differently next time? | Capture improvement ideas |
| 3 | Which methods were particularly effective / ineffective? | Feed into teacher observations |
| 4 | Were there surprises or unexpected difficulties? | Capture contextual insights |
| 5 | How well did the content align with the curriculum standards (Bildungsplan)? (too much / just right / too little content) | Calibrate future planning |

---

## Target-Period Gate

A reflection is always retrospective, so it targets a **past or current** school year/semester only — never a future one. This gate resolves the target period **before** any write and refuses a future target.

- **Past or current only.** The unit's target school year/semester, judged at the session date via the core skill's school-year derivation (its Step 2 date derivation), must be the current school year or earlier. A **future** school year — or a future semester within the current year, where determinable — is **never** a valid reflection target. The skill does not silently pick a year; it resolves the target period through the routing below and refuses a future target.
- **Route year resolution through the core skill.** Do **not** re-implement year derivation here — the core skill is the single owner of year detection. Use its year-context logic: the date-derived **default** year, the "an explicit teacher cue overrides the default" rule, and — decisively — its ambiguity rule ("ambiguity → ask in `conversation_language`, never silently guess across a year boundary"). This gate's own contribution is the **past/current-only constraint** and the **not-found flow** below; year *detection* stays owned by the core skill.
- **The question precedes the write.** This gate runs **before** any write to `plan.json`, the unit folder, or the class definition. The target period must be confirmed *first*. A stated-assumption flag written *after* the write does **not** satisfy this gate.
- **Class-observation writes are unchanged.** Class-specific feedback still writes to the class's **current** class definition (`class_observations`), exactly as before. This gate governs the **plan entry** and the **unit folder** only — not the class-observation write.

---

## Logic

1. **Identify the unit and its target period.** Search across `<WORKSPACE_ROOT>/data/school-years/*/plan.json` for a unit matching the teacher's description (title + class). This replaces the old "read *the* school year plan" step, which presumed a single existing plan entry. Three outcomes:
   - **Found in exactly one past/current-year plan** → that is the target period; proceed (no year question is needed unless the teacher's cue conflicts with it, in which case the core skill's ambiguity rule applies).
   - **Found in more than one year** → **ask** which occurrence the teacher means, in `conversation_language` (the core skill's ambiguity rule; e.g. *"Meinst du „Growing up" aus 2024-25 oder 2025-26?"*).
   - **Not found in any plan, or found only in a future-year plan** → the **not-found / retroactive-year flow** below. A match found **only** in a **future** year does **not** count as found — it is treated as *not a valid target*, the true (past/current) period is resolved with the teacher, and the future-year occurrence is never written to.

   **Not-found / retroactive-year flow** (the pre-Thalura / past-year case — the unit was taught before Thalura or in a year not yet recorded):
   - **State it transparently** in `conversation_language`: the unit is not recorded in any existing plan (e.g. it was taught before Thalura), so its target school year/semester must be confirmed. Do **not** invent a year.
   - **Resolve the target period explicitly with the teacher.** Offer the core skill's date-derived current year as a **default suggestion**; the teacher confirms or overrides it. The resolved year must be past or current; if the teacher names a **future** year, **refuse** it and re-ask (a reflection cannot target the future).
   - **Missing past/current-year folder → ASK, never auto-fall-back.** If the resolved (past/current) year's `<WORKSPACE_ROOT>/data/school-years/{year}/` folder does not exist, **ask** (in `conversation_language`) whether to create it retroactively. Only on confirmation is the folder/plan scaffolded — reusing the core skill's empty-plan scaffolding (its Step 10 hard-block plan creation) — and the reflection recorded there. **Never** default to whatever year folder happens to exist. Retroactive creation does **not** run the year-transition continuation proposal (that flow is forward-looking class scaffolding, not retroactive reflection).
2. **Read the unit plan ({unit_plan})** and any lesson files in `{lessons}/` for context — remind the teacher of the plan. **Cross-year continuity:** if the class definition has a `previous_year` link, you may also reference **prior years'** reflections for this group — by default the immediate prior year's `reflection` from `<WORKSPACE_ROOT>/data/school-years/{prior_year}/plan.json` (`strengths` / `improvements` / `reuse_recommendation`, plus the prior class definition's continuity notes), walking the full chain only on explicit request. This read is **read-only**, **degrades silently** on a missing/broken link and is bounded at **8 hops**, surfaces **pedagogical prose only** (never the raw internal `data/` JSON), and reads pedagogical notes only — no grades, no multi-year analytics.

   > **Manifest sweep (touchpoint-local).** On reading a manifest (`plan.json`), check the generated documents you are about to rely on: a document entry with a missing or failing `gates` record — or a year overview (Schuljahresübersicht) whose freshness marker (`rendered_rev`) trails the current plan state (`content_rev`) — is a **detected deviation**, not a fact to accept. Produce gate evidence for the existing artifact now (the Output-Gate Verifier is the mechanism of record; any equivalent evidence-producing method conforms), backfill the record and escalate-or-flag per gate, regenerate a stale year overview through the runner, and note the repair in chat. Never silently proceed over a hole. *(Honesty note: entries whose `gates` records already read as passing are never re-opened — in-product detection of a fabricated passing record is nil; that is a probe-time concern only.)* The reflection document written below is itself a generated-document entry that carries a `gates` record like any other. Sweep only the unit/year actually being read — no workspace-wide crawl — and repair records and derivatives, never content.
3. **Present the questions** — all at once. This is a direct interview, may skip the proposal phase.
4. **Process the answers:**
   - General method feedback → write to `<WORKSPACE_ROOT>/data/profiles/teacher-observations.json` (with immediate threshold check)
   - Class-specific feedback → write to class definition (`class_observations` array)
   - For class-specific feedback, ask: "Should I remember this? (Will be saved as an observation for this class.)"
5. **Create a structured reflection summary** and present it to the teacher for confirmation.
6. **After approval:**
   - Create `{reflection}_{draft_suffix}.docx` in the unit folder using `${CLAUDE_PLUGIN_ROOT}/templates/planning/template_reflection.docx` (see `${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` — Planning Document Templates; standard `_{draft_suffix}` cycle)
   - Run the Output-Gate Runner (`${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` Step 5) on the written output; do not present until its gate-outcome report is produced.
   - Update school year plan: set `status: "completed"` and write the `reflection` object
   - Update `plan.json` manifest in the unit folder
   - **If the reflected unit's school year is the current year**, regenerate the year overview (Schuljahresübersicht) through the Output-Gate Runner. A retroactive past-year reflection mutates a past `plan.json` → no regeneration (current-year-only scope; `${CLAUDE_PLUGIN_ROOT}/skills/year-planning/SKILL.md` → *Year Overview Document*)
7. **Library fold-back offer (after the writes).** When the confirmed `reuse_recommendation` is `"reuse_as_is"` or `"reuse_with_changes"`, offer — in `conversation_language`, once, never insisting — to carry the unit into the library (Bibliothek):
   - Unit **not in the library** (its manifest has no `library_ref`): offer plain shelving (*„Soll ich die Einheit in die Bibliothek stellen, damit du sie wiederverwenden kannst?"*). If a same-title unit already sits in the library, the shelve flow's own version detection asks the new-version-or-own-unit question — the offer here stays one simple sentence.
   - Unit **from the library** (`library_ref` present) **and changed** — the teacher chose `"reuse_with_changes"` or the plan entry carries a non-null `modification_notes`: offer a **new version (neue Fassung)**: *„Deine Änderungen könnte ich als neue Fassung in der Bibliothek ablegen — die bisherige Fassung bleibt erhalten. Soll ich?"* (the shelve flow pre-seeds the version note from this reflection's `improvements` and the unit's `modification_notes`).
   - Unit **from the library and unchanged** — `"reuse_as_is"` with `null` `modification_notes`: nothing to fold back — the library already offers this state; say so in one sentence (*„Die Einheit liegt unverändert in deiner Bibliothek — da gibt es nichts zu übernehmen."*), no question asked.
   - Accepting **hands off to the shelve flow** in `${CLAUDE_PLUGIN_ROOT}/skills/library/SKILL.md` — no re-implementation here; its gates (validation, snapshot, version detection, note gate) run unchanged.
   - `"redesign"` and `"shelve"` trigger **no** offer — `"shelve"` here means *retire, don't reuse*, not the shelve-unit flow; and a unit completed **without** a reflection **never triggers an offer** from anywhere (the teacher can still ask explicitly at any time).
   - Declining is final for the session — never re-offer in the same session.

---

## Reflection Output Format

```
Reflection: {unit_topic}
Subject: {subject} | Grade: {grade_level}
Time period: {time_period}

--- What Worked Well ---
[Teacher's positive feedback, structured]

--- What I Would Change ---
[Teacher's improvement ideas, structured]

--- Method Effectiveness ---
| Method | Assessment | Notes |
|--------|-----------|-------|
| {method} | effective | {note} |
| {method} | ineffective | {note} |

--- Alignment with Curriculum Standards (Bildungsplan) ---
[Teacher's assessment of content fit]

--- Surprises / Difficulties ---
[Teacher's contextual insights]
```

The output is rendered in `conversation_language`. The template above shows the English structure; localized labels are resolved via `localization.json`.

---

## Impact on Future Planning

When The Holocron is called for a similar topic or the same grade/class in the future:
- The skill can reference past reflections for informed planning — **including prior years' reflections for the same group when the class definition has a `previous_year` link** (read-only, immediate prior year by default)
- Method effectiveness data influences Yoda's Wisdom recommendations
- Observation entries may trigger promotion proposals at session start

---

## Notes

- The Holocron Log does not create new instructional content — it captures and structures the teacher's reflection
- One reflection per unit (not per lesson)
- The teacher can update the reflection later by calling The Holocron Log again for the same unit
- Reflections are stored both in the school year plan (JSON, for cross-session access) and as `{reflection}.docx` in the unit folder (for documentation)
