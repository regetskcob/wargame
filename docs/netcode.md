# Netcode and Realtime limits

How Panzergefecht plays multiplayer without a game server of its own: what
travels between clients, who is the authority over what, how a client guards
itself against made up messages, and how the game stays inside the message
limits of Supabase Realtime. Read it if you want to understand the
architecture, add a network event (see also the `/net-event` checklist in
[`.claude/skills/net-event/SKILL.md`](../.claude/skills/net-event/SKILL.md)),
or run your own copy on your own Supabase project.

Contents:

- [How the netcode works](#how-the-netcode-works)
  - [A round is a seed](#a-round-is-a-seed)
  - [Who is the authority](#who-is-the-authority)
  - [Channels](#channels)
  - [Events](#events)
- [Trust and identity](#trust-and-identity)
- [Hosts, presence and rooms](#hosts-presence-and-rooms)
- [Traffic per mode](#traffic-per-mode)
- [Phone controller](#phone-controller)
- [Recording rounds](#recording-rounds)
- [Replays](#replays)
- [Realtime limits](#realtime-limits)

## How the netcode works

There is no game server. Every client runs the full game, and the clients
talk to each other through Supabase Realtime Broadcast. Supabase also
provides the database functions that rank hosts, share the message budget
and record rounds.

```text
+------------------------- Supabase Realtime --------------------------+
|  game-arena-<room>   events + presence, one channel per room         |
|  game-rooms          presence of public rooms                        |
|  pad-<CODE>[-<id>]   phone controllers                               |
+--------------------^---------------------------------^---------------+
                     | broadcast + presence            |
          +----------+----------+           +----------+----------+
          | client A (host)     |           | client B            |
          | world from the seed |           | world from the seed |
          | own tank and shells |           | own tank and shells |
          | CPU tanks, waves,   |           |                     |
          | flags               |           |                     |
          +----------+----------+           +----------+----------+
                     | RPC                             | RPC
+--------------------v---------------------------------v---------------+
|                         Supabase Postgres                            |
|  enter_room, room_order    who hosts the room                        |
|  claim_load                shared Realtime budget                    |
|  start_round, record_round rating and experience                     |
|  ping_online               heartbeat                                 |
+----------------------------------------------------------------------+
```

### A round is a seed

A round is defined by `{seed, startedAt}`. Every client builds the same
world from the seed (terrain, weather, day or night, paratrooper waves) and
derives the round clock from the start time. The world costs no bandwidth;
only events travel. The host sends both values in `roundStart`.

### Who is the authority

The netcode is peer-authoritative:

- Every client simulates its own tank and its own shells, drones and
  grenades.
- The victim of a hit applies its own damage and then broadcasts the
  result. Each tank has exactly one authority, so there are no conflicts to
  resolve, and hits stay fair under lag because the victim works them out on
  its own side.
- The host runs everything nobody owns: CPU tanks, the enemy waves and the
  base in defense mode, and the flags in capture the flag.

### Channels

| Channel | Purpose | Code |
| --- | --- | --- |
| `game-arena-<room>` | Events and presence of one room | [`net_service.dart`](../lib/src/net/net_service.dart) |
| `game-rooms` | Public rooms announce themselves through presence and vanish when their host leaves | [`room_directory.dart`](../lib/src/net/room_directory.dart) |
| `pad-<CODE>` | Pairing a phone controller with a screen | [`pad_link.dart`](../lib/src/net/pad_link.dart) |
| `pad-<CODE>-<phone>` | One lane per phone for sticks and status | [`pad_link.dart`](../lib/src/net/pad_link.dart) |

A client alone in its room puts nothing on the channel. It still records
the round for its replay.

### Events

All events of a room are in
[`net_events.dart`](../lib/src/net/net_events.dart), their payloads in
[`lib/src/net/payloads/`](../lib/src/net/payloads/).

| Event | Sent by | What it says |
| --- | --- | --- |
| `state` | every player, 10 per second | Position, speed, turret and health of the own tank |
| `states` | host, 10 per second | All CPU tanks of the host in one message |
| `shoot` | owner of the gun | A shell left a barrel (tanks, guns, soldiers, aircraft) |
| `hit` | victim | Damage the victim applied to itself |
| `death` | victim | The tank is destroyed, with the start of its round |
| `roundStart` | host | Seed, start time and the tanks of the round |
| `pickup` | picker | A crate was picked up |
| `use` | user | A repair or rapid fire was used, so others believe what follows |
| `smoke` | user | A smoke screen |
| `mine` | layer | Mines laid behind a tank |
| `artillery` | caller | A barrage that lands at a given spot and time |
| `grenade` | owner | A grenade left the launcher and where it lands |
| `drone` | owner | Where the owner's drone flies |
| `blast` | owner | A special weapon went off |
| `obstacle` | shooter | New health of a building, barrier, tree or supply depot |
| `soldier` | killer | A soldier was run over or shot |
| `squad` | owner | A squad on foot was deployed (or dropped by parachute) |
| `squadOrder` | squad commander | A squad was sent after an enemy or back to patrolling |
| `air` | runner of the enemies | Where an enemy aircraft flies and its hit points |
| `defense` | host | Defense mode: base hit points, wave, growth, result |
| `tower` | builder; host for hit points | Defense mode: a gun went up, or its hit points |
| `troops` | player | Base duel: an extra enemy tank, run by the host |
| `flag` | host | Capture the flag: both flags and the score |
| `close` | host | The host closed the room |

A message about a player sent by somebody else (the host reporting what is
left of a builder's gun) names its sender in `from`, so the builder does not
drop it as its own echo.

## Trust and identity

Anybody with the project's public key can broadcast into any room. Every
client therefore checks what it receives in three layers.

### Plausibility checks

[`plausibility.dart`](../lib/src/game/plausibility.dart) checks what others
broadcast against what their tank can do:

- Shots faster than the gun reloads, or far from the tank, are dropped.
- Tanks faster than their top speed are held back.
- Health only rises after a repair crate.
- A tank last heard above 75 health cannot die from one message, so the
  victim sends the `hit` that brought it down before its `death`.
- Mines and barrages need a crate first.

Every limit leaves room for lag. This is a plausibility check, not an
anti-cheat.

### Flood and forgery guards

These came out of a penetration test (issue #12):

- [`InboundLimiter`](../lib/src/net/inbound_limiter.dart) lets each sender
  pass 40 messages a second per event (bursts of 80) and everybody together
  300 a second per event. Rare events have tighter caps for all senders
  together, for example `roundStart` and `close` 4 a second, `squad` and
  `troops` 10.
- A round start must lie within five minutes of the own clock and name at
  most 32 tanks.
- A `blast` needs the drone that went off; a grenade must leave its tank's
  barrel at the launcher's pace.
- Remote speeds and angles must be finite and below any tank's top speed.
  Remote tanks, aircraft, drones and guns per builder are capped.
- A `close` only counts once the host's presence is gone.
- Duel troops come at most one per sender every 0.8 seconds.
- Forged early join times rank last; call signs lose control and invisible
  characters.
- A death carries the start of its round, so a late one cannot knock a
  player out of a rematch.
- Between states a remote tank rolls on with its last speed for half a
  second at most, then stops: a player whose round ended sends nothing more.

### Signed messages

Since migration 0020 every game speaks with a key of its own
([`room_key.dart`](../lib/src/net/room_key.dart)), so nobody can speak for
somebody else, not even another player in the room.

1. A game makes an X25519 key pair when it starts. Its id is the first 16 hex
   digits of the SHA-256 of the public key. Its presence carries the key as
   `key`; a presence whose key does not hash to its id is dropped.
2. Every two games in a room agree on a secret from their keys, bound to the
   room.
3. Every message carries `mac`: the sender `s`, a running number `n` and a
   tag per receiver in `t`. A tag is an HMAC-SHA256, cut to 9 bytes, over
   the event, sender, number and every field. Fields are written the same
   way on every platform (keys sorted, numbers in thousandths), because a
   browser reads `1.0` as `1`.
4. A message in the name of a keyed player (`from`, else `id`) only counts
   with that player's tag and a number above the last one. A copied or
   changed message fails.
5. Messages about CPU tanks, the enemy and the infantry only count from
   whoever runs them; a round start only from the host.

Cost: about 15 ms to make a key and agree on secrets in the apps, about
100 ms in a browser; a tag takes 0.07 ms (0.2 ms in a browser). A message
grows by about 30 bytes per receiver. The watch plays without a room and has
no key. Builds from before keys play on unsigned; only messages in their own
name, or for their own CPU tanks, count unsigned.

Channels stay public. Private channels with Realtime Authorization would only
keep out clients without a session, and anybody gets a guest session; the
tags already keep everybody to their own name.

## Hosts, presence and rooms

### Who hosts a room

Who leads the room comes from the server, not from presences, which anybody
can write. Every game enters its key with `enter_room` when it joins and
reads `room_order`: the keys of the room with the server's time of arrival
(migration 0020). The account that enters a room first owns it; a reload
with a new key keeps that.

Every client ranks the pilots the same way
([`host_rank.dart`](../lib/src/net/host_rank.dart)):

1. the owner by the server,
2. in rooms opened by builds without keys (no owner on the server), whoever
   claims to own it,
3. keys the server knows, by arrival,
4. keys the server does not know (the second player on one screen has no
   session), by claimed arrival,
5. players of builds without keys, by claimed arrival.

The first in the ranking hosts the room after three seconds
(`GameConfig.hostSettleSeconds`): it closes the room, starts rounds, and
runs flags and waves. The ranking also settles a doubled host and decides
who stays when too many come. Until the server answers (offline, or in tests
without keys) the presences decide: the owner who opened the room beats a
stand-in, and between two stand-ins, or two owners (one browser with the
room open in two tabs), the smaller id wins.

A player who drops out of the presence during a round (a phone switching
networks) keeps tank, guns and, as host, the waves for six seconds
(`GameConfig.peerLeftGrace`). Only who is still gone then counts as left.

### Presence

Presence powers the lobby roster, disconnect handling and match discovery.
Players in a match advertise the seed so late joiners can spectate. The host
also announces its mode (`mode`) and settings (`level`, `map` with -1 for a
random terrain, `teams`), so a guest's waiting room shows what will be
played. The fields are in
[`lobby_presence.dart`](../lib/src/net/payloads/lobby_presence.dart).

Presence updates are spaced out to at most four per channel in 30 seconds
([`presence_throttle.dart`](../lib/src/net/presence_throttle.dart)). Faster
changes wait and only the latest goes out. The count belongs to the
channel's topic, not to one channel object: a rejoin opens a new channel,
and its first track once came on top of the updates just before the drop,
which closed the channel with `ClientPresenceRateLimitReached`.

### Content level

A round is its seed, and older clients read the map out of it as `seed % 4`
and the defense layout as `(seed ~/ 4) % 4`. Newer maps and layouts are
marked in higher bits (`MapTheme.indexOf`, `DefenseMap.layoutFor`), which
older clients ignore, so they would play on another field.

Every presence therefore says how far its client goes (`content`,
`GameConfig.contentLevel`, currently 1: the mountain forest, the islands,
the defense layouts riverbank and hairpin, and the Igel). The host only rolls
the newer content when everybody in the room has at least that level
(`roomContent`). Raise the level with the next content that older clients
would read differently out of a seed.

A pilot's vehicle needs no gate: its index wraps round on an older client,
which draws the Igel as a Keiler. Enemies of a defense round do need one,
because every client works out each enemy's vehicle from the wave: the host
marks the seed of a room that knows content 1 one bit higher still
(`DefenseMap.freshRoom`), and only such rounds send the Igel in.

### Room size and the shared budget

A room holds `MAX_PILOTS` pilots (four by default), spectators included.
Every client keeps the first by the ranking; whoever comes later sees that
the room is full and leaves.

Rooms and phone controllers share the project's Realtime budget,
`REALTIME_BUDGET` messages a second (400 by default), through the
`claim_load` database function ([`room_slots.dart`](../lib/src/db/room_slots.dart),
migrations 0015 and 0016):

- A room takes a slot with its load as soon as a second pilot is in it; a
  screen with paired phones takes one for them.
- Everybody in the room refreshes the slot once a minute. A silent slot runs
  out after two and a half minutes.
- Only the pilot who claimed a slot may lower its load (migration 0019); the
  others may only raise it within the budget. When the claimer has not
  refreshed for two and a half minutes, the next pilot who refreshes takes
  the slot over.
- The server caps a room at 400 and a phone slot at 160 messages a second,
  and uses the smaller of the build's budget and `realtime_budget` in
  `private.settings` (400, set by SQL when the plan changes; migration 0018).
- Whoever comes into a room that no longer fits sees that all rooms are
  taken and leaves; the owner stays and waits. Phones that do not fit wait
  and steer nothing.
- A room with a phone in it plays without CPU tanks filling it up.

The numbers are in [Rooms and room sizes](#rooms-and-room-sizes). Without
a server the game still starts, see
[Running without the server](#running-without-the-server).

## Traffic per mode

### Squads on foot

Patrolling soldiers cost nothing on the wire. A squad off the road walks a
round of four points about where it stands, from its key and the round
clock (`SquadRoute`). Its commander (the owner; the host for CPU tanks and
the enemy; the infantry host for red and blue) sends a `squadOrder` only
when it sends the squad after an enemy within 520, or back to patrolling
6 seconds after losing it. Orders go out at most every 2.5 seconds per
squad and only when the spot moved more than 60.

Every client walks the squad from the same orders. Orders from anybody but
the commander, or more than 10 seconds off the own clock, are dropped. A
client that joins late sees the squad where the next order puts it.

### Defense mode

The players hold a base together on a fixed map without the closing zone.
The host runs the enemy waves like CPU tanks and is the authority over the
base:

- `defense` carries the base's hit points, the wave, the result, how far
  the base has grown and, once extended, the last wave of the extension
  (`until`).
- Guns go up with `tower`. Only their builder aims and fires them, so their
  shots are ordinary `shoot` events. The host keeps the guns' hit points and
  sends them with `tower` after every hit.

When the host leaves for good (still gone after the grace), the first by the
ranking of those still in the round takes over the waves
(`TankGame.nextBotHost`). Every client switches by itself; nothing extra
goes over the wire. The new host:

- turns the enemies and comrades it saw as remote tanks into its own CPU
  tanks where they were last seen,
- starts a director from the last `defense` state it heard (wave, break,
  base, growth, extension),
- sends the rest of the wave under unit numbers not yet used,
- aims and fires the old host's guns in their owner's name.

Aircraft and drones of the old host are dropped; they only flew on its
screen. Funds are every player's own and stay as they are. From then on
`defense`, `states`, `air`, wave squads and the guns' hit points count only
from the new host. A host that comes back takes the waves back and the
stand-in drops its director and units.

### Capture the flag

The host is the authority over the flags
([`flag_match.dart`](../lib/src/game/flag_match.dart)). It sees every tank
through the `state` and `states` it receives anyway, so nobody sends
anything extra to pick up a flag. The host notices who touches which flag,
who dropped it by being destroyed and who brought it home, and broadcasts
both flags and the score as `flag` whenever they change and every 5 seconds
(`GameConfig.flagSyncSeconds`), so a lost message or a late spectator
catches up. That is a few messages a minute.

Every client ends the round itself from the score and the round clock.
Destroyed tanks come back at their base and announce themselves with their
next `state`; one that arrives shortly after a death is ignored, so a late
message does not bring a wreck back.

When the host leaves, the next by the ranking takes over from the last state
they heard. A host that comes back (for example after the project went over
its message limit and every channel dropped) and ranks first takes the flags
back with its own state. After the round the flag host repeats the final
score for 45 seconds (`GameConfig.outageGrace`), so a last capture made
while its channel was down still ends the round for the others.

The crew of three CPU tanks a side costs more than a battle's CPU tanks, so
a flag room counts 19 instead of 13 messages a second per pilot for them
(`GameConfig.roomLoad`).

## Phone controller

A phone pairs with a screen on `pad-<CODE>`, with an eight character code
from the screen's QR code ([`pad_link.dart`](../lib/src/net/pad_link.dart)).

- The phone sends its sticks as `pad` at most every 80 ms, rounded so a
  resting thumb's tremor is no change, and single presses as `act`.
- The screen plays them as its touch controls and answers with `status`
  (health, ammunition, fuel, items, phase and, in defense mode, the shop
  with its prices and what the funds allow) at most every 250 ms.
- The defense shop's presses (`place`, `raise`, `upgrade`, `wave`, `extend`,
  `end`) are kinds of `act`, which an older screen drops.
- Sticks and status run on a lane per phone, `pad-<CODE>-<phone>`, so in a
  duel no phone hears the other. Ends from before lanes stay on the shared
  channel.
- Presence shows either end whether the other is there. The first phone
  steers; when it falls silent for a moment the tank lets go.
- The room never sees the phone. The pairing code is kept for the browser
  tab, so a new room keeps the phone.

## Recording rounds

Ratings and experience only change through database functions, never by
writing tables directly (row level security is hardened in migrations 0011
and 0012; guests are not rated).

1. When a round starts, the client calls `start_round` (migration 0019). It
   returns a ticket bound to the account and the server's clock, naming how
   many CPU tanks are in the round (at most four).
2. At the end, every player records their own round with `record_round`,
   handing in the ticket as `p_ticket`.

`record_round`:

- clamps every number, grants experience (10 per opponent outlasted since
  migration 0017; extra waves of an extended defense round since migration
  0022) and moves the Elo rating against the opponents the player outlasted
  or fell before,
- keeps the round in `round_results` for the wins per vehicle behind a
  badge,
- only counts opponents whose game sent a heartbeat in the last five minutes
  (`ping_online`, once a minute), records at most 300 rounds a day per
  pilot, and gives badges the server's time (migration 0018),
- caps survival, kills, damage and shots by the time from the ticket until
  the recording or the pilot's next ticket, whichever comes first, so rounds
  never overlap. CPU tanks count up to the number on the ticket, one per
  five seconds, and a round under five seconds earns only the ten points
  for taking part. A ticket used twice is refused.

Tickets stay valid for a day, so a round the watch keeps in `PendingRounds`
still counts with its own time. A round without a valid ticket (old store
builds, a watch round started without a usable phone token, a foreign or
expired ticket) still counts, but CPU tanks give neither rating nor
experience, a win only counts with a rated human outlasted, and kills and
damage are capped at a fifth of the ticket rate. The client falls back to
the older signature on a database without the newer migrations
([`score_service.dart`](../lib/src/db/score_service.dart)).

The leaderboard is read with a plain query and refreshed every 30 seconds.

## Replays

Replays need no extra traffic
([`replay.dart`](../lib/src/net/replay.dart)). The client keeps every
message of the round with its time. Since the world follows from the seed,
playing the messages back into a round that starts now shows the round
again. To bound memory in long defense sessions, positions (`state`,
`states`) are thinned to one every half second per sender after 20,000
messages, and recording stops at 60,000. Shots, hits and deaths are never
thinned. Replays stay on the device.

## Realtime limits

Supabase Realtime limits are the bottleneck of the multiplayer. This section
started from the Supabase logs of 8 October 2026 and records what changed
because of them. The loads are measured by the budget tests, see
[Development](development.md#tests).

### How Realtime counts

- **Messages per second** (free plan 100, Pro 500) count for the whole
  project, averaged over a minute. A broadcast counts once when a client
  sends it and once more for every client it is delivered to. A room of
  *n* pilots therefore costs *n* times what its pilots send together: the
  load grows with the square of the room.
- **Above the limit** Realtime closes **every channel of the project**, all
  rooms at once, with "Too many messages per second". Clients reconnect
  after two seconds, then wait twice as long after every further drop, up to
  30 seconds ([`retry_backoff.dart`](../lib/src/net/retry_backoff.dart)),
  so a project over its limit is not kept there by everybody knocking every
  two seconds. Realtime still lets every join through and closes it again
  at once, so only a channel that stayed up for ten seconds starts over at
  the short wait.
- **Messages per month**, counted the same way: 2 million on the free plan
  (then a grace period and restrictions), 5 million on Pro ($25 a month,
  then $2.50 per further million).
- **Presence per client**: at most five tracks or untracks in 30 seconds on
  one channel; one more and Realtime closes that channel
  (`ClientPresenceRateLimitReached`).

Sources: [Realtime limits](https://supabase.com/docs/guides/realtime/limits),
[ClientPresenceRateLimitReached](https://supabase.com/docs/guides/troubleshooting/realtime-client-presence-rate-limit-reached),
[Manage Realtime Messages usage](https://supabase.com/docs/guides/platform/manage-your-usage/realtime-messages)
and the `supabase/realtime` source, as of October 2026.

### Flood behaviour (measured locally)

Measured on 11 October 2026 against the local stack (`supabase start`,
tenant `realtime-dev`), with raw Phoenix clients and with real web builds
driven in headless Chrome. The hosted numbers are those of the Supabase
docs, not measured.

| Limit | Local `realtime-dev` | Hosted Free | Hosted Pro |
| --- | ---: | ---: | ---: |
| Concurrent connections | 200 | 200 | 500 |
| Messages per second (sent + delivered) | 100 | 100 | 500 |
| Channel joins per second | 100 | 100 | 500 |
| Channels per connection | 100 | 100 | 100 |
| Presence messages per second | 1000 | 20 | 50 |
| Broadcast payload | 3000 KB | 256 KB | 3000 KB |

- **Over the message limit** Realtime answers every channel of the tenant
  that sends, joins or tracks with the system message `Too many messages
  per second` and a `phx_close`, in every room, not only the flooder's. A
  silent channel (a player alone in a room) is only closed when it next
  acts.
- **Recovery** takes about 10 seconds after a pure flood ends. With a game
  running next to it the rate is averaged, so the closes go on as long as
  the game's own traffic and the rejoins keep it near the limit (up to 40
  seconds after the flood below).
- **Oversized messages**: above 3 MB a broadcast is dropped silently; at
  8 MB the server closes the sender's socket with code 1009.
- **100 channels per socket**; the per-client presence limit is not
  enforced on a self-hosted stack.

**Scenario:** two web clients in a defense round (waves 1 to 2, about 75 to
105 messages a second on their own, close to the local and free limit by
itself), and a flooder sending 300 a second from another room for 20
seconds:

| | Before the fixes | After |
| --- | --- | --- |
| First close | 20 s into the flood, when the one-minute average passed 100 | the same |
| Rejoins of the host | 4 (2, 4, 8, 16 s), back 46 s after the flood | 5 (2, 4, 8, 16, 30 s), back 71 s after |
| Rejoins of the guest | 3 (2, 4, 8 s), back 29 s after | 2 (2, 4 s), back 13 s after, one more drop later |
| Who ran the waves | **both**: the guest counted the host as gone after 6 s and took over, the host ran on, with a base each (1054 and 1229 hit points) | the host alone, both screens the same (wave 2, 972 hit points) |

Two fixes came out of it. A game whose own channel dropped in the last 45
seconds counts missing players as away, not gone
(`GameConfig.outageGrace`). A defense host who comes back after a stand-in
took over gets the waves back.

A capture the flag round of three people with CPU tanks (3 against 3) went
over the local limit of 100 on its own and split: the host ended it at 0:3
while its channel was down, one guest won 0:2 as a stand-in and the other
played on. Since then a returning flag host takes the flags back and
repeats the final score after the round
([`flag_takeover_test.dart`](../test/game/flag_takeover_test.dart)), and a
defense room counts 30 more messages a second per pilot for its waves
(`GameConfig.roomLoad`).

### What keeps the load down

Measured by [`message_budget_test.dart`](../test/net/message_budget_test.dart)
and [`pad_budget_test.dart`](../test/net/pad_budget_test.dart): a 20 second
round on a real `TankGame`, the own tank always driving, turning its turret
and firing, sent plus delivered.

| Load of one room | Before | After |
| --- | ---: | ---: |
| Solo with CPU tanks | ~107/s | 0 |
| 2 pilots | ~83/s | ~44/s |
| 2 pilots with CPU tanks | ~216/s | ~70/s |
| 3 pilots | ~186/s | ~98/s |
| 3 pilots with CPU tanks | ~386/s | ~138/s |
| 4 pilots | ~331/s | ~174/s |
| 4 pilots with CPU tanks | ~597/s | ~227/s |
| Phone controller, thumbs moving | ~60/s | ~32/s |
| Apple TV duel with two phones | ~95/s | ~63/s |

1. **Nothing is sent when nobody listens.** A client alone in its room puts
   nothing on the channel.
2. **Ten states a second instead of twenty**
   (`GameConfig.stateSyncInterval`). Remote tanks move on with their speed
   between states (dead reckoning).
3. **CPU tanks in one message.** The host sends all its CPU tanks together
   as `states`, ten times a second. Their shots still go out one by one.
4. **Presence is throttled** to four updates per channel in 30 seconds; the
   last one always arrives.
5. **Rooms hold `MAX_PILOTS` pilots**, four on Pro, two on the free plan.
   Eight would need about 800 a second, more than Pro allows.
6. **The phone controller is spaced out.** Sticks at most every 80 ms,
   status at most every 250 ms. Items and building go out at once.
7. **Rooms and phones share a budget** through `claim_load` (`RoomSlots`);
   a new one only gets in while all of them stay within `REALTIME_BUDGET`.
8. **A phone makes room for itself.** A room with a phone controller plays
   without CPU tanks filling it up (except in defense mode, where the
   enemies are CPU tanks).
9. **A lane per phone**, so in an Apple TV duel neither phone hears the
   other.

### Rooms and room sizes

Messages per second decide how many rooms play **at the same time**,
messages per month how much **playing time** there is in all. The build sets
the room size and the shared budget, keeping a fifth of the plan in reserve:

| Plan | `MAX_PILOTS` | `REALTIME_BUDGET` | Carries, for example |
| --- | ---: | ---: | --- |
| Pro (default; the hosted project is on Pro since October 2026) | 4 | 400 | a room of four and two rooms of two, or five rooms of two |
| Pro, many small rooms | 2 | 400 | five rooms of two with CPU tanks |
| Free | 2 | 80 | one room of two, or a room of two and a phone |

Both are `--dart-define` flags
([`env.dart`](../lib/src/app/env.dart)). The `pages` workflow passes them to
the web build from repository variables of the same name. The store builds
are made locally (`tool/archive_ios.sh`, `tool/archive_apple.sh`,
`tool/release_android.sh`) with the defaults, so add the same
`--dart-define`s there when the plan changes. Build every client of one
release with the same values. A fork on the free plan builds with
`MAX_PILOTS=2` and `REALTIME_BUDGET=80`, and sets `realtime_budget` in
`private.settings` to match.

Rooms count with their CPU tanks unless a phone is in them, as only the host
knows whether it fills up (`GameConfig.roomLoad`, `GameConfig.padLoad`).
Solo rounds and two players on one screen cost nothing and always fit.

**On Pro** (400 a second):

| At the same time | Counted load | |
| --- | ---: | --- |
| One room of 4 pilots | ~228/s | fits |
| A room of 4 and two rooms of 2 | ~368/s | fits |
| A room of 4 and a room of 3 | ~366/s | fits |
| Five rooms of 2 | ~350/s | fits |
| A room of 4, a room of 2 and a phone controller | ~330/s | fits |
| Two rooms of 4 | ~456/s | the second is turned away |
| Six rooms of 2 | ~420/s | the sixth is turned away |

**On the free plan** (80 a second):

| At the same time | Counted load | |
| --- | ---: | --- |
| One room of 2 pilots with CPU tanks | ~70/s | fits |
| One room of 2 pilots and a phone controller | ~76/s | fits, the room plays without CPU tanks |
| Two players on one screen, each on a phone | ~64/s | fits while no room plays |
| Two rooms of 2 pilots | ~140/s | the second is turned away |
| A room of 2 pilots and somebody else's phone | ~102/s | the phone waits |

**Playing time per month**, shared by all rooms of the project:

| Room | Messages an hour | Free (2 million) | Pro, included (5 million) | Pro, each hour beyond |
| --- | ---: | ---: | ---: | ---: |
| 2 pilots | ~160,000 | ~12 h | ~31 h | ~$0.40 |
| 2 pilots with CPU tanks | ~250,000 | ~8 h | ~20 h | ~$0.63 |
| 3 pilots with CPU tanks | ~500,000 | ~4 h | ~10 h | ~$1.24 |
| 4 pilots with CPU tanks | ~820,000 | ~2.5 h | ~6 h | ~$2.04 |
| Phone controller, on top | ~115,000 | ~17 h | ~43 h | ~$0.29 |

On Pro the **spend cap** (Organization, Billing, Cost Control) decides what
happens past the quota: on, Realtime is blocked for the rest of the month;
off, every further million costs $2.50. A free project past its grace period
may get `402` on **every** API request, Auth and database included. Either
way single player keeps working.

In short: **the free plan carries one small room at a time and a few
evenings a month; rooms of four or several rooms at once need Pro**, and on
Pro the playing time is what costs money, not the number of rooms.

### Running without the server

The game does not depend on the server to start
([`server_status.dart`](../lib/src/db/server_status.dart)). A failed sign-in
only marks the server as away; the heartbeat (`ping_online`, once a minute
while the app is in front) asks again and keeps `ServerStatus.available` up
to date. While the server is away, the start page and the waiting room say
so, multiplayer and the room list are greyed out, and single player and
defense on one's own go on, unrecorded.

### What players notice

- **The room limit**: one pilot too many reads "Der Raum ist voll:
  höchstens 4 Piloten." ("The room is full") and leaves; the room list shows
  full rooms as `VOLL`. Spectators count as pilots.
- **All rooms taken**: the start page says the server carries no more right
  now, the multiplayer card reads `ALLE RÄUME BELEGT`, rooms in the list
  read `BELEGT`. A slot comes free up to two and a half minutes after its
  room ended.
- **Phones that have to wait**: the pairing says so; the phone steers once
  there is room. Controllers, keyboard and touch always work.
- **The phone controller**: about 40 ms, at most 80 ms more delay on the
  sticks, and a tap on the aim stick shorter than 80 ms can go unnoticed.
- **Other tanks**: on sharp turns or full braking a remote tank can slide on
  a few pixels and pull back.
- **Presence**: after four changes within 30 seconds the others see only the
  latest, up to 30 seconds later.

The rates are constants in `GameConfig` and `pad_link.dart`, and the budget
tests show at once whether a change still fits the plan. Not yet tried by
hand: a round on two devices with sharp manoeuvres, and a round with the
phone controller.

### Still open

- Rooms bigger than four would need a relay of our own instead of Broadcast.
- The loads in the budget are estimates from the budget tests
  (`GameConfig.roomLoad`, `GameConfig.padLoad`), not live counts. Shots,
  hits and other events are not counted against the budget yet.
- Clients from before migrations 0015 and 0016 take no slot or count as a
  room of two with CPU tanks, and know neither the room limit nor the lanes.
  Web and app builds should go out together.
- A player of a build without keys can still be posed as, and a room opened
  by such a build still trusts claims to own it.
- Any client can flood the project above its message limit, which closes
  every room (see [Flood behaviour](#flood-behaviour-measured-locally)); only
  Supabase can stop that.
- A defense host's takeover rebuilds what the old host kept to itself only
  roughly: the clean waves towards the next base level follow from the level,
  the base's hit points at the start of the wave are those at the takeover,
  and a jet of the base still to come in that wave stays away. Clients whose
  roster differs at the end of the grace could pick different hosts for a
  moment. A host that comes back takes the waves back, but what the
  stand-in's waves left (squads, dug-in enemy guns) stays on its screen only.
  Replays of a defense round do not show the waves.
- Maintainer, on Pro: decide on the spend cap and look at the usage once a
  month.
