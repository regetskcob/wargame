import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../db/account_service.dart';
import '../../theme.dart';

/// Guest or lasting account: secure the guest account by e-mail or with a
/// login, sign into an account from another device, or sign out.
class AccountPanel extends StatefulWidget {
  const AccountPanel({
    required this.accounts,
    this.embedded = false,
    super.key,
  });

  final AccountService accounts;

  /// On the welcome page: always open, without the status line, and signing
  /// in comes first. Securing the fresh guest account there means creating
  /// a new one.
  final bool embedded;

  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

enum _Step { idle, codeSent }

class _AccountPanelState extends State<AccountPanel> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  var _open = false;
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

  @override
  void dispose() {
    widget.accounts.providers.removeListener(_refresh);
    _email.dispose();
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
      _message = error.message;
      _error = true;
    } on Object catch (error) {
      _message = '$error';
      _error = true;
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  void _sendMail() {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _message = 'Bitte eine E-Mail-Adresse eingeben.';
        _error = true;
      });
      return;
    }
    _run(
      () async {
        if (_signIn) {
          await widget.accounts.sendSignInMail(email);
        } else {
          await widget.accounts.secureWithEmail(email);
        }
        _step = _Step.codeSent;
      },
      'Mail ist unterwegs. Öffne den Link darin, oder gib den Code ein, '
      'falls die Mail einen enthält.',
    );
  }

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
                Row(
                  children: [
                    Icon(
                      guest ? Icons.person_outline : Icons.verified_user,
                      size: 18,
                      color: guest ? BwColors.textDim : BwColors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
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
                    if (guest)
                      TextButton(
                        onPressed: () => setState(() => _open = !_open),
                        child: Text(
                          _open ? 'SCHLIESSEN' : 'SICHERN / ANMELDEN',
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                widget.accounts.signOut,
                                'Abgemeldet, du spielst jetzt als Gast.',
                              ),
                        child: const Text('ABMELDEN'),
                      ),
                  ],
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
    final dim = const TextStyle(color: BwColors.textDim, fontSize: 12);
    final fresh = widget.embedded;
    return [
      const SizedBox(height: 6),
      Text(switch ((_signIn, fresh)) {
        (true, _) =>
          'Melde dich mit deinem Konto an, um Rang, Wertung und Abzeichen '
              'auf dieses Gerät zu holen.',
        (false, true) =>
          'Lege ein Konto mit deiner E-Mail an. Rang, Wertung und Abzeichen '
              'bleiben dann auf jedem Gerät erhalten.',
        (false, false) =>
          'Als Gast hängt dein Fortschritt an diesem Browser. Sichere dein '
              'Konto, damit Rang, Wertung und Abzeichen bleiben.',
      }, style: dim),
      const SizedBox(height: 10),
      if (_step == _Step.idle) ...[
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'E-MAIL'),
          onSubmitted: (_) => _sendMail(),
        ),
        const SizedBox(height: 8),
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
          decoration: const InputDecoration(labelText: 'CODE AUS DER MAIL'),
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 8),
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
      const SizedBox(height: 4),
      TextButton(
        onPressed: () => setState(() {
          _signIn = !_signIn;
          _step = _Step.idle;
          _message = null;
        }),
        child: Text(switch ((_signIn, fresh)) {
          (true, true) => 'Noch kein Konto? Registrieren',
          (true, false) => 'Noch kein Konto? Gastkonto sichern',
          (false, _) => 'Schon ein Konto? Anmelden',
        }),
      ),
    ];
  }
}
