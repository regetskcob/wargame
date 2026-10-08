// Integration smoke test of the phone controller against a running local
// Supabase stack, like netcode_smoke_test.dart. Start it first with
// `supabase start` from the repository root. CI has no stack and leaves it
// out with `--exclude-tags supabase`.

@Tags(['supabase'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/net/pad_link.dart';
import 'package:wargame/src/net/payloads/pad_payload.dart';

import '../helpers/fakes.dart';

const _url = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54621',
);
const _key = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
);

/// Waits until [check] holds, polling, or fails after [seconds].
Future<void> _until(bool Function() check, {int seconds = 15}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!check()) {
    if (DateTime.now().isAfter(end)) {
      fail('timed out');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  late SupabaseClient phone;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The test binding answers every request with 400, this one needs the
    // real network.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: _url, publishableKey: _key);
    phone = SupabaseClient(
      _url,
      _key,
      authOptions: AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage()),
    );
  });

  tearDownAll(() async {
    await phone.dispose();
  });

  test('a phone pairs, steers the tank and hears how it is doing', () async {
    final screen = PadScreen.instance;
    final game = offlineGame()..myName = 'Wolf';
    screen.game = game;
    await screen.open();
    final code = screen.code.value!;

    final remote = PadRemote(code, client: phone);
    await remote.start('Handy');
    await _until(() => screen.paired.value == 'Handy');
    await _until(() => remote.screenOnline.value);

    // The screen tells the phone about the tank.
    await _until(() => remote.status.value != null);
    expect(remote.status.value!.name, 'Wolf');
    expect(remote.status.value!.phase, GamePhase.lobby);

    // The sticks come through as touch controls on the screen.
    remote.input
      ..drive = (0, -1)
      ..aim = 1.0
      ..aimHeld = true
      ..aimFire = true;
    await _until(() => game.touch.aimFire);
    expect(game.touch.drive, (0.0, -1.0));
    expect(game.touch.aim, 1.0);

    // Letting go lets go on the screen too.
    remote.input
      ..drive = null
      ..aimHeld = false
      ..aimFire = false;
    await _until(() => !game.touch.aimFire && game.touch.drive == null);
    expect(game.touch.aim, 1.0, reason: 'the turret keeps its aim');

    // A phone that drops out stops the tank.
    remote.input.drive = (1, 0);
    await _until(() => game.touch.drive != null);
    await remote.stop();
    await _until(() => screen.paired.value == null);
    await _until(() => game.touch.drive == null, seconds: 3);

    // What the screen sends reads back on the phone.
    final status = PadScreen.statusOf(game);
    expect(status.phase, GamePhase.lobby);
    expect(PadStatus.tryParse(status.toJson())?.name, 'Wolf');

    await screen.close();
    expect(screen.code.value, isNull);
  });
}
