# Bundle Manifest Schema

> The shared envelope for every family bundle. A bundle is a portable archive with one top-level `manifest.json` (this envelope) and a `payload/` content tree. This document is the single normative definition of the envelope; the flows that **pack** and **unpack** archives (unit export/import; workspace backup/restore) build on it — the envelope itself carries no packing logic.

## Container Layout

A family bundle is a **tar.gz** archive with a custom extension (never surfaced to the teacher as a tar/zip):

```
<bundle root>
  manifest.json          ← the envelope (below)
  payload/               ← the content tree
    …                    ← profile-specific; the unit profile is defined below
```

Detection **trusts the manifest, not the extension**: a consumer reads `manifest.json` first and routes on `bundle_kind`; a renamed file is identified by its manifest and redirected or refused, never mis-processed.

## Envelope Grammar (`manifest.json`)

| Field | Type | Required | Description |
|---|---|---|---|
| `format_version` | `number` | yes | Envelope format version, `1`. Bumped **only** on a breaking structural change; consumers must **not** fail on unknown fields or extra payload files (forward-compatibility rule). |
| `plugin_version` | `string` | yes | Plugin version that created the bundle. |
| `bundle_kind` | `string` | yes | Discriminant: `"unit"` (a single-unit bundle) or `"workspace"` (a whole-workspace backup). Consumers route on this field. |
| `created_at` | `string` | yes | ISO-8601 creation timestamp. |
| `creator` | `string` | yes | Display name of the creating teacher. |
| `federal_state` | `string` | yes | Creating workspace's federal-state ID. |
| `school_type` | `string` | yes | Creating workspace's school-type ID. |
| `conversation_language` | `string` | yes | Creating workspace's conversation language (`"de"`, `"en"`, …) — the portability axis: payload subfolder names are canonical keys, and they are re-localized only when the material enters a class tree (assign), into the *target* workspace's language. |
| `contents` | `array` | yes | One object per payload file: `{ "path": "<payload-relative path, canonical subfolder keys>", "sha256": "<hex>", "bytes": <number> }`. Makes extraction verifiable, the submissions exclusion auditable, and per-member integrity checking automatic. **Class-neutrality is a `unit`-profile property, not a universal one:** because a unit payload is a snapshot (below), a `unit`-profile `contents[]` path carries **no class identifiers** — neither in folder names nor in filenames. A **`workspace`-profile** payload instead **keeps its class-bound output filenames** (a whole-workspace backup restores to the *same* teacher's *same* classes, so the class prefix is correct); only the *subfolder* names are canonicalised there (see the workspace-profile layout below). |
| `draft_contents` | `array` | no | Present **only** in a `unit` bundle, and only when the exporting teacher opted their in-progress drafts (Entwürfe) in — absent or empty otherwise. One object per **draft** payload file — `{ "path": "<payload-relative path under the drafts/ region>", "sha256": "<hex>", "bytes": <number> }`, the **same shape** as `contents[]` (per-member integrity checking is therefore automatic over both lists). It describes a structurally separate draft channel: `draft_contents[]` and `contents[]` are **disjoint**, and the normative constraints on this list (region confinement, draft suffix, class-neutrality, never-localized keys) are stated with the `drafts/` region in the unit-profile payload layout below. |
| `unit` | `object` | when `bundle_kind: "unit"` | The reconciled library entry (see the library-subject schema) **minus** `source_class` and `materials_path` (workspace-internal fields, stripped on export). The importing consumer writes `source` as its own view (`"external"`). The field list is normative here; the exact strip/rewrite steps belong to the export/import flow. |
| `workspace` | `object` | when `bundle_kind: "workspace"` | The workspace profile body — defined by the backup/restore flow; this document reserves the key and the discriminant only. |

## Unit-Profile Payload Layout

```
payload/
  <unit_plan filename>.docx        ← unit plan document (snapshot root)
  lessons/…                        ← canonical keys; class-neutral, localized FILE names
  materials/…                        (validated channel — unchanged)
  assessments/…                    ← may contain numbered subfolders
  drafts/                          ← NEW, optional; present iff draft_contents[] is non-empty
    lessons/…                        canonical keys; draft-suffixed, class-neutral FILE names
    materials/…
    assessments/…
```

The **validated** payload tree — everything outside the optional `drafts/` region — is **identical to a draft-free library snapshot** (equivalently: the validated channel of a drafts-carrying imported snapshot): a unit bundle's validated channel **is** a snapshot, and its `unit` body **is** a library entry. The optional `drafts/` region is a strictly separate draft channel (below), present only on explicit opt-in.

- Subfolder names are **canonical (locale-neutral) keys** — `lessons` / `materials` / `assessments` — never localized names. Import lands the payload with its canonical keys as-is; the keys are re-localized only when the material enters a class tree (assign), into the target workspace's `conversation_language`.
- Filenames are the **class-neutral** snapshot names: the class-identifying `{subject_abbr}{grade}` prefix is stripped when the snapshot is taken, so the payload inherits class-neutral names for free.
- **Draft channel (`drafts/` region) — optional, opt-in only.** When the exporting teacher opts their in-progress drafts (Entwürfe) in, a unit payload additionally carries a `drafts/` region, enumerated by the parallel `draft_contents[]` list. The channel is **strictly separated** from the validated channel and governed by these normative constraints:
  - `draft_contents[]` and `contents[]` are **disjoint** — no path appears in both lists.
  - Every `draft_contents[]` path lies under the **`drafts/` region**, and its filename carries a **draft suffix** (some language's `system_labels.draft_suffix`).
  - No `contents[]` path lies under `drafts/` — the validated list never reaches into the draft region.
  - **Class-neutrality applies to both lists identically:** a `unit`-profile path carries **no class identifiers** in any folder name or filename, in `contents[]` and `draft_contents[]` alike (the snapshot property above, now stated over both lists).
  - `drafts/` and its sub-subfolders `drafts/lessons`, `drafts/materials`, `drafts/assessments` are **canonical, locale-neutral keys — never localized** (the same discipline as the three validated canonical keys). Region membership is therefore a **language-independent path-prefix test**; the localized draft suffix is a **secondary, within-region label check**, never the primary discriminator.
- **The one universal exclusion (both profiles):** student submissions (the localized submissions folder, resolved from the source workspace's `conversation_language`, at any depth) are **never included in any profile** — the hard privacy rule. It covers the `drafts/` region too: **no submissions path may appear anywhere, in either list.**
- **`unit`-profile exclusions:** the unit manifest (`plan.json`) and the material-overview document remain **categorically excluded** from a `unit` payload — a shelved snapshot regenerates both on assign, so neither ever travels in a unit bundle. **Draft-suffixed files are excluded from `contents[]` and the validated tree** and may travel **only** via `draft_contents[]` / the `drafts/` region — and **only at the exporting teacher's explicit opt-in** (ask-first; the default is exclude, and no draft is carried without an explicit yes). All three (`plan.json`, the material-overview, and draft-suffixed files) are instead **included in the `workspace` profile** (see below): a whole-workspace backup exists to preserve exactly the teacher's in-flight draft (`_ENTWURF`) work, its restore has **no** regeneration step (unlike assign, so the material-overview must travel or every restored unit's `plan.json` would track a missing document), and the per-unit `plan.json` is the referential anchor the restore's integrity pass reads.

## Workspace-Profile Payload Layout

Present when `bundle_kind: "workspace"`. A whole-workspace backup is a **curated differential**: teacher-authored and irreplaceable state is carried, while reinstall-recoverable shipped files, regenerable caches, and transient scratch are left out. The payload spans **two roots** — the curated data tree and the generated document (output) tree:

```
payload/
  data/                ← curated data tree (authored + irreplaceable state)
    school-years/…        (year plans + class definitions)
    library/…             (entries + materials/{unit_id}/ — canonical subfolder keys)
    profiles/…            (teacher profile, school config, preferences, observations)
    config/…              (the teacher's naming/config overrides — the whole directory)
    assets/…              (teacher-placed branding assets)
    regulations/sic/…     (the teacher-authored school-internal curriculum tree)
    version.json          (the data-tier version stamp — drives the restore version bridge)
  outputs/             ← the generated document folders
    {subject}/{year}/{class_id}/{unit_slug}/…   ← {subject} = canonical id, NOT the localized folder name
```

- **Canonical-key-internal, re-localized on restore.** Every localized document subfolder inside a unit output folder (`lessons` / `materials` / `assessments`) is stored under its **canonical key** in the payload; restore re-localizes them into the *target* workspace's `conversation_language`. This is the same canonical-key discipline a `unit` payload uses. Library `materials/` snapshots already travel canonical-key.
- **The subject segment is stored as its canonical id** (for example `outputs/english/…`, never the localized `outputs/Englisch/…`); restore re-localizes it into the target workspace's language via the `subjects` map. Storing the localized name verbatim would split a cross-locale restore across two locale spellings.
- **Document filenames travel as-authored** — a `workspace` payload keeps the output filenames' own class prefixes (correct, because a backup restores to the *same* teacher's *same* classes). Only the subject segment and the subfolder keys are canonicalised.
- **No submissions folder appears anywhere** in the payload, in any profile (the universal exclusion above).
- Detection **trusts the manifest**: a consumer reads `manifest.json` and routes on `bundle_kind: "workspace"`; a `unit` bundle renamed to look like a workspace backup is identified by its `bundle_kind: "unit"` and refused or redirected, never mis-processed.

## Workspace Object

Present **iff** `bundle_kind: "workspace"`. It carries everything a consumer needs to make its safety decisions **from the manifest alone**, before extracting anything:

Every field below is **required when `bundle_kind: "workspace"`** (they are absent in a `unit` bundle):

| Field | Type | Required | Description |
|---|---|---|---|
| `data_version` | `string` | when workspace | The backed-up data-tier version (equal to the envelope's `plugin_version` at backup time). Carried here so the consumer's version-skew check needs no payload read; it drives the reverse-skew decision. |
| `scopes` | `array` | when workspace | The curated scopes the payload actually carries, drawn from `{ "data", "library", "outputs", "sic", "assets" }` (reflects the teacher's opt-outs). `"data"` (profiles + config + school-years + version stamp) is always present. Used for the referential-closure check and the prose preview. |
| `inventory` | `object` | when workspace | The **semantic** content summary — the collision-detection basis. It is **never** built from filesystem modification times: on a disaster-recovery clone every file's timestamp is set at copy time, so a timestamp-based freshness check is unreliable on exactly the machines a backup targets. |
| `counts` | `object` | when workspace | Compact totals for the preview: `{ school_years, classes, units_in_plans, library_units, output_folders }`. Redundant-but-cheap, so the preview renders without walking `inventory`. |

`school_id` is **not** duplicated into this object — it lives authoritatively in the payload's school-config file; surfacing it here would risk drift and is unneeded for the manifest-only peek.

### `inventory` shape (semantic collision basis)

```json
"inventory": {
  "school_years": [
    { "year": "2025-26",
      "classes": [
        { "class_id": "E10a", "subject": "english",
          "previous_year": null,
          "units": [ { "title": "Globalisation", "semester": 1,
                       "status": "completed",
                       "updated_at": "2026-01-20T14:00:00Z" } ] }
      ] }
  ],
  "library": [
    { "subject": "english",
      "units": [ { "unit_id": "lib_globalisation_001", "title": "Globalisation",
                   "shelved_at": "2026-02-24T09:00:00Z" } ] }
  ]
}
```

- `units[].updated_at` is the **semantic** freshness stamp — the source unit entry's own last-modified timestamp, falling back to its creation timestamp when never modified. It is **never** a filesystem modification time.
- `library[].units[]` carries `unit_id` (the identity for additive-merge dedup on restore) plus a `shelved_at` / `imported_at` stamp.
- The `class_id`, unit titles, and library ids here are the teacher's **own** labels — the teacher-facing identifiers they already work with, not student data — in a manifest the teacher created and can read.

## Versioning

`format_version` is shared between the envelope and the unit body (one family format). Version `1` is defined here. The compatibility *check* is shared; the compatibility *policy* (warn vs. block on an unknown version) belongs to the consuming flow.

The **`workspace` profile's** version policy is a plugin-version-skew rule, decided by the restore flow from `workspace.data_version` against the installed plugin version, following standard semantic-version precedence (including pre-release ordering):

- **Reverse skew — the backup is *newer* than the installed plugin → block.** A newer backup may use schema or features the installed plugin cannot read; the consumer refuses and asks the teacher to update the plugin first, then restore.
- **Equal or forward skew — the backup is the *same* or *older* → proceed.** Restore lands the backup's data-tier version stamp as-is and defers any forward migration to the plugin's own first-startup update path; the consumer does not migrate inline.

## Consumer Obligations

A short, shared note so every consuming flow inherits the same handling from one place:

- Stage an archive **session-local** and copy it once into place — never build directly on the workspace mount.
- After copying, **verify by hash** and sweep for orphaned temporary files.
- On extraction, verify each member against `contents[]`.
- On inbound, **list before extract** with a path-traversal screen and an isolated extraction area — never a silent import.
