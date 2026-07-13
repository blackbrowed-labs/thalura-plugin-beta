# Thalura — Data Folder README Template (setup satellite)

The English source template for the protective README written to `<WORKSPACE_ROOT>/data/README.md`. Loaded on demand by its two consumers — the setup skill (§6.9, new workspaces) and the core startup version-migration step (existing workspaces, seeded on a version change) — never always-loaded.

Contract, shared by both consumers:

- The written file content must be in the teacher's `conversation_language` (default `"de"` when the profile is missing or the field is absent). The template below is English — translate at runtime.
- If `<WORKSPACE_ROOT>/data/README.md` already exists — whatever its content — **skip** (never overwrite; existence check only, no content compare).

```markdown
# This folder is managed by Thalura

Thalura keeps its internal working data here: your profile and settings, your
planning state, and regulation files. Please do not change, rename, move, or
delete anything in this folder — Thalura may otherwise no longer find its data.
In the worst case it will look as if Thalura had never been set up.

## The two places where you add files yourself

There are exactly two spots in this folder where Thalura will ask you to place
files:

1. **Your school logo** — into the `assets` folder (it appears once you set up
   branding).
2. **Your school-internal curriculum (Schulinternes Curriculum), as PDF files** —
   into `regulations` → `sic` → the folder for your subject. You can add or
   update these PDFs at any time.

Everything else in this folder is managed automatically.

## Your documents live elsewhere

Everything you actually work with — unit plans, lessons, materials,
assessments — is stored in your subject folders next to this `data` folder.
Nothing you need day to day is in here.
```
