// Shared constants for the mushaf binary manifest (MUSF version 2).
//
// One file per quality tier: <tier>/mushaf_manifest.bin. It describes
//   * the SHARED atlas (<tier>/shared.webp): shapes that repeat across the
//     mushaf, stored once — surah border, basmala, the word سورة, the ayah
//     frame, and the digits ٠-٩;
//   * every PAGE atlas (<tier>/pages/<n>.webp): everything else on that page;
//   * per page: page-sprite records (1:1, as in v1) and shared-sprite
//     INSTANCES (sprite + uniform scale + position).
//
// FILE LAYOUT (little-endian)
//
//   HEADER — 32 bytes
//      0  u32  magic 'MUSF'
//      4  u8   version (2)
//      5  u8   flags  bit0 ids · bit1 page size · bit2 shared instances
//      6  u16  page-table entry size        (24)
//      8  u32  pageCount
//     12  u32  recordCount     (page sprites, all pages)
//     16  u32  instanceCount   (shared-sprite instances, all pages)
//     20  u16  sharedCount     (sprites in the shared atlas)
//     22  u16  shared-table entry size      (12)
//     24  u16  instance size                (12)
//     26  u16  record size                  (16)
//     28  u16  sharedAtlasWidth
//     30  u16  sharedAtlasHeight
//
//   SHARED TABLE — sharedCount x 12
//      +0 u16 sprX  +2 u16 sprY  +4 u16 W  +6 u16 H
//      +8 u8 kind (0 border, 1 basmala, 2 surahWord, 3 ayahFrame, 4 digit)
//      +9 u8 value (the digit for kind 4, else 0)   +10 u16 reserved
//
//   PAGE TABLE — pageCount x 24
//      +0  u32 firstRecord   +4  u16 recordCount  +6  u16 pageNum
//      +8  u16 atlasWidth    +10 u16 atlasHeight
//      +12 u16 pageWidth     +14 u16 pageHeight   (px at this tier's scale)
//      +16 u32 firstInstance +20 u16 instanceCount +22 u16 reserved
//
//   RECORDS — recordCount x 16   (same as v1; drawn 1:1)
//      +0 u32 id  +4 u16 L  +6 u16 T  +8 u16 W  +10 u16 H  +12 u16 sprX  +14 u16 sprY
//
//   INSTANCES — instanceCount x 12
//      +0  u32 id       packed id of the element this belongs to (an ayah
//                       marker = 1 frame + 1-3 digit instances, same id)
//      +4  u16 shared   index into the shared table
//      +6  u16 scale    uniform scale = value / 32768 (sprite px -> page px)
//      +8  i16 x        top-left of the sprite on the page, in 1/4 px
//      +10 i16 y
//   Draw with RSTransform(scos: scale, ssin: 0, tx: x/4, ty: y/4).

import 'dart:typed_data';

const int kMushafManifestMagic = 0x4D555346; // 'MUSF'
const int kMushafManifestVersion = 2;

const int kHeaderSize = 32;
const int kSharedEntrySize = 12;
const int kPageEntrySize = 24;
const int kRecordSize = 16;
const int kInstanceSize = 12;

const int kFlagHasIds = 1 << 0;
const int kFlagHasPageSize = 1 << 1;
const int kFlagHasShared = 1 << 2;

const double kInstanceScaleOne = 32768;
const double kInstancePosUnits = 4;

const Endian kMushafManifestEndian = Endian.little;

/// What a shared sprite is.
enum SharedKind { border, basmala, surahWord, ayahFrame, digit }
