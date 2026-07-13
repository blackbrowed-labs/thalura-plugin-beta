# Document Metadata

Every generated deliverable document (`.docx`, `.pptx`) carries plugin-defined OOXML metadata, set on the **output** document at write time. This replaces the authoring library's defaults a document would otherwise inherit — an empty or library-named Author, a library `Application` fingerprint, a sandbox `lastModifiedBy`. The metadata is set on the **output** — never inherited from the template that supplied the chrome.

**Execution — the Output-Gate Runner.** These gates are executed via the Output-Gate Runner in `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md` (Step 5) — after every write or in-place revision, before the document is presented, each applicable gate runs its verify-then-escalate-or-flag loop with a concrete read-back and its outcome is reported. See hitl-lifecycle Step 5 for the inlined checklist, the gate-outcome reporting requirement, and the presentation barrier.

**Evidence — machine read-back, gate-defined.** The metadata and link contracts on this page are satisfied by **machine read-back of the written artifact**, not by a narrated claim about how it was made. The shipped Output-Gate Verifier (`${CLAUDE_PLUGIN_ROOT}/scripts/verify_output.py`) is the **reference mechanism** producing that evidence in one command — a machine-parsable evidence block per gate plus the concrete read-back values it observed (the actual `dc:creator`, `cp:lastModifiedBy`, `dc:title`, `Application` from `docProps`, the emitted hyperlink relationship targets, the PDF `/Author`/`/Producer`, …) — recorded in the document's manifest `gates` record (shape in `${CLAUDE_PLUGIN_ROOT}/references/schemas/unit-manifest.md` and `${CLAUDE_PLUGIN_ROOT}/references/schemas/school-year-plan.md`). **Any equivalent evidence-producing method conforms** — the platform's own document-inspection capabilities, or a direct unzip + read of the `docProps` parts — chosen at runtime, never a hard-coded library. **Swap trigger:** if the platform later ships a native equivalent covering these checks, that method becomes the preferred mechanism. The permanent contract is the **evidence**, not the tool.

---

## The Metadata Gate

After a document is written (or revised in place), its OOXML metadata MUST satisfy every row below. This is a **gate on the output**, independent of the capability used to author the file.

| OOXML part | Field | Required value | Source |
|---|---|---|---|
| `docProps/core.xml` | `dc:creator` (Author) | The teacher's full name | `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json` → `name` |
| `docProps/core.xml` | `cp:lastModifiedBy` | The teacher's full name (same as Author) | `<WORKSPACE_ROOT>/data/profiles/teacher-profile.json` → `name` |
| `docProps/core.xml` | `dc:title` | The document's own title | The resolved (localized) document or material title |
| `docProps/core.xml` | `dcterms:created` | Real generation time (W3CDTF / ISO-8601) | Current time at first write |
| `docProps/core.xml` | `dcterms:modified` | Real last-write time | Current time at each write or in-place revision |
| `docProps/app.xml` | `Application` | The literal string `Thalura` | Constant — a deliberate product attribution |
| `docProps/app.xml` | `Company` | The school name, or empty | `<WORKSPACE_ROOT>/data/profiles/school-config.json` → `school_name`; empty when unavailable |
| `docProps/custom.xml` | *(custom document properties)* | None that identify the authoring library or tool | — |

### Notes

- **`Application` must be `Thalura` — the product.** It MUST NOT carry an authoring library name (`python-docx`, `python-pptx`, `PptxGenJS`, a round-tripped `Microsoft Office …`, or any other how-it-was-made fingerprint). A neutral or empty `Application` is not used; the value is `Thalura`. This is a deliberate product attribution, not a scrubbed or blank field.

- `dc:title` and `dc:subject` may be absent from a source template. When required by this gate they are added to the output.

- `dc:subject` and `cp:keywords` are optional and not set by default.

---

## In-Place Revision

On an in-place edit (the shared revision path), apply the gate as follows:

- **Refresh:** `cp:lastModifiedBy` (teacher name) and `dcterms:modified` (real current time).
- **Preserve:** `dc:creator` and `dcterms:created` from the original write.
- **Re-assert:** `Application = Thalura`. An in-place edit capability may rewrite `app.xml`; the gate value must be confirmed or restored.

---

## Verify, Then Escalate or Flag

After writing (or revising), verify the output satisfies every row above — for example by reading `docProps/core.xml` and `docProps/app.xml` from the written file (a `.docx` / `.pptx` is a zip; those parts are plain XML).

- **If the authoring capability set the metadata correctly** → done.
- **If a field is wrong or the capability could not set it** (some capabilities do not expose every property), escalate to another method — for example, editing the OOXML parts directly (e.g. via `core_properties` in python-docx / python-pptx, or a direct OOXML edit of `docProps/core.xml` and `docProps/app.xml` — chosen at runtime, never a bundled script) — and re-verify.
- **If no available method can satisfy a gate row,** flag the residual to the teacher (which field is wrong, and that the file may show an incorrect author or a library name in File → Properties) rather than shipping a fingerprinted or wrong-author document.

---

## Why

- The Author a teacher (or a colleague they share with) sees in **File → Properties** should be the teacher, not a library or an empty field.
- `Application = Thalura` is the intended product attribution. It must not leak the authoring library — that is a how-it-was-made fingerprint.
- The plain export (colleague-facing) deliberately leaves this metadata intact — it is set once, at generation, and preserved by every subsequent path.

---

## Validated-material PDF

When a validated in-scope material (Unterrichtsmaterial) receives an automatic PDF — see `skills/core/hitl-lifecycle.md` Step 8 for the trigger — the generated PDF is a print/share-ready deliverable that must satisfy both a **generation gate** and a **PDF metadata gate**.

### Generation gate

A print/share-ready PDF exists alongside each validated in-scope material (same folder as the source `.docx`/`.pptx`). It is regenerated whenever the material is re-validated so it never goes stale. The PDF is registered in the unit manifest (`plan.json`) as `pdf_path` and is included in the unit's exports (Exporte) and backups (Sicherungen).

**The PDF is an additive deliverable — its absence never blocks validation.** Validation completes regardless; if a PDF cannot be produced, the residual is flagged to the teacher (see escalation path below).

**Mechanism-of-record, gate-defined:** converting a validated `.docx`/`.pptx` to PDF uses whatever conversion capability the environment exposes. LibreOffice headless (`soffice --headless --convert-to pdf`) is *a current* mechanism-of-record — named here as an illustration, **not** as the sole path or an eternal contract. The runtime picks the best available method; another conversion capability may be chosen when available or when `soffice` is not.

**Verify-then-escalate-or-flag loop:**

1. **Convert** the validated source to PDF alongside it, via the available conversion capability.
2. **Verify** the PDF exists, is non-empty, opens, and reflects the source content.
3. **If the capability is unavailable or a verify step fails**, escalate to another method (a different conversion tool or approach, chosen at runtime).
4. **If no method succeeds**, flag the residual to the teacher — the material is validated and usable, but no PDF could be produced — rather than silently shipping a missing PDF or blocking validation.

### PDF metadata gate (PDF-shaped)

The produced PDF's document information must carry the same author/application intent as the OOXML metadata gate above — expressed for PDF:

| PDF field | Required | Prohibited |
|---|---|---|
| `/Author` | The teacher's full name (same source as `dc:creator`) | An authoring-library name or empty |
| `/Title` | The document's own title | — |
| `/Producer` | No authoring-library fingerprint carried from the source; the conversion engine's own identity is permitted (e.g. a `LibreOffice…`/`Writer` string from the converting engine) | A carried authoring-library string (e.g. `python-docx …`) |
| `/Creator` | No authoring-library fingerprint carried from the source; the conversion engine's own identity is permitted | A carried authoring-library string (e.g. `python-docx …`) |

Conversion tools typically carry the source `dc:creator` into the PDF's `/Author` and may also write their own converter identity into `/Producer` and `/Creator` (for example, a `LibreOffice…`/`Writer` string — the honest converter's own signature is **permitted**).
What remains **prohibited** is an authoring-library fingerprint carried over from the source document (for example, a `python-docx`-style string).
The gate is **verify-then-flag:** read back the PDF document information after conversion; an empty or library-named `/Author` is the **sole hard failure** — escalate to set those PDF fields directly (via whatever PDF metadata tool the environment exposes — chosen at runtime, never a bundled script) or flag the residual to the teacher; for `/Producer` and `/Creator`, flag any carried authoring-library fingerprint (not the converter's own identity).
A flagged residual is named precisely: which field is wrong and what the teacher may see in the document properties.

## Referenced-file hyperlinks

When a generated document **references another workspace file** — a material, a lesson document, a task paper (Aufgabe), a grading rubric (Erwartungshorizont) — that reference is rendered as a **clickable relative-path hyperlink to the file on disk**, so the reader clicks straight to the file instead of hunting through folders. This makes the material overview (Materialübersicht) a navigable index and lets the unit plan (Einheitenplanung) and lesson plans (Verlaufsplan) jump to their materials and lessons.

### The emission gate

Applied **per referenced file**:

> Compute the target's path **relative to the linking document's own folder**. **IF** the file exists on disk at that relative path → emit a clickable relative-path hyperlink to it (the editable file; **and**, when a validated PDF sibling exists, a second hyperlink to the PDF). **ELSE** → emit plain text. **Never** a broken link, and **never** an absolute `file://` path.

### Relative, never absolute

The link target is the path **from the linking document's own folder to the target file** — never an absolute `file://` path or a drive-letter path. Both the linking document and the target are recorded in `plan.json` as **unit-folder-relative** paths, so the target is a pure re-basing: `relative-target = relpath(target-path, dirname(linking-doc-path))`.

| Linking document | Target | Emitted relative link |
|---|---|---|
| Materialübersicht / unit plan (unit-folder root) | a material in `Materialien/` | `Materialien/… .docx` |
| Materialübersicht / unit plan (root) | a lesson in `Stunden/` | `Stunden/… .docx` |
| a lesson plan in `Stunden/` | a material in `Materialien/` | `../Materialien/… .docx` |
| an assessment in `Lernkontrollen/` | its sibling Aufgabe / Erwartungshorizont | `Aufgabe.docx` (no `../`) |
| an assessment in `Lernkontrollen/` | a cited material in `Materialien/` | `../Materialien/… .docx` |
| an assessment in `Lernkontrollen/01-slug/` | a cited material in `Materialien/` | `../../Materialien/… .docx` |
| Year overview (workspace root) | a unit's unit plan (Einheitenplanung) in its unit folder | `{Subject}/{school_year}/{class_id}/{Unit_slug}/… .docx` |

Relative links survive a workspace move/rename and ride through exports and backups (`.thaluraunit` unit export, plain-export ZIP, whole-workspace backup) intact, because the relative folder structure is preserved in every bundle — where absolute `file://` links would break the moment the folder moved.

### Path source

Every material, lesson, and assessment entry in `plan.json` already carries a unit-folder-relative `path`, and a validated in-scope material additionally carries a `pdf_path` (its validated PDF sibling — see *Validated-material PDF* above). The hyperlink target is computed from those recorded relative paths; no absolute path ever enters.

The recorded base may also be a **workspace-root-relative folder** rather than a unit-folder-relative document path: the year overview (Schuljahresübersicht) at the workspace root links each unit row to that unit's unit plan (Einheitenplanung) from the school-year `plan.json`'s `units[].output_path` — a workspace-root-relative folder, resolved literally and locale-invariantly. Because `output_path` records the folder, not the file, the target **filename is reconstructed** — the localized unit-plan filename via `naming-conventions.json` `documents.unit_plan` + `localization.json`, preferring the validated file and falling back to the `_{draft_suffix}` file — and **each candidate is exists-checked before emission** (the same verify-exists-then-emit loop; both candidates missing → plain text). For a root-placed linking document the re-basing degenerates to the recorded workspace-root-relative path itself.

### Which documents

Gate-defined by *"does this document point at other files?"*, not a fixed allow-list. The documents that do, today:

- **Materialübersicht** — every created-material row links to its editable file (+ PDF when validated). The overview becomes a click-through table of contents.
- **Unit plan (Einheitenplanung)** — the Lesson Overview's material references (M-numbers) and lesson references become hyperlinks.
- **Lesson plans (Verlaufsplan / Stundenentwurf)** — the lesson's materials-to-create references become hyperlinks.
- **Assessments (Klausur / Lernkontrolle)** — the Erwartungshorizont ↔ Aufgabe cross-reference and any cited source material become hyperlinks.
- **Year overview (Schuljahresübersicht)** — every unit row links to that unit's unit plan (Einheitenplanung), the validated file when it exists else the `_{draft_suffix}` file, each exists-checked before emission.

A document that references no other file (a standalone worksheet, a reading text) has nothing to link — no change.

### Link targets and affordance

- **Both editable and PDF.** Link the **editable file** whenever it exists; when a validated **PDF** sibling exists (`pdf_path`), link it **too**.
- **Render:** the referenced title/name stays **plain text**; trailing link affordances follow — the **editable-format label** (`[DOCX]` for documents, `[PPTX]` for slide decks, chosen automatically from the material kind: worksheets, handouts, reading texts, plans, rubrics → `[DOCX]`; slide decks / student task decks → `[PPTX]`) is the hyperlink to the editable file, and `[PDF]` — the hyperlink to the validated PDF — appears **only when a `pdf_path` exists**. The acronyms are file-format extensions, not domain terms, and need no localization. Example rows:
  > • M01 – Worksheet: Metaphors (Entwurf)  `[DOCX]`
  > • M02 – Reading-Text  `[DOCX]` `[PDF]`
- The **link mechanism and affordance semantics** (which references link, both targets, plain title + trailing affordance) are settled and stable; the **fine visual styling** (glyphs, colour, an applied character style, spacing) is a presentation detail that **converges with the template redesign** and is not fixed here. This behaviour is **not blocked on that redesign**.

### Draft vs planned

Link **only files that exist on disk** — which **includes** `_{draft_suffix}` (`_ENTWURF`) drafts (real files; a draft links its editable file only, since no PDF exists until validation) and **excludes** planned-but-not-yet-created rows (no file → plain text, no affordance).

### Verify-then-degrade loop

1. **Resolve** the target file's path relative to the linking document's own folder (re-basing the recorded unit-folder-relative paths).
2. **Verify** the file exists on disk at that relative path.
3. **If it exists** → emit the relative-path hyperlink (the editable file; + the PDF when `pdf_path` is present and the PDF exists).
4. **If it does not exist** → emit plain text (a planned material, or a file removed/renamed out-of-band). Never a broken or absolute link.

No broken link is ever written. Regeneration heals: the Materialübersicht regenerates on every material-set change (see *Validated-material PDF* and the draft-aware overview), and the unit/lesson plans regenerate when the unit changes, so links track the current on-disk state. A relative link dangled by an out-of-band Finder rename produces the editor's own benign "cannot open" notice — no crash, no data loss — and self-heals on the next regeneration of that document.

### Mechanism-of-record, gate-defined

Emitting a clickable relative-path hyperlink uses whatever hyperlink capability the environment's document generation exposes. The DOCX/OOXML relationship-based hyperlink (and the Markdown `[text](relative/path)` form on any Markdown surface) is *a current* mechanism-of-record — named here as an illustration, **not** the sole path or an eternal contract. The runtime picks the best available method; the permanent contract is *"a clickable relative-path hyperlink in the generated document,"* under the verify-exists-then-degrade gate above. No single library is hard-coded.

## Regulation-citation links

When a generated document or a chat reply **cites an official regulation** — a curriculum framework (Bildungsplan), an abitur guideline (Abiturrichtlinie), an operator list (Operatorenliste), or any regulation behind the firewall — that citation is rendered as a **clickable link to the official published source**, opened at (or near) the cited page, so the teacher checks the quote and reads its context in one click. Where no resolvable link exists, the citation stays exactly as it is today (plain text). This is a **sibling gate** to *Referenced-file hyperlinks* above — the same verify-resolvable-then-degrade philosophy — but a **different target**: an *online* source URL, not a workspace-relative path. A workspace-relative path structurally cannot reach a regulation source (it lives under `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/…`, a different root, and is host-unreachable in a sandboxed runtime), so this gate is decoupled from the referenced-file gate, not an extension of it.

The regulation citation carries these fields from the regulation firewall's digest: a human-facing `document_title` + `printed_page` (the citation prose the teacher reads), and — internal-only — `source_pdf_sha256` and `physical_page`. The **citation text is unchanged**; the link is layered onto it.

### The emission gate

Applied **per regulation citation**, at the point the citation is rendered:

> **Resolve** the digest citation's `source_pdf_sha256` against the resolved state's source companion `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/document-sources.json` (keyed on `source_pdf_sha256`). **IF** an entry with a non-empty `canonical_url` exists for that key:
> &nbsp;&nbsp;• **IF** the cited `physical_page` is present **and** the page anchor is reliable → emit the citation as a hyperlink to **`<canonical_url>#page=<physical_page>`** (finest granularity).
> &nbsp;&nbsp;• **ELSE** → emit the citation as a hyperlink to the **bare `<canonical_url>`** (whole-document).
> **ELSE** (no entry, or `canonical_url` is `null`/empty) → emit the **plain-text citation** exactly as today.
> **Never** a broken link, **never** an absolute `file://`/drive-letter path, **never** a host-unreachable plugin-side path. **Never fabricate a `#page` anchor** — if `physical_page` is absent or unreliable, fall back to the whole-document link, not a guessed page (never `#page=null`, never `#page=`).

The presence-of-URL check is the "verify" step; absence degrades to plain text — the citation is never lost, only un-linked.

### Resolve on `source_pdf_sha256` (not `document_id`)

The join key is the citation's `source_pdf_sha256`, **not** its `document_id`. The regulations tree carries the **same `document_id` stem under more than one school-type subtree** (the same document title exists as distinct editions for different school types), and those copies are **distinct documents with distinct source URLs and distinct `source_pdf_sha256`s**. `document_id` alone therefore **collides** and would serve the wrong URL. The digest citation carries **both** `document_id` and `source_pdf_sha256`, so `source_pdf_sha256` is the **globally-unique join key** — and it doubles as a **freshness guard**: a republished, rehashed bundled PDF makes a stale URL entry detectable (the sha no longer matches), mirroring the page-map's own sha pin.

### Best-effort page anchor

`#page=<physical_page>` uses the digest's `physical_page` **verbatim** — the firewall already resolved printed→physical via the page-map, so the gate **does not recompute or invent it**. `physical_page` is used **only** to build the `#page` fragment; it never surfaces as visible text.

The anchor is **best-effort**. The bundled PDF is sha-pinned; the document served at `canonical_url` is whatever the authority currently publishes and **can drift** (re-pagination, a new edition). When the hosted edition's pagination matches the bundled one (the common case), the `#page` anchor lands correctly; where an `edition`/`url_note` flag marks a mismatch, the gate **degrades to the whole-document link**. The URL never claims byte-fidelity to the bundled PDF — it points the teacher at the *authoritative published source* for context.

### Which surfaces

The gate is defined **once** and applied at **every** point a regulation citation is rendered:

- **Generated documents (firm):** the unit plan's Curriculum Anchoring (Bildungsplan-Verankerung) block, the compliance audit (The Sacred Texts), the assessment grading rubric (Erwartungshorizont), and lesson plans (Verlaufsplan) — each regulation citation becomes a real hyperlink where the gate resolves a URL.
- **Chat (best-effort / "if possible"):** an inline Markdown link on the citation. An online URL renders and clicks in chat, which is exactly why an online target (not a local path) is what makes a clickable chat citation viable at all.

The teacher-visible citation prose is identical across surfaces; only the link affordance is layered on.

### A pointer, not content (firewall unaffected)

Building the link needs **no firewall read of its own** and does not weaken the firewall's sole-gateway invariant. The citation key already legitimately lives in the main session — it rides the firewall digest — and the URL is additional *pointer metadata* joined at emit-time from a plain JSON companion, **not** from a regulation PDF. The URL is **not** carried in the firewall digest; the main session joins it from the digest's already-returned `source_pdf_sha256` + `physical_page`. Reading `document-sources.json` is ordinary metadata file-reading (like reading a page-map sidecar), explicitly **not** a firewall content read: no regulation content enters the main context.

### Verify-resolvable-then-degrade loop

1. **Resolve** the citation's `source_pdf_sha256` against the resolved state's `document-sources.json`.
2. **Verify** a matching entry exists with a non-empty `canonical_url` that is a well-formed online URL (never `file://`, never absolute/drive-letter).
3. **If it resolves** → emit the hyperlink: `<canonical_url>#page=<physical_page>` when the page anchor is reliable, else the bare `<canonical_url>`.
4. **If it does not resolve** (no entry, `null`/empty URL, or an ill-formed/absolute URL) → emit the plain-text citation. Never a broken, absolute, or host-unreachable link; never a hazard.

### Mechanism-of-record, gate-defined

Emitting a clickable link to the cited source uses whatever hyperlink capability the surface exposes. The DOCX/OOXML relationship-based hyperlink (in a generated document) and the Markdown `[text](url)` form (in chat) are *a current* mechanism-of-record — named here as an illustration, **not** the sole path or an eternal contract. The runtime picks the best available method; the permanent contract is *"a clickable link to the cited source, verify-resolvable-then-degrade,"* under the gate above. No single library is hard-coded.

### State-agnostic

The emission gate and the `document-sources.json` **shape** are universal — the reusable prose carries no issuer, authority, or school-type names. Every **URL / edition** is **state data** in the per-state `regulations/<state>/document-sources.json` companion. Adding a state ships its own companion file; the mechanism is untouched. The companion-file shape is documented in `${CLAUDE_PLUGIN_ROOT}/references/schemas/document-sources.md`.
