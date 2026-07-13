# Glossary — Core Subset (hot-path terms)

A frequency-driven strict subset of `${CLAUDE_PLUGIN_ROOT}/references/glossary-de.md`, holding the highest-frequency English↔German pairs used across the skill corpus. Loaded on the hot path; the full glossary loads on demand for the long tail. Every row here is verbatim from the full glossary — this file is generated/checked as a strict subset, never hand-diverged.


## School Structure

| Term | English | Meaning | Notes |
|------|---------|---------|-------|
| **Gymnasium** | — | Academic secondary school (Grades 5–S4) | Hamburg has 8-year Gymnasium (G8) |
| **Stadtteilschule** | — | Comprehensive secondary school (Grades 5–S4) | 9-year track; includes Vorstufe (Grade 11) before Studienstufe; offers ESA (Grade 9) and MSA (Grade 10) exit qualifications |
| **Oberstufe** | — | Upper secondary (umbrella term for Sek II) | At Gymnasium = Studienstufe; at Stadtteilschule = Vorstufe + Studienstufe |
| **Studienstufe** | — | Four semesters (S1–S4) spanning two school years before Abitur | Gymnasium: Grades 11–12; Stadtteilschule: Grades 12–13 |

## Course Levels (Sek II)

| Term | English | Abbreviation | Meaning |
|------|---------|-------------|---------|
| **Anforderungsniveau** | course level | — | Course level category (gA or eA) |

## Lesson Planning

| Term | English | Meaning |
|------|---------|---------|
| **Einstieg** | opening | Opening/warm-up phase |
| **Erarbeitung** | main phase | Main working/exploration phase |
| **Sicherung** | consolidation | Consolidation/wrap-up phase |

## Competency Standards

| Term | English | Meaning |
|------|---------|---------|
| **AB I** | — | Reproduktion — reproduction, basic comprehension |
| **AB II** | — | Reorganisation und Transfer — application, analysis |
| **AB III** | — | Reflexion und Bewertung — evaluation, judgment |

## Assessment

| Term | English | Meaning |
|------|---------|---------|
| **Klausur** | formal exam | Formal written exam |
| **Aufgabe** | exam paper | Exam paper / task — file name for the student-facing assessment document |
| **ESA** | — | Erster allgemeinbildender Schulabschluss — first general school-leaving qualification (Stadtteilschule, Grade 9) |
| **MSA** | — | Mittlerer Schulabschluss — intermediate school-leaving qualification (Stadtteilschule, Grade 10) |

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

## Special Needs (Anonymized Categories)

| Code | English | Meaning | Key Differentiation |
|------|---------|---------|---------------------|
| **LRS** | reading and spelling difficulty | Lese-Rechtschreib-Schwäche | Larger font, reduced text, extended time |

## Subject Names

| German | English | Abbreviation |
|--------|---------|-------------|
| **Englisch** | English | **E** |
| **Philosophie** | Philosophy | **P** |
| **Religion** | Religion (Protestant/Catholic/Islamic, etc.) | **R** |

## Thalura Task Codenames

| Codename | System Name | Function |
|----------|-------------|----------|
| **The Holocron** | `plan_unit` | Unit planning (unit outline) |
| **The Upside Down** | `plan_lesson_detail` | Detailed lesson planning |
| **The Playbook** | `generate_assets` | Material creation |
| **Eleven's Vision** | `generate_image_prompts` | Image generation prompts |
