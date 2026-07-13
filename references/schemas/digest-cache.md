# Session Digest Cache Schema (`<WORKSPACE_ROOT>/data/.cache/`)

## Purpose and internal-only status

The session digest cache stores the regulation firewall digest so that downstream tasks can reuse it without re-dispatching the full heavy read of regulation PDFs. It lives under `<WORKSPACE_ROOT>/data/.cache/` — in the teacher-workspace tier, never in the read-only plugin tier. `<WORKSPACE_ROOT>` is resolved canonically via the data-root resolver (`${CLAUDE_PLUGIN_ROOT}/scripts/resolve-data-root.sh`), so both the read-before-dispatch lookup and the post-miss write address this same directory rather than a guessed path.

**Granularity and layout (per-section, document-grouped).** A cache entry is **one resolved section** — keyed by `(document_id, source_pdf_sha256, section_anchor / printed-page-range)`, not by a whole read-scope bundle. Entries for one document are grouped under a per-document directory: `<WORKSPACE_ROOT>/data/.cache/<document_id>/<section-key>.json`, one file per resolved section. A read that resolves N sections therefore writes N entries (one per section), each independently retrievable and independently version-stamped — so a later read touching any one of those sections HITs that section's entry regardless of what else shared the original read. The `<document_id>` directory is a `mkdir -p` namespace; writes are atomic (temp + rename); a republished PDF is invalidated wholesale for one document by removing its directory (`rm -rf data/.cache/<document_id>/`). The canonical `document_id` and `section_anchor` that form the key are taken from the registry/page-map (the page-map's `sections[].section_anchor` is the single source of truth for a section's identity), never from the query topic.

The cache is **internal-only**: it is never a deliverable, never presented to the teacher, and never previewed. It is an implementation detail of the firewall pipeline, invisible to the teacher's working output.

Caching is sound because regulation documents are static within a version — the same PDF at the same version always yields the same digest. The cache therefore carries a **correctness obligation**: re-serving a digest built from a different or outdated version of the regulations is a silent compliance error. This obligation is discharged by the version-stamp gate described below.

---

## Entry shape

Each cache entry is a JSON object. The canonical field names and their types are defined in the field table below; the annotated example shows the full structure.

```json
{
  "key_components": {
    "federal_state": "…",
    "subject": "…", "level": "…", "school_type": "…",
    "abitur_year": 2028, "sic_fingerprint": "sha256:…",
    "read_scope_identity": "sha256:…"
  },
  "freshness": [
    { "document_id": "…", "source_pdf_sha256": "…", "index_version": 1 }
  ],
  "digest": {
    "claims": [
      {
        "content": "…",
        "citation": { "document_id": "…", "document_title": "…", "source_pdf_sha256": "…", "section_anchor": "…", "printed_page": 27, "physical_page": 29 },
        "cited_text": "…",
        "residual_flags": []
      }
    ],
    "page_map_fragment": { "page_table": [], "sections": [] },
    "section_pointers": [ { "document_id": "…", "section_anchor": "…", "printed_page_range": "27–28" } ],
    "hierarchy": { "order": ["curriculum-framework", "abitur-supplement", "school-internal-curriculum"], "note": "precedence preserved, not flattened" }
  }
}
```

### Canonical field names

| Field | Type | Description |
|---|---|---|
| `key_components` | `object` | The composite cache key — identifies which entry to select. See the Cache-key composition section. |
| `key_components.federal_state` | `string` | The federal state (Bundesland) — the top-level routing discriminator; different federal states load entirely different document sets. State-agnostic: a generic state identifier, never assume a specific state. |
| `key_components.subject` | `string` | Subject identifier (e.g. `"english"`, `"philosophy"`). |
| `key_components.level` | `string` | Grade level or semester identifier (e.g. `"S3"`, `"10"`). |
| `key_components.school_type` | `string` | School type — different school types load different document sets. State-agnostic: a generic identifier for the school type, never a state-specific institution name. |
| `key_components.abitur_year` | `integer` | The Abitur year (Abiturjahrgang) whose edition of the abitur supplement (Abiturrichtlinie) was loaded. Year-dependent editions make this a required discriminator. |
| `key_components.sic_fingerprint` | `string` | Hash over the sorted set of auto-detected school-internal-curriculum (Schulinternes Curriculum, SiC) PDFs. See the Cache-key composition section. |
| `key_components.read_scope_identity` | `string` | The canonical **per-section key**: a hash over the single `(document_id, source_pdf_sha256, section_anchor / printed-page-range)` triple of the resolved section this entry covers. One entry = one section, so the historical "set of triples" degenerates to a single element. **Never** the query topic or question intent — two different questions about the same resolved section yield the same `read_scope_identity` and share one entry. |
| `freshness` | `object[]` | One entry per regulation document included in the digest. The version-stamp gate reads this array to decide whether the entry is still valid. |
| `freshness[].document_id` | `string` | The filename stem of the regulation PDF (e.g. `"abiturrichtlinie-english"`). Matches the `document_id` in the page-map sidecar. |
| `freshness[].source_pdf_sha256` | `string` | SHA-256 of the bundled PDF at the time the digest was built. Must match the current bundled PDF for the entry to be trusted. |
| `freshness[].index_version` | `integer` | Page-map generator version at the time the digest was built. Must match the current page-map's `index_version` for the entry to be trusted. |
| `digest` | `object` | The regulation firewall digest itself — the result of the heavy read. |
| `digest.claims` | `object[]` | Extracted regulation claims, each with a full citation and the verbatim cited text. |
| `digest.claims[].content` | `string` | The claim derived from the regulation passage. |
| `digest.claims[].citation` | `object` | Full citation: `document_id`, `document_title`, `source_pdf_sha256`, `section_anchor`, `printed_page`, `physical_page`. Joins back to the page-map sidecar via `(source_pdf_sha256, index_version)`. |
| `digest.claims[].cited_text` | `string` | The verbatim regulation text the claim is derived from. |
| `digest.claims[].residual_flags` | `string[]` | Any quality-gate flags raised during extraction that were not fully resolved (e.g. an unverified diagram). Empty array means no residual flags. |
| `digest.page_map_fragment` | `object` | A subset of the page-map covering the sections the digest was built from. Shape mirrors the `page-map.md` schema: `{ "page_table": [], "sections": [] }`. Carried forward so downstream tasks can resolve printed → physical pages without re-reading the full page-map. |
| `digest.section_pointers` | `object[]` | Registry-style pointers to the sections the digest covers: `document_id`, `section_anchor`, `printed_page_range`. Carries **one pointer per distinct `section_anchor`** present in `claims[]` — every section the rendered range covers, not only the dispatched one — so a lookup can recognise a section is already covered by this entry (a coverage check) without re-parsing the claims. Lets downstream tasks identify the source range without re-parsing the digest claims. |
| `digest.hierarchy` | `object` | The document-precedence order that was active when the digest was built, preserved in the cache so it is not recomputed on reuse. `order` is an array of generic descriptors (e.g. `["curriculum-framework", "abitur-supplement", "school-internal-curriculum"]`); `note` records that precedence is preserved, not flattened. |

**Hierarchy precedence note (state-agnostic):** the framework document type outranks the abitur supplement for the upper-secondary level, which in turn outranks the school-internal curriculum. Generic descriptor names are used in `hierarchy.order` — no issuer or state name is encoded.

---

## Cache-key composition

The cache key selects *which* entry to retrieve. It is formed from seven components in `key_components`:

- **`federal_state`** — the primary routing discriminator. Different federal states (Bundesland) load entirely different document sets; a digest built for one state must never be served for another. This is the leading component and is always the first field in `key_components`.

- **`subject`** and **`level`** — base discriminators. Different subjects and levels load different document sets and are always distinct entries.

- **`school_type`** — different school types load different document sets for Sek I. Described generically; never a concrete institution name.

- **`abitur_year`** — the abitur supplement (Abiturrichtlinie) is published per cohort year; a digest built for one year must not be served for another.

- **`sic_fingerprint`** — a hash over the **sorted set of `(detection-relative path, sha256)` pairs** for every auto-detected school-internal-curriculum (Schulinternes Curriculum, SiC) PDF in the resolved document hierarchy.

  The fingerprint is sensitive along four dimensions:
  - **Content-sensitive** — an edited SiC PDF changes its `sha256`, changing the fingerprint.
  - **Presence-sensitive** — adding or removing a SiC PDF changes the set, changing the fingerprint.
  - **Hierarchy-position-sensitive** — the same-named file at a different location in the hierarchy is disambiguated by its detection-relative path; a swap of two identically-named files at different levels invalidates.
  - **Detection-root-relative, not absolute** — the path component is relative to the detection root, not the absolute filesystem path. Relocating a byte-identical workspace to a different directory must not spuriously invalidate a valid cache entry.

  When no SiC PDFs are present, the fingerprint is a stable sentinel value (not an empty-string hash) to make the absence case explicit and unambiguous.

- **`read_scope_identity`** — the canonical **per-section key**: a hash over the single `(document_id, source_pdf_sha256, section_anchor / printed-page-range)` triple of the **one resolved section** this entry covers. A cache entry is one section; the key identifies that section. A digest built for one section is a different entry from one built for another, and entries for the same document live side by side under `<WORKSPACE_ROOT>/data/.cache/<document_id>/`. **The query topic or question intent is never a component: two different questions answered from the same resolved section yield the same `read_scope_identity` and share one entry.** (Earlier revisions defined this as a hash over a *set* of triples for a whole read-scope bundle; the set now degenerates to a single section per entry.)

---

## Version-stamp read gate

The version stamp is layered **on top of** the key: the key selects an entry; the stamp decides whether that entry is still valid.

**Gate protocol:**

1. Select the entry whose `key_components` match the current request.
2. For every `freshness[]` element, compare `source_pdf_sha256` against the SHA-256 of the currently bundled PDF for that `document_id`, and compare `index_version` against the current page-map's `index_version`.
3. **Trust the entry only if every comparison passes** — all SHA-256 values match and all `index_version` values match.
4. On **any** mismatch → **cache miss** → re-dispatch the full firewall read → **overwrite the whole entry** with the newly built digest.

**Partial refresh is not permitted** (ruling 4): when any freshness check fails, the entire entry is discarded and rebuilt from scratch. A partial refresh risks a digest where some claims come from a current PDF version and others from a stale version — a silent compliance inconsistency.

**Failure classes this gate catches:**

- **Same-filename republish** — a regulation issuer publishes a corrected regulation under the same filename. The new PDF has a different `source_pdf_sha256`, which fails the SHA comparison and forces a re-extraction.
- **Regenerated page-map** — the page-map generator logic is updated (new hazard detector, schema field addition) and `index_version` is bumped. An old cache entry with a lower `index_version` fails the comparison and is rebuilt.

**SiC changes** are caught at the key level via `sic_fingerprint`, not by the version stamp. A changed SiC PDF set changes the fingerprint, which selects a different (or absent) cache entry, triggering a full re-extraction.

---

## Operator-cache entry

A dedicated **`{subject}_operators`** cache entry carries the action-verb table (Operatoren) for the subject. This entry has its own lifetime, independent of content-task digest entries.

The operator table is the highest-reuse, Private-Use-Area-glyph-sensitive (PUA-glyph-sensitive), highest-correctness-stakes fragment of the firewall output. PUA glyph sensitivity matters because operator-marking symbols in regulation PDFs often map to Private Use Area codepoints — a wrong glyph mapping produces a silently incorrect operator classification.

**Reference, not embed (ruling 3):** a content-task digest entry carries a **reference to the operator-cache entry by its key** rather than an embedded copy of the operator table. This enforces a single source of truth: two cache entries with divergent copies of the operator table are a correctness risk, because a rebuild that updates the operator entry but not the embedded copy would silently serve stale operator data from a content-task entry.

**Producer under per-document fan-out:** when a read fans out to one reader per document, the `{subject}_operators` entry is produced by whichever reader reads the operator document — its own reader where the operator table is a standalone document, or the shared reader where the operator table is a distinct section of a content document, which persists both the content-section entry and the `{subject}_operators` entry (one entry per resolved section).

**Location anchor vs. content (consumer rule):** the page-map operator `section_anchor` is a location/keying anchor, not a substitute for this entry — operator content is never resolved from the anchor alone. A consumer resolves a warm `{subject}_operators` entry by key (HIT, no read); on a MISS it triggers a section-scoped firewall read of the operator section (scoped via that anchor) that produces this entry as its digest. Where a content-document read already covers the operator section, this entry is produced as a byproduct of that read — no separate operator read occurs.

---

## Eviction policy

**Leave-and-gate — no active eviction in v1** (ruling 2).

Stale entries are never deleted proactively. They are invalidated on read via the version-stamp gate: a stale entry is never served — it triggers a re-extraction that overwrites it. The gate is the safety net; eviction is not the safety net.

Rationale: active eviction adds complexity (scheduling, startup cost, partial-eviction races) with no correctness benefit, because the gate already guarantees a stale entry is never served. Disk growth from accumulating superseded entries is expected to be negligible for the volume of regulation documents in scope.

**Future addition (built only if disk growth justifies it):** a wholesale cache-clear on plugin version bump. This is recorded as a planned extension, not implemented in v1. Triggering on plugin version bump (rather than on individual entry timestamps) avoids the complexity of per-entry expiry while catching the case where a major plugin upgrade changes the digest format.
