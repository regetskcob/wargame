/// Decides when the engine loop's volume and pitch are worth changing.
///
/// The game asks ten times a second. Each change is two calls to the
/// platform (volume and rate) that go through the main thread, the same
/// one that starts every shot and blast. On the BoPad in a late defense
/// wave that was 20 calls a second for an engine whose speed hardly moved,
/// queued among the sounds of the field. Now the load is rounded to
/// [steps] and only a different step goes out, and never while the last
/// change is still on its way.
class EngineThrottle {
  /// Steps of the load from standstill to top speed: fine enough that the
  /// pitch still glides, coarse enough that cruising sends nothing.
  static const steps = 20;

  double? _sent;
  bool _pending = false;

  /// The load to send now, rounded, or null when nothing changed or a
  /// change is still under way. [load] is the speed as a share of the top
  /// speed. Call [done] once the change has gone through.
  double? next(double load) {
    if (_pending) {
      return null;
    }
    final level = (load.clamp(0.0, 1.0) * steps).roundToDouble() / steps;
    if (level == _sent) {
      return null;
    }
    _sent = level;
    _pending = true;
    return level;
  }

  /// The change handed out by [next] went through or failed.
  void done() => _pending = false;

  /// A new loop starts at its own volume: send the next load whatever it is.
  void reset() {
    _sent = null;
    _pending = false;
  }
}
