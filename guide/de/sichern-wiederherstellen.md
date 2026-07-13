---
title: Sichern und Wiederherstellen
description: Deine gesamte Arbeit in eine Sicherungsdatei packen und auf einem neuen oder frisch eingerichteten Rechner wiederherstellen.
---

# Deine Arbeit sichern und auf einen neuen Rechner umziehen

Deine Jahrespläne, Klassen, deine Bibliothek und all die erzeugten Dokumente
sind unersetzlich. Mit einer **Sicherung** packst du sie in eine einzige Datei —
und stellst sie später auf einem neuen oder frisch eingerichteten Rechner wieder
her. Genau dafür gibt es zwei Schritte, die zusammengehören: **sichern** und
**wiederherstellen**.

## Eine Sicherung erstellen

*Sag z. B.:* „Ich wechsle auf einen neuen Rechner. Kannst du mir eine Sicherung
von allem machen?"

Thalura packt deine **unersetzliche Arbeit** in eine Sicherungsdatei:

- deine **Jahrespläne** und **Klassen**,
- deine **Bibliothek (Bibliothek)** mit allen aufgehobenen Einheiten,
- **jedes erzeugte Dokument** — Einheitenpläne, Verlaufspläne, Materialien und
  Klausuren mit Erwartungshorizont,
- und ausdrücklich auch deine **Entwürfe (Entwürfe)**, damit nichts
  Halbfertiges verloren geht.

Was **nicht** mitkommt, bleibt bewusst zurück:

- **Schülerabgaben (Abgaben)** — die Arbeiten deiner Schülerinnen und Schüler
  verlassen niemals deinen Rechner. Sie gehören nicht in eine Sicherung.
- **Wieder erzeugbare Daten** — Zwischenspeicher und Ähnliches baut Thalura bei
  Bedarf neu auf; das Plugin selbst wird auf dem neuen Rechner neu installiert,
  nicht gesichert.

Bevor Thalura anfängt, zeigt es dir in Worten, was in die Sicherung kommt, und
fragt nach. Auf Wunsch kannst du die Bibliothek oder die erzeugten Dokumente
weglassen, um eine kleinere Datei zu bekommen — dann weist Thalura dich darauf
hin, dass eine spätere Wiederherstellung Verweise ins Leere haben kann. Am Ende
liegt die Datei in deinem Thalura-Ordner, und Thalura sagt dir, was gesichert
wurde und was bewusst nicht.

## Der Umzug auf einen neuen Rechner

Der Weg auf einen neuen (oder leeren) Rechner hat drei Schritte:

1. **Installieren** — Thalura auf dem neuen Rechner einrichten.
2. **Datei ablegen** — leg die Sicherungsdatei in deinen Thalura-Ordner
   (`~/Thalura/`).
3. **Wiederherstellen** — und Thalura baut deinen Arbeitsbereich direkt aus
   der Sicherung auf. Eine Ersteinrichtung ist nicht nötig: Thalura richtet
   alles so ein, wie es eine Einrichtung getan hätte — bis hin zur
   Folienvorlage in deinen Schulfarben, wenn du ein Branding eingerichtet
   hattest. Kann etwas davon in dieser Umgebung nicht erzeugt werden, sagt
   Thalura es dir ehrlich, statt es stillschweigend wegzulassen.

## Eine Sicherung wiederherstellen

*Sag z. B.:* „Ich habe die Sicherung hier abgelegt. Bitte spiel sie wieder ein."

Thalura stellt **sicher-voreingestellt** wieder her — es überschreibt niemals
still deine Arbeit. Was passiert, hängt davon ab, wie der Arbeitsbereich
aussieht:

- **Ein leerer oder noch gar nicht eingerichteter Arbeitsbereich** — alles
  kommt sauber zurück: deine Jahrespläne, Klassen, die Bibliothek und jedes
  Dokument. Ist der Ordner noch komplett leer, fragt Thalura einmal nach und
  baut den Arbeitsbereich dann direkt aus der Sicherung auf — ohne
  Ersteinrichtung. Wenn du vorher schon eine Einrichtung durchlaufen und dabei
  Klassen angelegt hast, nennt Thalura dir genau diese Klassen und ersetzt sie
  durch die Fassungen aus der Sicherung, bevor es startet. Zum Schluss prüft
  Thalura, dass wirklich alles an seinem Platz ist, was eine Einrichtung
  angelegt hätte, und ergänzt Fehlendes.
- **Ein Arbeitsbereich, der schon Einheiten enthält** — Thalura überschreibt
  deine vorhandene Arbeit nicht. Stattdessen bietet es zwei sichere Wege an:
  **nur die Bibliothek** aus der Sicherung ergänzen (nichts von dir wird
  ersetzt, nur neue Einheiten kommen dazu), **oder** die vollständige Sicherung
  in einen frischen Arbeitsbereich zurückspielen.
- **Eine Sicherung aus einer neueren Thalura-Version** — Thalura bittet dich,
  zuerst das Plugin zu aktualisieren, und stellt dann wieder her. So kann eine
  neuere Sicherung nie von einer älteren Version falsch verarbeitet werden.

Nach der Wiederherstellung prüft Thalura, dass alle Verweise stimmen (jeder Plan
findet seine Dokumente und seine Klassen), und sagt dir in Worten, was
zurückgekommen ist. Sollte einmal etwas mittendrin abbrechen, meldet Thalura
ehrlich, was schon zurückgespielt wurde und was nicht — und ein erneuter Start
mit derselben Datei setzt genau dort fort, ohne etwas doppelt anzulegen.
