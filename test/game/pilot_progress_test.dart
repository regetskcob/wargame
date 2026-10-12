import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/db/score_service.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/pilot_progress.dart';
import 'package:wargame/src/game/round_stats.dart';

import '../helpers/fakes.dart';

/// Hands out numbered tickets and keeps what each round was recorded with.
class _TicketScores implements ScoreService {
  _TicketScores({this.guest = false});

  final bool guest;
  final cpuAsked = <int>[];
  final recordedWith = <String?>[];

  @override
  bool get isGuest => guest;

  @override
  Future<String?> startRound({int cpu = 0}) async {
    cpuAsked.add(cpu);
    return 'ticket-${cpuAsked.length}';
  }

  @override
  Future<RoundRecord?> recordRound({
    required String name,
    required RoundStats stats,
    required bool won,
    required int tankType,
    List<String> beaten = const [],
    List<String> beatenBy = const [],
    int cpuBeaten = 0,
    int cpuBeatenBy = 0,
    int cpuRating = 1000,
    String? ticket,
    int waves = 0,
    bool wavesBaseFell = false,
  }) async {
    recordedWith.add(ticket);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> finish(PilotProgress progress) => progress.recordRound(
    name: 'Darwin',
    stats: RoundStats(),
    won: true,
    tankType: TankType.hermelin,
    hpLeft: 50,
    soldiers: 0,
    night: false,
    beaten: const [],
    beatenBy: const [],
    cpuBeaten: 3,
  );

  test('a round hands in the ticket taken at its start, once', () async {
    final scores = _TicketScores();
    final progress = PilotProgress(scores: scores, profiles: FakeProfiles());
    progress.startRound(cpu: 3);
    await finish(progress);
    expect(scores.cpuAsked, [3]);
    expect(scores.recordedWith, ['ticket-1']);
    // A second recording without a new start has no ticket left to use.
    await finish(progress);
    expect(scores.recordedWith, ['ticket-1', null]);
    progress.startRound(cpu: 0);
    await finish(progress);
    expect(scores.recordedWith.last, 'ticket-2');
  });

  test('guests take no ticket', () async {
    final scores = _TicketScores(guest: true);
    final progress = PilotProgress(scores: scores, profiles: FakeProfiles());
    progress.startRound(cpu: 4);
    await finish(progress);
    expect(scores.cpuAsked, isEmpty);
    expect(scores.recordedWith, isEmpty);
    expect(progress.unranked.value, isTrue);
  });

  test('the ticket goes into the parameters only when there is one', () {
    Map<String, dynamic> params(String? ticket) => ScoreService.roundParams(
      name: 'Darwin',
      stats: RoundStats(),
      won: false,
      tankType: 0,
      ticket: ticket,
    );
    expect(params('abc')['p_ticket'], 'abc');
    // Old databases refuse parameters they do not know.
    expect(params(null).containsKey('p_ticket'), isFalse);
  });

  test('only a defense round sends its waves', () {
    Map<String, dynamic> params(int waves) => ScoreService.roundParams(
      name: 'Darwin',
      stats: RoundStats(),
      won: true,
      tankType: 0,
      waves: waves,
      wavesBaseFell: true,
    );
    expect(params(14)['p_waves'], 14);
    expect(params(14)['p_waves_base_fell'], isTrue);
    expect(params(0).keys.where((k) => k.startsWith('p_waves')), isEmpty);
  });
}
