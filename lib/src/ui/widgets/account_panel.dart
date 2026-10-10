import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../db/account_service.dart';
import '../../net/room.dart';
import '../theme.dart';
import 'choice_row.dart';
import 'panel.dart';
import '../../l10n/l10n.dart';

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
    this.callSignAbove,
    super.key,
  });

  final AccountService accounts;

  /// Takes the call sign given when registering. Others only ever see this
  /// name, never the e-mail address.
  final ValueChanged<String>? onCallSign;

  /// The current call sign, to start the field with.
  final String? callSign;

  /// Called after signing out, right before the game starts over on the
  /// start page. A dialog closes itself here.
  final VoidCallback? onSignedOut;

  /// On the welcome page: always open, without the status line, and signing
  /// in comes first. Securing the fresh guest account there means creating
  /// a new one.
  final bool embedded;

  /// Set where a call sign field already sits above the panel, as in the
  /// account sheet: registering then takes that name instead of asking for
  /// it a second time, and says so. Called right before the mail goes out,
  /// so it can take a name that is typed but not yet saved.
  final ValueGetter<String>? callSignAbove;

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
            _message = tr(
              'E-Mail bestätigt, dein Konto steht.',
              'E-mail confirmed, your account is set up.',
            );
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

  /// Signs out and starts over on the start page, with nothing of the
  /// account left in the game: no name, no progress, no open dialog.
  Future<void> _signOut() async {
    await _run(widget.accounts.signOut, tr('Abgemeldet.', 'Signed out.'));
    if (_error) {
      return;
    }
    widget.onSignedOut?.call();
    openFreshRoom();
  }

  void _sendMail() {
    final email = _email.text.trim();
    final name = (widget.callSignAbove?.call() ?? _name.text).trim();
    if (!_signIn && (name.length < 2 || name.length > 16)) {
      setState(() {
        _message = tr(
          'Bitte einen Rufnamen mit 2 bis 16 Zeichen wählen. Andere sehen '
              'nur ihn, nie deine E-Mail-Adresse.',
          'Please choose a call sign of 2 to 16 characters. Others only '
              'ever see it, never your e-mail address.',
        );
        _error = true;
      });
      return;
    }
    if (!email.contains('@')) {
      setState(() {
        _message = tr(
          'Bitte eine E-Mail-Adresse eingeben.',
          'Please enter an e-mail address.',
        );
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
      tr(
        'Mail ist unterwegs. Öffne den Link darin, das reicht. Steht in der '
            'Mail auch ein Code, kannst du ihn stattdessen hier eingeben.',
        'The mail is on its way. Open the link in it, that is enough. If '
            'the mail also contains a code, you can enter it here instead.',
      ),
    );
  }

  /// Error codes of the auth service, see
  /// https://supabase.com/docs/guides/auth/debugging/error-codes
  static const _noAccount = 'otp_disabled';
  static const _taken = {'email_exists', 'user_already_exists'};

  /// The auth service answers in English: say it in the player's language
  /// where we know the case.
  String _describe(AuthException error) => switch (error.errorCode) {
    _noAccount => tr(
      'Zu dieser E-Mail gibt es noch kein Konto.',
      'There is no account for this e-mail yet.',
    ),
    'email_exists' || 'user_already_exists' => tr(
      'Zu dieser E-Mail gibt es schon ein Konto. Melde dich damit an.',
      'There is already an account for this e-mail. Sign in with it.',
    ),
    'email_address_invalid' || 'validation_failed' => tr(
      'Diese E-Mail-Adresse ist ungültig.',
      'This e-mail address is invalid.',
    ),
    'over_email_send_rate_limit' || 'over_request_rate_limit' => tr(
      'Zu viele Versuche in kurzer Zeit. Bitte warte einen Moment.',
      'Too many attempts in a short time. Please wait a moment.',
    ),
    'otp_expired' => tr(
      'Der Code ist falsch oder abgelaufen. Fordere eine neue Mail an.',
      'The code is wrong or has expired. Request a new mail.',
    ),
    'email_address_not_authorized' => tr(
      'An diese Adresse darf gerade keine Mail gehen.',
      'No mail may be sent to this address right now.',
    ),
    _ => error.message,
  };

  void _verify() {
    _run(
      () =>
          widget.accounts.verifyCode(_email.text, _code.text, signIn: _signIn),
      _signIn
          ? tr('Angemeldet.', 'Signed in.')
          : widget.embedded
          ? tr('Konto angelegt.', 'Account created.')
          : tr('Konto gesichert.', 'Account secured.'),
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
          decoration: ShapeDecoration(
            color: const Color(0x44000000),
            shape: GameShapes.card(),
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
                            color: guest
                                ? GameColors.textDim
                                : GameColors.amber,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              guest
                                  ? tr('KONTO: GAST', 'ACCOUNT: GUEST')
                                  : '${tr('KONTO', 'ACCOUNT')}: ${widget.accounts.email ?? tr('VERKNÜPFT', 'LINKED')}',
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
                            _open
                                ? tr('SCHLIESSEN', 'CLOSE')
                                : tr(
                                    'REGISTRIEREN / ANMELDEN',
                                    'REGISTER / SIGN IN',
                                  ),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: _busy ? null : _signOut,
                          child: Text(tr('ABMELDEN', 'SIGN OUT')),
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
          color: _error ? GameColors.danger : GameColors.sand,
        ),
      ),
    ],
  ];

  List<Widget> _guest(BuildContext context) {
    final dim = widget.embedded
        ? const TextStyle(color: GameColors.text, fontSize: 14, height: 1.35)
        : const TextStyle(color: GameColors.textDim, fontSize: 12);
    final fresh = widget.embedded;
    return [
      if (fresh) ...[
        const SizedBox(height: 16),
        ChoiceRow<bool>(
          options: [
            (true, tr('ANMELDEN', 'SIGN IN'), null),
            (false, tr('REGISTRIEREN', 'REGISTER'), null),
          ],
          selected: _signIn,
          onSelected: (v) => _switchTo(signIn: v ?? _signIn),
        ),
      ],
      SizedBox(height: fresh ? 14 : 6),
      Text(switch ((_signIn, fresh)) {
        (true, true) => tr(
          'Melde dich mit deinem Konto an, um Rang, Wertung und Abzeichen '
              'auf dieses Gerät zu holen. Gibt es zu der Adresse noch kein '
              'Konto, legen wir eins an.',
          'Sign in with your account to bring your rank, rating and badges '
              'to this device. If there is no account for the address yet, '
              'we create one.',
        ),
        (true, false) => tr(
          'Melde dich mit deinem Konto an, um Rang, Wertung und Abzeichen '
              'auf dieses Gerät zu holen.',
          'Sign in with your account to bring your rank, rating and badges '
              'to this device.',
        ),
        (false, true) => tr(
          'Lege ein Konto mit deiner E-Mail an. Rang, Wertung und Abzeichen '
              'bleiben dann auf jedem Gerät erhalten.',
          'Create an account with your e-mail. Your rank, rating and badges '
              'are then kept on every device.',
        ),
        (false, false) => tr(
          'Als Gast spielst du ohne Wertung. Lege ein Konto an, um EP, Rang, '
              'Wertung und Abzeichen zu sammeln und Fahrzeuge freizuschalten.',
          'As a guest you play without ranking. Create an account to collect '
              'XP, rank, rating and badges and to unlock vehicles.',
        ),
      }, style: dim),
      SizedBox(height: fresh ? 16 : 10),
      if (_step == _Step.idle) ...[
        if (!_signIn && widget.callSignAbove != null) ...[
          Text(
            tr(
              'Du registrierst dich als ${widget.callSign}. Den Rufnamen '
                  'änderst du oben.',
              'You register as ${widget.callSign}. Change the call sign '
                  'above.',
            ),
            style: dim,
          ),
          const SizedBox(height: 8),
        ] else if (!_signIn) ...[
          TextField(
            controller: _name,
            maxLength: 16,
            autofillHints: const [AutofillHints.username],
            decoration: InputDecoration(
              labelText: tr('RUFNAME', 'CALL SIGN'),
              helperText: tr(
                'Öffentlich sichtbar, zum Beispiel in der Bestenliste',
                'Publicly visible, for example on the leaderboard',
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(labelText: tr('E-MAIL', 'E-MAIL')),
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
                (true, _) => tr('ANMELDELINK SENDEN', 'SEND SIGN-IN LINK'),
                (false, true) => tr('KONTO ANLEGEN', 'CREATE ACCOUNT'),
                (false, false) => tr('REGISTRIEREN', 'REGISTER'),
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
                        tr(
                          'Weiter im Anmeldefenster.',
                          'Continue in the sign-in window.',
                        ),
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
          decoration: InputDecoration(
            labelText: tr(
              'CODE AUS DER MAIL (FALLS VORHANDEN)',
              'CODE FROM THE MAIL (IF ANY)',
            ),
          ),
          onSubmitted: (_) => _verify(),
        ),
        SizedBox(height: fresh ? 16 : 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: Text(tr('BESTÄTIGEN', 'CONFIRM')),
            ),
            TextButton(
              onPressed: () => setState(() => _step = _Step.idle),
              child: Text(tr('ZURÜCK', 'BACK')),
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
                ? tr(
                    'Noch kein Konto? Registrieren',
                    'No account yet? Register',
                  )
                : tr(
                    'Schon ein Konto? Anmelden',
                    'Already have an account? Sign in',
                  ),
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
