import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/env.dart';
import '../../game/tank_game.dart';
import '../../net/room.dart';
import '../theme.dart';
import 'account_panel.dart';
import 'choice_row.dart';
import 'fit_or_scroll.dart';
import 'legal.dart';
import 'pad_pairing.dart';
import 'panel.dart';
import '../../l10n/l10n.dart';
import '../../tv/tv_input.dart';

/// Round profile button in the corner of the start page and the waiting
/// room. Opens the account: who you play as, securing or signing in, and
/// deleting a lasting account.
class AccountButton extends StatelessWidget {
  const AccountButton({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tr('Konto', 'Account'),
      onPressed: () => AccountSheet.show(context, game),
      icon: const Icon(Icons.account_circle_outlined),
    );
  }
}

class AccountSheet extends StatefulWidget {
  const AccountSheet({required this.game, super.key});

  final TankGame game;

  static Future<void> show(BuildContext context, TankGame game) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: onTv ? 1100 : 560,
            maxHeight: 760,
          ),
          // Picking another language below redraws the whole sheet in it.
          child: ValueListenableBuilder<AppLang>(
            valueListenable: L10n.lang,
            builder: (context, _, _) => AccountSheet(game: game),
          ),
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

  TankGame get _game => widget.game;

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
        title: Text(tr('KONTO LÖSCHEN?', 'DELETE ACCOUNT?')),
        content: Text(
          tr(
            'Dein Konto ${_game.accounts.email ?? ''} wird mit Rang, Wertung, '
                'Abzeichen, allen Spielständen und deinem Rufnamen endgültig '
                'gelöscht, auf allen Geräten. Das lässt sich nicht rückgängig '
                'machen.',
            'Your account ${_game.accounts.email ?? ''} will be permanently '
                'deleted with rank, rating, badges, all saved games and your '
                'call sign, on all devices. This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('ABBRECHEN', 'CANCEL')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BwColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('ENDGÜLTIG LÖSCHEN', 'DELETE PERMANENTLY')),
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
          _error = tr(
            'Das Löschen hat nicht geklappt. Prüfe die Verbindung und '
                'versuch es noch einmal.',
            'Deleting failed. Check your connection and try again.',
          );
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
    // Name, language and controllers, then the account itself.
    final left = <Widget>[
      TextField(
        controller: _name,
        maxLength: 16,
        decoration: InputDecoration(
          labelText: tr('RUFNAME', 'CALL SIGN'),
          helperText: tr(
            'Öffentlich sichtbar, zum Beispiel in der '
                'Bestenliste',
            'Publicly visible, for example on the leaderboard',
          ),
        ),
        onChanged: _rename,
      ),
      const SizedBox(height: 12),
      Text(
        tr('SPRACHE', 'LANGUAGE'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      // The game keeps the choice with the account, so it
      // comes along to every device.
      ChoiceRow<AppLang>(
        options: [
          for (final lang in AppLang.values)
            (lang, lang.label.toUpperCase(), null),
        ],
        selected: L10n.current,
        onSelected: (lang) {
          if (lang != null) {
            unawaited(L10n.set(lang));
          }
        },
      ),
      const SizedBox(height: 16),
      ControllerSection(game: _game),
    ];
    final right = <Widget>[
      if (Env.accounts)
        AccountPanel(
          accounts: accounts,
          onCallSign: _game.claimCallSign,
          callSign: _game.myName,
          onSignedOut: () => Navigator.of(context).pop(),
          initiallyOpen: true,
        )
      else
        Text(
          tr(
            'Du spielst als Gast, ohne Wertung.',
            'You play as a guest, without ranking.',
          ),
        ),
      // A guest has nothing lasting to delete, signing in or
      // securing the account above is what they are offered.
      ValueListenableBuilder(
        valueListenable: accounts.user,
        builder: (context, _, _) => accounts.isGuest
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    tr('KONTO LÖSCHEN', 'DELETE ACCOUNT'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'Löscht dein Konto mit Rang, Wertung, Abzeichen, allen '
                          'Spielständen und deinem Rufnamen. Danach spielst du als '
                          'neuer Gast weiter.',
                      'Deletes your account with rank, rating, badges, all '
                          'saved games and your call sign. Afterwards you '
                          'carry on as a new guest.',
                    ),
                    style: const TextStyle(
                      color: BwColors.textDim,
                      fontSize: 13,
                    ),
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
                    label: Text(tr('KONTO LÖSCHEN', 'DELETE ACCOUNT')),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: BwColors.danger),
                    ),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 12),
      const LegalLinks(),
    ];
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
                  tr('KONTO', 'ACCOUNT'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: tr('Schließen', 'Close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Flexible(
            child: FitOrScroll(
              padding: const EdgeInsets.only(right: 8),
              // The television has the width for two columns.
              child: onTv
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _column(left)),
                        const SizedBox(width: 28),
                        Expanded(child: _column(right)),
                      ],
                    )
                  : _column([...left, const SizedBox(height: 16), ...right]),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _column(List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
}
