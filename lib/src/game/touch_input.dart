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

  /// Held while the special weapon button is pressed.
  bool special = false;

  /// Touch: where the drive stick points, as a screen direction with its
  /// length from 0 to 1. The tank turns that way and drives, so a phone
  /// player steers like in a twin stick shooter instead of with the tank's
  /// own left and right. Null while the thumb is off the stick.
  (double, double)? drive;

  /// Touch: whether the thumb is on the aim stick right now.
  bool aimHeld = false;

  /// Touch: the turret picks the nearest enemy in range and fires on it as
  /// long as the aim stick is not held. Switched with a button.
  bool assist = false;

  /// Set by the tank while assisted aim is on target.
  bool assistFire = false;

  /// How far a grenade should fly. Bots set it, players aim with the mouse.
  double? lobDistance;

  void reset() {
    left = right = thrust = brake = fire = aimFire = special = false;
    aimHeld = assistFire = false;
    aim = null;
    drive = null;
    lobDistance = null;
  }
}
