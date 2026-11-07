import 'package:flutter/material.dart';

import '../widgets/glass_ui.dart';
import 'downloader_screen.dart';
import 'photo_compress_screen.dart';

class UtilitiesHubScreen extends StatefulWidget {
  const UtilitiesHubScreen({super.key});

  @override
  State<UtilitiesHubScreen> createState() => _UtilitiesHubScreenState();
}

class _UtilitiesHubScreenState extends State<UtilitiesHubScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;

  static const _tools = [
    _UtilityTool(
      title: 'Media downloader',
      subtitle: 'Pinterest & YouTube to gallery',
      icon: Icons.download_rounded,
      gradient: [Color(0xFFE60023), Color(0xFFFF4060)],
    ),
    _UtilityTool(
      title: 'Photo compress',
      subtitle: 'Shrink photos to a target size',
      icon: Icons.compress_rounded,
      gradient: [Color(0xFF5B4DFF), Color(0xFF00C9FF)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fades = List.generate(_tools.length, (i) {
      final start = 0.2 + i * 0.14;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entrance,
        curve: Interval(start, end, curve: AppleMotion.entrance),
      );
    });
    _slides = List.generate(_tools.length, (i) {
      final start = 0.2 + i * 0.14;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
          .animate(CurvedAnimation(
        parent: _entrance,
        curve: Interval(start, end, curve: AppleMotion.standard),
      ));
    });
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _openTool(int index) {
    final page = switch (index) {
      0 => const DownloaderScreen(),
      _ => const PhotoCompressScreen(),
    };
    pushAppleGlassPage(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassScaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(isDark)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return FadeTransition(
                      opacity: _fades[index],
                      child: SlideTransition(
                        position: _slides[index],
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _UtilityCard(
                            tool: _tools[index],
                            onTap: () => _openTool(index),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _tools.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FrostedPanel(
            borderRadius: 20,
            blur: 18,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.blur_on_rounded,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Personal tools in one place',
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Utility box',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilityTool {
  const _UtilityTool({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
}

class _UtilityCard extends StatelessWidget {
  const _UtilityCard({required this.tool, required this.onTap});

  final _UtilityTool tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassPressable(
      onTap: onTap,
      child: FrostedPanel(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: tool.gradient),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: tool.gradient.first.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(tool.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tool.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: -0.15,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
