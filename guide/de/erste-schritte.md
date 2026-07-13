---
title: Erste Schritte
description: Die Einrichtung starten, dein Lehrerprofil anlegen und dein erstes Material erzeugen.
---

# Erste Schritte

Nach der Installation richtest du Thalura einmalig ein. Danach kannst du sofort
mit der Planung beginnen.

## Die Einrichtung starten

- **In Claude Cowork:** Sag Thalura in normaler Sprache, dass du loslegen
  möchtest — zum Beispiel „Einrichtung starten" oder „Richte Thalura für mich
  ein".
- **In Claude Code:** Du kannst zusätzlich den Befehl `/thalura:setup`
  verwenden.

Die Einrichtung ist ein geführtes Gespräch — Thalura fragt der Reihe nach ab,
was es wissen muss, und du antwortest in deiner Sprache.

## Was abgefragt wird

1. **Sprache** — in welcher Sprache Thalura mit dir spricht (Standard: Deutsch).
2. **Bundesland und Schulform** — z. B. Hamburg, Gymnasium oder
   Stadtteilschule.
3. **Schulname und Stundenraster** — Name deiner Schule und die Länge deiner
   Unterrichtsstunden.
4. **Branding (optional)** — Logo und Farben deiner Schule für gestaltete
   Folien.
5. **Lehrerprofil (Lehrerprofil)** — dein Name, dein Kürzel und optional deine
   E-Mail-Adresse.
6. **Fächer** — die Fächer, die du unterrichtest, samt Unterrichtssprache.
7. **Schulinternes Curriculum (schulinternes Curriculum)** — falls vorhanden,
   damit Thalura deine schulischen Vorgaben berücksichtigt.

Du musst keine Regelwerke oder PDF-Dateien selbst ablegen — die Hamburger
Vorgaben sind bereits in Thalura enthalten.

Deine Fächer kannst du später jederzeit über die Profil-Konfiguration ändern —
ein Fach hinzufügen oder entfernen — mit `/thalura:config profile`.

## Geschlechtergerechte Sprache (Gendern)

Wie deine erzeugten deutschen Dokumente gendern, wird bei der Einrichtung
**automatisch gesetzt** (eine barrierearme, neutrale Standardform) und ist
**später über die Profil-Konfiguration änderbar** — mit `/thalura:config
profile`. Die Einrichtung fragt dich danach nicht.

Im Profil siehst du zu jeder Option ein Beispiel: Für
schülerorientierte Dokumente kannst du zwischen der neutralen Form („die
Lernenden"), der Beidnennung („Schülerinnen und Schüler"), dem
Gender-Doppelpunkt („Schüler:innen") und dem Gendersternchen
(„Schüler\*innen") wählen. Für lehrerorientierte Planungsdokumente entscheidest
du, ob Kurzformen wie „SuS" verwendet oder ob sie ausgeschrieben werden. Die
gewählte Form wird durchgängig in jedem Dokument verwendet; englische Dokumente
bleiben unverändert.

## Branding ist optional

Das Branding (Logo und Farben) ist freiwillig und blockiert die Einrichtung
nie. Wenn du es überspringst oder keine Website angibst, erzeugt Thalura deine
Folien aus einer neutralen, mitgelieferten Vorlage — sie funktionieren genauso.
Du kannst das Branding jederzeit später ergänzen: Sag Thalura einfach, dass du
jetzt doch Logo und Schulfarben einrichten möchtest (das läuft über die
Konfiguration deiner Schuldaten). Thalura legt dann alle nötigen Ordner selbst
an, erkennt die Farben von deiner Website, erstellt die Logo-Varianten und
gestaltet die Folienvorlage neu. Das Branding betrifft nur deine Folien —
deine Word-Dokumente (Arbeitsblätter, Handouts, Pläne, Lernkontrollen) bleiben
neutral, egal ob sie schon vorhanden sind oder erst danach entstehen.

In Claude Cowork kann Thalura das Logo nicht automatisch von der Website laden;
in diesem Fall bittet es dich, die Logodatei in den Unterordner `assets` deines
Lehrer-Ordners zu legen.

## Was dabei angelegt wird

Thalura legt in deinem Lehrer-Ordner deine Profil- und Konfigurationsdaten sowie
die Ordnerstruktur für deine Materialien an. Um die internen Dateipfade musst du
dich nicht kümmern — Thalura verwaltet sie für dich. Im Ordner `data` legt
Thalura außerdem eine kurze README-Datei ab, die erklärt, was dort gespeichert
ist und an welchen zwei Stellen du selbst Dateien ablegst.

## Der Schuljahreswechsel

Thalura erkennt aus dem Gespräch, für welches Schuljahr du planst — du musst
nichts umstellen. Sagst du zum Beispiel „Plane eine Einheit für meine neue
E10a", erkennt Thalura, dass ein neues Schuljahr gemeint ist, und legt es an.

Beim ersten Kontakt mit einem neuen Schuljahr schlägt Thalura passende
Klassen-Fortsetzungen vor — entlang der Klassenstufen-Abfolge deiner Schulform:
aus deiner E9a wird eine E10a, eine 10. Klasse wird in der Oberstufe zur S1
(Übergang Sek I → Sek II), und ein Abiturjahrgang nach der letzten Stufe wird
als abgeschlossen erkannt. Du kannst die Vorschläge bestätigen, ändern,
ergänzen oder einzelne entfernen.

Dabei gilt: Es wird nichts angelegt, bevor du bestätigst, und die Daten
vergangener Schuljahre bleiben unangetastet.

## Dein erstes Material

Sobald die Einrichtung abgeschlossen ist, kannst du sofort loslegen. Beschreibe
einfach, was du brauchst, zum Beispiel:

> „Plane eine Unterrichtseinheit (Unterrichtseinheit) zu Shakespeares Sonetten
> für die Oberstufe."

Tippst du `/`, findest du alle Fähigkeiten von Thalura außerdem als
`thalura:`-Einträge im Menü. Einen Überblick über
alles, was Thalura kann, findest du unter
**[Aufgabenmodule](./aufgabenmodule.md)**.
