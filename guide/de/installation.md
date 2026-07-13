---
title: Installation
description: Thalura in Claude Code oder Claude Cowork einrichten — Stable- oder Beta-Kanal.
---

# Installation

Thalura wird über zwei Kanäle bereitgestellt. Wähle einen aus:

- **Stable** — für den allgemeinen Einsatz, geprüfte Versionen.
- **Beta** — für Testerinnen und Tester, mit den jeweils kommenden Versionen.

Der Installationsbefehl ist in beiden Fällen identisch; nur der Marktplatz
unterscheidet sich.

## Claude Code (Befehlszeile und Desktop)

**Stable:**

```
/plugin marketplace add blackbrowed-labs/thalura-plugin-dist
/plugin install thalura@blackbrowed-labs
```

**Beta:**

```
/plugin marketplace add blackbrowed-labs/thalura-plugin-beta
/plugin install thalura@blackbrowed-labs
```

Starte Claude Code **aus deinem Lehrer-Ordner heraus**, damit Thalura deinen
Arbeitsbereich findet. Alles, was du anlegst, bleibt in diesem Ordner.

## Claude Cowork

1. Öffne **Customize → Personal plugins**.
2. Klicke auf **„+" → „Create plugin"**.
3. Wähle **„Add marketplace" → „Add from a repository"**.
4. Füge die Adresse deines Kanal-Repositorys ein:
   - Stable: `https://github.com/blackbrowed-labs/thalura-plugin-dist`
   - Beta: `https://github.com/blackbrowed-labs/thalura-plugin-beta`
5. Klicke auf **Sync**, um den Marktplatz zu synchronisieren.
6. Wähle **`Thalura`** aus und klicke auf **Install**.

Verbinde anschließend deinen Lehrer-Ordner (unter `mnt/<Ordner>`); Thalura
erkennt ihn beim Start automatisch.

## Berechtigungen in Cowork

Cowork fragt standardmäßig vor jeder Aktion nach („Ask before acting"). Da
Thalura beim Planen laufend Dateien in deinem Lehrer-Ordner anlegt und
aktualisiert, führt das zu vielen Rückfragen — besonders beim Löschen von
Dateien. Für einen flüssigen Ablauf empfehlen wir, in den Cowork-Einstellungen
auf **„Act without asking"** umzustellen.

**Abwägung:** Mit „Act without asking" arbeitet Thalura ohne einzelne
Bestätigung. Alles bleibt in deinem Lehrer-Ordner, und du behältst die
Kontrolle über das Ergebnis; du bestätigst aber nicht mehr jede einzelne
Aktion vorab. Möchtest du jede Aktion einzeln freigeben, bleibe bei „Ask
before acting".

## Deine Daten bleiben erhalten

Dein Lehrerprofil (Lehrerprofil), deine Schulkonfiguration
(Schulkonfiguration) und alle erzeugten Materialien liegen ausschließlich in
deinem Lehrer-Ordner. Sie bleiben erhalten, wenn du Thalura neu installierst
oder den Kanal wechselst.

Als Nächstes: **[Erste Schritte](./erste-schritte.md)**.
