import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_merger/pdf_merger.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import 'file_export_service.dart';

class PdfToolsService {
  /// Merge PDFs in order (Android/iOS native). Falls back to error on desktop.
  static Future<String> mergePdfs(List<String> paths) async {
    if (paths.isEmpty) throw Exception('Add at least one PDF.');
    final out = await FileExportService.newOutputPath('merged');
    final result = await PdfMerger.mergeMultiplePDF(
      paths: paths,
      outputDirPath: out,
    );
    if (result.status != Status.success || result.response == null) {
      throw Exception(result.message ?? 'Merge failed.');
    }
    return result.response!;
  }

  /// Split [sourcePath] into PDFs with up to [pagesPerFile] pages each (default 1).
  static Future<List<String>> splitPdf({
    required String sourcePath,
    int pagesPerFile = 1,
  }) async {
    if (pagesPerFile < 1) pagesPerFile = 1;

    final doc = await pdfrx.PdfDocument.openFile(sourcePath);
    try {
      final total = doc.pages.length;
      if (total == 0) throw Exception('PDF has no pages.');

      final outputs = <String>[];
      for (var start = 0; start < total; start += pagesPerFile) {
        final end = math.min(start + pagesPerFile, total);
        final pdf = pw.Document();
        for (var i = start; i < end; i++) {
          final page = doc.pages[i];
          final targetW = (page.width * 2).round().clamp(360, 2400);
          final targetH = (page.height * 2).round().clamp(360, 3200);
          final rendered = await page.render(
            fullWidth: targetW.toDouble(),
            fullHeight: targetH.toDouble(),
          );
          if (rendered == null) continue;
          final pngBytes = _bgraToPng(rendered.pixels, rendered.width, rendered.height);
          rendered.dispose();
          final image = pw.MemoryImage(pngBytes);
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(
                page.width,
                page.height,
                marginAll: 0,
              ),
              build: (_) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(image, fit: pw.BoxFit.fill),
              ),
            ),
          );
        }
        final out = await FileExportService.newOutputPath('split_${start + 1}_$end');
        await File(out).writeAsBytes(await pdf.save(), flush: true);
        outputs.add(out);
      }
      return outputs;
    } finally {
      await doc.dispose();
    }
  }

  /// Build a single PDF from image files (one page per image).
  static Future<String> imagesToPdf(
    List<String> imagePaths, {
    bool fitToA4 = true,
  }) async {
    if (imagePaths.isEmpty) throw Exception('Add at least one image.');

    final pdf = pw.Document();
    for (final path in imagePaths) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Center(
            child: pw.Image(
              image,
              fit: fitToA4 ? pw.BoxFit.contain : pw.BoxFit.scaleDown,
            ),
          ),
        ),
      );
    }

    final out = await FileExportService.newOutputPath('scan');
    await File(out).writeAsBytes(await pdf.save(), flush: true);
    return out;
  }

  static Uint8List _bgraToPng(Uint8List bgra, int width, int height) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        image.setPixelRgba(
          x,
          y,
          bgra[i + 2],
          bgra[i + 1],
          bgra[i],
          bgra[i + 3],
        );
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  static String basename(String path) => p.basename(path);
}
