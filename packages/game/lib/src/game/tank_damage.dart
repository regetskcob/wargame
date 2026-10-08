import '../l10n/l10n.dart';

/// How badly a tank is battered, and what that does to it. Everything follows
/// from the hit points alone, so every client sees the same wreckage on every
/// tank without extra network traffic.
enum DamageStage {
  intact(0, null, null),
  scratched(0.15, null, null),
  damaged(0.4, 'KETTE BESCHÄDIGT', 'TRACK DAMAGED'),
  crippled(0.65, 'MOTOR BESCHÄDIGT', 'ENGINE DAMAGED'),
  burning(0.82, 'PANZER BRENNT', 'TANK ON FIRE');

  const DamageStage(this.threshold, this._noticeDe, this._noticeEn);

  /// Wear from which on the stage applies.
  final double threshold;

  /// Warning for the driver when the tank sinks to this stage.
  String? get notice => _noticeDe == null ? null : tr(_noticeDe, _noticeEn!);

  final String? _noticeDe;
  final String? _noticeEn;
}

class TankDamage {
  const TankDamage(this.wear);

  factory TankDamage.of(double hp, double maxHp) =>
      TankDamage(maxHp <= 0 ? 0 : (1 - hp / maxHp).clamp(0.0, 1.0));

  /// 0 for a fresh tank, 1 for a wreck.
  final double wear;

  DamageStage get stage =>
      DamageStage.values.lastWhere((s) => wear >= s.threshold);

  /// Wear past the first scratches, where the tank starts to suffer.
  double get _hurt => ((wear - 0.25) / 0.75).clamp(0.0, 1.0);

  /// Top speed drops by up to a third.
  double get speedFactor => 1 - 0.33 * _hurt;

  /// The engine pulls weaker, by up to 45 %.
  double get accelerationFactor => 1 - 0.45 * _hurt;

  /// Steering gets sluggish, by up to a quarter.
  double get turnFactor => 1 - 0.25 * _hurt;

  /// The turret drive grinds, by up to half its speed.
  double get turretFactor => 1 - 0.5 * _hurt;

  /// 0 to 1: how much a damaged running gear shakes the ride.
  double get bumpiness => _hurt;

  /// Engine misfires per second at full throttle.
  double get stallRate =>
      wear < DamageStage.crippled.threshold ? 0 : 0.35 + 1.2 * _hurt;

  /// Seconds between two puffs from the engine deck, null for none.
  double? get smokeInterval => switch (stage) {
    DamageStage.intact || DamageStage.scratched => null,
    DamageStage.damaged => 0.45,
    DamageStage.crippled => 0.2,
    DamageStage.burning => 0.09,
  };
}
