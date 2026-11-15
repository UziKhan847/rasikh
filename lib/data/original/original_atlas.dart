import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../core/display_rotation.dart';
import '../../core/perf_log.dart';
import '../mushaf.dart';
import 'binary_mushaf_reader.dart';
import 'mushaf_manifest_format.dart';
import 'mushaf_packs.dart';

/// A printed muṣḥaf's pages as atlases: one texture per page, plus one of the
/// shapes they share (`tool/gen_print_layout.py` and the atlas tools).
/// Only the pages around the reader are ever in memory (see [PageImageWindow]).

/// low: 10 px/mm, small screens and low-end devices; high: 16 px/mm, the rest.
enum OriginalTier { low, high }

/// The tier for a device. Lite mode or 4 GB of memory or less: low. Otherwise
/// by how many pixels a page gets: above 11 px/mm low would be upscaled.
OriginalTier originalTierFor({
  required bool lite,
  required int shortPx,
  required int longPx,
  int? ramMb,
}) {
  if (lite || (ramMb != null && ramMb <= 4096)) return OriginalTier.low;
  const pageWmm = 117.0, pageHmm = 197.0;
  final pxPerMm = math.min(shortPx / pageWmm, longPx / pageHmm);
  return pxPerMm > 11 ? OriginalTier.high : OriginalTier.low;
}

/// This device's tier.
Future<OriginalTier> originalTierOfDevice({required bool lite}) async {
  final d = ui.PlatformDispatcher.instance;
  final ui.Size size = d.displays.isNotEmpty
      ? d.displays.first.size
      : (d.implicitView?.physicalSize ?? const ui.Size(1080, 1920));
  return originalTierFor(
    lite: lite,
    shortPx: size.shortestSide.round(),
    longPx: size.longestSide.round(),
    ramMb: await deviceRamMb(),
  );
}

/// Where a set's files come from: a folder on this device (chosen, or
/// later downloaded — see [MushafPacks]).
abstract interface class OriginalAtlasSource {
  Future<Uint8List> read(String path);
}

class FileOriginalSource implements OriginalAtlasSource {
  final String root;
  const FileOriginalSource(this.root);

  @override
  Future<Uint8List> read(String path) => File('$root/$path').readAsBytes();
}

/// A print's files aren't on this device (or have gone).
class OriginalPackMissing implements Exception {
  final String script;
  const OriginalPackMissing(this.script);
  @override
  String toString() => '$script: no pack';
}

/// Keeps a window of decoded page images: every page some holder wants, and
/// nothing else once it's settled. As a swipe moves the window, the near side
/// loads first and the far side goes once that's done (a page further off goes
/// at once, so a jump can't double the memory). A few load at a time, nearest
/// first and the way the reader is heading before behind them; one that
/// finishes after it has left the window is disposed on arrival.
class PageImageWindow {
  /// Decodes running together: enough that a swipe's near page never queues
  /// behind the far ones, few enough not to crowd the device.
  static const maxLoads = 3;

  final Future<ui.Image> Function(int page) _load;
  PageImageWindow(this._load);

  final Map<Object, _Hold> _holds = {};
  final Map<int, ui.Image> _images = {};
  final Map<int, _Signal> _signals = {};
  final Set<int> _loading = {};
  final Set<int> _failed = {};

  /// Pages asked for by being on screen without an image: first in the queue.
  final Set<int> _asked = {};
  bool _closed = false;

  /// [page]'s image, if it's in memory. Don't keep it: it can be disposed at
  /// any swipe.
  ui.Image? imageOf(int page) => _images[page];

  /// Fires when [page]'s image arrives.
  Listenable signal(int page) => _signals.putIfAbsent(page, _Signal.new);

  /// The pages in memory (tests, logs).
  Iterable<int> get loaded => _images.keys;

  /// The pages being decoded now (tests).
  @visibleForTesting
  Set<int> get loading => _loading;

  /// The pages the holders want (tests).
  @visibleForTesting
  Set<int> get held => {
        for (final h in _holds.values)
          for (var p = h.first; p <= h.last; p++) p,
      };

  bool get isHeld => _holds.isNotEmpty;

  /// [owner] wants [first]..[last]; [focus] is what's on screen. A page that
  /// failed gets another try.
  void hold(Object owner, int first, int last, {required int focus}) {
    final was = _holds[owner];
    final dir = was == null || focus == was.focus
        ? (was?.dir ?? 1)
        : (focus > was.focus ? 1 : -1);
    _holds[owner] = _Hold(first, last, focus, dir);
    _failed.clear();
    _asked.clear();
    _sweepFar();
    _pump();
  }

  void release(Object owner) {
    _holds.remove(owner);
    _sweep();
  }

  /// [page] is on screen with no image: next in line, in a hold or not.
  void ask(int page) {
    if (_closed || _images.containsKey(page) || _failed.contains(page)) return;
    if (_asked.add(page)) _pump();
  }

  bool _wanted(int page) =>
      _asked.contains(page) ||
      _holds.values.any((h) => page >= h.first && page <= h.last);

  void _sweep() {
    _images.removeWhere((page, image) {
      if (_wanted(page)) return false;
      image.dispose();
      return true;
    });
  }

  /// Disposes what's more than a page outside every hold; those just outside
  /// wait for the loads under way ([_pump]).
  void _sweepFar() {
    _images.removeWhere((page, image) {
      if (_wanted(page) ||
          _holds.values.any((h) => page >= h.first - 1 && page <= h.last + 1)) {
        return false;
      }
      image.dispose();
      return true;
    });
  }

  int? _next() {
    for (final p in _asked) {
      if (!_images.containsKey(p) && !_loading.contains(p) && !_failed.contains(p)) return p;
    }
    int? best;
    var cost = 1 << 30;
    for (final h in _holds.values) {
      for (var p = h.first; p <= h.last; p++) {
        if (_images.containsKey(p) || _loading.contains(p) || _failed.contains(p)) continue;
        final d = p - h.focus;
        final c = d.abs() * 2 + (d == 0 || d.sign == h.dir ? 0 : 1);
        if (c < cost) {
          cost = c;
          best = p;
        }
      }
    }
    return best;
  }

  void _pump() {
    while (!_closed && _loading.length < maxLoads) {
      final p = _next();
      if (p == null) break;
      _loading.add(p);
      _loadOne(p);
    }
    if (_loading.isEmpty) _sweep();
  }

  Future<void> _loadOne(int p) async {
    try {
      final image = await _load(p);
      if (_closed || !_wanted(p)) {
        image.dispose();
      } else {
        _images[p] = image;
        _signals[p]?.ping();
      }
    } catch (e) {
      debugPrint('muṣḥaf page $p: $e');
      _failed.add(p);
    } finally {
      _loading.remove(p);
      _pump();
    }
  }

  void dispose() {
    _closed = true;
    _holds.clear();
    _asked.clear();
    _sweep();
    for (final s in _signals.values) {
      s.dispose();
    }
    _signals.clear();
  }

  /// Every signal, for what all pages wait on.
  void pingAll() {
    for (final s in _signals.values) {
      s.ping();
    }
  }
}

class _Hold {
  final int first, last, focus, dir;
  const _Hold(this.first, this.last, this.focus, this.dir);
}

class _Signal extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// The pages to keep for what's on screen: [first]..[last] (one page, or two
/// facing), and [reach] either side, within the book.
(int, int) originalWindow(int first, int last, int total, {int reach = 3}) =>
    (math.max(1, first - reach), math.min(total, last + reach));

/// What drawing a page needs beyond the manifest
/// (the pack's pages.json, from tool/gen_print_layout.py), in mm.
class OriginalPages {
  final double pitch, blockW;
  final Map<int, (double cx, double y0)> pages;
  final Map<int, List<double>> rows;
  final Map<int, int> attach;
  final Map<int, List<(int, int)>> words;
  OriginalPages._(this.pitch, this.blockW, this.pages, this.rows, this.attach, this.words);

  factory OriginalPages.parse(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return OriginalPages._(
      (m['pitch'] as num).toDouble(),
      (m['blockW'] as num).toDouble(),
      {
        for (final e in (m['pages'] as Map<String, dynamic>).entries)
          int.parse(e.key): (
            ((e.value as List)[0] as num).toDouble(),
            ((e.value as List)[1] as num).toDouble(),
          ),
      },
      {
        for (final e in (m['rows'] as Map<String, dynamic>).entries)
          int.parse(e.key): [for (final v in e.value as List) (v as num).toDouble()],
      },
      {
        for (final e in (m['attach'] as Map<String, dynamic>).entries)
          int.parse(e.key): e.value as int,
      },
      {
        for (final e in (m['words'] as Map<String, dynamic>).entries)
          int.parse(e.key): [
            for (final v in e.value as List)
              ((v as List)[0] as int, v[1] as int),
          ],
      },
    );
  }

  /// The block's shape, width ÷ height: 15 lines.
  double get ratio => blockW / (15 * pitch);
}

/// One tier of the print: its manifest and shared atlas (kept while any
/// screen holds pages) and the window of page atlases.
class OriginalAtlas {
  final OriginalTier tier;
  final String script;
  final double pxPerMm;
  final OriginalAtlasSource _source;
  final MushafReader reader;
  final OriginalPages pages;

  /// The classic āyah circle on the shared atlas, and where the print's
  /// frame has its opening's centre (signs.json; Old Madani's only).
  final ({double x, double y, double w, double h, double cx, double cy})? classicCircle;

  /// The clean ۞ and sajdah sign on the shared atlas, drawn in place of the
  /// print's on the page images (signs.json). Without them (New Madani,
  /// whose signs are already the font's), the page's own are drawn.
  final ({double x, double y, double w, double h})? hizbSign, sajdahSign;
  late final PageImageWindow window = PageImageWindow(_loadPage);

  OriginalAtlas._(this.tier, this.script, this.pxPerMm, this._source, this.reader, this.pages,
      this.classicCircle, this.hizbSign, this.sajdahSign);

  static final Map<(String, OriginalTier), Future<OriginalAtlas>> _open = {};

  /// Each print's scale at each tier, px per mm: New Madani's pages are
  /// larger, so its tiers give the same page sizes in pixels as Old Madani's.
  static const pxPerMmOf = {
    kOldMadani: {OriginalTier.high: 16.0, OriginalTier.low: 10.0},
    kNewMadaniPrint: {OriginalTier.high: 13.6, OriginalTier.low: 8.5},
  };

  /// [script]'s print at [tier], or the tier its pack has; its files are
  /// read once. Throws [OriginalPackMissing] without a pack.
  static Future<OriginalAtlas> open(String script, OriginalTier tier) {
    final pack = MushafPacks.of(script);
    if (pack == null) return Future.error(OriginalPackMissing(script));
    final t = pack.best(tier);
    final key = (script, t);
    final f = _open[key] ??= _read(script, pack, t);
    // A failed read isn't kept: the next try reads again.
    f.then<void>((_) {}, onError: (Object _) {
      if (identical(_open[key], f)) _open.remove(key);
    });
    return f;
  }

  /// Forgets what's been read: the pack's folder has changed.
  static void reset() => _open.clear();

  /// How a sprite takes its colour. The sprites are black with the shape in
  /// alpha; whether the image counts as source or destination in
  /// `drawRawAtlas`'s blend isn't the same on every renderer, so it's tried
  /// once on this one: red on a black sprite, and which of the two gives red.
  static ui.BlendMode atlasBlend = ui.BlendMode.dstIn;

  static Future<void> _probeBlend() async {
    final dot = ui.PictureRecorder();
    ui.Canvas(dot).drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), ui.Paint()..color = const ui.Color(0xFF000000));
    final picture = dot.endRecording();
    final sprite = await picture.toImage(1, 1);
    picture.dispose();
    final out = ui.PictureRecorder();
    ui.Canvas(out).drawRawAtlas(
        sprite,
        Float32List.fromList([1, 0, 0, 0]),
        Float32List.fromList([0, 0, 1, 1]),
        Int32List.fromList([0xFFFF0000]),
        ui.BlendMode.srcIn,
        null,
        ui.Paint());
    final result = out.endRecording();
    final image = await result.toImage(1, 1);
    result.dispose();
    final data = await image.toByteData();
    final red = data != null && data.getUint8(0) > 128;
    atlasBlend = red ? ui.BlendMode.srcIn : ui.BlendMode.dstIn;
    image.dispose();
    sprite.dispose();
  }

  static Future<OriginalAtlas> _read(String script, MushafPack pack, OriginalTier tier) async {
    await _probeBlend();
    final root = pack.root;
    final source = FileOriginalSource(pack.tierDir(tier));
    final bytes = await source.read('mushaf_manifest.bin');
    final reader = MushafReader(bytes);
    final pages = OriginalPages.parse(await File('$root/pages.json').readAsString());
    final px = pxPerMmOf[script]![tier]!;
    final signsFile = File('$root/signs.json');
    if (!signsFile.existsSync()) {
      return OriginalAtlas._(tier, script, px, source, reader, pages, null, null, null);
    }
    final signs = jsonDecode(await signsFile.readAsString()) as Map<String, dynamic>;
    final circle = signs[tier.name] as Map<String, dynamic>;
    ({double x, double y, double w, double h}) signAt(String name) {
      final r = [for (final v in circle[name] as List) (v as num).toDouble()];
      return (x: r[0], y: r[1], w: r[2], h: r[3]);
    }

    final rect = [for (final v in circle['rect'] as List) (v as num).toDouble()];
    final centre = [for (final v in circle['frameCentre'] as List) (v as num).toDouble()];
    return OriginalAtlas._(tier, script, px,
        source, reader, pages,
        (x: rect[0], y: rect[1], w: rect[2], h: rect[3], cx: centre[0], cy: centre[1]),
        signAt('hizb'),
        signAt('sajdah'));
  }

  ui.Image? _shared;
  bool _sharedLoading = false;

  /// The atlas of shapes the pages share, once loaded.
  ui.Image? get shared => _shared;

  Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  /// Whether pages about to be shown use the classic circle: their data is
  /// prepared for it as their image arrives.
  bool warmClassic = false;

  Future<ui.Image> _loadPage(int page) async {
    final sw = kMushafPerf ? (Stopwatch()..start()) : null;
    final image = await _decode(await _source.read('pages/$page.webp'));
    if (sw != null) PerfLog.log('old madani p.$page ready in ${sw.elapsedMilliseconds} ms');
    // The page's data too, now and not in the frame that first shows it.
    // Only with the text in memory: without it the page's words have no tokens.
    if (MushafRepo.isLoaded(script)) {
      final data = kMushafPerf ? (Stopwatch()..start()) : null;
      dataOf(page, classic: warmClassic);
      if (data != null) {
        PerfLog.log('old madani p.$page data in ${data.elapsedMicroseconds} µs');
      }
    }
    return image;
  }

  /// [owner] wants the pages on screen ([first]..[last]) and [reach] around.
  void hold(Object owner, int first, int last, {int reach = 3}) {
    final total = reader.pageCount;
    final (a, b) = originalWindow(first, last, total, reach: reach);
    window.hold(owner, a, b, focus: first);
    if (_shared == null && !_sharedLoading) {
      _sharedLoading = true;
      _source.read('shared.webp').then(_decode).then((image) {
        _sharedLoading = false;
        if (window.isHeld) {
          _shared = image;
          window.pingAll();
        } else {
          image.dispose();
        }
      }, onError: (Object e) {
        _sharedLoading = false;
        debugPrint('muṣḥaf shared atlas: $e');
      });
    }
  }

  /// Completes once [page] can be drawn (held by the caller); false if it
  /// couldn't be loaded.
  Future<bool> whenReady(int page, {int maxMs = 5000}) async {
    for (var i = 0; i < maxMs / 10; i++) {
      if (window.imageOf(page) != null && _shared != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return false;
  }

  /// [owner] is done: with no one left, everything is freed.
  void release(Object owner) {
    window.release(owner);
    if (!window.isHeld) {
      _shared?.dispose();
      _shared = null;
    }
  }

  // ── pages' data ──

  final Map<int, OriginalPageData> _data = {};

  /// [page]'s sprites and where its words are (kept for a few pages; there's
  /// nothing of the GPU's in them).
  OriginalPageData dataOf(int page, {bool classic = false}) {
    final key = page * 2 + (classic ? 1 : 0);
    final hit = _data.remove(key);
    if (hit != null) return _data[key] = hit;
    final d = OriginalPageData._(this, page, classic);
    // (Room for the window, with either circle after a switch.)
    while (_data.length >= 16) {
      _data.remove(_data.keys.first);
    }
    return _data[key] = d;
  }
}

/// One page, in its own pixels with the block's top-left at (0, 0): every
/// sprite, the token it belongs to and the line it's on.
class OriginalPageData {
  final int page;
  late final double blockW, pitch;

  /// Page sprites and shared-atlas instances, in parallel lists. x, y: where
  /// the sprite's top-left goes.
  late final Float32List pageRects, sharedRects;
  late final Float32List pageX, pageY, sharedX, sharedY, sharedScale;
  late final Int32List pageToken, sharedToken, pageRow, sharedRow;

  /// Drawn in the ornament colour: the border and the āyah frames.
  late final Uint8List sharedOrnament;

  /// The lines' middles.
  late final List<double> rowCentres;

  /// Whether the page's lines are its own (the opening pages), not the grid.
  late final bool opening;

  /// Each token's horizontal extent and its line.
  final Map<int, ({double left, double right, int row})> tokens = {};

  /// Each line's tokens.
  final Map<int, List<int>> rowTokens = {};

  /// The tokens in reading order.
  late final List<int> order;

  OriginalPageData._(OriginalAtlas atlas, this.page, bool classic) {
    final mm = atlas.pxPerMm;
    final info = atlas.pages;
    blockW = info.blockW * mm;
    pitch = info.pitch * mm;
    final manifest = atlas.reader.page(page);
    final (cx, y0) = info.pages[page]!;
    final open = info.rows[page];
    opening = open != null;
    final dx = blockW / 2 - cx * mm;
    final double dy;
    if (open != null) {
      dy = 15 * pitch / 2 - (open.first + open.last) * mm / 2;
      rowCentres = [for (final c in open) c * mm + dy];
    } else {
      dy = pitch / 2 - y0 * mm;
      rowCentres = [for (var k = 0; k < 15; k++) (k + .5) * pitch];
    }

    int rowOf(double y) {
      if (!opening) return (y / pitch).floor().clamp(0, 14);
      var best = 0;
      for (var i = 1; i < rowCentres.length; i++) {
        if ((rowCentres[i] - y).abs() < (rowCentres[best] - y).abs()) best = i;
      }
      return best;
    }

    final script = atlas.script;
    int tokenOf(int id) {
      final s = id & 0x7F, v = (id >> 7) & 0x1FF, t = (id >> 16) & 0xF, i = (id >> 20) & 0x7FF;
      if (v == 0) return -1;
      final g = MushafRepo.globalAyahOf(s, v);
      return switch (t) {
        0 => MushafRepo.tokenOf(script, g, info.words[g]?[i - 1].$1 ?? i - 1),
        1 => MushafRepo.tokenOf(script, g, -1),
        _ => MushafRepo.tokenOf(script, g, info.attach[id] ?? 0),
      };
    }

    void place(int token, double left, double right, int row, {int? lastToken}) {
      for (var t = token; t <= (lastToken ?? token); t++) {
        final was = tokens[t];
        tokens[t] = was == null
            ? (left: left, right: right, row: row)
            : (left: math.min(was.left, left), right: math.max(was.right, right), row: was.row);
        if (was == null) (rowTokens[row] ??= []).add(t);
      }
    }

    // The ۞ and the sajdah sign come from the shared atlas: their page sprites
    // only say where.
    const sajdah = 3, hizb = 5;
    final cleanSigns = atlas.hizbSign != null && atlas.sajdahSign != null;
    bool isSign(int id) =>
        cleanSigns && switch ((id >> 16) & 0xF) { sajdah || hizb => true, _ => false };
    final allSprites = manifest.sprites;
    final sprites = [for (final r in allSprites) if (!isSign(r.id)) r];
    final signs = [for (final r in allSprites) if (isSign(r.id)) r];
    final n = sprites.length;
    pageRects = Float32List(n * 4);
    pageX = Float32List(n);
    pageY = Float32List(n);
    pageToken = Int32List(n);
    pageRow = Int32List(n);
    for (var i = 0; i < n; i++) {
      final r = sprites[i];
      final x = r.left + dx, y = r.top + dy;
      pageRects
        ..[i * 4] = r.sprX.toDouble()
        ..[i * 4 + 1] = r.sprY.toDouble()
        ..[i * 4 + 2] = (r.sprX + r.width).toDouble()
        ..[i * 4 + 3] = (r.sprY + r.height).toDouble();
      pageX[i] = x;
      pageY[i] = y;
      final row = rowOf(y + r.height / 2);
      pageRow[i] = row;
      final token = tokenOf(r.id);
      pageToken[i] = token;
      if (token >= 0 && (r.id >> 16) & 0xF == 0) {
        final g = MushafRepo.globalAyahOf(r.id & 0x7F, (r.id >> 7) & 0x1FF);
        final span = atlas.pages.words[g]?[((r.id >> 20) & 0x7FF) - 1];
        place(token, x, x + r.width, row,
            lastToken: span == null ? null : token + span.$2 - span.$1);
      }
    }

    final shared = atlas.reader.shared;
    final instances = manifest.instances;
    final m = instances.length + signs.length;
    sharedRects = Float32List(m * 4);
    sharedX = Float32List(m);
    sharedY = Float32List(m);
    sharedScale = Float32List(m);
    sharedToken = Int32List(m);
    sharedRow = Int32List(m);
    sharedOrnament = Uint8List(m);
    // A marker's row is its frame's: its digits stand a little off the line.
    final frameRow = <int, int>{};
    for (final e in instances.indexed) {
      final (i, q) = e;
      final s = shared[q.shared];
      if (s.kind == SharedKind.ayahFrame) {
        frameRow[q.id] = rowOf(q.y + dy + s.height * q.scale / 2);
      }
      sharedScale[i] = q.scale;
      final c = classic ? atlas.classicCircle : null;
      if (c != null && s.kind == SharedKind.ayahFrame) {
        // The classic circle, its opening where the frame's is: the digits
        // sit in it the same way.
        sharedRects
          ..[i * 4] = c.x
          ..[i * 4 + 1] = c.y
          ..[i * 4 + 2] = c.x + c.w
          ..[i * 4 + 3] = c.y + c.h;
        sharedX[i] = q.x + dx + (c.cx - c.w / 2) * q.scale;
        sharedY[i] = q.y + dy + (c.cy - c.h / 2) * q.scale;
      } else {
        sharedRects
          ..[i * 4] = s.sprX.toDouble()
          ..[i * 4 + 1] = s.sprY.toDouble()
          ..[i * 4 + 2] = (s.sprX + s.width).toDouble()
          ..[i * 4 + 3] = (s.sprY + s.height).toDouble();
        sharedX[i] = q.x + dx;
        sharedY[i] = q.y + dy;
      }
      sharedOrnament[i] =
          s.kind == SharedKind.border || s.kind == SharedKind.ayahFrame ? 1 : 0;
    }
    for (final e in instances.indexed) {
      final (i, q) = e;
      final s = shared[q.shared];
      final row = frameRow[q.id] ?? rowOf(q.y + dy + s.height * q.scale / 2);
      sharedRow[i] = row;
      final token = tokenOf(q.id);
      sharedToken[i] = token;
      if (token >= 0) {
        place(token, sharedX[i],
            sharedX[i] + (sharedRects[i * 4 + 2] - sharedRects[i * 4]) * q.scale, row);
      }
    }
    // The signs, centred where the print's stood, on the same word and line.
    for (final e in signs.indexed) {
      final (k, r) = e;
      final i = instances.length + k;
      final c = (r.id >> 16) & 0xF == hizb ? atlas.hizbSign! : atlas.sajdahSign!;
      sharedRects
        ..[i * 4] = c.x
        ..[i * 4 + 1] = c.y
        ..[i * 4 + 2] = c.x + c.w
        ..[i * 4 + 3] = c.y + c.h;
      sharedX[i] = r.left + dx + (r.width - c.w) / 2;
      sharedY[i] = r.top + dy + (r.height - c.h) / 2;
      sharedScale[i] = 1;
      sharedToken[i] = tokenOf(r.id);
      sharedRow[i] = rowOf(r.top + dy + r.height / 2);
    }
    order = tokens.keys.toList()..sort();
  }
}
