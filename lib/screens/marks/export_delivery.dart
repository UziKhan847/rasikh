import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../ui/kit.dart' show showQToast;

/// What an export comes out as: the PDF, or an image of each of its pages.
enum ExportFormat { pdf, png, jpg }

/// Where it goes. [send]: a phone's share sheet; on a computer, which has none,
/// saved in Downloads and opened.
enum ExportAction { print, send, saveAs }

/// How an export is delivered.
class ExportOut {
  final ExportFormat format;
  final ExportAction action;
  const ExportOut(this.action, [this.format = ExportFormat.pdf]);
}

/// Dots per inch of an exported image: an A4 page about 1650 × 2340.
const kExportImageDpi = 200.0;

/// Hands a made PDF on as [out] asks. [name]: the PDF's file name; [pages]: the
/// muṣḥaf page each of its pages shows, for the images' names (null: numbered).
Future<void> deliverExport(BuildContext context, Uint8List pdf, String name, ExportOut out,
    {List<int>? pages}) async {
  if (out.format != ExportFormat.pdf) {
    return _deliverImages(context, pdf, name, out, pages);
  }
  switch (out.action) {
    case ExportAction.print:
      await Printing.layoutPdf(name: name, onLayout: (_) async => pdf);
    case ExportAction.saveAs:
      final at = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (at == null || !context.mounted) return;
      await _write(context, at.path, pdf);
    case ExportAction.send:
      if (isDesktopPlatform()) {
        // No share sheet to hand it to (and the printing plugin's Linux "share"
        // waits on xdg-open on the UI thread, freezing the window until the
        // viewer closes): saved and opened, unblocked.
        final path = await saveAndOpen(pdf, name);
        if (context.mounted && path != null) {
          showQToast(context, context.l10n.rpSavedTo(path));
        }
      } else {
        await Printing.sharePdf(bytes: pdf, filename: name);
      }
  }
}

Future<void> _write(BuildContext context, String path, Uint8List bytes) async {
  final l = context.l10n;
  final messenger = context;
  try {
    await File(path).writeAsBytes(bytes, flush: true);
    if (messenger.mounted) showQToast(messenger, l.rpSavedTo(path));
  } catch (e) {
    if (messenger.mounted) showQToast(messenger, '$e');
  }
}

/// [bytes] in the Downloads folder (else Documents) as [name], opened in what
/// the desktop opens it with, without waiting. Its path, or null if it failed.
Future<String?> saveAndOpen(Uint8List bytes, String name) async {
  try {
    final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes, flush: true);
    await _open(file.path);
    return file.path;
  } catch (e) {
    debugPrint('[export] save failed: $e');
    return null;
  }
}

Future<void> _open(String path) async {
  final (cmd, args) = Platform.isMacOS
      ? ('open', [path])
      : Platform.isWindows
          ? ('cmd', ['/c', 'start', '', path])
          : ('xdg-open', [path]);
  await Process.start(cmd, args, mode: ProcessStartMode.detached);
}

// ─────────────────────────── images ───────────────────────────

/// An image's file name, from its PDF's: `Zayd_marks_10_2026-11-05.png` with
/// the muṣḥaf page it shows, else the PDF's own name and its place.
@visibleForTesting
String exportImageName(String pdfName, int index, int total, int? page, String ext) {
  final base = pdfName.endsWith('.pdf') ? pdfName.substring(0, pdfName.length - 4) : pdfName;
  if (page != null) {
    final m = RegExp(r'_marks_[^_]+_(\d{4}-\d{2}-\d{2})$').firstMatch(base);
    if (m != null) return '${base.substring(0, m.start)}_marks_${page}_${m.group(1)}.$ext';
  }
  return total == 1 ? '$base.$ext' : '${base}_${index + 1}.$ext';
}

/// [pixels] (RGBA, on white) as a JPEG. Off the UI thread: see [compute].
@visibleForTesting
Uint8List encodeExportJpg((Uint8List pixels, int width, int height) r) {
  final image = img.Image.fromBytes(
      width: r.$2, height: r.$3, bytes: r.$1.buffer, numChannels: 4);
  return Uint8List.fromList(
      img.encodeJpg(img.compositeImage(
          img.Image(width: r.$2, height: r.$3, numChannels: 3)
            ..clear(img.ColorRgb8(255, 255, 255)),
          image), quality: 90));
}

Future<void> _deliverImages(BuildContext context, Uint8List pdf, String name, ExportOut out,
    List<int>? pages) async {
  final l = context.l10n;
  final ext = out.format == ExportFormat.jpg ? 'jpg' : 'png';
  // Where they go is asked first: nothing's made for a dialog cancelled.
  String? folder;
  if (out.action == ExportAction.saveAs) {
    folder = await getDirectoryPath();
    if (folder == null || !context.mounted) return;
  }
  final progress = ValueNotifier<int>(0);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (d) => AlertDialog(
      content: ValueListenableBuilder<int>(
        valueListenable: progress,
        builder: (d, n, _) => Row(children: [
          const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(width: 16),
          Expanded(child: Text(d.l10n.exMakingImages(n))),
        ]),
      ),
    ),
  );
  final images = <Uint8List>[];
  Object? error;
  try {
    await for (final raster in Printing.raster(pdf, dpi: kExportImageDpi)) {
      images.add(out.format == ExportFormat.jpg
          ? await compute(encodeExportJpg, (raster.pixels, raster.width, raster.height))
          : await raster.toPng());
      progress.value = images.length;
    }
  } catch (e, st) {
    error = e;
    debugPrint('[export] images: $e\n$st');
  }
  final made = [
    for (final (i, bytes) in images.indexed)
      (
        exportImageName(name, i, images.length,
            pages != null && i < pages.length ? pages[i] : null, ext),
        bytes,
      ),
  ];
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  progress.dispose();
  if (error != null || made.isEmpty) {
    showQToast(context, '${error ?? l.ppNone}');
    return;
  }
  try {
    if (folder != null) {
      await _writeAll(folder, made);
      if (context.mounted) showQToast(context, l.rpSavedTo(folder));
    } else if (isDesktopPlatform()) {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      await _writeAll(dir.path, made);
      await _open(dir.path);
      if (context.mounted) showQToast(context, l.rpSavedTo(dir.path));
    } else {
      // All in one share, so they arrive as a group.
      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}${Platform.pathSeparator}export');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      final paths = await _writeAll(dir.path, made);
      await SharePlus.instance.share(ShareParams(files: [for (final p in paths) XFile(p)]));
    }
  } catch (e) {
    if (context.mounted) showQToast(context, '$e');
  }
}

Future<List<String>> _writeAll(String folder, List<(String, Uint8List)> files) async => [
      for (final (name, bytes) in files)
        (await File('$folder${Platform.pathSeparator}$name').writeAsBytes(bytes, flush: true)).path,
    ];
