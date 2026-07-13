---
name: unit-exchange
description: Einheit teilen oder importieren. Use when the teacher wants to hand a whole teaching unit (Unterrichtseinheit) to a colleague as a file, or take in a colleague's unit file — export a unit to share with a colleague (eine Einheit exportieren / weitergeben), or import a received unit file into the library (eine Einheit importieren). The exported file leaves the workspace; the imported file lands in the library (Bibliothek) as an external entry.
when_to_use: |
  DE + EN: "Einheit teilen", "Einheit exportieren", "Einheit an eine Kollegin / einen Kollegen weitergeben", "Einheit weitergeben", "Einheit importieren", "eine Kollegin hat mir eine Einheit geschickt", "Datei von einem Kollegen einlesen", "kannst du mit dieser Datei etwas anfangen?" (with an attached or placed unit file), "share this unit with a colleague", "export a unit", "hand this unit to a colleague", "import a unit", "a colleague sent me this file". DISAMBIGUATION: export ≠ shelve — "Einheit exportieren/teilen/weitergeben" produces a file that LEAVES the workspace to a colleague; "Einheit aufheben / in die Bibliothek stellen" (no recipient, no file) stays inside the workspace (→ library). A colleague-sent file (attached or placed) → import. A document-format request ("exportiere das Arbeitsblatt als PDF") is a single document's format, NOT a unit hand-off (→ the owning content task). A received whole-workspace backup file is NOT a unit file (refuse-with-redirect, below).
---

# /thalura:unit-exchange — Unit Exchange (Einheiten exportieren und importieren)

> Core protocols — startup, workspace-root resolution, profile load, HiTL/draft lifecycle, class definitions — run via the `core` skill; this task assumes startup has run (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`).

This task hands a whole teaching unit (Unterrichtseinheit) between workspaces. Two flows:

- **export a unit (eine Einheit exportieren / weitergeben)** — pack a shelved library (Bibliothek) unit into one file, deliver it to the teacher's Thalura folder, and hand them the file location so they can send it to a colleague. The export delivers **one of two forms**, chosen in the shared export dialog: the single portable **unit file (Einheiten-Datei)** — the re-importable Thalura package (Thalura-Paket) — or the **plain export („Nur die Dokumente")**, a plain ZIP of the unit's finished documents (its own flow section below).
- **import a unit (eine Einheit importieren)** — take in a colleague's unit file, check it thoroughly, and land it in the library (Bibliothek) as an external entry the teacher can then assign to a class.

The library skill owns shelving, assigning, and restoring; this task owns pack, deliver, receive, and validate. The shelved unit and the imported entry share one format — the library entry defined in `${CLAUDE_PLUGIN_ROOT}/references/schemas/library-subject.md`, carried inside the shared envelope defined in `${CLAUDE_PLUGIN_ROOT}/references/schemas/bundle-manifest.md`. Those two schema documents are the normative formats; this skill implements the strip, deliver, receive, screen, and write steps on top of them.

**Presentation rule (both flows):** interact in `conversation_language`; present **prose previews, never raw `data/` JSON** — never show the teacher a manifest or an entry as raw JSON, always describe it in prose; select units menu-driven (title + subject + grade + creator). The teacher never types a path or a `unit_id`. The unit file is never described as a tar or zip archive — it is simply the teacher's unit file. And because it is a **binary bundle, not a human-readable document**, its delivery is confirmed **in prose only**: name the exact file name and where it lies („liegt als `Globalisierung.thaluraunit` in deinem Thalura-Ordner"), plus the next step — the file itself is **never attached or opened for inline preview** (a rendered preview of binary content is pure noise and buries the actual confirmation). This prose-only delivery applies to **every binary bundle artifact** — a unit file, a backup file (Sicherung), or any future binary format; human-readable deliverables (documents, slides, PDFs) keep their normal presentation.

**Transport discipline (both flows, gate-defined — the mechanism is chosen at runtime and verified, never named here):**

- **Outbound:** stage the file in a session-local working area, copy it once into place, verify by hash after the copy, and sweep for stray temporary artifacts. Never build the file directly on the workspace folder; never overwrite an existing file; never rely on renaming or deleting a file on the workspace folder.
- **Inbound:** peek the manifest first, list the members before extracting anything, screen every member path, extract in an isolated session-local area bounded by the manifest's `contents[]`, and verify each member before it lands. Never a silent import.
- Whatever context does the packing or unpacking must actually be able to read and write both the workspace folder and the session-local working area — verify that before relying on it, and if it cannot, flag it rather than proceeding.

---

## export a unit (eine Einheit exportieren / weitergeben)

**Trigger examples:** "Einheit teilen", "Einheit exportieren", "Einheit an eine Kollegin / einen Kollegen weitergeben", "Einheit weitergeben", "share this unit with a colleague", "export a unit", "hand this unit to a colleague".

Because a shelved unit is already class-stripped and validated by construction, export packs an **already-clean snapshot** and re-verifies the invariants rather than re-implementing the exclusions. The flow and its gates:

### 1. Select the unit (G-E1)

List the teacher's library (Bibliothek) unit **families** for their subjects — **one row per family** (title, subject, grade, course level (grundlegendes oder erhöhtes Anforderungsniveau), creator, and the shelved or imported date, from the family's newest non-archived version (Fassung), with a version cue when the family has more than one) — and let them pick one. When the picked family has more than one version, the version choice runs exactly as in the assign flow of `${CLAUDE_PLUGIN_ROOT}/skills/library/SKILL.md`: the newest non-archived version by default, alternatives one question away, summarized from the version note + date + class context. The bundle carries the **picked** version.

- **Not-shelved edge:** if the teacher names a class-bound unit that is not in the library (for example "meine Globalisation-Einheit an Herrn X geben"), do not dead-end — explain that sharing works from the library (Bibliothek) and **offer to shelve it first**, then continue the export with the fresh entry. An empty library gets the same offer. Shelving delegates to the `shelve-unit` flow in `${CLAUDE_PLUGIN_ROOT}/skills/library/SKILL.md` — no re-implementation here.
- **Archived entries** are not listed by default but are exportable on explicit request; when the entry's `replaced_by` is set, add a one-line note that a newer version exists („eine neuere Fassung existiert").
- **External entries are exportable** (pass-through re-share): the unit body's provenance fields — `creator`, `federal_state`, `school_type` — stay the **original author's**, verbatim; only the envelope identifies the exporting teacher.
- **Dangling-entry guard:** if the entry's `materials_path` folder is missing, or its `documents` inventory does not match the snapshot on disk, report it and stop — never export a snapshot that fails its own inventory.

### 2. Shared export dialog (G-X1)

Once a unit (and, when the family has more than one, a version (Fassung)) is picked, ask **how** the teacher wants to hand it over — menu-driven, in `conversation_language`, always prose, never raw JSON:

- **Q1 — mode.** „Als **Thalura-Paket** (zum Re-Import in Thalura) oder als **nur die Dokumente** (fertige Dateien, für alle lesbar)?" State the one-line consequence of each option: the Thalura package (Thalura-Paket) can be read back into a colleague's own library (Bibliothek), while „nur die Dokumente" gives finished files any colleague can open but nothing to re-import.
- **Q2 — drafts (Entwürfe).** Asked **only when eligible drafts exist** (per the *Draft carriage (Entwürfe)* (G-X2) eligibility rules below): „Auch die Entwürfe mitgeben? (Für die Zusammenarbeit an der Einheit: ja. Für eine fertige Einheit: besser nicht.)" Q2 fires for **both modes** — the Thalura package (Thalura-Paket) and the plain export („nur die Dokumente") alike — whenever eligible drafts exist. Eligibility now has **two mutually-exclusive sources** (G-X2): for `source: "self"` entries the drafts are sourced from the **live class-bound unit**; for `source: "external"` entries with a drafts region they are sourced from the **snapshot's `drafts/` region**. When no eligible drafts exist, Q2 is skipped entirely. The two questions may share one conversational turn; both answers are restated in the hand-off.

Then **branch on Q1:**

- **Thalura package (Thalura-Paket)** → the manifest-and-pack flow below (G-E2…G-E5), with draft members carried in `draft_contents[]` / the `drafts/` region when Q2 was answered yes; without a Q2 yes the package carries no drafts (Entwürfe) — the default is exclude, and drafts travel **only** on an explicit yes.
- **„nur die Dokumente"** → the plain-export flow (G-P1…G-P4) in its own section below, with eligible drafts (Entwürfe) joining the pack as loose files when Q2 was answered yes.

### 3. Build the manifest (G-E2)

Build the envelope per the bundle-manifest schema, with every required field:

- `format_version: 1`; `plugin_version` = the installed plugin version; `bundle_kind: "unit"`; `created_at` = now, ISO-8601; `creator` = the **exporting** teacher's profile display name; `federal_state` and `school_type` = the **exporting** workspace's profile values; `conversation_language` = the exporting workspace's language.
- `contents[]`: one `{ path, sha256, bytes }` object per snapshot file — paths payload-relative with canonical (locale-neutral) subfolder keys (`lessons`, `materials`, `assessments`), exactly the files the entry's `documents` inventory names, and nothing more. A validated material's PDF sibling (registered as `pdf_path` in the unit manifest (Einheitenplanung)) is part of the entry's `documents` inventory and therefore travels as a normal `contents[]` member; a validated `.pdf` carries no draft suffix, is not the material-overview document (Materialübersicht), and is not a submissions file — it passes every export invariant stated below.
- `draft_contents[]`: **present only when the teacher opted the drafts (Entwürfe) in at Q2** (absent or empty otherwise) — one `{ path, sha256, bytes }` object per draft payload member, the **same shape** as `contents[]`. Paths are payload-relative under the **`drafts/` region** with canonical (locale-neutral) subfolder keys (`drafts/lessons`, `drafts/materials`, `drafts/assessments`) — never localized. The list is **disjoint from `contents[]`**: no path appears in both, and no `contents[]` path lies under `drafts/`.
- `unit` body = the library entry **minus `source_class` and `materials_path`** (workspace-internal fields), with the workspace-local lifecycle fields **normalized**: `archived: false`, `replaces: null`, `replaced_by: null` (Soft-Replace links reference workspace-local ids that are meaningless — or colliding — in the target workspace). Every other field is verbatim, including `source`, `shelved_at`, `imported_at`, `version_note`, and the full `documents` inventory — **plus**, when drafts (Entwürfe) were opted in at Q2, the parallel `draft_documents` inventory (staged as described below; absent otherwise). A bundle carries **one version (Fassung)** — the picked entry and its snapshot; **the family never travels** (a colleague wanting two versions receives two files).

**Draft staging (only when Q2 was answered yes):** the eligible draft files — sourced per the *Draft carriage (Entwürfe)* (G-X2) rules (the live class-bound unit for a `source: "self"` entry, the snapshot's `drafts/` region for a `source: "external"` entry) — are staged into the payload's `drafts/` region under the canonical keys `drafts/lessons` / `drafts/materials` / `drafts/assessments`. For a **self** entry each file is **class-stripped on the fly** (the same class-neutrality rule the shelve-time strip applies — the source `class_id` token never leaves the workspace) with its **draft suffix retained** in the source language (the receiving side re-localizes the suffix at assign); for an **external** entry the region files travel **verbatim** (already class-neutral and draft-suffixed). `draft_contents[]` is then computed over the staged region exactly as `contents[]` is over the snapshot (path / sha256 / bytes). The unit body's `draft_documents` inventory carries the **semantic** fields (number/title/duration, id/type/linked_to) read from the live unit's manifest (`plan.json`) draft entries for a self entry (copied verbatim for an external re-share), but every `filename` is **derived from the staged, class-stripped `drafts/`-region member names — never taken verbatim from the live unit's manifest**, whose draft filenames are class-bound (reading them verbatim would ship the source `class_id` out of the workspace inside the delivered file). The inventory is therefore class-neutral by construction.

**Re-assert the snapshot invariants (belt-and-suspenders — they held at shelve time; now list-scoped across both channels):**

- **Validated channel (`contents[]`) — categorical bar, verbatim.** No `contents[]` path may name a student-submissions folder (**any** language's `folder_names.submissions` value in `${CLAUDE_PLUGIN_ROOT}/references/localization.json`), carry a draft suffix (**any** language's `system_labels.draft_suffix`), be the unit manifest (`plan.json`) or a material-overview document, or contain the source `class_id` token in any path segment or filename. A draft suffix in `contents[]` is still a corrupt-snapshot flag — the draft channel is the *only* place a draft-suffixed file may travel.
- **Draft channel (`draft_contents[]`) — inverse assertions (only when drafts were opted in).** Every `draft_contents[]` member MUST carry a draft suffix (some language's `system_labels.draft_suffix`), MUST lie under the `drafts/` region, and MUST be class-neutral (no source `class_id` token in any path segment or filename — the same strip rule G-X2 applies). A non-suffixed member, a member outside `drafts/`, or a class-carrying member in `draft_contents[]` is the same flag-and-stop. No `contents[]` path may lie under `drafts/`, and the two lists stay **disjoint** (no shared path) — both directions.
- **Draft inventory (`draft_documents`) — export-side two-sided check.** Every `draft_documents` `filename` MUST be class-neutral (no source `class_id` token) and draft-suffixed, and a **two-sided `drafts/`-region↔`draft_documents` consistency check** runs at export: every staged region member is named in the inventory, and every inventory `filename` is staged in the region (the export-side mirror of the import G-I8a two-sided check). A class-token leak or a region/inventory mismatch is caught **here, in the exporting workspace** — never first at the recipient.
- **Both lists (per-manifest, not per-snapshot).** The submissions / `plan.json` / material-overview / class-token bars apply over **both** `contents[]` and `draft_contents[]`; and the unit body's `version_note` must not carry the source `class_id` token (the note is class-neutral by the shelve-time gate).

A violation on either channel means the snapshot itself is corrupt — flag it to the teacher and stop; never export it.

### 4. Pack in a session-local working area (G-E3)

Build the file in a session-local working area — never on the workspace folder. Verify the staged file before it moves: it decompresses cleanly, its member list matches `manifest.json` plus `payload/` plus exactly the **union of the `contents[]` and `draft_contents[]` paths** (member completeness runs over **both** lists), and every member — validated and draft alike — re-hashes to its declared `sha256`. When drafts were opted in, this staged verify also re-asserts the export-side two-sided `drafts/`-region↔`draft_documents` consistency check (G-E2). On failure, rebuild once by a different method; if it still fails, stop and tell the teacher.

### 5. Deliver to the workspace folder (G-E4)

Copy the verified file **once** onto the workspace root (`<WORKSPACE_ROOT>/` — the teacher's connected Thalura folder, the same surface every generated document uses), then:

- **Filename:** `{unit_slug}.thaluraunit`, using the entry's stored `unit_slug` (for example `Globalisation.thaluraunit`). **Never overwrite an existing file:** if that name is already taken, choose a fresh numbered name (`Globalisation-2.thaluraunit`, counting up) — a copy on the workspace folder replaces content in place and renaming or deleting there is unreliable, so collision avoidance happens **before** the copy.
- **Post-copy verify:** re-hash the delivered file; it must equal the staged file's hash. On mismatch, retry the copy once, then flag — never announce a file that has not verified.
- **Stray-temp sweep:** list the destination folder and check for orphaned temporary artifacts of the copy. If a stray exists and cannot be removed from the session, tell the teacher its exact name and that it is safe to delete manually.

### 6. Hand-off prose (G-E5)

Tell the teacher, in prose:

- the exact filename and that it is in their Thalura folder;
- what the file contains — the validated unit documents and the unit's description, **plus**, when drafts (Entwürfe) were opted in at Q2, „N Entwürfe, als Entwurf markiert" (N = the number of included drafts) — and what it **never** contains: no student submissions (Abgaben), no class names, and — **only** when the teacher excluded them — no drafts (Entwürfe), so the file is safe to pass on;
- how the colleague imports it: send the file any way they like; the colleague either attaches it in a Thalura chat or drops it into their own Thalura folder and asks Thalura to import it.

No archive-tool jargon; the file is never described as a tar or zip. And per the presentation rule, the hand-off is **prose-only**: never attach or open the delivered file for inline preview — naming the exact file and its location *is* the hand-off.

### Export failure modes

| Failure | Behaviour |
|---|---|
| Entry's snapshot folder missing / inventory mismatch | Stop before packing; report (dangling guard, G-E1). |
| Snapshot invariant violation — validated channel (submissions / draft-suffix in `contents[]` / `plan.json` / material-overview / class-id) **or** draft channel (a `draft_contents[]` member that is non-suffixed, outside `drafts/`, or class-carrying; or a `draft_documents` class token or region↔inventory mismatch) | Stop; flag as a corrupt snapshot; never export (G-E2). |
| Staged file fails verification | Rebuild once by a different method; else stop with prose (G-E3). |
| Post-copy hash mismatch | Retry once; else flag with prose — the file on disk is not announced as good (G-E4). |
| Destination filename taken | Fresh numbered name, never overwrite (G-E4). |
| Stray temporary artifact un-removable | Name it to the teacher; safe to delete manually (G-E4). |

---

## plain export („Nur die Dokumente")

**Reached from** the shared export dialog (G-X1) when the teacher picks **„nur die Dokumente"** — the unit's finished documents as one ordinary **ZIP file** any colleague can open, no Thalura needed. Delivery only: a plain export is **never re-importable** as a unit. Same unit selection and same source snapshot as the Thalura-package (Thalura-Paket) flow, and the same transport discipline; it differs only in **what is packed** (documents only, transformed per G-P3) and **what is delivered** (a plain ZIP file, no envelope, no manifest).

### plain export — 1. Content set (G-P1)

Source = the picked library (Bibliothek) entry's snapshot (validated by construction, class-stripped at shelve time). The pack list is:

- the **unit-plan document (Einheitenplanung)** at the snapshot root;
- every file in the snapshot's `lessons`/`materials`/`assessments` subtrees that the entry's `documents` inventory names — exactly, with the same **dangling-entry guard** as G-E1 (an inventory/disk mismatch stops the export);
- every **validation PDF** sibling already present (registered as `pdf_path` in the unit manifest (Einheitenplanung)) — included as it stands, **never generated** at export time;
- **plus**, when drafts (Entwürfe) were opted in at Q2, the eligible draft files per the *Draft carriage (Entwürfe)* (G-X2) rules below.

**Never packed (assert, belt-and-suspenders — mirror G-E2's re-assert the snapshot invariant, even though the snapshot is clean by construction):** the bundle manifest or any envelope artifact, `plan.json`, the material-overview document (Materialübersicht), any path under **any** language's `folder_names.submissions` value, cache or temporary artifacts, and — unless opted in — any file carrying **any** language's `system_labels.draft_suffix`. No packed filename or path segment may contain the source `class_id` token. A violation is a corrupt-snapshot flag: stop, tell the teacher, and never export.

### plain export — 2. Localized ZIP layout (G-P2)

One top-level `{unit_slug}/` folder; inside it the subfolders are the **localized** `folder_names` values of the exporting workspace's `conversation_language` (for a German workspace, `Stunden` / `Materialien` / `Lernkontrollen`) — **never** the canonical keys `lessons`/`materials`/`assessments`, which are an internal portability convention and never surface raw. The recipient is a human browsing folders, so they get the same localized tree a workspace would show.

**Honest link caveat:** the shelve-time class-neutral rename strips the class prefix from filenames but does **not** rewrite intra-document links, so a link that referenced an old class-prefixed sibling is **likely already broken inside the snapshot**; mirroring the localized folder layout does not restore it. The layout mirror is best-effort, **not** a link-integrity guarantee. **The guarantee is the spot-check-and-note:** after staging, spot-check relative link targets (when any exist in the packed documents) against the staged tree; every non-resolving link is reported in the hand-off prose as a **named, benign note** — never silently shipped as "verified", never claimed as resolved.

### plain export — 3. Notice-strip (G-P3 — transform copies, verify by read-back)

Documents that carry the AI-generation notice (Erstellungshinweis) block are **copied to the session-local staging area and the notice block is removed from the copy**; the source snapshot is never modified.

- **Identify by semantic identity, never by layout:** the block is the one whose heading and body originate from the `ai_generation_notice_heading` / `ai_generation_notice` localization keys — match against **every** language's values, never by font, size, or colour.
- **Read-back per transformed file:** (a) no delivered file's extracted text contains any language's notice heading or body; (b) the file still opens as a structurally valid document of its type; (c) its Author/Application metadata is **unchanged** versus the source file. On failure: re-attempt by a different method; if it still fails, **flag and stop** — never deliver a file that failed its read-back.
- **Files without a notice pass trivially** — including every file once a future generation-time redesign removes the notice from the source. The gate ("no delivered file contains a notice") is the permanent contract; the strip is the mechanism-of-record only while sources still carry the block.
- **Notice-bearing PDFs** (the validation-PDF ride-alongs) are transformed the same gate-defined way; where a faithful PDF edit is not achievable, the PDF is **excluded with a named note in the hand-off prose** — never delivered notice-bearing, never regenerated. (In practice only planning-document PDFs can carry the notice, and those exist only when the workspace's `pdf_on_validation` preference is `"all"` — most exports encounter none.)

### plain export — 4. Pack, deliver, hand off (G-P4)

Same transport discipline as G-E3/G-E4:

- Build the ZIP file in the session-local staging area, **never** on the workspace folder. **Staged verify:** it lists cleanly and its member list equals **exactly** the G-P1 pack list (after the G-P3 transforms). On failure, rebuild once by a different method, else stop with prose.
- Deliver by a **single copy** to the workspace root as **`{unit_slug}.zip`** (from the entry's stored `unit_slug`). **Never overwrite:** if that name is already taken, choose a fresh numbered name (`{unit_slug}-2.zip`, counting up) **before** the copy. **Post-copy** re-hash must equal the staged hash (retry the copy once, then flag). Sweep for stray temporary artifacts; name any unremovable stray to the teacher as safe to delete manually.
- **Hand-off is prose-only** — a plain ZIP file is a binary bundle artifact, so it is named and located in prose, never attached or opened for inline preview. The prose states:
  - the exact filename and where it lies in the Thalura folder;
  - that it contains the finished documents as ordinary files any colleague can open — no Thalura needed;
  - what it never contains: no student submissions (Abgaben), no class names, and — when the teacher excluded them — no drafts (Entwürfe), with a one-line note that in-progress material was left out;
  - that this file is **for using, not for re-importing** — a colleague who does use Thalura and wants the unit in their own library (Bibliothek) should be sent a **Thalura package (Thalura-Paket)** instead.

  No archive-tool jargon beyond calling it a ZIP file.

### Draft carriage (Entwürfe) (G-X2)

Q2 of the shared export dialog (G-X1) offers to include the unit's drafts (Entwürfe) in **either** export mode — the plain export and the Thalura package (Thalura-Paket) alike — but only when eligible drafts actually exist. Eligibility has **two mutually-exclusive sources**: live-unit sourcing for `source: "self"` entries, and snapshot-region sourcing for `source: "external"` entries with a drafts region. Sourcing and eligibility:

- **Self entries (`source: "self"`) — live-unit source.** The library (Bibliothek) snapshot **never contains drafts (Entwürfe)** for a self-shelved entry — the shelve flow excludes them by construction. Draft carriage therefore sources from the **live class-bound unit** the entry was shelved from (the entry's `source_class`).
- **Eligible (self entries) only when** all of these hold: the picked version (Fassung) is the family's newest non-archived entry; `source_class` resolves to an existing class-bound unit in the current school year (Schuljahr); and that unit's `lessons`/`materials`/`assessments` folders contain files carrying `system_labels.draft_suffix`. Archived entries and older picked versions (Fassungen) have no meaningful live draft state — the question never fires for them. (External entries are covered by the separate region source below; an external entry **without** a `drafts/` region likewise never fires Q2.)
- **Targeted sweep (self entries):** only draft-suffixed files under the unit's lesson/material/assessment folders. **Never** `plan.json`, the material-overview document (Materialübersicht), anything under the student-submissions (Abgaben) folder, or cache artifacts.
- **Per included draft file (self entries):** strip the source `class_id` token from the filename on the fly (the same class-neutrality rule the shelve-time strip applies — class names must never leave the workspace), and **keep the draft label visible** — the localized `system_labels.draft_suffix` is preserved in the delivered filename so the recipient is never misled about maturity.
- **Coherence guard — plain export („nur die Dokumente") (self entries only; warn-and-proceed):** drafts belong to the live unit; the snapshot is the last shelved state. (Like the package hard-gate below, this guard cannot fire for an external entry — there is no live unit to diverge; the snapshot region source is self-coherent by construction.) When the live unit's *validated* files differ from the snapshot (the entry is stale), a drafts-included **plain export** would mix an old validated state with new drafts. Detect the divergence (an inventory/hash comparison against the snapshot) and, **for the plain export only**, **offer** to fold the current state into the library (Bibliothek) as a new version (Fassung) first (the existing shelve/version flow), then **proceed** either way — loose files, human judgement, no bundle claiming a coherent unit. This warn-and-proceed governs the plain export alone: it ships loose documents that make no coherent-unit claim, so a human eyeballing them is the right safeguard. The Thalura package (Thalura-Paket) makes the stronger claim and is governed by the hard-gate below.
- **Coherence hard-gate — Thalura package (Thalura-Paket) (self entries only):** a package claims a coherent, re-importable unit a colleague's library (Bibliothek) will trust, so it must not ship a stale validated core beside newer drafts. (External entries carry **no** coherence guard by construction — a snapshot region is self-coherent; see the external-entries source below.) **Trigger precision — both conditions, never drafts alone:** the gate fires **only** when the live unit's **validated** state has diverged from the picked snapshot (the same inventory/hash comparison the plain-export guard uses) **and** the teacher opted the drafts (Entwürfe) in at Q2. The mere presence of drafts with an **unchanged** validated state fires nothing — the export proceeds. The trigger is validated-file divergence, **never** draft presence; in the common shelve-then-draft-forward workflow the validated core is unchanged, so the gate never fires.
- **On trigger,** the export does **not** proceed as-is; present the teacher, in `conversation_language`, three options. A fourth — proceed with the mixed bundle — is **deliberately not offered**: the recipient cannot see the incoherence (the draft label signals maturity, not whether the parts belong together), and the imported unit would enter the colleague's library (Bibliothek) as if coherent.

  > „Deine Einheit hat sich seit der letzten Fassung in der Bibliothek weiterentwickelt: Die geprüften Dokumente deiner Klasse sind neuer als der Stand in der Bibliothek. Ein Thalura-Paket soll deiner Kollegin oder deinem Kollegen einen stimmigen Stand übergeben. Du hast drei Möglichkeiten:
  > 1. **Empfohlen:** Den aktuellen Stand zuerst als neue Fassung in die Bibliothek aufnehmen — dann exportiere ich diese neue Fassung zusammen mit den Entwürfen, und alles passt zusammen.
  > 2. Die vorhandene Fassung aus der Bibliothek exportieren, ohne die Entwürfe (dafür ist keine neue Fassung nötig).
  > 3. Den Export abbrechen."

  **Option semantics:** (1) the recommended default — run the existing shelve/version flow to fold the current state into the library (Bibliothek) as a new version (Fassung), then export that fresh entry together with its drafts (the only path that ships the drafts coherently); (2) export the picked snapshot **without** drafts — the escape that needs **no** new version (the Q2 drafts-yes outcome is overridden to no, and no new version is created); (3) abort cleanly — nothing is written or delivered. The two modes deliberately differ: the package hard-gates because it claims a coherent, re-importable unit, while the plain export only warns because it is loose files making no such claim — a designed distinction, not an inconsistency.
- **External entries (`source: "external"`) — snapshot-region source.** For an imported (external) entry whose `draft_documents` inventory is **non-empty**, Q2 fires sourced from the snapshot's **`drafts/` region** — no live unit is involved, **no coherence guard** (a snapshot is self-coherent by construction), and **no class-strip** (region files are class-neutral already). On yes, the region files and the `draft_documents` inventory travel **verbatim** (pass-through re-share — provenance stays the original author's). An external entry **without** a `drafts/` region still never fires Q2.
- **Carriage:** eligible draft files join the G-P1 pack list, land in their localized folders, keep their (class-stripped, draft-suffixed) filenames, and pass the G-P3 notice-strip gate like any other document. For an **external** entry the opted-in files come from the snapshot's `drafts/` region — already class-neutral and draft-suffixed — and likewise join the pack list as loose files, passing G-P3 like any document.

### plain export failure modes

| Failure | Behaviour |
|---|---|
| Corrupt-snapshot invariant violation (submissions / draft / `plan.json` / material-overview / envelope / `class_id` found) | Stop; flag as a corrupt snapshot; never export (G-P1). |
| Staged member list ≠ pack list | Rebuild once by a different method; else stop with prose (G-P4). |
| Post-copy hash mismatch | Retry the copy once; else flag — the file on disk is not announced as good (G-P4). |
| Destination filename taken | Fresh numbered name, chosen before the copy; never overwrite (G-P4). |
| Notice read-back fails (notice text still present / not a valid document / metadata changed) | Re-attempt by a different method; if it still fails, flag and stop — never deliver (G-P3). |
| Notice-bearing PDF not faithfully strippable | Exclude it with a named note in the hand-off prose; never deliver it notice-bearing, never regenerate (G-P3). |
| Non-resolving relative link in a packed document | Named benign note in the hand-off prose; never reported as "verified" or resolved (G-P2). |

---

## import a unit (eine Einheit importieren)

**Trigger examples:** "Einheit importieren", "eine Kollegin hat mir eine Einheit geschickt", "Datei von einem Kollegen einlesen", "kannst du mit dieser Datei etwas anfangen?" (with an attached or placed unit file), "import a unit", "a colleague sent me this file".

Import is verify-screen-admit: validate the envelope, screen the payload defensively (the exporter is a foreign workspace — possibly buggy, old, or hand-crafted), extract only what the manifest declares, verify what landed, and **add** the unit to the library (Bibliothek) — never modifying or removing anything that already exists.

### 1. Locate the inbound file (G-I1)

Two first-class paths:

- **Chat upload:** the attached file materializes as a real file in the session; use it where it landed.
- **Folder placement:** the teacher placed the file in their Thalura folder; locate it at the workspace root. When several candidate unit files are present, ask which one — list them by filename, size, and modification date, in prose.

Detection **trusts the manifest, not the extension:** a candidate file without the `.thaluraunit` extension is still peeked; a `.thaluraunit`-named file whose manifest says otherwise is routed by its manifest (below). The inbound file is **never deleted or renamed** by import; after a successful import, tell the teacher the file itself is no longer needed and can be deleted manually.

### 2. Envelope validation (G-I2, manifest-first)

Extract **nothing** into the workspace yet. Peek the file in an isolated session-local working area:

1. **Readable file:** it decompresses and lists. Failure → "the file appears damaged in transit — ask your colleague to export and send it again" (prose; no partial import).
2. **Manifest present and parseable:** a top-level `manifest.json` exists and parses. Failure → "this is not a Thalura unit file". **Redirect hint for a plain export:** when the inbound file decompresses and lists cleanly (it passed the readable-file check) but carries **no** top-level `manifest.json`, it is most likely a plain export („Nur die Dokumente") — a ZIP of finished documents meant for direct use. Say it is not a Thalura unit file and that a plain export **cannot be imported** into the library (Bibliothek); if the colleague wants the unit in their library, ask them to send a **Thalura package (Thalura-Paket)** instead. **No library entry is written** — nothing is added to the index.
3. **Route on `bundle_kind`:**
   - `"unit"` → proceed.
   - `"workspace"` → refuse-with-redirect: this is a whole-workspace backup (Sicherung), not a single unit; restoring backups is a separate flow (say the restore feature is not yet available until it ships). Never imported as a unit.
   - any unknown value → refuse: it was likely created by a newer Thalura version; suggest updating the plugin.
4. **`format_version` check:** `1` → proceed. **Greater than `1` → block** with prose: "this unit file was created with a newer Thalura version — update the plugin, then import" (a bumped `format_version` means a breaking structural change by definition, so warn-and-proceed would mis-parse). Unknown **extra** fields at version 1 → ignored (forward-compatibility).
5. **Required envelope fields present** (the bundle-manifest field list). Missing required fields → refuse with prose (malformed; ask for a re-export).
6. **Path and member screen:** every archive member path — the top-level `manifest.json` being the one expected non-`payload/` member, explicitly exempt from the payload-relativity rule — and every `contents[]` and `draft_contents[]` path must be payload-relative and clean: no absolute paths, no `..` segments, nothing that escapes the extraction area. Members must be **regular files** — no symlinks, hardlinks, devices, or FIFOs. **Duplicate member paths are refused, including case-insensitive duplicates** (a case-colliding pair silently collapses to one overwritten file on a case-insensitive filesystem) — the duplicate, path-traversal, and regular-file screens apply to every archive member, `drafts/`-region members included. Any violation → **refuse the whole file** (a manipulated archive is never partially imported).
7. **Member completeness and size bounds:** **every `contents[]` path must exist as an archive member** — a missing member means the file is incomplete or damaged → refuse the whole import ("the file is incomplete or damaged — ask your colleague to re-export"). A declared-but-absent member must never pass silently. **Member completeness is per-list:** when the manifest carries a `draft_contents[]`, **every `draft_contents[]` path must likewise exist as an archive member** — a declared-but-absent `draft_contents[]` member refuses the import exactly as a missing `contents[]` member does. Declared `bytes` are enforced **during** extraction (or via a pre-extraction total-size sanity bound) over **both** lists: a member exceeding its declared size stops extraction immediately — a decompression bomb must hit the bound, not a post-hoc check.

### 3. Unit-body validation and compatibility prose (G-I3, G-I4)

1. **Unit body shape (G-I3):** the `unit` object carries every required library-entry field (minus the export-stripped `source_class` / `materials_path`); `grade_level` matches the schema's shape gate; the `documents` inventory is present and internally consistent (every inventory `filename` / `files` value appears in `contents[]`). Failures → refuse with prose (malformed; re-export).

   **Early draft-channel consistency (G-I3, parallel):** when the manifest carries a `draft_contents[]`, the draft channel gets the same two-sided **early** check the validated channel has — every `draft_documents` `filename` must resolve to a declared `drafts/`-region path in `draft_contents[]`, **and** every `draft_contents[]` member must be named in `draft_documents`. A mismatch in **either** direction **refuses the import cleanly before any write** (the same failure class as the `documents`↔`contents[]` check above), never surfacing late as a post-copy rollback. `draft_documents` empty or absent is tolerated **only when** `draft_contents[]` is likewise absent or empty; a populated channel with a missing or empty counterpart on **either** side refuses here.
2. **Prose summary (G-I4a):** before anything is written, show the teacher what arrived — title, subject, grade, course level, creator, federal state (Bundesland), planned hours, and document counts (lessons / materials / assessments) — in prose, never raw JSON. When the manifest carries a non-empty `draft_contents[]`, the summary also notes „enthält N Entwürfe" (N = the `draft_contents[]` length) — a manifest-only count, no payload read.
3. **Federal-state / school-type mismatch (G-I4b — warn, never block):** compare the **unit body's** `federal_state` / `school_type` (the authoring provenance — what the content was written against) with the importing teacher's profile. On mismatch, warn: the unit was created for another federal state (Bundesland) or school type (Schulform), so curriculum and regulation references inside the documents may not match — the teacher confirms or aborts. Never a silent proceed, never a hard block. The warning is generic ("another federal state / school type"); it never names one.
4. **Subject gate (G-I4c):** the unit is **never re-labelled** to a different subject (cross-subject import is not supported).
   - Subject supported by the plugin **and configured** for this teacher → proceed.
   - Supported by the plugin but **not among the teacher's configured subjects** → warn and ask for explicit confirmation ("you don't currently teach X; the unit would sit in your library under X until you add the subject"); on confirm, create the missing `<WORKSPACE_ROOT>/data/library/{subject}.json` skeleton (`{"subject": …, "units": []}`) and proceed; on decline, abort with nothing written.
   - **Not a plugin-supported subject at all** → refuse with prose (there is no workspace anywhere for it to live — folder localization and assign both need a supported subject).
5. **Duplicate and family cue (G-I4d):**
   - If a non-archived entry with the same `title` and `creator` (and subject) already exists, say so ("you appear to already have this unit, imported or shelved on DATE") and ask before importing a second copy.
   - **Family cue (informative, never blocking):** if the library holds a version family matching on **title (+subject) alone** — case-insensitive title or same `unit_slug`, regardless of `creator` — mention it in one sentence and say the imported unit lands beside it as its own unit: *„du hast bereits 2 Fassungen von ‚Globalisation' (zuletzt aufgehoben Juni 2026) — die importierte Einheit lege ich als **eigene Einheit** daneben."* The imported entry always lands as its **own family** — its version links were normalized at export, and whether it is "the same" unit is the teacher's judgement, not a mechanical one; no link is ever written at import.

   This is teacher-facing duplicate handling; it is independent of the mechanical id collision below.

### 4. Extraction and defense-in-depth screen (G-I5)

Extract **only the files the manifest declares** into the isolated session-local working area — the `contents[]` members into the validated tree, and, when the manifest carries a `draft_contents[]`, its members into the working area's `drafts/` region — never directly onto the workspace, and never a file the manifest does not declare (extra payload files are tolerated but **not extracted**; report them in prose).

**Per-member integrity:** every extracted file's `sha256` and byte size must match its declaration — `contents[]` for a validated member, `draft_contents[]` for a draft-region member. Any mismatch → **refuse the whole import** ("the file appears damaged — ask your colleague to re-export"); never land a partially-verified snapshot.

**Defense-in-depth screen:** even though a conformant exporter excludes them, re-screen the verified set and **skip** (do not land) any file that:

- sits in a student-submissions folder — **any** language's `folder_names.submissions` value in `${CLAUDE_PLUGIN_ROOT}/references/localization.json`, at any depth (**categorical, both regions** — a submissions path is screened wherever it appears, the validated tree and the `drafts/` region alike);
- carries a draft suffix — **any** language's `system_labels.draft_suffix` — **unless it is a genuine draft-channel member:** a draft-suffixed file is admitted **iff** it is declared in `draft_contents[]` **and** its path lies under the `drafts/` region. A draft-suffixed member arriving **outside** `drafts/`, or **undeclared** in `draft_contents[]`, is screened exactly as today (skipped-and-reported; refused when `documents`-inventory-listed);
- is the unit manifest (`plan.json`) or a material-overview document (**categorical, both regions, any depth** — never admitted anywhere, `drafts/` region included);
- carries a filename outside **its** inventory (an inventory-unlisted straggler) — a validated-tree member is matched against the `documents` inventory; a `drafts/`-region member is matched against `draft_documents`, so a legitimate declared draft member is **not** a straggler.

Skipped files are **reported to the teacher in prose** (what was skipped and why Thalura never imports it) — a screen, not a silent drop. Screening an **inventory-unlisted** file narrows the import and never fails it. **A screened file that is listed in the `documents` inventory, however, forces a refuse** (nothing has been written at this stage): landing the entry would leave it referencing a file that was deliberately never extracted — a broken entry by construction — so the file is refused as malformed or hazardous with a re-export ask. Student-submission screening is the privacy-critical case: a colleague's students' work must never enter this teacher's library.

### 5. Identity and entry write (G-I6, G-I7)

1. **`unit_id` (G-I6):** take the bundle's `unit_id` and run it through the `unit_id` verify contract in `${CLAUDE_PLUGIN_ROOT}/skills/library/SKILL.md` (shape, uniqueness against both the index and the `materials/` folders, and the post-write freshness gate). If shape-valid **and** free, keep it. On **collision**, re-sequence locally: mint the next free sequence for the same slug via that same contract, keeping **all provenance fields verbatim**. If the bundle's id fails the shape gate, mint a fresh id from the unit body's `unit_slug` via the same contract. The teacher never sees ids; this is mechanical.

   The two verify-contract gates fail in different ways and are handled differently — do not conflate them:
   - A **uniqueness (pre-write) failure** is a collision → re-sequence locally, as above, and write the re-sequenced id.
   - A **freshness (post-write, second-draw) failure** follows the id contract's own remediation: the **written entry stands — it is not rolled back** (the id was already verified unique before the write), the failure means the **generator** is broken (echoing instead of sampling current state), so **flag the generator to the teacher** and switch to a different derivation method for any further id this session. **A freshness-gate failure leaves the written entry standing and flags the generator — it is never the index-rewrite rollback** below.

2. **Entry rewrite rules (G-I7)** — authoritative regardless of what the bundle claims:

   | Field | Written value |
   |---|---|
   | `unit_id` | Per G-I6 (bundle's id, or locally re-sequenced / re-minted). |
   | `source` | `"external"` — always, regardless of the bundle body's value. |
   | `imported_at` | Now (ISO-8601). |
   | `shelved_at` | `null` (the export date lives in the envelope's `created_at` and is not persisted onto the entry). |
   | `source_class` | `null` (stripped at export; never reconstructed). |
   | `materials_path` | `"materials/{final unit_id}/"` (local). |
   | `archived`, `replaces`, `replaced_by` | `false`, `null`, `null` — normalized on write even if the bundle carries junk. |
   | `version_note` | Verbatim from the unit body (`null` if absent). |
   | `creator`, `federal_state`, `school_type`, `plugin_version`, `format_version` | Verbatim from the unit body (authoring provenance). |
   | `competency_areas`, `planned_hours`, `title`, `unit_slug`, `subject`, `grade_level`, `sek_level`, `course_level`, `documents` | Verbatim (competency ids carry best-effort; assign confirms them with the teacher). |
   | `draft_documents` | Verbatim from the unit body; absent or empty tolerated **only** when `draft_contents[]` is likewise absent or empty (the early G-I3 draft-channel check already refused any mismatch). |

3. **Library-additive write — verify-before-append ordering:** copy the screened snapshot from the working area into `<WORKSPACE_ROOT>/data/library/materials/{final unit_id}/`, **preserving the canonical subfolder keys exactly as they arrived** — no re-localization: the snapshot lands canonical-key, and re-localization into a workspace's own folder names happens only later, when the material enters a class tree at assign time. Then run the landed-snapshot verify (below) on the copied tree, and **only then** append the entry to `<WORKSPACE_ROOT>/data/library/{subject}.json` → `units[]`. The index entry is always the **last** write, so a snapshot that fails its verify never has an entry pointing at it, and most rollbacks are a no-write. Nothing existing is ever modified or removed — import only adds.

### 6. Post-import verify and confirmation (G-I8, G-I9)

**Landed-snapshot verify (G-I8a — runs BEFORE the index append):** **every file named in the entry's `documents` inventory exists in the landed snapshot** (the inventory-files-exist direction — the one that catches a hole); and the reverse is checked too, as the inbound stray sweep — nothing landed under `materials/{unit_id}/` that the inventory does not name (copy-temp artifacts or stragglers are flagged). The straggler sweep is explicitly scoped to run **outside** `materials/{unit_id}/drafts/` — region members are expected files verified by the region check below, not strays.

**Outside** `materials/{unit_id}/drafts/`, the categorical bar holds verbatim: no student-submissions folder (any language), no draft-suffixed file, and no `plan.json` anywhere. A draft-suffixed file found in the landed snapshot **outside** the `drafts/` region is a **hard no-write**, never a mere screen-skip — that is the exact guarantee that keeps the validated subtrees byte-identical to a draft-free snapshot.

**Inside** `materials/{unit_id}/drafts/` (present only when the entry carries a `draft_documents` inventory), a **two-sided region check** runs: **every** file carries a draft suffix, **every** file is named in the entry's `draft_documents` inventory, and — the reverse direction — **every** `draft_documents` `filename` exists in the region (the same two-directional inventory check the validated channel gets). Submissions and `plan.json` stay categorically barred inside the region too. A bundle **without** a `drafts/` region takes exactly today's path — the region check is dormant, byte-identical in behaviour. A violation on **either** side takes the existing fix-or-no-write-rollback path (the index append still comes last), and the entry passes the schema shape gates. On failure: fix and re-verify; if unfixable, stop with prose — **the index has not been written yet, so the rollback is a no-write.** Removal of the partial snapshot folder is then *attempted* honestly: deletion on the workspace folder is unreliable, so if the folder cannot be removed, **name it to the teacher as safe to delete manually** — never claim a clean rollback that did not happen.

**Post-append verify (G-I8b):** the index file parses and the new entry is present and well-formed. If a **post-append structural** failure is unfixable, **rewrite the index file back to its pre-import content** — an in-place content rewrite is feasible on the workspace folder where deletion is not, and it is the never-fail-silently half of the rollback — then handle any snapshot leftovers as in G-I8a. **Never leave an index entry pointing at a snapshot that failed its verify.** (This index-rewrite rollback is only for a structural failure of the append itself; a freshness-gate outcome from G-I6 is never routed here — its remediation leaves the entry standing and flags the generator.)

**Confirmation prose (G-I9):** tell the teacher, in prose, what landed (title, creator, origin state), that it now sits in the library (Bibliothek) like any shelved unit, any warnings given (state / school-type mismatch, skipped files), that the inbound file itself can be deleted manually, and the natural next step: assign it to a class ("Einheit übernehmen") via the library flow — where the adaptation reminder and competency confirmation apply as usual. When the imported unit carried drafts (Entwürfe), name them too: that N Entwürfe landed with it, that they are recognizable as drafts (Entwürfe) and stay **unused until taken over**, and that taking the unit over ("übernehmen") will ask whether to take the drafts (Entwürfe) over as well.

### Import failure modes

| Failure | Behaviour |
|---|---|
| Corrupt / unreadable file | Refuse; "damaged in transit — ask for a re-export" (G-I2.1). |
| No / unparseable `manifest.json` | Refuse; "not a Thalura unit file"; for a plain ZIP of documents add the redirect hint (cannot import; ask for a Thalura package (Thalura-Paket)) and write no library entry (G-I2.2). |
| `bundle_kind: "workspace"` | Refuse-with-redirect to the backup / restore flow (G-I2.3). |
| Unknown `bundle_kind` | Refuse; suggest a plugin update (G-I2.3). |
| `format_version` greater than 1 | Block; "update the plugin, then import" (G-I2.4). |
| Missing required envelope / unit fields; `grade_level` shape fail; inventory inconsistent | Refuse; malformed — re-export (G-I2.5, G-I3). |
| Path traversal / absolute path / non-regular-file member | Refuse the whole file (G-I2.6). |
| Duplicate member paths (including case-insensitive duplicates) | Refuse the whole file (G-I2.6). |
| `contents[]` or `draft_contents[]` path with no matching archive member (missing member) | Refuse the whole import; incomplete / damaged — re-export (per-list completeness, G-I2.7). |
| Member exceeds declared `bytes` during extraction (either list) | Stop extraction; refuse the whole import (G-I2.7). |
| Per-member hash / size mismatch (validated or draft-region member) | Refuse the whole import (G-I5). |
| Extra payload file not in `contents[]` / `draft_contents[]` | Tolerated, not extracted, reported (G-I5). |
| Draft-channel early mismatch — a `draft_documents` filename undeclared in `draft_contents[]`, or a `draft_contents[]` member unnamed in `draft_documents` (either direction), or a populated channel with an absent/empty counterpart | Refuse cleanly before any write (G-I3 parallel). |
| Screened hazard (submissions / draft / `plan.json` / straggler) **not** in the `documents` inventory | Skipped and reported; import proceeds narrowed (G-I5). |
| Screened hazard **listed in** the `documents` inventory | Refuse the whole import — the entry must never reference a never-landed file (G-I5). |
| Draft-suffixed member outside `drafts/` or undeclared in `draft_contents[]` | Screened as today — skipped-and-reported; refused when `documents`-inventory-listed (G-I5). |
| Landed `drafts/` region two-sided check fails (unsuffixed region file / region file unnamed in `draft_documents` / `draft_documents` filename missing from the region) | No-write rollback; index untouched (G-I8a). |
| Draft-suffixed file outside the `drafts/` region in the landed snapshot | Hard no-write rollback — never a mere screen-skip (G-I8a). |
| `unit_id` collision | Re-sequenced locally, provenance verbatim; invisible to the teacher (G-I6). |
| Same title and creator already in library | Ask before importing a duplicate (G-I4d). |
| Same-title family in library (different creator) | Informative family cue; lands as its own family (G-I4d). |
| State / school-type mismatch | Warn; the teacher decides (G-I4b). |
| Subject not configured / not supported | Confirm-then-scaffold / refuse (G-I4c). |
| Landed-snapshot verify fails pre-append, unfixable | No-write rollback (index untouched); partial-folder removal attempted, unremovable leftover named to the teacher (G-I8a). |
| Post-append structural verify fails, unfixable | Index rewritten back to pre-import content; leftovers handled per G-I8a (G-I8b). |

---

## Notes

- Both flows run core session startup first and interact in `conversation_language`.
- The library tree under `data/` is internal English-lowercase storage; it is never surfaced to the teacher as raw JSON — every preview is prose.
- Export sends a file out of the workspace; import brings a file in and lands it in the library (Bibliothek). Shelving, assigning, and restoring stay inside the workspace and live in the library flow; whole-workspace backup and restore are a separate flow.
