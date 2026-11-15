// Justifies every line of the app's Madani muṣḥaf with digitalkhatt.org's
// own engine (vendor/just.service.ts, MIT) and the DigitalKhatt New Madina
// font (fonts/madina.otf, OFL): kashīdas and widened letter forms — the
// font's cvNN alternates — instead of wide spaces.
//
//   cd tool/mushaf_justify && npm install
//   node --experimental-transform-types justify.mts [--pages 1-604] [--measure <font units>] [--min-measure <em>] [--stats]
//
// Writes out/lines.json: per text line (page, line index in the page's
// layout), the line as shaped (our tokens, with the site's mark-order fix),
// each character's features, the space widths and any horizontal squeeze.
// Each page is set at the size that fits its widest line, as on the site,
// but no larger a size than --min-measure allows (17 em by default, so a page
// of short lines takes more kashīdas rather than a far larger font);
// --stats prints the natural line widths instead.
//
// The vendored files are used as they are; only their imports are patched
// (into out/ts/), so a newer copy from the site drops straight in.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const here = path.dirname(new URL(import.meta.url).pathname);
const root = path.resolve(here, '../..');
const require = createRequire(import.meta.url);
const args = process.argv.slice(2);
const arg = (k: string) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : undefined; };

// ── the vendored engine, imports patched ──
const ts = path.join(here, 'out/ts');
fs.mkdirSync(ts, { recursive: true });
fs.writeFileSync(path.join(ts, 'stubs.ts'), `
export enum MushafLayoutType { NewMadinah = 1, OldMadinah, IndoPak15Lines }
// The site caches layouts in localStorage with lz-string; not used here.
export const compress = (s: string) => s;
export const decompress = (s: string) => s;
`);
function patch(file: string, pairs: [string, string][]) {
  let s = fs.readFileSync(path.join(here, 'vendor', file), 'utf8');
  for (const [a, b] of pairs) {
    if (!s.includes(a)) throw new Error(`${file}: patch target not found: ${a}`);
    s = s.replace(a, b);
  }
  fs.writeFileSync(path.join(ts, file), s);
}
patch('just.service.ts', [
  ['import { MushafLayoutType, QuranTextService } from "../../services/qurantext.service";',
    'import { MushafLayoutType } from "./stubs.ts"; type QuranTextService = any;'],
  ['import { HarfBuzzFont, HarfBuzzBuffer, hb as HarfBuzz, getWidth, HBFeature } from "./harfbuzz"',
    'import { HarfBuzzFont, HarfBuzzBuffer, hb as HarfBuzz, getWidth, type HBFeature } from "./harfbuzz.ts"'],
  ["import { compress, decompress } from 'lz-string';", 'import { compress, decompress } from "./stubs.ts";'],
]);
patch('harfbuzz.ts', [
  ['import * as hbjs from "harfbuzzjs/hb.js"', 'import * as hbjs from "harfbuzzjs/hb.js"\nexport function initHarfbuzz(module: any) { hb = new HarfBuzzExports(module) }'],
]);
const H: any = await import(path.join(ts, 'harfbuzz.ts'));
const J: any = await import(path.join(ts, 'just.service.ts'));

const hbFactory = (await import('harfbuzzjs/hb.js')).default;
H.initHarfbuzz(await hbFactory({ wasmBinary: fs.readFileSync(require.resolve('harfbuzzjs/hb.wasm')) }));
const blob = new H.HarfBuzzBlob(new Uint8Array(fs.readFileSync(path.join(here, 'fonts/madina.otf'))));
const face = new H.HarfBuzzFace(blob, 0);
const font = new H.HarfBuzzFont(face);
const FONTSIZE: number = J.FONTSIZE;

// ── our lines ──
const text: string[] = JSON.parse(fs.readFileSync(path.join(root, 'assets/quran/mushaf_u_text.json'), 'utf8'));
const layout: [number, number][][] = JSON.parse(fs.readFileSync(path.join(root, 'assets/quran/mushaf_u_layout.json'), 'utf8'));
const tokens: string[] = [], ayahFirst: number[] = [];
for (const a of text) {
  ayahFirst.push(tokens.length);
  for (const t of a.split('‌')) if (t) tokens.push(t);
}
ayahFirst.push(tokens.length);
type Line = { page: number; line: number; first: number; end: number };
const starts: Omit<Line, 'end'>[] = [];
layout.forEach((p, pi) => p.forEach(([a, w], li) => {
  if (a >= 0) starts.push({ page: pi + 1, line: li, first: ayahFirst[a] + w });
}));
const lines: Line[] = starts.map((s, k) => ({ ...s, end: k + 1 < starts.length ? starts[k + 1].first : tokens.length }));

/// The site's mark-order fix (QuranTextService.adjustText): a combining
/// grapheme joiner keeps a feature on the letter off its hamza or madda.
function adjust(t: string) {
  return t.replaceAll('آ', 'ا͏ٓ')
    .replaceAll('أ', 'ا͏ٔ͏')
    .replaceAll('ؤ', 'و͏ٔ͏')
    .replaceAll('ئ', 'ي͏ٔ͏');
}

const lineText = (l: Line) => adjust(tokens.slice(l.first, l.end).join(' '));

/// The site's narrower lines (QuranTextService.newMadinaLineWidths, keyed
/// by page × 15 + line number) and the opening pages' tapering lines. Our
/// line index counts the page's header and basmala rows too, as the site's
/// does.
const narrow = new Map<number, number>([
  [255 * 15 + 2, 0.74], [528 * 15 + 9, 0.6], [534 * 15 + 6, 0.7], [545 * 15 + 6, 0.75],
  [586 * 15 + 1, 0.81], [593 * 15 + 2, 0.81], [594 * 15 + 5, 0.63], [600 * 15 + 10, 0.75],
  [602 * 15 + 5, 0.63], [602 * 15 + 11, 0.9], [602 * 15 + 15, 0.53], [603 * 15 + 10, 0.66],
  [603 * 15 + 15, 0.60], [604 * 15 + 4, 0.55], [604 * 15 + 9, 0.55], [604 * 15 + 14, 0.675],
  [604 * 15 + 15, 0.5],
]);

// The opening pages are set in a circle, as the printed Madani muṣḥaf sets
// them: each line's width a share of the widest row (row 4), measured to the
// pixel off the print (rows 1–7; al-Baqarah's row 1 is its basmala, al-Fātiḥah's
// words drawn again: nothing to set). One circle for both pages, just wide
// enough that no line has to be squeezed into its share (or --opening-d, in em).
const PRINT_SHARE: Record<number, number[]> = {
  1: [.508, .699, .899, 1, .898, .695, .398],
  2: [0, .697, .899, .996, .902, .695, .398],
};
const openingLines = lines.filter(l => l.page <= 2);
const openingWidth = new Map(openingLines.map(l => [l, H.getWidth(lineText(l), font, FONTSIZE, null) as number]));
const shareOf = (l: Line) => PRINT_SHARE[l.page][l.line - 1];
// A line of two or three words has too few places for kashīdas to fill
// half again its width (its spaces would gape): it's stretched at most this
// much, centred inside its share.
const SHORT_STRETCH = Number(arg('--short-stretch') ?? 1.5);
let fit = 0;
for (const l of openingLines) fit = Math.max(fit, openingWidth.get(l)! / shareOf(l));
const openingD = Number(arg('--opening-d') ?? 0) * FONTSIZE || fit;
for (const l of openingLines) {
  const w = openingWidth.get(l)!;
  const share = shareOf(l) * openingD;
  const width = l.end - l.first < 4 ? Math.min(share, w * SHORT_STRETCH) : share;
  narrow.set(l.page * 15 + l.line + 1, width / openingD);
  console.log(`opening p${l.page} line ${l.line}: ${(width / FONTSIZE).toFixed(2)} em, ` +
    `natural ${(w / FONTSIZE).toFixed(2)} em (×${(width / w).toFixed(2)})`);
}
console.log(`opening circle: ${(openingD / FONTSIZE).toFixed(2)} em across`);
if (openingD / FONTSIZE > 17.3) {
  console.error('the opening circle is wider than a page (17.3 em): pass --opening-d');
  process.exit(1);
}

const pages = (arg('--pages') ?? '1-604').split('-').map(Number);
const inPages = (p: number) => p >= pages[0] && p <= (pages[1] ?? pages[0]);
const selected = lines.filter(l => inPages(l.page));

// Each line's natural width (font units at FONTSIZE) and its share of the
// measure (narrower lines, see above).
const ratioOf = (l: Line) => narrow.get(l.page * 15 + l.line + 1) ?? 1;
const natural = new Map(selected.map(l => [l, H.getWidth(lineText(l), font, FONTSIZE, null) as number]));
if (args.includes('--stats')) {
  const full = selected.filter(l => ratioOf(l) === 1).map(l => natural.get(l)!).sort((a, b) => a - b);
  const q = (f: number) => full[Math.min(full.length - 1, Math.floor(f * full.length))].toFixed(0);
  console.log(`${full.length} full lines: natural width min ${q(0)} · median ${q(0.5)} · 95% ${q(0.95)} · 99% ${q(0.99)} · max ${q(1 - 1e-9)}`);
  process.exit(0);
}
// The measure: as the site does, each page is set at the size that fits its
// widest line, and every other line is stretched to it — unless one measure
// is given for all (--measure; wider lines are then squeezed).
const fixed = Number(arg('--measure') ?? 0);
const pageMeasure = new Map<number, number>();
for (const l of selected) {
  pageMeasure.set(l.page, Math.max(pageMeasure.get(l.page) ?? 0, natural.get(l)! / ratioOf(l)));
}
const minMeasure = Number(arg('--min-measure') ?? 17) * FONTSIZE;
for (const [page, m] of pageMeasure) if (m < minMeasure) pageMeasure.set(page, minMeasure);
for (const page of [1, 2]) if (pageMeasure.has(page)) pageMeasure.set(page, openingD);

// ── justify ──
const spaceWidth = H.getWidth(' ', font, FONTSIZE, null);
const out: any[] = [];
let squeezed = 0, spaceOnly = 0;
for (const l of selected) {
  const t = lineText(l);
  const ratio = ratioOf(l);
  const measure = fixed || Math.ceil(pageMeasure.get(l.page)!);
  const info = J.analyzeLineForJust({ quranText: { [l.page * 100 + l.line]: { [0]: t } } }, l.page * 100 + l.line, 0);
  const r = J.justifyLine(info, font, FONTSIZE / (measure * ratio), spaceWidth);
  const features: Record<number, [string, number][]> = {};
  for (const [i, fs_] of r.fontFeatures) features[i] = fs_.map((f: any) => [f.name, f.value]);
  if (r.xScale !== 1) squeezed++;
  if (!Object.keys(features).length && r.xScale === 1) spaceOnly++;
  out.push({ page: l.page, line: l.line, first: l.first, end: l.end, text: t, ratio,
    measure, natural: natural.get(l), features, simpleSpacing: r.simpleSpacing, ayaSpacing: r.ayaSpacing, xScale: r.xScale });
}
fs.mkdirSync(path.join(here, 'out'), { recursive: true });
fs.writeFileSync(path.join(here, 'out/lines.json'), JSON.stringify({ spaceWidth, font: 'madina.otf', lines: out }));
console.log(`${out.length} lines → out/lines.json (${fixed ? `measure ${fixed}` : 'per-page measure'}; ${squeezed} squeezed, ${spaceOnly} by spaces alone)`);
