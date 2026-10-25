// End-to-end test of the review page (review, attach, export, import).
// Needs: npm i jsdom@24 fake-indexeddb@6 jszip@3 (in a scratch folder), then
//   node tools/content_review/page_test.js $PWD   (NODE_PATH=<that folder>/node_modules)
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');
const { IDBFactory } = require('fake-indexeddb');
const JSZip = require('jszip');

const repo = process.argv[2];
const html = fs.readFileSync(path.join(repo, 'tools/content_review/index.html'), 'utf8')
  .replace(/<script src="[^"]+"><\/script>/g, '');
const cjs = fs.readFileSync(path.join(repo, 'tools/content_review/content.js'), 'utf8');
const CONTENT = JSON.parse(cjs.slice(cjs.indexOf('{'), cjs.lastIndexOf('}') + 1));
const sleep = ms => new Promise(r => setTimeout(r, ms));

function browser() {
  const page = html.slice(0, html.lastIndexOf('<script>')) + html.slice(html.lastIndexOf('</script>') + 9);
  const dom = new JSDOM(page, { runScripts: 'dangerously', url: 'http://localhost/#sec=tajwid.nun', pretendToBeVisual: true });
  const w = dom.window;
  w.CONTENT = CONTENT; w.JSZip = shim(w); w.indexedDB = new IDBFactory();
  w.CSS = { escape: s => s.replace(/["\\]/g, '\\$&') };
  w.downloads = [];
  w.addEventListener('unhandledrejection', e => console.error('page:', e.reason));
  w.addEventListener('error', e => console.error('page:', e.error));
  w.URL.createObjectURL = b => { w.downloads.push(b); return 'blob:x'; };
  w.HTMLAnchorElement.prototype.click = function () { w.lastDownload = this.download; };
  w.eval(html.slice(html.lastIndexOf('<script>') + 8, html.lastIndexOf('</script>')));
  return w;
}
const click = (w, sel) => w.document.querySelector(sel).dispatchEvent(new w.MouseEvent('click', { bubbles: true }));
function assert(c, m) { if (!c) { console.error('FAIL:', m); process.exit(1); } console.log('ok:', m); }

(async () => {
  const id = 'lesson:tajwid.izhar';
  const a = browser();
  await sleep(300);
  assert(a.document.querySelectorAll('.card').length > 3, 'tajwid.nun cards render');
  a.document.querySelector('#reviewer').value = 'Shaykh';
  click(a, `[data-status="${id}"][data-v="change"]`);
  await sleep(100);
  a.document.querySelector(`[data-comment="${id}"]`).value = 'Mention the six letters';
  click(a, `[data-addc="${id}"]`);
  await sleep(100);
  // A correction, and an attached file.
  const ta = a.document.querySelector(`[data-corr="${id}"][data-field="intro"][data-lang="en"]`);
  ta.value = 'Pronounce it clearly.'; ta.dispatchEvent(new a.Event('change', { bubbles: true }));
  await sleep(100);
  const input = a.document.querySelector(`[data-attach="${id}"]`);
  const file = new a.File(['hello'], 'note.txt', { type: 'text/plain' });
  Object.defineProperty(input, 'files', { value: [file] });
  input.dispatchEvent(new a.Event('change', { bubbles: true }));
  await sleep(200);
  assert(a.document.querySelector(`#item-${CSS_id(id)} .file`), 'attachment listed');
  assert(a.document.querySelector('#progress').textContent.startsWith('1 '), 'progress counts 1');

  click(a, '#exportBtn');
  for (let i = 0; i < 50 && !a.lastDownload; i++) await sleep(100);
  const blob = a.downloads.at(-1);
  assert(blob && /\.zip$/.test(a.lastDownload), 'exported ' + a.lastDownload);
  const zip = await JSZip.loadAsync(Buffer.from(await new Promise(r => { const fr = new a.FileReader(); fr.onload = () => r(fr.result); fr.readAsArrayBuffer(blob); })));
  const review = JSON.parse(await zip.file('review.json').async('string'));
  const r = review.items[id];
  assert(r.status === 'change' && r.comments.length === 1 && r.corrections.intro.en === 'Pronounce it clearly.', 'review.json holds status, comment, correction');
  assert(r.files[0].path && !/[:#]/.test(r.files[0].path) && zip.file(r.files[0].path), 'attachment at a safe path: ' + r.files[0].path);

  // A fresh browser, with an earlier comment of its own: import merges.
  const b = browser();
  await sleep(300);
  b.document.querySelector('#reviewer').value = 'Me';
  b.document.querySelector(`[data-comment="${id}"]`).value = 'My note';
  click(b, `[data-addc="${id}"]`);
  await sleep(100);
  const zbytes = await new Promise(r => { const fr = new a.FileReader(); fr.onload = () => r(fr.result); fr.readAsArrayBuffer(blob); });
  const zfile = new b.File([new b.Uint8Array(zbytes)], a.lastDownload);
  Object.defineProperty(b.document.querySelector('#importFile'), 'files', { value: [zfile], configurable: true });
  b.document.querySelector('#importFile').dispatchEvent(new b.Event('change'));
  await sleep(800);
  const card = b.document.querySelector(`#item-${CSS_id(id)}`);
  assert(card.querySelectorAll('.comment').length === 2, 'both reviewers\' comments kept');
  assert(card.classList.contains('question'), 'the newer status (B\'s own, after the export) wins');
  assert(b.document.querySelector(`[data-corr="${id}"][data-field="intro"][data-lang="en"]`).value === 'Pronounce it clearly.', 'imported correction shown');
  assert(card.querySelector('.file'), 'imported attachment listed');
  console.log('all good');
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });

// JSZip for the page, converting its (jsdom-realm) buffers and Blobs.
function shim(w) {
  const read = b => new Promise(r => { const fr = new w.FileReader(); fr.onload = () => r(Buffer.from(new Uint8Array(fr.result))); fr.readAsArrayBuffer(b); });
  const conv = d => (d && d.byteLength !== undefined && typeof d !== 'string') ? Buffer.from(new Uint8Array(d)) : d;
  function wrap(z) {
    return {
      file(name, data) {
        if (data === undefined) { const f = z.file(name); return f && { async: t => f.async(t === 'uint8array' ? 'nodebuffer' : t).then(v => t === 'uint8array' ? new w.Uint8Array(v) : v) }; }
        z.file(name, conv(data)); return this;
      },
      generateAsync: async () => { const buf = await z.generateAsync({ type: 'nodebuffer' }); return new w.Blob([new w.Uint8Array(buf)], { type: 'application/zip' }); },
    };
  }
  function Z() { return wrap(new JSZip()); }
  Z.loadAsync = async f => wrap(await JSZip.loadAsync(await read(f)));
  return Z;
}

function CSS_id(id) { return id.replace(/[^\w-]/g, c => '\\' + c); }
