import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileExportService {
  static Future<String> newOutputPath(String basename) async {
    final dir = await getApplicationDocumentsDirectory();
    final exports = Directory(p.join(dir.path, 'UtilityBox'));
    if (!await exports.exists()) {
      await exports.create(recursive: true);
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safe = basename.replaceAll(RegExp(r'[^\w\-.]+'), '_');
    return p.join(exports.path, '${safe}_$stamp.pdf');
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  static Future<void> shareFiles(List<String> paths, {String? text}) async {
    final files = paths.map((path) => XFile(path)).toList();
    await SharePlus.instance.share(
      ShareParams(files: files, text: text),
    );
  }

  static Future<void> shareFile(String path, {String? text}) =>
      shareFiles([path], text: text);
}
