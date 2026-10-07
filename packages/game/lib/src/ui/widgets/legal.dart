import 'package:flutter/material.dart';

import '../../theme.dart';
import 'panel.dart';

/// "Impressum · Datenschutz" along the bottom edge of the welcome and the
/// start page. Each opens its text in a dialog.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12, color: BwColors.textDim);
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            onPressed: () => _show(context, 'IMPRESSUM', _imprint),
            child: const Text('Impressum', style: style),
          ),
          const Text('·', style: style),
          TextButton(
            onPressed: () => _show(context, 'DATENSCHUTZ', _privacy),
            child: const Text('Datenschutz', style: style),
          ),
        ],
      ),
    );
  }

  static void _show(BuildContext context, String title, List<_Block> text) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: Panel(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Schließen',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 8),
                    child: SelectionArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final block in text) ...[
                            if (block.heading != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 14,
                                  bottom: 4,
                                ),
                                child: Text(
                                  block.heading!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: BwColors.sand,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            Text(
                              block.body,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Block {
  const _Block(this.heading, this.body);

  final String? heading;
  final String body;
}

const _owner =
    'Daniel Bocksteger\n'
    'Kirchstraße 42\n'
    '47546 Kalkar\n'
    'Deutschland';

const _mail = 'regetskcob@icloud.com';

const _imprint = [
  _Block('Angaben gemäß § 5 DDG', _owner),
  _Block('Kontakt', 'E-Mail: $_mail'),
  _Block(
    'Verantwortlich für den Inhalt nach § 18 Abs. 2 MStV',
    'Daniel Bocksteger, Anschrift wie oben',
  ),
  _Block(
    null,
    '\nPanzergefecht ist ein privates, nicht kommerzielles Spiel. Es steht in '
    'keiner Verbindung zur Bundeswehr oder zu den Herstellern der '
    'gezeigten Fahrzeuge.',
  ),
];

const _privacy = [
  _Block(
    'Verantwortlicher',
    '$_owner\nE-Mail: $_mail\n\n'
        'Diese Erklärung gilt für das Spiel Panzergefecht. Für die übrige '
        'Website gilt die Datenschutzerklärung unter regetskcob.de/legal.',
  ),
  _Block(
    'Bereitstellung des Spiels',
    'Die Dateien des Spiels liegen bei GitHub Pages (GitHub Inc., USA). '
        'Beim Aufruf verarbeitet GitHub technisch notwendige Zugriffsdaten, '
        'darunter die IP-Adresse, um die Seite auszuliefern und gegen '
        'Missbrauch zu schützen. Die Laufzeitumgebung des Spiels (Flutter) '
        'lädt zur Darstellung außerdem Schriften und Programmbibliotheken '
        'von Servern von Google (gstatic.com); dabei wird ebenfalls die '
        'IP-Adresse übermittelt. Rechtsgrundlage ist Art. 6 Abs. 1 lit. f '
        'DSGVO, unser Interesse ist ein funktionierendes und sicheres Spiel.',
  ),
  _Block(
    'Spielkonto und Spielstände',
    'Für Spielstände, Bestenliste und Mehrspieler nutzt das Spiel Supabase '
        '(Supabase Inc.) mit Servern in Irland (EU). Beim ersten Start wird '
        'ein anonymes Gastkonto mit einer zufälligen Kennung angelegt. Dazu '
        'werden gespeichert: dein Rufname, das gewählte Fahrzeug mit Tarnung, '
        'Spielstatistiken (Runden, Siege, Abschüsse, Schaden, Treffer, '
        'Überlebenszeit), Erfahrung, Rang, Wertung, Abzeichen und die '
        'Ergebnisse einzelner Runden. Rechtsgrundlage ist Art. 6 Abs. 1 '
        'lit. b DSGVO, denn ohne diese Daten lässt sich das Spiel mit '
        'Fortschritt und Bestenliste nicht anbieten.',
  ),
  _Block(
    'Öffentlich sichtbar',
    'In der Bestenliste stehen dein Rufname, deine Wertung und deine '
        'Statistiken für alle sichtbar. Öffnest du einen öffentlichen Raum, '
        'erscheint dein Rufname in der Raumliste. Wähle deshalb einen '
        'Rufnamen, der nicht deinen echten Namen enthält, wenn du das nicht '
        'möchtest.',
  ),
  _Block(
    'Mehrspieler',
    'Während einer Runde gehen Positionen, Schüsse und ähnliche '
        'Spielereignisse sowie dein Rufname, Fahrzeug und Team über Supabase '
        'Realtime an die anderen Spieler im selben Raum. Diese Nachrichten '
        'werden nur weitergereicht und nicht dauerhaft gespeichert. Die '
        'Wiederholung der letzten Runde bleibt nur in deinem Browser.',
  ),
  _Block(
    'Konto mit E-Mail-Adresse (freiwillig)',
    'Sicherst du dein Gastkonto mit einer E-Mail-Adresse, speichert Supabase '
        'die Adresse, um dich anzumelden und dir Anmelde- und '
        'Bestätigungsmails zu schicken. Die Adresse wird anderen Spielern '
        'nie angezeigt, öffentlich erscheint nur dein Rufname. Sofern eine '
        'Anmeldung mit GitHub oder Google angeboten wird und du sie nutzt, '
        'erhalten wir von dort deine E-Mail-Adresse und eine Kennung des '
        'Kontos. Rechtsgrundlage ist Art. 6 Abs. 1 lit. b DSGVO.',
  ),
  _Block(
    'Speicherung im Browser',
    'Das Spiel legt im lokalen Speicher deines Browsers die Anmeldesitzung, '
        'deine Wahl als Gast und den zuletzt eröffneten Raum ab. Es setzt '
        'keine Cookies, nutzt keine Analyse- oder Werbedienste und erstellt '
        'keine Nutzungsprofile.',
  ),
  _Block(
    'Speicherdauer',
    'Die Daten deines Kontos bleiben gespeichert, solange das Konto besteht. '
        'Schreib eine E-Mail an $_mail, wenn dein Konto mit allen '
        'Spielständen gelöscht werden soll.',
  ),
  _Block(
    'Übermittlung in die USA',
    'GitHub, Google und Supabase sind Unternehmen mit Sitz in den USA. '
        'Soweit dabei Daten in die USA gelangen, stützen sich die Anbieter '
        'auf das EU-US Data Privacy Framework oder auf '
        'EU-Standardvertragsklauseln.',
  ),
  _Block(
    'Deine Rechte',
    'Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung '
        'der Verarbeitung und Datenübertragbarkeit sowie das Recht, der '
        'Verarbeitung zu widersprechen (Art. 15 bis 21 DSGVO). Wende dich '
        'dazu an $_mail. Du kannst dich außerdem bei einer '
        'Datenschutz-Aufsichtsbehörde beschweren, zuständig ist die '
        'Landesbeauftragte für Datenschutz und Informationsfreiheit '
        'Nordrhein-Westfalen.',
  ),
  _Block(null, '\nStand: Oktober 2026'),
];
