import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../db/account_service.dart';
import '../../net/room.dart';
import '../../theme.dart';
import 'choice_row.dart';

/// Guest or lasting account: secure the guest account by e-mail or with a
/// login, sign into an account from another device, or sign out.
class AccountPanel extends StatefulWidget {
  const AccountPanel({
    required this.accounts,
    this.embedded = false,
    this.onCallSign,
    this.callSign,
    this.onSignedOut,
    this.initiallyOpen = false,
    super.key,
  });

  final AccountService accounts;

  /// Takes the call sign given when registering. Others only ever see this
  /// name, never the e-mail address.
  final ValueChanged<String>? onCallSign;

  /// The current call sign, to start the field with.
  final String? callSign;

  /// Called after signing out, right before the game starts over on the
  /// welcome page. A dialog closes itself here.
  final VoidCallback? onSignedOut;

  /// On the welcome page: always open, without the status line, and signing
  /// in comes first. Securing the fresh guest account there means creating
  /// a new one.
  final bool embedded;

  /// Starts with securing and signing in shown, for a guest who opened the
  /// account to do just that.
  final bool initiallyOpen;

  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

enum _Step { idle, codeSent }

class _AccountPanelState extends State<AccountPanel> {
  final _email = TextEditingController();
  late final _name = TextEditingController(
    text: _generated.hasMatch(widget.callSign ?? '') ? '' : widget.callSign,
  );

  /// The names the game hands out to fresh guests, not worth keeping.
  static final _generated = RegExp(r'^Panzer-\d{4}$');
  final _code = TextEditingController();
  late var _open = widget.initiallyOpen;
  late var _signIn = widget.embedded;
  var _step = _Step.idle;
  var _busy = false;
  String? _message;
  var _error = false;

  @override
  void initState() {
    super.initState();
    widget.accounts.providers.addListener(_refresh);
    unawaited(widget.accounts.loadProviders());
  }

  void _refresh() => setState(() {});

  Timer? _watch;

  /// A new address is confirmed with the link in the mail, often in another
  /// tab or on the phone. Ask every few seconds for up to ten minutes, so
  /// this page notices without a reload.
  void _watchConfirmation() {
    _watch?.cancel();
    var tries = 0;
    _watch = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted || ++tries > 120 || !widget.accounts.isGuest) {
        timer.cancel();
        return;
      }
      try {
        await widget.accounts.refresh();
      } on Object {
        return;
      }
      if (!widget.accounts.isGuest) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _step = _Step.idle;
            _message = 'E-Mail bestätigt, dein Konto steht.';
            _error = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _watch?.cancel();
    widget.accounts.providers.removeListener(_refresh);
    _email.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      _message = done;
      _error = false;
    } on AuthException catch (error) {
      _message = _describe(error);
      _error = true;
    } on Object catch (error) {
      _message = '$error';
      _error = true;
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  /// Signs out and starts over on the welcome page, with nothing of the
  /// account left in the game: no name, no progress, no open dialog.
  Future<void> _signOut() async {
    await _run(widget.accounts.signOut, 'Abgemeldet.');
    if (_error) {
      return;
    }
    forgetGuest();
    widget.onSignedOut?.call();
    openFreshRoom();
  }

  void _sendMail() {
    final email = _email.text.trim();
    final name = _name.text.trim();
    if (!_signIn && (name.length < 2 || name.length > 16)) {
      setState(() {
        _message =
            'Bitte einen Rufnamen mit 2 bis 16 Zeichen wählen. Andere sehen '
            'nur ihn, nie deine E-Mail-Adresse.';
        _error = true;
      });
      return;
    }
    if (!email.contains('@')) {
      setState(() {
        _message = 'Bitte eine E-Mail-Adresse eingeben.';
        _error = true;
      });
      return;
    }
    if (!_signIn) {
      widget.onCallSign?.call(name);
    }
    _run(
      () async {
        if (_signIn) {
          try {
            await widget.accounts.sendSignInMail(email);
          } on AuthException catch (error) {
            // No account with this address yet: create one from the guest
            // account instead of turning the player away.
            if (error.errorCode != _noAccount) {
              rethrow;
            }
            await widget.accounts.secureWithEmail(email, name: name);
            _signIn = false;
          }
        } else {
          try {
            await widget.accounts.secureWithEmail(email, name: name);
          } on AuthException catch (error) {
            // The address has an account already. On the welcome page the
            // guest has nothing to lose yet, so sign into that account.
            if (!widget.embedded || !_taken.contains(error.errorCode)) {
              rethrow;
            }
            await widget.accounts.sendSignInMail(email);
            _signIn = true;
          }
        }
        _step = _Step.codeSent;
        if (!_signIn) {
          _watchConfirmation();
        }
      },
      'Mail ist unterwegs. Öffne den Link darin, das reicht. Steht in der '
      'Mail auch ein Code, kannst du ihn stattdessen hier eingeben.',
    );
  }

  /// Error codes of the auth service, see
  /// https://supabase.com/docs/guides/auth/debugging/error-codes
  static const _noAccount = 'otp_disabled';
  static const _taken = {'email_exists', 'user_already_exists'};

  /// The auth service answers in English: say it in German where we know
  /// the case.
  String _describe(AuthException error) => switch (error.errorCode) {
    _noAccount => 'Zu dieser E-Mail gibt es noch kein Konto.',
    'email_exists' || 'user_already_exists' =>
      'Zu dieser E-Mail gibt es schon ein Konto. Melde dich damit an.',
    'email_address_invalid' ||
    'validation_failed' => 'Diese E-Mail-Adresse ist ungültig.',
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      'Zu viele Versuche in kurzer Zeit. Bitte warte einen Moment.',
    'otp_expired' =>
      'Der Code ist falsch oder abgelaufen. Fordere eine neue Mail an.',
    'email_address_not_authorized' =>
      'An diese Adresse darf gerade keine Mail gehen.',
    _ => error.message,
  };

  void _verify() {
    _run(
      () =>
          widget.accounts.verifyCode(_email.text, _code.text, signIn: _signIn),
      _signIn
          ? 'Angemeldet.'
          : widget.embedded
          ? 'Konto angelegt.'
          : 'Konto gesichert.',
    ).then((_) {
      if (!_error && mounted) {
        setState(() => _step = _Step.idle);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<User?>(
      valueListenable: widget.accounts.user,
      builder: (context, user, _) {
        final guest = widget.accounts.isGuest;
        if (widget.embedded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [..._guest(context), ..._status()],
          );
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x44000000),
            border: Border.all(color: BwColors.oliveLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The status and its button share a line when they fit,
                // narrow screens put the button below instead of cutting
                // the status short.
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            guest ? Icons.person_outline : Icons.verified_user,
                            size: 18,
                            color: guest ? BwColors.textDim : BwColors.amber,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              guest
                                  ? 'KONTO: GAST'
                                  : 'KONTO: ${widget.accounts.email ?? 'VERKNÜPFT'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (guest)
                        TextButton(
                          onPressed: () => setState(() => _open = !_open),
                          child: Text(
                            _open ? 'SCHLIESSEN' : 'SICHERN / ANMELDEN',
                          ),
                        )
                      else
                        TextButton(
                          onPressed: _busy ? null : _signOut,
                          child: const Text('ABMELDEN'),
                        ),
                    ],
                  ),
                ),
                if (guest && _open) ..._guest(context),
                ..._status(),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _status() => [
    if (_message != null) ...[
      const SizedBox(height: 8),
      Text(
        _message!,
        style: TextStyle(
          fontSize: 12,
          color: _error ? BwColors.danger : BwColors.sand,
        ),
      ),
    ],
  ];

  List<Widget> _guest(BuildContext context) {
    final dim = widget.embedded
        ? const TextStyle(color: BwColors.text, fontSize: 14, height: 1.35)
        : const TextStyle(color: BwColors.textDim, fontSize: 12);
    final fresh = widget.embedded;
    return [
      if (fresh) ...[
        const SizedBox(height: 16),
        ChoiceRow<bool>(
          options: const [
            (true, 'ANMELDEN', null),
            (false, 'REGISTRIEREN', null),
          ],
          selected: _signIn,
          onSelected: (v) => _switchTo(signIn: v ?? _signIn),
        ),
      ],
      SizedBox(height: fresh ? 14 : 6),
      Text(switch ((_signIn, fresh)) {
        (true, true) =>
          'Melde dich mit deinem Konto an, um Rang, Wertung und Abzeichen '
              'auf dieses Gerät zu holen. Gibt es zu der Adresse noch kein '
              'Konto, legen wir eins an.',
        (true, false) =>
          'Melde dich mit deinem Konto an, um Rang, Wertung und Abzeichen '
              'auf dieses Gerät zu holen.',
        (false, true) =>
          'Lege ein Konto mit deiner E-Mail an. Rang, Wertung und Abzeichen '
              'bleiben dann auf jedem Gerät erhalten.',
        (false, false) =>
          'Als Gast spielst du ohne Wertung. Lege ein Konto an, um EP, Rang, '
              'Wertung und Abzeichen zu sammeln und Fahrzeuge freizuschalten.',
      }, style: dim),
      SizedBox(height: fresh ? 16 : 10),
      if (_step == _Step.idle) ...[
        if (!_signIn) ...[
          TextField(
            controller: _name,
            maxLength: 16,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              labelText: 'RUFNAME',
              helperText:
                  'Öffentlich sichtbar, zum Beispiel in der Bestenliste',
            ),
          ),
          const SizedBox(height: 4),
        ],
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'E-MAIL'),
          onSubmitted: (_) => _sendMail(),
        ),
        SizedBox(height: fresh ? 16 : 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: _busy ? null : _sendMail,
              child: Text(switch ((_signIn, fresh)) {
                (true, _) => 'ANMELDELINK SENDEN',
                (false, true) => 'KONTO ANLEGEN',
                (false, false) => 'KONTO SICHERN',
              }),
            ),
            for (final (provider, label) in widget.accounts.providers.value)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => _signIn
                            ? widget.accounts.signInWith(provider)
                            : widget.accounts.secureWith(provider),
                        'Weiter im Anmeldefenster.',
                      ),
                child: Text(label),
              ),
          ],
        ),
      ] else ...[
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          decoration: const InputDecoration(
            labelText: 'CODE AUS DER MAIL (FALLS VORHANDEN)',
          ),
          onSubmitted: (_) => _verify(),
        ),
        SizedBox(height: fresh ? 16 : 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: const Text('BESTÄTIGEN'),
            ),
            TextButton(
              onPressed: () => setState(() => _step = _Step.idle),
              child: const Text('ZURÜCK'),
            ),
          ],
        ),
      ],
      if (!fresh) ...[
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => _switchTo(signIn: !_signIn),
          child: Text(
            _signIn
                ? 'Noch kein Konto? Gastkonto sichern'
                : 'Schon ein Konto? Anmelden',
          ),
        ),
      ],
    ];
  }

  void _switchTo({required bool signIn}) => setState(() {
    _signIn = signIn;
    _step = _Step.idle;
    _message = null;
  });
}
