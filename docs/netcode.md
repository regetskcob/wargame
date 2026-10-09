# Netcode and Realtime limits

## How the netcode works

- One Realtime channel per room carries the broadcast events `state`,
  `states`, `shoot`, `hit`, `death`, `roundStart`, `pickup`, `smoke`, `obstacle`,
  `soldier`, `mine`, `artillery`, `grenade`, `drone`, `blast`,
  `defense`, `tower`, `troops` (a duel's extra tank, sent by a player and run
  by the host), and `close`.
- The netcode is peer-authoritative: every client simulates its own player and
  bullets, and the victim of a hit applies its own damage before broadcasting
  the result. Each player has exactly one authority, so there are no conflicts.
- Every client checks what the others broadcast against what their tank can
  do (`plausibility.dart`): shots faster than the gun reloads or far from the
  tank are dropped, tanks faster than their top speed are held back, health
  only rises after a repair crate, a tank at high health cannot die from one
  message, and mines and barrages need a crate first. This is a plausibility
  check, not an anti-cheat.
- A round is defined by `{seed, startedAt}`: every client generates an
  identical world from the seed and derives the round clock from the start
  time. The world costs zero bandwidth.
- Tank state goes out ten times a second and remote players smooth over the
  gaps with dead reckoning. The host sends the states of all its CPU tanks
  together as one `states` message. A client alone in its room sends
  nothing at all. See [Realtime limits](#realtime-limits).
- A room holds `MAX_PILOTS` pilots (four by default), spectators included.
  Presences carry when the pilot joined; every client keeps the owner and
  then the earliest arrivals, and whoever comes later sees that the room is
  full and leaves.
- Rooms and phone controllers share the project's Realtime budget,
  `REALTIME_BUDGET` messages a second (400 by default). A room takes a slot
  with its load through the `claim_load` database function as soon as a
  second pilot is in it, a screen with paired phones takes one for them,
  and everybody refreshes once a minute; a silent slot runs out after two
  and a half minutes. Who comes into a room that does not fit any more
  sees that all rooms are taken and leaves; the owner stays and waits.
  Phones that do not fit wait and steer nothing. A room with a phone in it
  plays without CPU tanks filling it up. See
  [Rooms and room sizes](#rooms-and-room-sizes).
- Without a server the game still starts; single player goes on, and the
  heartbeat notices when the server is back. See
  [Running without the server](#running-without-the-server).
- Presence updates are spaced out to at most four per channel in 30 seconds
  (`presence_throttle.dart`); faster changes wait and only the latest goes
  out.
- Presence powers the lobby roster, disconnect handling, and match discovery:
  players in a match advertise the seed so late joiners can spectate.
- In the defense mode the players hold a base together on a fixed map without
  the closing zone. The host runs the enemy waves like CPU tanks and is the
  authority over the base: it broadcasts the base's hit points, the wave and
  the result as `defense`, along with how far the base has grown. Guns go up
  with `tower`, and only their builder aims and fires them, so their shots
  travel as ordinary `shoot` events. The host also keeps the guns' hit
  points and sends them with `tower` after every hit; at nothing the gun is
  gone on every client.
- Every player records their round through the `record_round` database
  function. It clamps the numbers, grants experience and moves the Elo rating
  against the human opponents the player outlasted, and keeps the round in
  `round_results` for the weekly leaderboard and the numbers per vehicle. The
  all time leaderboard is a typed Postgres Changes stream on `scores`.
- Replays need no extra traffic: the client keeps every message of the round
  with its time, and since the world follows from the seed, playing them back
  into a round that starts now shows the round again.
- Public rooms announce themselves through Presence on a separate
  `game-rooms` channel and vanish when their host leaves.
- A phone controller pairs on a channel of its own, `pad-<CODE>`, with an
  eight character code from the screen's QR code. The phone sends its
  sticks as `pad` at most twelve and a half times a second, rounded so a
  resting thumb's tremor is no change, and single presses as `act`; the
  screen plays them as its touch controls and answers with `status`
  (health, ammunition, items, phase) at most about three times a second.
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
  (`MessagePerSecondRateLimitReached`). The clients reconnect after two
  seconds, then wait twice as long after every further drop, up to 30
  seconds (`RetryBackoff`), so a project over its limit is not kept there
  by everybody knocking every two seconds.
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

Set them as repository variables next to `ACCOUNTS`; the `pages`, `play`
and `testflight` workflows hand them to the build. Every client of one
release should be built with the same values. Rooms count with their CPU
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
