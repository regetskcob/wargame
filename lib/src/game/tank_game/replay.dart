part of '../tank_game.dart';

/// Replays: playing the recorded messages of the last round back into a round that starts now.
extension TankGameReplay on TankGame {
  /// Watches the round that just ended, or the last one recorded, again.
  void watchReplay() {
    final current = phase.value;
    if (current != GamePhase.lobby && current != GamePhase.roundOver) {
      return;
    }
    final recorded = _recorder.finish();
    if (recorded != null) {
      lastReplay.value = recorded;
    }
    final replay = lastReplay.value;
    if (replay == null) {
      return;
    }
    // A short moment to look around before the first shots.
    final startedAt = DateTime.now().millisecondsSinceEpoch + 1500;
    _replayPlayer = ReplayPlayer(replay, startedAt: startedAt);
    net.muted = true;
    replaying.value = true;
    final original = replay.round;
    _applyRoundStart(
      RoundStartPayload(
        seed: original.seed,
        startedAt: startedAt,
        participants: original.participants,
        teams: original.teams,
        bots: original.bots,
        botHost: original.botHost,
        botLevel: original.botLevel,
      ),
      replay: true,
    );
  }

  void stopReplay() {
    if (_replayPlayer == null) {
      return;
    }
    _replayPlayer = null;
    replaying.value = false;
    net.muted = false;
    _clearWorld();
    round = null;
    GameConfig.swapSides = false;
    _setPhase(GamePhase.lobby);
    unawaited(pushPresence());
  }

  /// Feeds the recorded messages that are due into the game, as if they had
  /// just come over the network.
  void _playReplay() {
    final player = _replayPlayer;
    if (player == null) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final event in player.due(now).toList()) {
      final json = event.payload;
      switch (event.event) {
        case NetEvent.state:
          _onTankState(TankStatePayload.fromJson(json));
        case NetEvent.states:
          _onTankStates(TankStatesPayload.fromJson(json));
        case NetEvent.shoot:
          _onShoot(ShootPayload.fromJson(json));
        case NetEvent.hit:
          _onHit(HitPayload.fromJson(json));
        case NetEvent.death:
          _onDeath(DeathPayload.fromJson(json));
        case NetEvent.pickup:
          _onPickup(PickupPayload.fromJson(json));
        case NetEvent.smoke:
          _onSmoke(SmokePayload.fromJson(json));
        case NetEvent.obstacle:
          _onObstacle(ObstaclePayload.fromJson(json));
        case NetEvent.soldier:
          _onSoldier(SoldierPayload.fromJson(json));
        case NetEvent.mine:
          _onMine(MinePayload.fromJson(json));
        case NetEvent.artillery:
          final strike = ArtilleryPayload.fromJson(json);
          _onArtillery(
            ArtilleryPayload(
              id: strike.id,
              strikeId: strike.strikeId,
              x: strike.x,
              y: strike.y,
              at: strike.at + player.shift,
            ),
          );
        case NetEvent.grenade:
          _onGrenade(GrenadePayload.fromJson(json));
        case NetEvent.drone:
          _onDrone(DronePayload.fromJson(json));
        case NetEvent.blast:
          _onBlast(BlastPayload.fromJson(json));
        case NetEvent.squad:
          _onSquad(SquadPayload.fromJson(json));
        case NetEvent.use:
          _onUse(UsePayload.fromJson(json));
        case NetEvent.flag:
          if (FlagPayload.tryParse(json) case final payload?) {
            _onFlag(payload);
          }
        case NetEvent.air ||
            NetEvent.roundStart ||
            NetEvent.defense ||
            NetEvent.tower ||
            NetEvent.troops ||
            NetEvent.close:
          break;
      }
    }
    if (player.done && now > player.startedAt + player.replay.length + 3000) {
      stopReplay();
    }
  }
}
