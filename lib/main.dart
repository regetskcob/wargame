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
import 'src/vision/vision_support.dart';
import 'src/watch/wear_crown.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The setup below waits for the server; until then the launch screen
  // stays, with a spinner, instead of a dark screen.
  await LoadingView.loadImages();
  runApp(const LoadingApp());
  // A Wear OS watch runs the Android app with the watch screens.
  await detectWear();
  // An Apple Vision Pro runs the iPad app, aiming where the player looks.
  await detectVision();
  await Env.loadShots();
  if (!kIsWeb &&
      !onTv &&
      !onWear &&
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
      // Store pictures of tablets are taken sideways (tool/store_shots.sh).
      if (!tablet || Env.shotScene == null) DeviceOrientation.portraitUp,
      if (tablet && Env.shotScene == null) DeviceOrientation.portraitDown,
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
  // still starts: solo rounds need none, the heartbeat tries again. A first
  // visit signs in as a guest on the way: the start page does not wait for
  // it, the game takes the pilot on when the session arrives (see
  // `AccountService.user`). Waiting cost half a second on 4G and up to ten
  // when the server was slow.
  final session = ServerStatus.ensureSession(auth)
      .then((ok) => ServerStatus.available.value = ok);
  if (auth.currentUser?.newEmail != null) {
    // The stored account still waits for its address. It may have been
    // confirmed in another tab since, which only shows after a refresh.
    unawaited(
      auth.refreshSession().then<void>(
        (_) {},
        onError: (Object _) {
          // Offline: the lobby still offers the code from the mail.
        },
      ),
    );
  }
  if (fromMail) {
    AccountService.mailLinkFailed = auth.currentUser?.isAnonymous ?? true;
    leaveMailLink();
  }
  // A phone browser that opened a pairing link steers the game elsewhere.
  // Its channel claims a share of the server, which takes a session.
  final pad = padCodeFrom(padCodeOfPage() ?? '');
  if (pad != null) {
    await session;
    runApp(ControllerApp(code: pad));
    return;
  }
  unawaited(session);
  TvInput.instance.start();
  runApp(const GameApp());
  // The sounds load once the start page stands, so they take no bandwidth
  // from what it needs.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(AudioService.init()),
  );
}
