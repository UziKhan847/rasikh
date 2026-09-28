/// The drawn animal faces that stand in for Kids Mode's emoji avatars.
///
/// A profile still stores an **emoji** in `KidsProfile.avatar` — that string is
/// the avatar's identity everywhere: it is what the shop's avatar unlocks match
/// by value (`kidsAvatarUnlock`), what `baseAvatar` remembers, and what every
/// saved profile already holds. This catalogue only says which emoji have
/// drawn art. Rendering swaps the emoji for the face
/// (`KidsAvatarFace`), so no saved profile needs migrating, nothing a child
/// bought moves, and an avatar with no art (the ant, the spider, the cow, the
/// whale) simply keeps showing its emoji.
///
/// The art is the design handoff's: 17 front-facing faces on a 120×120 box,
/// drawn so that every platform — including Linux, which has no colour emoji
/// font — renders them the same. They live in `assets/avatars/`, with the
/// design's C2PA provenance metadata stripped (179 KB down to 50 KB).
class KidsAnimal {
  /// The asset's file name, `assets/avatars/<id>.svg`.
  final String id;

  /// The emoji a profile stores when it wears this animal.
  final String emoji;

  /// Art that ships but is **not offered**: no picker tile and no shop item, so
  /// no child can wear it. The shop's avatar shelf is animals the Qurʼān names
  /// (see `kidsShopItems`), and these four are not — but selling an avatar is
  /// irreversible (a child spends gems and owns it), so the decision to offer
  /// one is made deliberately, in one line of `kidsShopItems`, not by default.
  final bool held;
  const KidsAnimal(this.id, this.emoji, {this.held = false});

  String get asset => 'assets/avatars/$id.svg';
}

/// Every animal with drawn art. Order is the design's: the nine it makes free,
/// then the eight it sells.
///
/// **Who owns what is not decided here.** The design prices camel and horse
/// free and elephant at 120; this app already sells camel (60), horse (90) and
/// elephant (80) as shop unlocks, and nothing a child has bought becomes free
/// or changes price — the design's art is adopted, its price list is not. The
/// picker's free choices stay the eight it always offered. Of the six the
/// design adds, monkey and sheep are sold (the Qurʼān names both); cat, bunny,
/// penguin and owl are [KidsAnimal.held].
const kidsAnimals = <KidsAnimal>[
  KidsAnimal('fox', '🦊'),
  KidsAnimal('panda', '🐼'),
  KidsAnimal('tiger', '🐯'),
  KidsAnimal('lion', '🦁'),
  KidsAnimal('koala', '🐨'),
  KidsAnimal('frog', '🐸'),
  KidsAnimal('horse', '🐴'),
  KidsAnimal('dolphin', '🐬'),
  KidsAnimal('camel', '🐪'),
  KidsAnimal('bee', '🐝'),
  KidsAnimal('cat', '🐱', held: true),
  KidsAnimal('bunny', '🐰', held: true),
  KidsAnimal('penguin', '🐧', held: true),
  KidsAnimal('owl', '🦉', held: true),
  KidsAnimal('monkey', '🐵'),
  KidsAnimal('elephant', '🐘'),
  KidsAnimal('sheep', '🐑'),
];

/// The drawn animal for [avatar], or null when it has none and should keep
/// showing as an emoji.
///
/// Matched by exact emoji, on purpose. The shop's 🐎 is a *different emoji*
/// from the picker's free 🐴, and it stays an emoji: giving it the horse's art
/// would let a child spend 90 gems on an avatar identical to the free one.
KidsAnimal? kidsAnimalFor(String avatar) {
  for (final a in kidsAnimals) {
    if (a.emoji == avatar) return a;
  }
  return null;
}
