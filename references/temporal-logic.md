# Temporal Logic — A-Heft Lookup & Abitur Year Computation

This reference file explains how to determine the correct Abitur year for a given cohort, which is needed to select the right A-Heft (Schwerpunktthemen). It also provides the Abitur countdown logic for S3/S4 courses.

---

## Hamburg Gymnasium Semester Calendar

The Studienstufe spans four semesters (S1–S4):

| Semester | Period |
|---|---|
| S1 | August Year X → January Year X+1 |
| S2 | February Year X+1 → July Year X+1 |
| S3 | August Year X+1 → January Year X+2 |
| S4 | February Year X+2 → ~April/May Year X+2 (Abitur exams) |

---

## Abitur Year Computation

Given: `current_semester` (S1–S4), `current_date` (month + year)

### Step 1: Determine the year when this cohort started S1

```
If current_semester = S1:
    If month ∈ {August, September, October, November, December}:
        s1_year = current_year
    If month = January:
        s1_year = current_year - 1

If current_semester = S2:
    s1_year = current_year - 1
    (S2 starts in February, so S1 began the previous August)

If current_semester = S3:
    If month ∈ {August, September, October, November, December}:
        s1_year = current_year - 1
    If month = January:
        s1_year = current_year - 2

If current_semester = S4:
    s1_year = current_year - 2
    (S4 starts in February, two years after S1 started)
```

### Step 2: Compute Abitur year

```
abitur_year = s1_year + 2
```

The Abitur exams take place in the spring (April/May) of the S4 semester.

---

## Examples

| Scenario | current_semester | current_date | s1_year | abitur_year |
|---|---|---|---|---|
| Teacher plans for S2 in Feb 2026 | S2 | Feb 2026 | 2025 | **2027** |
| Teacher plans for S1 in Sep 2025 | S1 | Sep 2025 | 2025 | **2027** |
| Teacher plans for S3 in Oct 2026 | S3 | Oct 2026 | 2025 | **2027** |
| Teacher plans for S4 in Mar 2027 | S4 | Mar 2027 | 2025 | **2027** |
| Teacher plans for S1 in Jan 2026 | S1 | Jan 2026 | 2025 | **2027** |

---

## Selecting the A-Heft

The A-Heft filename uses the **Abitur year** directly — no publication year indirection.

Once `abitur_year` is computed:

1. Look for: `${CLAUDE_PLUGIN_ROOT}/regulations/hamburg/shared/cross-subject/a-heft-{abitur_year}.pdf`
2. If found: load it
3. If not found: use the most recent available file and warn:
   > "Schwerpunktthemen für Abitur {abitur_year} nicht vorhanden. Verwende {available_file} — bitte prüfe auf Aktualität."

**Currently available:**

| Filename | Applies to |
|---|---|
| `a-heft-2026.pdf` | Abitur 2026 |
| `a-heft-2027.pdf` | Abitur 2027 |
| `a-heft-2028.pdf` | Abitur 2028 |

**Schwerpunktthemen are chapters within A-Hefte**, not separate files. Each A-Heft covers all subjects — Claude reads the relevant chapter for the current subject. See `document-registry.md` Layer 5 for the subject-to-chapter mapping.

---

## Abitur Countdown

For S3 and S4 courses, the skill calculates the remaining time until Abitur exams and warns the teacher if time is running short.

### Computation

```
abitur_exam_date ≈ mid-April of abitur_year (estimate: April 15)
weeks_remaining = (abitur_exam_date - current_date) / 7
```

### Warning Thresholds

| weeks_remaining | Warning Level | Message |
|---|---|---|
| > 20 weeks | None | No warning |
| 12–20 weeks | Info | "Bis zum Abitur verbleiben ca. {weeks} Unterrichtswochen." |
| 6–12 weeks | Warning | "Bis zum Abitur verbleiben ca. {weeks} Unterrichtswochen. Soll ich Wiederholung und Klausurvorbereitung in die Planung integrieren?" |
| < 6 weeks | Urgent | "Nur noch ca. {weeks} Wochen bis zum Abitur. Schwerpunktthemen-Review und intensive Prüfungsvorbereitung empfohlen." |

### Integration

When the Abitur countdown is active (S3/S4):
- The Holocron suggests integrating Schwerpunktthemen review blocks
- Challenge Accepted warns about timing conflicts
- The Map shows the countdown in the school year overview

---

## When to Apply Temporal Logic

Temporal logic is needed in these situations:

1. **Challenge Accepted (create_assessment):** When `exam_type = "abitur_exam"`, the Schwerpunktthemen must match the Abitur year of the cohort being tested.
2. **The Holocron (plan_unit):** When planning for S3 or S4, the unit topic should align with the relevant Schwerpunktthemen.
3. **The Map (plan_school_year):** For S3/S4 school year plans, show the Abitur countdown and remaining teaching weeks.

For all other tasks and grades, temporal logic is not needed.
