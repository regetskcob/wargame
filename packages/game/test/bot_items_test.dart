import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/game/bot_items.dart';
import 'package:game/src/game/components/player_ship.dart';
import 'package:game/src/game/components/power_up.dart';
import 'package:game/src/game/components/tank_painter.dart';
import 'package:game/src/game/touch_input.dart';
import 'package:game/src/game/bot_level.dart';

PlayerShip _bot() => PlayerShip(
  playerId: 'cpu-1',
  playerName: 'CPU-1',
  shipColor: const Color(0xFF6B7F3A),
  tankType: TankType.puma,
  position: Vector2.zero(),
  controls: TouchInput(),
);

void main() {
  test('a bot only rushes for what it badly needs', () {
    final bot = _bot();
    expect(BotItems.urgent(bot, PowerUpType.ammo), isFalse);
    bot.ammo = 2;
    expect(BotItems.urgent(bot, PowerUpType.ammo), isTrue);
    bot.endlessAmmo = true;
    expect(BotItems.urgent(bot, PowerUpType.ammo), isFalse);
    expect(BotItems.useful(bot, PowerUpType.ammo), isFalse);

    expect(BotItems.useful(bot, PowerUpType.fuel), isFalse);
    bot
      ..usesFuel = true
      ..fuel = 0.2;
    expect(BotItems.urgent(bot, PowerUpType.fuel), isTrue);

    expect(BotItems.useful(bot, PowerUpType.repair), isFalse);
    bot.hp = bot.stats.maxHp * 0.3;
    expect(BotItems.urgent(bot, PowerUpType.repair), isTrue);
    expect(BotItems.useful(bot, PowerUpType.airstrike), isTrue);
  });

  test('bots on higher levels go further out of their way', () {
    expect(
      BotItems(BotLevel.hard).detour,
      greaterThan(BotItems(BotLevel.easy).detour),
    );
  });

  test('a bot keeps what it picks up', () {
    final bot = _bot()..items.add(PowerUpType.smoke);
    expect(bot.items.value.single.type, PowerUpType.smoke);
  });
}
