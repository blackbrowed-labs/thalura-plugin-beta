---
title: Installation
description: Set up Thalura in Claude Code or Claude Cowork — stable or beta channel.
---

# Installation

> Only the section below is translated so far. For the rest of this page, see the German version: [`guide/de/installation.md`](../de/installation.md).

## Requirement: Thalura runs on your own computer

This applies to Claude Cowork. Thalura has to run on your own computer, not in
the cloud. If a task runs in the cloud, your results are missing several of the
things this guide promises you — which ones is set out just below.

How to set it: open **Settings → Cowork** and switch off
**"Run new tasks in the cloud"** — the setting that starts new tasks in the cloud
instead of on this computer — and then start a new task in Cowork. The setting
only takes effect for newly started tasks; the task you are currently in does not
move onto your computer.

What is at stake while a task runs in the cloud:

- Not a single citation in your documents is clickable — the references to the
  curriculum standards (Bildungsplan) stay plain text throughout.
- The year overview (Schuljahresübersicht) is not written, not even once your
  first teaching unit (Unterrichtseinheit) has been registered.
- Your documents are produced without your school's template — without your
  header and footer, and without your name as the author in the file properties.
- Every question put to the official regulations takes the full wait again, even
  where the same passage has long since been read.

None of this is reported as an error: no warning appears, no step breaks off, and
the finished documents look as though everything had been done. That is exactly
why there is a check here — you will not notice it on your own.

**How to check:** as soon as your first teaching unit (Unterrichtseinheit) has
been registered, the year overview (Schuljahresübersicht) has to sit directly in
your teacher folder. If it is not there, the task ran in the cloud: switch the
setting off as described above and start a new task. As a counter-check, open the
curriculum anchoring (Bildungsplan-Verankerung) of a unit plan
(Einheitenplanung) — if at least one citation there is clickable, Thalura worked
on your computer. (Individual citations staying without a link is normal: not
every document has an official online edition.)

This is where things stand today. If that changes, you will find it in
`CHANGELOG.md`.
