import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/qr_tool_service.dart';
import '../widgets/glass_ui.dart';

class QrToolScreen extends StatefulWidget {
  const QrToolScreen({super.key});

  @override
  State<QrToolScreen> createState() => _QrToolScreenState();
}

class _QrToolScreenState extends State<QrToolScreen> {
  final ImagePicker _picker = ImagePicker();
  final MobileScannerController _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  String _payload = '';
  String _source = '';
  bool _busy = false;
  bool _showCamera = true;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _setResult(String value, String source) {
    setState(() {
      _payload = value;
      _source = source;
    });
  }

  Future<void> _fromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _snack('Clipboard is empty');
      return;
    }
    _setResult(text, 'Clipboard');
  }

  Future<void> _fromGallery() async {
    setState(() => _busy = true);
    try {
      final pick = await _picker.pickImage(source: ImageSource.gallery);
      if (pick == null) return;
      final decoded = await QrToolService.decodeImageFile(pick.path);
      if (decoded == null) {
        _snack('No QR or barcode found in this image');
        return;
      }
      _setResult(decoded.rawValue, 'Gallery');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    for (final code in capture.barcodes) {
      final value = code.rawValue;
      if (value != null && value.isNotEmpty) {
        _setResult(value, 'Camera');
        _camera.stop();
        setState(() => _showCamera = false);
        break;
      }
    }
  }

  Future<void> _copy() async {
    if (_payload.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _payload));
    _snack('Copied');
  }

  Future<void> _openIfUrl() async {
    final uri = Uri.tryParse(_payload);
    if (uri == null || !uri.hasScheme) {
      _snack('Not a valid URL');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Could not open link');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  bool get _looksLikeUrl {
    final uri = Uri.tryParse(_payload);
    return uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00C97A);
    return GlassScaffold(
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'QR & barcode',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.4),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            FrostedPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: GlassPressable(
                      onTap: _busy ? () {} : _fromClipboard,
                      child: _actionChip(Icons.content_paste_rounded, 'Clipboard'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassPressable(
                      onTap: _busy ? () {} : _fromGallery,
                      child: _actionChip(Icons.photo_library_outlined, 'Gallery'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassPressable(
                      onTap: () => setState(() {
                        _showCamera = true;
                        _camera.start();
                      }),
                      child: _actionChip(Icons.qr_code_scanner_rounded, 'Scan'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_showCamera)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 280,
                  child: MobileScanner(
                    controller: _camera,
                    onDetect: _onDetect,
                  ),
                ),
              ),
            if (_payload.isNotEmpty) ...[
              const SizedBox(height: 16),
              FrostedPanel(
                borderColor: accent.withValues(alpha: 0.35),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'From $_source',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white54
                            : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _payload,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GlassPressable(
                      onTap: _copy,
                      child: FrostedPanel(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: const Center(child: Text('Copy', style: TextStyle(fontWeight: FontWeight.w600))),
                      ),
                    ),
                  ),
                  if (_looksLikeUrl) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassPrimaryButton(
                        accent: accent,
                        label: 'Open link',
                        icon: Icons.open_in_new_rounded,
                        onPressed: _openIfUrl,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionChip(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 26),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
