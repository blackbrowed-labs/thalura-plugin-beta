---
name: index-regulation
description: Use to (re)generate the page-map / section-index sidecar for one bundled regulation PDF. Reads the PDF against quality gates, emitting <stem>.pagemap.json (printed↔physical map + heading→page-range index + per-section hazard escalation hints).
user-invocable: false
when_to_use: |
  Dev-time only, owner-invoked. Run on a single regulation PDF when adding a federal state, or when a bundled PDF is republished (source_pdf_sha256 changed) and its page-map is flagged stale. Not a per-task runtime cost.
---

# index-regulation — Page-Map Generator Skill

Generates a `<stem>.pagemap.json` sidecar for one bundled regulation PDF. The sidecar is the non-authoritative navigation layer that records the `printed ↔ physical` page map, the heading → page-range index, and per-section hazard escalation hints. It is read at use time by the regulation reader to open the correct physical page, cite the printed page a teacher verifies against, and know which sections require a visual escalation before the read begins.

**Non-authoritative status.** The page-map is never cited. A teacher never sees it; citation authority comes from the gate-passing read of the PDF itself. Its prose-fidelity ceiling is harmless: a slightly-wrong heading label costs a marginally wider read, never a wrong citation.

---

## What it produces

A single `<stem>.pagemap.json` file written **next to `<stem>.pdf`** under `${CLAUDE_PLUGIN_ROOT}/regulations/`, conforming to the schema defined in `${CLAUDE_PLUGIN_ROOT}/references/schemas/page-map.md`. The sidecar contains:

- **`document_id`** — the PDF's filename stem (machine join key, never shown to the teacher).
- **`document_title`** — the teacher-facing name, sourced and verified from the PDF itself (cover page / PDF `/Title` metadata, cross-checked against the rendered cover — never derived from the filename).
- **`source_pdf_sha256`** — SHA-256 of the bundled PDF at generation time, pinning the sidecar to a specific PDF version.
- **`index_version`** — bumped when the generator's schema or logic changes.
- **`physical_page_count`** — total physical pages, 1-indexed.
- **`page_identity`** — `model`, `offset`, and `flags` encoding the page-identity case (see schema for the full model table).
- **`page_table`** — explicit per-physical-page mapping; the source of truth for printed↔physical resolution, not `offset`.
- **`sections[]`** — heading → page-range index entries, each carrying `section_anchor`, printed and physical page ranges, `ordinance` (for composite documents), `grades`, and `hazards`.

The emitted sidecar must pass all six self-validation checks (see "Self-validation" below) before being written.

---

## Gate-defined walk

This walk is **tool-independent**: it specifies the quality gates each step must pass and a verify-then-escalate-or-flag loop. The runtime picks the best available method for each step, verifies the result against the gate, escalates to another method when a gate fails, and flags the residual rather than emitting a gate-failing result.

### Step (a) — Establish the page-identity model and record `page_table`

Page-identity resolution — the `printed ↔ physical` offset — cannot be derived from footer-digit scraping alone. Two traps make scraping unsafe without verification: the publication-year appearing in the Impressum's footer field, and footnote text bleeding into the footer. Both yield plausible-looking digit strings that are not printed page numbers.

**The verified-sample approach:**

1. Take a small sample of pages distributed across the document (cover, a few early content pages, a few mid-document pages, and the last few pages).
2. Read each sampled page cheaply to extract footer/header digit candidates.
3. **Confirm each candidate against a single-page render** (see "Single-page-render gate" below): render that physical page and visually verify the printed number shown in the footer. This is the gate — a candidate that does not match the rendered footer fails and is discarded. Publication years and footnote text are trivially distinguishable on the rendered page.
4. From the confirmed sample, derive the page-identity model:
   - If the offset `printed = physical + offset` is constant across all sampled pages, the model is `"simple"` and `offset` is that constant.
   - If the document is a composite of multiple legally distinct ordinances under continuous page numbering, the model is `"composite"` and `offset` is `null`.
   - If the document stitches sub-documents with restarting numbering (non-monotonic `printed_page` sequences), the model is `"restarting"` and `offset` is `null`.
   - If two physical pages share the same printed page number, the model is `"duplicate"` and `offset` is `null`.
   - Unnumbered pages (covers, Impressum, TOC) appear in `page_table` with `printed_page: null`.

5. **Derive** the remaining `page_table` entries from the confirmed model — render only the **irregular, boundary, hazard, and cover pages**, not every page. "Irregular" means: any page where the derived offset would predict a number outside the document's printed range, any page near a section heading boundary, any page flagged as a potential hazard (see Step (d)), the cover, the Impressum, and the last page. Pages that fall cleanly within the model's prediction between confirmed samples do not need individual renders.

6. Record every physical page in `page_table`, including unnumbered pages (`printed_page: null`, `kind` ∈ `{"cover", "impressum", "toc", "blank"}`).

**The `page_table` is the source of truth — not `offset`.** `offset` is a convenience shorthand valid only when `model == "simple"`. A reader resolving printed→physical always consults `page_table`.

### Step (b) — Extract headings into `sections[]`

Extract the document's heading structure to build the `sections[]` index. For each heading:

- Determine the `section_anchor` — the heading text exactly as it will appear in a citation key, joining the citation, the registry pointer, and the page-map on one string.
- Determine the physical and printed page range: `physical_page_start` / `physical_page_end` and `printed_page_start` / `printed_page_end`. For the printed range, use the `page_table` to convert from physical.
- **`physical_page_end` is the page where the section's text actually ends — not the last page on which it *starts*.** A section's text routinely spills past a physical page boundary and continues at the top of the next page *before* the next heading appears. That spill-over is part of this section: its end is the physical page on which the **next heading** appears (that shared page carries this section's tail above the heading), or — if the section is the last one — the last page carrying its text. **The failure mode to avoid:** ending a section at the last page it *starts* on. When a section starts and ends on page *E* but its final paragraph continues onto *E+1* above the next heading, an end of *E* makes that paragraph **unreachable** — the reader opens only the declared pages, so it is never seen and can never be cited. Concretely: if the next section's heading appears partway down page *E+1* with this section's prose above it, this section ends on *E+1*, and the two sections legitimately share page *E+1* (adjacent sections sharing a boundary page is normal). Confirm the end against the rendered/extracted *E+1*: material text preceding the next heading belongs to *this* section. Self-validation check 6 verifies this mechanically.
- For composite documents (`model: "composite"`), set `ordinance` to the short name of the contained ordinance this section belongs to, recovered from the running header on the rendered page.
- For sections that govern specific grades or levels, set `grades` accordingly; set `null` otherwise.
- **Record multi-page table spans.** Where a table continues across a physical page break (signaled by an incomplete final row, a mid-table break, or a *Fortsetzung* cue), record the table's **actual span** — the number of physical pages it occupies — so the continuation-bounded neighbour read at use time is bounded by data, not a fixed count. Record the actual span per section, not an assumed maximum (the largest single-logical-table span observed so far is 2 physical pages — but do not hard-code it).
- Set `hazards` per Step (d); initialize to `[]`.

### Step (c) — Extract `document_title`

Extract the teacher-facing document title using two sources, then cross-check:

1. Read the PDF `/Title` metadata field.
2. Render the cover page and read the title as it appears visually on the rendered cover.

Cross-check: both sources must agree, or the cover page rendering wins. The metadata field is never trusted blind — regulation PDFs sometimes carry a stale or generic `/Title` that does not match the cover. If the two sources disagree, use the cover-rendered title and note the discrepancy.

The `document_title` is the document's main title as shown on the cover, in the form a teacher would say it. Where the cover carries a long formal headline **and** a shorter recurring short-title (e.g. in the running header on body pages), use the **short recurring form** — it is the citation-friendly name. It is a real string from the document, never invented and never derived from the filename.

### Step (d) — Set `hazards`: deterministic candidate scan, then visual adjudication

Hazard tagging is two stages: a **deterministic candidate scan** (mechanical — it catches every potential hazard page regardless of judgment), then a **visual adjudication** of each candidate (render the page and read it to confirm or drop the tag). **When adjudication is uncertain, keep the flag** — over-flagging costs only a wasted render; under-flagging ships a silent miss, which the contract forbids.

**Candidate scan (deterministic — mark the page a candidate if any signal fires):**

- **`pua-semantic` candidate** — any Unicode Private Use Area codepoint (U+E000–U+F8FF) on the page makes it a candidate. **Do not hard-code which codepoints are decorative:** the PUA codepoint→glyph mapping is **font-private**, so the same codepoint can be a list bullet in one document's symbol font and a meaning-bearing marker in another's. Instead, collect the **distinct PUA codepoints** in this document and the pages each appears on; the decorative-vs-semantic call is made per document in adjudication. (Note: **U+FFFE** and the soft hyphen **U+00AD** are *not* in the PUA range — they are word-wrap artifacts, never candidates.)
- **`text-layer-pollution` candidate** — the `P…C8T…#y` watermark/link-hotspot signature, or a similar hidden string that corrupts a text read, is present.
- **`diagram` candidate** — an embedded image or a substantial vector-graphic region not accounted for by the extracted text is present, **or** a figure-caption breadcrumb (`"Grafik N:"`, `"Abbildung"`, `"Abb."`) appears in the text.
- **`glyph-substitution` candidate** — a region that should carry a clause extracts to a suspiciously short or implausible span, or a symbol-font span maps to nonsense (e.g. a niveau-qualifier clause collapsing to two characters).

Because the scan is mechanical, it surfaces candidate pages **independent of any one read's narrative** — so a hazard a text-first pass might skip is still caught.

**Visual adjudication (render each candidate page and read it):**

- **`pua-semantic`** — classify each distinct PUA codepoint by **rendering it** (never by codepoint value — the mapping is font-private). The glyph *shape* is fixed by the font, but its *role* can vary by context: the same bullet-shaped glyph can be a decorative list marker on most pages and a meaning-bearing marker (e.g. one flagging a binding requirement) in a particular table. So **render a sample of the codepoint's occurrences spanning its distinct contexts** (different sections / tables), not a single instance. The decision is **asymmetric**: the codepoint is `pua-semantic` if it carries meaning in **any** sampled context — flag *those* contexts (one semantic occurrence is enough); it is dropped only if it is **consistently decorative across the sample** (a list bullet / dash everywhere). If its role varies, classify **per context**, flagging only the semantic ones. This keeps a bullet-heavy document cheap (adjudicate the few **distinct** codepoints, each by a small sample) without letting a single decorative instance mask a semantic one. **Uncertain → keep.**
- **`diagram`** — keep the tag if the region is a **meaning-bearing** diagram, process flow, competency model, or relational matrix whose structure is not recoverable from the text layer. A logo, a decorative rule, or a plain bordered data table that extracts in correct reading order may be dropped. **Uncertain → keep.** This tag covers both prose-orphan and prose-redundant diagrams — flagged identically, because the reader cannot safely distinguish them at read time (a prose-redundant diagram yields text that looks complete but omits vision-only structure).
- **`text-layer-pollution`** / **`glyph-substitution`** — confirm the corruption is present on the rendered page; these rarely have a benign explanation, so confirmation is usually immediate.

The page-map records the **adjudicated** tags. A section that survives adjudication with an empty `hazards` array is one where cheap text is expected to pass the quality gates.

**Mandatory escalation.** Any set `hazards` tag is a mandatory visual-escalation trigger at read time — the reader renders the physical page regardless of how complete the cheap text looks. This is load-bearing: the Q4 blind-escalation finding showed a prose-redundant diagram yields plausible-looking text that a reader will not self-escalate on without the flag. The trigger cannot rest on read-time judgment; it must be the flag.

**Backstop for a generator false-negative.** Even on an unflagged page, a figure-caption breadcrumb (`"Grafik N:"`, `"Abbildung"`) or an image/vector region the extracted text does not account for trips the diagram gate at read time. The page-map's flag is the primary trigger; the read-time backstop is the secondary guard.

**Page-identity is not a hazard tag.** Composite-document identity, restarting numbering, duplicate printed numbers, and unnumbered pages are class-A page-identity issues. They are resolved by `page_table` and `section_anchor`, never by escalating to vision. They do not appear in `hazards`.

---

## Single-page-render gate

Render **one page at a time** via the cheapest single-page renderer the runtime can provision. Selection order:

1. If the runtime already provides a page renderer that supports single-page output by page number, use it with its single-page selector — preferred (fast, no install).
2. If none is present, provision one: a self-contained, install-on-demand single-page renderer that bundles its own rendering engine needs no system-level dependency. Install it in the current environment and use it for single-page output.
3. Whole-document render is the **last resort** — use it only if neither of the above is available. The cost difference is significant (a whole-document render of a 77-page document can cost approximately as much as a large session's entire budget; a single-page render costs a fraction of that). If whole-document render is used, flag this in the generation log.

**Write renders to the connected workspace path (data root), never to `/tmp`.** In Cowork and other connected runtimes, files written to `/tmp` cannot be read back — they are outside the connected folders. All intermediate renders must be written to a path under `<WORKSPACE_ROOT>/` (the data root) so the generator can read them back. Clean up intermediate render files after generation completes.

---

## Self-validation

The generator runs these six checks on its own output before committing the sidecar. A failed check **flags for review and does not emit a gate-failing result** — it escalates to re-examine the relevant pages, or surfaces the failure as a noted residual. It never silently emits a sidecar that fails a gate.

### 1. Monotonicity

`printed_page` values in `page_table` (excluding `null` rows) are strictly increasing — **except** where `model ∈ {"restarting", "duplicate"}` legitimately produces a non-monotonic sequence. Any break outside those models is a flag: the generator re-examines the affected pages, determines whether it misread a footer, and either corrects the entry or records the anomaly with a `note` on the affected rows and escalates for owner review.

### 2. TOC cross-check

Where the PDF contains a source table of contents, compare the TOC's stated section-start pages against the body-derived `printed_page_start` values in `sections[]`. Where the two disagree, the generator:

- Sets `"toc_unreliable"` in `page_identity.flags`.
- Uses the body-derived ranges as the authoritative `sections[]` values — the body wins.
- Does not use a disagreeing TOC entry as a `section_anchor` — the body-read heading is used instead.

### 3. Range sanity

For every `sections[]` entry:
- `physical_page_start` and `physical_page_end` are within `[1, physical_page_count]`.
- `physical_page_start ≤ physical_page_end`.
- The physical range is consistent with `page_table`: the physical pages in the range must appear in `page_table`, and the `printed_page` values at those physical pages must match `printed_page_start` and `printed_page_end`.

### 4. Coverage

Every physical page from 1 to `physical_page_count` appears **exactly once** in `page_table`. No gaps; no duplicates at the physical level. (Duplicate `printed_page` values are legitimate under `model: "duplicate"`, but the physical pages that carry them are distinct.)

### 5. Stamp

`source_pdf_sha256` in the emitted sidecar matches the SHA-256 of the bundled PDF file at the time of generation. This is the join key the downstream reader's cache gates reuse on, and the value the regulation lint uses to detect staleness; an incorrect stamp makes the sidecar untrustworthy as a version identity.

### 6. No clipped section end

No section's declared end **clips** text that spills onto the following page before the next heading. For every section `S` whose immediate successor in reading order starts on page `end + 1`: extract that page and locate the successor's heading; if a material amount of body text (running header/footer stripped) **precedes** that heading, `S`'s text spills onto `end + 1` and its end must be `end + 1`, not `end`. The check **proposes** the correction with the preceding-text quote as evidence; a boundary is corrected only after confirming the preceding text is `S`'s and not one of the recurring false positives: a running header, a figure caption, or — most common — the successor being a **parent/container** section whose own front matter (e.g. a cover sheet) legitimately precedes its heading and is already reachable via that successor's page range.

Because a corrected range changes the section's extracted source text, correcting a clip **must** bump `index_version` so every digest cached against the clipped range is invalidated (see "Regeneration trigger" and the digest-cache coupling).

---

## Regeneration trigger

Regeneration is **owner-invoked** and runs on a single PDF at a time — it is never a per-task runtime cost.

**Trigger conditions:**
- The regulation issuer republishes a regulation PDF under the same filename: the `source_pdf_sha256` of the bundled file no longer matches the value in the existing sidecar. The staleness lint flags this. The owner runs this skill on that one PDF.
- A new federal state's regulations are added to the bundle: run this skill on each new PDF.
- The generator's schema or logic changes (`index_version` bump): the owner may choose to regenerate all sidecars to bring them to the current `index_version`.

**On regeneration, re-verify every corpus-proven constant against the new PDF version:**
- The page-identity model and offset — confirm the new version uses the same offset, or update if the republish changed pagination.
- Each section's page range — confirm headings and their page ranges survived the republish intact, or update.
- Each multi-page table's actual span — re-confirm the continuation bound is still accurate.
- The Bearbeitungszeit invariant (where applicable) — re-confirm the `eA ≥ gA` constraint holds across all two-value Bearbeitungszeit pages in the new version.

Drift surfaces at regeneration rather than shipping silently: a republish that shifts a section's page range or changes a table's structure is caught here and corrected before the updated sidecar is committed.
