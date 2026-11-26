# Streuwerk template package

Slides and reel scenes for Panzergefecht's social posts, read by
[Streuwerk](https://github.com/regetskcob/streuwerk) from this folder
(`docs/templates.md` there). Colours come from
`tool/horizont/horizont.product.json` (dark terrain, signal yellow), type from
Horizont (Mona Sans, Monaspace; `fonts/OFL.txt`). Change `version` in
`template.yaml` with every change; Streuwerk asks for approval of each new
version.

## Reels

Daniel's rules for reels, which the scenes are built for:

- Start moving in the first frame, never with a still text card: `hook`
  rolls a vehicle in and writes the line, the terrain drifts behind every
  scene on the reel's clock, so cuts do not jump.
- No capitals for effect: kickers and headings in sentence case.
- No burned-in subtitles over the game: `play`, `zoom` and `clip` end at
  1290px, the subtitles sit in their own band below.
- Gameplay large, not in a tiny phone: `play` (full width, slow push-in,
  from a full-screen shot without frame such as `media:tv-gefecht`),
  `zoom` (from the whole screen onto the player's tank in the middle, where
  the camera keeps it) and `clip` (a recording). The phone (`shot`) is for
  menus and the controller and stands still from shot to shot.
- `showcase` puts one piece of the game on the terrain: a vehicle, a crate,
  a base stage or a round map from `../media/` (see `media.yaml`), or in
  `piece` a vehicle's square clip instead of the picture.
- The game's box ends at 1290px above the subtitle band, so the zooms and
  recordings crop more at the bottom than at the top: the own tank in the
  middle of a screenshot or recording lands under the heading, not in the
  upper third.

Recordings of played rounds (battle, defense, room, phone controller) come
from `tool/streuwerk/record_scenes.sh`: a screenshot build with
`SHOT_DRIVE` lets a CPU brain drive the own tank on a simulator, without
blood.

A reel that reads well: `hook` with `media:fahrzeug-wolf-quer`, `zoom` on a
round, `showcase` of a crate or map, `play` of the defense, `end`.

## Media

`tool/streuwerk/render_media.sh` draws vehicles, crates, terrain, round map
views and base stages from the game's own painters (transparent PNGs) and a
short clip per vehicle. Run it again when a painter changes.
