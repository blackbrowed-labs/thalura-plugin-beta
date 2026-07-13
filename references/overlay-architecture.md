# Subject Overlay Architecture

Subject-specific data (suitability ratings, context notes) lives in **overlay files**, separate from subject-agnostic **core files**. Adding a new subject means adding overlay files only — no core edits.

---

## Directory Structure

```
references/{type}/
  core/
    {category}.md              — subject-agnostic content
  overlays/
    {subject}/
      {category}.md            — subject-specific ratings and notes
```

Concrete layout for v1.0 reference types:

```
references/methods/
  core/
    activation.md
    cooperative.md
    creative-performative.md
    discussion.md
    media-analysis.md
    self-directed.md
    text-analysis.md
    thinking-dilemma.md
    writing.md
  overlays/
    english/
      activation.md
      cooperative.md
      ...                      — one file per core category
    philosophy/
      ...
    religion/
      ...

references/exam-formats/
  core/
    {format}.md                — generic exam structure
  overlays/
    english/
      {format}.md              — subject-specific sections, operator lists
    philosophy/
      ...
    religion/
      ...
```

Subject directory names use English subject IDs from `${CLAUDE_PLUGIN_ROOT}/references/subjects.json`: `english`, `philosophy`, `religion`.

---

## Scope — Which Reference Types Use Overlays

| Reference type | Uses overlays? | Reason |
|---|---|---|
| Methods | Yes | Suitability varies by subject. Core describes procedure; overlay rates it. |
| Exam formats | Yes | Formats have subject-specific sections and operator lists. |
| Document registry | No | Already organized by document type, not subject. Subject-aware by design. |
| Glossary | No | Subject-agnostic educational terminology. |
| Temporal logic | No | Date/deadline calculations are subject-agnostic. |
| Special needs | No | Accommodations apply across all subjects. |
| Config system | No | Uses the two-tier config pattern, not overlays. |

---

## Core File Format

Core files contain everything **except** subject-specific ratings. Each method entry:

```markdown
## Gallery Walk

**Grades:** 5–S4
**Phase:** Erarbeitung, Sicherung
**Time:** 15–25 min

**Procedure:**

1. Poster mit Arbeitsergebnissen im Raum verteilen
2. SuS gehen in Kleingruppen von Poster zu Poster
3. An jedem Poster: lesen, diskutieren, Feedback notieren
4. Rückkehr zum eigenen Poster, Feedback auswerten

**Variations:**

- **Silent Gallery Walk:** Kein Gespräch, nur schriftliches Feedback
- **Expert Gallery Walk:** Ein SuS bleibt als Experte am Poster

**Avoid when:**

- Weniger als 3 verschiedene Ergebnisse vorliegen
- Raum zu klein für Bewegung
```

The `**Subjects:**` line from the current skill format is **removed** from core. All other fields stay.

Methods are separated by `---`.

---

## Overlay File Format

Each overlay file covers one category (matching the core file name). It contains per-method entries with a **Rating** and optional **Notes**.

```markdown
# English — Activation Methods

## Gallery Walk

**Rating:** high

**Notes:** Excellent for vocabulary display tasks and peer feedback on writing drafts. Works especially well with visual prompts in lower grades.

---

## Think-Pair-Share

**Rating:** moderate

**Notes:** Effective for grammar hypothesis building. Less suited for extended speaking practice — consider Fishbowl instead.

---

## Concept Mapping

**Rating:** high

**Notes:** Vocabulary networks and genre conventions.
```

### Rules

- The `## Method Name` heading must **exactly match** the heading in the corresponding core file. This is how core and overlay entries are paired at runtime.
- **Rating** is required for every entry. Must be one of: `high`, `moderate`, `low`, `none`.
- **Notes** is optional. When present, it provides subject-specific context, typical use cases, or caveats.
- Every method from the core file should have an overlay entry. Methods rated `none` should include a note explaining why.

---

## Rating Scale

| Keyword | Meaning | When to use |
|---|---|---|
| `high` | Highly suited | Method is a natural fit; use confidently |
| `moderate` | Moderately suited | Works well in specific contexts |
| `low` | Minimally suited | Possible but limited applicability |
| `none` | Not suited | Method conflicts with subject conventions or goals |

Keywords are used instead of symbols (●●●/●●/●/—) for unambiguous LLM parsing.

---

## Runtime Merge Algorithm

When Claude needs methods for a subject (e.g., English) and a category (e.g., activation):

1. **Read core file** — `${CLAUDE_PLUGIN_ROOT}/references/methods/core/activation.md`
2. **Read overlay file** — `${CLAUDE_PLUGIN_ROOT}/references/methods/overlays/english/activation.md`
3. **Match by heading** — pair each core method with its overlay entry by exact `## Method Name`
4. **Merge:**
   - Method has overlay entry → attach rating and notes from overlay
   - Method has **no** overlay entry → include method, flag as "not rated for English"
5. **Present** — show merged methods to Claude's generation logic

The merge is **read-only** — neither file is modified. Claude performs the merge in-context each time methods are needed.

### Merge Output (Conceptual)

For each method, the merged result contains:

| Field | Source |
|---|---|
| Name, Grades, Phase, Time | Core |
| Procedure, Variations, Avoid-when | Core |
| Rating | Overlay (or "not rated") |
| Notes | Overlay (or absent) |

---

## Missing Overlay Handling

Two levels of "missing":

### No overlay entry for a specific method

The method is available but flagged **"not rated for {subject}"**. The teacher sees it and can decide whether to use it. This is better than hiding potentially useful methods.

### No overlay file for an entire category

All methods from that core category are available but **all flagged as "not rated"**. This happens when a new core category is added before overlays are written.

### No overlay directory for a subject

The subject has no overlay data at all. All methods across all categories are available but unrated. This is the starting state when adding a new subject before writing any overlay files.

---

## Exam Format Files (Flat Architecture)

Unlike methods, exam formats do **not** use the core/overlay split. Each format is a self-contained flat file in `${CLAUDE_PLUGIN_ROOT}/references/exam-formats/`. Subject differences are structural additions (new sections, different operator sets), not suitability ratings — the heading-matching merge designed for methods doesn't apply.

**Plugin-bundled formats:** `${CLAUDE_PLUGIN_ROOT}/references/exam-formats/{format}.md`
- 9 format files: `short-test.md`, `exam-sek1.md`, `exam-sek2-ga.md`, `exam-sek2-ea.md`, `abitur-exam.md`, `oral-abitur-exam.md`, `presentation.md`, `oral-esa-exam.md`, `oral-msa-exam.md`
- Each file contains: metadata, structure, AB distribution, task rules, permitted aids, regulatory references, example skeleton, and subject-specific notes (embedded `## Subject-Specific Notes` sections)
- Immutable — updated via plugin releases only

**User-defined formats:** `<WORKSPACE_ROOT>/data/exam-formats/{format}.md`
- Created by the teacher using the `_template.md` scaffold
- If a user file has the same filename as a plugin file, the user file takes **full precedence** (no partial merge — entire file replaced)
- `_template.md` provides the standard section structure

**Path resolution:** The `exam_type` enum value (English, `snake_case`) maps to the filename by replacing `_` with `-`:
- `"exam_sek2_ga"` → `exam-sek2-ga.md`
- `"abitur_exam"` → `abitur-exam.md`

**Localized display:** When presenting format options to the teacher, resolve display names via `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `assessment_types` based on `conversation_language`. Internally, always use the English enum ID.

---

## Adding a New Subject

See `adding-a-subject.md` for the complete procedure covering all artifacts a new subject needs. This file is the detailed spec for the **method-overlay** and **exam-format** classes: method overlays are picked up automatically when Claude reads the overlay directory for that subject, and exam-format notes when reading the `## Subject-Specific Notes` section of each format file.

---

## Migration from Current Skill

The current skill embeds subject data inline:

```markdown
**Subjects:** English ●●●, Philosophy ●●● (ethical reasoning, Socratic dialogue)
```

Migration to the overlay architecture:

1. **Core file:** Remove the `**Subjects:**` line entirely. Keep all other fields.
2. **Per subject overlay:** Extract the rating and convert to keyword (`●●●` → `high`, `●●` → `moderate`, `●` → `low`, `—` → `none`, `○` → `none`). Parenthetical notes become the `**Notes:**` field.
3. **Missing subjects:** If a method's Subjects line omits a subject entirely, the overlay gets `**Rating:** none` with a note derived from context.
4. **Religion data:** The current skill has no Religion ratings — Religion overlays start empty. Ratings are added as the plugin matures.

---

## Design Notes

- **Markdown, not JSON:** Overlay files use markdown to stay consistent with the methods format. Claude reads markdown naturally. Teachers who inspect plugin files see readable content.
- **Heading matching, not IDs:** Method names are matched by exact `## Heading` text. No ID system needed — headings are already unique within each category file.
- **Spec only, not implementation:** This document defines what the merge should produce. The actual merge logic lives in the core skill instructions.
- **"Not rated" over "excluded":** Visibility with a flag is safer than silent removal. The teacher always sees the full method inventory.
