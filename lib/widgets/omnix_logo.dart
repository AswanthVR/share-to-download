import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../branding/omnix_brand.dart';

/// Animated OMNIX mark — hex ring + core glyph.
class OmnixLogo extends StatefulWidget {
  const OmnixLogo({
    super.key,
    this.size = 72,
    this.showWordmark = false,
    this.animate = true,
  });

  final double size;
  final bool showWordmark;
  final bool animate;

  @override
  State<OmnixLogo> createState() => _OmnixLogoState();
}

class _OmnixLogoState extends State<OmnixLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    if (widget.animate) _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (_, child) => Transform.rotate(
          angle: widget.animate ? _spin.value * 2 * math.pi : 0,
          child: child,
        ),
        child: CustomPaint(
          painter: _OmnixMarkPainter(
            primary: OmnixBrand.primary,
            accent: OmnixBrand.primaryDark,
            glyphSize: widget.size * 0.32,
          ),
        ),
      ),
    );

    if (!widget.showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              OmnixBrand.name,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                height: 1,
              ),
            ),
            SizedBox(height: 4),
            Text(
              OmnixBrand.versionLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.4,
                color: OmnixBrand.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OmnixMarkPainter extends CustomPainter {
  _OmnixMarkPainter({
    required this.primary,
    required this.accent,
    required this.glyphSize,
  });

  final Color primary;
  final Color accent;
  final double glyphSize;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.42;

    final ring = Paint()
      ..shader = SweepGradient(
        colors: [primary, accent, primary.withValues(alpha: 0.4), primary],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final p = c + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, ring);

    final core = Paint()
      ..shader = RadialGradient(
        colors: [accent, primary],
      ).createShader(Rect.fromCircle(center: c, radius: r * 0.55));
    canvas.drawCircle(c, r * 0.38, core);

    final text = TextPainter(
      text: TextSpan(
        text: 'O',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: glyphSize,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, c - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
