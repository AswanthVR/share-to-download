import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class CompressResult {
  const CompressResult({
    required this.bytes,
    required this.originalBytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int originalBytes;
  final int width;
  final int height;

  int get compressedBytes => bytes.length;

  double get savingsRatio =>
      originalBytes > 0 ? 1 - (compressedBytes / originalBytes) : 0;
}

class PhotoCompressService {
  PhotoCompressService._();

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  static Future<(int width, int height)> decodeDimensions(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = (image.width, image.height);
    image.dispose();
    return size;
  }

  /// Compress [sourcePath] to roughly [targetBytes] (or closest under).
  static Future<CompressResult> compressToTargetSize({
    required String sourcePath,
    required int targetBytes,
    void Function(double progress)? onProgress,
  }) async {
    final originalFile = File(sourcePath);
    if (!await originalFile.exists()) {
      throw Exception('Image file not found.');
    }

    final originalBytes = await originalFile.length();
    final originalData = await originalFile.readAsBytes();
    final (origW, origH) = await decodeDimensions(originalData);

    onProgress?.call(0.05);

    if (targetBytes >= originalBytes) {
      onProgress?.call(1);
      return CompressResult(
        bytes: originalData,
        originalBytes: originalBytes,
        width: origW,
        height: origH,
      );
    }

    Uint8List? closest;
    var step = 0;
    const totalSteps = 42.0;

    for (var scale = 1.0; scale >= 0.25; scale -= 0.12) {
      final maxSide = (4096 * scale).clamp(320, 4096).toInt();
      var quality = 92;

      while (quality >= 18) {
        step++;
        onProgress?.call((step / totalSteps).clamp(0.0, 0.95));

        final out = await FlutterImageCompress.compressWithFile(
          sourcePath,
          quality: quality,
          minWidth: maxSide,
          minHeight: maxSide,
          format: CompressFormat.jpeg,
        );

        if (out != null && out.isNotEmpty) {
          if (out.length <= targetBytes) {
            onProgress?.call(1);
            final (w, h) = await decodeDimensions(out);
            return CompressResult(
              bytes: out,
              originalBytes: originalBytes,
              width: w,
              height: h,
            );
          }
          if (closest == null || out.length < closest.length) {
            closest = out;
          }
        }
        quality -= 7;
      }
    }

    if (closest == null) {
      throw Exception('Could not compress this image.');
    }

    onProgress?.call(1);
    final (w, h) = await decodeDimensions(closest);
    return CompressResult(
      bytes: closest,
      originalBytes: originalBytes,
      width: w,
      height: h,
    );
  }

  static Future<void> saveToGallery(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(bytes, flush: true);

    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        throw Exception('Gallery permission was denied.');
      }
    }
    await Gal.putImage(path, album: 'Compressed');
  }
}
