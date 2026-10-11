import 'dart:ui';

import '../l10n/l10n.dart';

/// How a ground looks, which objects stand on it and how many of them.
///
/// The map of a round follows from its seed alone ([MapTheme.forSeed]), so all
/// clients agree on it without extra network traffic.
class MapTheme {
  const MapTheme({
    required this.nameDe,
    required this.nameEn,
    required this.ground,
    required this.patches,
    required this.ring,
    required this.treeOuter,
    required this.treeInner,
    required this.treeEdge,
    required this.wall,
    required this.roof,
    required this.roofLine,
    required this.window,
    required this.wallEdge,
    required this.debris,
    required this.barrierBody,
    required this.barrierStripe,
    required this.barrierEdge,
    required this.barrierDebris,
    required this.buildingCount,
    required this.barrierCount,
    required this.treeCount,
    required this.mudNameDe,
    required this.mudNameEn,
    required this.mud,
    required this.mudRim,
    required this.mudCount,
    this.flatRoofs = false,
    this.roads = false,
    this.mountains = false,
    this.islands = false,
  });

  final String nameDe;
  final String nameEn;
  String get name => tr(nameDe, nameEn);

  final Color ground;
  final List<Color> patches;
  final Color ring;

  /// Woods, boulders or rubble: slows tanks and gives cover.
  final Color treeOuter;
  final Color treeInner;
  final Color treeEdge;

  final Color wall;
  final Color roof;
  final Color roofLine;
  final Color window;
  final Color wallEdge;
  final Color debris;

  final Color barrierBody;
  final Color barrierStripe;
  final Color barrierEdge;
  final Color barrierDebris;

  final int buildingCount;
  final int barrierCount;
  final int treeCount;

  /// Soft ground that slows tanks: swamp, quicksand, deep snow, puddles.
  final String mudNameDe;
  final String mudNameEn;
  String get mudName => tr(mudNameDe, mudNameEn);
  final Color mud;
  final Color mudRim;
  final int mudCount;

  /// Flat roofs with rooftop boxes instead of a pitched roof with a ridge.
  final bool flatRoofs;

  /// Paved ground with a crossing of two roads in the middle.
  final bool roads;

  /// Hills on every level, more and steeper ones than elsewhere.
  final bool mountains;

  /// Mostly shallow water with islands (see `IslandShape`); [mud] is the
  /// water's colour and [mudRim] the sand of the shores.
  final bool islands;

  static const forest = MapTheme(
    nameDe: 'Gefechtsplatz',
    nameEn: 'Battlefield',
    ground: Color(0xFF424F29),
    patches: [
      Color(0xFF4A5A2E),
      Color(0xFF3A4724),
      Color(0xFF5C5436),
      Color(0xFF2B3320),
    ],
    ring: Color(0x225C4B32),
    treeOuter: Color(0xFF1F3318),
    treeInner: Color(0xFF2E4A22),
    treeEdge: Color(0xFF0F1D0B),
    wall: Color(0xFF8A6A50),
    roof: Color(0xFFA7835F),
    roofLine: Color(0xFF5B4333),
    window: Color(0xFF4A3A30),
    wallEdge: Color(0xFF2E221A),
    debris: Color(0xFF9C7B5A),
    barrierBody: Color(0xFF8E8E86),
    barrierStripe: Color(0xFFD9C14A),
    barrierEdge: Color(0xFF2E2E2A),
    barrierDebris: Color(0xFF9A9A92),
    buildingCount: 7,
    barrierCount: 14,
    treeCount: 50,
    mudNameDe: 'Sumpf',
    mudNameEn: 'Swamp',
    mud: Color(0xFF2F3A1F),
    mudRim: Color(0xFF1E2714),
    mudCount: 7,
  );

  static const desert = MapTheme(
    nameDe: 'Wüste',
    nameEn: 'Desert',
    ground: Color(0xFFC9A66B),
    patches: [
      Color(0xFFD9B97F),
      Color(0xFFB8935A),
      Color(0xFFE0C58F),
      Color(0xFFA9854E),
    ],
    ring: Color(0x228A6A3A),
    treeOuter: Color(0xFF6E5233),
    treeInner: Color(0xFF8F7048),
    treeEdge: Color(0xFF3F2E1B),
    wall: Color(0xFFD8BE8E),
    roof: Color(0xFFE6D0A4),
    roofLine: Color(0xFFB39A6B),
    window: Color(0xFF5A4630),
    wallEdge: Color(0xFF6B5636),
    debris: Color(0xFFD8BE8E),
    barrierBody: Color(0xFFB49B6C),
    barrierStripe: Color(0xFF7A6240),
    barrierEdge: Color(0xFF4A3B26),
    barrierDebris: Color(0xFFB49B6C),
    buildingCount: 4,
    barrierCount: 16,
    treeCount: 40,
    mudNameDe: 'Treibsand',
    mudNameEn: 'Quicksand',
    mud: Color(0xFFA8844A),
    mudRim: Color(0xFF86683A),
    mudCount: 6,
    flatRoofs: true,
  );

  static const winter = MapTheme(
    nameDe: 'Winter',
    nameEn: 'Winter',
    ground: Color(0xFFDCE6EC),
    patches: [
      Color(0xFFF4F8FA),
      Color(0xFFC2D2DC),
      Color(0xFFB0C4D0),
      Color(0xFFE9F0F4),
    ],
    ring: Color(0x2260788A),
    treeOuter: Color(0xFF1C3A2E),
    treeInner: Color(0xFFEAF2F6),
    treeEdge: Color(0xFF0E2119),
    wall: Color(0xFF6B4F3A),
    roof: Color(0xFFF1F6F8),
    roofLine: Color(0xFFB9C9D2),
    window: Color(0xFFE8B84A),
    wallEdge: Color(0xFF2E2118),
    debris: Color(0xFF8D6C50),
    barrierBody: Color(0xFFA9C6D6),
    barrierStripe: Color(0xFFEAF4F8),
    barrierEdge: Color(0xFF4E6877),
    barrierDebris: Color(0xFFCFE2EC),
    buildingCount: 5,
    barrierCount: 12,
    treeCount: 60,
    mudNameDe: 'Tiefschnee',
    mudNameEn: 'Deep snow',
    mud: Color(0xFFF7FBFD),
    mudRim: Color(0xFFA9BFCC),
    mudCount: 8,
  );

  static const city = MapTheme(
    nameDe: 'Stadt',
    nameEn: 'City',
    ground: Color(0xFF4A4D50),
    patches: [
      Color(0xFF3E4144),
      Color(0xFF55595C),
      Color(0xFF45484B),
      Color(0xFF383A3D),
    ],
    ring: Color(0x22101214),
    treeOuter: Color(0xFF2B2E2C),
    treeInner: Color(0xFF4C5A44),
    treeEdge: Color(0xFF151716),
    wall: Color(0xFF7D8186),
    roof: Color(0xFF9A9EA3),
    roofLine: Color(0xFF5E6266),
    window: Color(0xFF3B4045),
    wallEdge: Color(0xFF222427),
    debris: Color(0xFF8A8D91),
    barrierBody: Color(0xFFB9B9B2),
    barrierStripe: Color(0xFFC8402E),
    barrierEdge: Color(0xFF2A2A28),
    barrierDebris: Color(0xFFA5A59E),
    buildingCount: 14,
    barrierCount: 20,
    treeCount: 12,
    mudNameDe: 'Schlammpfütze',
    mudNameEn: 'Mud puddle',
    mud: Color(0xFF4A3B2A),
    mudRim: Color(0xFF2E2418),
    mudCount: 6,
    flatRoofs: true,
    roads: true,
  );

  /// Mountain forest: dense conifers, scree and hills on every level.
  static const mountainForest = MapTheme(
    nameDe: 'Bergwald',
    nameEn: 'Mountain forest',
    ground: Color(0xFF3E4A34),
    patches: [
      Color(0xFF6B6E66),
      Color(0xFF34402B),
      Color(0xFF4A5640),
      Color(0xFF5A5D55),
    ],
    ring: Color(0x22202A1A),
    treeOuter: Color(0xFF142A1C),
    treeInner: Color(0xFF23402A),
    treeEdge: Color(0xFF07130B),
    wall: Color(0xFF7A6248),
    roof: Color(0xFF5A4636),
    roofLine: Color(0xFF3A2C22),
    window: Color(0xFF3A3028),
    wallEdge: Color(0xFF241C14),
    debris: Color(0xFF8A8478),
    barrierBody: Color(0xFF8C8A84),
    barrierStripe: Color(0xFFD8C04A),
    barrierEdge: Color(0xFF2C2C28),
    barrierDebris: Color(0xFF9A988E),
    buildingCount: 3,
    barrierCount: 8,
    treeCount: 95,
    mudNameDe: 'Geröll',
    mudNameEn: 'Scree',
    mud: Color(0xFF77746C),
    mudRim: Color(0xFF55534D),
    mudCount: 7,
    mountains: true,
  );

  /// More water than land: a ring of islands round a middle one, joined by
  /// causeways, with shallow water between them that tanks wade through
  /// slowly and shells fly over.
  static const isles = MapTheme(
    nameDe: 'Inseln',
    nameEn: 'Islands',
    ground: Color(0xFF7E8A4E),
    patches: [
      Color(0xFF8C9858),
      Color(0xFF6E7A44),
      Color(0xFFB8A978),
      Color(0xFF66703E),
    ],
    ring: Color(0x22504A2A),
    treeOuter: Color(0xFF2E5A2A),
    treeInner: Color(0xFF4F8A3A),
    treeEdge: Color(0xFF163016),
    wall: Color(0xFFD8CCB0),
    roof: Color(0xFFB0563A),
    roofLine: Color(0xFF7A3A26),
    window: Color(0xFF3A4A58),
    wallEdge: Color(0xFF5A4E3A),
    debris: Color(0xFFCABE9E),
    barrierBody: Color(0xFFB8AE90),
    barrierStripe: Color(0xFF3A6E8A),
    barrierEdge: Color(0xFF4A4430),
    barrierDebris: Color(0xFFC4BA9C),
    buildingCount: 5,
    barrierCount: 8,
    treeCount: 34,
    mudNameDe: 'Flachwasser',
    mudNameEn: 'Shallow water',
    mud: Color(0xFF2F6E8A),
    mudRim: Color(0xFFD8C890),
    mudCount: 0,
    islands: true,
  );

  static const all = [forest, desert, winter, city, mountainForest, isles];

  /// The maps every client knows, also those of older versions: the seed
  /// carries them in `seed % 4`, as it always did.
  static const classic = 4;

  /// Maps after the [classic] ones are marked in the seed's bits above the
  /// opening sky (see `Conditions`): 6 picks the first new map, 7 the next,
  /// anything else leaves `seed % 4`. Older clients read `seed % 4` only, so
  /// a host offers the new maps only to a room where everybody knows them.
  static int indexOf(int seed) {
    final mark = (seed.abs() ~/ _markUnit) % 8;
    return mark >= 6 && classic + mark - 6 < all.length
        ? classic + mark - 6
        : seed.abs() % classic;
  }

  static MapTheme forSeed(int seed) => all[indexOf(seed)];

  /// Rewrites [seed] so that it selects [map] and keeps the bits that hold
  /// the sky and everything else.
  static int seedFor(int seed, int map) {
    final mark = (seed ~/ _markUnit) % 8;
    final rest = seed - mark * _markUnit;
    if (map >= classic) {
      return rest + (6 + map - classic) * _markUnit;
    }
    return rest - rest % classic + map + (mark % 6) * _markUnit;
  }

  /// `seed % 4` for the map and a factor of 20 for the opening sky.
  static const _markUnit = 4 * 20;
}
