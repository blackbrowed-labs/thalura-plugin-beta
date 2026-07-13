---
name: report-problem
description: Fehler melden. Use when the teacher wants to report a problem or unexpected behaviour (Fehler melden) — generates a diagnostic report (Fehlerbericht) as a single TXT file the teacher reviews and sends to support manually. Never includes student data; the plugin never sends anything itself.
when_to_use: |
  DE + EN: "Fehler melden", "Problem melden", "das sieht falsch aus", "etwas stimmt nicht", "da stimmt was nicht", "Thalura macht etwas Komisches", "Fehlerbericht erstellen", "report a problem", "report a bug", "something looks wrong", "that seems broken". Writes a report file only — sending is the teacher's manual step after review. Doubt about the CONTENT of an output ("is this compliant / regelkonform?") is a compliance check (→ compliance), not a problem report; when unclear which is meant, ask.
---

# /thalura:report-problem — Report a Problem (Fehler melden)

> Core protocols — startup, HiTL/draft lifecycle, preferences, class definitions — run via the `core` skill (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`). **Deviation from the sibling utility skills:** this skill *attempts* the idempotent startup precondition but **degrades instead of blocking**. An unresolvable workspace root, an unreadable profile, or a failing resolver run is diagnostic signal that goes **into the report** (the environment section) — never a reason to abort. A diagnostic tool that requires a healthy startup cannot diagnose a broken startup.

When the teacher wants to report a problem (Fehler melden) — Thalura did something wrong or unexpected — this skill generates a **diagnostic report (Fehlerbericht)**: a single TXT file carrying the build identity, environment state, the teacher's own symptom description, a session summary, and curated state snapshots, with privacy guardrails the teacher does not have to think about. The plugin only **writes** the file; the teacher **reviews** it and **sends it manually**. Nothing is ever transmitted by the plugin.

**Composed in the main session — never delegated.** The session summary is drawn from the session's own history, which no sub-agent can see. Composing the report in the main session is a deliberate, stated exception to the prefer-sub-agents norm: a delegated composer could not describe the very session the report is about.

---

## Workflow

1. **Trigger** — the teacher asks to report a problem (Fehler melden), or the core router hands the request over. Attempt the idempotent startup precondition; on any failure, continue degraded (see *Degraded Path*) — the failure itself becomes report content.
2. **Symptom interview** — at most **three questions, presented together in one message**, in `conversation_language`: *Was hattest du erwartet? Was ist stattdessen passiert? Wann/wo ist es aufgetreten — welche Aufgabe, ggf. Fach/Klasse?* Partial answers are followed up once; "unknown" ("unbekannt") is an acceptable answer.
3. **Compose** the report per the template below, in the main session, running the quality-gate loop (see *Quality Gates*).
4. **Student-data check** on the teacher's verbatim text (gate P1): if the symptom description looks student-identifying, point it out and ask the teacher to rephrase **before** writing the file. Never silently rewrite the teacher's words; never write the unrephrased text.
5. **Write** the TXT (see *File Mechanics*).
6. **Present with the review-before-send note** — the presenting chat message explicitly asks the teacher to review the file before sending it (gate P2).
7. **Done. No transmission.** The footer of the report tells the teacher how to send it (gate P3).

## Report Template

The report is written in the teacher's `conversation_language` (German default; if the profile is unreadable → German). Headings localize with the report language. Two registers:

- **Teacher-visible frame** (title, review note, symptom prompts, footer): plain, jargon-free language.
- **Technical payload** (build, environment, session summary, state snapshots): its audience is the developer — internal paths, resolver sentinels, and technical jargon are acceptable there, and only there.

German rendering (canonical layout — the numbered parts and their order are fixed):

```text
THALURA-FEHLERBERICHT — {YYYY-MM-DD HH:MM}
==========================================

BITTE VOR DEM VERSENDEN PRÜFEN: Lies diesen Bericht einmal durch, bevor du
ihn versendest — er verlässt deinen Rechner nur, wenn du ihn selbst
verschickst. Er enthält KEINE Schülerdaten. Angaben zu dir und deiner Schule
(Name, Schule, E-Mail) sind enthalten; entferne alles, was du nicht teilen
möchtest.

1. BUILD
   Plugin-Version: {version aus plugin.json}
   Build-Commit:   {sha, falls verfügbar | "nicht verfügbar (Dev-Build)"}

2. UMGEBUNG
   Laufzeit:            {Claude Cowork | Claude Code} (erkannt über {wie})
   Arbeitsbereich:      {aufgelöster Pfad | Resolver-Ausgabe wörtlich, z. B.
                         THALURA_SETUP_NEEDED / THALURA_AMBIGUOUS:… / Fehler}
   version.json:        {Inhalt | "nicht vorhanden"}
   Einschränkungen:     {degraded-tooling flags | "keine festgestellt"}

3. PROBLEMBESCHREIBUNG (deine eigenen Worte)
   Erwartet:            {…}
   Stattdessen passiert: {…}
   Wann/Wo:             {Aufgabe/Modul; Fach/Klasse falls relevant; diese
                         Sitzung oder eine frühere}

4. SITZUNGSVERLAUF (Kurzprotokoll dieser Sitzung)
   {chronologische Stichpunkte: ausgeführte Schritte/Werkzeuge/Befehle mit
    je einer Zeile Begründung — die Selbstauskunft des Assistenten}
   {wenn das Problem in einer früheren Sitzung auftrat: ausdrücklicher
    Hinweis, dass dieses Protokoll nur die aktuelle Sitzung zeigt}

5. ZUSTAND
   Aufgaben-/Planungsstand: {relevante Einträge, z. B. Einheit X: Entwurf}
   Betroffene Dateien:      {Namen/Pfade der betroffenen Ausgabedateien —
                             keine Inhalte über das Nötige hinaus}
   Regelwerks-Lesespeicher: {nur bei Regelungs-Bezug: Zusammenfassung —
                             Einträge, Stand, Treffer/Fehltreffer dieser
                             Sitzung — nie der gespeicherte Wortlaut}
   Konfiguration:           {je Datei: vorhanden/lesbar/plausibel — keine
                             Schlüssel- oder Zugangswerte irgendeiner Art}

6. ZEITPUNKTE
   Bericht erstellt:    {ISO-Zeitstempel}
   Problem beobachtet:  {aus der Befragung; "unbekannt" ist zulässig}

------------------------------------------------------------------
SO SENDEST DU DIESEN BERICHT: Prüfe den Inhalt (siehe Hinweis oben) und
sende die Datei dann als E-Mail-Anhang an support@thalura.de
(Betreff: „Thalura-Fehlerbericht – Version {plugin_version}").
Thalura versendet nichts selbst.
```

## Content Inventory

Every item below is present in the report, or explicitly marked unavailable **with the reason** — silent absence fails gate G1:

1. **Build identity** — `version` from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`; the build commit **if available**. On dev builds the commit is not available — accepted, and the report states it explicitly ("nicht verfügbar (Dev-Build)"). Absent-with-explanation passes the gate; silently absent fails it.
2. **Environment** — the runtime and how it was detected; the workspace-root resolution outcome **verbatim** (the resolved path, or the resolver's sentinel/error output); the contents of `<WORKSPACE_ROOT>/data/version.json`; any degraded-tooling flags observed this session.
3. **Symptom description** — the teacher's own words **verbatim** (subject to the student-data check, gate P1): expected vs. observed vs. when/where.
4. **Session summary** — the chronological steps/tools/commands the assistant ran this session, each with a one-line reasoning summary. If the problem occurred in an earlier session, the report says so explicitly — the summary never pretends to cover a session it cannot see.
5. **State snapshots** — the task/plan state relevant to the finding; the affected output files' **names/paths**, not contents beyond what is needed; a cache-state summary (entries, version stamps, hits/misses this session) **only** when the finding is regulation-related — never stored verbatim regulation wording; config sanity per file (present / parses / plausible) — **never the value of any credential or token of any kind**.
6. **Timestamps** — report-generation time; when the symptom was observed (teacher-supplied; "unbekannt" is acceptable).
7. **Frame** — the review-before-send note at the top; the how-to-send footer at the bottom.

## Privacy Gates (non-negotiable)

Four hard requirements. No environment, request, or convenience loosens them:

- **P1 — No student data, ever.** No student names, no submissions (Abgaben) contents, no observation detail that could identify a student — anonymized category names at most. This binds **both** registers, the technical payload included. Class-definition snapshots carry only type + count, and only the fields relevant to the finding. Nothing under a `{submissions}` (Abgaben) folder is ever read into a report, named beyond the folder level in a report, or quoted in a report. **The teacher's verbatim words are not exempt:** if the symptom description contains what looks like student-identifying data, point it out and ask the teacher to rephrase **before** the file is written — never silently rewrite the teacher's words, never write the unrephrased text.
- **P2 — The teacher reviews before sending.** The review-before-send note appears in the report header **and** in the chat message presenting the file, so the teacher sees exactly what would leave their machine. Teacher data (name, school, e-mail) is in scope precisely because of this gate — the teacher is the release authority for their own data.
- **P3 — Write-only.** The plugin only **writes** the file; sending is the teacher's manual act. No network call, no auto-upload, no background transmission of any kind, in any environment. The diagnostic report (Fehlerbericht) is the one sanctioned, teacher-requested path that packages internal state for the teacher — and it earns that status by construction: it **synthesizes a purpose-built TXT** (curated, student-data-scrubbed, human-readable) and **never hands over raw `data/*.json`** — not presented as files, not pasted wholesale into the report. Internal JSON is *read* to compose summaries; the raw artifact never becomes the teacher-facing surface. This loosens the never-surface-internal-state rule for **no other flow**.
- **P4 — No secrets.** No credential, token, or key value of any kind appears in the report — config checks report *presence and validity*, never secret values. The plugin stores no credentials today; the gate is stated so it holds if that ever changes.

## File Mechanics

- **Filename:** `{diagnostic_report} {YYYY-MM-DD} {HH-MM}.txt`, where `{diagnostic_report}` resolves via the localization key `document_filenames.diagnostic_report` in `${CLAUDE_PLUGIN_ROOT}/references/localization.json` — e.g. `Fehlerbericht 2026-07-02 14-31.txt`. Filesystem-safe (no colons), sorts chronologically; multiple reports coexist without overwriting. On a same-minute collision, append `-2`, `-3`, ….
- **Location:** `<WORKSPACE_ROOT>/` — directly at the top level of the teacher's workspace, the folder the teacher already knows. The report is a deliverable the teacher must find: emphatically **not** under `data/` (a report is not internal state), not under a `{Subject}/` output tree (a report is not subject-scoped), and no dedicated folder (reports are rare, one-off artifacts).

## Presentation

The diagnostic report (Fehlerbericht) TXT is a named human-facing deliverable under the core Presentation-hygiene rule (`${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md`) and is presented the way that rule presents deliverables in the current environment. The presenting chat message always carries the review-before-send note (gate P2).

## Degraded Path

The report never depends on a healthy workspace. If `<WORKSPACE_ROOT>` cannot be resolved — quite possibly *the very bug being reported*:

1. **Compose anyway.** The resolver's verbatim output goes into the environment section; each part of the report that needs workspace reads states "nicht lesbar" plus the reason instead.
2. **Delivery without a workspace:** ask the teacher for a folder to save the file into, or write it to the session working area and present it via the file-presentation mechanism so the teacher can download it — presentation-for-download is the delivery in that case, and the report states where it was written. (The core rule against writing into the session sandbox governs teacher *data* placement; a downloadable diagnostic artifact presented to the teacher is not that.) As a last resort, render the full report content in chat for copy-paste.
3. **Language fallback:** when no profile is readable, the report language falls back to German.

## Quality Gates

Before presenting, verify every gate. On a failure, fix and re-verify. If a gate cannot be satisfied, **flag the residual in the report itself and in chat** — never silently ship less:

| Gate | Check |
|---|---|
| **G1 — Inventory-complete** | Every *Content Inventory* item is present, or explicitly marked unavailable **with the reason** (e.g. "Build-Commit: nicht verfügbar (Dev-Build)"; "Sitzungsverlauf: Problem trat in früherer Sitzung auf"). Silent absence fails the gate. |
| **G2 — No student data** | Gate P1 holds across the whole file, teacher-verbatim text included. |
| **G3 — Build identity** | Version present; commit present **or** explicitly declared unavailable. |
| **G4 — Human-reviewable** | The frame (header note, symptom prompts, footer) is plain `conversation_language` prose, free of internal jargon; the file opens as plain text; the review note is present at the top. |
| **G5 — Write-only** | Nothing was transmitted; the file exists at the stated path (or the degraded delivery was used and stated). |

Mechanism selection — how state is gathered, how the file is written, how it is presented — is the model's choice, per environment. The gates define the contract; no specific tool does.

## Expected Outputs

| Output | Location | Format |
|--------|----------|--------|
| Diagnostic report (Fehlerbericht) | `<WORKSPACE_ROOT>/{diagnostic_report} {YYYY-MM-DD} {HH-MM}.txt` | Plain text (TXT) |
| Presentation + review-before-send note | Chat | Conversation |

## Reference Files

| File | Used in | Purpose |
|------|---------|---------|
| `${CLAUDE_PLUGIN_ROOT}/references/localization.json` | File Mechanics | `document_filenames.diagnostic_report` filename key |
| `${CLAUDE_PLUGIN_ROOT}/skills/core/SKILL.md` | Workflow, Presentation | Startup precondition (attempted, fail-open here) + Presentation-hygiene deliverable rule |
| `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` | Content Inventory | Build identity (`version`) |
