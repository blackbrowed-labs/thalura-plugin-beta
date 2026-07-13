---
title: Aufgabenmodule
description: Was Thalura für dich tun kann — von der Jahresplanung bis zur Methodenberatung.
---

# Was Thalura für dich tun kann

Du steuerst Thalura in normaler Sprache. Beschreibe einfach, was du brauchst —
Thalura erkennt, welche Fähigkeit gefragt ist, und legt los. Tippst du `/`,
findest du alle Fähigkeiten außerdem als `thalura:`-Einträge im Menü — nötig
ist das nicht, deine Beschreibung in eigenen Worten genügt immer.

## Schuljahresplanung (Schuljahresplanung)

Plant dein Schuljahr über die einzelnen Einheiten hinweg.
*Sag z. B.:* „Plane mein Englisch-Schuljahr für die 10. Klasse."

*Klassen über Jahre hinweg:* Du kannst eine Klasse mit ihrem Vorjahr verknüpfen
(z. B. E9 → E10) — auf Wunsch oder über ein kurzes Angebot, wenn du eine neue
Klasse anlegst, die eine Vorjahresgruppe fortsetzt. Beim Planen und Reflektieren
kann Thalura dann auf die Erfahrungen aus dem Vorjahr zurückgreifen: was gut lief,
welche Methoden funktioniert haben, wiederkehrende Stärken und Schwächen. Der Blick
ins Vorjahr ist rein lesend und enthält keine Noten.

Thalura führt außerdem eine stets aktuelle **Schuljahresübersicht** als Dokument — alle Klassen des laufenden Schuljahres mit ihren Einheiten (verlinkt zur jeweiligen Einheitenplanung) und der Kompetenzabdeckung. Die Datei liegt direkt im Thalura-Ordner und aktualisiert sich bei jeder Änderung von selbst. Sie ist nicht zum Bearbeiten gedacht — eigene Änderungen würden bei der nächsten Aktualisierung überschrieben.

## Unterrichtseinheit planen (Unterrichtseinheit)

Entwirft eine vollständige Unterrichtseinheit mit Lernzielen und Verlauf.
*Sag z. B.:* „Plane eine Unterrichtseinheit zu Utilitarismus."

*Schon einmal gemacht?* Eine fertige Einheit kannst du aufheben und später für
eine andere Klasse oder ein neues Schuljahr wiederverwenden — siehe
[Bibliothek](./bibliothek.md).

## Reflexion (Reflexion)

Hilft dir, eine gehaltene Einheit auszuwerten und festzuhalten, was du beim
nächsten Mal anders machen würdest.
*Sag z. B.:* „Lass uns meine letzte Einheit reflektieren."

## Verlaufsplan (Verlaufsplan)

Erstellt den detaillierten Verlauf einer einzelnen Unterrichtsstunde.
*Sag z. B.:* „Plane die nächste Stunde dieser Einheit."

## Aufgabenfolien (Aufgabenfolien)

Erstellt pro Stunde einen projektionsfertigen Foliensatz mit den Arbeitsaufträgen
für die SuS — gedacht als **Anzeige während der Arbeitsphase**: Die Folien bleiben
an der Wand, solange die SuS arbeiten, sodass jederzeit sichtbar ist, was gerade zu
tun ist. Eine Folie steht für eine Arbeitsphase; zusammengehörende Schritte einer
Aktivität (z. B. „Bearbeite das Arbeitsblatt, besprich dich dann mit deinem rechten
Sitznachbarn") stehen gemeinsam auf einer Folie, nicht eine Aufgabe pro Folie.

So läuft es ab: Beim Planen einer Stunde schlägt Thalura den Folieninhalt schon im
Stundenentwurf vor, sodass du beim Prüfen der Stunde siehst, was später auf die
Folien kommt. Die fertige `.pptx` wird erst erzeugt, **nachdem die Stunde validiert
ist** — auf deinen Wunsch oder über ein kurzes Angebot nach der Validierung.

Ändert sich beim Prüfen der Folien grundlegend etwas an den Aufgaben (eine andere
Aufgabe, ein anderer Operator, eine andere Sozialform), übernimmt Thalura die
Änderung zurück in den Stundenentwurf — Folien und Stundenplanung sollen nicht
auseinanderlaufen. Rein kosmetische Änderungen an den Folien wirken sich nicht auf
die Stunde aus.

Die Aufgabenfolien sind standardmäßig eingeschaltet. Du kannst sie über
`/thalura:config behaviour` aus- und wieder einschalten — es gibt dazu keine Frage
bei der Einrichtung.

## Arbeitsblätter, Folien und Handouts (Arbeitsblätter, Folien, Handouts)

Erzeugt Unterrichtsmaterial — vom Arbeitsblatt bis zur Foliensatz.
*Sag z. B.:* „Erstelle ein Arbeitsblatt zu diesem Text."

*Hinweis:* Wenn du ein Material überarbeiten lässt, das du selbst bearbeitet hast (ein ausgetauschtes Bild, ergänzter Inhalt, eigene Formatierung), bearbeitet Thalura die bestehende Datei direkt und behält deine Änderungen, die Kopf- und Fußzeile der Schule sowie die Formatierung bei — es wird nicht von Grund auf neu erstellt. Alles, was Thalura nicht selbst erzeugt hat — etwa ein von dir eingesetztes Bild oder ein von dir getippter Text — gilt dabei als deine Änderung und wird bei einer Überarbeitung niemals entfernt oder „aufgeräumt", solange du oder einer deiner Kommentare es nicht ausdrücklich verlangt. Steht eine deiner Änderungen der gewünschten Anpassung im Weg, fragt Thalura nach, statt selbst zu entscheiden.

*PDF bei Validierung:* Wenn du ein schülerorientiertes Material — also ein Arbeitsblatt, Handout, einen Lesetext, einen Foliensatz oder das Aufgabenblatt einer Lernkontrolle — validierst, legt Thalura automatisch eine PDF-Datei davon neben die bearbeitbare Datei. Die PDF ist sofort druckbereit und kann direkt weitergegeben oder auf eine Schulplattform hochgeladen werden. Validierst du dasselbe Material ein weiteres Mal nach einer Überarbeitung, wird die PDF aktualisiert und bleibt so stets aktuell. Wie viele und welche Materialien eine PDF erhalten, kannst du über die erweiterte Einstellung `pdf_on_validation` anpassen — sie wird bei der Einrichtung nicht abgefragt. Die Einstellung änderst du über `/thalura:config behaviour`.

*Anklickbare Verzeichnisse:* Die Materialübersicht sowie deine Einheiten- und Stundenpläne sind jetzt anklickbare Verzeichnisse. In der Materialübersicht steht hinter jedem Material ein Kürzel, mit dem du die Datei direkt öffnest: `[DOCX]` (bzw. `[PPTX]` bei Foliensätzen) öffnet die bearbeitbare Datei, und sobald das Material validiert ist, öffnet ein zusätzliches `[PDF]` die druckfertige PDF. In der Einheitenplanung und in den Verlaufsplänen werden die genannten Materialien und Stunden ebenso zu Verweisen, die du anklicken kannst — du musst die Datei nicht mehr im Ordner suchen. Materialien, die noch Entwürfe (Entwurf) sind, sind bereits verlinkt (sie haben aber noch kein PDF); nur geplante, noch nicht erstellte Materialien bleiben schlichter Text ohne Link. Die Verweise sind relativ gesetzt, sie funktionieren also weiter, wenn du deinen Thalura-Ordner verschiebst oder eine Sicherung wiederherstellst. Benennst du eine Datei einmal außerhalb von Thalura im Finder um, kann ein Verweis ins Leere zeigen — der Link heilt sich beim nächsten Erzeugen des jeweiligen Dokuments von selbst.

*Bildgenerierung:* Ist ein Bildgenerierungs-Werkzeug verbunden, erzeugt Thalura die im Materialvorschlag enthaltenen Bilder automatisch — gibst du den Vorschlag frei, sind die Bilder eingeschlossen, und es folgt keine zweite Rückfrage. Ohne ein solches Werkzeug bleibt der bisherige manuelle Ablauf unverändert: Thalura setzt für jedes Bild wie gewohnt einen Platzhalter mit dem zugehörigen Bild-Prompt ein. Lässt sich ein einzelnes Bild nicht erzeugen, erhält genau dieses Bild den gewohnten Platzhalter samt einem kurzen Hinweis im Chat, während das übrige Material vollständig fertiggestellt wird.

## Differenzierung (Differenzierung)

Passt Material an unterschiedliche Leistungsniveaus an.
*Sag z. B.:* „Differenziere dieses Arbeitsblatt für drei Niveaus."

*Hinweis:* Eine differenzierte Variante wird aus dem Ausgangsmaterial abgeleitet — Thalura kopiert es und passt die Kopie an, sodass die Kopf- und Fußzeile und die Formatierung erhalten bleiben. Hast du das Ausgangsmaterial selbst bearbeitet, übernimmt die Variante deine Änderungen unverändert — auch beim Differenzieren wird nichts davon entfernt oder ersetzt.

## Bildgenerierungs-Prompts

Formuliert Prompts für die Bilderzeugung zu deinem Unterricht.
*Sag z. B.:* „Schreib mir einen Bild-Prompt für ein Tafelbild zur Französischen
Revolution."

*Hinweis:* Dieser Baustein liefert dir einen eigenständigen Bild-Prompt zum Kopieren, den du selbst bei einem Bildgenerator einlöst. Das automatische Erzeugen freigegebener Bilder gehört zur Materialerstellung und greift nur dort, sobald ein Bildgenerierungs-Werkzeug verbunden ist.

## Klausur mit Erwartungshorizont (Klausur mit Erwartungshorizont)

Erstellt eine Leistungsüberprüfung samt Bewertungsraster (Erwartungshorizont).
*Sag z. B.:* „Erstelle eine Klausur zu dieser Einheit mit Erwartungshorizont."

## Compliance-Prüfung (Compliance-Prüfung)

Prüft deine Materialien gegen die Vorgaben der BSB.
*Sag z. B.:* „Prüfe diese Klausur auf BSB-Konformität."

## Methodenberatung (Methodenberatung)

Empfiehlt passende Unterrichtsmethoden für dein Vorhaben.
*Sag z. B.:* „Welche Methode passt für diese Doppelstunde?"

---

Daneben gibt es Hilfsfunktionen: deine Einstellungen ansehen oder ändern
(`/thalura:config`) und den aktuellen Status prüfen (`/thalura:status`).

Über `/thalura:config` passt du auch nach der Einrichtung alles Wesentliche an,
ohne neu einzurichten:

- **Profil** – Name, Kürzel, E-Mail, deine Fächer und die Sprache deiner
  Materialien.
- **Schule** – Schulname, dein Stundenraster (Einzel- und Doppelstunden, auch
  mit Pause), sowie Bundesland und Schulform.
- **Verhalten** – die drei Schalter, die steuern, wie Thalura beim Arbeiten
  vorgeht: die Aufgabenfolien (standardmäßig ein), das automatische PDF beim
  Validieren (`pdf_on_validation`) und die Compliance-Vorprüfung. Diese
  Einstellungen änderst du über `/thalura:config behaviour` — sie bleiben bei
  Plugin-Aktualisierungen erhalten und werden automatisch übernommen.
- **Einstellungen** – deine gemerkten Vorlieben (z. B. bevorzugte Methoden).
- **Benennung** – die Muster, nach denen deine Dateien benannt werden.
- **Standardmaterial** – die Liste deiner üblichen Klassenraum-Materialien (z. B. Post-its, Kreppband, Stifte), an der sich Thalura bei der Stundenplanung orientiert. Optional und schon sinnvoll vorbelegt: streiche, was du nicht hast, ergänze, was du zusätzlich nutzt. Thalura richtet sich nach deiner Liste, schränkt dich aber nie ein und meckert nie über fehlendes Material.

Sag z. B.: „Ändere meinen Stundenraster" oder „Wie sollen meine Dateien heißen?".

### Erweiterte Einstellung: PDF bei Validierung (`pdf_on_validation`)

Diese Einstellung legt fest, für welche Materialien Thalura beim Validieren
automatisch eine PDF-Datei erstellt. Sie wird bei der Einrichtung nicht abgefragt
und ist eine fortgeschrittene Einstellung.

| Wert | Verhalten |
|---|---|
| `"student_facing"` (Standard) | Nur schülerorientierte Materialien (Arbeitsblätter, Handouts, Lesetexte, Foliensätze, Aufgabenblätter) erhalten eine PDF. |
| `"all"` | Alle validierten Materialien erhalten eine PDF — auch lehrerorientierte Dokumente wie der Erwartungshorizont. |
| `"off"` | Keine PDF wird automatisch erstellt. Bereits vorhandene PDF-Dateien werden nicht gelöscht. |

Die Einstellung änderst du über `/thalura:config behaviour` oder auf Anfrage an
Thalura. Sie wird in der `config/behaviour.json` gespeichert und bleibt bei
Plugin-Aktualisierungen erhalten.
