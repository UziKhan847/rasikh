/// The drawn avatars — animals and a few objects — that stand in for Kids
/// Mode's emoji avatars.
///
/// A profile stores a **string** in `KidsProfile.avatar`, and that string is the
/// avatar's identity everywhere: it is what the shop's avatar unlocks match by
/// value (`kidsAvatarUnlock`), what `baseAvatar` remembers, and what every saved
/// profile already holds. For an animal it is the animal's emoji; for anything
/// with no fitting emoji of its own (the objects, the lion cub) it is
/// `avatar:<id>` — never an emoji that already means something else in the app
/// (🧊 is the Frozen theme and the streak freeze, 🌙 the Night theme…).
/// Rendering swaps the string for the drawing (`KidsAvatarFace`), so no saved
/// profile needs migrating and nothing a child bought moves.
///
/// The art is the design handoff's: 50 drawings, so that every platform —
/// including Linux, which has no colour emoji font — renders them the same.
/// They ship as PNGs at 1x/2x/3x in `assets/avatars/`, because their soft
/// shadows are SVG blur filters that `flutter_svg` cannot draw; the design's
/// C2PA provenance chunks are stripped (the pixels are untouched).
class KidsAnimal {
  /// The asset's file name, `assets/avatars/<id>.png`.
  final String id;

  /// The value a profile stores when it wears this: an emoji, or
  /// `avatar:<id>` (see the class doc).
  final String emoji;

  /// Art that ships but is **not offered**: no picker tile and no shop item, so
  /// no child can wear it (only the testing unlock's picker shows it). Selling
  /// an avatar is irreversible — a child spends gems and owns it — so the
  /// decision to offer one is made deliberately, in `kidsShopItems`, not by
  /// default.
  final bool held;

  /// Other values a profile may hold that draw this — the retired shop
  /// racehorse 🐎 draws the horse.
  final List<String> also;
  const KidsAnimal(this.id, this.emoji, {this.held = false, this.also = const []});

  String get asset => 'assets/avatars/$id.png';
}

/// Every drawn avatar. Order is the design's: animals (the free ones first),
/// then objects.
///
/// **Who owns what is not decided here.** The design's art is adopted, its
/// price list is not: nothing a child has bought becomes free or changes price.
/// The free picker is the eight it always offered plus the three the design
/// adds as free (grizzly, kangaroo, lion cub). Animals are sold only when the
/// Qurʼān names them (goat and wolf join camel, bee, ant, spider, cow, whale,
/// monkey, sheep); cat, bunny, penguin, owl, hippo, crocodile, rhino, shark and
/// buffalo are [KidsAnimal.held]. The objects are sold — except the Qurʼān
/// stand, the mosque and the prayer mat, held because a child "wearing" a
/// sacred thing as an avatar is not something every family will want. The Ice
/// Cube is never sold: it is the reward for a streak freeze saving the streak.
const kidsAnimals = <KidsAnimal>[
  KidsAnimal('fox', '🦊'),
  KidsAnimal('panda', '🐼'),
  KidsAnimal('tiger', '🐯'),
  KidsAnimal('lion', '🦁'),
  KidsAnimal('koala', '🐨'),
  KidsAnimal('frog', '🐸'),
  KidsAnimal('horse', '🐴', also: ['🐎']),
  KidsAnimal('dolphin', '🐬'),
  KidsAnimal('camel', '🐪'),
  KidsAnimal('cow', '🐄'),
  KidsAnimal('bear', '🐻'),
  KidsAnimal('kangaroo', '🦘'),
  KidsAnimal('lioncub', 'avatar:lioncub'),
  KidsAnimal('bee', '🐝'),
  KidsAnimal('ant', '🐜'),
  KidsAnimal('cat', '🐱', held: true),
  KidsAnimal('bunny', '🐰', held: true),
  KidsAnimal('penguin', '🐧', held: true),
  KidsAnimal('owl', '🦉', held: true),
  KidsAnimal('monkey', '🐵'),
  KidsAnimal('elephant', '🐘'),
  KidsAnimal('sheep', '🐑'),
  KidsAnimal('spider', '🕷️'),
  KidsAnimal('hippo', '🦛', held: true),
  KidsAnimal('crocodile', '🐊', held: true),
  KidsAnimal('rhino', '🦏', held: true),
  KidsAnimal('shark', '🦈', held: true),
  KidsAnimal('goat', '🐐'),
  KidsAnimal('buffalo', '🐃', held: true),
  KidsAnimal('whale', '🐋'),
  KidsAnimal('wolf', '🐺'),
  // objects
  KidsAnimal('shield', 'avatar:shield'),
  KidsAnimal('sword', 'avatar:sword'),
  KidsAnimal('helmet', 'avatar:helmet'),
  KidsAnimal('tasbeeh', 'avatar:tasbeeh'),
  KidsAnimal('prayermat', 'avatar:prayermat', held: true),
  KidsAnimal('topi', 'avatar:topi'),
  KidsAnimal('dates', 'avatar:dates'),
  KidsAnimal('dallah', 'avatar:dallah'),
  KidsAnimal('tea', 'avatar:tea'),
  KidsAnimal('flask', 'avatar:flask'),
  KidsAnimal('lantern', 'avatar:lantern'),
  KidsAnimal('crescent', 'avatar:crescent'),
  KidsAnimal('palm', 'avatar:palm'),
  KidsAnimal('mosque', 'avatar:mosque', held: true),
  KidsAnimal('quran', 'avatar:quran', held: true),
  KidsAnimal('miswak', 'avatar:miswak'),
  KidsAnimal('zamzam', 'avatar:zamzam'),
  KidsAnimal('attar', 'avatar:attar'),
  KidsAnimal('icecube', 'avatar:icecube'),
];

/// Whether [avatar] names drawn art by id (`avatar:<id>`) rather than an emoji.
bool kidsIsArtKey(String avatar) => avatar.startsWith('avatar:');

/// The drawing for [avatar], or null when it has none and should keep showing
/// as an emoji.
///
/// Matched by exact value. The shop's 🐎 was once a separate, paid horse; it is
/// no longer sold (the horse is a free choice), so those who own it simply get
/// the drawn horse too.
KidsAnimal? kidsAnimalFor(String avatar) {
  for (final a in kidsAnimals) {
    if (a.emoji == avatar || a.also.contains(avatar)) return a;
  }
  return null;
}
