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
    'keiner Verbindung zu Streitkräften oder Fahrzeugherstellern.',
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

// English reading copies of the texts above, shown in the game when English is
// chosen. The German texts are the binding ones.

const _ownerEn =
    'Daniel Bocksteger\n'
    'Kirchstraße 42\n'
    '47546 Kalkar\n'
    'Germany';

const imprintEn = [
  LegalBlock('Information pursuant to § 5 DDG', _ownerEn),
  LegalBlock('Contact', 'E-mail: $_mail'),
  LegalBlock(
    'Responsible for the content pursuant to § 18 (2) MStV',
    'Daniel Bocksteger, address as above',
  ),
  LegalBlock(
    null,
    '\nPanzergefecht is a private, non-commercial game. It has no '
    'connection to any armed forces or vehicle manufacturer.\n\nThis is an English reading copy. The German text is binding.',
  ),
];

const privacyEn = [
  LegalBlock(
    'Controller',
    '$_ownerEn\nE-mail: $_mail\n\n'
        'This notice applies to the game Panzergefecht in the browser and in '
        'the apps for iPhone, iPad and Android. The privacy notice at '
        'regetskcob.de/legal applies to the rest of the website.',
  ),
  LegalBlock(
    'Providing the game',
    'The files of the game are hosted on GitHub Pages (GitHub Inc., USA). '
        'When you open the page, GitHub processes technically necessary '
        'access data, including the IP address, to deliver the page and to '
        'protect it against abuse. To display the game, its runtime '
        '(Flutter) also loads fonts and program libraries from Google '
        'servers (gstatic.com); the IP address is transmitted in this case '
        'as well. The legal basis is Art. 6 (1) (f) GDPR, our interest is a '
        'working and secure game.\n\n'
        'You download the apps for iPhone and iPad from Apple\'s App Store. '
        'Apple\'s privacy terms apply to downloads and updates, we receive '
        'no data about you. The app brings its fonts with it and loads '
        'nothing from Google.',
  ),
  LegalBlock(
    'Game account and saved games',
    'The game uses Supabase (Supabase Inc.) with servers in Ireland (EU) '
        'for saved games, the leaderboard and multiplayer. On first start an '
        'anonymous guest account with a random identifier is created. The '
        'following is stored: your call sign and the chosen vehicle with '
        'camouflage. Guests play without ranking. With an account, game '
        'statistics (rounds, wins, kills, damage, hits, survival time), '
        'experience, rank, rating, badges and the results of individual '
        'rounds are added. The legal basis is Art. 6 (1) (b) GDPR, because '
        'the game cannot be offered with progress and a leaderboard without '
        'this data.',
  ),
  LegalBlock(
    'Publicly visible',
    'The leaderboard shows your call sign, your rating and your statistics '
        'to everyone. If you open a public room, your call sign appears in '
        'the room list. If you do not want that, choose a call sign that '
        'does not contain your real name.',
  ),
  LegalBlock(
    'Multiplayer',
    'During a round, positions, shots and similar game events as well as '
        'your call sign, vehicle and team are sent to the other players in '
        'the same room via Supabase Realtime. These messages are only passed '
        'on and not stored permanently. The replay of the last round stays '
        'on your device only.',
  ),
  LegalBlock(
    'Camera (apps only)',
    'To join a waiting room by QR code, you can open the camera in the app. '
        'The image is searched for the code on your device only and is '
        'neither stored nor transmitted. The app asks for permission first, '
        'you can withdraw it in the settings at any time and type the room '
        'code instead.',
  ),
  LegalBlock(
    'Account with e-mail address (optional)',
    'If you secure your guest account with an e-mail address, Supabase '
        'stores the address to sign you in and to send you sign-in and '
        'confirmation mails. These mails are sent through the mail server of '
        'our web host do.de (Domain-Offensive), which receives your e-mail '
        'address and the content of the mail for this purpose. The address '
        'is never shown to other players, only your call sign appears '
        'publicly. If a sign-in with GitHub or Google is offered and you use '
        'it, we receive your e-mail address and an identifier of the account '
        'from there. The legal basis is Art. 6 (1) (b) GDPR.',
  ),
  LegalBlock(
    'Storage on your device',
    'The game keeps the sign-in session, your choice to play as a guest, '
        'whether you have seen the briefing and, in the browser, the room '
        'opened last in the local storage of your browser or the app. It '
        'sets no cookies, uses no analytics or advertising services and '
        'creates no usage profiles.',
  ),
  LegalBlock(
    'Retention',
    'The data of your account stays stored as long as the account exists. '
        'You can delete your account, a guest account too, in the game at '
        'any time: via the Account button at the top, then "Delete account". '
        'Rank, rating, badges, all saved games, your call sign and a stored '
        'e-mail address are deleted immediately and permanently. You can '
        'also request deletion by e-mail to $_mail.',
  ),
  LegalBlock(
    'Transfer to the USA',
    'GitHub, Google and Supabase are companies based in the USA. Where data '
        'reaches the USA, the providers rely on the EU-US Data Privacy '
        'Framework or on EU standard contractual clauses.',
  ),
  LegalBlock(
    'Your rights',
    'You have the right of access, rectification, erasure, restriction of '
        'processing and data portability as well as the right to object to '
        'processing (Art. 15 to 21 GDPR). Contact $_mail for this. You can '
        'also lodge a complaint with a data protection supervisory '
        'authority; the competent one is the State Commissioner for Data '
        'Protection and Freedom of Information of North Rhine-Westphalia.',
  ),
  LegalBlock(
    null,
    '\nAs of: 8 October 2026\n\nThis is an English reading copy. The German '
    'text is binding.',
  ),
];
