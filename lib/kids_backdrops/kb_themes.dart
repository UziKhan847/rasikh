// GENERATED from Kids Backdrops.dc.html (THEMES, AVATARS). Do not hand-edit values.
// Colours are 0xRRGGBB ints; use kbC(rgb, alpha) to get a Color.

class KbRidge {
  final String kind; // wave | dune | hill | crag | tree | ice
  final double base, amp, wavelength;
  const KbRidge(this.kind, this.base, this.amp, this.wavelength);
}

class KbOrnament {
  final String kind; // sun | moon | clouds | aurora
  final double x, y, r;
  final bool soft, isNew;
  /// Optional override for the over-exposed horizon sun (Sunset): position/size of the big low sun.
  final double? lx, ly, lr;
  const KbOrnament(this.kind, {this.x = 0, this.y = 0, this.r = 0, this.soft = false, this.isNew = false, this.lx, this.ly, this.lr});
  bool get hasLight => lx != null;
}

class KbTheme {
  final String id, name;
  final int bg, text, accent, bright, deep, accent2, reward, dark;
  final String? skyTop, skyBot, ground, litTop;
  final bool stars, snowcap;
  /// Light-mode lighting pass (rich sky, warm side / cool side on ridges, sun-facing rim light).
  final bool lit;
  /// dusk: dark/OLED modes also use the over-exposed horizon sun.
  /// softSun: light mode keeps the soft disc + halo (Sunrise).
  /// hotHorizon: saturated orange horizon + orange sun (Sunset).
  /// sil: ridges drawn as near-black silhouettes (Sunset).
  final bool dusk, softSun, hotHorizon, sil;
  final int? silC, silD, darkGlow;
  final KbOrnament? orn;
  final List<KbRidge> ridges;
  final String moteType; // bubble | dust | twinkle | firefly | petal | rain | snow | spore
  final int moteCount;
  final int price; // gems, 0 = free
  const KbTheme({required this.id, required this.name, required this.bg, required this.text, required this.accent, required this.bright, required this.deep, required this.accent2, required this.reward, required this.dark, this.skyTop, this.skyBot, this.ground, this.litTop, this.stars = false, this.snowcap = false, this.lit = false, this.dusk = false, this.softSun = false, this.hotHorizon = false, this.sil = false, this.silC, this.silD, this.darkGlow, this.orn, required this.ridges, required this.moteType, required this.moteCount, this.price = 0});

  int color(String key) {
    switch (key) {
      case 'bg': return bg;
      case 'text': return text;
      case 'accent': return accent;
      case 'bright': return bright;
      case 'deep': return deep;
      case 'accent2': return accent2;
      case 'reward': return reward;
      case 'dark': return dark;
    }
    throw ArgumentError(key);
  }
}

const List<KbTheme> kbThemes = [
  KbTheme(id: 'ocean', name: 'Ocean', bg: 0xEFF7FA, text: 0x1E3A44, accent: 0x2196C9, bright: 0x5BC4E8, deep: 0x15738F, accent2: 0x6C63D6, reward: 0x28C4B4, dark: 0x11202A,
    lit: true, orn: KbOrnament('sun', x: 0.78, y: 0.12, r: 0.1),
    ridges: [KbRidge('wave', 0.6, 0.035, 1.1), KbRidge('wave', 0.74, 0.045, 0.8), KbRidge('wave', 0.9, 0.055, 0.6)],
    moteType: 'bubble', moteCount: 14, price: 0),
  KbTheme(id: 'lagoon', name: 'Lagoon', bg: 0xE8F2F0, text: 0x163B32, accent: 0x2C967C, bright: 0x59CFBB, deep: 0x165A51, accent2: 0xCEB07E, reward: 0xED876E, dark: 0x152823,
    lit: true, orn: KbOrnament('sun', x: 0.2, y: 0.13, r: 0.1),
    ridges: [KbRidge('hill', 0.61, 0.075, 0.7), KbRidge('wave', 0.76, 0.055, 0.55), KbRidge('wave', 0.91, 0.05, 0.4)],
    moteType: 'bubble', moteCount: 16, price: 0),
  KbTheme(id: 'desert', name: 'Desert', bg: 0xF3E4C6, text: 0x3F2A14, accent: 0xC9772B, bright: 0xE3A45B, deep: 0x94531A, accent2: 0x7B5EA7, reward: 0xE6B34A, dark: 0x2B1F10,
    skyTop: 'accent', skyBot: 'reward', lit: true, orn: KbOrnament('sun', x: 0.74, y: 0.11, r: 0.085),
    ridges: [KbRidge('dune', 0.62, 0.085, 1.3), KbRidge('dune', 0.74, 0.095, 0.95), KbRidge('dune', 0.9, 0.08, 0.7)],
    moteType: 'dust', moteCount: 18, price: 0),
  KbTheme(id: 'night', name: 'Night', bg: 0xF3F0FA, text: 0x2E2A4A, accent: 0x4A3F8C, bright: 0x6C5CE7, deep: 0x352A6B, accent2: 0xE8C468, reward: 0xF0D278, dark: 0x1B1830,
    stars: true, orn: KbOrnament('moon', x: 0.7, y: 0.13, r: 0.105),
    ridges: [KbRidge('hill', 0.64, 0.08, 0.9), KbRidge('hill', 0.8, 0.09, 0.65)],
    moteType: 'twinkle', moteCount: 12, price: 0),
  KbTheme(id: 'forest', name: 'Forest', bg: 0xE8F2E9, text: 0x163B1B, accent: 0x389444, bright: 0x70CD7C, deep: 0x195726, accent2: 0x885E3A, reward: 0xC3B555, dark: 0x152818,
    skyTop: 'reward', lit: true, orn: KbOrnament('sun', x: 0.72, y: 0.14, r: 0.1),
    ridges: [KbRidge('hill', 0.58, 0.065, 0.85), KbRidge('tree', 0.76, 0.11, 0.9), KbRidge('tree', 0.93, 0.13, 0.6)],
    moteType: 'firefly', moteCount: 12, price: 0),
  KbTheme(id: 'blossom', name: 'Blossom', bg: 0xF2E8F2, text: 0x3B163B, accent: 0xC760C7, bright: 0xE29CE2, deep: 0x883A88, accent2: 0x7153AC, reward: 0xE2AD78, dark: 0x281528,
    litTop: 'accent2', lit: true, orn: KbOrnament('sun', x: 0.74, y: 0.15, r: 0.12, soft: true, isNew: true),
    ridges: [KbRidge('hill', 0.6, 0.08, 1), KbRidge('hill', 0.76, 0.09, 0.72), KbRidge('hill', 0.92, 0.085, 0.52)],
    moteType: 'petal', moteCount: 16, price: 0),
  KbTheme(id: 'sunset', name: 'Sunset', bg: 0xF2E8E9, text: 0x3B1619, accent: 0xD4545E, bright: 0xF0A06A, deep: 0x792A37, accent2: 0x8D57A8, reward: 0xEEAF77, dark: 0x281517,
    skyTop: 'accent2', dusk: true, hotHorizon: true, sil: true, lit: true, orn: KbOrnament('sun', x: 0.3, y: 0.2, r: 0.14, lx: 0.5, ly: 0.575, lr: 0.34),
    ridges: [KbRidge('hill', 0.62, 0.07, 1.2), KbRidge('hill', 0.79, 0.085, 0.8)],
    moteType: 'dust', moteCount: 12, price: 0),
  KbTheme(id: 'rain', name: 'Rain', bg: 0xE9EEF2, text: 0x1F2D3A, accent: 0x4F6D8A, bright: 0x8FB3D1, deep: 0x2E4459, accent2: 0x7A6FA8, reward: 0xF2C94C, dark: 0x141C24,
    orn: KbOrnament('clouds', isNew: true),
    ridges: [KbRidge('hill', 0.6, 0.07, 0.95), KbRidge('hill', 0.76, 0.08, 0.7), KbRidge('hill', 0.91, 0.06, 0.55)],
    moteType: 'rain', moteCount: 46, price: 80),
  KbTheme(id: 'cave', name: 'Cave', bg: 0xECE8F0, text: 0x2A2233, accent: 0x6B4F8C, bright: 0x9B7FD0, deep: 0x3A2A4E, accent2: 0x3F8C8A, reward: 0x5FE0D0, dark: 0x16121C,
    lit: true, orn: null,
    ridges: [KbRidge('crag', 0.6, 0.1, 0.9), KbRidge('crag', 0.76, 0.12, 0.8), KbRidge('crag', 0.92, 0.1, 0.6)],
    moteType: 'spore', moteCount: 16, price: 100),
  KbTheme(id: 'sunrise', name: 'Sunrise', bg: 0xFBEFE6, text: 0x3D2418, accent: 0xF08A4B, bright: 0xFFC27A, deep: 0xA2472A, accent2: 0xE0679A, reward: 0xFFD66B, dark: 0x2A1A14,
    skyTop: 'accent2', dusk: true, softSun: true, lit: true, orn: KbOrnament('sun', x: 0.5, y: 0.56, r: 0.15),
    ridges: [KbRidge('hill', 0.62, 0.06, 1.3), KbRidge('hill', 0.8, 0.08, 0.85)],
    moteType: 'dust', moteCount: 14, price: 80),
  KbTheme(id: 'frozen', name: 'Frozen', bg: 0xEAF4F8, text: 0x15323D, accent: 0x3AA5C8, bright: 0x8FDDF0, deep: 0x1D6A86, accent2: 0x7C8BE0, reward: 0xC6F4FF, dark: 0x0E1C24,
    lit: true, orn: KbOrnament('aurora', isNew: true),
    ridges: [KbRidge('ice', 0.6, 0.12, 0.9), KbRidge('ice', 0.75, 0.14, 0.8), KbRidge('wave', 0.91, 0.03, 0.8)],
    moteType: 'twinkle', moteCount: 14, price: 120),
  KbTheme(id: 'snowy', name: 'Snowy', bg: 0xF1F3F7, text: 0x23303F, accent: 0x5C7FB0, bright: 0xA9C4E8, deep: 0x34507A, accent2: 0x8A7FC0, reward: 0xFF8A65, dark: 0x131A26,
    ground: 'snow', snowcap: true, lit: true, orn: KbOrnament('sun', x: 0.24, y: 0.14, r: 0.09, soft: true, isNew: true),
    ridges: [KbRidge('hill', 0.6, 0.08, 1), KbRidge('tree', 0.76, 0.11, 0.9), KbRidge('hill', 0.92, 0.07, 0.7)],
    moteType: 'snow', moteCount: 34, price: 120),
];

class KbAvatarInfo {
  final String id, name;
  final int price; // gems, 0 = free
  const KbAvatarInfo(this.id, this.name, [this.price = 0]);
  /// PNG (1x/2x/3x). The avatars' soft shadows use SVG blur filters, which flutter_svg does not
  /// render, so ship the PNG exports. SVG sources are in source/avatars/.
  String get asset => 'assets/avatars/$id.png';
}

const List<KbAvatarInfo> kbAvatars = [
  KbAvatarInfo('fox', 'Fox'),
  KbAvatarInfo('panda', 'Panda'),
  KbAvatarInfo('tiger', 'Tiger'),
  KbAvatarInfo('lion', 'Lion'),
  KbAvatarInfo('koala', 'Koala'),
  KbAvatarInfo('frog', 'Frog'),
  KbAvatarInfo('horse', 'Horse'),
  KbAvatarInfo('dolphin', 'Dolphin'),
  KbAvatarInfo('camel', 'Camel'),
  KbAvatarInfo('cow', 'Cow'),
  KbAvatarInfo('bear', 'Grizzly'),
  KbAvatarInfo('kangaroo', 'Kangaroo'),
  KbAvatarInfo('lioncub', 'Lion Cub'),
  KbAvatarInfo('bee', 'Bee', 60),
  KbAvatarInfo('ant', 'Ant', 60),
  KbAvatarInfo('cat', 'Cat', 60),
  KbAvatarInfo('bunny', 'Bunny', 80),
  KbAvatarInfo('penguin', 'Penguin', 80),
  KbAvatarInfo('owl', 'Owl', 100),
  KbAvatarInfo('monkey', 'Monkey', 100),
  KbAvatarInfo('elephant', 'Elephant', 120),
  KbAvatarInfo('sheep', 'Sheep', 120),
  KbAvatarInfo('spider', 'Spider', 120),
  KbAvatarInfo('hippo', 'Hippo', 60),
  KbAvatarInfo('crocodile', 'Crocodile', 90),
  KbAvatarInfo('rhino', 'Rhino', 90),
  KbAvatarInfo('shark', 'Shark', 120),
  KbAvatarInfo('goat', 'Goat', 60),
  KbAvatarInfo('buffalo', 'Buffalo', 90),
  KbAvatarInfo('whale', 'Whale', 120),
  KbAvatarInfo('wolf', 'Wolf', 100),
  // objects
  KbAvatarInfo('shield', 'Shield', 60),
  KbAvatarInfo('sword', 'Sword', 80),
  KbAvatarInfo('helmet', 'Helmet', 100),
  KbAvatarInfo('tasbeeh', 'Tasbeeh', 40),
  KbAvatarInfo('prayermat', 'Prayer Mat', 40),
  KbAvatarInfo('topi', 'Topi', 40),
  KbAvatarInfo('dates', 'Dates', 30),
  KbAvatarInfo('dallah', 'Qahwa', 60),
  KbAvatarInfo('tea', 'Chai', 30),
  KbAvatarInfo('flask', 'Flask', 50),
  KbAvatarInfo('lantern', 'Lantern', 80),
  KbAvatarInfo('crescent', 'Crescent', 100),
  KbAvatarInfo('palm', 'Palm Tree', 40),
  KbAvatarInfo('mosque', 'Mosque', 120),
  KbAvatarInfo('quran', 'Quran Stand', 100),
  KbAvatarInfo('miswak', 'Miswak', 30),
  KbAvatarInfo('zamzam', 'Zamzam', 50),
  KbAvatarInfo('attar', 'Attar', 60),
  // Reward-only: unlocked by the "Streak Freeze" reward, not bought. Price 0 here; gate it in the app.
  KbAvatarInfo('icecube', 'Ice Cube'),
];

/// Parallax speed per layer (fraction of camera movement). x = tab swipe, y = page scroll.
class KbPlx { final double x, y; const KbPlx(this.x, this.y); }
const Map<String, KbPlx> kbParallax = {
  'orn': KbPlx(0.03, 0.05),
  'far': KbPlx(0.12, 0.1),
  'mid': KbPlx(0.25, 0.2),
  'near': KbPlx(0.45, 0.35),
  'motes': KbPlx(0.6, 0.5),
  'mist0': KbPlx(0.18, 0.15), // High/Ultra mist, in front of far
  'mist1': KbPlx(0.34, 0.27), // High/Ultra mist, in front of mid
};
/// Depth-blur sigma per layer (logical px at 390 wide; scale by width/390).
const Map<String, double> kbDepthBlur = {'far': 2.6, 'mid': 1.1, 'near': 0, 'bokeh': 9, 'mist0': 3.5, 'mist1': 2.5};
/// Ultra: extra blur added at full scroll progress (depth of field follows scrolling).
const Map<String, double> kbScrollBlur = {'far': 3, 'mid': 1.6, 'mist0': 2};
const double kbPlxMaxScrollY = 400; // total vertical travel, spread across the full page scroll
