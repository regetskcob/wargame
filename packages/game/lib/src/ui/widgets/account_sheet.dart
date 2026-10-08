import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../env.dart';
import '../../game/space_game.dart';
import '../../net/room.dart';
import '../../theme.dart';
import 'account_panel.dart';
import 'legal.dart';
import 'panel.dart';

/// Round profile button in the corner of the start page and the waiting
/// room. Opens the account: who you play as, securing or signing in, and
/// deleting the account.
class AccountButton extends StatelessWidget {
  const AccountButton({required this.game, super.key});

  final SpaceGame game;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Konto',
      onPressed: () => AccountSheet.show(context, game),
      icon: const Icon(Icons.account_circle_outlined),
    );
  }
}

class AccountSheet extends StatefulWidget {
  const AccountSheet({required this.game, super.key});

  final SpaceGame game;

  static Future<void> show(BuildContext context, SpaceGame game) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
          child: AccountSheet(game: game),
        ),
      ),
    );
  }

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  var _busy = false;
  String? _error;
  late final _name = TextEditingController(text: widget.game.myName);

  SpaceGame get _game => widget.game;

  @override
  void initState() {
    super.initState();
    _game.pilotVersion.addListener(_reloadName);
  }

  /// Signing in here brings the account's call sign along.
  void _reloadName() {
    if (_name.text.trim() != _game.myName) {
      _name.text = _game.myName;
    }
  }

  @override
  void dispose() {
    _game.pilotVersion.removeListener(_reloadName);
    _name.dispose();
    super.dispose();
  }

  /// Takes the call sign while typing, the start page and the waiting
  /// room behind the sheet follow along. An empty field keeps the old one.
  void _rename(String value) {
    if (value.trim().isNotEmpty) {
      _game.claimCallSign(value);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BwColors.surface,
        title: const Text('KONTO LÖSCHEN?'),
        content: Text(
          _game.accounts.isGuest
              ? 'Dein Gastkonto wird mit Rang, Wertung, Abzeichen, allen '
                    'Spielständen und deinem Rufnamen endgültig gelöscht. '
                    'Das lässt sich nicht rückgängig machen.'
              : 'Dein Konto ${_game.accounts.email ?? ''} wird mit Rang, '
                    'Wertung, Abzeichen, allen Spielständen und deinem '
                    'Rufnamen endgültig gelöscht, auf allen Geräten. Das '
                    'lässt sich nicht rückgängig machen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ABBRECHEN'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BwColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ENDGÜLTIG LÖSCHEN'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _game.accounts.deleteAccount();
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Das Löschen hat nicht geklappt. Prüfe die Verbindung und '
              'versuch es noch einmal.';
        });
      }
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
    // Starts over as the fresh guest, in a fresh room, with nothing of the
    // deleted account left in the game.
    openFreshRoom();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _game.accounts;
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Column(
        // As tall as its content, scrolling only once that is too much.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'KONTO',
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
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _name,
                    maxLength: 16,
                    decoration: const InputDecoration(
                      labelText: 'RUFNAME',
                      helperText:
                          'Öffentlich sichtbar, zum Beispiel in der '
                          'Bestenliste',
                    ),
                    onChanged: _rename,
                  ),
                  const SizedBox(height: 12),
                  if (Env.accounts)
                    AccountPanel(
                      accounts: accounts,
                      onCallSign: _game.claimCallSign,
                      callSign: _game.myName,
                      onSignedOut: () => Navigator.of(context).pop(),
                    )
                  else
                    Text(
                      'Du spielst als Gast. Dein Fortschritt hängt an diesem '
                      '${kIsWeb ? 'Browser' : 'Gerät'}.',
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'KONTO LÖSCHEN',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Löscht dein Konto mit Rang, Wertung, Abzeichen, allen '
                    'Spielständen und deinem Rufnamen. Danach spielst du als '
                    'neuer Gast weiter.',
                    style: TextStyle(color: BwColors.textDim, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BwColors.danger,
                      side: const BorderSide(color: BwColors.danger),
                    ),
                    onPressed: _busy ? null : _delete,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_forever),
                    label: const Text('KONTO LÖSCHEN'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: BwColors.danger),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const LegalLinks(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
