import 'package:flutter/material.dart';

import '../branding/omnix_brand.dart';
import '../widgets/glass_ui.dart';
import '../widgets/omnix_logo.dart';
import 'downloader_screen.dart';
import 'pdf_studio_screen.dart';
import 'photo_compress_screen.dart';
import 'qr_tool_screen.dart';

class UtilitiesHubScreen extends StatefulWidget {
  const UtilitiesHubScreen({super.key});

  @override
  State<UtilitiesHubScreen> createState() => _UtilitiesHubScreenState();
}

class _UtilitiesHubScreenState extends State<UtilitiesHubScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _logoPulse;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;
  late final Animation<double> _headerFade;

  static final _tools = [
    _UtilityTool(
      title: OmnixBrand.toolCopy[0].$1,
      subtitle: OmnixBrand.toolCopy[0].$2,
      icon: Icons.download_rounded,
      gradient: const [Color(0xFFE60023), Color(0xFFFF4060)],
    ),
    _UtilityTool(
      title: OmnixBrand.toolCopy[1].$1,
      subtitle: OmnixBrand.toolCopy[1].$2,
      icon: Icons.compress_rounded,
      gradient: const [Color(0xFF5B4DFF), Color(0xFF00C9FF)],
    ),
    _UtilityTool(
      title: OmnixBrand.toolCopy[2].$1,
      subtitle: OmnixBrand.toolCopy[2].$2,
      icon: Icons.qr_code_scanner_rounded,
      gradient: const [Color(0xFF00C97A), Color(0xFF5EFCE8)],
    ),
    _UtilityTool(
      title: OmnixBrand.toolCopy[3].$1,
      subtitle: OmnixBrand.toolCopy[3].$2,
      icon: Icons.picture_as_pdf_rounded,
      gradient: const [Color(0xFFFF8A3D), Color(0xFFFFD26B)],
    ),
    _UtilityTool(
      title: OmnixBrand.toolCopy[4].$1,
      subtitle: OmnixBrand.toolCopy[4].$2,
      icon: Icons.document_scanner_outlined,
      gradient: const [Color(0xFF7B61FF), Color(0xFFB693FF)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _logoPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _headerFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0, 0.35, curve: AppleMotion.entrance),
    );

    _fades = List.generate(_tools.length, (i) {
      final start = 0.15 + i * 0.085;
      final end = (start + 0.45).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entrance,
        curve: Interval(start, end, curve: AppleMotion.entrance),
      );
    });
    _slides = List.generate(_tools.length, (i) {
      final start = 0.15 + i * 0.085;
      final end = (start + 0.45).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
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
    _logoPulse.dispose();
    super.dispose();
  }

  void _openTool(int index) {
    final page = switch (index) {
      0 => const DownloaderScreen(),
      1 => const PhotoCompressScreen(),
      2 => const QrToolScreen(),
      3 => const PdfStudioScreen(initialTab: PdfStudioTab.merge),
      _ => const PdfStudioScreen(initialTab: PdfStudioTab.images),
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
            SliverToBoxAdapter(child: _buildSectionTitle(isDark)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return FadeTransition(
                      opacity: _fades[index],
                      child: SlideTransition(
                        position: _slides[index],
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _UtilityCard(
                            tool: _tools[index],
                            index: index,
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
    return FadeTransition(
      opacity: _headerFade,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.02).animate(
                    CurvedAnimation(parent: _logoPulse, curve: Curves.easeInOut),
                  ),
                  child: const OmnixLogo(size: 64, showWordmark: true),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FrostedPanel(
              borderRadius: 18,
              blur: 16,
              borderColor: OmnixBrand.primary.withValues(alpha: 0.22),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 20,
                    color: OmnixBrand.primary.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          OmnixBrand.tagline,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : OmnixBrand.slate,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          OmnixBrand.workspaceLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Text(
        'Applications',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
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
  const _UtilityCard({
    required this.tool,
    required this.index,
    required this.onTap,
  });

  final _UtilityTool tool;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassPressable(
      onTap: onTap,
      child: FrostedPanel(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: tool.gradient),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: tool.gradient.first.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(tool.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tool.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        (index + 1).toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tool.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      letterSpacing: -0.1,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
