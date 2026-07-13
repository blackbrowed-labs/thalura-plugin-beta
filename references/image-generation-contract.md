# Image-Generation Tool Contract

The single authoritative statement of the image-generation tool contract as **the
plugin depends on it** — the arguments the plugin passes, the result it consumes, the
error classes it tolerates, and the verify-then-escalate-or-flag loop that governs
acceptance. Everything else points here; this file never repeats a rule stated elsewhere.

**Consumers.** The material-generation flow (The Playbook) reads the gate, the arguments,
and the consumption rules to call a conforming tool and record its result. The embed step
reads the result shape and the recorded metadata to swap bytes into a document and render
the citation. Later flows read the reserved `refs` slot (character consistency) and document
the wiring of a conforming server against this same contract. One home, many readers.

**Gate-defined and tool-independent.** This contract names the *properties an output must
have* and the *behaviour the plugin guarantees* — never a mechanism, a specific tool, a
server, a provider, or a model. A tool "conforms" when it satisfies the properties below,
whatever it is called and however it is implemented. The runtime selects the tool; the
contract is the permanent surface. All prose here is state-agnostic and cite-free.

---

## Capabilities

Machine-readable capability declaration. This is the **one and only home** of the value.

```
embed_capability: absent
```

<!-- The tool-present branch of material generation (both its proposal wording AND the
     generate-image call) is textually conditioned on this capability value. While it
     reads `absent`, that branch stays dormant and the plugin behaves byte-for-byte as the
     manual placeholder flow. The auto-embed work flips this to `present` in THIS
     file, in the same edit that lands the document-embed capability. The value set is
     exactly {absent, present} — no third state. -->

The tool-present branch requires **both** a conforming tool detected (the gate below) **and**
the capability value above reading `present`. Either condition unmet ⇒ the manual placeholder
path, unchanged.

---

## The availability gate

An image-generation tool is **available** when the session exposes a callable tool whose
name **ends in `generate_image`**. The match is on the **trailing tool name only** — never
on a server name or prefix (a tool surfaced under a server-prefixed name matches on its
trailing segment).

- **Detection is name-match only; the call is the verifier.** The floor is the trailing-name
  match. The parameter surface is **not** assumed to be eagerly inspectable — tools may
  surface by name with their schemas fetched on demand — so a name-matched tool whose actual
  surface rejects the call falls to the per-image fallback. Where the runtime *does* cheaply
  expose a schema, an optional pre-check that the tool accepts a `prompt` parameter may narrow
  false positives, but it is a **courtesy filter, never a correctness dependency** (the other
  arguments are optional by design; their absence from a tool's schema is never a mismatch).
- **When evaluated.** Twice, cheaply. At **proposal time** it sets *wording only* (automatic
  vs. manual). At **call time** it is **authoritative** — re-verify before the first call, as
  tools can appear or vanish in between. Manual-at-proposal but present-at-call ⇒ still
  generate (strictly better; note it in the confirmation). Automatic-at-proposal but
  absent-at-call ⇒ placeholder path for all images plus one flag line, never a hard error.
- **Multiple conforming tools.** Use the **first** conforming tool in the session's inventory
  order; never fan one image out to several tools.

---

## Arguments the plugin passes

The plugin calls the tool with:

| Argument | Required | Value |
|---|---|---|
| `prompt` | yes | The full English image prompt (Bild-Prompt) **verbatim** from the material plan (`plan.json`) — the single source of truth. Never rewritten, never forked. |
| `aspect_ratio` | yes | A first-class explicit argument, equal to the placeholder's EMU `cx:cy` ratio, so a swapped image lands distortion-free. |
| `print_optimized` | yes | The material's print flag, from the material preferences. |
| `provider` | no | Pass-through override — passed **only** when config supplies it. |
| `model` | no | Pass-through override — passed **only** when config supplies it. |
| `size` | no | Pass-through override — passed **only** when config supplies it. |
| `refs` | no | **Reserved** — passed through when supplied by a future flow, **never populated by this flow**. |

**The plugin never originates a provider or model identifier.** The shipped default supplies
none, so `provider`/`model`/`size` are omitted and the tool's own configured defaults govern.
They ride the call only when an explicit config value sets them.

**Prompt redundancy is accepted; explicit arguments win.** The stored prompt begins with a
technical first line (its aspect/resolution note) because the manual flow needs it in-text.
The tool-present path passes that prompt **verbatim** *and* passes `aspect_ratio` explicitly;
a conforming tool resolves geometry from the **explicit argument**, not the prose line. One
prompt serves both branches with zero drift.

---

## Result shape

A conforming tool returns a **two-item payload**:

```
[
  ImageContent,   # the image: base64-encoded PNG bytes carried in the content block
  { model, mime, watermark, provider, cost_estimate_usd }   # the metadata dict
]
```

- The image **bytes ride the content block** (`ImageContent`), base64-encoded PNG. There is
  **no `image_path` field and no `image_b64` field** anywhere in this payload.
- The metadata dict carries `model` (the identifier actually served), `mime`, `watermark`
  (**one or more** watermark tags — a provider may emit several at once — or absent;
  passed through opaquely, single value or list), `provider` (the provider identifier), and
  `cost_estimate_usd`.
- **Reserved extension — a returned filesystem path.** A future tool that *shares a filesystem*
  with the client could return a readable path to the PNG instead of base64. That leg is
  handled by the consumption rules below but is **not the current case** — no field in the
  payload above carries such a path. It is documented so a future shared-filesystem tool
  needs no contract change, not because any conforming tool returns it today.

---

## Consumption rules

Applied **per image**, as a verify-then-escalate-or-flag loop:

1. **Path leg (reserved).** If the result carries a filesystem path that resolves to a
   **readable PNG** in this session, use it directly (the bytes never enter the reasoning
   loop). Not the current case; present only for future shared-filesystem tools.
2. **Base64 leg (the current case).** Otherwise decode the `ImageContent` base64 and **write
   it to disk immediately** in a session-scoped transient location — **never** a
   teacher-visible output folder, so no orphan image files appear in the workspace. The
   decode-and-write is mechanical; the bytes are **never quoted, summarized, or re-read into
   chat**.
3. **Verify before accepting.** The written file must be a **non-empty** file with a
   **readable PNG header**, and the returned `mime` must be **`image/png`**. A non-PNG,
   empty, or unreadable result is a **failed generation** ⇒ the per-image fallback below.
4. **Read the actual dimensions client-side** from the PNG header — **not** from a metadata
   field (the payload carries none). A conforming tool may legally return the
   nearest-supported dimensions, so the plugin reads the actuals itself rather than trusting
   the request, and the downstream embed reconciles sizing instead of silently distorting.
5. **Record** from the metadata dict: `model` (the **served** identifier — authoritative for
   the citation, and it may differ from any recommendation), `provider` (the identifier that
   drives the citation-display data map below), and `watermark` (recorded for labeling).
   `cost_estimate_usd` is **informational only** and is not persisted.

The plugin's responsibility ends at a **verified PNG on disk plus recorded metadata**. Swapping
the bytes into a document and flipping the manifest `status` are the embed step's concern, not
this contract's.

---

## Error classes

The plugin **tolerates** all of these classes, and every one maps to the per-image fallback:

- invalid request
- content filtered
- rate limited
- provider error
- auth error
- budget exceeded

**No plugin-side retry.** A conforming tool retries the transient classes internally, so **any
returned error is final for that image**. The plugin never re-issues the call.

---

## Per-image graceful degradation

For each approved image, **any** failure on the tool path — call rejected, error class
returned, result fails PNG verification, or the embed step reports failure — yields:

1. **That image's manual placeholder outcome, verbatim** — the same placeholder, comments,
   citation-footnote template, and `status` the fully-manual flow produces.
2. **One localized flag line** in chat naming the image and the failure in teacher terms.
3. **No abort.** Sibling images proceed independently; the material completes.

**The material never fails because an image did.** The tool-present path can only *add*
generated images or *add* flag lines — it never removes the manual outcome. A whole-run failure
is simply N per-image fallbacks plus N flag lines: a fully-manual material, exactly as today.

**Never leak.** Never echo a raw error payload, a stack trace, a provider error string
verbatim, or any token- or secret-shaped material into teacher-facing chat.

---

## Provider → citation-display data map

> **REFERENCE DATA — not prose.** This **section** (everything under this `##` heading) is
> the **one place** provider identifiers legitimately appear as shipped data (as model
> identifiers already do elsewhere). It is **mechanically exempt** from the contract-prose
> provider-name ban; the deny-list guard scopes out this section **by its `##` heading
> range**. It maps a `provider` identifier to the APA-7 author/source display name and URL
> used to render the AI-image citation footnote (Quellenangabe).

| `provider` id | APA-7 author / source | URL |
|---|---|---|
| `google` | Google | https://gemini.google.com |
| `openai` | OpenAI | https://openai.com |

- The `google` row is the **manual-flow** attribution (the web-interface flow's provider) — it
  is one ordinary row of the same map, authored exactly as the manual flow does today.
- **Fallback rule — never guess an attribution.** A `provider` identifier **not** in this map
  is cited by its **identifier verbatim, with no URL**, and the omission is **flagged in the
  chat confirmation**. An unmapped provider is never given a guessed author or URL.

---

## Related files

- `${CLAUDE_PLUGIN_ROOT}/references/schemas/unit-manifest.md` — the `plan.json` per-image
  fields (`model`, `provider`, `watermark`, `status`) this contract's recorded metadata writes.
- `${CLAUDE_PLUGIN_ROOT}/references/localization.json` — the localized image labels and the
  per-image fallback flag line surfaced under this contract.
- `${CLAUDE_PLUGIN_ROOT}/references/document-metadata.md` — the output-document gate the
  written document passes, independent of image generation.
