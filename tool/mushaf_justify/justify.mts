// Justifies every line of the app's Madani muṣḥaf with digitalkhatt.org's
// own engine (vendor/just.service.ts, MIT) and the DigitalKhatt New Madina
// font (fonts/madina.otf, OFL): kashīdas and widened letter forms — the
// font's cvNN alternates — instead of wide spaces.
//
//   cd tool/mushaf_justify && npm install
//   node --experimental-transform-types justify.mts [--pages 1-604] [--measure <font units>] [--stats]
//
// Writes out/lines.json: per text line (page, line index in the page's
// layout), the line as shaped (our tokens, with the site's mark-order fix),
// each character's features, the space widths and any horizontal squeeze.
// Each page is set at the size that fits its widest line, as on the site;
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
for (const page of [1, 2]) {
  narrow.set(page * 15 + 2, 0.7 * 0.8);
  for (let l = 3; l <= 8; l++) narrow.set(page * 15 + l, 0.7);
}

const pages = (arg('--pages') ?? '1-604').split('-').map(Number);
const inPages = (p: number) => p >= pages[0] && p <= (pages[1] ?? pages[0]);
const selected = lines.filter(l => inPages(l.page));
const lineText = (l: Line) => adjust(tokens.slice(l.first, l.end).join(' '));

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
