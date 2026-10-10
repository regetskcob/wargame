part of '../tank_game.dart';

/// The waiting room: modes and settings, the pilot and the account, the host role, the room listing, who is who, and closing or leaving the room.
extension TankGameLobby on TankGame {
  void setMode(GameMode value) => mode.value = value;

  /// Welcome page: go on without an account.
  void playAsGuest() => welcomed.value = true;

  /// Start page: take [value] and move on to the waiting room.
  void chooseMode(GameMode value, {bool duel = false}) {
    duelNext.value = duel && value == GameMode.defense;
    mode.value = value;
    configuring.value = false;
    choosingMode.value = false;
  }

  /// A chat invitation chose the mode already: skip the start page. The
  /// names are those of the Messages extension, unknown ones change
  /// nothing.
  void chooseInvitedMode(String name) {
    switch (name) {
      case 'multi':
        chooseMode(GameMode.multi);
      case 'flag':
        chooseMode(GameMode.flag);
      case 'defense':
        chooseMode(GameMode.defense);
      case 'duel':
        chooseMode(GameMode.defense, duel: true);
    }
  }

  /// Back to the start page, to play another way.
  void changeMode() => choosingMode.value = true;

  /// From the waiting room to the settings of the round.
  void editSettings() => configuring.value = true;

  /// The settings are done: back to the waiting room.
  void closeSettings() => configuring.value = false;

  void _updateListing() {
    final listed =
        isHost.value &&
        !beforeWaitingRoom &&
        (mode.value == GameMode.multi || mode.value == GameMode.flag) &&
        publicRoom.value;
    final current = phase.value;
    unawaited(
      directory.advertise(
        listed
            ? RoomListing(
                room: net.room,
                host: myName,
                players: max(1, roster.value.length),
                inMatch:
                    current != GamePhase.lobby &&
                    current != GamePhase.roundOver,
                teams: teamMode.value || mode.value == GameMode.flag,
              )
            : null,
      ),
    );
  }

  void _refreshTutorialDone() => tutorialDone.value = _tutorialSeen();

  /// Seen in this browser, or on the account for the current controls. A
  /// browser that saw it before accounts kept the marker hands it on.
  bool _tutorialSeen() {
    if (tutorialSeen()) {
      unawaited(accounts.rememberTutorialSeen(touch: touchMode.value));
      return true;
    }
    if (accounts.olderThanTutorial) {
      // Players from before the tutorial get the marker right away, for
      // both kinds of controls.
      rememberTutorialSeen();
      unawaited(() async {
        await accounts.rememberTutorialSeen(touch: true);
        await accounts.rememberTutorialSeen(touch: false);
      }());
      return true;
    }
    return accounts.tutorialSeen(touch: touchMode.value);
  }

  /// Opens the tutorial over everything else, from the welcome page, the
  /// start page or the waiting room.
  void showTutorial() {
    if (!overlays.isActive(OverlayIds.tutorial)) {
      overlays.add(OverlayIds.tutorial);
    }
  }

  /// Closes the tutorial and marks it as seen, whether it was finished or
  /// skipped.
  void closeTutorial() {
    rememberTutorialSeen();
    tutorialDone.value = true;
    unawaited(accounts.rememberTutorialSeen(touch: touchMode.value));
    overlays.remove(OverlayIds.tutorial);
  }

  /// Signing in or out swaps the account: bring in its name, look and
  /// progress.
  void _onAccountChanged() {
    if (!accounts.isGuest) {
      welcomed.value = true;
    }
    _refreshTutorialDone();
    final id = accounts.user.value?.id;
    if (id == null || id == _accountId) {
      return;
    }
    _accountId = id;
    _adoptLanguage();
    unawaited(() async {
      await _loadPilot();
      pilotVersion.value++;
      await pushPresence();
    }());
  }

  /// Speaks the language kept with the account. An account without one
  /// takes the language in use on this device.
  void _adoptLanguage() {
    final kept = accounts.language;
    if (kept == null) {
      _saveLanguage();
    } else if (kept != L10n.current) {
      unawaited(L10n.set(kept));
    }
  }

  void _saveLanguage() => unawaited(accounts.rememberLanguage(L10n.current));

  /// Name, look and progress from the last visit. Gives up after a few
  /// seconds so a slow network never holds up the lobby.
  Future<void> _loadPilot() async {
    try {
      final profile = await profiles.load().timeout(const Duration(seconds: 3));
      await progress.load().timeout(const Duration(seconds: 3));
      if (profile != null) {
        myName = profile.name;
        final color = profile.style % GameConfig.tankColors.length;
        final type = GameConfig.typeOf(profile.style);
        myColorIndex = GameConfig.styleOf(
          progress.vehicleUnlocked(type) ? type.index : TankType.hermelin.index,
          progress.unlocked(color) ? color : 0,
        );
      } else if (accounts.user.value?.userMetadata['call_sign']
          case final String name when name.isNotEmpty) {
        // Registered elsewhere, first time on this device.
        myName = name;
      }
    } on Object {
      return;
    }
  }

  LobbyPresence _presencePayload() {
    return LobbyPresence(
      id: myId,
      name: myName,
      colorIndex: myColorIndex,
      phase: phase.value.name,
      team: phase.value == GamePhase.lobby ? teamPick : myTeam,
      host: isHost.value,
      owner: net.isHost,
      seed: round?.seed,
      startedAt: round?.startedAt,
      uid: scoreService.myId,
      defense: round?.defense ?? false,
      flag: round?.flag ?? false,
      botHost: switch (round) {
        final r? when r.defense => r.botHost,
        final r? when r.flag => r.flagHost,
        _ => null,
      },
      joinedAt: net.joinedAt,
      pad: padSteered.value,
    );
  }

  Future<void> pushPresence() => net.updatePresence(_presencePayload());

  void setTeamPick(int team) {
    teamPick = team;
    unawaited(pushPresence());
  }

  /// Teams for a round: picks are honoured, players without a pick fill up
  /// whichever team is smaller. [force] makes teams without the switch in
  /// the lobby, for capturing the flag.
  Map<String, int> _assignTeams(List<String> ids, {bool force = false}) {
    if (!teamMode.value && !force) {
      return const {};
    }
    final teams = <String, int>{};
    for (final id in ids) {
      final pick = id == myId ? teamPick : _rosterMember(id)?.team ?? 0;
      if (pick == 1 || pick == 2) {
        teams[id] = pick;
      }
    }
    for (final id in ids) {
      if (teams.containsKey(id)) {
        continue;
      }
      final red = teams.values.where((t) => t == 1).length;
      final blue = teams.values.where((t) => t == 2).length;
      teams[id] = red <= blue ? 1 : 2;
    }
    return teams;
  }

  /// The call sign given when registering: shown everywhere instead of the
  /// e-mail address.
  void claimCallSign(String name) {
    setPilot(name: name, colorIndex: myColorIndex);
    pilotVersion.value++;
  }

  void setPilot({required String name, required int colorIndex}) {
    myName = name.trim().isEmpty ? myName : name.trim();
    final color = colorIndex % GameConfig.tankColors.length;
    if (progress.unlocked(color) &&
        progress.vehicleUnlocked(GameConfig.typeOf(colorIndex))) {
      myColorIndex = colorIndex;
    }
    unawaited(pushPresence());
    // Typing a name calls this on every key, so save once it settles.
    _saveTimer?.cancel();
    _saveTimer = async.Timer(const Duration(milliseconds: 800), () {
      unawaited(profiles.save(name: myName, style: myColorIndex));
    });
  }

  LobbyPresence? get liveMatch {
    for (final member in roster.value) {
      // The own presence still says playing for a moment after leaving a
      // round, and nobody watches themselves.
      if (member.id != myId &&
          member.inMatch &&
          TankGame._liveMatchPhases.contains(member.phase)) {
        return member;
      }
    }
    return null;
  }

  /// Only the host starts a round. When the host leaves, the role moves on.
  bool get canStart => isHost.value;

  void _setHost(bool value) {
    if (isHost.value == value) {
      return;
    }
    isHost.value = value;
    if (!value && mode.value == GameMode.solo) {
      // Guests always play together, the settings belong to the host.
      mode.value = GameMode.multi;
    }
    unawaited(pushPresence());
  }

  /// Makes sure the room has exactly one host. Presence takes a moment to
  /// travel, so a missing or doubled host is only fixed once it lasts: then
  /// the player with the smallest id stands in, and a stand-in hands back as
  /// soon as the owner of the room returns.
  void _settleHost(double dt) {
    final members = roster.value;
    if (phase.value == GamePhase.closed || !members.any((m) => m.id == myId)) {
      _hostlessFor = _hostClashFor = 0;
      return;
    }
    final hosts = [
      for (final member in members)
        if (member.host) member.id,
    ];
    _hostlessFor = hosts.isEmpty && !isHost.value ? _hostlessFor + dt : 0;
    _hostClashFor = hosts.length > 1 ? _hostClashFor + dt : 0;
    final first = (members.map((m) => m.id).toList()..sort()).first;
    if (_hostlessFor >= GameConfig.hostSettleSeconds && first == myId) {
      _hostlessFor = 0;
      _setHost(true);
    }
    final outranked = members.any(
      (m) => m.host && m.id != myId && (m.owner || m.id.compareTo(myId) < 0),
    );
    // The owner never steps down.
    if (_hostClashFor >= GameConfig.hostSettleSeconds &&
        isHost.value &&
        !net.isHost &&
        outranked) {
      _hostClashFor = 0;
      _setHost(false);
    }
  }

  /// Red against blue is coming up: every tank drives in its side's
  /// colour, so choosing a camouflage makes no sense. The defense always
  /// plays it, the defenders red and the attackers blue.
  bool get teamsAhead =>
      mode.value == GameMode.flag ||
      mode.value == GameMode.defense ||
      teamMode.value;

  /// Colour of a player's tank as the lobby previews it: the side's colour
  /// in red against blue (neutral while AUTO has not decided yet),
  /// camouflage alone, one colour per seat when playing with others.
  Color lobbyColorOf(String id, int style) {
    if (mode.value == GameMode.defense) {
      // A duel takes exactly two players, the host on the left, red base.
      final players = {myId, for (final member in roster.value) member.id};
      if (!duelNext.value || players.length != 2) {
        return GameConfig.teamColors[1];
      }
      final host = id == myId ? isHost.value : _rosterMember(id)?.host;
      return GameConfig.teamColors[host ?? false ? 1 : 2];
    }
    if (teamsAhead) {
      final team = id == myId ? teamPick : _rosterMember(id)?.team ?? 0;
      return GameConfig.teamColors[team.clamp(0, 2)];
    }
    if (!mode.value.withOthers) {
      return GameConfig.colorOf(style);
    }
    final seats = {myId, for (final member in roster.value) member.id}.toList()
      ..sort();
    return GameConfig.playerColor(max(0, seats.indexOf(id)));
  }

  Color _colorFor(String id) {
    final activeRound = round;
    // Red against blue, and every defense: the hull tells friend from foe.
    if (activeRound != null && (activeRound.teamMode || activeRound.defense)) {
      final team = activeRound.teamOf(id);
      if (team > 0) {
        return GameConfig.teamColors[team];
      }
    }
    if (activeRound != null && activeRound.distinctColors) {
      final seat = activeRound.participants.indexOf(id);
      if (seat >= 0) {
        return GameConfig.playerColor(seat);
      }
    }
    return GameConfig.colorOf(_styleFor(id));
  }

  LobbyPresence? _rosterMember(String id) {
    for (final member in roster.value) {
      if (member.id == id) {
        return member;
      }
    }
    return null;
  }

  int _styleFor(String id) {
    if (_replayPlayer?.replay.styles[id] case final style?) {
      return style;
    }
    if (id == myId) {
      return myColorIndex;
    }
    final activeRound = round;
    if (activeRound != null && activeRound.isEnemy(id)) {
      return activeRound.enemyStyle(id);
    }
    if (activeRound != null && activeRound.isAlly(id)) {
      return activeRound.allyStyle(id);
    }
    return activeRound?.bots[id] ?? _rosterMember(id)?.colorIndex ?? 0;
  }

  String _nameFor(String id) {
    if (_replayPlayer?.replay.names[id] case final name?) {
      return name;
    }
    if (id == myId) {
      return myName;
    }
    if (id.startsWith('inf-')) {
      final team = int.tryParse(id.substring(4)) ?? 0;
      return '${tr('INFANTERIE', 'INFANTRY')} ${GameConfig.teamNames[team.clamp(0, 2)]}'
          .trim();
    }
    final activeRound = round;
    if (activeRound != null && activeRound.isBot(id)) {
      return activeRound.botName(id);
    }
    return _rosterMember(id)?.name ?? tr('Panzer', 'Tank');
  }

  String _nameOf(String id) =>
      id == myId ? myName : remoteTanks[id]?.playerName ?? _nameFor(id);

  bool isTeammate(String id) => id != myId && sameTeam(myId, id);

  /// True for two different tanks of the same team, never in a free for all.
  bool sameTeam(String a, String b) {
    final activeRound = round;
    if (activeRound == null || a == b) {
      return false;
    }
    final team = activeRound.teamOf(a);
    return team > 0 && team == activeRound.teamOf(b);
  }

  /// Closes the waiting room: as host for everybody, as guest just for you.
  /// The host closed it on purpose, so a closed screen would only be in the
  /// way: they go straight on to choosing the next mode.
  Future<void> closeRoom() async {
    if (phase.value == GamePhase.closed) {
      return;
    }
    final host = isHost.value;
    _enterClosed(
      host
          ? null
          : tr(
              'Du hast den Warteraum verlassen.',
              'You left the waiting room.',
            ),
    );
    if (!host) {
      await net.dispose();
      return;
    }
    await net.closeRoom();
    await backToStart();
  }

  void _onClose(String id) {
    final sender = _rosterMember(id);
    if (sender == null || !sender.host || phase.value == GamePhase.closed) {
      return;
    }
    // Anybody can claim to be host in their own presence. While the owner
    // is in the room only the owner closes it, and an id two presences
    // claim is somebody posing as another.
    final owners = roster.value.where((m) => m.owner).toList();
    if (net.duplicateIds.contains(id) ||
        owners.length > 1 ||
        (owners.length == 1 && owners.single.id != id)) {
      return;
    }
    _enterClosed(
      tr(
        'Der Gastgeber hat den Warteraum geschlossen.',
        'The host closed the waiting room.',
      ),
    );
    fireAndForget(net.dispose(), 'Leaving the room');
  }

  /// Nobody started a round or came and went for a long time: leave the
  /// room, so forgotten tabs do not keep it open forever.
  @visibleForTesting
  void closeWhenIdle({DateTime? now}) {
    if (phase.value != GamePhase.lobby || dozing) {
      return;
    }
    final idle = (now ?? DateTime.now()).difference(_lastActivity);
    if (idle < GameConfig.lobbyIdleTimeout) {
      return;
    }
    if (beforeWaitingRoom) {
      // No waiting room on screen to close: leave the room quietly and
      // join it again with the next step.
      dozing = true;
      roster.value = const [];
      fireAndForget(net.dispose(), 'Leaving the room');
      return;
    }
    _enterClosed(
      tr(
        'Der Warteraum wurde nach '
            '${GameConfig.lobbyIdleTimeout.inMinutes} Minuten ohne Aktivität '
            'geschlossen.',
        'The waiting room was closed after '
            '${GameConfig.lobbyIdleTimeout.inMinutes} minutes without '
            'activity.',
      ),
    );
    fireAndForget(net.dispose(), 'Leaving the room');
  }

  /// Whether the player still looks at the welcome page or, as host, at
  /// the start page: the room is joined, but no waiting room is shown.
  bool get beforeWaitingRoom =>
      !welcomed.value || (choosingMode.value && isHost.value);

  /// Moving on to the waiting room joins the room again after dozing.
  void _wake() {
    if (!dozing || beforeWaitingRoom) {
      return;
    }
    dozing = false;
    _lastActivity = DateTime.now();
    fireAndForget(net.connect(_presencePayload()), 'Joining the room');
  }

  void _enterClosed(String? reason) {
    _dropSlot();
    _clearWorld();
    round = null;
    myTeam = 0;
    roster.value = const [];
    closedReason.value = reason;
    _setPhase(GamePhase.closed);
  }

  /// Leaves this room for good, before the apps swap in a game for another
  /// one: the channels close, timers stop and nothing writes anymore.
  Future<void> leave() async {
    if (_saveTimer?.isActive ?? false) {
      // A name typed just now still goes out.
      _saveTimer!.cancel();
      try {
        await profiles.save(name: myName, style: myColorIndex);
      } on Object {
        // Leaving the room matters more.
      }
    }
    _noticeTimer?.cancel();
    _dropSlot();
    pauseEngine();
    L10n.lang.removeListener(_saveLanguage);
    accounts.dispose();
    await directory.dispose();
    await net.dispose();
  }

  /// Leaves the closed screen for the start page of a new room, hosted by
  /// this player.
  Future<void> backToStart() async {
    if (phase.value != GamePhase.closed || openFreshRoom()) {
      return;
    }
    // No address bar to start over from: meet in the same room again.
    _setHost(true);
    choosingMode.value = true;
    _lastActivity = DateTime.now();
    closedReason.value = null;
    _setPhase(GamePhase.lobby);
    await net.connect(_presencePayload());
  }

  void _onRosterChanged(List<LobbyPresence> all) {
    final members = LobbyPresence.admitted(all, GameConfig.maxPilots);
    if (phase.value != GamePhase.closed &&
        all.any((member) => member.id == myId) &&
        !members.any((member) => member.id == myId)) {
      _enterClosed(
        tr(
          'Der Raum ist voll: höchstens ${GameConfig.maxPilots} Piloten.',
          'The room is full: ${GameConfig.maxPilots} pilots at most.',
        ),
      );
      fireAndForget(net.dispose(), 'Leaving the room');
      return;
    }
    final before = {for (final member in roster.value) member.id};
    final after = {for (final member in members) member.id};
    if (before.length != after.length || !before.containsAll(after)) {
      _lastActivity = DateTime.now();
    }
    roster.value = members;
    _watchSlot();
  }

  /// Pilots in the room that Realtime carries: the second player on this
  /// device talks to this game directly and costs nothing.
  int get _pilotsOnline =>
      roster.value.where((member) => !net.isLocalPeer(member.id)).length;

  /// A phone steers somebody's tank in this room, this game's included.
  bool get roomHasPhone =>
      padSteered.value || roster.value.any((member) => member.pad);

  /// Realtime messages a second this room costs. With a phone in it there
  /// are no CPU tanks, except in defense, where the enemies are CPU tanks.
  int get _roomLoad => GameConfig.roomLoad(
    _pilotsOnline,
    cpu: !roomHasPhone || mode.value == GameMode.defense,
    flag: mode.value == GameMode.flag,
  );

  void _onPadSteered() {
    unawaited(pushPresence());
    _watchSlot();
  }

  /// With somebody else in the room messages flow, and the room needs a
  /// slot of the project's Realtime budget. Everybody in it keeps the slot
  /// fresh, and claims again at once when the room's load changes.
  void _watchSlot() {
    // The second player on this device costs nothing: only people on other
    // devices make the room take a slot.
    final shared = _pilotsOnline > 1 && phase.value != GamePhase.closed;
    if (!shared) {
      // Alone again, for now: no refresh, but a room that held its slot
      // keeps counting as one when the others come back.
      _slotTimer?.cancel();
      _slotTimer = null;
      _claimedLoad = null;
      return;
    }
    if (_slotTimer != null && _claimedLoad == _roomLoad) {
      return;
    }
    _slotTimer ??= async.Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_claimSlot()),
    );
    unawaited(_claimSlot());
  }

  /// Claims the room's slot again at once, as the pairing does before the
  /// phones claim theirs. Nothing while the pilot is alone.
  Future<void> refreshRoomSlot() async {
    if (_pilotsOnline > 1 && phase.value != GamePhase.closed) {
      await _claimSlot();
    }
  }

  void _dropSlot() {
    _slotTimer?.cancel();
    _slotTimer = null;
    _slotHeld = false;
    _claimedLoad = null;
  }

  Future<void> _claimSlot() async {
    final load = _roomLoad;
    _claimedLoad = load;
    final ok = await slots.claim(net.room, load);
    if (_slotTimer == null) {
      return;
    }
    if (ok) {
      _slotHeld = true;
      return;
    }
    // The budget has no room for this one. Who just came in leaves again;
    // the room's owner stays and waits, and a room that already played
    // keeps playing.
    if (_slotHeld || net.isHost || phase.value == GamePhase.closed) {
      return;
    }
    _enterClosed(
      tr(
        'Alle Räume sind gerade belegt. Versuch es in ein paar Minuten '
            'noch einmal, Einzelspieler geht immer.',
        'All rooms are taken right now. Try again in a few minutes, '
            'single player always works.',
      ),
    );
    fireAndForget(net.dispose(), 'Leaving the room');
  }
}
