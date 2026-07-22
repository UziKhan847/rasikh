/// Verse-of-the-day pool, shared by the mobile home and the desktop dashboard.
/// Picked deterministically by calendar day so everyone sees the same verse.
class Votd {
  final String ar; // Arabic text
  final String ref; // e.g. "Al-Fātiḥah · 1:1"
  final int s; // surah (for tap-to-play)
  final int v; // ayah
  const Votd(this.ar, this.ref, this.s, this.v);
}

const List<Votd> votdPool = [
  Votd('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ', 'Al-Fātiḥah · 1:1', 1, 1),
  Votd('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ', 'Al-Fātiḥah · 1:2', 1, 2),
  Votd('إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ', 'Al-Fātiḥah · 1:5', 1, 5),
  Votd('قُلْ هُوَ ٱللَّهُ أَحَدٌ', 'Al-Ikhlāṣ · 112:1', 112, 1),
  Votd('إِنَّ مَعَ ٱلْعُسْرِ يُسْرًا',
      'Ash-Sharḥ · 94:6', 94, 6),
  Votd('فَٱذْكُرُونِىٓ أَذْكُرْكُمْ',
      'Al-Baqarah · 2:152', 2, 152),
  Votd('وَقُل رَّبِّ زِدْنِى عِلْمًا',
      'Ṭā Hā · 20:114', 20, 114),
  Votd('وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ',
      'Al-Ḥadīd · 57:4', 57, 4),
];

Votd get verseOfDay {
  final day = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
  return votdPool[day % votdPool.length];
}
