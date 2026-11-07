import 'package:mobile_scanner/mobile_scanner.dart';

class QrDecodeResult {
  const QrDecodeResult({required this.rawValue, this.format});

  final String rawValue;
  final BarcodeFormat? format;
}

class QrToolService {
  static final MobileScannerController _analyzer = MobileScannerController();

  static Future<QrDecodeResult?> decodeImageFile(String path) async {
    final capture = await _analyzer.analyzeImage(path);
    final barcodes = capture?.barcodes ?? [];
    for (final code in barcodes) {
      final value = code.rawValue;
      if (value != null && value.isNotEmpty) {
        return QrDecodeResult(rawValue: value, format: code.format);
      }
    }
    return null;
  }

  static void dispose() => _analyzer.dispose();
}
