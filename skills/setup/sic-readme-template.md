# Thalura — SiC Folder README Template (setup satellite)

The English source template for the README written to `<WORKSPACE_ROOT>/data/regulations/sic/README.md`. Loaded on demand by its two consumers — the setup skill (§6.8, new workspaces) and the scaffold-completion routine (existing workspaces, seeded when the file is missing) — never always-loaded.

Contract, shared by both consumers:

- The written file content must be in the teacher's `conversation_language` (default `"de"` when the profile is missing or the field is absent). The template below is English — translate at runtime.
- If `<WORKSPACE_ROOT>/data/regulations/sic/README.md` already exists — whatever its content — **skip** (never overwrite; existence check only, no content compare).

```markdown
# School-Internal Curriculum (Schulinternes Curriculum)

Place your school-internal curriculum PDF files in the subject subdirectories below.

## Expected format
- **File type:** PDF
- **File names:** Any name is accepted — Thalura scans for all `.pdf` files in each folder
- **One folder per subject:** Place files in the matching subject folder

## How Thalura uses these files
- The school-internal curriculum (Schulinternes Curriculum) enriches the official curriculum standards (Bildungsplan) with your school's topic sequencing and emphasis
- It informs unit planning (topic order, competency focus) but does not override regulatory compliance
- For S3/S4 courses, Abitur focus topics (Schwerpunktthemen) take precedence over the school-internal curriculum where conflicts exist
- If no school-internal curriculum is present, Thalura uses the curriculum standards (Bildungsplan) directly — it is optional
```
