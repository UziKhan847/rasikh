import 'package:flutter/material.dart';

import '../../data/kids_avatars.dart';

/// The face an unknown `avatar:` key falls back to (the default avatar's).
const kKidsDefaultAvatarFace = '🦊';

/// An avatar's face: the drawn animal when it has one (see [kidsAnimals]), the
/// plain emoji when it does not.
///
/// Takes the emoji a profile stores rather than an animal id, so it can stand
/// in for any `Text(profile.avatar)` — and for the shop's `Text(item.emoji)`,
/// where a frame's ✨ or a theme's 🌊 has no drawn art and simply stays an emoji.
///
/// [size] is the emoji's font size, as it always was at these call sites; the
/// drawn face takes about the space that emoji would, so a layout built for
/// one holds for the other.
class KidsAvatarFace extends StatelessWidget {
  final String avatar;
  final double size;
  const KidsAvatarFace(this.avatar, {super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    // An `avatar:<id>` with no art (one a newer version added, say) shows the
    // default face — never the key itself as text.
    final animal = kidsAnimalFor(avatar) ??
        (kidsIsArtKey(avatar) ? kidsAnimalFor(kKidsDefaultAvatarFace) : null);
    if (animal == null) return Text(avatar, style: TextStyle(fontSize: size));
    final box = size * 1.15;
    return SizedBox(
      key: ValueKey('kidsAvatar.${animal.id}'),
      width: box,
      height: box,
      // The emoji it replaces is read aloud as an animal; the drawing is
      // decoration next to whatever labels it, so it stays out of the tree.
      // Decoded at the size it is shown (a 17 px nav face used to decode the
      // whole 256 or 384 px image), then fitted to the box.
      child: Image.asset(
        animal.asset,
        excludeFromSemantics: true,
        width: box,
        height: box,
        fit: BoxFit.contain,
        cacheWidth: (box * MediaQuery.devicePixelRatioOf(context)).ceil(),
      ),
    );
  }
}
