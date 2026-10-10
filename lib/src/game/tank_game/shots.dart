part of '../tank_game.dart';

/// The screenshot mode of tool/store_shots.sh: one debug build with
/// `SHOTS=true`, launched once per picture with the scene in its
/// environment (see [Env.shotScene]). The game walks into the scene by
/// itself, waits for it to settle and writes its own frame, so no picture
/// needs a hand on the simulator, and no status bar or simulator chrome ends
/// up in it.
extension TankGameShots on TankGame {
  /// How long each scene runs before the frame is taken: menus only need
  /// their fonts, rounds a few seconds of fighting.
  static const _settle = {
    'menu': 4,
    'lobby': 4,
    'room': 8,
    'battle': 14,
    'defense': 12,
    'pad': 5,
  };

  Future<void> _stageShot(String scene) async {
    welcomed.value = true;
    rememberTutorialSeen();
    tutorialDone.value = true;
    await _speakShotLanguage();
    // The olive Hermelin in every picture, not a random starter.
    setPilot(
      name: myName,
      colorIndex: GameConfig.styleOf(TankType.hermelin.index, 0),
    );
    switch (scene) {
      case 'menu':
        choosingMode.value = true;
      case 'lobby':
        chooseMode(GameMode.solo);
      case 'room':
        // The versus room: a defense room paints every vehicle in its
        // team's red. Kept out of the public room list.
        publicRoom.value = false;
        chooseMode(GameMode.multi);
      case 'battle':
        quickStart();
      case 'defense':
        chooseMode(GameMode.defense);
        startRound();
      case 'pad':
      // The app shell opens the phone controller over the game, see
      // GameApp.initState.
    }
    await Future<void>.delayed(Duration(seconds: _settle[scene] ?? 6));
    // The account may have loaded its own language meanwhile.
    await _speakShotLanguage();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final out = Env.shotOut;
    if (out != null) {
      await _saveFrame(out);
      exit(0);
    }
  }

  Future<void> _speakShotLanguage() async {
    final lang = switch (Env.shotLang) {
      'de' => AppLang.de,
      'en' => AppLang.en,
      _ => null,
    };
    if (lang != null && lang != L10n.current) {
      await L10n.set(lang);
    }
  }

  /// Writes what the screen shows, in physical pixels, as a PNG to [path].
  Future<void> _saveFrame(String path) async {
    final view = RendererBinding.instance.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final size = view.flutterView.physicalSize;
    final image = await layer.toImage(Offset.zero & size);
    final png = await image.toByteData(format: ImageByteFormat.png);
    // Renamed when complete, so the script never picks up half a file.
    final part = File('$path.part');
    await part.writeAsBytes(png!.buffer.asUint8List(), flush: true);
    await part.rename(path);
  }
}
