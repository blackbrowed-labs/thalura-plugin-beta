# Glossary — Educational Terminology (Hamburg)

Canonical reference for all domain terms used in Thalura skill files.

- **German term** (left column): as used in regulatory documents and teacher-facing output.
- **English** column: the canonical English equivalent used in skill file prose with the parenthetical pattern `"English term (German term)"`. A dash (`—`) indicates the term is used as-is (proper noun, abbreviation, or no canonical English equivalent).

Regulatory provenance for each term is in the [Regulatory Provenance](#regulatory-provenance) section at the end. Source paths are relative to `${CLAUDE_PLUGIN_ROOT}/regulations/hamburg/` and use the three-way directory structure: `shared/`, `gymnasium/`, `stadtteilschule/`.

---

## School Structure

| Term | English | Meaning | Notes |
|------|---------|---------|-------|
| **Gymnasium** | — | Academic secondary school (Grades 5–S4) | Hamburg has 8-year Gymnasium (G8) |
| **Stadtteilschule** | — | Comprehensive secondary school (Grades 5–S4) | 9-year track; includes Vorstufe (Grade 11) before Studienstufe; offers ESA (Grade 9) and MSA (Grade 10) exit qualifications |
| **Sekundarstufe I (Sek I)** | — | Lower secondary (Grades 5–10) | Comprises Beobachtungsstufe + Mittelstufe |
| **Beobachtungsstufe** | observation stage | Grades 5–6 (part of Sek I) | Hamburg-specific; commonly called "Unterstufe" |
| **Mittelstufe** | — | Grades 7–10 (part of Sek I) | — |
| **Sekundarstufe II (Sek II)** | — | Upper secondary | At Gymnasium: Studienstufe S1–S4 (Grades 11–12). At Stadtteilschule: Vorstufe (Grade 11) + Studienstufe S1–S4 (Grades 12–13) |
| **Oberstufe** | — | Upper secondary (umbrella term for Sek II) | At Gymnasium = Studienstufe; at Stadtteilschule = Vorstufe + Studienstufe |
| **Vorstufe** | preparatory year | Grade 11 before the Studienstufe | Stadtteilschule-specific; not part of Gymnasium |
| **Studienstufe** | — | Four semesters (S1–S4) spanning two school years before Abitur | Gymnasium: Grades 11–12; Stadtteilschule: Grades 12–13 |
| **Jahrgang / Klasse** | — | Grade level (= one school year) | "Klasse 5" = Grade 5. Grades use year numbering; S1–S4 are semesters (two per school year) |
| **Semester (Halbjahr)** | semester | Half-year term | S1–S4 are semesters, not school years; S1–S4 spans two school years |
| **Schuljahreswechsel** | school year transition | The roll-over from one school year to the next | A class continues into the next year (e.g. E9a → E10a); the transition is inferred from context, never a mode the teacher toggles |
| **Abiturjahrgang** | graduated cohort | A cohort that has completed its Abitur (after the final Sek II semester) | Excluded from auto-continuation — its courses are not advanced past the final semester (Hamburg Gymnasium: after S4) |

---

## Course Levels (Sek II)

| Term | English | Abbreviation | Meaning |
|------|---------|-------------|---------|
| **Anforderungsniveau** | course level | — | Course level category (gA or eA) |
| **grundlegendes Anforderungsniveau** | — | **gA** | Standard-level course |
| **erhöhtes Anforderungsniveau** | — | **eA** | Advanced-level course (profilgebend) |

---

## Lesson Planning

| Term | English | Meaning |
|------|---------|---------|
| **Unterrichtseinheit (UE)** | teaching unit | A series of lessons on one topic |
| **Stunde** | — | A lesson (45 min = Einzelstunde, 90 min = Doppelstunde) |
| **Einzelstunde** | single period | Single lesson period (45 min) |
| **Doppelstunde** | double period | Double lesson period (90 min) |
| **Stundenentwurf** | lesson plan | The complete lesson plan document (document type); contains the Verlaufsplan (phase table) and lesson metadata |
| **Verlaufsplan** | detailed lesson plan | Phase-by-phase lesson plan (the phase table within a Stundenentwurf) |
| **Grobplanung** | unit outline | Unit-level plan (overview of all lessons) |
| **Einstieg** | opening | Opening/warm-up phase |
| **Erarbeitung** | main phase | Main working/exploration phase |
| **Sicherung** | consolidation | Consolidation/wrap-up phase |
| **Vertiefung** | deepening | Extension/deepening phase |
| **Puffer** | — | Buffer activity (for when time remains) |
| **Stundenzahl** | — | Number of lessons |
| **Stundenstruktur** | — | Lesson structure (sequence of single/double periods) |
| **Didaktisches Konzept** | — | Didactic concept (the pedagogical "red thread" of a unit) |
| **Materialübersicht** | material overview | Auto-generated index document listing all materials in a unit |
| **Schuljahresübersicht** | year overview | Auto-generated overview document for the current school year, listing all classes and their teaching units (linked to each unit's planning) with competency coverage; stays current and updates itself whenever the year plan changes |
| **Standardmaterial** | standard supplies | Everyday classroom supplies (e.g. Post-its, tape, pens); the teacher can maintain an optional list of what they actually have, which gently biases lesson-planning proposals toward those items without ever restricting them |
| **Leitfrage** | guiding question | Overarching question guiding the unit's inquiry |
| **Bildungsplan-Verankerung** | curriculum anchoring | Introductory block citing the regulatory foundation of a unit |
| **Querbezüge** | cross-references | Connections to optional modules or related curriculum areas |
| **Fachbegriffe** | key terms | Subject-specific vocabulary introduced or reinforced in a lesson |
| **Phasen-Leitfrage** | phase guiding question | Guiding question scoped to a specific lesson phase |
| **Bildungsplan-Bezug** | curriculum reference | Per-lesson citation of specific competency indicators from the curriculum standards (Bildungsplan) |
| **Zeitbudget** | time budget | Per-lesson summary showing phase time breakdown at a glance |
| **Vorwissen-Check** | prerequisite knowledge check | Section documenting prior knowledge students need for this lesson |
| **Bewertungshinweis** | assessment note | Optional didactic hint below a grading rubric (Erwartungshorizont) table |
| **Sub-Phase** | sub-phase | Indented phase row within a parent phase, splitting it into timed steps |
| **Zeitpuffer** | time buffer | Per-segment time reserve subtracted from plannable lesson time |
| **propädeutisch** | propedeutic | Introducing advanced concepts (e.g., Sek II operators) at an introductory level |
| **SuS** | students | Schülerinnen und Schüler — common abbreviation in German educational documents. In teacher-facing documents its written-out vs. abbreviated form follows the gendering (Gendern) `teacher_docs` register; see Inclusive Language (Geschlechtergerechte Sprache) |

---

## Unit Library (Bibliothek)

| Term | English | Meaning |
|------|---------|---------|
| **Bibliothek** | unit library | The teacher's permanent, year-independent, per-subject shelf of read-only unit snapshots for reuse across classes and years |
| **eine Einheit in die Bibliothek stellen** | shelve a unit | Copy a finished, validated unit into the library (strips class binding, drafts, and student submissions) |
| **eine Einheit übernehmen/zuweisen** | assign a unit | Copy a shelved unit from the library into a fresh class-bound folder for a new class or school year |
| **Fassung** | version (of a library unit) | One kept state of a library unit. Re-shelving a revised unit keeps the previous state; the library presents one unit with its versions (Fassungen), the newest offered by default |
| **eine Einheit als neue Fassung aufnehmen** | shelve as a new version | Re-shelve a revised unit as a new version (neue Fassung) of its existing library unit — the previous version stays restorable; the alternative is an own, new unit (eigene, neue Einheit), which starts its own history |
| **eine archivierte Einheit wiederherstellen** | restore an archived unit | Bring a replaced (archived) library version back into the offered list — offer an older version (Fassung) as the family's default again (eine ältere Fassung wieder als Standard anbieten) |
| **eine Einheit exportieren / weitergeben** | export a unit | Pack a shelved library unit into a single portable file to hand to a colleague at another school |
| **eine Einheit importieren** | import a unit | Read a colleague's unit file into your own library as an external entry, checked and screened first |
| **Einheiten-Datei** | unit file | The single portable file a shared unit travels in; its contents are the validated documents only, never drafts, submissions, or class names |
| **„Nur die Dokumente" (Nur-Dokumente-Export)** | plain export | Hand a unit's finished documents to a colleague as ordinary files in one ZIP — openable by anyone, no Thalura needed; delivery only, never re-importable as a unit |
| **Thalura-Paket** | Thalura package | The re-importable unit file (`.thaluraunit`) a colleague who also uses Thalura reads back into their own library (Bibliothek) — the alternative to the plain export |

---

## Backup & Restore (Sicherung & Wiederherstellung)

| Term | English | Meaning |
|------|---------|---------|
| **Sicherung / Backup** | workspace backup | A single file holding the teacher's whole irreplaceable workspace — year plans, classes, the library (Bibliothek), every generated document, and in-progress drafts (Entwürfe) — for moving to a new computer or recovering after a loss; student submissions (Abgaben) and regenerable data are left out. **Disambiguation:** `Sicherung` reads as *workspace backup* only in a data/file context (with `Daten`/`Datei`/`Backup`); the bare `Sicherung` in a lesson-planning context stays the consolidation phase (Sicherung, the Stundenstruktur term above) — not a backup. |
| **Wiederherstellung / wiederherstellen** | restore a workspace | Bring a whole-workspace backup file back — cleanly into a fresh/empty workspace, or additively adding only the library (Bibliothek) into a populated one. **Disambiguation:** restoring the *whole workspace* (this) is distinct from *eine archivierte Einheit wiederherstellen* (restore an archived unit, the Bibliothek term above), which brings a single replaced library version back into the assignable list; when a bare "wiederherstellen" could mean either, ask. |

---

## Social Forms

| Term | English | Abbreviation | Meaning |
|------|---------|-------------|---------|
| **Einzelarbeit** | — | EA | Individual work |
| **Partnerarbeit** | — | PA | Pair work |
| **Gruppenarbeit** | — | GA | Group work |
| **Plenum** | — | PL | Whole-class activity |
| **Lehrervortrag** | — | LV | Teacher-led lecture/presentation |

---

## Competency Standards

| Term | English | Meaning |
|------|---------|---------|
| **Kompetenzbereich** | competency domain | Competency domain (as defined in the Bildungsplan) |
| **Kompetenzübersicht** | competency overview | Summary table mapping competency domains (Kompetenzbereiche) and indicators to unit lessons |
| **Anforderungsbereich (AB)** | performance level | Performance level (I = reproduction, II = transfer, III = evaluation) |
| **AB I** | — | Reproduktion — reproduction, basic comprehension |
| **AB II** | — | Reorganisation und Transfer — application, analysis |
| **AB III** | — | Reflexion und Bewertung — evaluation, judgment |
| **Operatoren** | action verbs | BSB-published verbs defining the expected cognitive operation (e.g., "beschreiben", "analysieren", "beurteilen") |

**Important:** The correct abbreviation is **AB** (Anforderungsbereich), never "AFB".

---

## Cross-Curricular Framework

### Guiding Perspectives (Leitperspektiven)

| Term | English | Abbreviation | Meaning |
|------|---------|-------------|---------|
| **Leitperspektive** | guiding perspective | — | Cross-cutting educational perspective anchored in the curriculum framework (Bildungsplan); applies across all subjects (Fächer) and school types (Schulformen) |
| **Wertebildung / Werteorientierung** | values education | **W** | Democratic values, tolerance, social responsibility |
| **Bildung für nachhaltige Entwicklung** | education for sustainable development | **BNE** | Sustainability, global justice, ecological responsibility |
| **Leben und Lernen in einer digital geprägten Welt** | digital literacy | **D** | Digital competence, media literacy, data sovereignty |

### Cross-Curricular Task Areas (Aufgabengebiete)

Sek I only (Grades 5–10 and Vorstufe). Each cross-curricular task area (Aufgabengebiet) organizes competencies into three domains: Erkennen, Bewerten, Handeln.

| Term | English | Meaning |
|------|---------|---------|
| **Aufgabengebiet** | cross-curricular task area | Cross-curricular learning area mandated for Sek I |
| **Berufsorientierung** | career orientation | Career guidance and work-world orientation |
| **Gesundheitsförderung** | health promotion | Physical and mental health education |
| **Globales Lernen** | global learning | Global justice, development, and interconnectedness |
| **Interkulturelle Erziehung** | intercultural education | Cultural diversity, anti-discrimination, inclusion |
| **Medienerziehung** | media education | Critical media use and media production |
| **Sexualerziehung** | sex education | Sexuality, gender identity, relationships |
| **Sozial- und Rechtserziehung** | social and legal education | Legal awareness, civic responsibility, conflict resolution |
| **Umwelterziehung** | environmental education | Ecological awareness, resource conservation |
| **Mobilitäts- und Verkehrserziehung** | mobility and traffic education | Safe and sustainable mobility |

---

## Assessment

| Term | English | Meaning |
|------|---------|---------|
| **Kurztest** | short test | Short test (usually Sek I, no formal Abitur weight) |
| **Klausur** | formal exam | Formal written exam |
| **Abiturklausur** | Abitur exam | Abitur-level exam (must match ARL format exactly) |
| **Erwartungshorizont (EH)** | grading rubric | Grading rubric / model answer sheet (teacher version) |
| **Aufgabenstellung** | — | Task/question sheet (student version) |
| **Aufgabe** | exam paper | Exam paper / task — file name for the student-facing assessment document |
| **Notenschlüssel** | grading scale | Grading scale (points → grade mapping) |
| **Nachteilsausgleich** | accommodations | Legally defined accommodations for students with special needs |
| **Präsentationsprüfung** | — | Oral presentation exam (alternative Abitur format) |
| **ESA** | — | Erster allgemeinbildender Schulabschluss — first general school-leaving qualification (Stadtteilschule, Grade 9) |
| **MSA** | — | Mittlerer Schulabschluss — intermediate school-leaving qualification (Stadtteilschule, Grade 10) |
| **Mündliche Prüfung (ESA/MSA)** | oral exam (ESA/MSA) | Oral exit exam at Stadtteilschule; two-part format (material-based presentation + Fachgespräch) |

---

## Materials

| Term | English | Config Key | Abbreviation |
|------|---------|-----------|--------------|
| **Arbeitsblatt** | worksheet | `worksheet` | AB (in naming: use full word to avoid confusion with Anforderungsbereich) |
| **Handout** | handout | `handout` | HO |
| **Lesetext** | reading text | `reading_text` | LT |
| **Folien** | slides | `slides` | — |
| **Aufgabenfolien** | student task deck | `student_task_deck` | — |

---

## Image Generation

| Term | English | Meaning |
|------|---------|---------|
| **Bildgenerierungs-Werkzeug** | image-generation tool | A connected tool that generates images automatically during material creation |
| **Bild-Prompt** | image prompt | The full English description used to generate an image |
| **Quellenangabe** | citation | Source attribution (e.g. the AI-image footnote) |

---

## Inclusive Language (Geschlechtergerechte Sprache)

Terms for the configurable gendering (Gendern) of generated German documents. The chosen form is applied consistently across each German document; English output is unaffected.

| Term | English | Meaning |
|------|---------|---------|
| **Gendern** | gendering | Use of gender-inclusive language forms in generated German documents |
| **geschlechtergerechte Sprache** | gender-inclusive language | The umbrella concept for gender-inclusive language; the BSB's own term |
| **Beidnennung** | paired form | Full written-out feminine + masculine form ("Schülerinnen und Schüler"); the `paired` enum value |
| **Gendersternchen** | gender star | The `*` form ("Schüler\*innen"); the `star` enum value |
| **Gender-Doppelpunkt** | gender colon | The `:` form ("Schüler:innen"); the `colon` enum value |
| **Lehrkräfte** | teaching staff | Gender-neutral plural for teachers ("die Lehrkräfte") |

`Aufgabe` (exam paper, student version) and `Erwartungshorizont` (grading rubric, teacher version) are in the Assessment section above — they are the assessment file-role tags and are **not** gendering-responsive.

---

## Regulations

| Term | English | Full Name | Scope |
|------|---------|-----------|-------|
| **BP** | curriculum standards | Bildungsplan | Curriculum standards per subject and level |
| **ARL** | Abitur exam regulations | Abiturrichtlinie | Abitur exam regulations per subject |
| **APO-GrundStGy** | — | Ausbildungs- und Prüfungsordnung (Grundschule, Sek I) | Exam rules for Sek I |
| **APO-AH** | — | Ausbildungs- und Prüfungsordnung (Allgemeine Hochschulreife) | Exam rules for Sek II / Abitur |
| **SiC** | — | Schulinternes Curriculum | School-specific curriculum (optional override) |
| **BSB** | — | Behörde für Schule und Berufsbildung | Hamburg school authority |
| **Schwerpunktthemen** | Abitur focus topics | — | Published per subject and Abitur year; content emphasis for S3/S4 |

---

## Special Needs (Anonymized Categories)

| Code | English | Meaning | Key Differentiation |
|------|---------|---------|---------------------|
| **Förderbedarf / Förderbedarfe** | special learning need(s) | Special learning need(s) | Broader category; Nachteilsausgleich is specifically the accommodation measures |
| **Förderschwerpunkt** | priority area of support | The recognized category of special learning need a measure addresses (per-category heading term in the catalog) | The catalog's per-category sections; the 8 codes below are the Förderschwerpunkte |
| **Binnendifferenzierung** | internal differentiation | Pedagogical differentiation *within* the lesson (depth, scaffolding, enrichment) | Distinct from Nachteilsausgleich (the legal accommodation); the kind of measure for HB and the everyday-lesson side of ADHS/ASS/DaZ |
| **ADHS** | attention-deficit/hyperactivity disorder | Aufmerksamkeitsdefizit-Hyperaktivitätsstörung | Shorter phases, clear structure, visual markers |
| **LRS** | reading and spelling difficulty | Lese-Rechtschreib-Schwäche | Larger font, reduced text, extended time |
| **HB** | giftedness | Hochbegabung | Extension tasks, advanced sources, higher AB |
| **DaZ** | German as a second language | Deutsch als Zweitsprache | Bilingual glossaries, visual scaffolding |
| **ASS** | autism spectrum disorder | Autismus-Spektrum-Störung | Predictable structure, written instructions |
| **KB** | physical impairment | Körperliche Beeinträchtigung | Digital alternatives, flexible formats |
| **SB** | visual impairment | Sehbeeinträchtigung | Large print, high contrast, verbal descriptions |
| **AUD** | hearing impairment | Auditive Beeinträchtigung (Hörbeeinträchtigung) | Visual instructions, written task cards |

See `${CLAUDE_PLUGIN_ROOT}/references/special-needs-catalog.md` for detailed differentiation measures per category.

---

## Subject Names

| German | English | Abbreviation |
|--------|---------|-------------|
| **Englisch** | English | **E** |
| **Philosophie** | Philosophy | **P** |
| **Psychologie** | Psychology | **Psy** |
| **Religion** | Religion (Protestant/Catholic/Islamic, etc.) | **R** |

---

## Product Terms

| Term | English | Meaning |
|------|---------|---------|
| **Fehlerbericht** | diagnostic report | The single TXT file the report-a-problem (Problem melden) flow generates for the teacher to review and send manually |
| **Problem melden / Fehler melden** | report a problem | The teacher intent that triggers the diagnostic report (Fehlerbericht) flow |

---

## Thalura Task Codenames

| Codename | System Name | Function |
|----------|-------------|----------|
| **The Map** | `plan_school_year` | School year planning |
| **The Holocron** | `plan_unit` | Unit planning (unit outline) |
| **The Holocron Log** | `reflect_unit` | Unit reflection |
| **The Upside Down** | `plan_lesson_detail` | Detailed lesson planning |
| **The Playbook** | `generate_assets` | Material creation |
| **The Multiverse** | `differentiate_assets` | Differentiated material variants |
| **Eleven's Vision** | `generate_image_prompts` | Image generation prompts |
| **Challenge Accepted** | `create_assessment` | Assessment creation |
| **The Sacred Texts** | `compliance_check` | Compliance validation |
| **Yoda's Wisdom** | `methodology_advisor` | Method recommendations |

---

## Regulatory Provenance

Each term's regulatory source. Source paths are relative to `${CLAUDE_PLUGIN_ROOT}/regulations/hamburg/` and use the three-way directory structure: `shared/` (both school types), `gymnasium/` (Gymnasium Sek I only), `stadtteilschule/` (Stadtteilschule Sek I only). `{subject}/` is shorthand for subject-specific directories (`english/`, `philosophy/`, `psychology/`, `religion/`). `—` indicates general educational terminology not defined in a specific bundled regulatory document.

**Current scope:** Hamburg — Gymnasium and Stadtteilschule. Shared docs (Sek II, cross-subject framework) apply to both school types. Sek I docs are school-type-specific. Adding documents from another federal state requires no schema change, just new rows.

| Term | Federal State | School Type | Source |
|------|--------------|-------------|--------|
| Gymnasium | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf` (§ 6.3, p. 31) |
| Stadtteilschule | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf` (§ 6.2, p. 30) |
| Beobachtungsstufe | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf` (§ 6.2, p. 30; § 6.3.2, p. 31) |
| Mittelstufe | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf` (§ 6.2, p. 30; § 6.3.2, p. 31) |
| Sekundarstufe I (Sek I) | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf` (§ 6.2, p. 30; § 6.3.2, p. 31) |
| Sekundarstufe II (Sek II) | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf` (§ 6.2, p. 30; § 6.3.2, p. 31) |
| Vorstufe | Hamburg | Stadtteilschule | `shared/cross-subject/allgemeiner-teil.pdf` (§ 6.2, p. 30) |
| Studienstufe | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf` (§ 6.4, p. 33) |
| Jahrgang / Klasse | — | — | — |
| Anforderungsniveau (gA / eA) | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf` (§ 6.4.3, p. 34), `shared/cross-subject/apo-ah.pdf` (§ 5) |
| Unterrichtseinheit (UE) | — | — | — |
| Stunde / Einzelstunde / Doppelstunde | — | — | — |
| Stundenentwurf | — | — | — |
| Verlaufsplan | — | — | — |
| Grobplanung | — | — | — |
| Einstieg / Erarbeitung / Sicherung / Vertiefung / Puffer | — | — | — |
| Stundenzahl / Stundenstruktur | — | — | — |
| Didaktisches Konzept | — | — | — |
| Materialübersicht | — | — | — |
| Schuljahresübersicht | — | — | — |
| Standardmaterial | — | — | — |
| propädeutisch | — | — | — |
| SuS | — | — | — |
| Leitfrage | — | — | — |
| Bildungsplan-Verankerung | — | — | — |
| Querbezüge | Hamburg | shared | `shared/{subject}/bildungsplan-sek2-*.pdf`, `{school_type}/{subject}/bildungsplan-sek1-*.pdf` |
| Fachbegriffe | — | — | — |
| Phasen-Leitfrage | — | — | — |
| Bildungsplan-Bezug | Hamburg | shared | `shared/{subject}/bildungsplan-sek2-*.pdf`, `{school_type}/{subject}/bildungsplan-sek1-*.pdf` |
| Zeitbudget | — | — | — |
| Vorwissen-Check | — | — | — |
| Bewertungshinweis | — | — | — |
| Sub-Phase | — | — | — |
| Zeitpuffer | — | — | — |
| Einzelarbeit / Partnerarbeit / Gruppenarbeit / Plenum / Lehrervortrag | — | — | — |
| Kompetenzbereich | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf`, `shared/{subject}/bildungsplan-sek2-*.pdf`, `{school_type}/{subject}/bildungsplan-sek1-*.pdf` |
| Kompetenzübersicht | — | — | — |
| Anforderungsbereich (AB I / II / III) | Hamburg | shared | `shared/{subject}/abiturrichtlinie-*.pdf` (e.g. ARL English § 3.2), `shared/cross-subject/operatoren-gesellschaftswissenschaften.pdf` |
| Operatoren | Hamburg | shared | `shared/cross-subject/operatoren-gesellschaftswissenschaften.pdf`, `shared/philosophy/operatoren-beispiel-philosophie.pdf`, `shared/psychology/operatoren-beispiel-psychologie.pdf`, `shared/{subject}/abiturrichtlinie-*.pdf` |
| Leitperspektive | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf` (§ 3, pp. 8–14) |
| Wertebildung / Werteorientierung (W) | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf` (§ 3.1, pp. 8–10) |
| Bildung für nachhaltige Entwicklung (BNE) | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf` (§ 3.2, pp. 11–12) |
| Leben und Lernen in einer digital geprägten Welt (D) | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf` (§ 3.3, pp. 12–14) |
| Aufgabengebiet | Hamburg | school-type-specific | `{school_type}/cross-subject/sek1-aufgabengebiete.pdf` (§ 1, pp. 4–7) |
| Berufsorientierung | Hamburg | school-type-specific | `{school_type}/cross-subject/sek1-aufgabengebiete.pdf` (§ 2.1) |
| Gesundheitsförderung | Hamburg | school-type-specific | `{school_type}/cross-subject/sek1-aufgabengebiete.pdf` (§ 2.2) |
| Globales Lernen | Hamburg | school-type-specific | `{school_type}/cross-subject/sek1-aufgabengebiete.pdf` (§ 2.3) |
| Interkulturelle Erziehung | Hamburg | school-type-specific | `{school_type}/cross-subject/sek1-aufgabengebiete.pdf` (§ 2.4) |
| Medienerziehung | Hamburg | school-type-specific | `{school_type}/cross-subject/sek1-aufgabengebiete.pdf` (§ 2.5) |
| Sexualerziehung | Hamburg | school-type-specific | `{school_type}/cross-subject/sek1-aufgabengebiete.pdf` (§ 2.6) |
| Sozial- und Rechtserziehung | Hamburg | school-type-specific | `{school_type}/cross-subject/sek1-aufgabengebiete.pdf` (§ 2.7) |
| Umwelterziehung | Hamburg | school-type-specific | `{school_type}/cross-subject/sek1-aufgabengebiete.pdf` (§ 2.8) |
| Mobilitäts- und Verkehrserziehung | Hamburg | school-type-specific | `{school_type}/cross-subject/sek1-aufgabengebiete.pdf` (§ 2.9) |
| Kurztest | — | — | — |
| Klausur | Hamburg | shared | `shared/cross-subject/apo-ah.pdf` (§ 10), `shared/{subject}/abiturrichtlinie-*.pdf` |
| Abiturklausur | Hamburg | shared | `shared/cross-subject/apo-ah.pdf` (§ 24), `shared/{subject}/abiturrichtlinie-*.pdf` |
| Erwartungshorizont (EH) | Hamburg | shared | `shared/{subject}/abiturrichtlinie-*.pdf` (e.g. ARL English § 4.3) |
| Aufgabenstellung / Aufgabe | Hamburg | shared | `shared/{subject}/abiturrichtlinie-*.pdf` |
| Notenschlüssel | Hamburg | shared | `shared/cross-subject/apo-ah.pdf` (§ 9) |
| Nachteilsausgleich | Hamburg | shared | `shared/cross-subject/apo-ah.pdf` (§ 13), `shared/cross-subject/apo-grundstgy.pdf` (§ 6) |
| Präsentationsprüfung | Hamburg | shared | `shared/cross-subject/apo-ah.pdf` (§ 26), `shared/{subject}/abiturrichtlinie-*-praesentation.pdf` |
| ESA | Hamburg | Stadtteilschule | `shared/cross-subject/apo-grundstgy.pdf` (§ 21 Abs. 1a), `stadtteilschule/{subject}/musteraufgaben-esa-*.pdf` |
| MSA | Hamburg | Stadtteilschule | `shared/cross-subject/apo-grundstgy.pdf` (§ 21 Abs. 1b), `stadtteilschule/{subject}/musteraufgaben-msa-*.pdf` |
| Mündliche Prüfung (ESA/MSA) | Hamburg | Stadtteilschule | `shared/cross-subject/apo-grundstgy.pdf` (§ 21), `stadtteilschule/{subject}/musteraufgaben-{esa,msa}-*.pdf` |
| Arbeitsblatt / Handout / Lesetext / Folien | — | — | — |
| Bildgenerierungs-Werkzeug | — | — | — |
| Bild-Prompt | — | — | — |
| Quellenangabe | — | — | — |
| Bildungsplan (BP) | Hamburg | shared | `shared/cross-subject/allgemeiner-teil.pdf`, `shared/{subject}/bildungsplan-sek2-*.pdf`, `{school_type}/{subject}/bildungsplan-sek1-*.pdf` |
| Abiturrichtlinie (ARL) | Hamburg | shared | `shared/cross-subject/abiturrichtlinie.pdf`, `shared/{subject}/abiturrichtlinie-*.pdf` |
| APO-GrundStGy | Hamburg | shared | `shared/cross-subject/apo-grundstgy.pdf` |
| APO-AH | Hamburg | shared | `shared/cross-subject/apo-ah.pdf` |
| SiC | Hamburg | shared | `shared/cross-subject/sic-leitfaden.pdf` |
| BSB | Hamburg | — | — |
| Schwerpunktthemen | Hamburg | shared | `shared/cross-subject/a-heft-2026.pdf`, `shared/cross-subject/a-heft-2027.pdf` (Ch. 2 English, Ch. 17 Philosophy, Ch. 18 Psychology, Ch. 19 Religion) |
| Förderbedarf / Förderbedarfe | Hamburg | shared | `shared/cross-subject/apo-ah.pdf` (§ 13), `shared/cross-subject/apo-grundstgy.pdf` (§ 6) |
| ADHS / LRS / HB / DaZ / ASS / KB / SB / AUD | — | — | — |
