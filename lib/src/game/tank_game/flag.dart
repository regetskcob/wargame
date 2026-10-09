part of '../tank_game.dart';

/// Capture the flag: the bases and flags of the round, the authority that
/// runs them, what the others hear of it, spawning at the own base, CPU
/// tanks that come back and what they head for, and the end of the round.
extension TankGameFlag on TankGame {
  /// The tank called [id] on this device, wherever it is kept.
  TankBase? tankById(String id) =>
      id == myId ? myTank : remoteTanks[id] ?? botTanks[id];

  /// Where [id] starts and comes back: at the own base, side by side,
  /// facing the middle of the field.
  (Vector2, double) _flagSpawn(RoundState activeRound, String id) {
    final team = activeRound.teamOf(id);
    final mates = [
      for (final other in activeRound.participants)
        if (activeRound.teamOf(other) == team) other,
    ];
    final n = mates.length;
    final k = max(0, mates.indexOf(id));
    final base = FlagMatch.baseOf(team == 0 ? 1 : team);
    final inward = base.x < 0 ? 1.0 : -1.0;
    final at = Vector2(base.x + inward * 30, (k - (n - 1) / 2) * 70);
    return (at, TankGame._headingFrom(at, Vector2(0, at.y)));
  }

  void _setUpFlag() {
    flagMatch = FlagMatch();
    _flagSync = 0;
    _flagOvertime = false;
    final bases = FlagBases();
    final markers = FlagMarkers();
    _extras.addAll([bases, markers]);
    world
      ..add(bases)
      ..add(markers);
  }

  bool get _runsFlags =>
      !replaying.value && round?.flag == true && round?.flagHost == myId;

  /// Every frame of a capture the flag round: the authority moves the flags
  /// on and tells the others, everybody slows the carriers down and looks
  /// whether the round is over.
  void _updateFlag(double dt) {
    final activeRound = round;
    final match = flagMatch;
    if (activeRound == null || match == null || !activeRound.flag) {
      return;
    }
    final current = phase.value;
    if (current != GamePhase.playing && current != GamePhase.spectating) {
      return;
    }
    _respawnBots(dt);
    if (_runsFlags) {
      final tanks = <String, FlagTank>{
        for (final tank in [?myTank, ...remoteTanks.values, ...botTanks.values])
          if (tank.isMounted && activeRound.alive.contains(tank.playerId))
            tank.playerId: (
              team: activeRound.teamOf(tank.playerId),
              position: tank.position,
            ),
      };
      final events = match.step(dt, tanks, authority: myId);
      for (final event in events) {
        net.send(NetEvent.flag, event.toJson());
        _announceFlag(event);
      }
      _flagSync += dt;
      if (events.isNotEmpty) {
        _flagSync = 0;
      } else if (_flagSync >= GameConfig.flagSyncSeconds) {
        _flagSync = 0;
        net.send(
          NetEvent.flag,
          match.snapshot(myId, FlagAction.sync, 1).toJson(),
        );
      }
    } else {
      match.tick(dt);
    }
    myTank?.carriesFlag = match.carriedBy(myId) != null;
    for (final bot in botTanks.values) {
      bot.carriesFlag = match.carriedBy(bot.playerId) != null;
    }
    _checkFlagEnd(activeRound, match);
  }

  void _checkFlagEnd(RoundState activeRound, FlagMatch match) {
    if (phase.value == GamePhase.roundOver || replaying.value) {
      return;
    }
    final elapsed = _secondsIntoRound;
    var team = match.winner(elapsed);
    // A side with nobody left gives up the field.
    for (final side in const [1, 2]) {
      if (activeRound.teamGone(side)) {
        team ??= FlagMatch.otherTeam(side);
      }
    }
    if (team == null) {
      if (match.overtime(elapsed) && !_flagOvertime) {
        _flagOvertime = true;
        showNotice(
          tr(
            'VERLÄNGERUNG: DIE NÄCHSTE FAHNE ENTSCHEIDET',
            'OVERTIME: THE NEXT FLAG DECIDES',
          ),
        );
      }
      return;
    }
    final winner = team;
    final ids = activeRound.participants.where(
      (id) =>
          activeRound.teamOf(id) == winner && activeRound.alive.contains(id),
    );
    _endRound(ids.isEmpty ? null : ids.first, winnerTeam: winner);
  }

  /// The authority of the round told how the flags stand.
  void _onFlag(FlagPayload payload) {
    final activeRound = round;
    final match = flagMatch;
    if (activeRound == null ||
        match == null ||
        !activeRound.flag ||
        payload.id != activeRound.flagHost) {
      return;
    }
    match.apply(payload);
    _announceFlag(payload);
  }

  /// What a flag message means for this player, said in a few words.
  void _announceFlag(FlagPayload payload) {
    final activeRound = round;
    if (activeRound == null || payload.action == FlagAction.sync) {
      return;
    }
    final mine = myTeam == payload.team;
    final by = payload.by;
    final who = by == null
        ? ''
        : by == myId
        ? tr('DU', 'YOU')
        : _nameOf(by).toUpperCase();
    final side = GameConfig.teamNames[payload.team];
    final other = GameConfig.teamNames[FlagMatch.otherTeam(payload.team)];
    final score = '${payload.red}:${payload.blue}';
    showNotice(switch (payload.action) {
      FlagAction.take when by == myId => tr(
        'DU HAST DIE FAHNE! AB ZUM EIGENEN STÜTZPUNKT',
        'YOU HAVE THE FLAG! BACK TO YOUR BASE',
      ),
      FlagAction.take when mine => tr(
        '$who HAT EURE FAHNE!',
        '$who HAS YOUR FLAG!',
      ),
      FlagAction.take => tr(
        '$who HAT DIE FAHNE VON $side',
        '$who HAS THE $side FLAG',
      ),
      FlagAction.drop => tr(
        'FAHNE VON $side LIEGT IM FELD',
        'THE $side FLAG IS DOWN',
      ),
      FlagAction.back => tr(
        'FAHNE VON $side IST ZURÜCK',
        'THE $side FLAG IS BACK',
      ),
      FlagAction.capture => tr(
        '$other EROBERT DIE FAHNE · $score',
        '$other CAPTURES THE FLAG · $score',
      ),
      FlagAction.sync => '',
    });
    if (payload.action == FlagAction.capture) {
      AudioService.play(myTeam == payload.team ? 'lose' : 'win');
      shake(6);
    } else if (payload.action == FlagAction.take && (mine || by == myId)) {
      Haptics.tick();
    }
  }

  /// The authority left: the next player in line runs the flags, from the
  /// state they last heard.
  void _handOverFlags(RoundState activeRound) {
    if (!activeRound.flag || !activeRound.left.contains(activeRound.flagHost)) {
      return;
    }
    final present = {myId, for (final member in roster.value) member.id};
    final next = [
      for (final id in activeRound.participants)
        if (!activeRound.isBot(id) &&
            !activeRound.left.contains(id) &&
            present.contains(id))
          id,
    ]..sort();
    activeRound.flagHost = next.isEmpty ? null : next.first;
    _flagSync = GameConfig.flagSyncSeconds;
  }

  /// Host: CPU tanks come back at their base a while after they were
  /// destroyed.
  void _respawnBots(double dt) {
    final activeRound = round;
    if (activeRound == null ||
        activeRound.botHost != myId ||
        (phase.value != GamePhase.playing &&
            phase.value != GamePhase.spectating)) {
      return;
    }
    for (final id in _botRespawns.keys.toList()) {
      final wait = _botRespawns[id]! - dt;
      if (wait > 0) {
        _botRespawns[id] = wait;
        continue;
      }
      _botRespawns.remove(id);
      final (at, facing) = _flagSpawn(activeRound, id);
      _spawnBot(activeRound, id, at, facing);
      activeRound.alive.add(id);
      aliveCount.value = activeRound.alive.length;
    }
  }

  /// Where a CPU tank of a capture the flag round drives when no enemy is
  /// close: its carrier home, the others after the flags. One in three of a
  /// side stays back to guard the base.
  Vector2? flagGoal(PlayerTank bot) {
    final activeRound = round;
    final match = flagMatch;
    if (activeRound == null || match == null) {
      return null;
    }
    final team = activeRound.teamOf(bot.playerId);
    if (team == 0) {
      return null;
    }
    final home = FlagMatch.baseOf(team);
    if (match.carriedBy(bot.playerId) != null) {
      return home;
    }
    final own = match.flags[team]!;
    final theirs = match.flags[FlagMatch.otherTeam(team)]!;
    // The own flag is out: get it back, the carrier is where it is.
    if (!own.home) {
      final carrier = own.carrier;
      return carrier == null
          ? own.position
          : tankById(carrier)?.position ?? own.position;
    }
    final mates = [
      for (final id in activeRound.participants)
        if (activeRound.teamOf(id) == team) id,
    ];
    final guard = mates.length > 1 && mates.indexOf(bot.playerId) % 3 == 2;
    if (guard) {
      return bot.position.distanceTo(home) > 150 ? home : null;
    }
    // A comrade has their flag: ride along home with them.
    if (theirs.spot == FlagSpot.carried) {
      final carrier = theirs.carrier;
      return carrier == null ? home : tankById(carrier)?.position ?? home;
    }
    return theirs.position;
  }
}
