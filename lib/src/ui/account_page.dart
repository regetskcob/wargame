import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/env.dart';
import '../app/routes.dart';
import '../game/tank_game.dart';
import '../haptics.dart';
import '../net/room.dart';
import 'theme.dart';
import 'widgets/account_panel.dart';
import 'widgets/choice_row.dart';
import 'widgets/fit_or_scroll.dart';
import 'widgets/legal.dart';
import 'widgets/pad_pairing.dart';
import 'widgets/tablet_scale.dart';
import '../l10n/l10n.dart';
import '../tv/tv_input.dart';

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
      onPressed: () => AccountPage.open(context),
      icon: const Icon(Icons.account_circle_outlined),
    );
  }
}

/// The account as a page of its own over the game: the call sign, the
/// account it belongs to, then the settings of this device and the
/// controllers. A page instead of a dialog, so a large tablet shows all of
/// it side by side instead of a narrow sheet that scrolls.
class AccountPage extends StatefulWidget {
  const AccountPage({required this.game, super.key});

  final TankGame game;

  /// Shows the page over the game.
  static void open(BuildContext context) =>
      unawaited(context.push<void>(Routes.account));

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  var _busy = false;
  String? _error;

  /// Set once a new call sign is taken, so the field can say so until the
  /// next edit.
  var _nameSaved = false;
  late final _name = TextEditingController(text: widget.game.myName);

  TankGame get _game => widget.game;

  static bool get _vibrates => Haptics.onPhone && deviceIsPhone;

  @override
  void initState() {
    super.initState();
    _shownName = _game.myName;
    _game.pilotVersion.addListener(_reloadName);
  }

  /// The call sign the field was last filled with.
  late String _shownName;

  /// Signing in here brings the account's call sign along, unless the
  /// player is in the middle of typing a new one.
  void _reloadName() {
    if (_name.text.trim() == _shownName) {
      _name.text = _shownName = _game.myName;
    }
  }

  bool get _nameDirty => _name.text.trim() != _game.myName;

  bool get _nameValid => _name.text.trim().length >= 2;

  @override
  void dispose() {
    _game.pilotVersion.removeListener(_reloadName);
    _name.dispose();
    super.dispose();
  }

  /// Takes the call sign only on the save button or Enter: a name others
  /// see should not change with every key, and the player wants to know
  /// it was kept.
  void _rename() {
    if (!_nameDirty || !_nameValid) {
      return;
    }
    _game.claimCallSign(_name.text);
    _name.text = _shownName = _game.myName;
    setState(() => _nameSaved = true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GameColors.surface,
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
            style: FilledButton.styleFrom(backgroundColor: GameColors.danger),
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
    // The call sign, the account it belongs to, then the settings of this
    // device and the controllers in a quiet box of their own, as on the
    // start page.
    final left = <Widget>[
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _name,
        builder: (context, _, _) {
          final dirty = _nameDirty;
          final saved = _nameSaved && !dirty;
          return TextField(
            controller: _name,
            maxLength: 16,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: tr('RUFNAME', 'CALL SIGN'),
              helperText: saved
                  ? tr('Gespeichert', 'Saved')
                  : dirty
                  ? tr(
                      'Mit dem Haken oder Enter speichern',
                      'Save with the tick or Enter',
                    )
                  : tr(
                      'Öffentlich sichtbar, zum Beispiel in der '
                          'Bestenliste',
                      'Publicly visible, for example on the leaderboard',
                    ),
              helperStyle: saved
                  ? const TextStyle(color: GameColors.amber)
                  : null,
              // A phone has not the width for the hint beside the counter.
              helperMaxLines: 2,
              // Always there, so the field does not change width when it
              // turns into a button.
              suffixIcon: saved
                  ? const Icon(
                      Icons.check_circle_outlined,
                      color: GameColors.amber,
                    )
                  : IconButton(
                      tooltip: tr('Rufnamen speichern', 'Save call sign'),
                      onPressed: dirty && _nameValid ? _rename : null,
                      // Dim until there is something to save.
                      style: IconButton.styleFrom(
                        foregroundColor: GameColors.amber,
                        disabledForegroundColor: GameColors.textDim.withAlpha(
                          90,
                        ),
                      ),
                      icon: const Icon(Icons.check_outlined),
                    ),
            ),
            onChanged: (_) {
              if (_nameSaved) {
                setState(() => _nameSaved = false);
              }
            },
            onSubmitted: (_) => _rename(),
          );
        },
      ),
      const SizedBox(height: 24),
      if (Env.accounts)
        // Follows the saved call sign, which registering takes.
        ValueListenableBuilder<int>(
          valueListenable: _game.pilotVersion,
          builder: (context, _, _) => AccountPanel(
            accounts: accounts,
            onCallSign: _game.claimCallSign,
            callSign: _game.myName,
            callSignAbove: () {
              _rename();
              return _game.myName;
            },
            onSignedOut: () => Navigator.of(context).pop(),
            initiallyOpen: true,
          ),
        )
      else
        Text(
          tr(
            'Du spielst als Gast, ohne Wertung.',
            'You play as a guest, without ranking.',
          ),
        ),
      // A guest has nothing lasting to delete, signing in or
      // registering above is what they are offered.
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
                      color: GameColors.textDim,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GameColors.danger,
                      side: const BorderSide(color: GameColors.danger),
                    ),
                    onPressed: _busy ? null : _delete,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_forever_outlined),
                    label: Text(tr('KONTO LÖSCHEN', 'DELETE ACCOUNT')),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: GameColors.danger),
                    ),
                  ],
                ],
              ),
      ),
    ];
    final right = <Widget>[
      // Only phones: iPads and most Android tablets have no motor, the
      // switch would do nothing there.
      if (_vibrates)
        // A plain row: a ListTile would paint its ink behind the panel.
        ValueListenableBuilder<bool>(
          valueListenable: Haptics.on,
          builder: (context, on, _) => Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('VIBRATION', 'VIBRATION'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      tr(
                        'Treffer, Explosionen und Rundenstart spüren',
                        'Feel hits, blasts and the start of a round',
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: on,
                onChanged: (value) => unawaited(Haptics.set(value: value)),
              ),
            ],
          ),
        ),
      if (_vibrates) const SizedBox(height: 24),
      _ControllerBox(game: _game),
      const SizedBox(height: 12),
      const LegalLinks(),
    ];
    // Lets go of the keyboard before the page goes, however it is closed:
    // a field that keeps the focus past its route leaves the keyboard
    // standing over the page below.
    return PopScope(
      onPopInvokedWithResult: (_, _) =>
          FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: GameColors.background,
        // The same shade as the menus over the dark field.
        body: ColoredBox(
          color: GameColors.panel,
          child: MenuScale(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, box) {
                  // From a tablet up the account and this device sit side by
                  // side, so the page fits without scrolling.
                  final columns = onTv || box.maxWidth >= 760;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                            child: _title(context, narrow: box.maxWidth < 420),
                          ),
                          Expanded(
                            child: FitOrScroll(
                              // The call sign's label floats over its field
                              // and needs the room above it.
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                10,
                                20,
                                20,
                              ),
                              child: columns
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: FocusTraversalGroup(
                                            child: _column(left),
                                          ),
                                        ),
                                        const SizedBox(width: 32),
                                        Expanded(
                                          child: FocusTraversalGroup(
                                            child: _column(right),
                                          ),
                                        ),
                                      ],
                                    )
                                  : _column([
                                      ...left,
                                      const SizedBox(height: 20),
                                      ...right,
                                    ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The title with the language and the one way out. The language sits in
  /// the title line, on a narrow phone on a line of its own right below.
  Widget _title(BuildContext context, {required bool narrow}) {
    final title = Row(
      children: [
        Expanded(
          child: Text(
            tr('KONTO', 'ACCOUNT'),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        if (!narrow) const _Language(),
        const SizedBox(width: 4),
        IconButton(
          tooltip: tr('Schließen', 'Close'),
          // The remote starts on the page instead of the game below it.
          autofocus: onTv,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_outlined),
        ),
      ],
    );
    if (!narrow) {
      return title;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [title, const _Language(), const SizedBox(height: 4)],
    );
  }

  static Widget _column(List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
}

/// The controllers drawn like the controller box on the start page: a
/// quiet dark box without a frame, set apart from the account above.
class _ControllerBox extends StatelessWidget {
  const _ControllerBox({required this.game});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.sports_esports_outlined,
                  color: GameColors.sand,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  tr('CONTROLLER', 'CONTROLLERS'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: GameColors.textDim,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ControllerSection(game: game, heading: false),
          ],
        ),
      ),
    );
  }
}

/// The language in one short line. The game keeps the choice with the
/// account, so it comes along to every device.
class _Language extends StatelessWidget {
  const _Language();

  @override
  Widget build(BuildContext context) {
    // Listens itself: as a const widget it is not rebuilt with the sheet.
    return ValueListenableBuilder<AppLang>(
      valueListenable: L10n.lang,
      builder: (context, current, _) => Semantics(
        label: tr('Sprache', 'Language'),
        child: ChoiceRow<AppLang>(
          minHeight: 32,
          options: [
            for (final lang in AppLang.values)
              (lang, lang.label.toUpperCase(), null),
          ],
          selected: current,
          onSelected: (lang) {
            if (lang != null) {
              unawaited(L10n.set(lang));
            }
          },
        ),
      ),
    );
  }
}
