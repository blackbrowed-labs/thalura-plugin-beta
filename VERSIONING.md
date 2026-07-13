# Versioning & Changelog

This document is the versioning and changelog standard for the **public Thalura
plugin distribution**. It ships in both public channel repos and describes how
versions are numbered and how the two release channels relate. It is based on:

- [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html)
- [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/)

When this document and those specifications disagree, the specifications win
and this document is a bug.

---

## Versioning

### Where the version lives

`.claude-plugin/plugin.json` holds the single canonical version string and is
the **sole version authority**. The marketplace entry carries no version: if a
version were set in both places, `plugin.json` would win silently, so it is
declared in exactly one place.

**The manifest version always equals the most recently released version.** It
is bumped *as part of the release commit*, not at the start of a development
cycle.

### Version format

`MAJOR.MINOR.PATCH`, optionally followed by `-PRE_RELEASE`. The version is
**bare numerals everywhere** — no leading `v`. The git tag exactly matches the
manifest string. Per the
[SemVer 2.0.0 FAQ](https://semver.org/spec/v2.0.0.html#is-v123-a-semantic-version):
"`v1.2.3` is not a semantic version" — the `v` is a folk-tradition prefix
without spec backing.

### Bump rules — pre-1.0 (initial development)

Per SemVer §4, while the version is below `1.0.0` the public API is not
considered stable and "anything MAY change at any time." This project applies:

- **MINOR (`0.x` → `0.(x+1).0`)** — any new feature, breaking change, or
  significant behavior change.
- **PATCH (`0.x.y` → `0.x.(y+1)`)** — bug fixes only, no new behavior.

The first version intended for any external visibility is `0.1.0`.

### Reaching 1.0.0

`1.0.0` is cut when the public API is considered stable and a commitment to
backward compatibility is being made. After `1.0.0`, full SemVer rules apply.

### Bump rules — post-1.0

- **MAJOR (`X.y.z` → `(X+1).0.0`)** — incompatible API changes (SemVer §8).
- **MINOR (`x.Y.z` → `x.(Y+1).0`)** — backwards-compatible features (SemVer §7).
- **PATCH (`x.y.Z` → `x.y.(Z+1)`)** — backwards-compatible bug fixes (SemVer §6).

### Pre-release identifiers — what `-beta.N` means

A pre-release version (`MAJOR.MINOR.PATCH-beta.N`, per SemVer §9) is a version
that needs public validation before going final. In Thalura, `-beta.N` versions
ship to the **beta channel** and bare `X.Y.Z` versions ship to the **stable
channel** (see "Release channels" below). A given `X.Y.Z` typically appears as
one or more `X.Y.Z-beta.N` pre-releases first, then as the bare `X.Y.Z` once it
has soaked.

The `-dev.N` identifier (`MAJOR.MINOR.PATCH-dev.N`) is an **internal
development identifier** used on the private development channel. It is **never
published to the public beta or stable channels** — only `-beta.N` and bare
`X.Y.Z` versions are public.

---

## Release channels

Thalura is distributed through **two parallel public channels, each its own
GitHub repository**. You install from exactly one, by adding that repo as a
marketplace.

| Channel | Repository | Versions | Who it's for |
|---|---|---|---|
| **Beta** | `blackbrowed-labs/thalura-plugin-beta` | `X.Y.Z-beta.N` | Testers who want the upcoming release early and can tolerate rough edges. |
| **Stable** | `blackbrowed-labs/thalura-plugin-dist` | `X.Y.Z` | General users who want the soaked, released version. |

Each repo is **single-branch**: its default branch always holds that channel's
currently-shipping version. Both repos use the same marketplace name
(`blackbrowed-labs`), so the install verb is identical
(`/plugin install thalura@blackbrowed-labs`) — you only ever add one channel,
so the names never collide.

### How the channels relate

The beta channel carries the **upcoming** release; the stable channel carries
the **soaked** one. A version generally appears on beta as `X.Y.Z-beta.N`
first; once it is stable it is published to the stable channel as bare `X.Y.Z`.
The two channels are independent pools: a beta tester and a stable user can run
different versions at the same time, each updated when *their* channel's repo
is bumped.

When a version stabilizes, the bare `X.Y.Z` is published to the stable channel
**and** also advances the beta channel to that same `X.Y.Z` — so the beta
channel always holds the highest available build and a beta tester is never
behind a stable user. The next cycle's pre-release then moves beta ahead again.

Each channel repo accumulates a per-version git tag and an annotated GitHub
Release (with the changelog notes) for every published version, so you can
browse the release history or pin a specific version.

### Moving between channels

- **Joining beta:** add `blackbrowed-labs/thalura-plugin-beta` as a marketplace
  and install `thalura@blackbrowed-labs`.
- **Moving from beta to stable** (or back): add the other channel's repo URL as
  a marketplace and install from it; optionally remove the channel you left.
- **Your data is safe either way.** Teacher data lives in your own workspace
  folder, never inside the plugin install, so switching channels — or
  reinstalling — never touches it.

---

## Changelog

### File location and format

- Exactly one file: `CHANGELOG.md` at the repo root.
- Format: [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
  strict adherence.

### `[Unreleased]` section

Always present, immediately below the preamble. All changes since the last
release accumulate here, organized by category. Empty on a fresh release.

### Released version entries

- Heading format: `## [X.Y.Z] - YYYY-MM-DD` (plain ASCII hyphen, ISO-8601 date).
- Versions ordered most-recent first.
- A withdrawn release gets `[YANKED]` appended to its heading.

### Categories

Use only these six, in this order when multiple appear: **Added**, **Changed**,
**Deprecated**, **Removed**, **Fixed**, **Security**.

### Entry style

- **Noun-phrase only — never a leading verb** (the category heading supplies the
  verb): `- Support for X`, not `- Added support for X`.
- One concept per bullet; lead with the user-visible noun phrase.
- No emoji decoration.

### Compare links

The bottom of `CHANGELOG.md` carries reference-style links resolving
`[Unreleased]` and each `[X.Y.Z]` to diffs. The first released version uses
`releases/tag/`; every later version uses `compare/`; `[unreleased]` always
points from the most recent released tag to `HEAD`.

---

## Project-specific deviations

If a future need forces a deviation from this standard, document it prominently
at the top of `CHANGELOG.md` with the rationale.
