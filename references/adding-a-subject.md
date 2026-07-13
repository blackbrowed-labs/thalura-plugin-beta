# Adding a New Subject

This is the single entry-point for adding a new subject to Thalura. A subject touches several artifacts across the plugin; this guide lists all of them in order so a contributor can add a subject completely without reconciling steps scattered across other docs.

The detailed per-artifact specs live in their own reference files, cross-referenced below:

- `overlay-architecture.md` — method-overlay file format and rating scale, and the flat exam-format architecture.
- `regulation-naming.md` — regulation-PDF filename patterns and `shared/{id}/` vs `{school_type}/{id}/` placement.
- `document-registry.md` — which PDFs load for a given `(subject, grade, school_type)`.

Once the plugin-side artifacts below exist and the subject is selectable, a teacher adds it during setup or via `/thalura:config profile`, and the teacher-side workspace folders are created automatically (see "Runtime scaffolding" at the end).

## The 6 artifact classes

Add these in order.

### 1. `subjects.json` entry

Add an entry to `${CLAUDE_PLUGIN_ROOT}/references/subjects.json`:

- `id` — the English subject ID (e.g. `"psychology"`). This is the option value and the key used to resolve everything else.
- `abbreviation` — variable length is fine (the `"Psy"` precedent shows a multi-letter abbreviation).
- `has_overlay` — `true` when the subject ships method overlays (it normally does).

This file is the source of truth for **which** subjects exist; the setup and profile subject lists read it directly, so a new entry appears automatically with no skill edit. The human-readable label is **not** stored here — it is resolved from `localization.json` (next).

### 2. `localization.json` entries

Add display labels to `${CLAUDE_PLUGIN_ROOT}/references/localization.json`:

- `de.subjects.{id}` — the German label (e.g. `"Psychologie"`).
- `en.subjects.{id}` — the English label (e.g. `"Psychology"`).

Both are required: the label renders the subject in the setup and profile selection lists and becomes the localized output-folder name.

### 3. Method overlays (9 files)

Create one method overlay per core category under `${CLAUDE_PLUGIN_ROOT}/references/methods/overlays/{id}/`:

```
activation.md
cooperative.md
creative-performative.md
discussion.md
media-analysis.md
self-directed.md
text-analysis.md
thinking-dilemma.md
writing.md
```

Use the overlay file format and rating scale documented in `overlay-architecture.md`, including the "not rated" handling for methods a subject does not rate. No core method files need editing — the merge discovers the overlay directory for the subject by reading it at runtime.

### 4. Exam-format subject notes

For each relevant exam-format file under `${CLAUDE_PLUGIN_ROOT}/references/exam-formats/{format}.md`, add a `### {Subject}` subsection under the file's `## Subject-Specific Notes` section. The exam-format architecture is flat (one file per format); notes are discovered when reading the `## Subject-Specific Notes` section. See `overlay-architecture.md` for the exam-format structure.

### 5. Regulation PDFs

Create the regulation directories and place the bundled PDFs:

- `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/shared/{id}/` — for Sek II documents and any Sek I curriculum standards (Bildungsplan) that are shared across school types.
- `${CLAUDE_PLUGIN_ROOT}/regulations/{federal_state}/{school_type}/{id}/` — only where the subject has school-type-specific Sek I curriculum standards (Bildungsplan).

Filenames follow the patterns in `regulation-naming.md` (English subject IDs). Note the Psychology precedent: a subject whose Sek I curriculum standards (Bildungsplan) are identical across school types lives **only** in `shared/{id}/` and has no `{school_type}/{id}/` directory.

### 6. `document-registry.md` routing rows

Add the subject's routing rows to `document-registry.md`:

- the **Layer 3** (subject-specific curriculum) block for the subject;
- **Layer 4** (operators) rows where the subject has its own operator list;
- **Layer 5** (A-Hefte / Schwerpunktthemen) rows where applicable.

The registry is the runtime's authority for which PDFs load for a given `(subject, grade, school_type)`, so a subject is not fully wired until its rows are present.

## Runtime scaffolding (automatic once selectable)

A contributor adds the 6 plugin-side artifacts above. The teacher-side workspace folders follow automatically: once the subject is selectable and a teacher adds it (during setup or via `/thalura:config profile`), Thalura creates, only if missing:

- the localized output folder `<WORKSPACE_ROOT>/{localized_subject_name}/{school_year}/` (name from `localization.json`);
- the school-internal curriculum (Schulinternes Curriculum) folder `<WORKSPACE_ROOT>/data/regulations/sic/{subject_id}/`;
- the library skeleton `<WORKSPACE_ROOT>/data/library/{subject_id}.json` (shape `{ "subject": "{subject_id}", "units": [] }` — see `schemas/library-subject.md`).

No contributor action is needed for these — they are created by the setup and profile-add flows.
