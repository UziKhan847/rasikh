import 'package:flutter/material.dart' show Icons;
import 'qiraah_icons.dart';

/// Every icon the app shows, by what it is for.
///
/// Most come from the redesign's `QiraahIcons` font. The ones that font does
/// not cover yet are marked `// stand-in`: a neutral Material Rounded icon used
/// until the matching Qiraah icon is drawn (see docs/icons_needed.md). Swapping
/// one in is a one-line change here.
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
  static const coach = Icons.remove_red_eye_rounded; // stand-in

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
  static const stop = Icons.stop_rounded; // stand-in
  static const skipPrevious = QiraahIcons.skipPrevious;
  static const skipNext = QiraahIcons.skipNext;
  static const repeat = QiraahIcons.repeat;
  static const recite = QiraahIcons.recite;
  static const wordByWord = QiraahIcons.wordByWord;
  static const volume = QiraahIcons.volume;
  static const unpin = QiraahIcons.unpin;
  static const dock = QiraahIcons.dockBottom;
  static const dragHandle = QiraahIcons.dragHandle;
  static const mic = Icons.mic_none_rounded; // stand-in
  static const video = Icons.ondemand_video_rounded; // stand-in

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
  static const lock = Icons.lock_outline_rounded; // stand-in
  static const textSize = Icons.text_fields_rounded; // stand-in
  static const gridView = Icons.grid_view_rounded; // stand-in
  static const listView = QiraahIcons.indexList;
  static const shapeHeight = Icons.height_rounded; // stand-in
  static const shapeJoin = Icons.link_rounded; // stand-in
  static const shapeRoute = Icons.route_rounded; // stand-in
  static const shapeStack = Icons.layers_rounded; // stand-in
  static const bolt = Icons.bolt_rounded; // stand-in
  static const comfort = Icons.auto_fix_high_rounded; // stand-in
  static const dots = Icons.blur_on_rounded; // stand-in
  static const zoom = Icons.zoom_out_map_rounded; // stand-in
  static const dot = Icons.brightness_1; // stand-in
  static const speed = Icons.speed_rounded; // stand-in

  // ── settings & data ──
  static const bell = Icons.notifications_none_rounded; // stand-in
  static const download = Icons.download_rounded; // stand-in
  static const upload = Icons.upload_rounded; // stand-in
  static const delete = Icons.delete_outline_rounded; // stand-in
  static const sync = Icons.sync_rounded; // stand-in
  static const partial = Icons.incomplete_circle_rounded; // stand-in
  static const devices = Icons.devices_rounded; // stand-in
  static const phone = Icons.smartphone_rounded; // stand-in
  static const desktop = Icons.desktop_windows_rounded; // stand-in
  static const brush = Icons.brush_rounded; // stand-in
  static const document = Icons.description_outlined; // stand-in

  // ── hifz marks ──
  static const pen = Icons.edit_rounded; // stand-in
  static const undo = Icons.undo_rounded; // stand-in
  static const chart = Icons.insights_rounded; // stand-in
  static const person = Icons.person_outline_rounded; // stand-in
  static const group = Icons.group_outlined; // stand-in
  static const comment = Icons.chat_bubble_outline_rounded; // stand-in
  static const link = Icons.link_rounded; // stand-in
  static const cloud = Icons.cloud_outlined; // stand-in
  static const hifz = Icons.hearing_rounded; // stand-in
  static const add = Icons.add_rounded; // stand-in
  static const more = Icons.more_horiz_rounded; // stand-in
  static const review = Icons.fact_check_outlined; // stand-in
  static const cards = Icons.view_carousel_outlined; // stand-in
  static const memorize = Icons.visibility_off_outlined; // stand-in
  static const show = Icons.visibility_outlined; // stand-in
  static const nextVerse = Icons.keyboard_double_arrow_left_rounded; // stand-in
  static const prevVerse = Icons.keyboard_double_arrow_right_rounded; // stand-in
  static const pdf = Icons.picture_as_pdf_outlined; // stand-in
  static const pageOn = Icons.first_page_rounded; // stand-in (points left: onward)
}
