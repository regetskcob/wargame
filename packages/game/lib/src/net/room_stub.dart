import '../env.dart';

/// Room of this session. Outside the browser there is no address to read it
/// from, so everybody meets in the default room.
String resolveRoom() => Env.room;

/// True when this session opened the room, false when it joined by a link.
bool isRoomHost() => true;

/// Link that brings others into [room], empty when there is none to share.
String roomLink(String room) => '';

/// Hands [url] to the share sheet of the device. False when there is none.
Future<bool> shareRoomLink(String url, String text) async => false;

/// Opens a fresh room. False when this platform cannot, the game then joins
/// its one room again.
bool openFreshRoom() => false;
