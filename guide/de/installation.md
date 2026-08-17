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

## Voraussetzung: Thalura läuft auf deinem Computer

Das Folgende gilt für Claude Cowork. Thalura muss auf deinem Computer laufen,
nicht in der Cloud. Läuft eine Aufgabe in der Cloud, fehlen deinen Ergebnissen
mehrere Dinge, die dieses Handbuch dir zusagt — welche, steht gleich unten.

So stellst du es ein: Öffne **Settings → Cowork** und schalte
**„Run new tasks in the cloud"** aus — die Einstellung, die neue Aufgaben in
der Cloud statt auf diesem Computer startet — und starte danach eine neue
Aufgabe in Cowork. Die Einstellung wirkt nur auf neu gestartete Aufgaben; die
Aufgabe, in der du gerade bist, wechselt damit nicht auf deinen Computer.

Das steht auf dem Spiel, solange eine Aufgabe in der Cloud läuft:

- Keine einzige Quellenangabe in deinen Dokumenten lässt sich anklicken — die
  Verweise auf den Bildungsplan bleiben durchgehend Text.
- Die Schuljahresübersicht wird nicht geschrieben, auch nicht nach der ersten
  eingetragenen Unterrichtseinheit.
- Deine Dokumente entstehen ohne die Vorlage deiner Schule — ohne deine Kopf-
  und Fußzeile und ohne deinen Namen als Autor in den Dateieigenschaften.
- Jede Frage an die offiziellen Vorgaben braucht wieder die volle Wartezeit,
  auch wenn dieselbe Stelle längst nachgelesen ist.

Nichts davon wird als Fehler gemeldet: Es erscheint keine Warnung, kein Schritt
bricht ab, und die fertigen Dokumente sehen aus, als wäre alles erledigt. Genau
deshalb steht hier eine Probe — von allein fällt es dir nicht auf.

**So prüfst du es:** Sobald deine erste Unterrichtseinheit eingetragen ist, muss
die Schuljahresübersicht direkt in deinem Lehrer-Ordner liegen. Liegt sie nicht
dort, lief die Aufgabe in der Cloud: Schalte die Einstellung wie oben
beschrieben aus und starte eine neue Aufgabe. Zur Gegenprobe öffnest du die
Verankerung im Bildungsplan einer Einheitenplanung — lässt sich dort wenigstens
eine Quellenangabe anklicken, hat Thalura auf deinem Computer gearbeitet. (Dass
einzelne Angaben ohne Link bleiben, ist normal: Nicht zu jedem Dokument gibt es
eine offizielle Online-Fassung.)

Das ist der Stand heute. Ändert sich daran etwas, findest du es in
`CHANGELOG.md`.

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
