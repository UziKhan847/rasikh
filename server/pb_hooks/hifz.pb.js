/// <reference path="../pb_data/types.d.ts" />
// Qiraah Arabiyyah — Hifz marks: sharing routes, the stale-write guard,
// account deletion and pruning. Schema and rules: pb_migrations/.

// ── share codes ──────────────────────────────────────────────────────────

// The owner creates a share code for a listener or a checker.
routerAdd("POST", "/api/hifz/invites", (e) => {
  const u = require(`${__hooks}/hifz_utils.js`);
  const body = e.requestInfo().body;
  const book = u.book($app, String(body.book || ""));
  if (book.getString("owner") !== e.auth.id) {
    throw new ForbiddenError("Only the book's owner can invite.");
  }
  const role = body.role === "checker" ? "checker" : "listener";
  const code = $security.randomStringWithAlphabet(8, u.ALPHABET);
  const expires = new Date(Date.now() + 7 * 24 * 3600 * 1000);
  const inv = new Record($app.findCollectionByNameOrId("invites"));
  inv.set("book", book.id);
  inv.set("role", role);
  inv.set("code_hash", $security.sha256(code));
  inv.set("expires", u.pbTime(expires));
  inv.set("max_uses", 20);
  inv.set("uses", 0);
  $app.save(inv);
  return e.json(200, { code: code, role: role, expires: expires.toISOString() });
}, $apis.requireAuth());

// Anyone signed in redeems a code: they join the book in the code's role.
routerAdd("POST", "/api/hifz/invites/accept", (e) => {
  const u = require(`${__hooks}/hifz_utils.js`);
  const code = String(e.requestInfo().body.code || "")
    .toUpperCase().replace(/[^A-Z0-9]/g, "");
  let inv;
  try {
    inv = $app.findFirstRecordByData("invites", "code_hash", $security.sha256(code));
  } catch (_) {
    throw new BadRequestError("That code isn't valid.");
  }
  const expired = new Date(inv.getDateTime("expires").string().replace(" ", "T")) < new Date();
  if (expired || inv.getInt("uses") >= inv.getInt("max_uses")) {
    throw new BadRequestError("That code isn't valid.");
  }
  const bookId = inv.getString("book");
  const uid = e.auth.id;
  $app.runInTransaction((tx) => {
    const book = tx.findRecordById("books", bookId);
    if (!u.isMember(book, uid)) {
      const field = inv.getString("role") === "checker" ? "checkers" : "listeners";
      book.set(field, u.list(book, field).concat([uid]));
      tx.save(book);
    }
    const i = tx.findRecordById("invites", inv.id);
    i.set("uses", i.getInt("uses") + 1);
    tx.save(i);
  });
  return e.json(200, { book: bookId });
}, $apis.requireAuth());

// ── members ──────────────────────────────────────────────────────────────

// Who is in a book (usernames are otherwise private), for its members.
routerAdd("GET", "/api/hifz/books/{id}/members", (e) => {
  const u = require(`${__hooks}/hifz_utils.js`);
  const book = u.book($app, e.request.pathValue("id"));
  if (!u.isMember(book, e.auth.id)) throw new NotFoundError("No such book.");
  const out = [];
  const add = (id, role) => {
    try {
      const r = $app.findRecordById("users", id);
      out.push({
        id: r.id,
        username: r.getString("username"),
        displayName: r.getString("displayName"),
        role: role,
      });
    } catch (_) {}
  };
  add(book.getString("owner"), "owner");
  for (const id of u.list(book, "listeners")) add(id, "listener");
  for (const id of u.list(book, "checkers")) add(id, "checker");
  return e.json(200, { members: out });
}, $apis.requireAuth());

// The owner removes a member.
routerAdd("POST", "/api/hifz/books/{id}/remove", (e) => {
  const u = require(`${__hooks}/hifz_utils.js`);
  const book = u.book($app, e.request.pathValue("id"));
  if (book.getString("owner") !== e.auth.id) {
    throw new ForbiddenError("Only the book's owner can remove members.");
  }
  const who = String(e.requestInfo().body.user || "");
  book.set("listeners", u.list(book, "listeners").filter((x) => x !== who));
  book.set("checkers", u.list(book, "checkers").filter((x) => x !== who));
  $app.save(book);
  return e.json(200, { ok: true });
}, $apis.requireAuth());

// A member leaves.
routerAdd("POST", "/api/hifz/books/{id}/leave", (e) => {
  const u = require(`${__hooks}/hifz_utils.js`);
  const book = u.book($app, e.request.pathValue("id"));
  const me = e.auth.id;
  book.set("listeners", u.list(book, "listeners").filter((x) => x !== me));
  book.set("checkers", u.list(book, "checkers").filter((x) => x !== me));
  $app.save(book);
  return e.json(200, { ok: true });
}, $apis.requireAuth());

// ── last writer wins ─────────────────────────────────────────────────────

// Refuse a write older than the stored copy (the app then pulls the newer
// one), and pull clocks that run far ahead back to the server's time.
onRecordUpdateRequest((e) => {
  const incoming = e.record.getInt("client_updated");
  const stored = e.record.original().getInt("client_updated");
  if (incoming < stored) {
    throw new ApiError(409, "A newer copy exists.", {});
  }
  const now = Date.now();
  if (incoming > now + 5 * 60 * 1000) e.record.set("client_updated", now);
  e.next();
}, "books", "sessions", "marks", "mark_fixes", "mark_comments", "mark_links");

onRecordCreateRequest((e) => {
  const now = Date.now();
  if (e.record.getInt("client_updated") > now + 5 * 60 * 1000) {
    e.record.set("client_updated", now);
  }
  e.next();
}, "books", "sessions", "marks", "mark_fixes", "mark_comments", "mark_links");

// ── account deletion ─────────────────────────────────────────────────────

// Their own books go with them (books.owner cascades). What they wrote in
// other people's books belongs to those reciters' records: it stays, without
// their name.
onRecordDelete((e) => {
  const u = require(`${__hooks}/hifz_utils.js`);
  const uid = e.record.id;
  const shared = e.app.findRecordsByFilter(
    "books", "listeners.id ?= {:u} || checkers.id ?= {:u}", "", 0, 0, { u: uid });
  for (const b of shared) {
    b.set("listeners", u.list(b, "listeners").filter((x) => x !== uid));
    b.set("checkers", u.list(b, "checkers").filter((x) => x !== uid));
    e.app.save(b);
  }
  const authored = [
    ["sessions", "created_by", "listener_name"],
    ["marks", "author", "author_name"],
    ["mark_fixes", "fixed_by", "fixed_by_name"],
    ["mark_comments", "author", "author_name"],
    ["mark_links", "author", ""],
  ];
  for (const [coll, field, nameField] of authored) {
    const rows = e.app.findRecordsByFilter(
      coll, `${field} = {:u} && book.owner != {:u}`, "", 0, 0, { u: uid });
    for (const r of rows) {
      r.set(field, "");
      if (nameField && coll !== "sessions") r.set(nameField, "Deleted user");
      e.app.save(r);
    }
  }
  e.next();
}, "users");

// ── housekeeping ─────────────────────────────────────────────────────────

// Nightly: tombstones older than 90 days (every device has seen them by
// then) and expired share codes.
cronAdd("hifz_prune", "30 3 * * *", () => {
  const u = require(`${__hooks}/hifz_utils.js`);
  const cutoff = u.pbTime(new Date(Date.now() - 90 * 24 * 3600 * 1000));
  for (const coll of u.DATA) {
    const rows = $app.findRecordsByFilter(
      coll, "deleted = true && updated < {:t}", "", 1000, 0, { t: cutoff });
    for (const r of rows) $app.delete(r);
  }
  const old = $app.findRecordsByFilter(
    "invites", "expires < {:t}", "", 1000, 0, { t: u.pbTime(new Date()) });
  for (const r of old) $app.delete(r);
});
