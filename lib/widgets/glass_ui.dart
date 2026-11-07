import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Apple-like motion constants.
abstract final class AppleMotion {
  static const pageMs = Duration(milliseconds: 550);
  static const pageReverseMs = Duration(milliseconds: 420);
  static const pressMs = Duration(milliseconds: 380);
  static const panelMs = Duration(milliseconds: 480);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve entrance = Curves.easeOutQuart;
  static const Curve springy = Curves.easeOutBack;
}

class AppleGlassRoute<T> extends PageRouteBuilder<T> {
  AppleGlassRoute({required Widget page, super.settings})
      : super(
          transitionDuration: AppleMotion.pageMs,
          reverseTransitionDuration: AppleMotion.pageReverseMs,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final inCurve = CurvedAnimation(
              parent: animation,
              curve: AppleMotion.standard,
              reverseCurve: Curves.easeInCubic,
            );
            final scale = Tween<double>(begin: 0.94, end: 1).animate(inCurve);
            final fade = Tween<double>(begin: 0, end: 1).animate(inCurve);
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(inCurve);

            final dim = Tween<double>(begin: 0, end: 0.06).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeOut,
              ),
            );

            return Stack(
              children: [
                FadeTransition(
                  opacity: dim,
                  child: const ColoredBox(color: Colors.black),
                ),
                FadeTransition(
                  opacity: fade,
                  child: SlideTransition(
                    position: slide,
                    child: ScaleTransition(
                      scale: scale,
                      child: child,
                    ),
                  ),
                ),
              ],
            );
          },
        );
}

void pushAppleGlassPage(BuildContext context, Widget page) {
  Navigator.of(context).push(AppleGlassRoute(page: page));
}

class GlassTokens {
  static double blur(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? 28 : 22;

  static Color fill(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const Color(0xFF2A2A2E).withValues(alpha: 0.42)
        : Colors.white.withValues(alpha: 0.52);
  }

  static Color border(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.85);
  }

  static Color subtleBorder(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.06);
  }
}

/// Slow-drifting color blobs behind frosted panels.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF0A0A0C) : const Color(0xFFE8ECF4);

    return AnimatedBuilder(
      animation: _drift,
      builder: (context, child) {
        final t = _drift.value * 2 * math.pi;
        return DecoratedBox(
          decoration: BoxDecoration(color: base),
          child: Stack(
            children: [
              _blob(
                alignment: Alignment(
                  math.sin(t) * 0.55,
                  math.cos(t * 0.7) * 0.35 - 0.5,
                ),
                size: 320,
                color: const Color(0xFFE60023).withValues(alpha: dark ? 0.35 : 0.28),
              ),
              _blob(
                alignment: Alignment(
                  math.cos(t * 0.9) * 0.5,
                  math.sin(t * 0.8) * 0.4 + 0.45,
                ),
                size: 280,
                color: const Color(0xFF5B4DFF).withValues(alpha: dark ? 0.32 : 0.22),
              ),
              _blob(
                alignment: Alignment(
                  math.sin(t * 1.1 + 1) * 0.45,
                  math.cos(t * 0.6 + 2) * 0.3,
                ),
                size: 240,
                color: const Color(0xFF00C9FF).withValues(alpha: dark ? 0.22 : 0.18),
              ),
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }

  Widget _blob({
    required Alignment alignment,
    required double size,
    required Color color,
  }) {
    return Align(
      alignment: alignment,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: appBar != null,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        body: body,
      ),
    );
  }
}

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final Widget title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassTokens.blur(context) * 0.65,
          sigmaY: GlassTokens.blur(context) * 0.65,
        ),
        child: Container(
          height: preferredSize.height + top,
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            color: GlassTokens.fill(context).withValues(alpha: 0.55),
            border: Border(
              bottom: BorderSide(color: GlassTokens.subtleBorder(context)),
            ),
          ),
          child: NavigationToolbar(
            leading: leading,
            middle: title,
            trailing: trailing,
            centerMiddle: true,
          ),
        ),
      ),
    );
  }
}

class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 22,
    this.blur,
    this.tint,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double? blur;
  final Color? tint;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final sigma = blur ?? GlassTokens.blur(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint ?? GlassTokens.fill(context),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? GlassTokens.border(context),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.28
                      : 0.07,
                ),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Subtle scale-down on press, springy release (Apple tap feel).
class GlassPressable extends StatefulWidget {
  const GlassPressable({
    super.key,
    required this.onTap,
    required this.child,
    this.pressedScale = 0.97,
  });

  final VoidCallback onTap;
  final Widget child;
  final double pressedScale;

  @override
  State<GlassPressable> createState() => _GlassPressableState();
}

class _GlassPressableState extends State<GlassPressable>
    with SingleTickerProviderStateMixin {
  late double _scale = 1;

  void _setPressed(bool pressed) {
    setState(() => _scale = pressed ? widget.pressedScale : 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: AppleMotion.pressMs,
        curve: _scale < 1 ? Curves.easeOutCubic : AppleMotion.springy,
        child: widget.child,
      ),
    );
  }
}

class GlassSegmentChip extends StatelessWidget {
  const GlassSegmentChip({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: onTap,
      pressedScale: 0.95,
      child: AnimatedContainer(
        duration: AppleMotion.panelMs,
        curve: AppleMotion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? accent.withValues(alpha: 0.22)
              : GlassTokens.fill(context).withValues(alpha: 0.35),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.55) : GlassTokens.subtleBorder(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? accent : null,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

class GlassPrimaryButton extends StatelessWidget {
  const GlassPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.accent = const Color(0xFF5B4DFF),
    this.busy = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color accent;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: onPressed == null,
      child: GlassPressable(
        onTap: onPressed ?? () {},
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: onPressed == null ? 0.45 : 1,
          child: FrostedPanel(
          borderRadius: 16,
          blur: 14,
          tint: accent.withValues(alpha: 0.75),
          borderColor: accent.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
