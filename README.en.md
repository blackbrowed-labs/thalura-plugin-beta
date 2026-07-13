[🇩🇪 Deutsch](README.md) | 🇬🇧 English

# Thalura

A Claude Code plugin for lesson planning and assessment creation for Hamburg
secondary-school teachers (Gymnasium / Stadtteilschule). Grounded in official
Hamburg curriculum standards (Bildungsplan) and education authority
(Behörde für Schule und Berufsbildung, BSB) regulations.

## Support

☕ Enjoying Thalura? Support the development.

[![Support on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/blackbrowedlabs)

## What it does

Plan a school year, scaffold a teaching unit (Unterrichtseinheit), generate
differentiated worksheets (Arbeitsblätter), or build an assessment (Klausur)
with grading rubric (Erwartungshorizont) — all traceable to the curriculum
standards (Bildungsplan) for your subject and grade. Every output is checked
against official BSB regulations before delivery.

## Subjects

| Subject | German | Abbreviation |
|---|---|---|
| English | Englisch | E |
| Philosophy | Philosophie | P |
| Psychology | Psychologie | Psy |
| Religion | Religion | R |

## Installation

Thalura ships through two channels — pick one and add it as a marketplace in
Claude Code, then install:

**Stable** (general use):

```
/plugin marketplace add blackbrowed-labs/thalura-plugin-dist
/plugin install thalura@blackbrowed-labs
```

**Beta** (testers — upcoming releases):

```
/plugin marketplace add blackbrowed-labs/thalura-plugin-beta
/plugin install thalura@blackbrowed-labs
```

Run Claude Code from your teacher folder so the plugin finds your workspace.
Update with `/plugin update thalura@blackbrowed-labs`.

The full walkthrough — step-by-step install, Claude Cowork, getting started, and
updating — lives in the **[guide](guide/en/index.md)**.

## Quick start

```
/thalura:setup
```

Walks you through your teacher profile (Lehrerprofil), school configuration
(Schulkonfiguration), and preferences. Then just describe what you need, or type
`/` and pick a `thalura:` entry. See **[task modules](guide/en/aufgabenmodule.md)**
for everything Thalura can do.

## Project status

Active development toward v1.0, targeted for July 2026. Pre-1.0: anything may
change between minor releases. See [VERSIONING.md](VERSIONING.md).

## Documentation

- [Guide (English)](guide/en/index.md) — installation, getting started,
  updating, task modules
- [CHANGELOG.md](CHANGELOG.md) — release history
- [VERSIONING.md](VERSIONING.md) — versioning and changelog standard

## License

[MIT](LICENSE) © Lars Weiser / blackbrowed labs
