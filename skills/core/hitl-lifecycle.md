# Thalura — HiTL & Draft Lifecycle (core satellite)

Loaded on demand by the seven document-producing tasks (The Holocron, The Upside Down, The Playbook, The Multiverse, Challenge Accepted, Eleven's Vision, and The Holocron Log). The always-on `core` skill keeps the Chat-vs-Document medium rule; this satellite carries the two approval gates, the `_{draft_suffix}` lifecycle, and the Output-Gate Runner. The reflection (Reflexion) task (The Holocron Log) is document-producing: it writes `{reflection}_{draft_suffix}.docx` and runs the full draft cycle and the runner like every other document-producing task. Advisory tasks (The Sacred Texts, Yoda's Wisdom) do not load it. The Map stays advisory for the approval gates (Steps 3/6) and the `_{draft_suffix}` draft cycle — its year plan is JSON, nothing to approve — but its year-overview (Schuljahresübersicht) regeneration writes a document, so The Map loads and executes the **Step 5** Output-Gate Runner section only for that derivative. **Document-producing ≠ compliance-gated:** loading this satellite (and running the runner) is independent of the Step-4 compliance quick-check — reflection produces a document yet stays on the Step-4 exclusion list.

## Integrated 8-Step Flow (HiTL + _{draft_suffix} Lifecycle)

Two approval gates: **proposal approval** ("create this") and **validation** ("this is final").

**Step 1 — Proposal (chat):**
- Present structured proposal in chat (never as a document)
- Include: scope, key parameters, estimated structure
- Nothing written to disk

**Step 2 — Proposal Feedback (chat):**
- Teacher iterates on the proposal ("add X", "remove Y")
- Cycle repeats until teacher is satisfied
- Still no files on disk

**Step 3 — Proposal Approval (chat):**
- Teacher says "go" / "mach das so" / approves
- **First approval gate** — approves the plan, triggers file generation
- Input validation rule: never assume missing inputs; ask and wait

**Step 4 — Internal Compliance Gate (automatic):**
- **Applies to:** Holocron, Upside Down, Playbook, Multiverse, Challenge Accepted, Eleven's Vision
- **Does NOT apply to:** The Map, Holocron Log, Sacred Texts, Yoda's Wisdom
- Runs on the generated content BEFORE writing `_{draft_suffix}.docx` to disk:
  1. Sacred Texts quick-check on the draft content
  2. Auto-fix silently where possible
  3. Flag remaining issues (reported in the Step-5 gate-outcome block)
- **Configurable:** `internal_compliance_check` (boolean, default: `true`) — resolved from the two-tier behaviour config: read `<WORKSPACE_ROOT>/data/config/behaviour.json` (teacher override) overlaid on `${CLAUDE_PLUGIN_ROOT}/config-defaults/behaviour.json` (plugin default); effective value = teacher override if the key is present, else plugin default. Absent ≡ `true`. Schema: `${CLAUDE_PLUGIN_ROOT}/references/schemas/behaviour.md`.
- **Reported in Step 5:** this quick-check's outcome is folded into the Step-5 gate-outcome block, so an absent compliance line is itself the signal that the gate was skipped.
- **Late-compliance recovery (no fabricated "ran"):** if at Step-5 report time the quick-check never ran (the flow jumped straight to authoring), do **not** fabricate a "ran" line and do not merely flag the omission — run the quick-check **now**, pre-presentation, on the written content, and report the outcome honestly with an **ordering-deviation note** (it ran post-write instead of pre-write).
- Also runs again on every revision (Step 7)

**Step 5 — Draft Delivery (document):**

Every deliverable is delivered in one ordered, mandatory sequence — **write → gate → report → present** — on every generation path (bundled-template fill, any fallback, in-place revision, a delegated out-of-band generation whose runner runs in the writing context and whose gate-outcome lines cross back in the delegate's structured return) and every doc-writing surface:

- **5a Write** — author the deliverable from its template with whatever document-authoring capability the environment exposes (e.g. the official `docx`/`pptx` skills, or direct OOXML manipulation) — chosen at runtime, never a bundled script. **Write gate:** the written file must open without repair in Word/Microsoft apps, retain the template's branded header/footer and named styles, and contain the generated content; if the chosen capability cannot meet that gate, escalate to another method, and if none can, flag the shortfall to the teacher rather than shipping a corrupt or styleless file.
- **5b Run the Output-Gate Runner** — produce **machine evidence** for every applicable gate below, each a *verify-then-escalate-or-flag* loop with a concrete read-back, **and write the resulting `gates` record into the document's manifest entry**. The reference mechanism for the read-back is the shipped verifier `${CLAUDE_PLUGIN_ROOT}/scripts/verify_output.py` (one invocation over the written file; it emits per-gate evidence JSON whose `gates` block lifts verbatim into the manifest record, and it never edits the artifact). This is **gate-defined, not tool-bound**: any equivalent evidence-producing method conforms — e.g. the official `docx`/`pptx`/`pdf` skills' own inspection paths, or a direct `unzip` + read-back — so the model runs whatever the environment offers and checks its output against the gates below. The authoritative contracts live in `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md`; the rows below are the read-back checklist, not a second copy of the contract. The record vocabulary is the manifest schema's — an evidence source (`verifier` / `equivalent` / `imported`) plus a per-gate outcome (`pass` / `fixed` / `flagged` / `n/a`) and the concrete read-back values — per `${CLAUDE_PLUGIN_ROOT}/references/schemas/unit-manifest.md`.

  | Gate | Read back to verify | Full contract in `document-metadata.md` |
  |---|---|---|
  | Metadata (OOXML) | read `docProps/core.xml` + `docProps/app.xml` from the written file (a `.docx`/`.pptx` is a zip — e.g. via `unzip` or any archive capability) and confirm the metadata contract: `dc:creator`/`cp:lastModifiedBy` = teacher, `Application` = `Thalura`, real `dcterms:created`/`dcterms:modified`, no authoring-library fingerprint in `app.xml` or `docProps/custom.xml` | *The Metadata Gate* |
  | Referenced-file hyperlinks | each referenced file that exists on disk carries a real clickable relative-path hyperlink — e.g. the OOXML `w:hyperlink` relationship element — never plain bracket text | *Referenced-file hyperlinks* |
  | Regulation-citation links | each resolvable citation carries a `<canonical_url>#page=N` (or bare `canonical_url`) hyperlink; unresolved citations stay plain text | *Regulation-citation links* |
  | Template fidelity | the written file carries its resolved template's lineage — the named styles and header/footer (docx) or master/layout (pptx) parts listed in the template's fingerprint sidecar (shipped next to each template; a workspace-override template is fingerprinted live) are all present in the file — or the record carries `absent-evidenced` backed by the recorded listing summary | *(sidecar next to the template; record shape in the manifest schema)* |
  | PDF-on-validation (Step 8) | read back the PDF document info — `/Author` = the teacher's full name (empty or a library name is the sole hard failure); `/Producer`/`/Creator` may carry the conversion engine's own identity but never an authoring-library fingerprint carried over from the source | *Validated-material PDF* |
  | Compliance quick-check (Step 4) | the Sacred Texts quick-check actually executed on the draft content, or was explicitly skipped by config | Step 4 above |

  **On a gate FAIL, escalate** — fix the artifact with any capability (e.g. restamp `docProps`, inject the missing hyperlink relationships, or fill the resolved template and re-flow the content), then **re-verify**: a `fixed` outcome requires a passing re-read of the artifact, never the fix's own claim.

  **Reachability bridge.** Run the verifier where both the script and the artifact are reachable; when no single side reaches both — the plugin tree host-side, the artifact in the shared workspace — materialize the script to the artifact's side and verify the materialized copy's integrity against its shipped checksum sidecar before trusting its output. The fingerprint sidecars ride the same bridge.

  **No-python floor.** Where no `python3` is available on the artifact's side, a shell read-back (e.g. `unzip` + `grep` of the document parts) qualifies as evidence recorded as `equivalent`; if no read-back capability exists at all, the gate outcome is `flagged` with the honest reason — never a silent pass.

  **Unfixable residuals.** Policy gates (metadata, referenced-file / citation links, template fidelity) → **deliver with a localized flag** naming the residual: the teacher gets the document plus the honest deficiency note (the existing `flagged` outcome). Integrity failures (a corrupt or unopenable file) → **withhold, flag, retry** per the 5a write gate. A gate-failing artifact is never *silently* delivered.

- **5c Report** each applicable gate's outcome — rendered from the recorded evidence values (the actual read-back strings, counts, and outcomes), never composed free-hand — in the chat confirmation (see the reporting requirement below).
- **5d Present** — deliver the document — **and not before 5c.**

**Presentation barrier:** *"Do not present, deliver, or `present_files` the document until every applicable output gate has run and its outcome is reported. Presenting a document before its gate report is a contract violation, not a shortcut."*

**Cross-context discharge (delegated writes):** when the write ran out-of-band, the barrier is discharged in the main session against the delegate's *relayed* `gates` record (the per-gate outcome lines it produced) — or, when the delegate returned no usable record (a missing report, or a failing line it did not itself escalate), against the Output-Gate Runner **re-run by the main session** on the written file — never against the delegate's mere assertion that it ran. Delegation changes *who executes* the gates, never *whether* they run.

**One-message rule:** 5c and 5d may ride a single delivery message — the gate-outcome block must be **in** (or before) the message that presents, never after it. Report-then-present is an ordering constraint, not a two-message ritual.

**Gate-outcome reporting requirement.** The confirmation MUST carry a compact outcome line per applicable gate. The internal taxonomy — the outcomes that must stay distinguishable — is: `verified` (read-back passed) · `escalated → verified` (a field was wrong, fixed via another method, re-verified) · `flagged` (no method satisfied it; residual named to the teacher) · `n/a` (gate does not apply to this document kind) · and, for the compliance quick-check, `ran (N findings)` / `skipped (internal_compliance_check=false)`. The manifest record's vocabulary maps one-to-one onto this reporting taxonomy: a recorded `pass` renders as `verified`, a recorded `fixed` as `escalated → verified`; `flagged` and `n/a` are shared by both. **A confirmation with no gate-outcome block is itself the violation signal** — it means the runner did not run. A gate-outcome block **not backed by a written `gates` record or concrete read-back evidence** is equally a violation — an unbacked block is treated exactly like an absent one, and the block itself is rendered *from* those recorded evidence values, never composed free-hand. **Teacher-facing rendering (localized):** that taxonomy is the *internal* classification; the teacher never sees raw English jargon (`verified` / `n/a` / `ran (N)`). The block renders compactly in `conversation_language`, glossary-aligned via `${CLAUDE_PLUGIN_ROOT}/references/glossary-de.md` — a short summary naming what was checked, anything fixed, and any residual flagged. The wording is localized; the distinguishable-outcome requirement is not.

**Scope — generation and revision writes only.** The runner binds writes that *generate or revise document content*. Copy/pack paths — export (Export), backup (Sicherung), library (Bibliothek), and unit-exchange (Einheiten-Austausch) — copy already-gated files and never re-run the runner (re-stamping would rewrite `dcterms:modified` and contradict the plain-export ruling).

On the draft write, also:
- Create `{Name}_{draft_suffix}.docx` (suffix resolved via `localization.json`)
- Update `plan.json` with document entry, status `"draft"`
- Update school year plan if applicable
- Log observations if applicable

**Out-of-band execution (optional).** After an approval gate, a *mechanical* execution step — the template-fill-and-write of an approved deliverable, an approved-image prompt generation, an approved variant application, or a read-and-summarize of existing unit/lesson files — MAY run out-of-band via the available delegation mechanism (in Claude Code, the sub-agent/`Task` mechanism), and MUST produce an identical, identically-gated result when it runs inline instead. This is a **cost optimization, never a correctness gate**: a skipped or unavailable delegation degrades context economy, never the document. It is a preferred-path / inline-**fallback** pattern — **not a coin-flip** (the precedent is the branding-deck delegate). Its invariants:

- **Post-approval, mechanical only.** Only work downstream of an approval gate is delegable. Everything judgment-bearing or interactive — proposals, structured interviews, revision interpretation, lesson sequencing (lesson N depends on N−1) — stays in the main session; a delegate never interacts with the teacher (no interactive selection is available to it; all confirmations happen inline beforehand).
- **Self-contained payload.** The delegation prompt carries everything the delegate needs as model-resolved absolute paths and literal values — the approved content, the resolved output path(s) and naming values, and *pointers* to the authoritative contract files it must read (never inlined copies of contract prose — single-sourcing).
- **Artifact-only writes.** A delegate writes ONLY the named output artifact(s). Manifest (`plan.json`) updates, observation logging, config writes, and the material overview (Materialübersicht) regeneration stay **main-session** obligations — a half-failed delegate can strand a draft file but never corrupt tracked state.
- **Path-invariant correctness.** Every gate and contract that binds the inline path binds the delegated path identically — the Output-Gate Runner (Step 5), the clean-document/template rules, the template-lookup gate, manual-edit preservation, naming conventions, and the content ↔ layout boundary. "It ran in a sub-agent" is never a gate exemption.
- **Runner runs where the write happens; verified return; inline escalation.** A delegated write runs the Output-Gate Runner *inside the delegate's own flow* and returns the written path(s) plus the **per-gate outcome lines** in its structured return; the main session verifies the return against the gates and, on a missing or unusable return, runs the same work **inline** (verify-then-escalate-or-flag — never a silent skip). **The Step-4 compliance quick-check line is the one exception:** that quick-check runs main-session, pre-write (it stays main-session), so its outcome is carried into the payload as an explicit `compliance_quickcheck` field and the delegate **echoes** that field **verbatim** as its Step-4 compliance line (it relays, never re-derives it) — so the returned gate report is structurally complete and the "a confirmation with no gate-outcome block is itself the violation signal" rule holds end-to-end.
- **Fan-out is an option, not a requirement.** Where a site names a per-item fan-out (per image, per variant, per unit folder), items are independent and MAY run in parallel; sequential execution (delegated or inline) is equally conformant. No ordering or cross-item state may be assumed between fan-out items.

Delegation payloads carry **no inline layout values** (no widths, alignment, fonts, spacing, or colour literals); where a payload must reference presentation at all it binds by **named style or design-token key**, and the delegate resolves the values from the layout layer (`${CLAUDE_PLUGIN_ROOT}/references/template-specification.md` + `${CLAUDE_PLUGIN_ROOT}/references/design-tokens.json`) itself.

**Step 6 — Draft Review (document, teacher-side):**
- Teacher opens `_{draft_suffix}.docx` in Word/Microsoft apps
- Reviews content, optionally adds Word comments on specific passages
- No skill involvement — teacher works offline in the document

**Step 7 — Draft Revision (chat + document, repeatable):**
- Teacher returns and says "Revise" (with optional chat feedback)
- Skill reads the .docx including Word comments + any chat feedback
- **Detect whether the teacher manually changed the file first.** Before revising, determine whether the teacher has manually edited this document (a replaced image, edited or added content, manual formatting). This is behavioural: inspect the file, use what the teacher says, and **ask if unsure**. **Conservative default — if you cannot confidently tell the file is comments-only or unmodified, treat it as modified** and edit it in place. This classification decides the revision path; it is a **hard rule**, not a tunable preference.
- **Manual-edit preservation (hard rule).** Anything in the document that the `plan.json` manifest and what the skill last wrote do not account for — a replaced or re-saved embedded image, inserted or edited text runs, changed formatting — is **presumed a teacher edit**, never an artifact, bloat, or a leftover to clean up. An embedded image whose bytes or size differ from the generated one is the teacher's chosen image (an application re-save alone changes bytes and size — larger is not "bloat"); a stray-looking string or marker is the teacher's own insertion. Teacher edits are **never removed, reverted, or "cleaned up"** during a revision unless the teacher's instruction or a Word comment explicitly covers that content. If a teacher edit obstructs the requested change, **ask the teacher — don't decide.**
- Compliance gate (Step 4) runs again on revised content
- Apply the matching revision path:
  - **Modified beyond pure comments** (a replaced image, edited or added content, manual formatting) ⇒ **edit the existing file in place.** Surgically modify the existing file, preserving the teacher's manual edits, the branded header/footer, and the styles. **Never rebuild it from the template or from scratch.** Do the in-place document surgery with whatever document-editing capability the environment exposes — e.g. lxml on the `.docx`/`.pptx`, or the official `docx`/`pptx` skills — chosen at runtime; never a bundled script. After the in-place edit, refresh `cp:lastModifiedBy` (teacher name) and `dcterms:modified` (real current time), preserve `dc:creator` and `dcterms:created` from the original write, and re-assert `Application = Thalura` (an edit capability may rewrite `app.xml`) — per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md`.
  - **Comments-only** (the only difference is Word comments the teacher added) ⇒ regeneration is permitted: incorporate the comments as change requests and clean up the resolved comments via the existing comment mechanics.
  - **Unmodified** (the file matches what the skill last wrote) ⇒ full regeneration is safe, overwriting the previous draft. **Only here** may a persisted "revise in place" preference apply — and it may only ever reinforce the in-place path, never relax it for a modified file.
- **Route the revised output through the Output-Gate Runner (Step 5).** After the in-place edit (or the permitted regeneration), the revised output runs the same Output-Gate Runner before it is presented, producing its own gate-outcome lines; the Step-4 compliance quick-check re-runs and folds into that report. Do not present the revised document until its gate report is produced. For an in-place edit, the **template-fidelity gate is satisfied as preserved lineage** — the template's named styles and header/footer parts survive the surgical edit (the manual-edit-preservation rules above guarantee it), so fidelity is asserted, never treated as a rebuild trigger.
- Updates `plan.json` version counter
- If the revision changes the document's filename and the document is a unit material, regenerate the material overview ({material_overview}) — its rows must always show the current filenames, each emitting its relative-path hyperlink affordance (`[DOCX]`/`[PPTX]`, + `[PDF]` when a `pdf_path` exists) per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Referenced-file hyperlinks*
- Reports changes in chat
- **This cycle (Steps 6–7) can repeat** until teacher is satisfied

**Step 8 — Validation (chat):**
- Teacher says "Validated"
- **Second approval gate** — approves the document content
- Skill renames `{Name}_{draft_suffix}.docx` → `{Name}.docx`
- Updates `plan.json` status from `"draft"` to `"validated"`
- Auto-regenerates the material overview ({material_overview}) if the unit tracks one — a validated material's row updates to the final filename and the draft marker ({draft_marker}) is dropped; the regenerated row emits its relative-path hyperlink affordance per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Referenced-file hyperlinks* — the editable `[DOCX]`/`[PPTX]` link (the `[PDF]` link is added by the post-PDF regeneration below, once `pdf_path` exists, per the verify-exists-then-emit gate). This overview regeneration writes a document, so it too runs through the Output-Gate Runner (Step 5) with its own gate-outcome lines.
- **Post-validation PDF generation:** after the rename and status flip, generate `<validated-base>.pdf` alongside the source (extension-swap on the already-resolved final validated name — no separate naming-conventions.json key) when the material is **student-facing** (see kind set below) **or** `pdf_on_validation` is `"all"`. Generate the PDF and read back its PDF metadata **through the Output-Gate Runner (Step 5)** (the PDF gate), producing its gate-outcome lines before the PDF is relied on. Register the resulting path as `pdf_path` in `plan.json`, per the generation and metadata contract in `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` (Validated-material PDF section). When `pdf_on_validation` is `"off"`, skip generation and **leave any existing PDF untouched** — never auto-delete a PDF the teacher may have kept. **After `pdf_path` is registered, regenerate the material overview once more** so the validated row now carries the `[PDF]` link alongside the editable file (the verify-exists-then-emit gate emits `[PDF]` only once the PDF exists on disk); this regeneration writes a document, so it runs through the Output-Gate Runner (Step 5) with its own gate-outcome lines.

  **Student-facing kind set (PDF by default):** materials whose `type` is one of `worksheet`, `handout`, `reading_text`, `slides`, `student_task_deck`, plus the assessment task paper (Aufgabe). **Differentiated variants** (Differenzierungsvarianten) inherit their base material's student-facing status — they are the copies actually distributed to students. This classification is gate-defined by kind and stated here once; a new document type is classified by adding it to this set, not by scattering audience flags.

  **Teacher-facing (PDF only under `"all"`):** the grading rubric (Erwartungshorizont), unit plan (Einheitenplanung), lesson plans (Verlaufsplan/Stundenentwurf), reflection (Reflexion).

  **Material overview excluded from both scopes:** the material overview (Materialübersicht) is an auto-generated derivative and never receives a PDF — excluded from `"student_facing"` and `"all"` alike.

  **Re-validation:** a validated material sent back to draft (Step 7) and re-validated (Step 8 again) **regenerates** the PDF from the current source, overwriting the previous one so the PDF never goes stale.

  The `pdf_on_validation` preference (default `"student_facing"`, values `"student_facing"` / `"all"` / `"off"`) is resolved from the two-tier behaviour config: read `<WORKSPACE_ROOT>/data/config/behaviour.json` (teacher override) overlaid on `${CLAUDE_PLUGIN_ROOT}/config-defaults/behaviour.json` (plugin default); effective value = teacher override if the key is present, else plugin default. Absent ≡ `"student_facing"`. Schema: `${CLAUDE_PLUGIN_ROOT}/references/schemas/behaviour.md`.

  **Overview linking:** the material overview (Materialübersicht) surfaces the validated PDF by hyperlinking it — the row's `[PDF]` affordance links the `pdf_path` sibling alongside the editable file, per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Referenced-file hyperlinks* (verify-exists-then-emit; relative path).

- **Downstream tasks unblock:** e.g., lesson detail planning refuses to run if the unit plan is still in draft status
- **Task-specific post-validation actions:** Some tasks define additional logic after validation (e.g., The Upside Down evaluates unit plan updates — see lesson-detail skill)

## Exceptions (No _{draft_suffix} Cycle)

- `plan.json` — auto-maintained manifest, never a draft
- `{material_overview}` — auto-generated derivative, regenerated on every event that changes the unit's material set: a material draft landing (creation), a revision that renames a material file, a variant landing (differentiation), and validation — never only on validation, so the overview never lags the visible contents of `{materials}/`. Draft materials are listed with their current draft filename and the localized draft marker ({draft_marker}). Each regenerated row emits its relative-path hyperlink affordance (`[DOCX]`/`[PPTX]`, + `[PDF]` when a `pdf_path` exists) per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Referenced-file hyperlinks*. Because each regeneration writes a document, it runs through the Output-Gate Runner (Step 5) — metadata + referenced-file-hyperlink gates — and emits its own gate-outcome lines before the regenerated overview is presented or relied on.
- `{year_overview}` — the workspace-root year overview (Schuljahresübersicht): an auto-generated pure derivative regenerated on every content-mutating write to the **current** school year's `plan.json` (a unit registered / status-flipped / revised / reflected, a class plan entry added, a library assignment landing). Draft units are listed with the localized draft marker ({draft_marker}); every unit row emits its relative-path hyperlink affordance ([DOCX], + [PDF] when a validated sibling exists) per `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Referenced-file hyperlinks*. Because each regeneration writes a document, it runs through the Output-Gate Runner (Step 5) — metadata + referenced-file-hyperlink gates — and emits its own gate-outcome lines before the regenerated overview is presented or relied on. **Freshness marker:** the year plan carries a monotonic `content_rev` (incremented on every content-mutating write listed above) and the overview record carries `rendered_rev`; the overview is **fresh ⇔ its `rendered_rev` equals the plan's `content_rev`**. Every mutating write's delivery report carries a localized `year_overview` line — `regenerated` | `n/a — past year` | `flagged` — fed from that freshness state, and a stale marker (a `rendered_rev` trailing `content_rev`, or absent) is itself a regenerate trigger. A content-mutating write to a **past** school year's `plan.json` never regenerates it.
- The Map output — the school year plan is stored as JSON in `plan.json` (never a draft); The Map additionally renders the derived `{year_overview}` overview (see the entry above)
- Yoda's Wisdom — advisory, chat-only, no document produced
- Sacred Texts — compliance report, chat-only
- Holocron Log — a document-producing task: it follows the standard `_{draft_suffix}` draft cycle and the Output-Gate Runner (may skip the proposal phase — direct interview → draft), and is excluded only from the Step-4 compliance quick-check
