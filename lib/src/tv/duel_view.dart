import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/overlay_ids.dart';
import '../db/account_service.dart';
import '../db/profile_service.dart';
import '../db/score_service.dart';
import '../game/game_config.dart';
import '../game/game_mode.dart';
import '../game/tank_game.dart';
import '../l10n/l10n.dart';
import '../net/net_service.dart';
import '../net/payloads/defense_payload.dart';
import '../ui/countdown_overlay.dart';
import '../ui/hud_overlay.dart';
import '../ui/spectator_overlay.dart';
import '../ui/theme.dart';
import '../ui/widgets/panel.dart';
import '../ui/widgets/tablet_scale.dart';
import 'tv_input.dart';

/// One against one on the Apple TV: the screen split in half, each player
/// with a controller of their own defends a base of their own against the
/// same waves on the same map. Whose base falls first loses.
///
/// Each half is a game of its own, in a room of its own, so the defense
/// runs exactly as it does for one player. Both start from the same seed at
/// the same moment and go on past the last regular wave by themselves. The
/// rounds count for nobody: two players share one account here.
class DuelView extends StatefulWidget {
  const DuelView({super.key});

  /// Whether a duel is on screen and its games need the focus.
  static var running = false;

  static Future<void> open(BuildContext context) {
    return Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const DuelView()));
  }

  @override
  State<DuelView> createState() => _DuelViewState();
}

class _DuelViewState extends State<DuelView> {
  late List<TankGame> _games;
  Timer? _watch;
  final _focus = FocusNode(debugLabel: 'duel');
  final _rematchFocus = FocusNode(debugLabel: 'rematch');

  /// The half that won, -1 for both falling at once, null while it runs.
  int? _winner;

  @override
  void initState() {
    super.initState();
    DuelView.running = true;
    _games = _newGames();
  }

  @override
  void dispose() {
    DuelView.running = false;
    _watch?.cancel();
    _focus.dispose();
    _rematchFocus.dispose();
    for (final game in _games) {
      unawaited(game.leave());
    }
    super.dispose();
  }

  List<TankGame> _newGames() {
    final games = [for (var player = 0; player < 2; player++) _game(player)];
    unawaited(_begin(games));
    _watch?.cancel();
    _watch = Timer.periodic(const Duration(milliseconds: 400), (_) => _check());
    return games;
  }

  TankGame _game(int player) {
    final client = Supabase.instance.client;
    final random = Random();
    final id = [
      for (var i = 0; i < 16; i++) random.nextInt(16).toRadixString(16),
    ].join();
    return TankGame(
        net: NetService(myId: id, room: _roomCode(random), isHost: true),
        myId: id,
        scoreService: _Unranked(client),
        profiles: ProfileService(client),
        accounts: AccountService(client),
      )
      ..tvPlayer = player
      ..chooseMode(GameMode.defense);
  }

  /// A private room nobody else knows, one per half.
  static String _roomCode(Random random) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return [
      for (var i = 0; i < 5; i++) alphabet[random.nextInt(alphabet.length)],
    ].join();
  }

  /// Both halves on the same map with the same waves, starting together.
  Future<void> _begin(List<TankGame> games) async {
    await Future.wait([for (final game in games) game.loaded]);
    if (!mounted || !identical(games, _games)) {
      return;
    }
    final seed = Random().nextInt(1 << 30);
    final startedAt =
        DateTime.now().millisecondsSinceEpoch +
        GameConfig.countdownSeconds * 1000;
    for (final game in games) {
      game.startRound(seed: seed, startedAt: startedAt);
    }
  }

  void _check() {
    if (_winner != null) {
      return;
    }
    for (final game in _games) {
      // Nobody to ask after the last regular wave: on with the waves.
      if (game.defense.value?.deciding ?? false) {
        game.extendDefense();
      }
    }
    final fallen = [for (final game in _games) _fallen(game)];
    if (!fallen.contains(true)) {
      return;
    }
    for (final game in _games) {
      game.pauseEngine();
    }
    setState(() {
      _winner = fallen.every((f) => f) ? -1 : (fallen[0] ? 1 : 0);
    });
    // The duel held the focus so far: hand it to the next duel.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rematchFocus.requestFocus();
      }
    });
  }

  static bool _fallen(TankGame game) {
    final state = game.defense.value;
    return state != null &&
        (state.hp <= 0 || state.result == DefenseResult.lost);
  }

  void _rematch() {
    for (final game in _games) {
      unawaited(game.leave());
    }
    setState(() {
      _winner = null;
      _games = _newGames();
    });
    _focus.requestFocus();
  }

  /// Menu or B in the middle of the duel: carry on or stop.
  Future<void> _askToStop() async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: BwColors.surface,
        title: Text(tr('DUELL BEENDEN?', 'END THE DUEL?')),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(tr('BEENDEN', 'END')),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(tr('WEITER', 'CARRY ON')),
          ),
        ],
      ),
    );
    if (stop ?? false) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final over = _winner != null;
    DuelView.running = !over;
    return PopScope(
      canPop: over,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_askToStop());
        }
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        // Swipes, clicks and the pads of the controllers come as keys as
        // well. The sticks steer, the keys must not move anything.
        onKeyEvent: (_, _) =>
            over ? KeyEventResult.ignored : KeyEventResult.handled,
        child: Scaffold(
          backgroundColor: BwColors.background,
          body: Stack(
            children: [
              // The games steer with the sticks, never with the focus.
              ExcludeFocus(
                child: Row(
                  children: [
                    for (final (player, game) in _games.indexed) ...[
                      if (player > 0)
                        const SizedBox(
                          width: 4,
                          child: ColoredBox(color: BwColors.oliveLight),
                        ),
                      Expanded(child: _half(player, game)),
                    ],
                  ],
                ),
              ),
              if (over)
                _Result(
                  winner: _winner!,
                  waves: [for (final game in _games) game.defense.value?.wave],
                  rematchFocus: _rematchFocus,
                  onRematch: _rematch,
                  onEnd: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _half(int player, TankGame game) {
    // The game draws its world past its own edges: each half clips it.
    return ClipRect(child: _halfContent(player, game));
  }

  Widget _halfContent(int player, TankGame game) {
    return Stack(
      children: [
        GameWidget<TankGame>(
          key: ObjectKey(game),
          game: game,
          autofocus: false,
          overlayBuilderMap: {
            OverlayIds.lobby: (context, game) => const _Waiting(),
            OverlayIds.countdown: (context, game) =>
                CountdownOverlay(game: game),
            // Half a screen: the plates a bit smaller, so the field shows.
            OverlayIds.hud: (context, game) =>
                FixedScale(scale: 0.8, child: HudOverlay(game: game)),
            OverlayIds.spectator: (context, game) =>
                SpectatorOverlay(game: game),
            OverlayIds.roundOver: (context, game) => const SizedBox.shrink(),
            OverlayIds.closed: (context, game) => const SizedBox.shrink(),
            OverlayIds.tutorial: (context, game) => const SizedBox.shrink(),
          },
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PlayerTag(player: player),
          ),
        ),
      ],
    );
  }
}

/// Rounds of a duel count for nobody: the record of a guest.
class _Unranked extends ScoreService {
  _Unranked(super.client);

  @override
  bool get isGuest => true;
}

/// Which player a half belongs to, and what steers it.
class _PlayerTag extends StatelessWidget {
  const _PlayerTag({required this.player});

  final int player;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: TvInput.instance.count,
      builder: (context, _, _) {
        final kind = TvInput.instance.player(player).kind;
        final steer = switch (kind) {
          TvPadKind.gamepad => tr('Controller', 'controller'),
          TvPadKind.remote => 'Siri Remote',
          TvPadKind.none => tr(
            'Controller ${player + 1} fehlt',
            'controller ${player + 1} missing',
          ),
        };
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: BwColors.panel,
            shape: BwShapes.chip(
              edge: kind == TvPadKind.none ? BwColors.danger : BwColors.sand,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '${tr('SPIELER', 'PLAYER')} ${player + 1} · $steer',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: BwColors.text,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Until the round starts.
class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        tr('GEFECHTSFELD WIRD VORBEREITET …', 'PREPARING THE FIELD …'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

/// Who won, how far each got, and on to the next duel.
class _Result extends StatelessWidget {
  const _Result({
    required this.winner,
    required this.waves,
    required this.rematchFocus,
    required this.onRematch,
    required this.onEnd,
  });

  final int winner;
  final List<int?> waves;
  final FocusNode rematchFocus;
  final VoidCallback onRematch;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final title = winner < 0
        ? tr('UNENTSCHIEDEN', 'DRAW')
        : tr('SPIELER ${winner + 1} GEWINNT', 'PLAYER ${winner + 1} WINS');
    return ColoredBox(
      color: const Color(0xAA000000),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Panel(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  winner < 0
                      ? tr(
                          'Beide Stützpunkte sind zugleich gefallen.',
                          'Both bases fell at the same time.',
                        )
                      : tr(
                          'Der Stützpunkt von Spieler ${2 - winner} ist '
                              'zuerst gefallen.',
                          'The base of player ${2 - winner} fell first.',
                        ),
                ),
                const SizedBox(height: 8),
                for (final (player, wave) in waves.indexed)
                  Text(
                    '${tr('Spieler', 'Player')} ${player + 1}: '
                    '${tr('Welle', 'wave')} ${wave ?? 0}',
                    style: const TextStyle(color: BwColors.textDim),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEnd,
                        icon: const Icon(Icons.arrow_back),
                        label: Text(tr('BEENDEN', 'END')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        focusNode: rematchFocus,
                        onPressed: onRematch,
                        icon: const Icon(Icons.replay),
                        label: Text(tr('REVANCHE', 'REMATCH')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
