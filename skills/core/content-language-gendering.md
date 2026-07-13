# Thalura — Content Language & Gendering (core satellite)

Canonical reference for content-language resolution and gender-inclusive language (geschlechtergerechte Sprache). Loaded on demand by document-producing tasks; the always-on `core` skill keeps a one-line pointer. All document-producing skills MUST use the chain and directive here — do not re-implement language resolution or gendering in individual skills.

## Content Language Resolution

> Canonical reference — all document-producing skills must use this chain. Do not implement language resolution logic in individual skills.

Every piece of student-facing content needs a resolved content language. Use this 4-step fallback chain:

1. **`content_language.{output_type}`** — per-subject, per-output-type override (e.g., `content_language.worksheets = "en"` for English)
2. **`target_language`** — per-subject target language (`"en"` for English, `null` for non-language subjects)
3. **`content_language_default`** — profile-level default material language, set during onboarding
4. **`conversation_language`** — global fallback (the language Claude uses to communicate)

### Resolution steps

Given a subject and output type:

1. Look up `subjects[subject].content_language.{output_type}` — if set, use it
2. If missing or `content_language` object absent → look up `subjects[subject].target_language` — if non-null, use it
3. If null → look up root-level `content_language_default` — if set, use it
4. If missing → fall back to root-level `conversation_language`

### Output type key mapping

| Material type | Output type key |
|---|---|
| Worksheet | `worksheets` |
| Handout | `handouts` |
| Slides | `slides` |
| Assessment (student-facing) | `assessments` |
| Grading rubric (Erwartungshorizont) | `assessment_rubric` |
| Detailed lesson plan (Verlaufsplan) task instructions | `unit_plan_tasks` |

If the output type is ambiguous, infer from context: material file → its `asset_type`; lesson file → material table entry. Only ask if truly ambiguous.

### Edge case examples

| Scenario | Step 1 | Step 2 | Step 3 | Step 4 | Result |
|---|---|---|---|---|---|
| English worksheet | `worksheets = "en"` | — | — | — | **en** |
| English grading rubric (Erwartungshorizont) | `assessment_rubric = "de"` | — | — | — | **de** |
| Philosophy worksheet, German teacher | not set | `null` | `"de"` | — | **de** |
| Philosophy worksheet, international school (`conv_lang = "en"`, `default = "en"`) | not set | `null` | `"en"` | — | **en** |

### Interaction language vs content language

These are separate concerns:
- **`conversation_language`**: How Claude talks to the teacher (proposals, questions, status updates). Always use `conversation_language`.
- **Content language**: What students see in materials. Resolved via the fallback chain above.
- **Prompt language**: For image generation prompts (Eleven's Vision), always English regardless of content language.

See `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-profile.md` for the full field definitions.

## Gendering — Geschlechtergerechte Sprache

> Canonical reference — all document-producing skills apply gender-inclusive language (geschlechtergerechte Sprache) through this directive. It shapes **document content only**, never the conversation.

The teacher's gendering (Gendern) preference lives in `gendering` in the teacher profile, with two registers: `gendering.student_docs` and `gendering.teacher_docs`. Apply it as follows.

1. **Gate on the resolved content language.** First resolve the document's content language via the canonical 4-step chain (Content Language Resolution). **If the resolved content language is not German, this directive is a no-op** — apply no gendering transform. (English gendering is out of scope; the setting acts only on German output.)

2. **Pick the register by audience.** Use this audience-to-register mapping:

   | Document | Register |
   |---|---|
   | Worksheet (Arbeitsblatt) | `student_docs` |
   | Handout | `student_docs` |
   | Student-facing assessment paper (Aufgabe) | `student_docs` |
   | Unit Plan (Einheitenplanung) | `teacher_docs` |
   | Detailed Lesson Plan (Verlaufsplan) | `teacher_docs` |
   | Grading Rubric (Erwartungshorizont) | `teacher_docs` |
   | Reflection (Reflexion) | `teacher_docs` |
   | Material overview (Materialübersicht) | `teacher_docs` |

3. **Apply the chosen form — worked rule per value.** Each rule describes the target transform; for a representative example form, resolve the matching key under `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `gendering.student_docs_examples.{value}` (or `teacher_docs_examples.{value}` for the teacher register) rather than relying on an inlined literal.
   - `neutral` ⇒ neutral plurals / substantivised forms; resolve a representative example from `…gendering.student_docs_examples.neutral`.
   - `paired` ⇒ the full paired form (Beidnennung); resolve from `…gendering.student_docs_examples.paired`.
   - `colon` ⇒ the gender-colon form (Gender-Doppelpunkt); resolve from `…gendering.student_docs_examples.colon`.
   - `star` ⇒ the gender-star form (Gendersternchen); resolve from `…gendering.student_docs_examples.star`.
   - `abbreviation` ⇒ professional abbreviations; resolve from `…gendering.teacher_docs_examples.abbreviation`.
   - `full` ⇒ the form written out in full; resolve from `…gendering.teacher_docs_examples.full`.

4. **`neutral` per-term auto-fallback.** Under `student_docs: neutral`, where a clean neutral plural does not exist for a term, fall back to the paired form (Beidnennung — `paired`) **for that one term only**; every other term stays neutral. The fallback is per-term, never whole-document.

5. **Consistency is mandatory.** Apply the **one chosen form across the whole document.** Mixed forms within a single document are the worst outcome for human readers and text-to-speech.

6. **Never touch conversation.** This shapes document content only; proposals, questions, and status updates continue to follow `conversation_language`, ungendered by this directive.

7. **Defaults if `gendering` is absent:** `student_docs: neutral` (with the per-term `paired` fallback), `teacher_docs: abbreviation`.

8. **When it applies.** Apply at content-generation time (Step 4/Step 5 of the integrated 8-step flow — see `${CLAUDE_PLUGIN_ROOT}/skills/core/hitl-lifecycle.md`) **and again on every revision (Step 7)**, so revised and derived documents stay consistent with the setting. Re-gendering an already-edited file is an **in-place edit**, not a regeneration.

See `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-profile.md` for the `gendering` field definitions and `${CLAUDE_PLUGIN_ROOT}/references/localization.json` for the option examples.
