import '../env.dart';

/// Room of this session. Outside the browser there is no address to read it
/// from, so everybody meets in the default room.
String resolveRoom() => Env.room;

/// Link that brings others into [room], empty when there is none to share.
String roomLink(String room) => '';

/// Hands [url] to the share sheet of the device. False when there is none.
Future<bool> shareRoomLink(String url, String text) async => false;
