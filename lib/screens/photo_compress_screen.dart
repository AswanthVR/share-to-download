import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

import '../services/photo_compress_service.dart';
import '../widgets/glass_ui.dart';

class PhotoCompressScreen extends StatefulWidget {
  const PhotoCompressScreen({super.key});

  @override
  State<PhotoCompressScreen> createState() => _PhotoCompressScreenState();
}

enum _CompressPhase { idle, compressing, done, error }

class _SizePreset {
  const _SizePreset(this.label, this.bytes);

  final String label;
  final int bytes;
}

class _PhotoCompressScreenState extends State<PhotoCompressScreen>
    with TickerProviderStateMixin {
  static const _presets = [
    _SizePreset('100 KB', 100 * 1024),
    _SizePreset('250 KB', 250 * 1024),
    _SizePreset('500 KB', 500 * 1024),
    _SizePreset('1 MB', 1024 * 1024),
    _SizePreset('2 MB', 2 * 1024 * 1024),
  ];

  final ImagePicker _picker = ImagePicker();

  String? _sourcePath;
  int _originalBytes = 0;
  int _selectedPresetIndex = 2;

  CompressResult? _result;
  _CompressPhase _phase = _CompressPhase.idle;
  double _progress = 0;
  String _errorMessage = '';

  late AnimationController _shimmer;
  late AnimationController _successPop;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _successPop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _successPop.dispose();
    super.dispose();
  }

  int get _targetBytes => _presets[_selectedPresetIndex].bytes;

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (file == null) return;

    final bytes = await File(file.path).length();
    setState(() {
      _sourcePath = file.path;
      _originalBytes = bytes;
      _result = null;
      _phase = _CompressPhase.idle;
      _progress = 0;
      _errorMessage = '';
    });
  }

  Future<void> _compress() async {
    if (_sourcePath == null) return;
    setState(() {
      _phase = _CompressPhase.compressing;
      _progress = 0;
      _result = null;
    });

    try {
      final result = await PhotoCompressService.compressToTargetSize(
        sourcePath: _sourcePath!,
        targetBytes: _targetBytes,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _CompressPhase.done;
      });
      _successPop.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _CompressPhase.error;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _save() async {
    final bytes = _result?.bytes;
    if (bytes == null) return;
    try {
      await PhotoCompressService.saveToGallery(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Saved to Gallery → "Compressed" album'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  void _reset() {
    setState(() {
      _sourcePath = null;
      _originalBytes = 0;
      _result = null;
      _phase = _CompressPhase.idle;
      _progress = 0;
    });
    _successPop.reset();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFF5B4DFF);

    return GlassScaffold(
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Photo compress',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.4),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPreviewCard(isDark, accent),
              const SizedBox(height: 20),
              Text(
                'Target file size',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 10),
              _buildPresetRow(accent),
              const SizedBox(height: 20),
              if (_sourcePath != null) _buildSizeComparison(isDark, accent),
              if (_phase == _CompressPhase.compressing) ...[
                const SizedBox(height: 16),
                _buildProgress(accent),
              ],
              if (_phase == _CompressPhase.error) ...[
                const SizedBox(height: 12),
                _buildErrorBanner(),
              ],
              const SizedBox(height: 24),
              _buildActions(accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(bool isDark, Color accent) {
    final hasImage = _sourcePath != null;
    return GlassPressable(
      onTap: _phase == _CompressPhase.compressing ? () {} : _pickImage,
      child: AnimatedContainer(
        duration: AppleMotion.panelMs,
        curve: AppleMotion.standard,
        height: hasImage ? 260 : 200,
        child: FrostedPanel(
          borderRadius: 26,
          blur: hasImage ? 12 : GlassTokens.blur(context),
          borderColor: hasImage
              ? accent.withValues(alpha: 0.45)
              : GlassTokens.border(context),
          padding: EdgeInsets.zero,
          child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.file(
                  File(_sourcePath!),
                  fit: BoxFit.cover,
                )
              else
                _buildEmptyDropZone(isDark, accent),
              if (!hasImage)
                AnimatedBuilder(
                  animation: _shimmer,
                  builder: (_, __) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1 + _shimmer.value * 2, -1),
                          end: Alignment(1 + _shimmer.value * 2, 1),
                          colors: [
                            Colors.transparent,
                            accent.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              if (hasImage && _phase != _CompressPhase.compressing)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.swap_horiz_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildEmptyDropZone(bool isDark, Color accent) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.2),
                  const Color(0xFF00C9FF).withValues(alpha: 0.15),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_photo_alternate_rounded,
                size: 40, color: accent),
          ),
          const SizedBox(height: 14),
          const Text('Tap to choose a photo',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'From your gallery',
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[500] : Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetRow(Color accent) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == _selectedPresetIndex;
          final busy = _phase == _CompressPhase.compressing;
          return GlassSegmentChip(
            label: _presets[i].label,
            selected: selected,
            accent: accent,
            onTap: busy
                ? () {}
                : () => setState(() {
                      _selectedPresetIndex = i;
                      _result = null;
                      _phase = _CompressPhase.idle;
                    }),
          );
        },
      ),
    );
  }

  Widget _buildSizeComparison(bool isDark, Color accent) {
    final compressed = _result?.compressedBytes;
    final originalLabel = PhotoCompressService.formatBytes(_originalBytes);
    final targetLabel = _presets[_selectedPresetIndex].label;

    return AnimatedSwitcher(
      duration: AppleMotion.panelMs,
      switchInCurve: AppleMotion.standard,
      switchOutCurve: Curves.easeInCubic,
      child: _result == null
          ? _InfoStrip(
              key: const ValueKey('target'),
              isDark: isDark,
              accent: accent,
              leftLabel: 'Original',
              leftValue: originalLabel,
              rightLabel: 'Target',
              rightValue: '≤ $targetLabel',
            )
          : ScaleTransition(
              key: const ValueKey('result'),
              scale: CurvedAnimation(
                parent: _successPop,
                curve: AppleMotion.springy,
              ),
              child: _InfoStrip(
                isDark: isDark,
                accent: accent,
                leftLabel: 'Before',
                leftValue: originalLabel,
                rightLabel: 'After',
                rightValue: PhotoCompressService.formatBytes(compressed!),
                savings: _result!.savingsRatio,
              ),
            ),
    );
  }

  Widget _buildProgress(Color accent) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _progress),
            duration: const Duration(milliseconds: 200),
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: accent,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Compressing… ${(_progress * 100).round()}%',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return FrostedPanel(
      borderRadius: 16,
      tint: Colors.red.withValues(alpha: 0.12),
      borderColor: Colors.red.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Color accent) {
    final compressing = _phase == _CompressPhase.compressing;
    final hasResult = _result != null;

    if (hasResult) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await Gal.open();
                } catch (_) {}
              },
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_alt_rounded, size: 20),
              label: const Text('Save compressed',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        GlassPrimaryButton(
          onPressed:
              _sourcePath == null || compressing ? null : _compress,
          busy: compressing,
          accent: accent,
          icon: Icons.compress_rounded,
          label: compressing ? 'Compressing…' : 'Compress now',
        ),
        if (_sourcePath != null) ...[
          const SizedBox(height: 12),
          GlassPressable(
            onTap: compressing ? () {} : _reset,
            child: FrostedPanel(
              borderRadius: 14,
              blur: 12,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Center(
                child: Text(
                  'Choose another photo',
                  style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    super.key,
    required this.isDark,
    required this.accent,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    this.savings,
  });

  final bool isDark;
  final Color accent;
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  final double? savings;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      borderRadius: 18,
      borderColor: accent.withValues(alpha: 0.25),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: _cell(leftLabel, leftValue, isMuted: true)),
          Container(
            width: 1,
            height: 36,
            color: Colors.grey.withValues(alpha: 0.25),
          ),
          Expanded(child: _cell(rightLabel, rightValue, highlight: true)),
          if (savings != null && savings! > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '−${(savings! * 100).round()}%',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(String label, String value,
      {bool isMuted = false, bool highlight = false}) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            )),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: highlight ? accent : null,
          ),
        ),
      ],
    );
  }
}
