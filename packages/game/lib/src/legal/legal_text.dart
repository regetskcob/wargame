// Impressum and privacy notice of the game. Plain Dart without Flutter, so
// the in-game dialog and tool/legal_pages.dart, which writes the pages at
// /impressum/ and /datenschutz/ next to the web build, share one text.

class LegalBlock {
  const LegalBlock(this.heading, this.body);

  final String? heading;
  final String body;
}

const _owner =
    'Daniel Bocksteger\n'
    'Kirchstraße 42\n'
    '47546 Kalkar\n'
    'Deutschland';

const _mail = 'regetskcob@icloud.com';

const imprint = [
  LegalBlock('Angaben gemäß § 5 DDG', _owner),
  LegalBlock('Kontakt', 'E-Mail: $_mail'),
  LegalBlock(
    'Verantwortlich für den Inhalt nach § 18 Abs. 2 MStV',
    'Daniel Bocksteger, Anschrift wie oben',
  ),
  LegalBlock(
    null,
    '\nPanzergefecht ist ein privates, nicht kommerzielles Spiel. Es steht in '
    'keiner Verbindung zur Bundeswehr oder zu den Herstellern der '
    'gezeigten Fahrzeuge.',
  ),
];

const privacy = [
  LegalBlock(
    'Verantwortlicher',
    '$_owner\nE-Mail: $_mail\n\n'
        'Diese Erklärung gilt für das Spiel Panzergefecht im Browser und in '
        'den Apps für iPhone, iPad und Android. Für die übrige '
        'Website gilt die Datenschutzerklärung unter regetskcob.de/legal.',
  ),
  LegalBlock(
    'Bereitstellung des Spiels',
    'Die Dateien des Spiels liegen bei GitHub Pages (GitHub Inc., USA). '
        'Beim Aufruf verarbeitet GitHub technisch notwendige Zugriffsdaten, '
        'darunter die IP-Adresse, um die Seite auszuliefern und gegen '
        'Missbrauch zu schützen. Die Laufzeitumgebung des Spiels (Flutter) '
        'lädt zur Darstellung außerdem Schriften und Programmbibliotheken '
        'von Servern von Google (gstatic.com); dabei wird ebenfalls die '
        'IP-Adresse übermittelt. Rechtsgrundlage ist Art. 6 Abs. 1 lit. f '
        'DSGVO, unser Interesse ist ein funktionierendes und sicheres Spiel.\n\n'
        'Die Apps für iPhone und iPad lädst du aus dem App Store von Apple. '
        'Für Download und Updates gelten die Datenschutzbestimmungen von '
        'Apple, wir erhalten dabei keine Daten über dich. Die App bringt '
        'ihre Schriften mit und lädt nichts von Google.',
  ),
  LegalBlock(
    'Spielkonto und Spielstände',
    'Für Spielstände, Bestenliste und Mehrspieler nutzt das Spiel Supabase '
        '(Supabase Inc.) mit Servern in Irland (EU). Beim ersten Start wird '
        'ein anonymes Gastkonto mit einer zufälligen Kennung angelegt. Dazu '
        'werden gespeichert: dein Rufname und das gewählte Fahrzeug mit '
        'Tarnung. Gäste spielen ohne Wertung. Mit einem Konto kommen '
        'Spielstatistiken (Runden, Siege, Abschüsse, Schaden, Treffer, '
        'Überlebenszeit), Erfahrung, Rang, Wertung, Abzeichen und die '
        'Ergebnisse einzelner Runden dazu. Rechtsgrundlage ist Art. 6 Abs. 1 '
        'lit. b DSGVO, denn ohne diese Daten lässt sich das Spiel mit '
        'Fortschritt und Bestenliste nicht anbieten.',
  ),
  LegalBlock(
    'Öffentlich sichtbar',
    'In der Bestenliste stehen dein Rufname, deine Wertung und deine '
        'Statistiken für alle sichtbar. Öffnest du einen öffentlichen Raum, '
        'erscheint dein Rufname in der Raumliste. Wähle deshalb einen '
        'Rufnamen, der nicht deinen echten Namen enthält, wenn du das nicht '
        'möchtest.',
  ),
  LegalBlock(
    'Mehrspieler',
    'Während einer Runde gehen Positionen, Schüsse und ähnliche '
        'Spielereignisse sowie dein Rufname, Fahrzeug und Team über Supabase '
        'Realtime an die anderen Spieler im selben Raum. Diese Nachrichten '
        'werden nur weitergereicht und nicht dauerhaft gespeichert. Die '
        'Wiederholung der letzten Runde bleibt nur auf deinem Gerät.',
  ),
  LegalBlock(
    'Kamera (nur in den Apps)',
    'Um einem Warteraum per QR-Code beizutreten, kannst du in der App die '
        'Kamera öffnen. Das Bild wird nur auf deinem Gerät nach dem Code '
        'durchsucht, weder gespeichert noch übertragen. Die App fragt vorher '
        'um Erlaubnis, du kannst sie in den Einstellungen jederzeit '
        'zurücknehmen und den Raumcode stattdessen eintippen.',
  ),
  LegalBlock(
    'Konto mit E-Mail-Adresse (freiwillig)',
    'Sicherst du dein Gastkonto mit einer E-Mail-Adresse, speichert Supabase '
        'die Adresse, um dich anzumelden und dir Anmelde- und '
        'Bestätigungsmails zu schicken. Verschickt werden diese Mails über '
        'den Mailserver unseres Webhosters do.de (Domain-Offensive), der dazu '
        'deine E-Mail-Adresse und den Inhalt der Mail erhält. Die Adresse '
        'wird anderen Spielern '
        'nie angezeigt, öffentlich erscheint nur dein Rufname. Sofern eine '
        'Anmeldung mit GitHub oder Google angeboten wird und du sie nutzt, '
        'erhalten wir von dort deine E-Mail-Adresse und eine Kennung des '
        'Kontos. Rechtsgrundlage ist Art. 6 Abs. 1 lit. b DSGVO.',
  ),
  LegalBlock(
    'Speicherung auf deinem Gerät',
    'Das Spiel legt im lokalen Speicher deines Browsers oder der App die '
        'Anmeldesitzung, deine Wahl als Gast, ob du die Einweisung gesehen '
        'hast und im Browser den zuletzt eröffneten Raum ab. Es setzt '
        'keine Cookies, nutzt keine Analyse- oder Werbedienste und erstellt '
        'keine Nutzungsprofile.',
  ),
  LegalBlock(
    'Speicherdauer',
    'Die Daten deines Kontos bleiben gespeichert, solange das Konto besteht. '
        'Du kannst dein Konto, auch ein Gastkonto, jederzeit im Spiel löschen: '
        'oben über den Knopf Konto, dann „Konto löschen“. Dabei werden Rang, '
        'Wertung, Abzeichen, alle Spielstände, dein Rufname und eine '
        'hinterlegte E-Mail-Adresse sofort und endgültig gelöscht. Du kannst '
        'die Löschung auch per E-Mail an $_mail verlangen.',
  ),
  LegalBlock(
    'Übermittlung in die USA',
    'GitHub, Google und Supabase sind Unternehmen mit Sitz in den USA. '
        'Soweit dabei Daten in die USA gelangen, stützen sich die Anbieter '
        'auf das EU-US Data Privacy Framework oder auf '
        'EU-Standardvertragsklauseln.',
  ),
  LegalBlock(
    'Deine Rechte',
    'Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung '
        'der Verarbeitung und Datenübertragbarkeit sowie das Recht, der '
        'Verarbeitung zu widersprechen (Art. 15 bis 21 DSGVO). Wende dich '
        'dazu an $_mail. Du kannst dich außerdem bei einer '
        'Datenschutz-Aufsichtsbehörde beschweren, zuständig ist die '
        'Landesbeauftragte für Datenschutz und Informationsfreiheit '
        'Nordrhein-Westfalen.',
  ),
  LegalBlock(null, '\nStand: 8. Oktober 2026'),
];
