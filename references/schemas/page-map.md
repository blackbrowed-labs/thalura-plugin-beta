# Page-Map / Section-Index Schema (`<stem>.pagemap.json`)

## Purpose and non-authoritative status

A page-map sidecar does two jobs and nothing else:

1. **`printed ↔ physical` page map** — so a reader opens the correct physical PDF page for a given printed page number (and cites the printed page a teacher verifies against), absorbing the page-identity offsets found in regulation PDFs.
2. **Heading → page-range index** — so routing targets a narrow page range (a chapter, a section), never a whole document.

The page-map is **never cited**. A teacher never sees it; citation authority comes from the gate-passing read of the PDF itself, not from this index. Its prose-fidelity ceiling is therefore harmless: a slightly-wrong heading label costs a marginally wider read, never a wrong citation.

It also carries the **escalation hints** the read loop runs off: each `sections[]` entry's `hazards` list tells the reader, before it reads, which sections are likely to fail a quality gate and need a visual escalation.

One page-map sidecar per PDF, stored as `<stem>.pagemap.json` next to `<stem>.pdf` under `regulations/`.

---

## Per-document structure and canonical field names

```json
{
  "document_id": "abiturrichtlinie-english",
  "document_title": "Abiturrichtlinie Englisch",
  "source_pdf_sha256": "…",
  "index_version": 1,
  "physical_page_count": 64,
  "page_identity": {
    "offset": 0,
    "model": "simple",
    "flags": []
  },
  "page_table": [
    { "physical_page": 1,  "printed_page": null, "kind": "cover" },
    { "physical_page": 5,  "printed_page": 1,    "kind": "content" },
    { "physical_page": 29, "printed_page": 27,   "kind": "content", "note": "§5.2 — text-recoverable (no escalation hint)" }
  ],
  "sections": [
    {
      "section_anchor": "§5.2 Präsentationsprüfung",
      "printed_page_start": 27, "printed_page_end": 28,
      "physical_page_start": 29, "physical_page_end": 30,
      "ordinance": null,
      "grades": null,
      "hazards": []
    },
    {
      "section_anchor": "Grafik 1 — Überarbeitung der Fachcurricula",
      "printed_page_start": 10, "printed_page_end": 10,
      "physical_page_start": 12, "physical_page_end": 12,
      "ordinance": null, "grades": null,
      "hazards": ["diagram"]
    }
  ]
}
```

### Canonical field names

| Field | Type | Description |
|---|---|---|
| `document_id` | `string` | The PDF's filename stem (e.g. `abiturrichtlinie-english`). Machine join key to the registry and citation; **never shown to the teacher**. |
| `document_title` | `string` | Teacher-facing name, **sourced and verified from the PDF itself** (cover page / PDF `/Title` metadata, cross-checked against the rendered cover). Never derived from the filename. For composite PDFs this is the file-level title; the contained ordinance's title appears in `section_anchor` via `ordinance`. |
| `source_pdf_sha256` | `string` | SHA-256 of the bundled PDF at generation time. Version-pins the page-map to a specific PDF version; a same-filename republish by the regulation issuer changes this hash, making the stale state detectable. |
| `index_version` | `integer` | Bumped when the generator's schema or logic changes, independently of the PDF version. |
| `physical_page_count` | `integer` | Total number of physical pages in the PDF, 1-indexed. |
| `page_identity.offset` | `integer \| null` | Convenience: `printed = physical + offset` **where `model == "simple"`**. `null` for all other models. |
| `page_identity.model` | `string` | Page-identity model — see the model table below. |
| `page_identity.flags` | `string[]` | Document-level flags (e.g. `"duplicate_printed_numbers"`, `"toc_unreliable"`, `"restarting_numbering"`). |
| `page_table` | `object[]` | Explicit per-physical-page mapping. **This is the source of truth for printed↔physical resolution, not `offset`.** `offset` is a convenience that holds only when `model == "simple"`; a reader resolving printed→physical **always** consults `page_table`, falling back to `offset` only when `model == "simple"`. |
| `page_table[].physical_page` | `integer` | 1-indexed physical PDF page number. |
| `page_table[].printed_page` | `integer \| null` | Printed page number as it appears in the footer/header. `null` for unnumbered pages (covers, Impressum, TOC). |
| `page_table[].kind` | `string` | Page role: `"content"`, `"cover"`, `"impressum"`, `"toc"`, `"blank"`. |
| `page_table[].note` | `string` (optional) | Human-readable annotation, e.g. a section heading or a known irregularity. |
| `sections` | `object[]` | Heading → page-range index; the routing target. |
| `sections[].section_anchor` | `string` | The heading or section identifier, matching exactly what a citation key emits as its `section_anchor`. Joins the citation, the registry pointer, and the page-map on one string. |
| `sections[].printed_page_start` | `integer` | First printed page of this section. |
| `sections[].printed_page_end` | `integer` | Last printed page of this section. |
| `sections[].physical_page_start` | `integer` | First physical page of this section. Within `[1, physical_page_count]`; `≤ physical_page_end`. |
| `sections[].physical_page_end` | `integer` | Last physical page of this section. Within `[1, physical_page_count]`; consistent with `page_table`. |
| `sections[].ordinance` | `string \| null` | For composite PDFs (model `"composite"`): the contained ordinance this section belongs to (the short name of each contained law). `null` for non-composite documents. |
| `sections[].grades` | `string \| null` (optional) | Which grades or levels this section governs, where applicable. `null` otherwise. |
| `sections[].hazards` | `string[]` | Escalation-hint vocabulary — see the `hazards` section below. An empty array means cheap text is expected to pass the quality gates for this section. |

**Key rule — `page_table` is the source of truth, not `offset`:** `offset` holds only when `model == "simple"` and is `null` for all other models. A reader resolving a printed page to a physical page **always** consults `page_table` first. Relying on `offset` without checking the model leads to incorrect page resolution in composite, restarting, duplicate, and unnumbered documents.

---

## Page-identity model table

| Model | When to use | Encoding |
|---|---|---|
| `"simple"` | The printed-page footer increases by 1 per physical page at a fixed offset across the whole document — the common case. Unnumbered front-matter (cover, Impressum, TOC) typically precedes the numbered body, so the offset is usually negative; it can also be zero, or positive for an excerpt whose printed numbers start above its physical pages. | `model: "simple"`, `offset: N` (where `N` is the signed integer such that `printed = physical + offset`). A full `page_table` is still emitted for verification. For a "start-at-4" document (printed 1 = physical 4): `offset: -3`. |
| `"composite"` | The PDF contains multiple legally distinct ordinances under continuous page numbering (e.g. a single file bundling three ordinances under one continuous page sequence). A bare page number is ambiguous — it silently resolves to the wrong law without the section anchor. | `model: "composite"`, `offset: null`. Each `sections[]` entry carries `ordinance` naming the contained law. The reader uses the running header and `ordinance` to resolve document identity. |
| `"restarting"` | The PDF stitches two or more sub-documents with restarting page numbering (e.g. printed "4–14" followed by a restart to "1–12"). The `page_table` is legitimately non-monotonic. | `model: "restarting"`, `offset: null`, `flags: ["restarting_numbering"]`. The `page_table` carries the actual printed numbers, including non-monotonic sequences. |
| `"duplicate"` | Two physical pages share the same printed page number (e.g. physical pages 2 and 3 both print "2"). A page number alone does not uniquely identify a page. | `model: "duplicate"`, `offset: null`, `flags: ["duplicate_printed_numbers"]`. Two `page_table` rows share a `printed_page` value. Disambiguation is by `section_anchor` (the citation key), never by printed page number alone. |
| `"unnumbered"` | Pages that carry no printed page number (covers, Impressum, TOC). | `page_table` rows with `printed_page: null` and `kind` ∈ `{"cover", "impressum", "toc"}`. These pages do not receive `hazards` entries under `sections[]`. |
| Unreliable source TOC | The PDF's own table of contents is wrong (e.g. the TOC says §1 = printed page 7 but the body has it at printed page 6). | `flags: ["toc_unreliable"]`. The generator cross-checks the source TOC against the body-derived page ranges; where they disagree the **body wins** and the TOC heading is not used as a `section_anchor`. |

---

## `hazards` escalation-hint vocabulary

The `sections[].hazards` field contains zero or more of the following tags. **Any set tag is a mandatory visual-escalation trigger**: the reader renders the physical page and reads it visually, regardless of how complete the cheap text output looks. This mandatory trigger is load-bearing — a prose-redundant diagram yields plausible-looking text that a reader will not self-escalate on, so the trigger cannot rest on read-time judgment. An empty `hazards` list means cheap text is expected to pass the quality gates (the majority of sections).

| Tag | What it marks | Why visual escalation is required |
|---|---|---|
| `"diagram"` | A meaning-bearing diagram, process flow, or competency model whose relational structure (arrows, connections) is not recoverable from the text layer. Includes both prose-orphan diagrams (the text layer carries no restatement of the structure) and prose-redundant diagrams (where adjacent prose restates the flow). Both sub-cases are flagged identically because the reader cannot safely distinguish them at read time — a prose-redundant diagram yields text that looks complete but omits vision-only structural content. | The arrow directions, ring/sector structure, or box relationships are not in the text layer. Text alone produces an unverified answer the reader will not flag without a prompt from the page-map. |
| `"pua-semantic"` | A page containing a Unicode Private Use Area (PUA) codepoint (U+E000–U+F8FF) that carries meaning specific to a private symbol font (e.g. a required-resources / Hilfsmittel marker such as U+F0D1, or a pairing-arrow glyph such as U+F0F3, drawn from a regulation's private symbol font). | A good text reader keeps the codepoint but its glyph-to-meaning mapping is font-private. The codepoint alone is uninterpretable without a visual read to identify the glyph and its meaning. |
| `"glyph-substitution"` | A page where a text extraction library produces a glyph-substitution artifact — characters rendered in a symbol font are mapped to wrong Unicode codepoints (e.g. "→ gilt nur für das erhöhte Niveau" collapses to `'Dè'`). The substitution is silent: the output looks like text but is wrong. | The extracted text is incorrect and provides no signal of the substitution. A visual read of the rendered page is the only reliable path. |
| `"text-layer-pollution"` | A page whose text layer contains extraneous content that corrupts a text read — hidden watermark strings (e.g. `'P5 0C8T 0T #y'`), baked-in link-hotspot IDs, or other non-visible text that is worse than no text at all. | More text-extraction fidelity produces a worse result here. A page render is strictly cleaner than the polluted text layer. |

**Page-identity is not a hazard tag.** Class-A page-identity issues (wrong offset, composite document, restarting numbering, duplicate printed numbers) are resolved by `page_table` and `section_anchor`, never by escalating to vision. They do not appear in `hazards`.

---

## Join key and version pin

### Join key: `(source_pdf_sha256, index_version)`

The join key that ties a citation to its page-map sidecar — and to the read digest in the downstream reader — is the pair **`(source_pdf_sha256, index_version)`**:

- **`source_pdf_sha256`** identifies the exact PDF version. Regulation issuers republish corrected regulations under the same filename; a same-filename republish changes the SHA-256. A citation whose `source_pdf_sha256` no longer matches the bundled PDF's current hash is **flagged stale**, not served — this makes republishes detectable rather than silently wrong.
- **`index_version`** identifies the generator schema and logic version. When the generator's rules change (new hazard detector, schema field addition), `index_version` is bumped independently of the PDF version. A sidecar with an old `index_version` may be regenerated even when the PDF has not changed.

**`document_id`** (the filename stem) is retained alongside the join key for human readability and registry lookup, but it is not sufficient as a version identity on its own (it does not change on a republish).

### How citations join to the page-map

A citation key (from the reader) carries `document_id`, `source_pdf_sha256`, `section_anchor`, and `printed_page`. To resolve it against the page-map:

1. Locate the sidecar whose `document_id` matches and whose `source_pdf_sha256` matches the citation. A SHA mismatch means the citation was minted against a different PDF version — **flag stale**.
2. Look up `section_anchor` in `sections[]` to obtain the physical page range.
3. Look up `printed_page` in `page_table` to obtain the exact `physical_page` to open.
4. For composite documents (`model: "composite"`), confirm `sections[].ordinance` matches the ordinance in the running header of the cited page — a bare printed page number is insufficient to identify the correct law.
