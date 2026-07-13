---
title: Aktualisieren
description: Neue Versionen einspielen und erfahren, wann eine Aktualisierung verfügbar ist.
---

# Aktualisieren

Thalura wird laufend weiterentwickelt. So spielst du neue Versionen ein und
erfährst, wann eine Aktualisierung bereitsteht.

## Eine Aktualisierung einspielen

### Claude Code

Führe den folgenden Befehl aus, um die neueste Version deines Kanals zu holen:

```
/plugin update thalura@blackbrowed-labs
```

Alternativ kannst du in den Marktplatz-Einstellungen die automatische
Aktualisierung aktivieren. Dann werden neue Versionen still eingespielt, und
Thalura gleicht beim nächsten Start deine Daten ab.

### Claude Cowork

Cowork bietet eine **einmalige Zustimmung zur automatischen Aktualisierung**.
Ist sie aktiviert, synchronisiert Cowork den Kanal automatisch; andernfalls
synchronisierst du deinen persönlichen Marktplatz von Hand neu.

> **Hinweis:** Die genaue Bezeichnung und Position dieser Einstellung in Cowork
> wird vor der Veröffentlichung dieses Handbuchs noch bestätigt und hier ergänzt.

## Wann ist eine Aktualisierung verfügbar?

Thalura ruft selbst nichts aus dem Netz ab, um nach Updates zu suchen. Es gibt
aber einfache Wege, auf dem Laufenden zu bleiben:

- **GitHub „Watch → Releases only"** auf deinem Kanal-Repository: Du bekommst
  eine E-Mail, sobald eine neue Version erscheint — der bequemste Weg.
- Die **Releases-Seite** deines Kanal-Repositorys zeigt alle Versionen.
- Die Datei **`CHANGELOG.md`** listet, was sich in jeder Version geändert hat.

Für Testerinnen und Tester werden neue Versionen zusätzlich im
Feedback-Kanal angekündigt.

## Nach einer Aktualisierung

Hat sich die Version geändert, gleicht Thalura beim nächsten Start
zuverlässig deine Konfiguration ab und ergänzt fehlende Voreinstellungen —
unabhängig davon, wie das Gespräch beginnt. Bei einer größeren Änderung weist
dich Thalura in deiner Sprache darauf hin, falls etwas deine Aufmerksamkeit
braucht. Du musst also nicht selbst nachschauen — Thalura sagt dir Bescheid,
wenn etwas zu tun ist.
