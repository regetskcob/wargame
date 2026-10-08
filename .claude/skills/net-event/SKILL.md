---
name: net-event
description: Checklist for adding or changing a Realtime broadcast event or payload in Panzergefecht (shots, items, towers, defense state ...). Use whenever a feature needs a new message between clients or a new field in an existing payload.
---

# Adding a network event

Every client runs the same world from the seed; only events travel. A new
event touches these places, in this order:

1. **Enum** `lib/src/net/net_events.dart`: add the value. Its `name` is the
   wire name, so never rename existing values (old clients still send them).
2. **Payload** in `lib/src/net/payloads/`: an immutable class with
   `toJson()` and `fromJson()`. Read defensively: anybody can send anything
   on the channel. Missing or wrongly typed fields must not throw into the
   game loop; follow `LobbyPresence.tryParse` and the existing payloads.
   New fields on an existing payload need a default, so older clients'
   messages still parse.
3. **NetService** `lib/src/net/net_service.dart`: a callback field
   `onXyz`, a `_listen(channel, NetEvent.xyz, ...)` line, and a send helper
   if the others have one.
4. **TankGame**: wire `net.onXyz` to a handler `_onXyz` in `onLoad`
   (`lib/src/game/tank_game.dart`), write the handler in the extension of its
   topic under `lib/src/game/tank_game/` (`combat.dart`, `items.dart`,
   `defense.dart`, ...), and add the same case to the `switch` in
   `_playReplay` (`tank_game/replay.dart`), or the event is missing from
   replays.
5. **Authority**: decide who may send it (owner of the tank, the host in
   defense mode via `runsShooter` / host checks) and ignore it from anyone
   else. If it changes health, ammo or items, add a rule in
   `lib/src/game/plausibility.dart`.
6. **Traffic**: Realtime counts every message once sent and once per
   receiver, against 100 a second for the whole project on the free plan
   and a monthly quota (README, "Realtime limits"). Prefer events on change
   over per-frame messages; per-frame state goes in `state` (10/s), CPU
   tanks of the host in `states` (one message for all, 10/s). Nothing is
   sent while a client is alone in its room. Check a new stream with
   `test/net/message_budget_test.dart`.
7. **Tests**: round trip in `test/net/payloads/`, hostile input in
   `test/net/hostile_payload_test.dart`, game behaviour in `test/game/`
   with the fakes in `test/helpers/fakes.dart`.
8. **README**: add the event to the list in "How the netcode works".
