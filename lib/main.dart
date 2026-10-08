import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app/game_app.dart';
import 'src/audio/audio_service.dart';
import 'src/db/account_service.dart';
import 'src/app/env.dart';
import 'src/l10n/l10n.dart';
import 'src/net/pad_link.dart';
import 'src/net/room.dart';
import 'src/ui/widgets/tablet_scale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    // Phones play upright or sideways, tablets any way up, without system
    // bars. The camera shows the same stretch of the world along the shorter
    // side either way.
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final tablet =
        view.physicalSize.shortestSide / view.devicePixelRatio >=
        tabletShortSide;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      if (tablet) DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  await openLocalStore();
  await L10n.init();
  // A link from a sign-in mail carries a one time code. Supabase redeems it
  // during initialize and drops it from the address, unless this browser
  // lacks the key the code was requested with.
  final fromMail = Uri.base.queryParameters.containsKey('code');
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseKey,
  );
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession == null) {
    await auth.signInAnonymously();
  }
  if (auth.currentUser?.newEmail != null) {
    // The stored account still waits for its address. It may have been
    // confirmed in another tab since, which only shows after a refresh.
    try {
      await auth.refreshSession();
    } on Object {
      // Offline: the lobby still offers the code from the mail.
    }
  }
  if (fromMail) {
    AccountService.mailLinkFailed = auth.currentUser?.isAnonymous ?? true;
    leaveMailLink();
  }
  // A phone browser that opened a pairing link steers the game elsewhere.
  final pad = padCodeFrom(padCodeOfPage() ?? '');
  if (pad != null) {
    runApp(ControllerApp(code: pad));
    return;
  }
  unawaited(AudioService.init());
  runApp(const GameApp());
}
