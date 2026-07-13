---
name: backup-restore
description: Use when the teacher wants to back up their whole workspace to a file (eine Sicherung/ein Backup des Workspace erstellen) or restore their workspace from a backup file (eine Sicherung wiederherstellen) — for moving to a new computer or recovering after a loss. Backup packs the teacher's irreplaceable work (year plans, classes, library (Bibliothek), generated documents, in-progress drafts (Entwürfe)) into one file, leaving student submissions (Abgaben) and regenerable data behind; restore brings a backup back safely.
when_to_use: |
  DE + EN: "Backup erstellen", "eine Sicherung von allem machen", "meine Daten sichern", "alles sichern bevor ich den Rechner wechsle", "Backup vom Workspace", "auf einen neuen Rechner umziehen", "back up my workspace", "make a backup", "save all my data"; and for restore "Backup wiederherstellen", "meine Daten zurückholen", "die Sicherung einspielen", "auf dem neuen Rechner wiederherstellen", "restore my backup", "restore from a file", "restore my workspace". DISAMBIGUATION: "Sicherung" reads as a workspace backup ONLY in a data/file context — with "Daten", "Datei", "Backup", "Workspace", "Rechner" or the English "backup". A bare "Sicherung" inside a lesson-planning request (e.g. "gib mir eine Sicherung für die Stunde") is the lesson consolidation phase (Sicherung), NOT this skill — when genuinely ambiguous, ask. Whole-workspace "wiederherstellen" (Backup / Daten / den ganzen Workspace) → restore (this skill); "eine archivierte Einheit wiederherstellen" → the library restore flow; "eine Einheit aus der Bibliothek übernehmen" → assign-unit; a colleague's single-unit file → import (unit-exchange). When both readings of a bare "wiederherstellen" are live (whole workspace vs. a single archived unit), ask. Restore into a workspace that is not yet set up either initializes it directly from a full workspace backup (conditions apply) or hands off to setup first.
---

# /thalura:backup-restore — Backup & Restore (Sicherung & Wiederherstellung)

> Core protocols — startup, workspace-root resolution, profile load, HiTL/draft lifecycle, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).

This task moves the teacher's **whole workspace** as a single portable **backup file (Sicherung)** — the disaster-recovery / new-computer migration flow. Two flows:

- **back up a workspace (eine Sicherung erstellen)** — pack the teacher's curated, irreplaceable workspace state into one backup file (Sicherung) and deliver it to their Thalura folder.
- **restore a workspace (eine Sicherung wiederherstellen)** — take in a backup file and restore it **safely-by-default**: a clean full restore into an empty/fresh workspace, an additive library (Bibliothek)-only merge into a populated one, and a refusal to overwrite a non-empty workspace.

The backup file rides the shared envelope defined in `${CLAUDE_PLUGIN_ROOT}/references/schemas/bundle-manifest.md` with `bundle_kind: "workspace"` — the `workspace`-profile body (scope descriptor + semantic inventory + data-tier version stamp) is defined there and is the normative format; this skill implements the pack, deliver, peek, screen, and land steps on top of it.

**Presentation rule (both flows):** interact in `conversation_language`; present **prose previews, never raw `data/` JSON** — never show the teacher a manifest or an entry as raw JSON, always describe it in prose. The teacher never types a path or an identifier. The backup file is never described as a tar or zip archive — it is simply the teacher's backup file (Sicherung). And because it is a **binary bundle, not a human-readable document**, its delivery is confirmed **in prose only**: name the exact file name and where it lies („liegt als `thalura-backup-{YYYY-MM-DD}.thalurabackup` in deinem Thalura-Ordner"), plus the next step — the file itself is **never attached or opened for inline preview** (a rendered preview of binary content is pure noise and buries the actual confirmation). This prose-only delivery applies to **every binary bundle artifact** — a backup file (Sicherung), a unit file, or any future binary format; human-readable deliverables (documents, slides, PDFs) keep their normal presentation.

**Transport discipline (both flows, gate-defined — the mechanism is chosen at runtime and verified, never named here):** stage session-local, copy once, hash-verify after the copy, sweep for stray temporary artifacts; on inbound peek the manifest first, list members before extracting, screen every member path, extract into an isolated session-local area bounded by `contents[]`, and verify each member before it lands. Whatever context does the packing or unpacking must actually be able to read and write both the workspace folder and the session-local working area — verify that before relying on it, and flag it rather than proceeding if it cannot.

---

## back up a workspace (eine Sicherung erstellen)

**Trigger examples:** "Backup erstellen", "eine Sicherung von allem machen", "meine Daten sichern", "alles sichern bevor ich den Rechner wechsle", "back up my workspace", "make a backup".

The curated scope is a **differential**: only teacher-authored and irreplaceable content is packed; reinstall-recoverable shipped files, regenerable caches, and transient scratch are left out. The flow and its gates:

### 1. Scope choice (G-B1)

**Data is always included.** Offer the **library (Bibliothek)** and the generated **outputs** (documents) as opt-outs for a smaller file, in prose ("Soll die Bibliothek und sollen die erzeugten Dokumente mitgesichert werden? Ohne sie wird die Datei kleiner."). Record the chosen `scopes[]`.

- **Opt-out referential-closure warning:** if the teacher opts **out** of Outputs or Library while keeping Data, warn that restoring the smaller backup may leave dangling references (a plan's `output_path` pointing nowhere, a `library_ref` pointing nowhere) — the restore-side cross-reference pass reports them; the backup never silently produces an un-restorable set.

The curated scope, enumerated so backup and restore agree by construction:

**INCLUDE — teacher-authored + irreplaceable state:**

| Scope | Location | Why |
|---|---|---|
| School years | `<WORKSPACE_ROOT>/data/school-years/` (`plan.json` + `classes/*.json`) | Year plans, class definitions, reflections — irreplaceable. |
| Output folders | the generated documents under the subject output roots (below), **including the material-overview document, the per-unit `plan.json`, and in-progress draft (`_ENTWURF`) files** | The actual teaching artifacts — the point of the tool. Restore has **no** regeneration step, so the material-overview travels; the per-unit `plan.json` is the restore integrity pass's anchor; draft (`_ENTWURF`) work is exactly the irreplaceable content a disaster-recovery backup must not strip. Validated-material PDF siblings are among the generated documents swept in — a `.pdf` is a teaching artifact (Unterrichtsmaterial), not a draft, not a student submission (Abgabe), and not a cache entry, so it is included in the backup and landed normally on restore. |
| Library | `<WORKSPACE_ROOT>/data/library/` (entries + `materials/{unit_id}/`) | Shelved/imported reusable units — irreplaceable. |
| Profiles | `<WORKSPACE_ROOT>/data/profiles/` | Identity, school setup, learned preferences — irreplaceable; carries the `school_id`. |
| Config | `<WORKSPACE_ROOT>/data/config/` (the **whole `config/` directory** — currently the naming overrides, plus any future teacher-customized config file) | The teacher's naming and config overrides — irreplaceable if diverged; the whole directory is taken so a future config file is not silently dropped. |
| Assets | `<WORKSPACE_ROOT>/data/assets/` (teacher-placed branding logos) | Placed by the teacher; no fallback logo ships. |
| School-internal curriculum | `<WORKSPACE_ROOT>/data/regulations/sic/` (the whole `sic/` tree) | Teacher-authored, not shipped. |
| Version stamp | `<WORKSPACE_ROOT>/data/version.json` | Drives the restore version bridge (reverse-skew detection + the forward migrate-on-startup path). Tiny, load-bearing. |
| Year overview | `<WORKSPACE_ROOT>/Schuljahresübersicht *.docx` (workspace root, resolved from `documents.year_overview` for any school year) | The teacher's printable whole-year index — outside every subject root and outside `data/`, so the existing sweep never touches it. Restore has **no** regeneration step, so the year overview travels and lands verbatim; frozen past-year files ride along too. |

**EXCLUDE — regenerable / transient / plugin-shipped / privacy:**

| Scope | Location | Principle |
|---|---|---|
| Citation digest cache | `<WORKSPACE_ROOT>/data/.cache/` | Regenerable — re-derived on next read; never back up what the plugin can regenerate. |
| Residual render scratch | any residual `.render/` | Transient scratch — never teacher data. |
| Student submissions | the localized submissions folder (below) | Student submissions never leave the local machine — the one hard privacy rule. |
| Protective data README | `<WORKSPACE_ROOT>/data/README.md` | Regenerable — re-seeded by the scaffold-completion step on restore; carries no teacher content. |
| Shipped regulation PDFs | `${CLAUDE_PLUGIN_ROOT}/regulations/{state}/` | Re-provisioned on install; a reinstall restores them for free. (Contrast `sic/`, included because teacher-authored.) |
| Other shipped files | `${CLAUDE_PLUGIN_ROOT}/references/`, `${CLAUDE_PLUGIN_ROOT}/templates/`, `${CLAUDE_PLUGIN_ROOT}/config-defaults/`, `${CLAUDE_PLUGIN_ROOT}/skills/` | Plugin bundle — reinstall-recoverable. |

**Output-root enumeration (never bare root introspection).** The set of output-folder roots to pack is enumerated **only** from workspace-authoritative sources — **never** by listing whatever directories sit at `<WORKSPACE_ROOT>/`:

- **Subject sweep.** For each subject in the teacher's profile, resolve **every language's** localized subject folder name from `${CLAUDE_PLUGIN_ROOT}/references/localization.json`'s per-language `subjects` map (`english` → `Englisch` for `de`, `English` for `en`, …) — the all-language sweep, because a workspace that once ran in German then switched to English may hold both `Englisch/` and `English/` trees. A subject root is included iff it exists.
- **Plan cross-reference.** Union in every `<WORKSPACE_ROOT>/data/school-years/*/plan.json` `plans[].units[].output_path` — the authoritative record of where each unit's documents live; the closure basis for the restore integrity pass.
- **Year-overview pattern.** The `documents.year_overview` pattern (resolved for every school year in `<WORKSPACE_ROOT>/data/school-years/`) is included by name as an explicit, enumerated addition — `<WORKSPACE_ROOT>/Schuljahresübersicht *.docx` (or the locale's equivalent, resolved from `naming_labels.year_overview` + the plan's `school_year`), **not** bare root introspection; a stray root folder is still never swept.
- **Never bare root-directory introspection.** Enumeration is `profile subjects × all-language localized subject names ∪ plan.json output_paths`, **never** "pack every folder under `<WORKSPACE_ROOT>/`". A teacher's unrelated personal folder, a downloaded backup file in the drop directory, or a stray non-Thalura directory is **never** swept into a backup. The same enumeration drives the restore empty-gate, so pack-scope and empty-detection agree.

### 2. Preview (G-B2 — human prose, never `data/` JSON)

Summarise what will be backed up from the semantic inventory, in prose: "Data (3 classes, 2 school-year plans), Library (12 units), Outputs (English, Philosophy) — student submissions (Abgaben) are never included." Confirm before packing.

### 3. Build the workspace body (G-B3)

Walk the curated scope and build:

- `contents[]` — one `{ path, sha256, bytes }` object per payload file (the integrity + audit list).
- the `workspace` body: `data_version` = the workspace `version.json`'s plugin version; `scopes[]`; `inventory` from the school-year plans and library indices; `counts`.
- **`inventory` is built from semantic stamps, never filesystem mtime.** Each unit's `updated_at` is the source entry's own last-modified timestamp (falling back to its creation timestamp when never modified) — **never** a filesystem modification time, because on a disaster-recovery clone every file's mtime is set at copy time and a mtime-based freshness check would be a coin flip on exactly those machines.
- **Subject-segment canonicalisation.** In the payload the subject segment is stored as its **canonical id** (`outputs/english/…`, never the localized `outputs/Englisch/…`); the document subfolders (`lessons`/`materials`/`assessments`) are stored under their **canonical keys**; both are re-localized into the target workspace's language on restore. Document **filenames** travel as-authored (the own-class prefix is correct — a whole-workspace backup restores to the same teacher's same classes).

### 4. Exclusions are hard gates (G-B4)

Before staging, assert the curated exclusions: **no** `.cache/`, **no** `.render/`, **no** `README.md`, and — the privacy gate — **no** submissions folder at any depth.

- **Submissions exclusion (hard, localized).** Resolve the submissions folder name from the **source workspace's `conversation_language`** via `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `folder_names.submissions`, and exclude that folder **at any depth** inside the assessments folder (flat or numbered-subfolder layouts alike). As a belt-and-suspenders sweep, also exclude any folder matching **any** language's `folder_names.submissions` value. **Never a hardcoded lowercase submissions folder name.** The absence is auditable from the manifest `contents[]` — no path under it names a submissions folder.
- If a submissions folder or a `.cache/` entry reaches the staging list, **remove it and re-verify** — never stage a gate-failing tree.

### 5. Stage session-local, copy once (G-B5)

Build the backup file in a **session-local / non-connected-folder** scratch area — never on the workspace folder (a direct archive write onto the mount fails). Then **copy it once** into the connected-folder root as `thalura-backup-{YYYY-MM-DD}.thalurabackup` (`thalura-backup` is a literal, unlocalized stem; the extension is brand-fixed). **Never overwrite an existing file:** if that name is already taken, choose a fresh numbered name (`thalura-backup-{YYYY-MM-DD}-2.thalurabackup`, counting up) — collision avoidance happens **before** the copy.

### 6. Post-copy verify + stray-temp sweep (G-B6)

After the copy, **post-copy hash-verify** that the delivered backup file matches the staged one (the whole-file digest), and **stray-temp sweep** the destination folder for orphaned temporary artifacts of the copy-across-mount. If a stray remains and cannot be removed from the session, tell the teacher its exact name and that it is safe to delete manually — never claim a clean delivery over a stray.

### 7. Confirm in prose (G-B7)

Tell the teacher, in prose: what was backed up, what was excluded and why (submissions/Abgaben and regenerable caches stay local, the plugin itself is re-installed rather than backed up), the final filename and its location in their Thalura folder, and the size. Per the presentation rule, this confirmation is the **entire** hand-off: never attach or open the delivered backup file (Sicherung) for inline preview — naming the exact file and its location *is* the delivery.

### Backup failure modes

| Failure | Behaviour |
|---|---|
| Staging scratch unwritable | Escalate to another session-local location; else flag — never build on the mount. |
| Archive-onto-mount write fails | The copy-once path *is* the recovery; never build on the mount. |
| Post-copy hash mismatch | Re-copy and re-verify; else flag "delivery may be corrupt — do not rely on it". |
| Stray temporary artifact un-removable | Name it to the teacher; safe to delete manually. |

---

## restore a workspace (eine Sicherung wiederherstellen)

**Trigger examples:** "Backup wiederherstellen", "meine Daten zurückholen", "auf dem neuen Rechner wiederherstellen", "restore my backup", "restore from a file".

Restore is **safe-by-default**: peek the manifest, verify the whole payload in staging, then land it into an **empty/fresh** workspace or **additively** merge only the library into a populated one — and **refuse** a full-scope overwrite of a non-empty workspace. **Precondition (two paths):** the workspace must **resolve**, **or** the **direct-initialization conditions** (the „Direct initialization of an empty, unresolvable target (G-RS11)" section below) must all hold. When workspace resolution reports that setup is needed, restore does **not** dead-end: if the direct-init conditions hold, restore initializes the workspace **directly from the backup** (that branch); **in every other unresolvable case** — a scoped bundle without the data scope, a target folder that is neither truly empty nor same-bundle resume-equivalent, or a failed staging verification — it explains that a workspace must be set up first and hands off to the `setup` flow, then the teacher re-runs restore into the freshly-set-up (empty) workspace. Because restore will overwrite setup's class definitions with the backup's authoritative copies, that handoff **tells the teacher they may skip setup's optional class question** — the backup brings the classes — so they do not re-enter class data restore is about to replace. An ambiguous-workspace signal routes to the existing interactive workspace choice.

### 1. Locate the backup file (G-RS0)

Two first-class inbound paths:

- **Chat upload:** the attached file materializes as a real file in the session; use it where it landed.
- **Folder placement:** the teacher placed the file in their Thalura folder; locate it at the workspace root. When several candidate files are present, ask which one — list them by filename, size, and modification date, in prose.

List-before-act: never extract blindly. The inbound file is never deleted or renamed by restore; after a successful restore, tell the teacher the file can be deleted manually.

### 2. List-before-extract + isolated staging (G-RS1)

Extract to an **isolated session-local staging area** — never straight into the workspace. **List the members before extracting**, apply a **path-traversal screen** (reject any `contents[]` path with an absolute path or `..` segments, or that escapes `payload/`) and an executable/non-regular-file screen. Read `manifest.json` **first**.

### 3. `bundle_kind` routing (G-RS2 — detection trusts the manifest, not the extension)

Require `bundle_kind: "workspace"`. A single-unit file (`bundle_kind: "unit"`) renamed to look like a backup is **refused with a prose redirect** ("This is a single-unit file — use *assign a unit from the library* / import, not restore"), never mis-restored. A missing or garbled manifest → refuse ("this is not a readable Thalura backup").

### 4. Full staging integrity + defense-in-depth screen (G-RS2b — all in staging, before the first workspace write)

- **Member-complete + per-member integrity.** Every `contents[]` entry must exist as an archive member whose `sha256` **and** byte size match its declaration. A **listed member that is absent** → **refuse the whole restore** ("the backup appears damaged — do not rely on it") **before any workspace file is written**; never land a partially-verified workspace.
- **Unlisted extras tolerated, never landed.** An archive member **not** declared in `contents[]` is tolerated (forward-compatibility) but **never extracted into the workspace** — reported in prose (what was present and ignored).
- **All-before-any.** The complete `contents[]` set is verified in staging **first**; only once every member passes does the first workspace write happen. This makes restore atomic-at-decision: it either commits to a fully-verified payload or refuses without touching the workspace.
- **Defense-in-depth restore screen.** Even though a conformant backup never packs them, re-screen the verified set and **skip-and-report** (never land) any member that sits in a **submissions folder** (any language's `folder_names.submissions`, at any depth) or under **`.cache/`** — a crafted or hand-assembled backup carrying a colleague's students' submissions or a bloated cache must never write them into this workspace. **Screen only those two classes:** draft (`_ENTWURF`) files and per-unit `plan.json` **legitimately belong** in a workspace payload and are **landed normally** — the restore screen is narrower than a unit import's screen precisely because this is the teacher's *own* whole-workspace image, not a cross-workspace import. Skipped members are **reported in prose** (what was skipped and why Thalura never restores it) — a screen, not a silent drop.

### 4b. Direct initialization of an empty, unresolvable target (G-RS11 — sits between the staging-integrity gate and the empty-gate; taken before the empty-gate when the workspace does not resolve)

When workspace resolution reports **setup-needed**, restore does **not** automatically hand off to setup. It first tests the **direct-init conditions**: a full, fully-verified workspace backup landed into a truly-empty folder may **initialize the workspace directly from the backup**, skipping the setup interview it would immediately overwrite. This gate is evaluated **only** on an unresolvable workspace, **after** the staging-integrity gate (§4) has passed and **before** the empty-gate (§5) — which is reached only on a workspace that *does* resolve.

**The three conditions (ALL must hold; any miss → the setup handoff verbatim, per the precondition fallback above):**

- **C1 — bundle.** The manifest declares `bundle_kind: "workspace"` **and** its `scopes[]` includes the **data** scope (the profile-bearing scope — the payload carries `profiles/`, the whole `config/`, and `version.json` in authoritative form). A library-only or outputs-only workspace bundle does **not** qualify.
- **C2 — target.** The resolver reports setup-needed **and** the designated target folder is **truly empty** — it contains **no entries at all** other than the inbound backup file itself and `.DS_Store`-class system junk — **or** it is **same-bundle resume-equivalent**: every other entry is a path-coinciding file whose content hash-matches a member of the **same verified bundle** (the member's recorded `contents[]` digest, **or** the digest of its deterministic recorded-ref rewrite — the identical two-byte-image equivalence the idempotent-resume step (§6) defines, all computable in staging). Any entry that matches **neither** byte-image fails C2 — a folder with unknown content is not a zero-overwrite-surface target → the setup handoff verbatim. The resume-equivalence arm exists for one reason: a direct-init interrupted **before** `teacher-profile.json` lands leaves a target that is non-empty *and* still unresolvable (the resolver keys on the profile marker), and this arm is the **pre-profile window's** convergence path — without it the re-run would fall through to the verbatim setup handoff and re-import exactly the redundant setup interview the direct-init branch exists to avoid.
- **C3 — verification.** The full staging verification has passed **before the first workspace write** — G-RS1 (list-before-extract, isolated staging), G-RS2 (`bundle_kind` routing), G-RS2b (member-complete, per-member sha256 + size, all-before-any, defense-in-depth screen) **and** the G-RS8 version bridge (reverse skew still **blocks**; direct-init never bypasses the bridge — with no workspace `version.json` yet, the bridge compares the manifest's stamps against the installed plugin version, exactly as it does anyway).

**Target designation (C2's "designated folder").** Folder placement → the folder holding the backup file. Chat upload → when exactly one plausible workspace folder exists, that one; when several exist, **ask** the teacher which folder should become the workspace — never guess (the existing ambiguous-workspace discipline). In Claude Code the designated folder is the session's working directory.

**Confirm in prose before the first write.** Direct-init writes into the workspace without a scaffold to name (G-RS6's named-class confirmation cannot apply — there is nothing yet to overwrite), so consent is a plain prose confirmation in `conversation_language` (skill prose here is English; the German string is the runtime example, translated at runtime): *„Dein Ordner ist leer und noch nicht eingerichtet. Die Sicherung enthält deinen kompletten Arbeitsbereich — ich kann ihn direkt daraus aufbauen; die Ersteinrichtung ist dann nicht nötig. Fortfahren?"*

**Landing is identical to the clean restore.** When C1–C3 hold and the teacher confirms, land the payload **exactly per the clean full restore contract (§9)** — same fixed landing order, the same re-localization and recorded-ref rewrite (G-RS6c), the same `school_id` no-re-mint (G-RS7), the same honest-partial reporting (G-RS6a). Direct-init changes **when** the clean restore may run (on an unresolvable, truly-empty target), never **how** it lands. Then run the scaffold-completion step (G-RS12, §9 sub-step 6) — mandatory, before the integrity pass — followed by the integrity pass (§11) and the prose summary (§12).

**Interruption coverage is two-windowed.** An interruption **after** the profile marker lands leaves a workspace that now *resolves* — the re-run takes the normal restore entry and converges via the same-bundle hash-matched resume (§6) as today. An interruption **before** the marker lands leaves an unresolvable, non-empty target — the re-run converges via **C2's same-bundle resume-equivalence arm** above. **Neither window reaches the setup interview.**

### 5. Determine the target state — what "empty" means (G-RS3)

**"Empty/fresh"** is a predicate over teacher-authored **unit content**, not over the mere existence of a set-up workspace. A workspace is **empty** iff it has **no unit content across every restore-collision surface**: **zero** unit entries in every `plan.json` `plans[].units[]`, **zero** entries in every `<WORKSPACE_ROOT>/data/library/*.json` `units[]`, and **no** output folder present under any subject root — where the subject roots are the **same enumeration** the backup packs against (profile subjects × all-language localized names ∪ `plan.json` output_paths), **never** a bare listing of `<WORKSPACE_ROOT>/`.

- **System junk and setup scaffold do not make a workspace non-empty.** `.DS_Store`, a residual `.cache/`/`.render/`, the setup-scaffolded profiles / config / `version.json` / `README.md`, the empty library index skeletons, the scaffolded `classes/` directory, **and the class definitions the teacher entered during setup** are all **replaceable scaffold** — not irreplaceable unit work. The north-star flow (install → setup → restore) necessarily creates profiles and, for any teacher who answers setup's optional class question, class definitions before restore runs; counting them as blocking content would dead-end exactly those teachers. So they do **not** block — the named, content-aware confirmation below is the operative safeguard.
- **What restore does to the scaffold — the real semantics.** Restore is **per-path content-overwrite + union**, **never** tree replacement: it lands the backup's files at their paths, overwriting any file that path-coincides and leaving every other file untouched. A path present in the workspace but **not** in the backup **survives** — e.g. a fresh next-year classes tree the teacher created after the backup is not removed by restoring an older backup. This is safer than a replace-the-tree model (it can never silently delete), which is why the empty-gate can key on the narrow irreplaceable-unit surface.

**Empty → clean full restore (G-RS6).** The setup-scaffolded profiles / config / `version.json` / class definitions are **content-overwritten** by the backup's authoritative copies; a **single prose confirmation names the concrete class definitions** being overwritten (the path-coinciding set) and **flags any whose current content differs from the backup's copy**, so consent is informed rather than a bare count: *"Your workspace was just set up. This backup restores a full workspace and will overwrite these class definitions with the backup's versions: E10a, PS4, R9c. Note: your current E10a differs from the backup's (it has a special-needs entry the backup lacks — the backup's version wins). Your profile is also replaced. Continue?"*

**Non-empty → the safe-alternatives branch (below).** If **any** unit / library / output content exists, restore does **not** attempt a full overwrite.

### 6. Same-bundle hash-matched idempotent resume (G-RS6b — sits between the empty-gate and the non-empty guard)

The gate order is exactly: **empty? → clean restore** (§ above) / **non-empty? → [same-bundle + hash-matched? → resume-converge] → [else → the non-empty safe-alternatives guard]**. A **non-empty** verdict is tested for same-bundle hash-matched convergence **first**, and **only when that test fails** does the flow reach the safe-alternatives guard.

- **Idempotent resume — same-bundle, hash-matched only.** A re-run of restore **from the same backup file** treats an existing workspace file whose content **hash-matches that member's `contents[]` sha256** as **already-restored** (skip, or content-overwrite with the identical bytes), so the re-run **converges** instead of deadlocking on the empty-gate (a partial write already made the workspace "non-empty", which would otherwise send the re-run to the guard). **Scope is deliberately tight:** the resume path applies **only** when (a) the re-run is against the **same bundle** (same manifest identity) **and** (b) each target **hash-matches** the backup's per-member digest. It is **never** a general non-empty overwrite: a file whose content does **not** hash-match is a *different* file → the resume does not touch it, and the flow **falls back to the non-empty guard**. This keeps the non-empty-overwrite lock intact — resume is content-identical convergence of an interrupted *same-bundle* restore, not conflict resolution across differing content.
- **Cross-locale rewrite interaction — the resume-equivalence accepts the rewritten byte-image too.** A cross-locale-rewritten `plan.json` (§9 sub-step 5) **no longer hash-matches** its archive member, because the recorded-ref rewrite deliberately edited its bytes *after* it landed. So the same-bundle resume-equivalence counts a path-coinciding landed `plan.json` as already-restored when its content matches **either** the member's recorded `contents[]` digest **or** the digest of the deterministic recorded-ref rewrite applied to that member (both computable in staging from the member plus the localization maps). **Exactly these two byte-images qualify** — any other content still falls back to the non-empty guard, so the equivalence stays same-bundle-tight and the non-empty-overwrite lock is intact.

### 7. Non-empty target — safe alternatives, refuse full overwrite (G-RS4)

Restore peeks the manifest, detects existing teacher content via the **semantic** inventory (compared against the target's inventory — semantic stamps, **never filesystem mtime**), and **stops with a prose guard + safe alternatives**:

> *"This backup is a full workspace, but your current workspace already has units, classes and outputs. Restoring the whole backup over them would replace your files — Thalura can't do that safely yet. Options: (1) restore only the **library (Bibliothek)** units (added alongside what you have, nothing replaced), or (2) restore the full backup into a **fresh** workspace on a new/empty setup. Which would you like?"*

- **Non-empty full overwrite is refused** — restore **never** silently overwrites teacher data; the guard is a hard stop, not a warned proceed.
- **Option (2) — fresh-workspace restore.** Guide the teacher to restore into a new/empty setup (a new computer, or a fresh workspace) — the clean path.
- **The library-only-content trap (explicit re-order guidance, not a silent special-case).** A near-fresh workspace whose *only* content is one or two units imported into the library (an assign/import before restore) is technically **non-empty** (the library entries trip the empty-gate), so a full restore lands in this guard rather than the clean path. Restore **does not silently treat this as empty**. Instead it names the situation and gives explicit re-order guidance: *"Your workspace only has a few imported library units and no other work. For a clean full restore, the tidiest path is to restore into a fresh setup and re-import those units afterward — or I can add just this backup's library units to what you have now (nothing replaced)."* The teacher chooses; the flow never guesses.

### 8. Library-additive restore (G-RS5)

Option (1) restores **only** the `library` scope. Because the library is year-independent and append-only by nature (each unit a self-contained `materials/{unit_id}/` keyed by a unique `unit_id`), the merge is purely **additive**: **new `unit_id`s are added, existing ones untouched**. A `unit_id` **collision** (same id already present) is the *same* frozen unit by construction (materials immutable) → **skip-or-report, never clobber**. No existing teacher data is ever replaced. The cross-reference integrity pass runs scoped to the merged entries. Prose: *"This backup has 12 library units; 9 are new, 3 you already have. I'll add the 9 new ones — nothing you have is touched. Continue?"*

### 9. Clean full restore into an empty workspace (G-RS6) + `school_id` no-re-mint

Once the empty-gate, the full staging integrity + screen, and the version bridge pass:

1. **Re-localize + write, in a defined landing order.** Copy the fully-verified staged payload into the workspace. **Landing order (fixed):** the `data/` scope first (profiles → config → school-years → library → assets → sic → `version.json`), then the `outputs/` scope, so that if the write is interrupted the referential anchors (`plan.json`, class defs, library indices) land before the documents that reference them. Map the payload's **canonical subject segment → the target workspace's localized subject folder** and its **canonical subfolder keys → the target workspace's `conversation_language`** folder names for the output tree; `<WORKSPACE_ROOT>/data/library/materials/` snapshots keep canonical keys. Document **filenames** land as-authored (own-class prefixes are correct). A workspace-root year-overview `.docx` lands verbatim, with **no** regeneration step, exactly as the material overview does; a cross-locale restore may leave its internals in the source locale until the next current-year content-mutating write regenerates it (accepted, symmetric with the material-overview precedent).
2. **Honest partial report — never a success claim (G-RS6a).** If a write fails partway (mount hiccup, disk-full, unremovable target), restore **stops and reports the exact partial state in prose** — which scopes landed, which did not, and that the workspace is **incompletely restored** — and **never** declares success. It names the residual so the teacher can re-run (the same-bundle resume converges the re-run).
3. **Replace scaffold (confirmed above).** The backup's `profiles/`, whole `config/` directory, `version.json`, `school-years/` (incl. `classes/`), `assets/`, and the `sic/` curriculum tree content-overwrite the path-coinciding setup scaffold (per-path overwrite + union — non-coinciding workspace files survive).
4. **`school_id` no-re-mint (G-RS7 — hard).** The restored school-config file and the `school_id` reference in the teacher profile are landed **verbatim from the backup** — restore **never regenerates `school_id`**. `school_id` is minted at setup and is a stable school identity (enabling future multi-teacher sharing); the restored workspace is the *same* school migrating, so its original id must survive, and the freshly-set-up workspace's just-minted placeholder id is discarded with the rest of the scaffold. The generation-time verify gate does not apply (restore performs no generation); instead the integrity pass runs a **shape sanity-check** (`^[a-z0-9-]+-[0-9a-f]{4}$`) on the restored id as a corrupt-archive guard, and flags (never re-mints) a malformed one.

5. **Re-localize recorded refs on land (G-RS6c).** After the output tree is physically re-localized (sub-step 1) — and only ever on a landed file, never on a verified archive member — **restore rewrites the localized path segments recorded *inside* the landed `plan.json` files to the target language**, so a restored plan's recorded references match its own on-disk tree instead of the source workspace's folder names. Gate-defined:
   - **Source vs. target locale.** Source locale = the manifest's recorded `conversation_language` (the source-locale stamp the backup carries); target locale = the restore workspace's `conversation_language`. **Equal ⇒ the rewrite is a no-op — skip entirely** (the common single-locale case; verbatim landing holds, and nothing is touched).
   - **Order (fixed).** Staging integrity has already verified the archive members and the output tree has already been physically re-localized **before** this rewrite runs; the integrity pass (§11) then checks the **rewritten** refs. The rewrite therefore edits only landed files that are already on disk — the same class of post-verification transform the re-localized folder names themselves are — and never an archive member's verified bytes.
   - **Any-language reverse map.** Each localized segment is reversed to its canonical key by checking **every** language block of the localization reference (`${CLAUDE_PLUGIN_ROOT}/references/localization.json`'s per-language `subjects` and `folder_names` maps), not the source-locale block alone, then re-localized to the target language. This is unambiguous because each localized value maps to exactly one canonical key — a value shared across languages (e.g. `Religion`) maps to the *same* key, never two. It is therefore **idempotent**: an already-target-locale (or already-rewritten) segment reverses to its key and re-localizes to itself — a byte-stable no-op.
   - **School-year `plan.json` `output_path`s.** For every landed school-year `plan.json`, rewrite each `units[].output_path`'s **leading subject segment only** (any-language localized subject name → canonical id → target-language subject name, via `subjects`); leave `{school_year}/{class_id}/{Unit_slug}/` unchanged.
   - **Per-unit `plan.json` tracked-doc `path`s — the schema-complete set.** For each landed per-unit `plan.json`, rewrite the **leading document-subfolder segment only** (via `folder_names`) of **every** tracked-doc `path` the manifest defines: `unit_plan.path`, `material_overview.path`, `reflection.path`, each `lessons[].path`, each `materials[].path`, each `assessments[].path`, and each nested `assessments[].task.path` and `assessments[].rubric.path` — the assessment task and grading rubric (Erwartungshorizont) files carry the same localized assessment-subfolder prefix and must be rewritten too. A root-level path with no leading subfolder segment is left unchanged. **Filenames are never rewritten** — the recorded filename equals the landed filename (both travel as-authored), so only the leading subfolder segment is touched. There is no `documents[].path` field in a per-unit manifest, so nothing of that shape is rewritten.
   - **Runs on every converged restore — resume included.** The rewrite runs on **every** completing restore, the same-bundle hash-matched resume included: a restore interrupted *before* the rewrite (landed refs still verbatim) must still reach this step on the resumed run, or an interrupted-then-resumed cross-locale restore would ship source-locale refs. Safe to re-run because the transform is idempotent (above).
   - **Resume-time target-locale determination — recover from tree evidence, never from the overwritten profile.** The clean restore lands the backup's profile **over** the target's (the scaffold-replacement rule above), so an interrupted cross-locale restore leaves a workspace whose profile already reads the **source** language. A resumed run that naively re-read that profile for the target locale would conclude source == target, take the no-op fast path, skip the rewrite entirely, and ship source-locale refs — the same bug in resume form. The resumed run therefore **must not** take the target locale from a profile the interrupted run may already have overwritten: when the landed profile's `conversation_language` **equals** the manifest's source-language stamp, the target locale is recovered from the **evidence of the partially-restored workspace** — either an output-tree **subject folder** or a **document subfolder** (`subjects` / `folder_names`, any-language) spelled in a non-source language is the locale the interrupted run re-localized into (guard against cross-language same-spelling collisions by requiring a genuinely non-source spelling). The subfolder evidence widens the recovery beyond subject spelling alone: a workspace whose only subject is a cross-language same-spelling one (e.g. `Religion`, identical in both locales) still carries a re-localized document subfolder (`Lessons/` where the source would spell `Stunden/`), so its target locale stays recoverable. When **no** such evidence exists — a workspace with **no** re-localized folder of either kind (nothing has landed yet, or a genuine same-locale restore) — the profile value stands and the restore completes **self-consistently** in that language (profile, tree, and recorded refs all agree); should any recovered target still leave a ref whose folder/file is absent, the §11 integrity pass surfaces it (verify-then-flag), never a silent success.
   - **No other member's content is rewritten.** Everything else lands verbatim — profiles, the whole config, class definitions, library (Bibliothek) data, `version.json`; `<WORKSPACE_ROOT>/data/library/materials/` snapshots keep their canonical keys. This carves the minimum exception to verbatim landing the seam requires.
   - **Unknown segment — left verbatim, surfaced once (verify-then-flag).** A leading segment that matches **no** language's localized value in either map (a hand-edited or corrupt path, a subject the maps do not know) is **left unchanged** — never guessed, never dropped — and is surfaced **once** by the §11 integrity pass as a genuine unresolved reference (there is no separate rewrite-flag; the single integrity-pass line is the surfacing). Verify-then-flag: the integrity pass is the verification, and a rewritten ref whose target still does not exist is flagged in prose, never claimed as success.

6. **Scaffold completion (G-RS12).** Run the shared scaffold-completion routine (`${CLAUDE_PLUGIN_ROOT}/skills/setup/scaffold-completion.md`) so the restored workspace is **onboarding-equivalent** — every directory and starter file a fresh setup would have created is present, conditioned on the landed profile's own config (subjects, `conversation_language`, branding, present school years). It runs on **every completing full restore** — the direct-init branch **and** the standard restore-into-freshly-set-up path **and** a same-bundle resume that completes — because the standard path has the same hole in a subtler form: the backup's landed profile content-overwrites the setup-interview profile, so **the landed profile's subjects may not match the setup-interview scaffold** (setup with Philosophy only + a backup carrying English → `sic/english/` and the English library index are missing). **Library-additive restores are exempt** — they never change the profile, so the scaffold conditioning is unchanged. The routine's create-only writes and honestly-flagged residuals fold into the restore summary (§12, G-RS10). **Order (fixed):** this step runs **before the integrity pass (§11)**, so the pass validates the **final** tree; the integrity pass itself gains no new check classes.

### 10. Version bridge — reverse-skew block, forward-skew defer-to-migrate (G-RS8)

Restore reconciles the backup's data-tier version against the installed plugin **before landing files**, using the manifest's `workspace.data_version` and the envelope's plugin version, compared against the installed plugin version:

- **Reverse skew — backup NEWER than installed → BLOCK.** *"This backup was made with a newer Thalura version than you have installed. Update the plugin, then restore."* A newer backup may use schema/features the installed plugin cannot read. Comparison follows **SemVer 2.0.0 precedence** (including pre-release ordering — a pre-release sorts before its own final release, and a higher base version outranks any pre-release of a lower one), specified as a gate (verify-then-escalate-or-flag), not a hard-coded tool. This block is **load-bearing** and cannot be delegated to the first-startup update path, which compares by string inequality with **no ordering semantics** and would silently down-stamp a newer restored workspace to the older installed version.
- **Equal or forward skew — backup SAME or OLDER → PROCEED, then defer to the migrate-on-startup path.** Restore lands the backup's `version.json` **as-is** (it does **not** itself migrate). On the next session startup, core's update step runs the forward update flow (additively copies net-new config-defaults, atomically re-stamps `version.json` to the installed version) and renders the localized changelog notice. Restore must land *a workspace the startup flow accepts*, and a restored `version.json` at an older version is exactly the first-startup-after-a-plugin-bump state it already handles — restore does **not** duplicate migration logic.
- **`version.json` absent from the backup** (a partial that dropped it — should not happen, the `data` scope always includes it): treat as first-run — the next startup's first-run branch creates it at the installed version. Flag it, but do not block.

### 11. Post-restore cross-reference integrity pass (G-RS9)

After any restore (full or library-additive), extend the `plan.json`↔folder check to **cross-scope** references:

- **`units[].output_path` → folder exists** under `<WORKSPACE_ROOT>/`.
- **Per-unit `plan.json` tracked docs → files exist** in the restored output folder.
- **`library_ref.unit_id` → a library entry exists** for it.
- **`plans[].class_id` → a restored class definition exists** (`<WORKSPACE_ROOT>/data/school-years/{year}/classes/{class_id}.json`).
- **class-def `previous_year` (`{year}/{class_id}`) → the referenced prior class def exists.**
- **restored `school_id` shape** valid (the sanity-check above).

**Cross-locale resolution:** after the recorded-ref rewrite on land (§9 sub-step 5), a restored `plan.json`'s recorded path references are **already** in the target workspace's `conversation_language`, so the existence check is **direct and literal** against the on-disk tree — no mapping resolution at check time. This is what also guarantees every downstream consumer that resolves a recorded ref literally reads a correct path. A ref that still does not resolve — an unmappable segment the rewrite left verbatim — is a genuine dangle and is reported.

**Report dangling links in prose** (never silently). A backup that opted **out** of Outputs/Library restored into an empty workspace will have `output_path`/`library_ref` dangles by construction — the pass **reports** them and the flow explains they are expected given the opt-out.

### 12. Confirm in prose (G-RS10)

Success is **declared only after** the integrity pass. Report what was restored (counts), any dangling references found and why, the version-bridge outcome ("your plugin will finish updating the restored data on the next start"), and — for library-additive — which units were added vs. already present. Never present internal `data/` JSON; present only the human summary.

### Restore failure modes

| Failure | Behaviour |
|---|---|
| Corrupt / unreadable file | Refuse; "damaged — do not rely on it" (G-RS1). |
| No / unparseable `manifest.json` | Refuse; "not a readable Thalura backup" (G-RS2). |
| `bundle_kind: "unit"` | Refuse-with-redirect to the library assign / import flow (G-RS2). |
| Direct-init condition unmet | Setup handoff verbatim (G-RS11). |
| Listed `contents[]` member absent | Refuse the whole restore before any workspace write (G-RS2b). |
| Unlisted extra member | Tolerated, not landed, reported (G-RS2b). |
| Per-member hash / size mismatch | Refuse the whole restore; zero workspace files written (G-RS2b). |
| Screened hazard (submissions / `.cache/`) in a crafted bundle | Skipped and reported; drafts / `plan.json` land normally (G-RS2b). |
| Non-empty target | Full overwrite refused; library-only / fresh-workspace offered (G-RS4). |
| Interrupted mid-restore | Honest partial report; same-bundle hash-matched re-run converges (G-RS6a/G-RS6b). |
| Recorded ref carries an unmappable segment | Left verbatim; surfaced once as a genuine integrity-pass dangle (G-RS6c/G-RS9) — never guessed. |
| Reverse version skew | Block; "update the plugin, then restore" (G-RS8). |
| Dangling cross-reference after restore | Reported in prose (G-RS9). |
| Scaffold completion leaves a flagged residual | Reported in the restore summary; never a silent success (G-RS12). |

---

## Notes

- Both flows run core session startup first and interact in `conversation_language`.
- The `data/` tree is internal English-lowercase storage; it is never surfaced to the teacher as raw JSON — every preview is prose.
- Backup packs the whole workspace out to a file and restore brings it back; sharing a single unit as a file (export/import) and reusing a unit within the workspace (shelve/assign) are separate flows.
