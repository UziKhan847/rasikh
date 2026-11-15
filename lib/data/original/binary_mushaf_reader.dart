// READ SIDE ONLY (MUSF version 2 — see mushaf_manifest_format.dart).
//
//   MushafReader            LAZY — recommended. Holds the raw bytes and decodes
//                            one page on demand.
//   decodeMushafManifest()  EAGER — whole book at once, tooling/debug only.
//
// RENDERING a page (two drawRawAtlas calls, see mushaf_atlas_page.dart):
//   page sprites  (page atlas):   source = (sprX, sprY, W, H), placed 1:1 at (L, T)
//   instances     (shared atlas): source = shared[i] rect,
//                                 RSTransform(scale, 0, x, y)
//   identity of either = unpackSpriteId(id) -> surah / verse / index / type

import 'dart:collection';
import 'dart:typed_data';

import 'mushaf_manifest_format.dart';

// ===========================================================================
// TYPES
// ===========================================================================

/// A sprite in the page atlas, drawn 1:1.
class SpriteRecord {
  const SpriteRecord({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.sprX,
    required this.sprY,
  });

  final int id; // packed — unpackSpriteId(id) for surah/verse/index/type
  final int left; // page destination (px at this tier's scale)
  final int top;
  final int width; // also the atlas source width
  final int height; // also the atlas source height
  final int sprX; // atlas position
  final int sprY;
}

/// One sprite of the shared atlas.
class SharedSprite {
  const SharedSprite({
    required this.sprX,
    required this.sprY,
    required this.width,
    required this.height,
    required this.kind,
    required this.value,
  });

  final int sprX;
  final int sprY;
  final int width;
  final int height;
  final SharedKind kind;
  final int value; // the digit for SharedKind.digit
}

/// One placement of a shared sprite on a page.
class SpriteInstance {
  const SpriteInstance({
    required this.id,
    required this.shared,
    required this.scale,
    required this.x,
    required this.y,
  });

  final int id; // packed id of the element (ayah marker: frame + digits share it)
  final int shared; // index into MushafReader.shared
  final double scale; // uniform: sprite px -> page px
  final double x; // sprite top-left on the page (px)
  final double y;
}

/// One page: its page-atlas sprites, its shared instances, sizes.
class PageManifest {
  const PageManifest({
    required this.pageNum,
    required this.atlasWidth,
    required this.atlasHeight,
    required this.pageWidth,
    required this.pageHeight,
    required this.sprites,
    required this.instances,
  });

  final int pageNum;
  final int atlasWidth;
  final int atlasHeight;
  final int pageWidth; // px at this tier's scale
  final int pageHeight;
  final List<SpriteRecord> sprites;
  final List<SpriteInstance> instances;
}

// ===========================================================================
// LAZY READER
// ===========================================================================

class MushafReader {
  MushafReader(this._data) : _bytes = ByteData.sublistView(_data) {
    const e = kMushafManifestEndian;
    if (_bytes.getUint32(0, e) != kMushafManifestMagic) {
      throw const FormatException('Not a mushaf binary manifest');
    }
    final version = _bytes.getUint8(4);
    if (version != kMushafManifestVersion) {
      throw FormatException('Unsupported manifest version: $version');
    }
    _pageEntry = _bytes.getUint16(6, e);
    _pageCount = _bytes.getUint32(8, e);
    final recordCount = _bytes.getUint32(12, e);
    _sharedCount = _bytes.getUint16(20, e);
    _sharedEntry = _bytes.getUint16(22, e);
    _instanceSize = _bytes.getUint16(24, e);
    _recordSize = _bytes.getUint16(26, e);
    sharedAtlasWidth = _bytes.getUint16(28, e);
    sharedAtlasHeight = _bytes.getUint16(30, e);

    _pageTable = kHeaderSize + _sharedCount * _sharedEntry;
    _records = _pageTable + _pageCount * _pageEntry;
    _instances = _records + recordCount * _recordSize;

    shared = List<SharedSprite>.generate(_sharedCount, (i) {
      final o = kHeaderSize + i * _sharedEntry;
      return SharedSprite(
        sprX: _bytes.getUint16(o, e),
        sprY: _bytes.getUint16(o + 2, e),
        width: _bytes.getUint16(o + 4, e),
        height: _bytes.getUint16(o + 6, e),
        kind: SharedKind.values[_bytes.getUint8(o + 8)],
        value: _bytes.getUint8(o + 9),
      );
    }, growable: false);

    _indexByPageNum = HashMap<int, int>();
    for (var i = 0; i < _pageCount; i++) {
      _indexByPageNum[_bytes.getUint16(_pageTable + i * _pageEntry + 6, e)] = i;
    }
  }

  // ignore: unused_field
  final Uint8List _data; // kept alive so _bytes stays valid
  final ByteData _bytes;
  late final int _pageEntry, _pageCount, _sharedCount, _sharedEntry;
  late final int _instanceSize, _recordSize;
  late final int _pageTable, _records, _instances;
  late final Map<int, int> _indexByPageNum;

  /// The shared atlas' sprites (border, basmala, سورة, ayah frame, ٠-٩).
  late final List<SharedSprite> shared;
  late final int sharedAtlasWidth;
  late final int sharedAtlasHeight;

  int get pageCount => _pageCount;
  Iterable<int> get pageNumbers => _indexByPageNum.keys;

  /// Page canvas size in px at this tier's scale, without decoding.
  (int width, int height) pageSize(int pageNum) {
    final t = _tableOffset(pageNum);
    return (
      _bytes.getUint16(t + 12, kMushafManifestEndian),
      _bytes.getUint16(t + 14, kMushafManifestEndian),
    );
  }

  /// Decodes ONE page on demand. Hold the result while the page is on
  /// screen; don't call this every frame.
  PageManifest page(int pageNum) {
    const e = kMushafManifestEndian;
    final t = _tableOffset(pageNum);
    final firstRec = _bytes.getUint32(t, e);
    final recCount = _bytes.getUint16(t + 4, e);
    final firstInst = _bytes.getUint32(t + 16, e);
    final instCount = _bytes.getUint16(t + 20, e);

    final sprites = List<SpriteRecord>.generate(recCount, (k) {
      final o = _records + (firstRec + k) * _recordSize;
      return SpriteRecord(
        id: _bytes.getUint32(o, e),
        left: _bytes.getUint16(o + 4, e),
        top: _bytes.getUint16(o + 6, e),
        width: _bytes.getUint16(o + 8, e),
        height: _bytes.getUint16(o + 10, e),
        sprX: _bytes.getUint16(o + 12, e),
        sprY: _bytes.getUint16(o + 14, e),
      );
    }, growable: false);

    final instances = List<SpriteInstance>.generate(instCount, (k) {
      final o = _instances + (firstInst + k) * _instanceSize;
      return SpriteInstance(
        id: _bytes.getUint32(o, e),
        shared: _bytes.getUint16(o + 4, e),
        scale: _bytes.getUint16(o + 6, e) / kInstanceScaleOne,
        x: _bytes.getInt16(o + 8, e) / kInstancePosUnits,
        y: _bytes.getInt16(o + 10, e) / kInstancePosUnits,
      );
    }, growable: false);

    return PageManifest(
      pageNum: pageNum,
      atlasWidth: _bytes.getUint16(t + 8, e),
      atlasHeight: _bytes.getUint16(t + 10, e),
      pageWidth: _bytes.getUint16(t + 12, e),
      pageHeight: _bytes.getUint16(t + 14, e),
      sprites: sprites,
      instances: instances,
    );
  }

  int _tableOffset(int pageNum) {
    final i = _indexByPageNum[pageNum];
    if (i == null) throw RangeError('No page $pageNum in this manifest');
    return _pageTable + i * _pageEntry;
  }
}

// ===========================================================================
// EAGER DECODE (tooling/debug)
// ===========================================================================

class MushafManifest {
  MushafManifest(this.shared, this.pages);

  final List<SharedSprite> shared;

  /// In page order — `pages[0]` is page 1.
  final List<PageManifest> pages;

  PageManifest page(int pageNum) => pages[pageNum - 1];
}

MushafManifest decodeMushafManifest(Uint8List data) {
  final reader = MushafReader(data);
  final nums = reader.pageNumbers.toList()..sort();
  return MushafManifest(reader.shared, [for (final n in nums) reader.page(n)]);
}
