# Standard-Supplies Config Schema

The optional, teacher-maintained list of everyday classroom supplies (Standardmaterial) actually on hand. It is consumed as a **soft hint** that gently biases standard-supplies (Standardmaterial) proposals at lesson-proposal time — never a hard constraint, never an availability model.

## File Path

### Tier 1 — Plugin Default (base layer)

```
${CLAUDE_PLUGIN_ROOT}/config-defaults/standard-supplies.json
```

### Tier 2 — Teacher Override (project layer)

```
<WORKSPACE_ROOT>/data/config/standard-supplies.json
```

**Two-Tier:** This is a two-tier config file. The plugin default ships the base list; the teacher's project-level override replaces it whole when present. For the full overlay mechanism, see `${CLAUDE_PLUGIN_ROOT}/references/config-system.md`.

## Shape

One top-level object with a single key:

```json
{
  "standard_supplies": [
    "Post-its (3 Farben)",
    "Kreppband",
    "Whiteboard-Marker",
    "A3-Papier",
    "Stifte"
  ]
}
```

- **`standard_supplies`** — the sole top-level key. An English data key, deliberately matching the existing document-heading key family so the data key, the document heading, and the glossary pair all line up.
- **Value** — a free-text array of supply strings. The strings are *teacher-owned free text*: the teacher strikes defaults they lack and adds items they have, in whatever wording they use themselves. The shipped default values are German-first; after the first edit the file's language is whatever the teacher writes.
- **Order is teacher-meaningful but not contractual** — the list is a hint, not a ranking. Consumers must not attach semantics to position.

The wrapper object (rather than a bare top-level array) gives the list a named key so it is a well-defined override unit for the two-tier merge, keeps the file shape-consistent with the other two-tier config files, and leaves room for future sibling keys without a format break.

## Merge/Resolution — whole-value override

At read time the effective list is:

```
effective = teacher override value  [if the standard_supplies key is present in data/config/standard-supplies.json]
         else  plugin default value  [from config-defaults/standard-supplies.json]
```

This is a **whole-value replacement at key granularity, never an element-wise union or merge.** When the teacher's file carries the `standard_supplies` key, its array replaces the plugin default array entirely — the two lists are never combined element by element. An element union would resurrect struck defaults and defeat the core gesture ("strike the defaults you lack"), so it is deliberately excluded. The teacher's file is never patched at read time.

## Empty-list ≡ no-declaration semantics

An effective list that is **empty (`[]`), absent, or unreadable/malformed means "no declaration"** → consumers behave **exactly as today** (the assumed everyday set at proposal time). This is **fail-open, never blocking**: a broken or missing config file must never stall a lesson proposal.

An empty list does **not** mean "the teacher has nothing" — there is deliberately no way to express that. The list is a soft hint by design; the absence of a declaration falls back to today's behaviour, not to a claim of an empty inventory.

## Soft hint — not a constraint

The list is a **bias input to proposal content**, and nothing else:

- It **biases** standard-supplies (Standardmaterial) proposals toward the listed items when the effective list is non-empty: where pedagogically equivalent supply choices exist, a listed item is preferred over an unlisted one, and listed non-standard items are treated as live planning vocabulary.
- An **unlisted item stays proposable** whenever the lesson design genuinely calls for it.
- It is **never** a hard restriction, **never** an availability flag or "not on the list" / "unavailable" warning, **never** a prompt to confirm availability, and **never** a reason to weaken a pedagogical choice to fit the declared inventory.
- It is **not a rendering contract** — the strings need not be copied byte-for-byte; the runtime renders a supply naturally in the document's resolved content language.

## Consumed By

| Consumer | Role |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/skills/lesson-detail/SKILL.md` | The **sole content consumer** — resolves the effective list via the two-tier read and biases its standard-supplies (Standardmaterial) proposals toward it at lesson-proposal time (soft hint; bias, prohibitions, and fail-open per the contract above). |
| `${CLAUDE_PLUGIN_ROOT}/skills/config/SKILL.md` | The **editing surface** — `/thalura:config supplies` shows the effective list, edits it (add / remove / replace / reset), and writes `<WORKSPACE_ROOT>/data/config/standard-supplies.json`. |

The material overview (Materialübersicht) does **not** read this file directly. It stays a pure aggregation of the lesson plans; the hint reaches it only via the biased lesson proposals it aggregates.

## Design Notes

- **State-agnostic.** No issuer, authority, school type, or federal-state name appears in this schema or in `${CLAUDE_PLUGIN_ROOT}/config-defaults/standard-supplies.json`. Everyday classroom supplies (Standardmaterial) are universal across every deployment context, which is exactly why the category lives in `config-defaults/`.
- **No new supply vocabulary out of the box.** The shipped default set is exactly the everyday set the plugin already assumed, so a freshly seeded workspace can only bias proposals toward already-assumed items — never toward a new or unfamiliar supply.
- **No onboarding question.** The file is seeded silently at setup by the generic `config-defaults/` copy; the teacher first meets the feature via the guide or `/thalura:config supplies`.
- **Backup/restore.** The whole `<WORKSPACE_ROOT>/data/config/` directory is already in the workspace-backup scope, so the teacher's list survives backup and restore with no additional handling.
