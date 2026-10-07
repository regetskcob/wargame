/// Held-down state of the on-screen controls, read by the player's tank.
class TouchInput {
  bool left = false;
  bool right = false;
  bool thrust = false;
  bool brake = false;
  bool fire = false;

  /// Set while the aim stick is pushed to its edge, which also fires.
  bool aimFire = false;

  /// World angle picked with the aim stick. Stays set after release, so the
  /// turret keeps pointing where it was last aimed.
  double? aim;

  void reset() {
    left = right = thrust = brake = fire = aimFire = false;
    aim = null;
  }
}
