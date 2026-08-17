# Regulation PDF Naming Convention

Naming rules for all regulation PDFs in `regulations/`. These are official Hamburg BSB documents bundled with the plugin — the naming convention makes them machine-resolvable while preserving human readability.

**Scope:** This convention covers `regulations/` only. Separate from unit output naming and document structure specs.

---

## Directory Structure

```
regulations/
  {federal_state}/
    shared/               ← Documents used by ALL school types
      cross-subject/      ← Cross-subject framework docs
      {subject}/          ← Subject-specific docs (Sek II + shared Sek I)
    {school_type}/        ← School-type-specific Sek I documents
      cross-subject/      ← Sek I cross-subject docs (school-type-specific)
      {subject}/          ← Sek I subject Bildungspläne + exam-specific docs
```

### Path Components

| Component | Format | Example | Source |
|---|---|---|---|
| `{federal_state}` | Lowercase German | `hamburg/` | Slugified from `education-system.json` ID `"Hamburg"` |
| `shared` | Fixed English | `shared/` | Convention |
| `{school_type}` | Lowercase German | `gymnasium/`, `stadtteilschule/` | Slugified from `education-system.json` ID |
| `cross-subject` | Fixed English | `cross-subject/` | Convention |
| `{subject}` | Lowercase English subject ID | `english/` | From `subjects.json` ID |

### Hamburg (v1.0)

```
regulations/
  hamburg/
    shared/
      cross-subject/
        allgemeiner-teil.pdf
        praeambel.pdf
        apo-grundstgy.pdf
        sek2-teil-c.pdf
        apo-ah.pdf
        abiturrichtlinie.pdf
        operatoren-gesellschaftswissenschaften.pdf
        sic-leitfaden.pdf
        a-heft-2026.pdf
        a-heft-2027.pdf
      english/
        bildungsplan-sek2-english.pdf
        abiturrichtlinie-english.pdf
        abiturrichtlinie-english-praesentation.pdf
      philosophy/
        bildungsplan-sek2-philosophy.pdf
        abiturrichtlinie-philosophy.pdf
        abiturrichtlinie-philosophy-praesentation.pdf
        operatoren-beispiel-philosophie.pdf
      psychology/
        bildungsplan-sek1-psychology.pdf
        bildungsplan-sek2-psychology.pdf
        abiturrichtlinie-psychology.pdf
        abiturrichtlinie-psychology-praesentation.pdf
        operatoren-beispiel-psychologie.pdf
      religion/
        bildungsplan-sek1-religion-erlaeuterungen.pdf
        bildungsplan-sek2-religion.pdf
        abiturrichtlinie-religion.pdf
        abiturrichtlinie-religion-praesentation.pdf
    gymnasium/
      cross-subject/
        sek1-teil-c.pdf
        rahmenvorgaben-sprachbildung.pdf
        sek1-aufgabengebiete.pdf
      english/
        bildungsplan-sek1-english.pdf
      philosophy/
        bildungsplan-sek1-philosophy.pdf
      religion/
        bildungsplan-sek1-religion.pdf
    stadtteilschule/
      cross-subject/
        sek1-teil-c.pdf
        rahmenvorgaben-sprachbildung.pdf
        sek1-aufgabengebiete.pdf
      english/
        bildungsplan-sek1-english.pdf
      philosophy/
        bildungsplan-sek1-philosophy.pdf
        musteraufgaben-esa-philosophy.pdf
        musteraufgaben-msa-philosophy.pdf
      religion/
        bildungsplan-sek1-religion.pdf
        musteraufgaben-esa-religion.pdf
        musteraufgaben-msa-religion.pdf
```

---

## Filename Convention

```
{document_type}[-{qualifier}].pdf
```

- **Kebab-case, lowercase** — no spaces, no special characters
- **Document type names** use German terms for official BSB document types (Bildungsplan, Abiturrichtlinie, Operatoren). These are proper nouns of specific BSB-issued documents.
- **Subject names** in filenames use the **English subject ID** (`english`, `philosophy`, `religion`)
- **No publication year** in filenames — only one version per document is active at a time. When the BSB publishes an update, the old file is replaced.
- **Exception: A-Hefte** use the **Abitur year** (the cohort year, not publication year): `a-heft-{abitur_year}.pdf`. Multiple A-Hefte coexist for different cohorts.

---

## Shared Documents

Documents in `shared/` that apply to both Gymnasium and Stadtteilschule.

### Cross-Subject — Always loaded (Layer 1)

| Document | Filename | Official title |
|---|---|---|
| Allgemeiner Teil | `allgemeiner-teil.pdf` | Bildungsplan Allgemeiner Teil |
| Präambel | `praeambel.pdf` | Bildungsplan Präambel |

### Cross-Subject — Level-specific (Layer 2)

| Document | Filename | Loaded for |
|---|---|---|
| APO-GrundStGy | `apo-grundstgy.pdf` | Sek I only |
| Sek II Teil C | `sek2-teil-c.pdf` | Sek II only |
| APO-AH | `apo-ah.pdf` | Sek II only |
| Abiturrichtlinie (allgemein) | `abiturrichtlinie.pdf` | Sek II only |

### Cross-Subject — Operators (Layer 4)

| Document | Filename | Applies to |
|---|---|---|
| Operatoren gesellschaftswiss. Fächer | `operatoren-gesellschaftswissenschaften.pdf` | Philosophy, Psychology, Religion |

**Note:** English operators are integrated in `abiturrichtlinie-english.pdf` — no separate file. Subject-specific operator example files (`operatoren-beispiel-philosophie.pdf`, `operatoren-beispiel-psychologie.pdf`) are in their respective subject directories under `shared/`.

### Cross-Subject — A-Hefte (Layer 5, conditional)

| Document | Filename | Applies to |
|---|---|---|
| A-Heft for Abitur 2026 | `a-heft-2026.pdf` | Abitur cohort 2026 |
| A-Heft for Abitur 2027 | `a-heft-2027.pdf` | Abitur cohort 2027 |

A-Hefte are cross-subject — one PDF per Abitur year covers all subjects. The document-registry maps subject-specific chapters within the A-Heft.

### Cross-Subject — Reference

| Document | Filename | Notes |
|---|---|---|
| SiC-Leitfaden | `sic-leitfaden.pdf` | Implementation guide for school-internal curricula |

### Subject-Specific (Shared)

Documents in `shared/{subject}/` — Sek II documents and Sek I documents confirmed identical across school types.

| Document type | Filename pattern | Example |
|---|---|---|
| Bildungsplan Sek I (shared) | `bildungsplan-sek1-{subject}.pdf` | `bildungsplan-sek1-psychology.pdf` |
| Bildungsplan Sek II | `bildungsplan-sek2-{subject}.pdf` | `bildungsplan-sek2-english.pdf` |
| Abiturrichtlinie | `abiturrichtlinie-{subject}.pdf` | `abiturrichtlinie-english.pdf` |
| Abiturrichtlinie Präsentation | `abiturrichtlinie-{subject}-praesentation.pdf` | `abiturrichtlinie-english-praesentation.pdf` |
| Erläuterungen (shared) | `bildungsplan-sek1-{subject}-erlaeuterungen.pdf` | `bildungsplan-sek1-religion-erlaeuterungen.pdf` |
| Operatoren Beispiel | `operatoren-beispiel-{subject_de}.pdf` | `operatoren-beispiel-psychologie.pdf` |

**Psychology Sek I** is in `shared/` (blob 798408, identical for both school types).
**Religion Erläuterungen** is in `shared/` (blob 123146, identical on both BSB Gymnasium and Stadtteilschule pages).

---

## School-Type-Specific Documents

Documents in `{school_type}/` directories — Sek I documents that differ between school types.

### Cross-Subject (Sek I)

These three documents have **separate versions** per school type:

| Document | Gymnasium | Stadtteilschule |
|---|---|---|
| Teil C Leistungsbewertung | `gymnasium/cross-subject/sek1-teil-c.pdf` | `stadtteilschule/cross-subject/sek1-teil-c.pdf` |
| Rahmenvorgaben Sprachbildung | `gymnasium/cross-subject/rahmenvorgaben-sprachbildung.pdf` | `stadtteilschule/cross-subject/rahmenvorgaben-sprachbildung.pdf` |
| Aufgabengebiete | `gymnasium/cross-subject/sek1-aufgabengebiete.pdf` | `stadtteilschule/cross-subject/sek1-aufgabengebiete.pdf` |

Same filenames in both directories — the document-registry routes by school type.

### Subject Sek I Bildungspläne

| Document type | Filename pattern | Example |
|---|---|---|
| Bildungsplan Sek I | `bildungsplan-sek1-{subject}.pdf` | `bildungsplan-sek1-english.pdf` |

**Per-School-Type Inventory:**

**Gymnasium** (3 Sek I subject files): `english/bildungsplan-sek1-english.pdf`, `philosophy/bildungsplan-sek1-philosophy.pdf`, `religion/bildungsplan-sek1-religion.pdf`

**Stadtteilschule** (3 Sek I subject files): `english/bildungsplan-sek1-english.pdf`, `philosophy/bildungsplan-sek1-philosophy.pdf`, `religion/bildungsplan-sek1-religion.pdf`

**Note:** Psychology Sek I is in `shared/` (identical for both school types). English, Philosophy, and Religion have separate Sek I Bildungspläne per school type.

### ESA/MSA Musteraufgaben (Stadtteilschule only)

| Document type | Filename pattern | Example |
|---|---|---|
| ESA Musteraufgaben | `musteraufgaben-esa-{subject}.pdf` | `musteraufgaben-esa-philosophy.pdf` |
| MSA Musteraufgaben | `musteraufgaben-msa-{subject}.pdf` | `musteraufgaben-msa-philosophy.pdf` |

**Available:** Philosophy (ESA + MSA), Religion (ESA + MSA). Stored in `stadtteilschule/{subject}/`.

---

## A-Heft Year Convention

The A-Heft filename uses the **Abitur year** it applies to — the cohort year, **not** the BSB publication year.

| Filename | Applies to |
|---|---|
| `a-heft-2026.pdf` | Abitur 2026 |
| `a-heft-2027.pdf` | Abitur 2027 |

Lookup is a direct mapping:

```
abitur_year = computed via temporal logic (references/temporal-logic.md)
filename = a-heft-{abitur_year}.pdf
```

No `publication_year` indirection needed.

### No Schwerpunktthemen Files

Schwerpunktthemen are chapters within A-Hefte, not separate files. There is no `schwerpunktthemen-*.pdf`. The document-registry maps each subject to its chapter within the A-Heft.

---

## SiC (Schulinternes Curriculum)

Schulinternes Curriculum files are **school-level** documents, not plugin-bundled. Each school defines its own SiC for a given subject and level — all teachers at that school follow the same one. SiC files are referenced by the document-registry at runtime. See Layer 6 in `document-registry.md` for the lookup convention.

---

## Page-Map Convention

Each bundled regulation PDF has an associated **page-map sidecar** stored at `<stem>.pagemap.json` next to `<stem>.pdf` under `regulations/`. The sidecar does two jobs and nothing else:

1. **`printed ↔ physical` page map** — so a reader opens the correct physical PDF page for a given printed page (and cites the printed page a teacher verifies against), absorbing the page-identity offsets that differ across regulation PDFs.
2. **Heading → page-range index** — so routing targets a narrow page range (a chapter, a section), never a whole document.

The page-map is **never cited**. A teacher never sees it; citation authority comes from the gate-passing read of the PDF itself. Its prose-fidelity ceiling is harmless: a slightly-wrong heading label costs a marginally wider read, never a wrong citation.

The page-map also carries **escalation hints** (`hazards` per section) telling a reader, before it opens a page, which sections are likely to require a visual escalation. See `schemas/page-map.md` for the full field-name contract.

### Canonical field names

| Field | Role |
|---|---|
| `document_id` | Machine join ID — the filename stem (e.g. `abiturrichtlinie-english`). Never shown to the teacher. |
| `document_title` | Teacher-facing name, sourced and verified from the PDF cover or metadata — never derived from the filename (e.g. `"Abiturrichtlinie Englisch"`). |
| `source_pdf_sha256` | Version stamp. Ties the page-map to a specific PDF version so a same-filename republish is detectable. |
| `index_version` | Bumped when the generator's schema or logic changes. |
| `page_table` | Explicit per-physical-page `printed_page` mapping — the source of truth for offsets. `offset` in `page_identity` is a convenience that holds only for the `simple` model. |
| `sections[]` | Heading → page-range index. Each entry carries a `section_anchor`, `printed_page_start/end`, `physical_page_start/end`, and a `hazards` list. |
| `section_anchor` | Verbatim heading string. Joins the citation key, the registry `Read scope` pointer, and the page-map on exactly the same string. |
| `hazards` | Escalation-hint vocabulary: `diagram`, `pua-semantic`, `glyph-substitution`, `text-layer-pollution`. An empty list means cheap text is expected to pass the quality gates; any set tag is a mandatory visual-escalation trigger. |

The join key that ties a citation to a page-map is **`(source_pdf_sha256, index_version)`**, with `document_id` retained for human readability and registry lookup.

### A-Heft chapter page-ranges

A-Hefte (137–140 pages) exceed the practical per-request read ceiling and cannot be read whole. The chapter → page-range mapping that routes reading to the relevant subject chapter lives in the page-map sidecar of the loaded edition — not in split per-chapter files. The `document-registry.md` Layer 5 rows name the chapter anchor; the sidecar of the loaded edition (`a-heft-{abitur_year}.pagemap.json`) supplies the exact printed page range, because chapter boundaries shift between editions.

The subject-to-chapter mapping (static, cross-edition):

| Subject | Chapter |
|---|---|
| English | Chapter 2 |
| Philosophy | Chapter 17 |
| Psychology | Chapter 18 |
| Religion | Chapter 19 |

The chapter heading anchors and per-edition printed page ranges are authoritative in the page-map sidecars; the table above names only the chapter numbers for orientation.

---

## Citation Key

A regulation citation identifies its source with three required components plus a version pin:

```
document_id + section_anchor + printed_page + source_pdf_sha256
```

- **`document_id`** — the filename stem defined by this naming convention (e.g. `apo-grundstgy`). The machine half of the join key; never shown to the teacher.
- **`section_anchor`** — the verbatim heading or section string from the page-map (e.g. `§5.2 Präsentationsprüfung`, `VO-BF §3`). Disambiguates page identity for composite PDFs (multiple ordinances under continuous numbering), restarting-numbered documents, and duplicate printed page numbers. A page number alone is insufficient in these cases.
- **`printed_page`** — the page number a teacher sees in the document footer and verifies against. Always comes from the page-map's `page_table`, never from footer-digit scraping (which is unsafe: publication-year digits and footnote text appear in footer fields and produce wrong results).
- **`source_pdf_sha256`** — the SHA-256 of the bundled PDF the citation was read from. Makes a same-filename BSB republish detectable: a citation whose hash no longer matches the bundled PDF is flagged stale, not served silently.

For composite PDFs (`apo-grundstgy.pdf` = APO-GrundStGy / VO-BF / AO-SF under continuous numbering), the displayed title is the contained ordinance's name, recovered from the running header via `section_anchor` — because one file holds several titled laws.

### Teacher-Facing Citation Format

**This section is the single definition of how a regulation citation is written for a teacher.** Every other surface that renders one — a generated document, a chat reply, a compliance check — follows the rules here and does not restate them. A surface that needs to show an example marks it as an instance of this rule, never as a definition of its own.

**Components.** The teacher-facing citation renders **`document_title` + `section_anchor` + the page** (e.g. *"Abiturrichtlinie Englisch, §5.2, S. 27"*). `document_id` and `physical_page` are internal join and audit fields, never shown.

**Language — the page abbreviation follows the surface, not a global setting.** The page is abbreviated **`S.`** when the surface's resolved language is German and **`p.` / `pp.`** when it is English. The governing language is that of the **surface the citation appears on**: a generated document follows the resolved content language for that document, a chat reply follows the conversation language. These are separate settings and may differ, so a citation inside an English worksheet reads `p. 27` even where the surrounding conversation is German. **No surface hard-codes an abbreviation.** This is a language convention, not a regional one — it holds wherever the plugin is used.

**A cited span uses an en dash.** Where a citation names a passage covering several pages, the range is written `S. 23–25` (German) or `pp. 23–25` (English), with an **en dash (`–`), never a hyphen**.

**A quotation running across a page break is cited with `f.` / `ff.`** The cited page is the page the quotation **begins** on. Where it continues past the end of that page, the citation says so in the customary abbreviated form rather than naming the first page alone — so the reader looks for the whole passage, not only its beginning. The digest supplies the continuation as the optional `printed_page_end` (`${CLAUDE_PLUGIN_ROOT}/references/schemas/digest-cache.md`):

| Form | Meaning | Rendered when |
|---|---|---|
| `S. 23` | page 23 alone | the quotation sits on one page — no `printed_page_end` |
| `S. 23 f.` | page 23 **and the page following** | the quotation ends on the immediately following page |
| `S. 23 ff.` | page 23 **and more than one following page** | the quotation ends more than one page later |

**Spaced, not closed:** `S. 23 f.`, never `S. 23f.` The house rule settles this; the bundled documents themselves use both spacings and so decide nothing.

**The two range forms are disjoint and never mix.** A **span** (`S. 23–25`) comes from a citation naming a multi-page section or module; a **continuation** (`S. 23 f.`) comes from a single quotation whose `printed_page_end` is set. Nothing is both, so no precedence rule is needed — and a span whose end page is known is always written out (`S. 23–25`), never as `S. 23 ff.`

**Page forms in internal reference prose are not examples of this citation.** Reference material written for the model's own use cites its sources in its own file's language and conventions; those forms are not teacher-facing output and must not be imitated when rendering a citation for a teacher. Follow the rules above, not the nearest example on the page.

---

## Gate-Defined Read Contract

Regulations are **read at use time against quality gates** — opened as PDFs at the specific physical page the page-map resolves, with the output verified before it is cited. A cheap read method is tried first; where a quality gate fails (or a section carries a genuine-visual `hazards` tag), the read **escalates** to a method that clears the gate. A gate failure is never shipped silently: it either escalates to another method or surfaces as a flagged residual on the citation.

The contract names gates and a verify-then-escalate-or-flag loop — **not a required tool**. The reader selects the best available method, verifies against the gates, and escalates when a gate fails.

Key quality gates (for reference — the normative definition is in the spec):

- **Coverage gate** — the read must yield substantially complete content for the page (a near-empty result from a page known to carry content fails and triggers escalation).
- **Verbatim-presence gate** — the emitted cited text must be locatable on the cited page.
- **Structure / invariant gate** — tabular claims pass a consistency check plus any domain invariant proven for that table type.
- **Diagram / hazard gate** — a section flagged `diagram`, `pua-semantic`, `glyph-substitution`, or `text-layer-pollution` in the page-map escalates unconditionally to a visual read of the rendered page, regardless of how complete the cheap text appears. This trigger is mandatory, not advisory.

**Where to find what:**
- **`schemas/page-map.md`** — full page-map sidecar schema (field names, page-identity models, `hazards` vocabulary, join key).
- **`document-registry.md`** — routing matrix: which documents to load per (subject, grade, school type) and the `Read scope` column (section anchor / printed page range / hazard tags) that narrows the read within each document.

---

## Extensibility

### Adding a new federal state

```
regulations/
  schleswig-holstein/
    shared/
      cross-subject/
        allgemeiner-teil.pdf    ← different content, same filename pattern
      english/
        bildungsplan-sek2-english.pdf
    gymnasium/
      cross-subject/
        sek1-teil-c.pdf
      english/
        bildungsplan-sek1-english.pdf
```

### Adding a new school type

```
regulations/
  hamburg/
    shared/                   ← existing shared docs still apply
    {new_school_type}/
      cross-subject/
        sek1-teil-c.pdf       ← school-type-specific version
      english/
        bildungsplan-sek1-english.pdf
```

### Adding a new subject

See `adding-a-subject.md` for the complete procedure. This file is the detailed spec for the **regulation-PDF** filename patterns (English subject IDs; `shared/{id}/` vs `{school_type}/{id}/` placement).
