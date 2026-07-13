---
title: Task modules
description: What Thalura can do for you — from year planning to methodology advice.
---

# What Thalura can do for you

> The English guide is being translated. See the German version: [`guide/de/aufgabenmodule.md`](../de/aufgabenmodule.md).

## School year planning

Thalura keeps an always-current **year overview** (Schuljahresübersicht) as a document — all classes of the current school year with their teaching units (Unterrichtseinheiten), linked to each unit's plan (Einheitenplanung), and the competency coverage for each class. The file sits at the top level of your Thalura workspace and updates itself whenever the year plan changes. It is not meant to be edited by hand — any manual changes would be overwritten the next time it is regenerated.

## Worksheets, slides, and handouts

When you validate a student-facing material — a worksheet (Arbeitsblatt), handout
(Handout), reading text (Lesetext), slide deck (Foliensatz), or exam task paper
(Aufgabe) — Thalura automatically creates a PDF of it next to the editable file,
ready to print, hand out, or upload to a school platform. If you revise the material
and validate it again, the PDF is updated. The behaviour can be adjusted via the
advanced setting `pdf_on_validation` (not asked during setup), edited via
`/thalura:config behaviour`.

The material overview (Materialübersicht) and your unit (Einheitenplanung) and
lesson plans (Verlaufsplan) are now clickable indexes. In the overview each material
carries a label you click to open the file directly: `[DOCX]` (or `[PPTX]` for slide
decks) opens the editable file, and once the material is validated an extra `[PDF]`
opens the print-ready PDF. In the unit and lesson plans the referenced materials and
lessons become clickable links too — no more hunting through folders. Materials that
are still drafts (Entwurf) are already linked (but have no PDF yet); only
planned-but-not-yet-created materials stay plain text. The links are relative, so
they keep working when you move your Thalura folder or restore a backup; if you rename
a file outside Thalura in Finder a link can dangle, and it self-heals the next time
that document is regenerated.

When an image-generation tool (Bildgenerierungs-Werkzeug) is connected, Thalura
generates the images in a material proposal automatically — approving the proposal
covers the images, with no second question. Without one, the previous manual flow is
unchanged: for each image Thalura inserts a placeholder (Platzhalter) with the matching
image prompt (Bild-Prompt), as before. If a single image cannot be generated, that one
image gets the usual placeholder plus a short note in the chat, while the rest of the
material is still completed.

## Advanced setting: PDF on validation (`pdf_on_validation`)

This setting controls for which materials Thalura automatically creates a PDF on
validation. It is not asked during setup.

| Value | Behaviour |
|---|---|
| `"student_facing"` (default) | Only student-facing materials (worksheets, handouts, reading texts, slide decks, exam task papers) get a PDF. |
| `"all"` | All validated materials get a PDF — including teacher-facing documents such as the grading rubric (Erwartungshorizont). |
| `"off"` | No PDF is created automatically. Existing PDF files are never deleted. |

Edit this setting via `/thalura:config behaviour`. It is stored in
`config/behaviour.json` and is carried over safely through plugin updates.

## Standard supplies

Thalura keeps an optional list of your everyday classroom supplies (Standardmaterial) —
things like Post-its, tape, or pens. It comes seeded with a sensible default, and you
can strike what you don't have or add what you use instead. Lesson planning gently
leans toward the items on your list, but it never restricts your plans and never
complains about missing material. Edit the list via `/thalura:config`.
