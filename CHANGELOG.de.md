# Änderungsprotokoll

Was jede Store-Version von Panzergefecht gebracht hat, neueste zuerst, als
ihre wichtigsten Punkte. Die Build-Nummer steht in Klammern; die Web-Version
unter <https://panzergefecht.de/play/> ist immer der neueste Stand
von `main`. Die Store-Texte eines Release liegen in
`store/ios/metadata/*/release_notes.txt`. Diese Datei ist die deutsche
Fassung von [`CHANGELOG.md`](CHANGELOG.md) und wird mit ihr zusammen
gepflegt.

## 1.8.0 (16) – 26.10.2026

- Panzergefecht hat eine eigene Adresse: Spiel, Raum-Links und QR-Codes
  zeigen jetzt auf <https://panzergefecht.de/play/>, und früher geteilte
  Links öffnen weiter die App
- Neues Aussehen nach dem Designsystem Horizont, im Spiel und auf der
  Landingpage: ruhige Olivflächen mit Haarlinien, Signalgelb nur für die
  eine Hauptaktion und die Auswahl, neue Schriften und jede Zahl in
  Monaspace
- Neues App-Icon auf allen Plattformen, dazu passend Startbildschirme, Top
  Shelf des Apple TV, Banner von Android TV und die iMessage-Icons: der
  Panzer von der Seite auf dem Horizont
- Jedes Symbol in Menüs, HUD, Kisten, Tutorial, Fernseher und Uhr kommt
  aus Horizonts schlankem, kantigem Satz
- Der Warteraum wie im Entwurf: der Raumcode groß, die Besatzungen mit
  Zahl, die Fahrzeuge als Karten mit ihren Werten als Balken; auf dem iPad
  nutzt er hochkant wie quer den ganzen Bildschirm
- Auf iPhone, iPad und Mac öffnen Konto löschen, Steuerung und
  Kopplungscode als Dialoge des Systems
- Infanterie geht in der Verteidigung über die Brücken statt durch den
  Fluss
- NEUES SPIEL des Gastgebers nimmt alle mit, die noch auf dem
  Rundenende stehen, statt Gäste im Warteraum zurückzulassen
- Auf dem Fernseher ist die Anmelde-Karte der Startseite ein Fokus-Halt
  statt zwei
- Wer nach einem Verbindungsabbruch zurückkommt, schließt den Raumkanal
  nicht mehr gleich wieder, und Apple Watch und Fokusrahmen des Apple TV
  laufen ruhiger

## 1.7.0 (15) – 18.10.2026

- Die geschlossene Zone eines Gefechts hält 30 Sekunden und zieht sich
  dann ganz zusammen, mit jeder Sekunde mehr Schaden, so endet jede Runde
- Ein Gefecht, das allein im Raum beginnt, füllt sich mit CPU-Panzern auf,
  statt ohne Gegner weiterzulaufen
- Jede abgewehrte Welle nach der achten bringt in der Verteidigung 30
  Erfahrung, 15, wenn der Stützpunkt am Ende fällt
- Die Kamera fährt über den Rand des Verteidigungsfelds hinaus, so
  verdeckt das Feld oben weder Panzer noch Kisten
- Die deutschen Texte sagen überall „Gewonnen“ statt „Sieg“, vom
  Rundenende über die Bestenliste bis zur Uhr und zur Live-Aktivität
- Raum-Links aus dem Web öffnen die Mac-App, und ein Mac zählt nie als
  Handy, wie klein sein Fenster auch ist

## 1.6.1 (13) – 12.10.2026

- Auf dem Apple TV öffnet die Menü-Taste ein Rundenmenü: in der
  Verteidigung das Feld mit allen Geschützen und Upgrades, und immer den
  Weg hinaus, mit Wischen gewählt und per Klick oder Play/Pause gedrückt
- Zielhilfe und Kameraden nehmen sich einen Hubschrauber vor, wenn sonst
  nichts in Reichweite ist, so hält der letzte Hubschrauber eine Welle
  nicht mehr ewig offen
- Die Steuerungskarten der Einführung lassen sich auf dem Fernseher mit
  Fernbedienung und Controller ausprobieren, ein Klick drückt die Taste im
  Fokus
- Textfelder auf dem Fernseher öffnen die Tastatur erst per Klick, und die
  Kontoseite zeigt, dass die Anmelde-Mail unterwegs ist
- CPU-Panzer, die sich an einem Gebäude am Inselufer vorbeidrücken, werden
  nicht mehr ins tiefe Wasser geschoben

## 1.6.0 (12) – 11.10.2026

- Zwei neue Gelände: der Bergwald mit dichtem Wald, Geröll und Hügeln,
  und die Inseln mit mehr Wasser als Land, verbunden durch Holzbrücken,
  mit Flachwasser, durch das Panzer langsam waten
- Zwei neue Karten für die Verteidigung, Flussufer und Haarnadel, und ein
  neuntes Fahrzeug ab Stufe 6: der Igel, ein Raketenwerfer mit vier
  Raketen je Salve, ab Welle 6 auch auf der Gegnerseite
- CPU-Panzer fahren, was die Menschen in der Runde fahren, so trifft jede
  Stufe auf ihresgleichen; bei Rot gegen Blau wird verteilt, wer auf AUTO
  steht, sodass Neulinge mit Erfahrenen zusammen spielen
- Wenn CPU-Panzer mitspielen, dann mindestens so viele wie Spieler; sie
  gleichen zu kleine Teams aus, auf beiden Seiten in denselben Fahrzeugen,
  und Kameraden in der Verteidigung fahren die Fahrzeuge ihrer Welle
- Niemand kann mehr in fremdem Namen spielen: Jede Nachricht trägt ein
  Zeichen, das nur ihr Absender setzen kann, und wer einen Raum leitet,
  sagt der Server
- Verlässt der Gastgeber einer Verteidigung die Runde endgültig, übernimmt
  der nächste Spieler Wellen, Stützpunkt und Geschütze; Runden gegen
  CPU-Panzer zählen für die Zeit, die der Server gemessen hat
- Mörser und Haubitzen halten ihre Granaten dorthin vor, wo das Ziel sein
  wird, so hält ein Mörser Panzer auf der Straße auf
- Eine Wiederholung kann die ganze Karte von oben zeigen (*Gesamtkarte*
  oder die Taste M)
- Gäste sehen im Warteraum Schwierigkeit, Gelände und Teams des
  Gastgebers, und alles heißt überall gleich: Münzen, Geschütze und
  Aufrüstung
- Korrekturen: Ein Warteraum schließt sich nach einer Pause im
  Hintergrund-Tab nicht mehr, die Startseite bleibt ruhig, Töne kommen in
  einer vollen Verteidigung nicht mehr zu spät, und ein zweiter Daumen
  übernimmt einen Stick

## 1.5.0 (11) – 11.10.2026

- Gräben sind besetzt: drei Schützen und ein MG feuern auf Soldaten und
  Panzer, jeder zielt selbst und blickt dorthin, woher der Feind kommt, und
  ab Welle 4 trägt einer eine Panzerfaust; auf der Straße liegt ein Graben
  quer von Rand zu Rand, Panzer beider Seiten kriechen darüber und bleiben
  danach kurz langsam, und feindliche Granaten setzen ihm jetzt zu
- Fußgruppen patrouillieren, statt auf ihrem Platz zu stehen, und pirschen
  sich an feindliche Panzer und Soldaten heran, die in Sicht kommen
- Stufen dauern länger: jede Stufe beginnt bei 0 und braucht den Schritt,
  den die Karte früher als Summe zeigte, und die Karte zählt innerhalb der
  Stufe
- Der letzte feindliche Hubschrauber einer Welle kommt zu den Verteidigern,
  statt weit draußen zu warten, und Panzergranaten treffen ihn etwas härter
- Der Verteidigungsladen markiert nach dem Kauf nichts mehr: Knöpfe sind
  nur hell, wenn das Geld reicht, sonst blass; Bauen sagt, wofür Geschütz
  oder Graben gut ist, und ein Hinweis meldet, sobald das Geld reicht
- Geschütze und Soldaten halten auf Soldaten vor, die quer durch ihr Feuer
  laufen
- Der Knopf zum Beenden der Wiederholung sitzt in der Leiste neben dem
  nächsten Panzer
- Konto löschen steht ganz unten auf der Kontoseite

## 1.4.1 (10) – 11.10.2026

- Tablets nutzen ihren Bildschirm in den Menüs: Startseite und Warteraum
  beginnen oben und nehmen die ganze Breite, zwei Spalten, wo Platz ist,
  Fahrzeugkarten wachsen mit, die Balken stehen daneben
- Große Tablets wie das 13"-iPad zeigen die Menüs größer, wie das HUD
- Das Konto ist eine eigene Seite mit zwei Spalten statt eines Fensters,
  das scrollte, und hat nur einen Weg zum Schließen
- Ein Sprachwechsel erreicht sofort jeden Text, auch die Rechtslinks und die
  Seiten unter dem Konto
- Tablets zeigen keinen Vibrationsschalter mehr, für den ihnen der Motor
  fehlt

## 1.4.0 (9) – 10.10.2026

- Ruhiger, schlanker Look: Rahmen nur noch an den äußeren Flächen, rahmenlose
  Kästen für Modi, Abschnitte und Panzerkarten, feine Linien an Knöpfen,
  umrissene kleine Symbole
- Konto: Den Rufnamen speichert der Haken oder Enter, die Registrierung
  übernimmt diesen Namen, die Sprache sitzt in der Titelzeile
- Gäste finden die Anmeldung auf einer Karte der Startseite
- Wer in einer verlorenen Schlacht länger durchhält, bekommt Erfahrung und
  sieht seinen Platz
- Das Handy als Controller trägt den ganzen Laden der Verteidigung
- Nur die App auf einem Handy wird Controller, nie ein Tablet oder Browser
- Zu zweit an einem Bildschirm: Jede Hälfte trägt ihre Teamfarbe
- CPU-Panzer sehen nachts, im Nebel und im Sand nicht weiter als Menschen
- Geräusche werden mit der Entfernung leiser, lange Verteidigungsrunden
  laufen flüssiger, Räume sind gegen Fluten, gefälschte Nachrichten und kurze
  Aussetzer geschützt
- Apple Watch: jeder Modus allein gegen CPU-Panzer, gewertet für das Konto
  auf dem iPhone

### Korrekturen

- Konto: Das E-Mail-Feld bietet die gespeicherte Adresse an, die Tastatur
  bleibt nach dem Schließen nicht mehr stehen, der Sprach-Chip folgt einem
  Tipp, die Beschriftung des Rufnamens wird nicht mehr abgeschnitten
- Räume: ein Host, wenn ein Browser seinen Raum in zwei Tabs öffnet, Gäste
  sehen im Warteraum den Modus des Hosts, Spieler über einen Raum-Link zählen
  zum Realtime-Budget, ein iPad mit zwei gekoppelten Handys flutet den Server
  nicht mehr
- Geteilter Bildschirm: startet erst, wenn der zweite Spieler in der Runde
  ist (keine leere Hälfte), Rahmen in Teamfarben, gleicher Modus und gleicher
  Endbildschirm für beide, benannter zweiter Spieler, auf Handys nie
  angeboten
- HUD: Die Zielhilfe bleibt an, wenn das HUD neu aufgebaut wird, eine
  Berührung holt die Sticks über einem Controller zurück, Gegnerpfeile zucken
  nicht mehr und rutschen nicht mehr über Anzeigen, Karte und Flächen, das
  Inventar weicht auf Tastatur-Bildschirmen der Verteidigungsleiste,
  Hinweise lassen die Sticks frei
- CPU-Panzer fahren die Fahrzeuge ihrer Stufe und greifen nach dem sanften
  Start an, Nichtstun gewinnt also nicht mehr
- Statistik: Die Trefferquote bleibt bei höchstens 100 %, eine
  Wertungsänderung von null wird ausgeblendet, die Bestenliste blendet leere
  und Gast-Zeilen aus und springt nicht mehr
- Der Startknopf bleibt an seinem Platz, wenn eine Wiederholung erscheint,
  die zuletzt gewählte Schwierigkeit bleibt auf dem Gerät gespeichert
- Fern-Reparaturen, Schnellfeuer und das Aufsammeln von Kisten werden auf
  Machbarkeit geprüft
- Das Motorgeräusch wird nicht mehr doppelt freigegeben

### Penetrations- und Lasttest ([#12](https://github.com/regetskcob/wargame/issues/12))

- Räume begrenzen Nachrichten pro Absender und Art und prüfen, was
  ankommt: gefälschte Rundenstarts, Raumschließungen, Explosionen, Granaten,
  endlose Geschwindigkeiten und Fluten erfundener Panzer, Flugzeuge, Drohnen,
  Geschütze, Truppen oder Gegenstände kommen nicht mehr durch
- Wer bis zu sechs Sekunden aussetzt, behält Panzer, Geschütze und als Host
  die Verteidigung; Tode von vor einer Revanche zählen nicht mehr
- Ein Erbauer erfährt jetzt, wenn der Host sein Geschütz zerstört hat
- Rufnamen verlieren unsichtbare und Rechts-nach-links-Zeichen
- Migration 0018: Realtime-Plätze unter einem Budget aus der Datenbank,
  gewertete Gegner nur, solange sie online sind, Abschüsse und Schaden an die
  Zeit seit der letzten Runde gebunden, höchstens 300 Runden am Tag,
  Abzeichen mit der Serverzeit gestempelt
- Wer über einen Raum-Link kommt, zählt zum Realtime-Budget
- Lange Verteidigungsrunden häufen keine gefallenen Soldaten, Krater,
  Flecken, Wracks und Wiederholungs-Positionen mehr an
- Schnelleres Zeichnen: Auf einem iPad Pro 2018 stieg eine Verteidigung in
  Welle 30 von etwa 65 auf 95 fps
- Ein zweites Handy, das während der Ergebnisse gekoppelt wird, hinterlässt
  keine leere Hälfte mehr, und das Inventar hält sich von der Bauleiste der
  Verteidigung fern

## 1.3.0 (8) – 10.10.2026

- Aus iMessage einen Chat in einen Raum einladen, das Rundenergebnis
  erscheint dort
- Fahnenraub zu zweit an einem Bildschirm, miteinander oder gegeneinander
- Das iPhone vibriert mit dem Spiel (abschaltbar)
- Teamrunden färben jeden Panzer rot oder blau
- Die Flak stoppt Jets mit Annäherungszünder, die Verteidigung ist neu
  ausbalanciert
- Die Bestenliste zählt Punkte statt nur der Elo-Wertung
- Ein sanfter Start für neue Spieler, und die Startseite wartet nicht mehr
  auf den Server
- Auf hochkant gehaltenen Handys sitzt die Zielhilfe direkt über dem
  Ziel-Stick

## 1.2.1 (7) – 09.10.2026

- Fahnenraub als vierter Modus, Rot gegen Blau mit CPU-Panzern auf beiden
  Seiten
- Tankstellen und Munitionsdepots füllen den Panzer auf und fliegen bei
  Treffern in die Luft
- Eine laufende Runde lässt sich nach kurzer Rückfrage verlassen
- Fahrzeuge tragen Tiernamen
- Die Bestenliste passt auf ein Handy
- Aufgeräumteres Starten, Beitreten und Einweisen

## 1.2.0 (6) – 09.10.2026

- Die Apple-Watch-App ist in jedem Build eingebettet und geprüft (Build 5
  war ohne sie hinausgegangen), gebaut von `tool/archive_ios.sh`
- Neue Store-Screenshots auf Deutsch und Englisch
- Store-Beschreibung auf den aktuellen Funktionsumfang gebracht

## 1.1.0 (3–5) – 08.10.2026 bis 09.10.2026

- Eine Apple-Watch-Version des Spiels
- Ein Handy wird per QR-Code zum Controller des Spiels auf Computer oder
  Tablet
- Zu zweit an einem Bildschirm im Browser und auf dem iPad, ohne
  Realtime-Kosten
- Räume folgen dem, was der Supabase-Plan trägt (vier Piloten, ein
  gemeinsames Last-Budget), und sagen, wenn alle belegt sind
- Das Spiel bleibt allein spielbar, wenn der Server es abweist
- Aufgeräumterer Warteraum und Einstellungen
- Builds mit zusammengeklebten dart-defines brechen in Xcode ab (Build 4
  erreichte deswegen den Server nicht)

## 1.0.0 (1–2) – 08.10.2026

- Die erste Version für iPhone und iPad
- Einzelspieler, Mehrspieler und Verteidigung
- Acht Fahrzeuge
- Touch-Steuerung mit Zielhilfe, hochkant und quer
- Konten per E-Mail mit Rang, Wertung und Abzeichen; Gäste spielen ohne
  Wertung
- Build 2: das Handy als Controller
