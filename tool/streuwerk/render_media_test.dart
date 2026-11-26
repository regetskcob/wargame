// Draws the product media for Streuwerk from the game's own painters:
// vehicles, crates and gems, cut-outs of the terrain and the base stages,
// as PNGs with a transparent background, plus frame sequences that
// tool/streuwerk/render_media.sh turns into short clips.
//
// Not part of the test suite (tag `media`, skipped by default). Start it
// through tool/streuwerk/render_media.sh, which also writes the clips.
@Tags(['media'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/cover_field.dart';
import 'package:wargame/src/game/components/ground.dart';
import 'package:wargame/src/game/components/mud_field.dart';
import 'package:wargame/src/game/components/power_up.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/defense/defense_field.dart';
import 'package:wargame/src/game/defense/defense_map.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/map_theme.dart';

const _out = 'streuwerk/media';

/// German file names, the same names the template's media ids use.
const _tankNames = {
  TankType.spitzmaus: 'spitzmaus',
  TankType.fuchs: 'fuchs',
  TankType.hermelin: 'hermelin',
  TankType.habicht: 'habicht',
  TankType.keiler: 'keiler',
  TankType.hirsch: 'hirsch',
  TankType.dachs: 'dachs',
  TankType.igel: 'igel',
  TankType.wolf: 'wolf',
};

/// In the order of [MapTheme.all].
const _themeNames = ['wald', 'wueste', 'winter', 'stadt', 'bergwald', 'inseln'];

Future<void> _png(
  WidgetTester tester,
  String path,
  int width,
  int height,
  void Function(ui.Canvas canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  await tester.runAsync(() async {
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path)..parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
  picture.dispose();
}

Future<void> _loadSymbols() async {
  // Crate badges draw a Horizont symbol; tests only know Ahem otherwise.
  final loader = FontLoader('packages/horizont/MaterialSymbolsSharp');
  for (final weight in ['300', '400']) {
    try {
      loader.addFont(
        rootBundle.load(
          'packages/horizont/fonts/MaterialSymbolsSharp-$weight.ttf',
        ),
      );
    } catch (_) {
      // Only the weights the package ships.
    }
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final olive = GameConfig.tankColors.first;

  testWidgets('vehicles', (tester) async {
    // The 48 grid at 12x, with room for the barrels above and beside.
    const scale = 12.0;
    const side = 864;
    for (final MapEntry(key: type, value: name) in _tankNames.entries) {
      await _png(tester, '$_out/fahrzeuge/$name.png', side, side, (canvas) {
        canvas.translate(side / 2 - 24 * scale, side / 2 - 24 * scale);
        canvas.scale(scale);
        paintTank(canvas, 48, type, olive);
      });
      // Turned a quarter, as they cross the screen in a reel.
      await _png(tester, '$_out/fahrzeuge/$name-quer.png', side, side, (
        canvas,
      ) {
        // Smaller than the top view: the barrel reaches far to the right.
        canvas.translate(side / 2 - 90, side / 2);
        canvas.rotate(pi / 2);
        canvas.translate(-24 * 9.0, -24 * 9.0);
        canvas.scale(9);
        paintTank(canvas, 48, type, olive, turretAngle: -0.35);
      });
      // Frames of a turret sweep and a shot, 30 a second for 3 seconds.
      for (var f = 0; f < 90; f++) {
        final t = f / 30;
        final shot = ((t - 1.6) / 0.5).clamp(0.0, 1.0);
        final recoil = t > 1.6 ? max(0.0, 1 - shot * 1.6) : 0.0;
        final flash = t > 1.6 && t < 1.75 ? 1.0 : 0.0;
        final angle = sin(t / 3 * 2 * pi) * 0.7;
        await _png(
          tester,
          '/tmp/streuwerk-frames/$name/${f.toString().padLeft(3, '0')}.png',
          720,
          720,
          (canvas) {
            canvas.translate(360 - 24 * 8.0, 380 - 24 * 8.0);
            canvas.scale(8);
            paintTank(
              canvas,
              48,
              type,
              olive,
              turretAngle: angle,
              recoil: recoil,
              flash: flash,
            );
          },
        );
      }
    }
  });

  testWidgets('crates and gems', (tester) async {
    await _loadSymbols();
    const scale = 10.0;
    const side = 600;
    for (final type in PowerUpType.values) {
      final crate = PowerUp(
        slot: PowerUpSlot(
          id: 0,
          appearsAt: 0,
          position: Vector2.zero(),
          type: type,
        ),
      );
      await _png(tester, '$_out/kisten/${type.name}.png', side, side, (canvas) {
        // The gem's badge floats above the crate, so sit it lower.
        canvas.translate(side / 2 - 18 * scale, side / 2 - 12 * scale);
        canvas.scale(scale);
        crate.render(canvas);
      });
    }
  });

  testWidgets('terrain', (tester) async {
    // Each theme from a seed that draws it, a cut-out near the start ring.
    for (final theme in MapTheme.all) {
      var seed = 1;
      while (MapTheme.forSeed(seed) != theme) {
        seed++;
      }
      final cover = CoverField(seed: seed)..onLoad();
      final ground = Ground(theme);
      final name = _themeNames[MapTheme.all.indexOf(theme)];
      for (final (suffix, width, height, zoom) in [
        ('4x5', 1080, 1350, 1.6),
        ('9x16', 1080, 1920, 1.6),
      ]) {
        await _png(tester, '$_out/gelaende/$name-$suffix.png', width, height, (
          canvas,
        ) {
          canvas.translate(width / 2, height / 2);
          canvas.scale(zoom);
          // Off the centre, where the woods and buildings stand.
          canvas.translate(-260, -180);
          ground.render(canvas);
          for (final obstacle in cover.obstacles) {
            obstacle.renderTree(canvas);
          }
          for (final tree in cover.trees) {
            tree.renderTree(canvas);
          }
        });
      }
    }
  });

  testWidgets('base stages', (tester) async {
    // Watchtower, barracks, fortress; the citadel looks like the fortress
    // from above (it only has more hit points), so it gets no picture.
    const side = 1080;
    const zoom = 2.2;
    for (var level = 1; level <= 3; level++) {
      final hq = Headquarters(position: Vector2.zero())..level = level;
      hq.hp = GameConfig.baseMaxHp(level);
      await _png(tester, '$_out/stuetzpunkt/stufe-$level.png', side, side, (
        canvas,
      ) {
        canvas.translate(side / 2, side / 2);
        canvas.scale(zoom);
        canvas.translate(-DefenseMap.baseRadius, -DefenseMap.baseRadius);
        hq.render(canvas);
      });
    }
  });

  testWidgets('round map views', (tester) async {
    // Every map from above as a small round picture, so the islands' water
    // and the defense map's river, road and base show. The world is built
    // in a headless FlameGame, the same components as in a round.
    const side = 1080;
    Future<void> round(
      String name,
      double reach,
      Offset centre,
      List<Component> parts,
    ) async {
      final game = FlameGame();
      game.onGameResize(Vector2.all(side.toDouble()));
      await tester.runAsync(() async {
        // What flame_test's initializeGame does, without a widget.
        // ignore: invalid_use_of_internal_member
        await game.load();
        // ignore: invalid_use_of_internal_member
        game.mount();
        game.update(0);
        game.world.addAll(parts);
        game.update(0);
        await game.ready();
      });
      await _png(tester, '$_out/karten/$name.png', side, side, (canvas) {
        final clip = ui.Path()
          ..addOval(
            Rect.fromCircle(
              center: const Offset(side / 2, side / 2),
              radius: side / 2,
            ),
          );
        canvas.clipPath(clip);
        canvas.translate(side / 2, side / 2);
        canvas.scale(side / 2 / reach);
        canvas.translate(-centre.dx, -centre.dy);
        // The world only draws through a camera, so walk its children.
        for (final part in game.world.children) {
          part.renderTree(canvas);
        }
      });
    }

    for (final theme in MapTheme.all) {
      var seed = 1;
      while (MapTheme.forSeed(seed) != theme) {
        seed++;
      }
      await round(
        _themeNames[MapTheme.all.indexOf(theme)],
        GameConfig.worldRadius,
        Offset.zero,
        [
          Ground(theme),
          MudField(seed: seed, theme: theme),
          CoverField(seed: seed),
        ],
      );
    }
    // A green defense map, zoomed out so base, road and river all fit.
    var seed = 1;
    while (MapTheme.forSeed(seed) != MapTheme.forest) {
      seed++;
    }
    final map = DefenseMap.forSeed(seed);
    final field = DefenseField(seed: seed, map: map);
    final bounds = DefenseMap.bounds;
    await round(
      'verteidigung',
      bounds.longestSide / 2 * 0.8,
      // Nudged towards the base, which stands at the right end.
      bounds.center + Offset(bounds.width * 0.1, 0),
      [Ground(field.theme, plain: true), field],
    );
  });
}
