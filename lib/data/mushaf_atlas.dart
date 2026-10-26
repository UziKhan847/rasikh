import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The muṣḥaf's premade glyph atlas for one script: every glyph its text
/// uses, rasterised once into a few textures, and every word shaped once
/// into glyphs and positions — generated offline by
/// `tool/mushaf_atlas/gen_atlas.py` (HarfBuzz, the shaper Flutter uses, so
/// the lines come out as Flutter would draw them; the generator checks every
/// line's width against Flutter's own measurements).
///
/// A page's text is then drawn with `Canvas.drawRawAtlas` — no shaping and
/// no text rendering at runtime, which on a Pixel 7 Pro cost 3–13 ms per
/// line to shape and 17–28 ms of raster time per frame to draw two pages.
///
/// Indexed by the script's token stream (`MushafRepo`'s, which the file is
/// checked against when it loads): token → its word shape, the gap to the
/// next token, and the tajwīd rule of each of its glyphs.
class MushafAtlas {
  final int upem;
  final int ascender, descender; // font units (descender negative)

  /// A plain space's advance, font units (verse cards re-wrap words, so a
  /// word that ended a muṣḥaf line needs one).
  final int space;
  final List<AtlasTier> tiers;
  final Uint16List wordAdvance;
  final Uint32List wordGlyphStart;
  final Uint16List glyphId; // atlas glyph per word glyph
  final Int16List glyphX, glyphY; // font units from the word's left/baseline
  final Uint16List tokenWord;
  final Int16List tokenGap; // font units to the next token (0 at line end)
  final Uint32List tajwidStart;
  final Uint8List tajwidPairs; // (glyph index within word, rule) pairs

  /// Its lines come justified (format 3: the Madani muṣḥaf, set by
  /// digitalkhatt's engine): a narrow line is meant narrow, so only
  /// rounding is left to spread.
  final bool justified;

  MushafAtlas._(
    this.upem,
    this.ascender,
    this.descender,
    this.space,
    this.tiers,
    this.wordAdvance,
    this.wordGlyphStart,
    this.glyphId,
    this.glyphX,
    this.glyphY,
    this.tokenWord,
    this.tokenGap,
    this.tajwidStart,
    this.tajwidPairs,
    this.justified,
  );

  static final Map<String, MushafAtlas> _loaded = {};

  /// Lite mode: draw from the standard sheets only — the larger ones cost
  /// GPU memory that old phones lack. [capVersion] changes with it, so lines
  /// built under the other setting rebuild (see RenderMushafLine.spec).
  static bool get smallOnly => _smallOnly;
  static bool _smallOnly = false;
  static int capVersion = 0;
  static void setSmallOnly(bool v) {
    if (v == _smallOnly) return;
    _smallOnly = v;
    capVersion++;
    if (v) {
      for (final a in _loaded.values) {
        a.releaseLarge();
      }
    }
  }
  static final Map<String, Future<MushafAtlas?>> _loading = {};

  /// Off in tests that exercise the text path.
  @visibleForTesting
  static bool debugDisabled = false;

  static String _norm(String s) => s == 'indopak' ? 'indopak' : 'uthmani';

  /// The loaded atlas for [script], or null (not loaded, missing, or out of
  /// step with the text — the muṣḥaf then shapes text as before).
  static MushafAtlas? of(String script) =>
      debugDisabled ? null : _loaded[_norm(script)];

  /// Loads [script]'s atlas (once) and its standard-size sheets. [tokens] is
  /// the script's token stream; an atlas built from different text is
  /// refused.
  static Future<MushafAtlas?> load(String script, List<String> tokens) {
    final s = _norm(script);
    return _loading[s] ??= _load(s, tokens).then((a) {
      if (a != null) _loaded[s] = a;
      return a;
    });
  }

  static Future<MushafAtlas?> _load(String s, List<String> tokens) async {
    try {
      final raw = await rootBundle.load('assets/quran/atlas/$s.bin');
      // A fresh, aligned copy: the typed views below need it.
      final bytes = Uint8List.fromList(
        raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
      );
      final a = _parse(s, bytes);
      if (a.tokenWord.length != tokens.length ||
          _fnv1a(tokens) != _crc(bytes)) {
        debugPrint('muṣḥaf atlas $s: built from different text — not used');
        return null;
      }
      await a.tiers.first.load();
      return a;
    } catch (e) {
      debugPrint('muṣḥaf atlas $s: $e — not used');
      return null;
    }
  }

  static int _crc(Uint8List b) =>
      ByteData.sublistView(b).getUint32(18, Endian.little);

  static int _fnv1a(List<String> tokens) {
    var h = 0x811C9DC5;
    void add(int u) {
      h ^= u;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }

    for (var i = 0; i < tokens.length; i++) {
      if (i > 0) add(0x0A);
      final t = tokens[i];
      for (var j = 0; j < t.length; j++) {
        add(t.codeUnitAt(j));
      }
    }
    return h;
  }

  static MushafAtlas _parse(String script, Uint8List bytes) {
    final d = ByteData.sublistView(bytes);
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'MQA1') {
      throw const FormatException('not a muṣḥaf atlas');
    }
    var o = 4;
    int u8() => d.getUint8(o++);
    int u16() {
      final v = d.getUint16(o, Endian.little);
      o += 2;
      return v;
    }

    int i16() {
      final v = d.getInt16(o, Endian.little);
      o += 2;
      return v;
    }

    int u32() {
      final v = d.getUint32(o, Endian.little);
      o += 4;
      return v;
    }

    void align() => o = (o + 3) & ~3;
    Uint8List u8s(int n) {
      final v = bytes.buffer.asUint8List(o, n);
      o += n;
      return v;
    }

    Uint16List u16s(int n) {
      final v = bytes.buffer.asUint16List(o, n);
      o += n * 2;
      return v;
    }

    Int16List i16s(int n) {
      final v = bytes.buffer.asInt16List(o, n);
      o += n * 2;
      return v;
    }

    Uint32List u32s(int n) {
      final v = bytes.buffer.asUint32List(o, n);
      o += n * 4;
      return v;
    }

    final version = u16();
    final upem = u16(), asc = i16(), desc = i16();
    final space = u16(); // gaps are stored per token; this is for re-wraps
    final tokenCount = u32();
    u32(); // text checksum (see _crc)
    final glyphCount = u32();
    final wordCount = u32();
    final tierCount = u8();
    final tierHeads = <(int, List<(int, int)>)>[];
    for (var t = 0; t < tierCount; t++) {
      final em = u16();
      final n = u8();
      tierHeads.add((em, [for (var i = 0; i < n; i++) (u16(), u16())]));
    }
    final tiers = <AtlasTier>[];
    for (var t = 0; t < tierCount; t++) {
      align();
      final sheet = u8s(glyphCount);
      align();
      final x = u16s(glyphCount);
      align();
      final y = u16s(glyphCount);
      align();
      final w = u16s(glyphCount);
      align();
      final h = u16s(glyphCount);
      align();
      final left = i16s(glyphCount);
      align();
      final top = i16s(glyphCount);
      align();
      final (em, sheets) = tierHeads[t];
      tiers.add(
        AtlasTier._(script, t, em, sheets.length, sheet, x, y, w, h, left, top),
      );
    }
    align();
    final adv = u16s(wordCount);
    align();
    final starts = u32s(wordCount + 1);
    final n = u32();
    final gid = u16s(n);
    align();
    final gx = i16s(n);
    align();
    final gy = i16s(n);
    align();
    final tokWord = u16s(tokenCount);
    align();
    final tokGap = i16s(tokenCount);
    align();
    final tjStart = u32s(tokenCount + 1);
    final pairs = u8s(tjStart[tokenCount] * 2);
    return MushafAtlas._(
      upem,
      asc,
      desc,
      space,
      tiers,
      adv,
      starts,
      gid,
      gx,
      gy,
      tokWord,
      tokGap,
      tjStart,
      pairs,
      version >= 3,
    );
  }

  /// The tier to draw at [pxPerEm] (font size × device pixel ratio): the
  /// smallest whose glyphs are at least that big, else the largest.
  int tierFor(double pxPerEm) {
    if (_smallOnly) return 0;
    for (var i = 0; i < tiers.length; i++) {
      if (tiers[i].em * 1.25 >= pxPerEm) return i;
    }
    return tiers.length - 1;
  }

  /// Frees the larger sheets (the muṣḥaf closed); they load again on use.
  void releaseLarge() {
    for (final t in tiers.skip(1)) {
      t.release();
    }
  }
}

/// One resolution of the atlas: where each glyph sits in which sheet.
class AtlasTier {
  final String script;
  final int index;
  final int em; // px per em the glyphs were drawn at
  final int sheetCount;
  final Uint8List sheet; // 255 = no ink
  final Uint16List x, y, w, h;
  final Int16List left, top; // bearings, px (top: above the baseline)

  AtlasTier._(
    this.script,
    this.index,
    this.em,
    this.sheetCount,
    this.sheet,
    this.x,
    this.y,
    this.w,
    this.h,
    this.left,
    this.top,
  );

  List<ui.Image>? _images;
  Future<void>? _loading;

  /// The decoded sheets, once [load] has finished.
  List<ui.Image>? get images => _images;

  Future<void> load() => _loading ??= () async {
    final out = <ui.Image>[];
    for (var i = 0; i < sheetCount; i++) {
      final data = await rootBundle.load(
        'assets/quran/atlas/${script}_${em}_$i.png',
      );
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      out.add((await codec.getNextFrame()).image);
      codec.dispose();
    }
    _images = out;
  }();

  void release() {
    final imgs = _images;
    _images = null;
    _loading = null;
    if (imgs != null) {
      for (final i in imgs) {
        i.dispose();
      }
    }
  }
}
