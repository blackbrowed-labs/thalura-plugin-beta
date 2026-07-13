# Document Registry — Routing Matrix

This file maps (subject, grade, school_type) combinations to the relevant official Hamburg BSB regulation PDFs. The skill reads ONLY the documents listed here for the current query. Everything else is excluded.

All documents are stored under `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/` in a three-way directory structure, where `{federal_state}` is the slugified federal state from `<WORKSPACE_ROOT>/data/profiles/school-config.json` (currently always `hamburg`). **Every path in this file's tables is relative to `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/`** — the table cells omit that prefix for readability (Tier-1, read-only). The `{school_type}` and `{subject}` segments in the tables below are likewise resolved from teacher configuration:

```
regulations/hamburg/
  shared/           ← Documents used by BOTH Gymnasium and Stadtteilschule
  gymnasium/        ← Gymnasium Sek I ONLY
  stadtteilschule/  ← Stadtteilschule Sek I ONLY (+ ESA/MSA Musteraufgaben)
```

Filenames follow the convention in `regulation-naming.md`.

---

## Read scope and page-map sidecars (the DATA dimension)

The routing matrix answers two questions per query, not one: **which document** to read (the layered INCLUDE/EXCLUDE logic below) and **which page range or section** of it to read. The second answer is the **Read scope** column carried by every routing row.

**The `Read scope` column** holds one of:

- **`full`** — the whole document is small enough to read end-to-end (well under the ~100-page-per-request visual-read ceiling). Most regulations are `full`.
- **A section anchor + printed page range** — written `«anchor» — printed pp. X–Y`, where only a part of the document is relevant, or where a bare page number is ambiguous (a composite file, restarting numbering). The **anchor is verbatim** the heading string the page-map sidecar records for that section, so a citation, the registry pointer, and the page-map all join on the exact same string. **Page numbers are the printed numbers** a teacher sees in the footer — the sidecar resolves them to the physical PDF page to open.
- **A hazard tag in brackets** appended to a scope — `[diagram]`, `[pua-semantic]`, `[glyph-substitution]`, `[text-layer-pollution]` — flags that the named page is **not safely readable from cheap text** and needs a visual read of the rendered page. Routing surfaces the tag so the reader escalates rather than shipping an unverified text answer.

**Page-map pointer (uniform, derivable — no per-row column).** Every routed `<stem>.pdf` has a sibling page-map sidecar at `<stem>.pagemap.json` in the same directory. The sidecar carries the `printed ↔ physical` page table and the heading→page-range index, so a reader opens the correct physical page and cites the printed page a teacher verifies against. The pointer is therefore the document path with its extension swapped — no separate column is needed. **A section anchor in the `Read scope` column resolves through the matching sidecar's section index**; anchors are derived from the sidecars, never invented here. Where a document's relevant page range varies by edition (the A-Hefte), the registry names the chapter anchor and the **sidecar of the loaded edition supplies the page range** — see Layer 5.

**Two orthogonal dimensions, one layout.** The registry is redesigned once along two independent axes. **This DATA dimension** — the `Read scope` column (section anchor / printed page range), the hazard tags, and the page-map sidecar pointer — narrows the read *within* a document. A **separate routing dimension** — per-(subject × school-type × level) row-slicing and a read-once-per-session guard — narrows *which rows* are resolved and reads the resolved set a single time. The two are designed to coexist in the same tables: whichever lands second inherits this layout rather than re-inventing it. Until row-slicing lands, the full layered tables below resolve as before; the `Read scope` column is live now.

### Who consumes the resolved set — the firewall reader

The registry's job ends at **resolution**: it produces the INCLUDE list (the layered INCLUDE/EXCLUDE logic) and, per routed document, its `Read scope` (section anchor + printed page range, or `full`, plus any hazard tags). It does **not** itself open or read the PDFs.

The **firewall reader** (`${CLAUDE_PLUGIN_ROOT}/skills/read-regulations/SKILL.md`) consumes that already-resolved set. It performs the heavy read behind a context boundary — running the gate-defined verify-then-escalate-or-flag loop in an isolated sub-agent — and marshals back only a compact, citation-correct digest (citation key + verbatim receipt + per-claim flags); the raw PDF bytes and page images stay quarantined and never enter the main context. The firewall does **not** re-resolve routing: which documents to read and which rows apply is settled here by the Exclusion Rule and row-slicing, and is handed to the reader as a fixed input. The two responsibilities are disjoint — the registry decides *what* and *which range*; the firewall decides *how to read it safely* and returns the digest.

---

## Table of Contents

1. School Type Path Resolution
2. Grade-to-Level Resolution
3. Routing-Key Resolution (row-slicing — the LOAD-MECHANICS dimension)
4. Layer 1 — Always Loaded (Cross-Subject)
5. Layer 2 — Level-Specific (Cross-Subject)
6. Layer 3 — Subject-Specific Curriculum
7. Layer 4 — Operators
8. Layer 5 — A-Hefte / Schwerpunktthemen (Conditional)
9. Layer 6 — School-Internal Curriculum (Optional Enrichment)
10. Layer 7 — Methodologies
11. Routing Examples
12. Exclusion Rule

---

## School Type Path Resolution

The teacher's `school_type` (from `<WORKSPACE_ROOT>/data/profiles/school-config.json`) determines which directory provides each document:

| Document Category | Path Resolution |
|---|---|
| Shared cross-subject (Layer 1) | Always `shared/cross-subject/` |
| Sek I cross-subject (Layer 2) — Teil C, Sprachbildung, Aufgabengebiete | `{school_type}/cross-subject/` |
| Sek I cross-subject (Layer 2) — APO-GrundStGy | `shared/cross-subject/` |
| Sek II cross-subject (Layer 2) | Always `shared/cross-subject/` |
| Sek I subject Bildungspläne (Layer 3) | `{school_type}/{subject}/` — except Psychology: `shared/psychology/` |
| Sek II subject documents (Layer 3) | Always `shared/{subject}/` |
| Operators (Layer 4) | Always `shared/` |
| A-Hefte (Layer 5) | Always `shared/cross-subject/` |
| ESA/MSA Musteraufgaben | `stadtteilschule/{subject}/` (Stadtteilschule only) |

`{school_type}` is slugified from the `education-system.json` ID: `"Gymnasium"` → `gymnasium/`, `"Stadtteilschule"` → `stadtteilschule/`.

---

## Grade-to-Level Resolution

| Input Grade | School Type | Resolved Level | Key Implication |
|---|---|---|---|
| 5, 6, 7, 8, 9, 10 | Both | **Sekundarstufe I** | Sek I Bildungspläne, APO-GrundStGy |
| 11 | Stadtteilschule | **Sekundarstufe I** (Vorstufe) | Sek I framework |
| S1, S2, S3, S4 | Both | **Sekundarstufe II (Studienstufe)** | Sek II Bildungspläne, APO-AH, Abiturrichtlinien |

**Vorstufe:** Grade 11 at Stadtteilschule is structurally part of the Oberstufe (listed in `sek2_grades` in `education-system.json`) but regulatorily governed by the Sek I framework. The Stadtteilschule Sek I Bildungspläne cover grades 5–11 including Vorstufe. Grade 11 does NOT load Sek II documents (APO-AH, Abiturrichtlinien, A-Hefte).

---

## Routing-Key Resolution (row-slicing — the LOAD-MECHANICS dimension)

The matrix is resolved by **slicing to the rows the query selects**, not by reading the whole file and filtering afterward. A query's **routing key** is `(federal_state, subject, school_type, sek_level)` — every component is resolved from teacher configuration during startup before context is loaded, so slicing needs no new teacher input:

- `federal_state` — from `<WORKSPACE_ROOT>/data/profiles/school-config.json`; the **top-level discriminator**. Every path in this file resolves under `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/…`, so the resolver scopes the INCLUDE set to the resolved state's tree **first** — another state's rows never enter this slice. As more states are added, the saving compounds and the state boundary is the clean lift-out point for a future physical split.
- `subject` — the lowercase subject ID.
- `school_type` — slugified from the configured school type.
- `sek_level` — `sek1` / `sek2`, with the Vorstufe exception already applied (Grade 11 at Stadtteilschule resolves to `sek1`; see Grade-to-Level Resolution).

Scoped to the resolved `federal_state` tree, compose the INCLUDE set from: **Layer 1 (always)** ∪ **Layer 2 for the resolved `sek_level`** ∪ **Layer 3 for `(subject, sek_level)`** ∪ **Layer 4 for `subject`** ∪ the **conditional layers** per their existing gates (Layer 5 only for `sek2` + an A-Heft-triggering task; Layer 6 only when SiC files are present and the task is a planning task; Layer 7 methodologies per the task table). This is exactly the resolution the Routing Examples below encode by hand — slicing makes it structural: target the matching sections rather than read-whole-then-filter.

**The slice is keyed on the resolved values, not on any fixed corpus.** Load the rows whose `(federal_state, subject, school_type, sek_level)` match the routing key — whatever values the configuration supplies. The bundled corpus is an instance of this contract, never the contract itself; the same structure scales to additional states, subjects, and school types without change.

**Equivalence guarantee.** Slicing resolves the **identical** INCLUDE set — same documents, same paths, same `Read scope` cells — that resolving the whole matrix and filtering would. No routing target is added, dropped, or altered by slicing. The `Read scope` column (which page range or section to read within each document) rides along inside each sliced row, untouched.

### Read-once-per-session guard

The INCLUDE set is resolved **exactly once per session**, when context is first loaded for a routing key, and the resolved set — the document paths plus their `Read scope` cells — is held as session context and reused downstream. A task that needs the routed documents **consumes the already-resolved set**; it does not re-open this file. Resolve again only when the routing key itself changes mid-session (e.g. the teacher pivots to a different subject or level) — then a fresh resolve for the new key is correct. The guard keys on `(federal_state, subject, school_type, sek_level)`, never on "have I ever opened this file."

---

## Layer 1 — Always Loaded (Cross-Subject)

These documents are loaded for EVERY query regardless of subject, grade, or school type:

| Document | Path | Read scope |
|---|---|---|
| Bildungsplan Allgemeiner Teil | `shared/cross-subject/allgemeiner-teil.pdf` | full |
| Bildungsplan Präambel | `shared/cross-subject/praeambel.pdf` | full |

---

## Layer 2 — Level-Specific (Cross-Subject)

Load based on the resolved level (Sek I or Sek II):

### Sekundarstufe I (Grades 5–10; Grade 11 at Stadtteilschule)

| Document | Path | Read scope | Notes |
|---|---|---|---|
| Bildungsplan Sek I Teil C | `{school_type}/cross-subject/sek1-teil-c.pdf` | full | School-type-specific |
| Rahmenvorgaben Sprachbildung Sek I | `{school_type}/cross-subject/rahmenvorgaben-sprachbildung.pdf` | full | School-type-specific |
| Bildungsplan Sek I Aufgabengebiete | `{school_type}/cross-subject/sek1-aufgabengebiete.pdf` | full | School-type-specific |
| APO-GrundStGy | `shared/cross-subject/apo-grundstgy.pdf` | by ordinance section — see note | Shared (covers both school types) |

**APO-GrundStGy is a composite file** bundling three distinct ordinances under one continuous page sequence: the APO-GrundStGy itself (Inhaltsübersicht + Abschnitte 1–7 + Anlagen, printed pp. 5–50), the **`VO-BF — Verordnung über die besondere Förderung von Schülerinnen und Schülern (§ 45 HmbSG)`** (printed pp. 51–55), and the **AO-SF** (Inhaltsübersicht + Abschnitte 1–6, printed pp. 57–72). A bare page number is ambiguous here — cite by the contained ordinance's section anchor (the sidecar names the ordinance per section), not by page number alone. Read scope = the relevant ordinance's section range; e.g. the special-needs framework reads `VO-BF — Verordnung über die besondere Förderung von Schülerinnen und Schülern (§ 45 HmbSG)` — printed pp. 51–55.

### Sekundarstufe II (S1–S4)

| Document | Path | Read scope |
|---|---|---|
| Bildungsplan Sek II Teil C | `shared/cross-subject/sek2-teil-c.pdf` | full |
| APO-AH | `shared/cross-subject/apo-ah.pdf` | full; the score/conversion grids `Anlage 3 Tabelle zur Errechnung der Abiturdurchschnittsnote (N) aus der Punktzahl der Gesamtqualifikation (P)` (printed p. 43) and `Anlage 4 Berechnung der in Block 1 und in Block 2 (Abiturprüfung) erreichten Gesamtpunktzahl` (printed pp. 44–45) carry `[diagram]` — read those pages visually |
| Abiturrichtlinie (allgemein) | `shared/cross-subject/abiturrichtlinie.pdf` | full |

---

## Layer 3 — Subject-Specific Curriculum

Load based on (subject, level, school_type):

### English

| Level | Document | Path | Read scope |
|---|---|---|---|
| Sek I | Bildungsplan Sek I Englisch | `{school_type}/english/bildungsplan-sek1-english.pdf` | full |
| Sek II | Bildungsplan Sek II Englisch | `shared/english/bildungsplan-sek2-english.pdf` | full |
| Sek II | Abiturrichtlinie Englisch | `shared/english/abiturrichtlinie-english.pdf` | full; for the oral-presentation exam read `5.2 Präsentationsprüfung gemäß § 26 Absatz 3 APO-AH` — printed pp. 27–29 |
| Sek II | Abiturrichtlinie Englisch Präsentation | `shared/english/abiturrichtlinie-english-praesentation.pdf` | full |

### Philosophy

| Level | Document | Path | Read scope |
|---|---|---|---|
| Sek I | Bildungsplan Sek I Philosophie | `{school_type}/philosophy/bildungsplan-sek1-philosophy.pdf` | full |
| Sek I | Musteraufgaben ESA Philosophie | `stadtteilschule/philosophy/musteraufgaben-esa-philosophy.pdf` | full |
| Sek I | Musteraufgaben MSA Philosophie | `stadtteilschule/philosophy/musteraufgaben-msa-philosophy.pdf` | full |
| Sek II | Bildungsplan Sek II Philosophie | `shared/philosophy/bildungsplan-sek2-philosophy.pdf` | full |
| Sek II | Abiturrichtlinie Philosophie | `shared/philosophy/abiturrichtlinie-philosophy.pdf` | full |
| Sek II | Abiturrichtlinie Philosophie Präsentation | `shared/philosophy/abiturrichtlinie-philosophy-praesentation.pdf` | full |

### Psychology

| Level | Document | Path | Read scope |
|---|---|---|---|
| Sek I | Bildungsplan Sek I Psychologie | `shared/psychology/bildungsplan-sek1-psychology.pdf` | full — see numbering note |
| Sek II | Bildungsplan Studienstufe Psychologie | `shared/psychology/bildungsplan-sek2-psychology.pdf` | full |
| Sek II | Abiturrichtlinie Psychologie (Anlage 23) | `shared/psychology/abiturrichtlinie-psychology.pdf` | full |
| Sek II | Abiturrichtlinie Psychologie Präsentation | `shared/psychology/abiturrichtlinie-psychology-praesentation.pdf` | full |

**Note:** Psychology Sek I Bildungsplan (blob 798408) is identical for both school types — always loaded from `shared/`.

**Restarting numbering.** The Sek I Psychologie file stitches the curriculum body (printed pp. 4–14) and the module appendix (`M1`…`M9`, printed pp. 1–12) under **restarting** page numbering, so printed numbers are non-monotonic and a printed page must be resolved through the sidecar, never by adding a fixed offset. Several module pages carry `[pua-semantic]` — `M2 Grundaspekte des psychischen Systems (1. Lernjahr — Einführung in die Psychologie)` (printed p. 2) and the modules `M4`, `M6`, `M7`, `M8`, `M9` — where a private-font marker (e.g. a Hilfsmittel symbol) needs a visual read; read those pages visually.

### Religion

| Level | Document | Path | Read scope |
|---|---|---|---|
| Sek I | Bildungsplan Sek I Religion | `{school_type}/religion/bildungsplan-sek1-religion.pdf` | full |
| Sek I | Bildungsplan Sek I Religion Erläuterungen | `shared/religion/bildungsplan-sek1-religion-erlaeuterungen.pdf` | full |
| Sek I | Musteraufgaben ESA Religion | `stadtteilschule/religion/musteraufgaben-esa-religion.pdf` | full |
| Sek I | Musteraufgaben MSA Religion | `stadtteilschule/religion/musteraufgaben-msa-religion.pdf` | full |
| Sek II | Bildungsplan Sek II Religion | `shared/religion/bildungsplan-sek2-religion.pdf` | full |
| Sek II | Abiturrichtlinie Religion | `shared/religion/abiturrichtlinie-religion.pdf` | full |
| Sek II | Abiturrichtlinie Religion Präsentation | `shared/religion/abiturrichtlinie-religion-praesentation.pdf` | full |

**Note:** Religion Erläuterungen (blob 123146) is identical for both school types — always loaded from `shared/`.

---

## Layer 4 — Operators

Operators are loaded for ALL tasks that produce student-facing content — not only assessments.

| Subject | Source | Path | Read scope |
|---|---|---|---|
| **English** | Operators integrated in Abiturrichtlinie | `shared/english/abiturrichtlinie-english.pdf` (same as Layer 3) | full |
| **Philosophy** | Operatoren gesellschaftswiss. Fächer | `shared/cross-subject/operatoren-gesellschaftswissenschaften.pdf` | full |
| **Philosophy** | Operatoren Beispiel Philosophie | `shared/philosophy/operatoren-beispiel-philosophie.pdf` | full |
| **Psychology** | Operatoren gesellschaftswiss. Fächer | `shared/cross-subject/operatoren-gesellschaftswissenschaften.pdf` | full |
| **Psychology** | Operatoren Beispiel Psychologie | `shared/psychology/operatoren-beispiel-psychologie.pdf` | full |
| **Religion** | Operatoren gesellschaftswiss. Fächer | `shared/cross-subject/operatoren-gesellschaftswissenschaften.pdf` | full |

**English operators:** No separate operator file exists. Operators are part of the Abiturrichtlinie Englisch, which is loaded in Layer 3 for Sek II. For Sek I operator propedeutics, load `shared/english/abiturrichtlinie-english.pdf` if age-appropriate introduction of Studienstufe operators is needed.

**Propedeutic rule:** For Sek I, introduce Studienstufe operators where age-appropriate to build familiarity before the Studienstufe. Flag propedeutic operators in the teacher version (not in student materials).

---

## Layer 5 — A-Hefte / Schwerpunktthemen (Conditional, Sek II Only)

Load ONLY when these conditions are met:

| Condition | Document | Path | Read scope |
|---|---|---|---|
| Challenge Accepted + Abiturklausur | A-Heft for computed Abitur year | `shared/cross-subject/a-heft-{abitur_year}.pdf` | **never `full`** — read only the current subject's chapter range (see Subject-to-Chapter Mapping) |
| The Holocron for S3/S4 | A-Heft for computed Abitur year | `shared/cross-subject/a-heft-{abitur_year}.pdf` | **never `full`** — read only the current subject's chapter range (see Subject-to-Chapter Mapping) |

The Abitur year is computed via `${CLAUDE_PLUGIN_ROOT}/references/temporal-logic.md`.

**A-Heft filename uses the Abitur year directly** — no `publication_year` indirection. See `regulation-naming.md` for details.

**Currently available:**

| Filename | Applies to |
|---|---|
| `a-heft-2026.pdf` | Abitur 2026 |
| `a-heft-2027.pdf` | Abitur 2027 |
| `a-heft-2028.pdf` | Abitur 2028 |

**Fallback:** If the computed Abitur year's A-Heft is not available, use the most recent available file and warn:
> "Schwerpunktthemen für Abitur {abitur_year} nicht vorhanden. Verwende {available_file} — bitte prüfe auf Aktualität."

**Schwerpunktthemen are chapters within A-Hefte**, not separate files. Each A-Heft covers all subjects — Claude reads the relevant chapter for the current subject.

### Subject-to-Chapter Mapping (chapter → page range — MANDATORY)

A-Hefte are 137–140 printed pages — **over the ~100-page-per-request visual-read ceiling, so they CANNOT be read whole.** Reading the subject's chapter range is therefore **mandatory, not optional**: a Layer-5 read with no chapter range is invalid. The `Read scope` for a routed A-Heft is always the current subject's chapter, never `full`.

The chapter **anchor** is the verbatim section heading the A-Heft page-map sidecar records; the **page range is supplied by the sidecar of the loaded edition** (`a-heft-{abitur_year}.pagemap.json`) — it is **not** a single static number, because a chapter's printed page range shifts between editions (e.g. Englisch occupies printed pp. 9–12 in the 2026 edition and pp. 9–13 in the 2027/2028 editions). The registry pins the chapter number and verbatim anchor; the loaded edition's sidecar resolves the exact range and the printed↔physical offset. The chapter→page-range therefore lives in the page-map sidecar, **not** in split per-chapter files.

| Subject | Chapter | Verbatim chapter anchor (sidecar `section_anchor`) | Printed page range (per edition; sidecar is authoritative) |
|---|---|---|---|
| English | 2 | `2. Englisch` | 9–12 (Abitur 2026) · 9–13 (2027, 2028) |
| Philosophy | 17 | `17. Philosophie` `[pua-semantic]` | 71–74 (2026) · 72–75 (2027, 2028) |
| Psychology | 18 | `18. Psychologie (grundlegendes Anforderungsniveau)` | 75–77 (2026) · 76–78 (2027, 2028) |
| Religion | 19 | `19. Religion` | 78–81 (2026) · 79–83 (2027, 2028) |

**Hazard — Philosophie chapter.** Chapter 17 (`17. Philosophie`) carries `[pua-semantic]`: a page in the chapter holds a private-font Hilfsmittel / required-resources marker whose glyph-to-meaning mapping is font-private and not recoverable from cheap text. Read that chapter page visually so the resources line is not silently dropped.

Chapter **numbers** are stable across A-Heft editions (verified for 2026, 2027, and 2028) even though the **page ranges** are not. When a new A-Heft is added, verify both that the chapter numbering hasn't changed **and** that its sidecar supplies the per-chapter page ranges.

---

## Layer 6 — School-Internal Curriculum (Optional Enrichment)

| Condition | Behavior |
|---|---|
| SiC present for (subject) | SiC **enriches** the curriculum standards (Bildungsplan) with school-level topic sequencing and emphasis. Both are always used together. |
| No SiC | Curriculum standards (Bildungsplan) only (default) |

**SiC files** are school-level documents, not plugin-bundled. Each school defines its own school-internal curriculum (Schulinternes Curriculum) for a given subject — all teachers at that school follow the same one.

**File location:** `<WORKSPACE_ROOT>/data/regulations/sic/{subject}/` — using English subject IDs.

**Scan behavior:** Auto-detect by scanning the subject's SiC directory for all `*.pdf` files. Be tolerant of any filename — do not enforce naming conventions. SiC files are user-provided.

**Loading rule:** Auto-load when planning for a subject that has SiC files present. No manual parameter needed. The teacher can say "ignore the school-internal curriculum (Schulinternes Curriculum) for this unit" — the skill respects this without argument.

**Enrichment model:** The SiC enriches the curriculum standards (Bildungsplan) — it never contradicts or supersedes it. The regulatory hierarchy is:

1. **Curriculum standards (Bildungsplan)** — always authoritative (state-level competency framework)
2. **A-Heft / Schwerpunktthemen (Layer 5)** — binding for affected S3/S4 courses. **Always takes precedence over SiC** where conflicts exist.
3. **School-internal curriculum (Schulinternes Curriculum)** — school-level enrichment: adds topic sequencing, local emphasis, and school-specific priorities on top of the above.

**Conflict resolution:**
- If SiC conflicts with A-Heft Schwerpunktthemen (S3/S4): follow the A-Heft, flag the discrepancy to the teacher.
- If SiC suggests a topic for a different grade/semester than planned: flag the misalignment as advisory. The teacher decides.
- SiC never overrides competency standards (Bildungsplan) or assessment rules (APO/ARL).

**SiC-Leitfaden distinction:** `shared/cross-subject/sic-leitfaden.pdf` is a BSB meta-document about how to create school-internal curricula (Schulinterne Curricula). It is NOT a SiC itself and must NOT be loaded as Layer 6 content. **Read scope (when it is read as the meta-guide, not as Layer 6):** full; but the process diagram `Grafik 1: Die Überarbeitung der schulinternen Fachcurricula` (printed p. 10) carries `[diagram]` — its arrows and box relationships are not in the text layer, so read that page visually. A second process diagram `Grafik 2: Unterrichtsentwicklung in den Fachschaften durch die Arbeit an konkreten Unterrichtsvorhaben` (printed p. 41) carries `[diagram]` as well.

**SiC files (Layer 6 content) have no plugin-bundled page-map sidecar** — they are user-provided and scanned by filename. Read scope for a SiC PDF is `full` (no section anchors are pre-indexed).

---

## Layer 7 — Methodologies

Loaded selectively by task, subject, grade, and phase. See `${CLAUDE_PLUGIN_ROOT}/references/methods/` for the method index.

| Task | Loaded Files |
|---|---|
| The Holocron | Method index + 2–3 method files by subject + grade |
| The Upside Down | Relevant method files by lesson phase + subject + grade |
| Other tasks | Only when specifically needed |

Method files are plugin-internal reference content, not regulation PDFs — they carry no page-map sidecar and no `Read scope` field; they are read directly.

---

## Routing Examples

### Example 1: English, Klasse 5, Gymnasium
**INCLUDE:** Layer 1 (2 docs from `shared/cross-subject/`) + Layer 2/Sek I (3 docs from `gymnasium/cross-subject/` + 1 doc from `shared/cross-subject/`) + Layer 3/English/Sek I (1 doc from `gymnasium/english/`) + Layer 4/English (ARL from `shared/english/` for propedeutics if needed) + Layer 7 (method files)
**EXCLUDE:** All Philosophy, Psychology, Religion docs; all Sek II docs; all A-Hefte

### Example 2: Philosophy, S2 (eA), Gymnasium
**INCLUDE:** Layer 1 (2 docs from `shared/cross-subject/`) + Layer 2/Sek II (3 docs from `shared/cross-subject/`) + Layer 3/Phil/Sek II (3 docs from `shared/philosophy/`) + Layer 4/Phil (2 docs from `shared/`) + Layer 5 (if Abiturklausur or Holocron for S3/S4, from `shared/cross-subject/`) + Layer 7
**EXCLUDE:** All English, Psychology, Religion docs; all Sek I-specific docs

### Example 3: English, Klasse 8, Stadtteilschule
**INCLUDE:** Layer 1 (2 docs from `shared/cross-subject/`) + Layer 2/Sek I (3 docs from `stadtteilschule/cross-subject/` + 1 doc from `shared/cross-subject/`) + Layer 3/English/Sek I (1 doc from `stadtteilschule/english/`) + Layer 4/English (ARL from `shared/english/` for propedeutics if needed) + Layer 7
**EXCLUDE:** All Philosophy, Psychology, Religion docs; all Sek II docs; all Gymnasium Sek I docs

### Example 4: Philosophy, Klasse 11, Stadtteilschule (Vorstufe)
**INCLUDE:** Layer 1 (2 docs from `shared/cross-subject/`) + Layer 2/Sek I (3 docs from `stadtteilschule/cross-subject/` + 1 doc from `shared/cross-subject/`) + Layer 3/Phil/Sek I (1 doc from `stadtteilschule/philosophy/`) + Layer 4/Phil (2 docs from `shared/`) + Layer 7
**EXCLUDE:** All English, Psychology, Religion docs; all Sek II docs (APO-AH, Abiturrichtlinien, A-Hefte); all Gymnasium docs
**Note:** Grade 11 at Stadtteilschule uses Sek I framework — no Sek II documents loaded.

### Example 5: Psychology, Klasse 10, Stadtteilschule
**INCLUDE:** Layer 1 (2 docs from `shared/cross-subject/`) + Layer 2/Sek I (3 docs from `stadtteilschule/cross-subject/` + 1 doc from `shared/cross-subject/`) + Layer 3/Psy/Sek I (1 doc from `shared/psychology/`) + Layer 4/Psy (2 docs from `shared/`) + Layer 7
**EXCLUDE:** All English, Philosophy, Religion docs; all Sek II docs
**Note:** Psychology Sek I Bildungsplan always from `shared/` regardless of school type.

### Example 6: Religion, S2 (gA), Stadtteilschule
**INCLUDE:** Layer 1 (2 docs from `shared/cross-subject/`) + Layer 2/Sek II (3 docs from `shared/cross-subject/`) + Layer 3/Rel/Sek II (3 docs from `shared/religion/`) + Layer 4/Rel (1 doc from `shared/cross-subject/`) + Layer 5 (if applicable, from `shared/cross-subject/`) + Layer 7
**EXCLUDE:** All English, Philosophy, Psychology docs; all Sek I-specific docs
**Note:** Sek II routing is identical for both school types — all from `shared/`.

---

## Exclusion Rule (Token Efficiency)

For any query, the routing matrix explicitly defines what to INCLUDE. Everything not listed is EXCLUDED. This is not a suggestion — it is mandatory. Loading documents outside the routing matrix risks:
- Cross-contamination (applying wrong subject's standards)
- Token waste (loading irrelevant content)
- Hallucination (mixing up regulations from different contexts)

---

## Extensibility

To add a new subject:
1. Add PDFs to `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/shared/{subject}/` (Sek II + shared Sek I) and `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/{school_type}/{subject}/` (school-type-specific Sek I)
2. Add entries to this registry (Layers 3–5 as applicable)
3. Add subject to `${CLAUDE_PLUGIN_ROOT}/references/subjects.json`
4. Add localization entries to `${CLAUDE_PLUGIN_ROOT}/references/localization.json`
5. Add method files to `${CLAUDE_PLUGIN_ROOT}/references/methods/` (optional)

To add a new school type:
1. Create `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/{new_school_type}/` with cross-subject and subject directories
2. Add school-type-specific Sek I documents
3. Verify which existing `shared/` documents apply
4. Add routing entries to Layers 2–3 with `{school_type}` path resolution
5. Add school type to `education-system.json` and `plugin.json`
