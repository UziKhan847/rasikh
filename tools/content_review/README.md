# Content review

A page for reviewing the app's teaching content — every lesson, letter, rule,
example and the Nabr module — item by item, in English and Arabic.

## Make it
    flutter test tool/content_review/gen_content_test.dart
writes `tools/content_review/content.js` (open `index.html` here to use it)
and `build/content_review/qiraah_review.html` — one file with the content and
fonts inside, to send to a reviewer. (Zip export loads JSZip from cdnjs, so it
needs the internet; without it the page exports `review.json` alone.)

## Use it
- Type your name at the top, pick a section, and for each item: Approved,
  Needs change or Question; comments; corrected text per language; files.
- The review saves in the browser. **Export zip** to send it back; **Import**
  a zip (yours or someone else's) to merge it — comments from everyone are
  kept, the newest status wins.
- "Changed since reviewed" lists items whose content changed after their
  review. Links: `index.html#sec=<section id>&ui=ar`.

## Apply it
    python3 tool/content_review/summarize.py <export.zip>
writes `build/content_review/applied/<name>/REVIEW.md` (the change list) and
the attachments next to it.
