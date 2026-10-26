# Netcode and Realtime limits

## How the netcode works

- One Realtime channel per room carries the broadcast events `state`,
  `states`, `shoot`, `hit`, `death`, `roundStart`, `pickup`, `smoke`, `obstacle`,
  `soldier`, `mine`, `artillery`, `grenade`, `drone`, `blast`,
  `defense`, `tower`, `troops` (a duel's extra tank, sent by a player and run
  by the host), `flag` (capture the flag, see below), `squadOrder` (see
  below) and `close`.
- Soldiers on foot cost nothing on the wire while they patrol: a squad off
  the road walks a round of four points about where it stands, from its key
  and the round clock (`SquadRoute`). Only when its commander (the owner,
  the host for CPU tanks and the enemy, the infantry host for red and blue)
  sends it after an enemy within 520, or back to patrolling 6 s after losing
  it, does a `squadOrder` go out: the squad, the time and the spot, at most
  every 2.5 s per squad and only when the spot moved more than 60. Every
  client walks the squad from the same orders; orders from anybody but the
  commander, or more than 10 s off the own clock, are dropped. A client
  that joins late misses earlier orders and sees the squad where the next
  one puts it.
- The netcode is peer-authoritative: every client simulates its own player and
  bullets, and the victim of a hit applies its own damage before broadcasting
  the result. Each player has exactly one authority, so there are no conflicts.
- Every client checks what the others broadcast against what their tank can
  do (`plausibility.dart`): shots faster than the gun reloads or far from the
  tank are dropped, tanks faster than their top speed are held back, health
  only rises after a repair crate, a tank at high health cannot die from one
  message, and mines and barrages need a crate first. This is a plausibility
  check, not an anti-cheat.
- Anybody with the public key can broadcast into any room, so every client
  also guards itself against floods and made up messages (penetration test
  of issue #12): `InboundLimiter` lets each sender 40 messages a second per
  kind (80 at once) and everybody together 300 a second per kind, much less
  for rare kinds such as `squad`, `roundStart` or `close`; a round start must
  lie within five minutes of the own clock and name at most 32 tanks; a
  `blast` needs the drone that went off, a grenade must leave its tank's
  barrel at the launcher's pace; remote speeds and angles stay finite and
  below any tank's top speed; remote tanks, aircraft, drones and guns per
  builder are capped; a `close` only counts once the host's presence is
  gone; duel troops come at most one per sender every 0.8 seconds; forged
  early join times rank last; call signs lose control and invisible
  characters. A message about a player sent by somebody else (the host
  reporting what is left of a builder's gun) names its sender in `from`, so
  the builder does not drop it as its own echo. Deaths carry the start of
  their round, so a late one cannot knock a player out of a rematch.
- Every game speaks with a key of its own (`room_key.dart`, migration 0020),
  so nobody can speak for somebody else, not even another player in the
  room. A game makes an X25519 key pair when it starts; its id is the
  start of the SHA-256 of the public key (16 hex digits, as long as the
  random ids before), and its presence carries the key as `key`. A
  presence whose key is not its id's, or one without a key for an id that
  has one, is dropped. Every two games in a room agree on a secret from
  their keys, and every message carries `mac`: the sender `s`, a running
  number `n` and a tag `t` per receiver, an HMAC-SHA256 cut to 9 bytes over
  the event, sender, number and every field, written the same way on every
  platform (keys sorted, numbers in thousandths, since a browser reads
  `1.0` as `1`). A message in the name of a player with a key (`from`, else
  `id`) only counts with that player's tag and a number above the last
  one, so a copied or changed message does not either. Messages about CPU
  tanks, the enemy and the infantry only count from whoever runs them, a
  round start only from the host. A key costs ~15 ms to make and agree on
  in the apps and ~100 ms in a browser, a tag 0.07 ms (0.2 ms in a browser);
  a message grows by about 30 bytes per receiver. The watch plays without a
  room and has no key; games of builds before keys play on with unsigned
  messages, and only messages in their own name or for CPU tanks of such a
  runner count unsigned.
- Who leads the room comes from the server, not from the presences, which
  anybody can write: every game enters its key with `enter_room` when it
  joins (the account that enters a room first as its owner owns it, a
  reload with a new key keeps it) and reads `room_order`, the keys of the
  room with the server's time of arrival. Every client ranks the pilots the
  same way (`host_rank.dart`): the owner by the server, then (only in rooms
  of older builds, which have no owner on the server) whoever claims to
  own it, then keys by when the server saw them, then keys the server does
  not know (the second player on a screen has no session) and last the
  players of older builds, both by the time they claim. The first hosts the
  room after three seconds, closes it, starts rounds, and whoever ranks
  first among those still there takes over flags and waves; the ranking
  also decides who stays when too many come. Until the server answered,
  offline and in tests without keys the presences settle it as before.
- A player who drops out of the presence during a round (a phone switching
  networks) keeps tank, guns and, as host, the waves for six seconds
  (`GameConfig.peerLeftGrace`); only who is still gone then counts as left.
- A round is defined by `{seed, startedAt}`: every client generates an
  identical world from the seed and derives the round clock from the start
  time. The world costs zero bandwidth.
- Tank state goes out ten times a second and remote players smooth over the
  gaps with dead reckoning. The host sends the states of all its CPU tanks
  together as one `states` message. A client alone in its room sends
  nothing at all. See [Realtime limits](#realtime-limits).
- A room holds `MAX_PILOTS` pilots (four by default), spectators included.
  Every client keeps the first by the ranking above (before the server
  answered: the owner and then the earliest arrivals by their presences),
  and whoever comes later sees that the room is full and leaves.
- Rooms and phone controllers share the project's Realtime budget,
  `REALTIME_BUDGET` messages a second (400 by default). A room takes a slot
  with its load through the `claim_load` database function as soon as a
  second pilot is in it, a screen with paired phones takes one for them,
  and everybody refreshes once a minute; a silent slot runs out after two
  and a half minutes. Only the pilot who claimed a slot may lower its load
  (migration 0019); the others refresh it and may raise it within the
  budget. When the claimer has not refreshed for two and a half minutes,
  the next pilot who refreshes (the stand-in host or anybody left in the
  room) takes the slot over and may lower it from then on. Who comes into a room that does not fit any more
  sees that all rooms are taken and leaves; the owner stays and waits.
  Phones that do not fit wait and steer nothing. A room with a phone in it
  plays without CPU tanks filling it up. See
  [Rooms and room sizes](#rooms-and-room-sizes).
- Without a server the game still starts; single player goes on, and the
  heartbeat notices when the server is back. See
  [Running without the server](#running-without-the-server).
- Presence updates are spaced out to at most four per channel in 30 seconds
  (`presence_throttle.dart`); faster changes wait and only the latest goes
  out. The count belongs to the channel's topic, not to one channel object:
  a rejoin opens a new channel, and its first track used to come on top of
  the updates just before the drop, which once closed the channel with
  `ClientPresenceRateLimitReached` (22 October 2026).
- Presence powers the lobby roster, disconnect handling, and match discovery:
  players in a match advertise the seed so late joiners can spectate. The
  host also names the way to play it picked (`mode`) and its settings
  (`level`, `map` with -1 for a random terrain, `teams`), so a guest's
  waiting room describes the host's mode and shows what will be played
  before the round brings it. Older hosts send neither; their guests show
  no settings line.
- **Content level.** A round is its seed, and older clients read the map
  out of it as `seed % 4` and the defense layout as `(seed ~/ 4) % 4`.
  Newer maps and layouts are marked in higher bits (`MapTheme.indexOf`,
  `DefenseMap.layoutFor`: a mark of 6 or 7 above the sky's bits picks
  them), which older clients ignore, so they would play on another field.
  Every presence therefore says how far its client goes (`content`,
  `GameConfig.contentLevel`, 1 since the mountain forest, the islands, the
  layouts riverbank and hairpin and the Igel), and the host only rolls the
  newer ones when everybody in the room has at least that (`roomContent`).
  A pilot's vehicle needs no gate: its index sits at the end, and an older
  client draws an unknown one as the Keiler. Enemies of a defense round
  do, as every client works out each enemy's vehicle from the wave: the
  host marks the seed of a room that knows content 1 one bit higher still
  (`DefenseMap.freshRoom`), and only such rounds send the Igel in.
- One host per room: a doubled host settles after three seconds, by the
  ranking above. Before the server answered, the owner (who opened the
  room) keeps the role against a stand-in, two stand-ins leave it to the
  smaller id, and so do two owners, which happens when one browser opens
  the room in a second tab (both remember having opened it).
- In the defense mode the players hold a base together on a fixed map without
  the closing zone. The host runs the enemy waves like CPU tanks and is the
  authority over the base: it broadcasts the base's hit points, the wave and
  the result as `defense`, along with how far the base has grown and, once
  extended, the last wave of the extension (`until`; a client that gets an
  extension without it, from an older host, lets the waves run on). Guns go up
  with `tower`, and only their builder aims and fires them, so their shots
  travel as ordinary `shoot` events. The host also keeps the guns' hit
  points and sends them with `tower` after every hit; at nothing the gun is
  gone on every client.
- When the host of a defense leaves for good (still gone after the grace),
  the next player in line takes over the waves, by the same rule as the
  flags: the first by the ranking above of the people still in the round
  and the room, the smallest id while the server has not answered
  (`TankGame.nextBotHost`). Every client switches by itself, nothing extra
  goes over the wire. The new host turns the enemies and comrades it saw
  as remote tanks into its own CPU tanks where they were last seen, starts
  a director from the last `defense` state it heard (wave, break, base,
  growth, extension) and sends the rest of the wave under unit numbers not
  yet used, counted from the ids it knows. Aircraft and drones of the old
  host are dropped, they only flew on its screen. The old host's guns stay,
  the base's own among them, and the new host aims and fires them in their
  owner's name. Funds are every player's own and stay as they are. From
  then on `defense`, `states`, `air`, wave squads and the guns' hit points
  count only from the new host, so an old host that comes back after the
  grace plays on in a world of its own without touching the others'. A
  player left alone with the host goes on alone and sends nothing.
- In capture the flag the host is the authority over the flags. It sees
  every tank through the `state` and `states` it receives anyway, so
  nobody sends anything extra to pick up a flag: the host notices who
  touches which flag, who dropped it by being destroyed and who brought it
  home, and broadcasts the whole state of both flags and the score as
  `flag` whenever it changes, and again every 5 seconds so a lost message
  or a late spectator catches up. That is a few messages a minute. Every
  client ends the round itself from the score and the round clock. When
  the host leaves, the next player in line (by the ranking above) takes over from
  the last state they heard. A host that comes back (everybody dropped
  at once when the project went over its message limit) and ranks first
  takes the flags back with its own state, and a player counted as gone
  who is back in the room comes back with their next `state`. After the
  round the flag host repeats the final score for 45 seconds, so a last
  capture made while its channel was down still ends the round for the
  others. Destroyed tanks come back at their base and
  announce themselves with their next `state`; one that arrives shortly
  after a death is ignored, so a late message does not bring a wreck back.
  The bigger CPU crew of three a side costs more than a battle's, so a
  flag room claims 19 instead of 13 a second for its CPU tanks.
- Every player records their round through the `record_round` database
  function. It clamps the numbers, grants experience (10 more per opponent
  outlasted since migration 0017) and moves the Elo rating against the
  opponents the player outlasted or fell before, and keeps the round in
  `round_results` for the wins per vehicle behind a badge. Since migration
  0018 only opponents whose game sent a heartbeat in the last five minutes
  count, kills and damage are capped by the time since the pilot's last
  round, a pilot records at most 300 rounds a day, badges get the server's
  time and call signs lose invisible characters. Since migration 0019 every
  round starts with `start_round`, which returns a ticket bound to the
  account and the server's clock; `record_round` takes it once
  (`p_ticket`) and caps survival, kills, damage and shots by the time from
  the ticket until the recording or the pilot's next ticket, whichever
  comes first, so rounds never overlap. CPU tanks count up to the number
  the ticket names (at most four), one per five seconds, and a round under
  five seconds earns only the ten points for taking part. Tickets stay
  valid for a day, so a round the watch keeps in `PendingRounds` still
  counts with its own time. A round without a valid ticket (store builds
  from before, a watch round started without a usable phone token, a
  foreign or expired ticket) still counts, but CPU tanks give neither
  rating nor experience, a win only counts with a rated human outlasted,
  and kills and damage are capped at a fifth of the ticket rate over the
  time since the last round. A ticket used twice is refused. The client
  falls back to the old call on a database without the migration.
  `claim_load` caps a room at
  400 and a phone slot at 160 messages a second, ignores `p_force` and
  takes the smaller of the build's budget and the one in
  `private.settings` (`realtime_budget`, 400 for the Pro plan; set it with
  SQL when the plan changes). The
  all time leaderboard is a typed Postgres Changes stream on `scores`.
- Replays need no extra traffic: the client keeps every message of the round
  with its time, and since the world follows from the seed, playing them back
  into a round that starts now shows the round again. To bound memory in long
  defense sessions, positions (`state`, `states`) are thinned to one every
  half second per sender after 20 000 messages, and recording stops at
  60 000; shots, hits and deaths are never thinned.
- Public rooms announce themselves through Presence on a separate
  `game-rooms` channel and vanish when their host leaves.
- A phone controller pairs on a channel of its own, `pad-<CODE>`, with an
  eight character code from the screen's QR code. The phone sends its
  sticks as `pad` at most twelve and a half times a second, rounded so a
  resting thumb's tremor is no change, and single presses as `act`; the
  screen plays them as its touch controls and answers with `status`
  (health, ammunition, fuel, items, phase and, in defense, the shop with its
  prices and what the funds allow) at most about three times a second.
  The presses of the defense shop (`place`, `raise`, `upgrade`, `wave`,
  `extend`, `end`) are new kinds of `act`, which an older screen drops.
  Sticks and status run on a lane per phone, `pad-<CODE>-<phone>`, so in a
  duel no phone hears the other; ends from before lanes stay on the shared
  channel. Presence shows either end whether the other is there; the first phone steers, and when it falls silent for a
  moment the tank lets go. The room never sees the phone. The pairing code
  is kept for the browser tab, so a new room keeps the phone.

## Realtime limits

Supabase Realtime limits are the bottleneck of the multiplayer. This section
comes from going through the Supabase logs on 8 October 2026 and what changed
because of it. The numbers are measured by the budget tests, see
[Development](development.md#tests).

### How Realtime counts

- **Messages per second** (free plan 100, Pro 500) count for the whole
  project, averaged over a minute. A broadcast counts once when a client
  sends it and once more for every client it is delivered to, so a room of
  *n* pilots costs *n* times what its pilots send together: the load grows
  with the square of the room. Above the limit Realtime closes **every
  channel of the project**, all rooms at once
  (the server sends "Too many messages per second" and closes them). The
  clients reconnect after two seconds, then wait twice as long after every
  further drop, up to 30 seconds (`RetryBackoff`), so a project over its
  limit is not kept there by everybody knocking every two seconds. Above
  the limit Realtime still lets every join through and closes it again at
  once, so only a channel that stayed up for ten seconds starts over at the
  short wait.
- **Messages per month**, counted the same way: 2 million on the free plan
  (then a grace period and restrictions), 5 million on Pro ($25 a month,
  then $2.50 per further million).
- **Presence per client**: at most five tracks or untracks in 30 seconds on
  one channel, one more and Realtime closes that channel
  (`ClientPresenceRateLimitReached`).

Sources: [Realtime limits](https://supabase.com/docs/guides/realtime/limits),
[ClientPresenceRateLimitReached](https://supabase.com/docs/guides/troubleshooting/realtime-client-presence-rate-limit-reached),
[Manage Realtime Messages usage](https://supabase.com/docs/guides/platform/manage-your-usage/realtime-messages)
and the `supabase/realtime` source.

### Flood behaviour (measured locally)

Measured on 11 October 2026 against the local stack (`supabase start`,
tenant `realtime-dev`), with raw Phoenix clients and with real web builds
driven in headless Chrome. The hosted numbers are those of the Supabase
docs, not measured.

| Limit | Local `realtime-dev` | Hosted Free | Hosted Pro |
|---|---:|---:|---:|
| Concurrent connections | 200 | 200 | 500 |
| Messages per second (sent + delivered) | 100 | 100 | 500 |
| Channel joins per second | 100 | 100 | 500 |
| Channels per connection | 100 | 100 | 100 |
| Presence messages per second | 1000 | 20 | 50 |
| Broadcast payload | 3000 KB | 256 KB | 3000 KB |

- **Over the message limit** Realtime answers every channel of the tenant
  that sends, joins or tracks with the system message `Too many messages
  per second` and a `phx_close`, in every room, not only the flooder's. A
  channel that stays silent (a player alone in a room sends nothing) is
  only closed when it next acts. Joins are accepted and closed again at
  once for as long as the tenant stays over the limit.
- **Recovery**: about 10 seconds after a pure flood ends. With a game
  running next to it, the rate is averaged, so the closes go on as long
  as the game's own traffic and the rejoins keep it near the limit (up to
  40 seconds after the flood below).
- **Oversized messages**: above 3 MB a broadcast is dropped without a
  word; at 8 MB the server closes the sender's socket with code 1009.
- **100 channels per socket**; the per-client presence limit is not
  enforced on a self-hosted stack.

**Scenario (e)**: two web clients in a defense round (wave 1 to 2, about 75
to 105 messages a second on their own: a defense round of two is close to
the local and Free limit by itself), and a flooder sending 300 a second
from another room for 20 seconds:

| | Before the fixes | After |
|---|---|---|
| First close | 20 s into the flood, about when the average over a minute passed 100 | the same |
| Rejoins of the host | 4 (2, 4, 8, 16 s), back 46 s after the flood | 5 (2, 4, 8, 16, 30 s), back 71 s after |
| Rejoins of the guest | 3 (2, 4, 8 s), back 29 s after | 2 (2, 4 s), back 13 s after, one more drop later |
| Who ran the waves | **both**: the guest counted the host as gone after 6 s, took over, and the host ran on as well, with a base each (1054 and 1229 hit points) | the host alone, both screens the same (wave 2, 972 hit points) |

The backoff waited 2, 4, 8, 16 and 30 seconds as planned instead of
rejoining every 2 seconds (`RetryBackoff` only starts over once a channel
stayed up for 10 seconds). Two fixes came out of it: a game whose own
channel dropped in the last 45 seconds counts missing players as away, not
gone (`GameConfig.outageGrace`), and a defense host who comes back after a
stand-in took over gets the waves back, the stand-in drops its director
and its units.

A capture-the-flag round of three with CPU tanks (3 against 3) went over
the local limit of 100 on its own and split: the host ended it at 0:3
while its channel was down, so nobody heard the last capture, one guest
won 0:2 as a stand-in and the other played on. Since then a returning
flag host takes the flags back and repeats the final score after the
round (`flag_takeover_test.dart`), and a defense room claims 30 more a
second per pilot for its waves (`GameConfig.roomLoad`).

### What keeps the load down

Measured by `message_budget_test.dart`: a 20 second round on a real
`TankGame`, the own tank always driving, turning its turret and firing,
sent plus delivered.

| Load of one room | Before | After |
|---|---:|---:|
| Solo with CPU tanks | ~107/s | 0 |
| 2 pilots | ~83/s | ~44/s |
| 2 pilots with CPU tanks | ~216/s | ~70/s |
| 3 pilots | ~186/s | ~98/s |
| 3 pilots with CPU tanks | ~386/s | ~138/s |
| 4 pilots | ~331/s | ~174/s |
| 4 pilots with CPU tanks | ~597/s | ~227/s |
| Phone controller, thumbs moving | ~60/s | ~32/s |
| Apple TV duel with two phones | ~95/s | ~63/s |

1. **Nothing is sent when nobody listens.** A client alone in its room
   still records the round for its replay, but puts nothing on the channel.
2. **Ten states a second instead of twenty.** Remote tanks move on with
   their speed between states (dead reckoning).
3. **CPU tanks in one message.** The host sends the latest state of all its
   CPU tanks together as `states`, ten times a second. Their shots still go
   out one by one.
4. **Presence is throttled** to four updates per channel in 30 seconds, the
   last one always arrives.
5. **Rooms hold `MAX_PILOTS` pilots**, four on Pro, two on the free plan.
   Eight would need about 800 a second, more than Pro allows.
6. **The phone controller is spaced out.** Sticks at most every 80 ms,
   rounded so a resting thumb's tremor is no change, status at most every
   250 ms. Items and building go out at once.
7. **Rooms and phones share a budget.** Every room with more than one pilot
   and every screen with paired phones takes a slot with its load through
   `claim_load` (migrations 0015 and 0016, `RoomSlots`), and a new one only
   gets in while all of them stay within `REALTIME_BUDGET`.
8. **A phone makes room for itself.** A room with a phone controller plays
   without CPU tanks filling it up (except in defense, where the enemies
   are CPU tanks).
9. **A lane per phone**, so in an Apple TV duel neither phone hears the
   other.

### Rooms and room sizes

Messages per second decide how many rooms play **at the same time**,
messages per month how much **playing time** there is in all. The build
sets the room size and the shared budget, keeping a fifth of the plan in
reserve:

| Plan | `MAX_PILOTS` | `REALTIME_BUDGET` | Carries, for example |
|---|---:|---:|---|
| Pro (default, the project is on it since October 2026) | 4 | 400 | a room of four and two rooms of two, or five rooms of two |
| Pro, many small rooms | 2 | 400 | five rooms of two with CPU tanks |
| Free | 2 | 80 | one room of two, or a room of two and a phone |

Set them as repository variables next to `ACCOUNTS`; the `pages` workflow
hands them to the web build. The store builds are made locally
(`tool/archive_ios.sh`, `tool/archive_apple.sh`, `tool/release_android.sh`)
with the defaults, so add the same `--dart-define`s there when the plan
changes. Every client of one release should be built with the same values. Rooms count with their CPU
tanks unless a phone is in them, as only the host knows whether it fills
up. Solo rounds and two players on one screen cost nothing and always fit.

**On Pro** (400 a second):

| At the same time | Counted load | |
|---|---:|---|
| One room of 4 pilots | ~228/s | fits |
| A room of 4 and two rooms of 2 | ~368/s | fits |
| A room of 4 and a room of 3 | ~366/s | fits |
| Five rooms of 2 | ~350/s | fits |
| A room of 4, a room of 2 and a phone controller | ~330/s | fits |
| Two rooms of 4 | ~456/s | the second is turned away |
| Six rooms of 2 | ~420/s | the sixth is turned away |

**On the free plan** (80 a second):

| At the same time | Load | |
|---|---:|---|
| One room of 2 pilots with CPU tanks | ~70/s | fits |
| One room of 2 pilots and a phone controller | ~76/s | fits, the room plays without CPU tanks |
| Two players on one screen, each on a phone | ~64/s | fits while no room plays |
| Two rooms of 2 pilots | ~88/s | the second is turned away |
| A room of 2 pilots and somebody else's phone | ~102/s | the phone waits |

**Playing time per month**, shared by all rooms of the project:

| Room | Messages an hour | Free (2 million) | Pro, included (5 million) | Pro, each hour beyond |
|---|---:|---:|---:|---:|
| 2 pilots | ~160,000 | ~12 h | ~31 h | ~$0.40 |
| 2 pilots with CPU tanks | ~250,000 | ~8 h | ~20 h | ~$0.63 |
| 3 pilots with CPU tanks | ~500,000 | ~4 h | ~10 h | ~$1.24 |
| 4 pilots with CPU tanks | ~820,000 | ~2.5 h | ~6 h | ~$2.04 |
| Phone controller, on top | ~115,000 | ~17 h | ~43 h | ~$0.29 |

On Pro the **spend cap** (Organization, Billing, Cost Control) decides what
happens past the quota: on, Realtime is blocked for the rest of the month;
off, every further million costs $2.50. A free project past its grace
period may get `402` on **every** API request, Auth and database included.
Either way single player keeps working.

In short: **the free plan carries one small room at a time and a few
evenings a month; rooms of four or several rooms at once need Pro**, and on
Pro the playing time is what costs money, not the number of rooms.

### Running without the server

The game does not depend on the server to start
(`lib/src/db/server_status.dart`). A failed sign-in only marks the server
as away, the heartbeat (`ping_online`, once a minute while the app is in
front) asks again and keeps `ServerStatus.available` up to date. While the
server is away, the start page and the waiting room say so, multiplayer and
the room list are greyed out, and single player and defense on one's own go
on, unrecorded.

### What players notice

- **The room limit**: one pilot too many reads "Der Raum ist voll:
  höchstens 4 Piloten." and leaves, the room list shows full rooms as
  `VOLL`. Spectators count as pilots.
- **All rooms taken**: the start page says the server carries no more right
  now, the multiplayer card reads `ALLE RÄUME BELEGT`, rooms in the list
  read `BELEGT`. A slot comes free up to two and a half minutes after its
  room ended.
- **Phones that have to wait**: the pairing says so; the phone steers once
  there is room. Controllers, keyboard and touch always work.
- **The phone controller**: about 40 ms, at most 80 ms more delay on the
  sticks, and a tap on the aim stick shorter than 80 ms can go unnoticed.
- **Other tanks**: on sharp turns or full braking a remote tank can slide on
  a few pixels and pull back. Hits stay fair, since the victim works them
  out on its own side.
- **Presence**: after four changes within 30 seconds the others see only
  the latest, up to 30 seconds later.

Not yet tried by hand: a round on two devices with sharp manoeuvres, and a
round with the phone controller. The rates are constants in `GameConfig`
and `pad_link.dart`, and the budget tests show at once whether a change
still fits the plan.

### Still open

- Bigger rooms than four would need a relay of our own instead of Broadcast.
- The loads in the budget are estimates from the budget tests
  (`GameConfig.roomLoad`, `GameConfig.padLoad`), not live counts.
- Shots, hits and other events are not counted against the budget yet.
- Clients from before migrations 0015 and 0016 take no slot or count as a
  room of two with CPU tanks, and do not know the room limit or the lanes;
  older TestFlight builds also do not see the CPU tanks of a newer host.
  Web and a new TestFlight build should go out together.
- On Pro: decide on the spend cap and look at the usage once a month.
- Identity: messages carry tags and the host is ranked by the server since
  migration 0020. Channels stay public: private channels with Realtime
  Authorization would only keep out who has no session, and anybody gets
  a guest session; the tags already keep everybody to their own name. A
  player of a build before keys can still be posed as, and a room opened
  by such a build still trusts claims to own it. A client can still flood
  the project above its message limit, which closes every room (see
  "Flood behaviour"); only Supabase can stop that.
- A defense host's takeover rebuilds what the old host kept to itself
  only roughly: the clean waves towards the next base level follow from the
  level, the base's hit points at the start of the wave are those at the
  takeover, and a jet of the base still to come in that wave stays away.
  Clients whose roster differs at the end of the grace could pick
  different hosts for a moment. A host that comes back takes the waves
  back, but what the stand-in's waves left (squads, dug-in enemy guns)
  stays on its screen only. Replays of a defense round do not show the
  waves anyway.
