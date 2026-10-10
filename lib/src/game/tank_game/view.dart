part of '../tank_game.dart';

/// What the player sees: screen shake, hit numbers, notices, the weather layer and the camera.
extension TankGameView on TankGame {
  /// Distance from the middle of the screen, to fade out far away sounds.
  double _distanceToView(Vector2 point) =>
      point.distanceTo(camera.viewfinder.position);

  /// Rattles the screen. Strengths add up and fade out within a fraction of
  /// a second.
  void shake(double strength) {
    _shake = min(14.0, _shake + strength);
    Haptics.shake(strength);
  }

  /// Shakes by [strength], weaker the further [at] is from the middle of the
  /// screen, so far away explosions barely register.
  void shakeAt(Vector2 at, double strength) {
    final distance = _distanceToView(at);
    shake(strength * (1 - (distance / 700).clamp(0.0, 1.0)));
  }

  /// Leaves a scorched hole in the ground until the round ends.
  void addCrater(Vector2 at, double radius) => _tracks?.addCrater(at, radius);

  /// A tank at [at] took [amount] damage from a shell. [mine] marks hits the
  /// local player dealt or took.
  void showHit(Vector2 at, double amount, {required bool mine, Color? color}) {
    world.add(
      DamageNumber(
        position: at + Vector2(0, -GameConfig.tankRadius),
        amount: amount,
        color: color ?? const Color(0xFFFFE08A),
        mine: mine,
      ),
    );
  }

  /// The local tank was hit.
  void onLocalDamage(Vector2 at, double amount) {
    // On the overview of a duel the whole screen is both players'.
    if (!overview.value) {
      _damageFlash = min(1.0, _damageFlash + 0.35 + amount / 60);
    }
    shake(3 + amount / 4);
    showHit(at, amount, mine: true, color: const Color(0xFFFF6B5A));
  }

  /// Draws one weather layer. render() calls this per layer instead of
  /// looping over [?_passingWeather, ?_weather]: that list crashed the
  /// Android release build with SIGSEGV on the first frame of a round,
  /// while debug builds ran fine.
  void _renderWeather(
    Canvas canvas,
    WeatherLayer layer,
    bool playing,
    PlayerTank? tank,
  ) {
    layer.render(
      canvas,
      Size(canvasSize.x, canvasSize.y),
      camera: camera.viewfinder.position.toOffset(),
      scale: viewScale,
      heading: playing ? tank!.angle : null,
      focus: playing
          ? ((tank!.position - camera.viewfinder.position) * viewScale +
                    canvasSize / 2)
                .toOffset()
          : null,
      // Spectators and the fallen see the whole field, and so does the
      // overview of a duel, which shows both players.
      veil: playing && !overview.value,
    );
  }

  /// Flashes [text] in the middle of the HUD for two seconds.
  void showNotice(String text) {
    _noticeTimer?.cancel();
    notice.value = text;
    _noticeTimer = async.Timer(
      const Duration(seconds: 2),
      () => notice.value = null,
    );
  }

  /// Pixels per world unit. The shorter side of the window always shows the
  /// same stretch of the world, the longer side simply shows more, so the map
  /// fills the whole window without black bars. A defense round looks from
  /// further up, to keep the road and the guns in view.
  ///
  /// The defense field is wider than tall. On an upright phone the short
  /// side alone would show the whole field small with empty space above and
  /// below, so there the field's height fills the screen instead and the
  /// camera follows the tank sideways.
  double get viewScale {
    final short = min(canvasSize.x, canvasSize.y);
    // An upright phone shows the tank only about 25 points wide, too small
    // to read at arm's length: it looks a bit closer, a tablet does not.
    final uprightPhone =
        canvasSize.y > canvasSize.x && short < GameConfig.phoneShortSide;
    final zoom = onWatch
        ? GameConfig.watchZoom
        : uprightPhone
        ? GameConfig.uprightPhoneZoom
        : 1.0;
    if (defenseMap == null) {
      return zoom * short / GameConfig.viewShortSide;
    }
    if (overview.value) {
      // The whole field fits, with its border.
      const margin = TankGame._defenseMargin;
      return min(
        canvasSize.x / (DefenseMap.halfWidth * 2 + margin * 2),
        canvasSize.y / (DefenseMap.halfHeight * 2 + margin * 2),
      );
    }
    // The defense field already fills an upright phone from top to bottom.
    return (onWatch ? GameConfig.watchZoom : 1.0) *
        max(
          short / GameConfig.defenseViewShortSide,
          canvasSize.y /
              (DefenseMap.halfHeight * 2 + TankGame._defenseMargin * 2),
        );
  }

  /// Zooms for the current round. In a defense round the camera also stays
  /// over the field, instead of showing the dark beyond the border when the
  /// player stands at the base near the edge.
  void _fitCamera() {
    final scale = viewScale;
    camera.viewfinder.zoom = scale;
    if (defenseMap == null || scale <= 0) {
      camera.setBounds(null);
      return;
    }
    if (overview.value) {
      // Held still over the middle of the field.
      camera
        ..stop()
        ..setBounds(null);
      camera.viewfinder.position = Vector2.zero();
      return;
    }
    const margin = TankGame._defenseMargin;
    // On a desktop the mini map fills the lower right corner, right where
    // the base stands at the end of the road. The camera may go that far
    // past the edge, so the base and the tank by it come out from under it.
    final hud = touchMode.value ? 0.0 : TankGame._hudReserve / scale;
    final dx = max(
      1.0,
      DefenseMap.halfWidth + margin + hud - canvasSize.x / 2 / scale,
    );
    final dy = max(
      1.0,
      DefenseMap.halfHeight + margin - canvasSize.y / 2 / scale,
    );
    camera.setBounds(Rectangle.fromLTRB(-dx, -dy, dx, dy));
  }

  /// World position the mouse points at.
  Vector2? pointerWorld() {
    final screen = pointer;
    final canvas = canvasSize;
    if (screen == null || canvas.x <= 0 || canvas.y <= 0) {
      return null;
    }
    return camera.viewfinder.position + (screen - canvas / 2) / viewScale;
  }
}
