import 'qiraah_icons.dart';

/// Every icon the app shows, by what it is for.
///
/// All come from the redesign's `QiraahIcons` font (96 glyphs; the 49 that
/// were Material stand-ins were drawn in handoff update 7 — see
/// docs/icons_needed.md). A new icon gets a glyph there first, or a
/// `// stand-in` Material icon here until it does.
abstract final class AppIcons {
  // ── navigation ──
  static const today = QiraahIcons.home;
  static const reader = QiraahIcons.reader;
  static const mushaf = QiraahIcons.mushaf;
  static const learn = QiraahIcons.learn;
  static const trace = QiraahIcons.trace;
  static const settings = QiraahIcons.settings;
  static const tajweed = QiraahIcons.tajweed;
  static const sidebarShow = QiraahIcons.sidebarShow;
  static const sidebarHide = QiraahIcons.sidebarHide;
  static const coach = QiraahIcons.coach;

  // ── moving around ──
  static const back = QiraahIcons.back;
  static const forward = QiraahIcons.chevronRight;
  static const chevronRight = QiraahIcons.chevronRight;
  static const chevronLeft = QiraahIcons.chevronLeft;
  static const chevronDown = QiraahIcons.chevronDown;
  static const chevronUp = QiraahIcons.chevronUp;
  static const close = QiraahIcons.close;
  static const search = QiraahIcons.search;

  // ── audio ──
  static const play = QiraahIcons.play;
  static const pause = QiraahIcons.pause;
  static const stop = QiraahIcons.stop;
  static const skipPrevious = QiraahIcons.skipPrevious;
  static const skipNext = QiraahIcons.skipNext;
  static const repeat = QiraahIcons.repeat;
  static const recite = QiraahIcons.recite;
  static const wordByWord = QiraahIcons.wordByWord;
  static const volume = QiraahIcons.volume;
  static const unpin = QiraahIcons.unpin;
  static const dock = QiraahIcons.dockBottom;
  static const dragHandle = QiraahIcons.dragHandle;
  static const mic = QiraahIcons.mic;
  static const video = QiraahIcons.video;

  // ── reading ──
  static const tune = QiraahIcons.tune;
  static const bookmark = QiraahIcons.bookmark;
  static const bookmarkFilled = QiraahIcons.bookmarkFilled;
  static const gapDecrease = QiraahIcons.gapDecrease;
  static const gapIncrease = QiraahIcons.gapIncrease;
  static const focus = QiraahIcons.focus;
  static const focusExit = QiraahIcons.focusExit;
  static const viewSpread = QiraahIcons.viewSpread;
  static const viewSingle = QiraahIcons.viewSingle;
  static const fitWidth = QiraahIcons.fitWidth;
  static const rotate = QiraahIcons.rotate;
  static const pageColour = QiraahIcons.contrast;
  static const indexList = QiraahIcons.indexList;

  // ── learning ──
  static const quiz = QiraahIcons.quiz;
  static const check = QiraahIcons.check;
  static const star = QiraahIcons.starFilled;
  static const starOutline = QiraahIcons.star;
  static const streak = QiraahIcons.streak;
  static const timer = QiraahIcons.timer;
  static const reset = QiraahIcons.reset;
  static const lock = QiraahIcons.lock;
  static const textSize = QiraahIcons.textSize;
  static const gridView = QiraahIcons.gridView;
  static const listView = QiraahIcons.indexList;
  static const shapeHeight = QiraahIcons.shapeHeight;
  static const shapeJoin = QiraahIcons.shapeJoin;
  static const shapeRoute = QiraahIcons.shapeRoute;
  static const shapeStack = QiraahIcons.shapeStack;
  static const bolt = QiraahIcons.bolt;
  static const comfort = QiraahIcons.comfort;
  static const dots = QiraahIcons.dots;
  static const zoom = QiraahIcons.zoom;
  static const dot = QiraahIcons.dot;
  static const speed = QiraahIcons.speed;

  // ── settings & data ──
  static const bell = QiraahIcons.bell;
  static const download = QiraahIcons.download;
  static const upload = QiraahIcons.upload;
  static const delete = QiraahIcons.delete;
  static const sync = QiraahIcons.sync;
  static const partial = QiraahIcons.partial;
  static const devices = QiraahIcons.devices;
  static const phone = QiraahIcons.phone;
  static const desktop = QiraahIcons.desktop;
  static const brush = QiraahIcons.brush;
  static const document = QiraahIcons.document;

  // ── hifz marks ──
  static const pen = QiraahIcons.pen;
  static const undo = QiraahIcons.undo;
  static const chart = QiraahIcons.chart;
  static const person = QiraahIcons.person;
  static const group = QiraahIcons.group;
  static const comment = QiraahIcons.comment;
  static const link = QiraahIcons.link;
  static const cloud = QiraahIcons.cloud;
  static const hifz = QiraahIcons.hifz;
  static const add = QiraahIcons.add;
  static const more = QiraahIcons.more;
  static const review = QiraahIcons.review;
  static const cards = QiraahIcons.cards;
  static const memorize = QiraahIcons.memorize;
  static const show = QiraahIcons.show;
  static const nextVerse = QiraahIcons.nextVerse;
  static const prevVerse = QiraahIcons.prevVerse;
  static const pdf = QiraahIcons.pdf;
  static const textBigger = QiraahIcons.textBigger;
  static const textSmaller = QiraahIcons.textSmaller;
  static const pageOn = QiraahIcons.pageOn;
}
