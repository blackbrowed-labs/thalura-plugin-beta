---
name: differentiation
description: Material differenzieren. Use when the teacher wants differentiated variants of existing material (Differenzierung) for special needs — LRS, DaZ, HB, ADHS, etc.
when_to_use: |
  DE + EN: "Differenzierung", "differenziertes Material", "LRS-Version", "DaZ-Version", "Anpassung für ...", "differentiation", "accommodations", "LRS version". Adapts EXISTING material; NOT new material (→ material-gen).
---

# The Multiverse (`differentiate_assets`) — Differentiated Material Variants

> Core protocols — startup, HiTL/draft lifecycle, preferences, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).
>
> Before writing the `_{draft_suffix}` to disk (Step 4), the internal compliance gate runs a Sacred Texts quick-check. Load `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` for the full 8-step flow at the draft/validation step.

Creates differentiated versions of existing materials based on class definition and the special needs catalog.

---

## Purpose

Takes an existing asset (worksheet, handout, reading text, etc.) created by The Playbook and produces one or more differentiated variants tailored to specific learning needs (e.g., LRS, DaZ, HB, ADHS).

---

## Required Inputs

| Parameter | Type | Required | Example |
|-----------|------|----------|---------|
| `source_asset` | File | yes | An existing material created by The Playbook |
| `target_needs` | Enum[] | yes | ["LRS", "DaZ"] or ["HB"] |
| `class_id` | String | no | For automatic need detection and class definition sync |

---

## Logic (Step by Step)

1. **Read the source asset** — understand its content, structure, and cognitive demands.

   **Language:** The differentiated variant preserves the source asset's content language. If creating new content elements (e.g., vocabulary aids for DaZ), resolve language via the content language fallback chain (core skill satellite `${CLAUDE_PLUGIN_ROOT}/skills/core/content-language-gendering.md`, *Content Language Resolution*).

2. **Read the special needs catalog** (`${CLAUDE_PLUGIN_ROOT}/references/special-needs-catalog.md`) — load the standard differentiation measures for the target needs.

3. **If `class_id` is provided**, read the class definition from `<WORKSPACE_ROOT>/data/school-years/{year}/classes/`:
   - Check if the `target_needs` match the needs recorded in the class definition
   - Ask the teacher about additional or different needs
   - If the teacher reports changes: offer to update the class definition

4. **For each target need**, apply the standard differentiation measures from the catalog:

   | Need | Key Measures |
   |------|-------------|
   | **LRS** | Larger font (min 14pt), extended layout, reduced text density, same cognitive demand, oral alternatives noted |
   | **DaZ** | Bilingual glossary, simplified instructions alongside original, visual scaffolding, sentence starters |
   | **HB** | Extension tasks with higher AB levels, advanced source texts, open-ended research questions |
   | **ADHS** | Shorter sections (max 15 min blocks), visual phase markers, checklists, clear structure |
   | **ASS** | Predictable structure, written instructions, reduced group work or structured roles |
   | **KB** | Digital alternative formats, flexible layout, extended time notes |
   | **SB** | Large print, high contrast, verbal descriptions of visuals |
   | **AUD** | Visual instructions, written task cards, reduced audio dependency |

5. **Maintain cognitive demand:** Differentiation adjusts access, not expectation. LRS students get the same thinking tasks in a more accessible format. HB students get extended tasks on top of the core tasks.

6. **Cross-topic knowledge check:** If the source asset references unfamiliar concepts, ensure the differentiated version includes additional scaffolding.

7. **Create separate file(s)** for each variant — **derived from the source, never built from scratch.** For each variant, **copy the source asset and apply the differentiation measures in place on the copy**, so it inherits the source's branded header/footer and styles. Never build a variant from a blank document or from raw content. If the source itself was manually changed beyond comments (a replaced image, edited or added content, manual formatting), copy the **modified** source **as it currently stands on disk** so the teacher's edits carry into the variant — do not regenerate a clean source first. This is a **hard default.** Anything in the source that its `plan.json` manifest entry and the last generation do not account for — a replaced or re-saved embedded image, inserted or edited text, changed formatting — is **presumed a teacher edit** and travels into the variant unchanged: never stripped, reverted, or "cleaned up" while differentiating, unless a differentiation measure explicitly requires changing that content. Where a teacher edit collides with a differentiation measure, ask the teacher — don't decide.

   > **Manifest sweep (touchpoint-local).** On reading a manifest (`plan.json`), check the generated documents you are about to rely on: a document entry with a missing or failing `gates` record — or a year overview (Schuljahresübersicht) whose freshness marker (`rendered_rev`) trails the current plan state (`content_rev`) — is a **detected deviation**, not a fact to accept. Produce gate evidence for the existing artifact now (the Output-Gate Verifier is the mechanism of record; any equivalent evidence-producing method conforms), backfill the record and escalate-or-flag per gate, regenerate a stale year overview through the runner, and note the repair in chat. Never silently proceed over a hole. *(Honesty note: entries whose `gates` records already read as passing are never re-opened — in-product detection of a fabricated passing record is nil; that is a probe-time concern only.)* Sweep only the unit/year actually being read — no workspace-wide crawl — and repair records and derivatives, never content.

8. **Name with need code suffix:**
   - Validated (final) file: `M{number}-{Type}-{Topic}_{need_code}.docx`
     - Example: `M01-Worksheet-Globalisation_LRS.docx`
   - Draft file written to disk: `M{number}-{Type}-{Topic}_{need_code}_{draft_suffix}.docx`
     (the draft suffix is system-managed and resolved via `localization.json` — last component before the extension)
     - Example: `M01-Worksheet-Globalisation_LRS_{draft_suffix}.docx`

9. **Create the proposal** and present to the teacher in chat

---

## Proposal Format

```
Differentiated Version: {source_asset_name}
Target Group: {target_needs}
Class: {class_id} (if provided)

--- Changes from Original ---

For {need_code}:
- {change 1}: {description}
- {change 2}: {description}
- {change 3}: {description}

Cognitive Demand: {maintained / extended / scaffolded}

--- Preview ---
[Key sections of the differentiated content]
```

The proposal is output in `conversation_language`. The template above shows the English structure; localized labels are resolved via `localization.json`.

---

## After Approval (Steps 4-8 of the HiTL Flow)

1. **Internal compliance gate** (Step 4): Sacred Texts quick-check on the generated content.

2. **Generate the differentiated file(s)** (Step 5):
   - Write the draft file `M{number}-{Type}-{Topic}_{need_code}_{draft_suffix}.docx` to `{materials}/` in the unit folder (the draft pattern from Step 8; `{draft_suffix}` resolved via `localization.json`)
   - Run the Output-Gate Runner (`${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` Step 5) on the written output; do not present until its gate-outcome report is produced.
   - **Out-of-band option — one delegation per approved variant** (see `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` → *Out-of-band execution*). Each variant's copy-and-apply MAY run out-of-band; per-variant delegations are independent and MAY run in parallel. The payload names the **source file on disk** and the catalog-sourced measures for that `target_need` (from `${CLAUDE_PLUGIN_ROOT}/references/special-needs-catalog.md`); the delegate **copies the source as it currently stands on disk** — the manual-edit-preservation hard default applies to the delegate exactly as inline: anything the `plan.json` manifest and the last generation do not account for is **presumed a teacher edit** and travels into the variant unchanged, never stripped or "cleaned up". The delegate runs the Output-Gate Runner and returns the variant path plus the per-gate outcome lines; the main session collects the returns and owns the manifest + material-overview updates. A missing or unusable return is failed verification: run that variant inline.
   - Update `plan.json` manifest
   - Regenerate the material overview ({material_overview}) — each variant's row appears immediately, showing its current draft filename with the localized draft marker ({draft_marker})

3. **Update observations** (continuous): Log the teacher's choices

4. **If class definition was updated:** Confirm the changes are saved

5. **Teacher reviews and validates** (Steps 6-8): Standard `_{draft_suffix}` revision cycle.

---

## Class Definition Sync

This is a key feature of The Multiverse. When a `class_id` is provided:

1. **Compare** the requested `target_needs` with the needs in the class definition
2. **Ask about additional or different needs** — the class may have changed since the definition was created
3. **Offer to update** the class definition if the teacher reports changes
4. This ensures the class definition stays current without requiring a separate update step

---

## Notes

- The Multiverse does not modify the original asset — it creates new files alongside it. Each new file is **derived from** the source (copied, then differentiated in place on the copy), inheriting its branded header/footer and styles — **never built from scratch.** This is a hard default. The copy is always of the source **as it currently stands**: the teacher's manual edits travel into the variant unchanged and are never stripped or "cleaned up" while differentiating.
- Multiple need codes can be combined in one variant if the measures are compatible (e.g., LRS + DaZ)
- If measures conflict (e.g., HB extension vs. ADHS shorter sections), create separate variants
- The teacher can request differentiation for needs not in the catalog — the skill creates a custom variant and asks if the new need should be added to the class definition
