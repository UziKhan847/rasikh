/// <reference path="../pb_data/types.d.ts" />
// Mutashābihāt: the passages a mutashābih mark is confused with. Each link
// is its own row (word 0: a whole āyah), with the same rules as mark_fixes.
migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  const books = app.findCollectionByNameOrId("books");
  const ME = "@request.auth.id";
  const member = (p) =>
    `${p}owner = ${ME} || ${p}listeners.id ?= ${ME} || ${p}checkers.id ?= ${ME}`;
  const writer = (p) => `${p}owner = ${ME} || ${p}listeners.id ?= ${ME}`;

  app.save(new Collection({
    type: "base",
    name: "mark_links",
    listRule: member("book."),
    viewRule: member("book."),
    createRule: `${ME} != "" && author = ${ME} && (${writer("book.")})`,
    updateRule: `(author = ${ME} || book.owner = ${ME}) && @request.body.book:changed = false && @request.body.author:changed = false`,
    deleteRule: null,
    fields: [
      { name: "book", type: "relation", required: true, maxSelect: 1,
        collectionId: books.id, cascadeDelete: true },
      { name: "mark", type: "text", max: 15 },
      { name: "surah", type: "number", onlyInt: true, min: 1, max: 114 },
      { name: "ayah", type: "number", onlyInt: true, min: 1, max: 286 },
      { name: "word", type: "number", onlyInt: true, min: 0, max: 200 },
      { name: "author", type: "relation", maxSelect: 1, collectionId: users.id },
      { name: "made_at", type: "number", onlyInt: true },
      { name: "client_updated", type: "number", onlyInt: true },
      { name: "deleted", type: "bool" },
      { name: "created", type: "autodate", onCreate: true },
      { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],
    indexes: ["CREATE INDEX idx_links_book_updated ON mark_links (book, updated)"],
  }));
}, (app) => {
  try { app.delete(app.findCollectionByNameOrId("mark_links")); } catch (_) {}
});
