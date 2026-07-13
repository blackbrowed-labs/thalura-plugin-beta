---
name: methodology
description: Methode empfehlen lassen. Use when the teacher asks for a teaching-method recommendation (Methode / Unterrichtsmethode) — which method fits a phase/topic, or whether a method works.
when_to_use: |
  DE + EN: "welche Methode?", "Methodenvorschlag", "Methode für die Erarbeitung", "funktioniert X als Methode?", "which method?", "method suggestion". Advisory, chat-only.
---

# Yoda's Wisdom (`methodology_advisor`) — Method Recommendations

> Core protocols — startup, HiTL/draft lifecycle, preferences, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).

Recommends appropriate teaching methods based on subject, grade, lesson phase, and teacher preferences. Integrated into The Holocron and The Upside Down, and also available standalone.

---

## Method Index

39 methods organized in 9 categories. Each category has a core reference file with detailed method descriptions and step-by-step instructions, plus subject-specific overlay files with suitability ratings.

| Category | Core File | Method Count | Description |
|----------|-----------|-------------|-------------|
| Activation | `${CLAUDE_PLUGIN_ROOT}/references/methods/core/activation.md` | ~4-5 | Warm-ups, prior knowledge activation, energizers |
| Cooperative | `${CLAUDE_PLUGIN_ROOT}/references/methods/core/cooperative.md` | ~5-6 | Structured group work methods |
| Creative-Performative | `${CLAUDE_PLUGIN_ROOT}/references/methods/core/creative-performative.md` | ~4-5 | Role play, creative expression, performative tasks |
| Discussion | `${CLAUDE_PLUGIN_ROOT}/references/methods/core/discussion.md` | ~4-5 | Structured discussion formats |
| Thinking-Dilemma | `${CLAUDE_PLUGIN_ROOT}/references/methods/core/thinking-dilemma.md` | ~3-4 | Ethical dilemmas, thought experiments, philosophical inquiry |
| Writing | `${CLAUDE_PLUGIN_ROOT}/references/methods/core/writing.md` | ~4-5 | Structured writing activities |
| Text Analysis | `${CLAUDE_PLUGIN_ROOT}/references/methods/core/text-analysis.md` | ~4-5 | Reading comprehension, text work, analysis methods |
| Media Analysis | `${CLAUDE_PLUGIN_ROOT}/references/methods/core/media-analysis.md` | ~3-4 | Image, film, and media literacy methods |
| Self-Directed | `${CLAUDE_PLUGIN_ROOT}/references/methods/core/self-directed.md` | ~3-4 | Station learning, portfolio, individual research |

### Subject Overlays

Each subject has overlay files at `${CLAUDE_PLUGIN_ROOT}/references/methods/overlays/{subject}/{category}.md` with suitability ratings per method. See core skill *Overlay Merge Logic* for the overlay merge algorithm.

**Rating keywords:** `high`, `moderate`, `low`, `none` (see `${CLAUDE_PLUGIN_ROOT}/references/overlay-architecture.md` for the full scale).

---

## Method Selection Logic

When selecting methods (for Holocron, Upside Down, or standalone queries):

### Step 1: Determine Filters
- **Subject:** Which subject? Overlay ratings indicate subject-specific suitability.
- **Grade:** Age-appropriate? (e.g., complex discussion formats may not work in Grade 5)
- **Lesson phase:** Opening (Einstieg), Main Phase (Erarbeitung), Consolidation (Sicherung), Deepening (Vertiefung)?
- **Social form tendency:** Does the teacher prefer certain social forms?
- **Class observations:** Any methods flagged as problematic or excellent for this specific class?

### Step 2: Load Relevant Category Files
Based on the phase and subject, load 2-3 category files using the overlay-merge algorithm — the canonical statement (read core file, read overlay file, match by heading, attach rating + notes, flag unrated) lives in the `core` skill's Overlay Merge Logic section. Do not restate it here.

| Phase | Typical Categories |
|-------|-------------------|
| Opening (Einstieg) | Activation, Creative-Performative |
| Main Phase (Erarbeitung) | Cooperative, Text Analysis, Media Analysis, Writing, Thinking-Dilemma |
| Consolidation (Sicherung) | Discussion, Writing, Creative-Performative |
| Deepening (Vertiefung) | Self-Directed, Thinking-Dilemma, Discussion |

### Step 3: Filter by Preferences and Observations
- **Check teacher preferences (Layer 2):** Remove rejected methods, prefer liked methods
- **Check teacher observations (Layer 1):** Look for emerging patterns
- **Check class observations:** Avoid methods flagged as negative for this class, prefer positive ones
- **Preference Override (CRITICAL):** If all preferred methods are filtered out, or a rejected method is the only didactically appropriate choice, select the best fit and explain transparently. See core skill for the full override rule.

### Step 4: Rank and Suggest
Present 2-3 method options with brief justification:

```
Method suggestion for {phase}:

1. {Method Name} — {brief reason why it fits}
   Social form: {social form} | Duration: {time estimate} | Suitability: {subject rating}

2. {Method Name} — {brief reason}
   Social form: {social form} | Duration: {time estimate} | Suitability: {subject rating}

3. (Alternative) {Method Name} — {brief reason}
   Note: You have previously rejected this method, but it is particularly appropriate here because {reason}.
```

The output is rendered in `conversation_language`. The template above shows the English structure; localized labels are resolved via `localization.json`.

---

## Suitability Ratings

Each method in the overlay files includes suitability ratings using keywords:

| Dimension | Source | Values |
|-----------|--------|--------|
| **Subject fit** | Overlay file | `high` / `moderate` / `low` / `none` |
| **Grade range** | Core file | e.g., "5-8", "S1-S4" |
| **Phase fit** | Core file | Opening (Einstieg) / Main Phase (Erarbeitung) / Consolidation (Sicherung) / Deepening (Vertiefung) |
| **Time needed** | Core file | e.g., "10-15 min", "30-45 min" |
| **Preparation** | Core file | Low / Medium / High |

Methods without an overlay entry for the current subject are flagged as "not rated" — they can still be suggested but with a note that subject-specific suitability hasn't been assessed.

---

## Integrated Use

### In The Holocron (Unit Planning)
- Load method index + 2-3 relevant method files (core + overlays)
- Suggest methods for each lesson in the unit outline (Grobplanung)
- Teacher can accept, reject, or replace

### In The Upside Down (Lesson Detail)
- Load method files for the specific lesson phases (core + overlays)
- Provide detailed method suggestions for each phase
- Include step-by-step instructions in the detailed lesson plan (Verlaufsplan)

---

## Standalone Use

The teacher can ask directly:
- "Which method fits a Main Phase (Erarbeitung) on topic X in grade 7 Philosophy?"
- "Do you know a good Opening (Einstieg) method for English S2?"
- "What's an alternative to Kugellager for this class?"

Output is chat-only — no document produced.

---

## Notes

- Method files contain detailed step-by-step instructions. The skill references these when creating detailed lesson plan (Verlaufsplan) entries.
- If the teacher asks "Was ist [Method Name]?", read the relevant method file and explain it.
- New methods can be added to the core reference files without changing the skill.
- Religion suitability ratings are being developed. Where ratings are not yet available, assess the method's fit based on: interreligious dialogue support, sensitive faith topic handling, existential/personal nature of Religion topics.
