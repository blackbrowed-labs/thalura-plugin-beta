# Document-Sources Companion Schema (`document-sources.json`)

## Purpose and state-agnostic status

The document-sources companion maps each bundled regulation PDF to its **official published source URL**, so a regulation citation can be rendered as a clickable link to the authoritative online source. The emission gate that consumes this file — resolve the digest citation's `source_pdf_sha256`, emit a hyperlink when a `canonical_url` exists, else plain text — is defined in `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` → *Regulation-citation links*. This schema documents only the **file shape**.

The **shape is state-agnostic** (a universal companion-file format, documented once here); the **data is state-specific** (each state's own source URLs). One companion file per federal state, stored as:

```
${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/document-sources.json
```

It is a sibling of the state's regulation tree — plain JSON metadata, **not** a regulation PDF. Reading it is ordinary metadata file-reading (like reading a page-map sidecar), not a firewall content read.

---

## Structure and canonical field names

The `sources` map is **keyed on `source_pdf_sha256`**, not on `document_id`. The same `document_id` stem can recur under more than one school-type subtree as **distinct documents with distinct source URLs and distinct `source_pdf_sha256`s**, so `document_id` alone collides and cannot key the map. `source_pdf_sha256` is the globally-unique per-document key and the join key from the firewall digest's `citation.source_pdf_sha256`.

```json
{
  "schema_version": 1,
  "sources": {
    "<64-hex-source_pdf_sha256>": {
      "document_id": "some-regulation-stem",
      "path": "school-type/subject/some-regulation-stem.pdf",
      "canonical_url": "https://…/example.pdf",
      "edition": "2022",
      "url_note": null
    },
    "<64-hex-source_pdf_sha256-of-a-doc-with-no-public-url>": {
      "document_id": "some-doc-not-online",
      "path": "shared/…/some-doc.pdf",
      "canonical_url": null,
      "edition": null,
      "url_note": "no stable public URL — link omitted (plain-text citation)"
    }
  }
}
```

### Canonical field names

| Field | Type | Description |
|---|---|---|
| `schema_version` | `integer` | Companion-file schema version (state-agnostic shape). Bumped when this shape changes. |
| `sources` | `object` | Map keyed on **`source_pdf_sha256`** — the globally-unique per-document key (the join key from the digest `citation.source_pdf_sha256`). Disambiguates same-stem documents that recur across school-type subtrees. |
| `sources[sha].document_id` | `string` | The PDF's filename stem (human-readable co-field; cross-checked against the digest's `citation.document_id` and the sibling page-map's `document_id`). **Not unique on its own** — do not key on it. |
| `sources[sha].path` | `string` | The document's path relative to the state root `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/` (human-readable provenance; makes the same-stem distinction legible in the data file). |
| `sources[sha].canonical_url` | `string \| null` | The official published URL for this document. **`null`** (or empty) ⇒ no resolvable link ⇒ the gate emits plain text. Must be an online URL; **never** a `file://`, absolute, or drive-letter path. |
| `sources[sha].edition` | `string \| null` | The edition/year of the hosted document, for the bundled-vs-hosted drift caveat below. Optional. |
| `sources[sha].url_note` | `string \| null` | Free-text note: fragment support, pagination-match confidence, or why the URL is `null`. Feeds the anchor-reliability fallback in the emission gate. Optional. |

---

## Drift caveat and the best-effort anchor

The bundled PDF is sha-pinned (its `source_pdf_sha256`, shared with the page-map sidecar). The document served at `canonical_url` is whatever the authority currently publishes and **can drift** — re-pagination, a new edition. The `#page` anchor the emission gate appends is therefore **best-effort**:

- **Correct** when the hosted edition's pagination matches the bundled one — the common case.
- **Degrades to the whole-document link** where `edition`/`url_note` flags a mismatch.

The URL never claims byte-fidelity to the bundled PDF; it points the teacher at the *authoritative published source* for context. Because a same-filename republish by the issuer changes the bundled PDF's `source_pdf_sha256`, a stale entry is **detectable** (the sha key no longer matches the sibling PDF), mirroring the page-map's own sha-version pin.

---

## Join to the citation and page-map

A firewall digest citation carries `document_id`, `document_title`, `source_pdf_sha256`, `section_anchor`, `printed_page`, and `physical_page` (see `${CLAUDE_PLUGIN_ROOT}/references/schemas/digest-cache.md`). To render its link:

1. Look up `source_pdf_sha256` in `sources`. A miss ⇒ plain-text citation (no link).
2. If the entry's `canonical_url` is non-empty and well-formed, emit the hyperlink; else plain text.
3. Append `#page=<physical_page>` **only** when the page anchor is reliable and `physical_page` is present — using the digest's `physical_page` verbatim. The digest resolved it **per claim**, as the page that claim's quotation begins on: a read that opens the document resolves it while reading, a pre-generated entry resolves it by locating the claim's `cited_text` in the source PDF's per-page text. It is never recomputed here. Otherwise emit the bare URL.

The `document_id` and `path` fields are for human readability and cross-checking only; the machine join is always on `source_pdf_sha256`.
