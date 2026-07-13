# Scaffold Completion — the shared check-and-complete routine

One idempotent routine that verifies a teacher workspace carries the complete
setup scaffold and creates whatever is missing — **create-only**, never
overwriting anything that already exists. It exists so that every path that can
produce a workspace converges on the same scaffold a fresh onboarding would have
produced: first-run setup, a workspace restore, and a repair after partial loss
all end with the identical directory tree and starter files. The routine detects
deterministically (via `${CLAUDE_PLUGIN_ROOT}/scripts/scaffold-status.sh`, which
only reads) and then performs the localized, judgment-bearing writes itself.

## Callers and preconditions

**Callers:**

- **Setup** — as a post-write self-verification, after the file-writing phase, to
  catch any scaffold write that was dropped on the fresh path.
- **Restore** — on every completing full workspace restore (the direct-init
  branch and the standard restore-into-a-set-up-workspace path alike), because
  the landed profile's subjects may not match the scaffold the setup interview
  once conditioned on.
- **Setup's repair mode** — when setup runs on a workspace whose profile already
  exists and the teacher chooses to check and complete the scaffold.

**Preconditions:** the workspace root and the plugin root are already resolved
(both are passed to the detection script — neither is self-discovered), and a
teacher profile exists. This routine completes the scaffold **around an existing
identity**; it never creates a teacher profile and never creates a school
configuration. A workspace without a profile is not set up — that is the setup
interview's job, never this routine's. If the script prints
`scaffold=no-profile` (exit 10), the precondition is violated — do not proceed.

## The loop

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/scaffold-status.sh <PLUGIN_ROOT>
   <WORKSPACE_ROOT>` (both roots passed in — never self-discovered here). It
   prints one token per missing or degraded item, or the single line
   `scaffold=complete`.
2. `scaffold=complete` → done. Report in one line, in the profile's
   `conversation_language`, that the workspace is complete and nothing needed
   creating.
3. Otherwise, act on **every** token per the action table below. All writes are
   **create-only**: create a directory only when it is missing (`mkdir -p`
   semantics), copy or write a file only when the target does not already exist.
   Localized content (README text, folder names) is translated into the
   profile's `conversation_language` at write time. Branding tokens run the
   branding branch below.
4. **Re-run the script.** Proceed only when the re-run reports
   `scaffold=complete`, **or** when every token still present is an honestly
   flagged residual — the branding clean-stop state; a recorded logo asset that
   is genuinely missing (`branding=configured logo=missing:<file>`); or a missing
   school-settings file (`school_config=missing`). Never proceed silently over a
   token that is neither cleared nor flagged — a silent proceed over an
   uncleared, unflagged token is a contract violation.
5. **Report in prose**, in `conversation_language`: what was created, what was
   verified already present, and every flagged residual, named plainly. On the
   restore call site this report folds into the restore summary; on the setup
   call site into setup's closing summary; in repair mode it is the outcome
   message.

If the script prints `scaffold=unknown` (its fail-open state — an unreadable
profile, a missing reference file), fall back to **walking the action table's
checks manually**: verify each target the table lists and create the missing
ones under the same create-only rule, and say in the report that automatic
detection could not run and the checks were done by hand.

## Action table

One row per token the script can emit. Workspace-relative targets are written
under `<WORKSPACE_ROOT>/`; shipped sources are read from `${CLAUDE_PLUGIN_ROOT}/`.

| Token | Action |
|---|---|
| `dir=missing:<path>` | Create the directory `<WORKSPACE_ROOT>/<path>` (create-only; parents as needed). |
| `config_default=missing:<file>` | Copy `${CLAUDE_PLUGIN_ROOT}/config-defaults/<file>` → `<WORKSPACE_ROOT>/data/config/<file>`. Two-tier rule: copy only if the workspace copy is missing; never overwrite an existing one. |
| `exam_template=missing` | Copy `${CLAUDE_PLUGIN_ROOT}/references/exam-formats/_template.md` → `<WORKSPACE_ROOT>/data/exam-formats/_template.md` (create-only). |
| `library_index=missing:<subject>` | Write `<WORKSPACE_ROOT>/data/library/<subject>.json` with the empty library skeleton: `{ "subject": "<subject>", "units": [] }`. Never overwrite an existing index. |
| `sic_readme=missing` | Write `<WORKSPACE_ROOT>/data/regulations/sic/README.md` by translating `${CLAUDE_PLUGIN_ROOT}/skills/setup/sic-readme-template.md` into `conversation_language`. Existence check only — if the file already exists, skip; never overwrite. |
| `readme=missing` | Write `<WORKSPACE_ROOT>/data/README.md` by translating `${CLAUDE_PLUGIN_ROOT}/skills/setup/data-readme-template.md` into `conversation_language`. Existence check only — never overwrite. |
| `year_scaffold=missing:<year>` | An informational header only: it marks a workspace that carried no school years at all, for which the routine adopts the derived current year. The concrete writes for `<year>` arrive as its own `dir=missing:…` and `plan_skeleton=missing:<year>` tokens — act on those. Tell the teacher, in the report, that the class question comes at first planning; **this routine never asks it**. |
| `plan_skeleton=missing:<year>` | Write `<WORKSPACE_ROOT>/data/school-years/<year>/plan.json` with the empty skeleton: `{ "school_year": "<year>", "plans": [] }`. Never overwrite. |
| `output_root=missing:<subject>:<year>` | Create the localized output folder `<WORKSPACE_ROOT>/<localized_subject_name>/<year>/`, where `<localized_subject_name>` is resolved from `${CLAUDE_PLUGIN_ROOT}/references/localization.json` → `<conversation_language>.subjects.<subject>` (e.g. `de.subjects.english` → `Englisch`). |
| `profile_shell=missing:<file>` | Write the empty shell `<WORKSPACE_ROOT>/data/profiles/<file>` — the same initial structure setup writes for that file (see below). Never overwrite an existing shell. |
| `version_stamp=missing` | Write `<WORKSPACE_ROOT>/data/version.json` stamped at the installed plugin version (read from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`). **Create-only** — a `version.json` that already exists is never touched, so a restored backup's stamp keeps its forward-defer-to-migrate semantics. |
| `school_config=missing` | **Cannot be created here** — this routine never invents identity. Flag it honestly in the report: the school-settings file is missing; the teacher can restore it from a backup or re-enter the school details via the configuration flow. No branding action runs while it is absent. |
| `branding=configured logo=missing:<file>` | See the branding branch — logo verification: flag, never invent. |
| `branding=configured template=<state>` | See the branding branch — the template state machine. |

**Profile-shell structures** (`profile_shell=missing:<file>`) — write exactly the
structures setup seeds; both are short enough to inline here:

- `teacher-preferences.json`:

  ```json
  {
    "version": "1.0",
    "last_updated": null,
    "slide_preferences": {
      "accessibility_mode": true,
      "font": null,
      "body_font_size": null,
      "title_font_size": null,
      "line_spacing": null,
      "max_bullets_per_slide": null
    }
  }
  ```

- `teacher-observations.json`:

  ```json
  {
    "version": "1.0",
    "last_updated": null,
    "promotion_threshold": 3,
    "categories": {
      "method_acceptance": {},
      "method_rejection": {},
      "social_form_acceptance": {},
      "social_form_rejection": {},
      "format_preference": {},
      "style_preference": {},
      "assessment_format": {}
    }
  }
  ```

  (These mirror `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-preferences.md`
  and `${CLAUDE_PLUGIN_ROOT}/references/schemas/teacher-observations.md`. If either
  schema has evolved, follow the schema.)

## Branding branch

Runs only when `school-config.json` carries a **non-null `branding` object**. A
`null` or absent `branding` block is a *correct*, neutral state — nothing to
verify, nothing to regenerate, and no flag: the neutral bundled template is the
right template, so the branding branch does nothing at all in that case.

**Logo verification** (`branding=configured logo=missing:<file>`). For each logo
path the branding block records, the detection script has already confirmed the
recorded asset is absent on disk. **Flag it honestly; never invent one.** Name
exactly which file is missing and tell the teacher they can re-provide the logo
via the configuration flow (school branding). Do **not** re-run auto-detection,
do **not** download anything, and do **not** strip the branding block. A
palette-only branding block that records no logo paths has nothing to verify —
that is a valid state, not a flag.

**The branded slides template** (`branding=configured template=<state>`). The
template file itself never travels in a backup — it is regenerable by contract —
so it is regenerated in place. Regeneration goes through the **same** path the
school-configuration branding flow uses: the deck is authored by the **official
PPTX skill** per the template specification
(`${CLAUDE_PLUGIN_ROOT}/references/template-specification.md`), preferably via a
runtime sub-agent, with the same inline fallback when the sub-agent does not
return a usable deck — never a hand-rolled generator. The write is **atomic**,
and the new file's SHA-256 is recorded into `branding.template_hash` in
`school-config.json`. The action depends on the state:

- **`template=absent`** (a hash is recorded but the file is missing) and
  **`template=palette-only`** (no hash and no file — a prior clean-stop or a
  palette-only setup): both **attempt generation now**. An onboarding with a
  reachable PPTX capability would have produced the branded deck, so the
  restored workspace must match that. On success, update `template_hash` and
  report that the branded template was generated in the school colors. Treating
  `palette-only` as "leave it alone" would ship exactly the silent-neutral hazard
  this routine exists to prevent: the outcome is either the branded template or a
  fresh, explicit flag — never silence.
- **Clean-stop on unreachability.** If the official PPTX skill is unreachable in
  this environment (in both the sub-agent and the inline fallback), **do not
  write the file**: set `branding.template_hash` to `null`, keep the saved
  palette and any logo variants, tell the teacher plainly that this is a tooling
  limit and not a loss — the school colors are saved; presentations use the
  neutral template until the branded one can be generated (the next slides
  creation, or the school-branding configuration flow, retries) — and stop
  cleanly, no error. (Runtime-translated into `conversation_language`, in the
  tone of setup's own branded-template note.)
- **`template=modified`** (the file is present but its hash does not match the
  recorded one) and **`template=unstamped`** (the file is present but no hash is
  recorded): the action is **call-site-dependent**.
  - **On the restore call site** → **regenerate and inform, without asking.** The
    landed `school-config.json` is authoritative; the on-disk template is stale
    pre-restore output (setup generated it and stamped its hash into setup's
    config, then restore landed the backup's config verbatim over that stamp).
    The template embodies no teacher edit, so the configuration flow's "your
    changes will be overwritten" question would be wrong and misleading here.
    Regenerate for the restored school colors and give a plain notice that the
    slides template is being rebuilt — no question.
  - **In repair mode or setup's self-verification** → the file's provenance is
    unknown and a teacher edit is plausible, so **ask before overwriting**, using
    the configuration flow's manual-change question ("Your slides template has
    been modified since it was last generated. Regenerating will overwrite your
    changes. Continue?"). If the teacher declines, keep the file untouched and
    flag the out-of-sync state in the report.
- **Same-session exemption (setup call site only).** When setup's branding phase
  already ran its own template-generation attempt earlier in this same session —
  whatever its outcome — the setup self-verification does **not** re-attempt: it
  reports the current template state and moves on. No duplicate sub-agent
  dispatch, and no second honest note minutes after the first.
