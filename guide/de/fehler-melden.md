---
title: Fehler melden
description: Wenn etwas falsch aussieht — einen Fehlerbericht erstellen, prüfen und an die Entwickler senden.
---

# Wenn etwas falsch aussieht: Fehler melden

Auch bei sorgfältiger Arbeit kann einmal etwas schiefgehen — Thalura tut etwas
Unerwartetes, ein Schritt bricht ab, ein Ergebnis erscheint nicht dort, wo es
sollte. Damit die Entwickler so etwas beheben können, brauchen sie mehr als
„es hat nicht funktioniert": Sie brauchen die technischen Angaben dazu. Genau
die stellt Thalura dir auf Wunsch zusammen — als eine einzige Datei, die du
prüfst und selbst verschickst.

## Prüfe zuerst: Läuft Thalura auf deinem Computer?

Zwei Beobachtungen haben fast immer dieselbe Ursache: Die Schuljahresübersicht
liegt nicht in deinem Lehrer-Ordner, und in einer Einheitenplanung lässt sich
keine einzige Quellenangabe anklicken. Beides entsteht, wenn deine Aufgabe in
Claude Cowork in der Cloud läuft statt auf deinem Computer. Gemeldet wird das
nicht: Es erscheint keine Warnung, kein Schritt bricht ab, und die Dokumente
sehen fertig aus — deshalb steht diese Prüfung vor allen anderen.

**So prüfst du es:** Liegt die Schuljahresübersicht in deinem Lehrer-Ordner und
lässt sich in der Verankerung im Bildungsplan wenigstens eine Quellenangabe
anklicken, dann hat Thalura auf deinem Computer gearbeitet. (Dass einzelne
Angaben ohne Link bleiben, ist normal: Nicht zu jedem Dokument gibt es eine
offizielle Online-Fassung.) Sonst schalte unter **Settings → Cowork** die
Einstellung **„Run new tasks in the cloud"** aus — die Einstellung, die neue
Aufgaben in der Cloud statt auf diesem Computer startet —, starte danach eine
neue Aufgabe und sieh nach, ob sich damit erledigt hat, was dir aufgefallen
ist. Mehr dazu unter [Installation](./installation.md). Bleibt es dabei, melde
den Fehler wie unten beschrieben — das ist dann genau der richtige Weg.

So ist der Stand heute; ändert sich daran etwas, steht es in `CHANGELOG.md`.

## Wann du einen Fehler meldest

Immer dann, wenn sich **Thalura selbst** komisch verhält: Etwas sieht falsch
aus, etwas Unerwartetes ist passiert, ein Schritt hat nicht das getan, was du
wolltest. Du musst nichts Technisches wissen und keinen besonderen Befehl
kennen — sag es einfach in deinen Worten: „Fehler melden", „das sieht falsch
aus", „da stimmt etwas nicht".

Ein Hinweis zur Abgrenzung: Wirkt der **Inhalt** eines erzeugten Dokuments
fachlich fragwürdig — etwa eine Klausur, bei der du zweifelst, ob sie den
Vorgaben entspricht —, dann ist das ein Fall für die Compliance-Prüfung, nicht
für den Fehlerbericht.

## Was Thalura erstellt

Thalura stellt dir höchstens drei kurze Fragen — was du erwartet hast, was
stattdessen passiert ist und wann es aufgetreten ist — und erstellt dann eine
einzelne Textdatei: den **Fehlerbericht**. Darin stehen die technischen
Angaben, die die Entwickler brauchen: die Version von Thalura, deine
Arbeitsumgebung, deine eigene Beschreibung des Problems und was in der
Sitzung passiert ist. Die Datei landet direkt in deinem Arbeitsordner, mit
Datum und Uhrzeit im Namen (z. B. `Fehlerbericht 2026-07-02 14-31.txt`).

## Die drei Zusagen

Für jeden Fehlerbericht gilt, ohne Ausnahme:

- **Keine Schülerdaten.** Der Bericht enthält niemals Namen von Schülerinnen
  und Schülern und niemals Inhalte aus Abgaben.
- **Du prüfst die Datei vor dem Versenden.** Der Bericht verlässt deinen
  Rechner nur, wenn du ihn selbst verschickst.
- **Thalura versendet nichts selbst.** Thalura schreibt nur die Datei — das
  Versenden ist allein dein Schritt.

## So sendest du den Bericht

Lies die Datei einmal in Ruhe durch: Angaben zu dir und deiner Schule (Name,
Schule, E-Mail) sind enthalten — entferne alles, was du nicht teilen möchtest.
Dann sende die Datei als E-Mail-Anhang an `support@thalura.de`. Als Betreff
nimmst du „Thalura-Fehlerbericht – Version …" — Thalura schreibt dir den
passenden Betreff unten in die Datei, du kannst ihn einfach übernehmen.
