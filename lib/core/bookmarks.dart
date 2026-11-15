import '../data/mushaf.dart';
import 'settings.dart';

/// Pages and sūrahs as bookmarks. A page is kept as its first verse, so it's
/// still the same place in a muṣḥaf that numbers its pages differently.
extension PageSurahBookmarks on ProgressStore {
  bool isPageBookmarked(String script, int page) => bookmarkItems.any((b) =>
      b.kind == BookmarkKind.page && pageOfBookmark(script, b) == page);

  void togglePageBookmark(String script, int page) {
    final here = [
      for (final b in bookmarkItems)
        if (b.kind == BookmarkKind.page && pageOfBookmark(script, b) == page) b
    ];
    if (here.isNotEmpty) {
      removeBookmarks(here);
      return;
    }
    final (s, a) = MushafRepo.firstVerseOfPage(script, page);
    toggleBookmarkItem(Bookmark(BookmarkKind.page, s, a));
  }

  bool isSurahBookmarked(int surah) =>
      bookmarkItems.contains(Bookmark(BookmarkKind.surah, surah, 1));

  void toggleSurahBookmark(int surah) =>
      toggleBookmarkItem(Bookmark(BookmarkKind.surah, surah, 1));
}

/// The page a bookmark goes to in [script].
int pageOfBookmark(String script, Bookmark b) => b.kind == BookmarkKind.surah
    ? MushafRepo.surahPageSync(script, b.surah)
    : MushafRepo.pageForGlobalAyah(script, MushafRepo.globalAyahOf(b.surah, b.ayah));
