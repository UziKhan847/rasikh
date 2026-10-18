/// <reference path="../pb_data/types.d.ts" />
// Qiraah Arabiyyah — Hifz marks: schema and API rules.
//
// Word numbering: marks are keyed (surah, ayah, word) in the 15-line muṣḥaf's
// numbering ("mushaf15"), which the Madani and Indo-Pak texts share.
//
// Membership lives on the book: owner, listeners[], checkers[].
//   owner     everything; manages members (via /api/hifz routes)
//   listener  creates sessions, marks, fixes; edits only their own rows
//   checker   reads; adds comments
// Data rows are never hard-deleted through the API: the app writes a
// tombstone (deleted = true) so the deletion reaches every device. Stale
// writes are refused in pb_hooks/hifz.pb.js.
migrate((app) => {
  // ── users: username + password; email optional (recovery only) ──
  const users = app.findCollectionByNameOrId("users");
  users.fields.add(new TextField({
    name: "username", required: true, min: 3, max: 32,
    pattern: "^[a-z0-9_.-]+$",
  }));
  users.fields.add(new TextField({ name: "displayName", max: 60 }));
  users.fields.getByName("email").required = false;
  users.passwordAuth.enabled = true;
  users.passwordAuth.identityFields = ["username", "email"];
  users.addIndex("idx_users_username", true, "username", "");
  users.listRule = null; // nobody can enumerate users
  users.viewRule = "id = @request.auth.id";
  users.createRule = "";
  users.updateRule = "id = @request.auth.id";
  users.deleteRule = "id = @request.auth.id";
  app.save(users);

  const ME = "@request.auth.id";
  const member = (p) =>
    `${p}owner = ${ME} || ${p}listeners.id ?= ${ME} || ${p}checkers.id ?= ${ME}`;
  const writer = (p) => `${p}owner = ${ME} || ${p}listeners.id ?= ${ME}`;
  const stamps = [
    { name: "client_updated", type: "number", onlyInt: true },
    { name: "deleted", type: "bool" },
    { name: "created", type: "autodate", onCreate: true },
    { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
  ];

  // ── books ──
  const books = new Collection({
    type: "base",
    name: "books",
    listRule: member(""),
    viewRule: member(""),
    // Members are added by invite code and removed by the owner, both
    // through the /api/hifz routes — never by writing these fields.
    createRule: `${ME} != "" && owner = ${ME} && @request.body.listeners:isset = false && @request.body.checkers:isset = false`,
    updateRule: `owner = ${ME} && @request.body.owner:changed = false && @request.body.listeners:isset = false && @request.body.checkers:isset = false`,
    deleteRule: `owner = ${ME}`,
    fields: [
      { name: "name", type: "text", max: 120 },
      { name: "owner", type: "relation", required: true, maxSelect: 1,
        collectionId: users.id, cascadeDelete: true },
      { name: "listeners", type: "relation", maxSelect: 999, collectionId: users.id },
      { name: "checkers", type: "relation", maxSelect: 999, collectionId: users.id },
      { name: "word_scheme", type: "text", max: 20 },
      { name: "made_at", type: "number", onlyInt: true },
      ...stamps,
    ],
    indexes: ["CREATE INDEX idx_books_owner ON books (owner)"],
  });
  app.save(books);

  const bookField = {
    name: "book", type: "relation", required: true, maxSelect: 1,
    collectionId: books.id, cascadeDelete: true,
  };
  const userRef = (name) => ({
    name, type: "relation", maxSelect: 1, collectionId: users.id,
  });

  // Rules for a data collection whose author is in [authorField].
  const rules = (authorField, canCreate) => ({
    listRule: member("book."),
    viewRule: member("book."),
    createRule: `${ME} != "" && ${authorField} = ${ME} && (${canCreate})`,
    updateRule: `(${authorField} = ${ME} || book.owner = ${ME}) && @request.body.book:changed = false && @request.body.${authorField}:changed = false`,
    deleteRule: null,
  });

  app.save(new Collection({
    type: "base",
    name: "sessions",
    ...rules("created_by", writer("book.")),
    fields: [
      bookField, userRef("created_by"),
      { name: "started_at", type: "number", onlyInt: true },
      { name: "ended_at", type: "number", onlyInt: true },
      { name: "listener_name", type: "text", max: 80 },
      { name: "kind", type: "text", max: 20 },
      { name: "script", type: "text", max: 20 },
      { name: "from_ayah", type: "number", onlyInt: true },
      { name: "to_ayah", type: "number", onlyInt: true },
      { name: "note", type: "text", max: 2000 },
      ...stamps,
    ],
    indexes: ["CREATE INDEX idx_sessions_book_updated ON sessions (book, updated)"],
  }));

  app.save(new Collection({
    type: "base",
    name: "marks",
    ...rules("author", writer("book.")),
    fields: [
      bookField,
      { name: "session", type: "text", max: 15 },
      { name: "surah", type: "number", onlyInt: true, min: 1, max: 114 },
      { name: "ayah", type: "number", onlyInt: true, min: 1, max: 286 },
      { name: "word", type: "number", onlyInt: true, min: 0, max: 200 },
      { name: "type", type: "text", max: 20 },
      { name: "comment", type: "text", max: 4000 },
      userRef("author"),
      { name: "author_name", type: "text", max: 80 },
      { name: "made_at", type: "number", onlyInt: true },
      ...stamps,
    ],
    indexes: [
      "CREATE INDEX idx_marks_book_updated ON marks (book, updated)",
      "CREATE INDEX idx_marks_word ON marks (book, surah, ayah, word)",
    ],
  }));

  app.save(new Collection({
    type: "base",
    name: "mark_fixes",
    ...rules("fixed_by", writer("book.")),
    fields: [
      bookField,
      { name: "mark", type: "text", max: 15 },
      { name: "session", type: "text", max: 15 },
      userRef("fixed_by"),
      { name: "fixed_by_name", type: "text", max: 80 },
      { name: "fixed_at", type: "number", onlyInt: true },
      ...stamps,
    ],
    indexes: ["CREATE INDEX idx_fixes_book_updated ON mark_fixes (book, updated)"],
  }));

  app.save(new Collection({
    type: "base",
    name: "mark_comments",
    // Checkers may comment too.
    ...rules("author", member("book.")),
    fields: [
      bookField,
      { name: "mark", type: "text", max: 15 },
      userRef("author"),
      { name: "author_name", type: "text", max: 80 },
      { name: "text", type: "text", max: 4000 },
      { name: "made_at", type: "number", onlyInt: true },
      ...stamps,
    ],
    indexes: ["CREATE INDEX idx_comments_book_updated ON mark_comments (book, updated)"],
  }));

  // Share codes: only their hashes are stored; locked to the API (routes in
  // pb_hooks do all the reading and writing).
  app.save(new Collection({
    type: "base",
    name: "invites",
    listRule: null, viewRule: null, createRule: null, updateRule: null, deleteRule: null,
    fields: [
      bookField,
      { name: "role", type: "text", max: 20 },
      { name: "code_hash", type: "text", max: 64 },
      { name: "expires", type: "date" },
      { name: "max_uses", type: "number", onlyInt: true },
      { name: "uses", type: "number", onlyInt: true },
      { name: "created", type: "autodate", onCreate: true },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_invites_code ON invites (code_hash)"],
  }));

  // ── server settings the app relies on ──
  const settings = app.settings();
  settings.batch.enabled = true; // the app pushes rows as batched upserts
  settings.batch.maxRequests = 200;
  settings.rateLimits.enabled = true;
  settings.rateLimits.rules = [
    { label: "/api/hifz/invites/accept", maxRequests: 5, duration: 60 },
    { label: "*:auth", maxRequests: 10, duration: 60 },
    { label: "users:create", maxRequests: 5, duration: 300 },
    { label: "/api/batch", maxRequests: 60, duration: 60 },
    { label: "/api/", maxRequests: 300, duration: 60 },
  ];
  app.save(settings);
}, (app) => {
  for (const name of ["invites", "mark_comments", "mark_fixes", "marks", "sessions", "books"]) {
    try { app.delete(app.findCollectionByNameOrId(name)); } catch (_) {}
  }
  const users = app.findCollectionByNameOrId("users");
  users.removeIndex("idx_users_username");
  users.fields.removeByName("username");
  users.fields.removeByName("displayName");
  app.save(users);
});
