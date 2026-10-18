// Shared helpers for hifz.pb.js. PocketBase runs each hook handler in its own
// context, so handlers load this with require() instead of closing over it.

module.exports = {
  // No 0/O, 1/I: codes are read aloud and typed.
  ALPHABET: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789",
  DATA: ["sessions", "marks", "mark_fixes", "mark_comments"],

  /** A Go []string as a JS array. */
  list(record, field) {
    const raw = record.getStringSlice(field);
    const out = [];
    for (let i = 0; i < raw.length; i++) out.push(raw[i]);
    return out;
  },

  /** The book named in the URL, or 404. */
  book(app, id) {
    try {
      return app.findRecordById("books", id);
    } catch (_) {
      throw new NotFoundError("No such book.");
    }
  },

  isMember(book, uid) {
    return book.getString("owner") === uid ||
      this.list(book, "listeners").includes(uid) ||
      this.list(book, "checkers").includes(uid);
  },

  /** PocketBase datetime text for a JS Date. */
  pbTime(d) {
    return d.toISOString().replace("T", " ");
  },
};
