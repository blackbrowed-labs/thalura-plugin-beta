🇩🇪 Deutsch | [🇬🇧 English](README.en.md)

# Thalura

Ein Plugin für Claude Code zur Unterrichtsplanung und Leistungsüberprüfung für
Hamburger Lehrkräfte an weiterführenden Schulen (Gymnasium / Stadtteilschule).
Verankert im Hamburger Bildungsplan und in den Vorgaben der Behörde für Schule
und Berufsbildung (BSB).

## Unterstützung

☕ Gefällt dir Thalura? Unterstütze die Entwicklung.

[![Auf Ko-fi unterstützen](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/blackbrowedlabs)

## Was es kann

Plane ein Schuljahr, entwirf eine Unterrichtseinheit, erzeuge differenzierte
Arbeitsblätter oder erstelle eine Klausur mit Erwartungshorizont — alles
rückgebunden an den Bildungsplan für dein Fach und deine Klassenstufe. Jede
Ausgabe wird vor der Auslieferung gegen die BSB-Vorgaben geprüft.

## Fächer

| Fach | Englisch | Kürzel |
|---|---|---|
| Englisch | English | E |
| Philosophie | Philosophy | P |
| Psychologie | Psychology | Psy |
| Religion | Religion | R |

## Installation

Thalura wird über zwei Kanäle bereitgestellt — wähle einen aus und füge ihn in
Claude Code als Marktplatz hinzu, dann installiere:

**Stable** (allgemeiner Einsatz):

```
/plugin marketplace add blackbrowed-labs/thalura-plugin-dist
/plugin install thalura@blackbrowed-labs
```

**Beta** (Testerinnen und Tester — kommende Versionen):

```
/plugin marketplace add blackbrowed-labs/thalura-plugin-beta
/plugin install thalura@blackbrowed-labs
```

Starte Claude Code aus deinem Lehrer-Ordner, damit das Plugin deinen
Arbeitsbereich findet. Aktualisiere mit `/plugin update thalura@blackbrowed-labs`.

Die vollständige Anleitung — Schritt-für-Schritt-Installation, Claude Cowork,
Erste Schritte und Aktualisieren — findest du im **[Handbuch](guide/de/index.md)**.

## Schnellstart

```
/thalura:setup
```

Führt dich durch dein Lehrerprofil (Lehrerprofil), deine Schulkonfiguration
(Schulkonfiguration) und deine Einstellungen. Danach geht es los — beschreibe
einfach, was du brauchst, oder tippe `/` und wähle einen `thalura:`-Eintrag. Einen
Überblick über alle Fähigkeiten findest du unter
**[Aufgabenmodule](guide/de/aufgabenmodule.md)**.

## Projektstand

Aktive Entwicklung Richtung Version 1.0, angepeilt für Juli 2026. Vor 1.0 kann
sich zwischen zwei Versionen einiges ändern. Versionsregeln und
Änderungskonventionen siehe [VERSIONING.md](VERSIONING.md).

## Dokumentation

- [Handbuch (Deutsch)](guide/de/index.md) — Installation, Erste Schritte,
  Aktualisieren, Aufgabenmodule
- [CHANGELOG.md](CHANGELOG.md) — Änderungsverlauf
- [VERSIONING.md](VERSIONING.md) — Versions- und Änderungsstandard

## Lizenz

[MIT](LICENSE) © Lars Weiser / blackbrowed labs
