/// <reference path="../pb_data/types.d.ts" />
// A mark over several words: its last word (0 0 0 for a mark on one word).
migrate((app) => {
  const marks = app.findCollectionByNameOrId("marks");
  marks.fields.add(new NumberField({ name: "to_surah", onlyInt: true, min: 0, max: 114 }));
  marks.fields.add(new NumberField({ name: "to_ayah", onlyInt: true, min: 0, max: 286 }));
  marks.fields.add(new NumberField({ name: "to_word", onlyInt: true, min: 0, max: 200 }));
  app.save(marks);
}, (app) => {
  const marks = app.findCollectionByNameOrId("marks");
  for (const f of ["to_surah", "to_ayah", "to_word"]) marks.fields.removeByName(f);
  app.save(marks);
});
