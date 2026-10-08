/// Reads a room code from what a player typed or scanned: the bare code, or
/// a room link with `?room=CODE`. Null when neither fits.
String? roomCodeFrom(String text) {
  final trimmed = text.trim();
  final uri = Uri.tryParse(trimmed);
  final candidate = uri != null && uri.hasScheme
      ? uri.queryParameters['room'] ?? ''
      : trimmed;
  final code = candidate.trim().toUpperCase();
  return _code.hasMatch(code) ? code : null;
}

final _code = RegExp(r'^[A-Z0-9]{3,12}$');
