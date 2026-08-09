import 'audio.dart';
import '../data/quran.dart';

/// The reciters offered for bulk offline download on the Downloads screen.
/// Shaykh Khalifah Al-Tunaiji's recitation is deliberately excluded: it is
/// served only by EveryAyah.com, which has not yet responded to confirm
/// bulk/offline redistribution is permitted — unlike Al-ʿAfāsī/Al-Ḥuṣarī,
/// whose audio is republished through Quran Foundation's API under terms
/// this app already tracks (see `_FetchLog` in audio.dart). Tunaiji
/// recitation still streams normally and can still be downloaded one sūrah
/// at a time from the reader; it just isn't offered here for proactive bulk
/// download.
const downloadableReciters = ['alafasy', 'husary'];

enum DlState { none, partial, full }

DlState classifyDl(int have, int total) {
  if (total <= 0 || have <= 0) return DlState.none;
  return have >= total ? DlState.full : DlState.partial;
}

/// Per-surah download status for [reciter]'s verse audio.
Future<Map<int, DlState>> reciterDownloadStates(String reciter) async {
  final meta = await QuranRepo.meta();
  final counts = await AyahAudio.instance.downloadedCounts(reciter);
  return {
    for (final m in meta) m.n: classifyDl(counts[m.n] ?? 0, m.ayahs),
  };
}

/// Per-surah download status for word-by-word audio. Word totals come from
/// tokenizing the bundled text (there's no precomputed word-count asset),
/// same as the reader — [QuranRepo.words] caches each surah after its first
/// call, so this is only ever slow once per app run.
Future<Map<int, DlState>> wbwDownloadStates() async {
  final meta = await QuranRepo.meta();
  final counts = await WbwAudio.instance.downloadedCounts();
  final out = <int, DlState>{};
  for (final m in meta) {
    final words = await QuranRepo.words(m.n, 'uthmani');
    final total = words.fold(0, (a, w) => a + w.length);
    out[m.n] = classifyDl(counts[m.n] ?? 0, total);
  }
  return out;
}

/// Word count per sūrah, aligned with the word-by-word audio numbering —
/// shared by the Downloads screen for both status classification and
/// building the per-ayah word counts a wbw download needs.
Future<List<int>> wbwWordsPerAyah(int surah) async {
  final words = await QuranRepo.words(surah, 'uthmani');
  return [for (final w in words) w.length];
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  return '${(bytes / kb).ceil()} KB';
}
