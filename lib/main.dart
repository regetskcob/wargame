import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app/game_app.dart';
import 'src/audio/audio_service.dart';
import 'src/db/account_service.dart';
import 'src/db/server_status.dart';
import 'src/haptics.dart';
import 'src/app/env.dart';
import 'src/l10n/l10n.dart';
import 'src/net/pad_link.dart';
import 'src/net/room.dart';
import 'src/tv/tv_input.dart';
import 'src/ui/loading_view.dart';
import 'src/ui/widgets/tablet_scale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The setup below waits for the server; until then the launch screen
  // stays, with a spinner, instead of a dark screen.
  await LoadingView.loadImages();
  runApp(const LoadingApp());
  if (!kIsWeb &&
      !onTv &&
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
  await Haptics.init();
  // A link from a sign-in mail carries a one time code. Supabase redeems it
  // during initialize and drops it from the address, unless this browser
  // lacks the key the code was requested with.
  final fromMail = Uri.base.queryParameters.containsKey('code');
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseKey,
    // Nothing opens links on the Apple TV, and app_links has no tvOS side.
    authOptions: FlutterAuthClientOptions(detectSessionInUri: !onTv),
  );
  final auth = Supabase.instance.client.auth;
  // Without a server (offline, or the project over its quota) the game
  // still starts: solo rounds need none, the heartbeat tries again.
  ServerStatus.available.value = await ServerStatus.ensureSession(auth);
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
  TvInput.instance.start();
  runApp(const GameApp());
}
