import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'services/pinterest_service.dart';
import 'services/youtube_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PinDownloadApp());
}

// ─── App ─────────────────────────────────────────────────────────────────────

class PinDownloadApp extends StatelessWidget {
  const PinDownloadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Downloader',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE60023),
        primary: const Color(0xFFE60023),
        brightness: brightness,
      ),
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF4F4F4),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        centerTitle: true,
      ),
      cardColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    );
  }
}

// ─── Source Enum ──────────────────────────────────────────────────────────────

enum MediaSource { unknown, pinterest, youtube }

MediaSource _detectSource(String url) {
  if (YouTubeService.isYouTubeUrl(url)) return MediaSource.youtube;
  if (url.contains('pinterest.com') || url.contains('pin.it')) return MediaSource.pinterest;
  return MediaSource.unknown;
}

// ─── Download State ───────────────────────────────────────────────────────────

enum DownloadState { idle, extracting, ready, downloading, success, error }

// ─── Home Screen ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const MethodChannel _shareChannel =
      MethodChannel('com.example.pin_download/share');

  final TextEditingController _urlController = TextEditingController();

  DownloadState _state = DownloadState.idle;
  String _statusMessage = '';
  double _progress = 0.0;

  // Pinterest
  PinterestVideoInfo? _pinInfo;

  // YouTube
  YouTubeVideoInfo? _ytInfo;
  YouTubeStreamOption? _selectedStream;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initShareReceiver();
  }

  void _initShareReceiver() {
    _shareChannel.invokeMethod<String>('getInitialSharedText').then((text) {
      if (text != null && text.isNotEmpty) _handleIncomingText(text);
    }).catchError((_) {});

    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedTextReceived') {
        final text = call.arguments as String?;
        if (text != null && text.isNotEmpty) _handleIncomingText(text);
      }
    });
  }

  void _handleIncomingText(String rawText) {
    final extracted = PinterestService.extractUrl(rawText);
    if (extracted != null) {
      setState(() => _urlController.text = extracted);
      _fetchVideoInfo(autoDownload: true);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.trim().isNotEmpty) {
      final url = PinterestService.extractUrl(text) ?? text.trim();
      setState(() => _urlController.text = url);
      _fetchVideoInfo(autoDownload: false);
    } else {
      _showSnackbar('Clipboard is empty');
    }
  }

  Future<void> _fetchVideoInfo({bool autoDownload = false}) async {
    final input = _urlController.text.trim();
    if (input.isEmpty) {
      _showSnackbar('Please paste a link');
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _state = DownloadState.extracting;
      _statusMessage = 'Fetching video info…';
      _pinInfo = null;
      _ytInfo = null;
      _selectedStream = null;
      _progress = 0.0;
    });

    try {
      final source = _detectSource(input);

      if (source == MediaSource.youtube) {
        final info = await YouTubeService.getVideoInfo(input);
        setState(() {
          _ytInfo = info;
          _selectedStream = info.streams.isNotEmpty ? info.streams.first : null;
          _state = DownloadState.ready;
          _statusMessage = '${info.streams.length} quality options found';
        });
        if (autoDownload && _selectedStream != null) await _startYouTubeDownload();
      } else {
        final info = await PinterestService.extractVideo(input);
        setState(() {
          _pinInfo = info;
          _state = DownloadState.ready;
          _statusMessage = 'Found video: ${info.quality ?? "HD"}';
        });
        if (autoDownload) await _startPinterestDownload();
      }
    } catch (e) {
      setState(() {
        _state = DownloadState.error;
        _statusMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _startPinterestDownload() async {
    if (_pinInfo == null) return;
    setState(() {
      _state = DownloadState.downloading;
      _progress = 0.0;
      _statusMessage = 'Downloading…';
    });
    try {
      await PinterestService.downloadAndSaveToGallery(
        videoUrl: _pinInfo!.videoUrl,
        onProgress: (p) => setState(() {
          _progress = p;
          _statusMessage = 'Downloading: ${(p * 100).toInt()}%';
        }),
      );
      setState(() {
        _state = DownloadState.success;
        _progress = 1.0;
        _statusMessage = 'Saved to Gallery → "Pinterest" album';
      });
    } catch (e) {
      setState(() {
        _state = DownloadState.error;
        _statusMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _startYouTubeDownload() async {
    if (_ytInfo == null || _selectedStream == null) return;
    setState(() {
      _state = DownloadState.downloading;
      _progress = 0.0;
      _statusMessage = 'Downloading ${_selectedStream!.label}…';
    });
    try {
      await YouTubeService.downloadStream(
        info: _ytInfo!,
        option: _selectedStream!,
        onProgress: (p) => setState(() {
          _progress = p;
          _statusMessage = 'Downloading: ${(p * 100).toInt()}%';
        }),
      );
      final dest = _selectedStream!.isAudioOnly
          ? 'Downloads folder'
          : 'Gallery → "YouTube" album';
      setState(() {
        _state = DownloadState.success;
        _progress = 1.0;
        _statusMessage = 'Saved to $dest ✓';
      });
    } catch (e) {
      setState(() {
        _state = DownloadState.error;
        _statusMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _reset() => setState(() {
        _urlController.clear();
        _state = DownloadState.idle;
        _pinInfo = null;
        _ytInfo = null;
        _selectedStream = null;
        _progress = 0.0;
        _statusMessage = '';
      });

  void _showSnackbar(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );

  @override
  void dispose() {
    _urlController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSourceChips(),
              const SizedBox(height: 16),
              _buildInputCard(isDark),
              const SizedBox(height: 12),
              _buildActionRow(),
              const SizedBox(height: 24),
              _buildResultArea(isDark),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE60023), Color(0xFFFF4060)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Media Downloader',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      );

  Widget _buildSourceChips() {
    final url = _urlController.text.trim();
    final source = url.isEmpty ? MediaSource.unknown : _detectSource(url);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SourceChip(
          icon: Icons.push_pin_rounded,
          label: 'Pinterest',
          color: const Color(0xFFE60023),
          active: source == MediaSource.pinterest,
        ),
        const SizedBox(width: 10),
        _SourceChip(
          icon: Icons.play_circle_filled,
          label: 'YouTube',
          color: const Color(0xFFFF0000),
          active: source == MediaSource.youtube,
        ),
      ],
    );
  }

  Widget _buildInputCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: _urlController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Paste Pinterest or YouTube link…',
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[400],
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFFE60023)),
          suffixIcon: _urlController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: _reset,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    final busy = _state == DownloadState.extracting || _state == DownloadState.downloading;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : _pasteFromClipboard,
            icon: const Icon(Icons.content_paste_rounded, size: 18),
            label: const Text('Paste'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: busy ? null : () => _fetchVideoInfo(),
            icon: busy && _state == DownloadState.extracting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search_rounded, size: 18),
            label: const Text('Fetch Info'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE60023),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultArea(bool isDark) {
    if (_state == DownloadState.extracting) {
      return _buildLoadingCard('Fetching video info…');
    }
    if (_state == DownloadState.error) {
      return _buildErrorCard();
    }
    if (_ytInfo != null) {
      return _buildYouTubeCard(isDark);
    }
    if (_pinInfo != null) {
      return _buildPinterestCard(isDark);
    }
    return const SizedBox.shrink();
  }

  // ─── Pinterest Card ────────────────────────────────────────────────────────

  Widget _buildPinterestCard(bool isDark) {
    final info = _pinInfo!;
    return _MediaCard(
      isDark: isDark,
      thumbnail: info.thumbnailUrl,
      title: info.title,
      subtitle: info.quality ?? 'HD MP4',
      accentColor: const Color(0xFFE60023),
      badgeIcon: Icons.push_pin_rounded,
      downloadState: _state,
      progress: _progress,
      statusMessage: _statusMessage,
      successAlbum: '"Pinterest" album',
      onDownload: _startPinterestDownload,
      onReset: _reset,
    );
  }

  // ─── YouTube Card ─────────────────────────────────────────────────────────

  Widget _buildYouTubeCard(bool isDark) {
    final info = _ytInfo!;
    return _MediaCard(
      isDark: isDark,
      thumbnail: info.thumbnailUrl,
      title: info.title,
      subtitle: info.author,
      accentColor: const Color(0xFFFF0000),
      badgeIcon: Icons.play_circle_fill_rounded,
      downloadState: _state,
      progress: _progress,
      statusMessage: _statusMessage,
      successAlbum: _selectedStream?.isAudioOnly == true ? 'Downloads folder' : '"YouTube" album',
      onDownload: _startYouTubeDownload,
      onReset: _reset,
      qualityWidget: _buildQualityPicker(isDark, info),
    );
  }

  Widget _buildQualityPicker(bool isDark, YouTubeVideoInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text('Select Quality',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            )),
        const SizedBox(height: 8),
        ...info.streams.map((s) {
          final isSelected = _selectedStream == s;
          final isAudio = s.isAudioOnly;
          return GestureDetector(
            onTap: _state == DownloadState.downloading
                ? null
                : () => setState(() => _selectedStream = s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF0000).withValues(alpha: 0.12)
                    : isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF0000)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isAudio ? Icons.music_note_rounded : Icons.videocam_rounded,
                    color: isSelected ? const Color(0xFFFF0000) : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFFFF0000)
                            : isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFFFF0000), size: 18),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── Shared UI helpers ─────────────────────────────────────────────────────

  Widget _buildLoadingCard(String text) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Color(0xFFE60023)),
            const SizedBox(height: 16),
            Text(text, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_statusMessage,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.red, size: 20),
            onPressed: _reset,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Media Card ───────────────────────────────────────────────────────

class _MediaCard extends StatelessWidget {
  final bool isDark;
  final String? thumbnail;
  final String title;
  final String subtitle;
  final Color accentColor;
  final IconData badgeIcon;
  final DownloadState downloadState;
  final double progress;
  final String statusMessage;
  final String successAlbum;
  final VoidCallback onDownload;
  final VoidCallback onReset;
  final Widget? qualityWidget;

  const _MediaCard({
    required this.isDark,
    required this.thumbnail,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.badgeIcon,
    required this.downloadState,
    required this.progress,
    required this.statusMessage,
    required this.successAlbum,
    required this.onDownload,
    required this.onReset,
    this.qualityWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail + title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(url: thumbnail, accent: accentColor, icon: badgeIcon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(badgeIcon, size: 12, color: accentColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600])),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Quality picker (YouTube only)
          ?qualityWidget,

          const SizedBox(height: 16),

          // Progress bar
          if (downloadState == DownloadState.downloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 8,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                color: accentColor,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(statusMessage,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 10),
          ],

          // Success
          if (downloadState == DownloadState.success) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Saved to $successAlbum',
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try { await Gal.open(); } catch (_) {}
                    },
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Open Gallery'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('New Download'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ] else if (downloadState != DownloadState.downloading) ...[
            ElevatedButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text('Download',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Thumbnail Widget ─────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  final String? url;
  final Color accent;
  final IconData icon;
  const _Thumbnail({this.url, required this.accent, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url!,
          width: 80,
          height: 110,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: 80,
        height: 110,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: accent, size: 36),
      );
}

// ─── Source Chip ──────────────────────────────────────────────────────────────

class _SourceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  const _SourceChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color : Colors.grey.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? color : Colors.grey, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                color: active ? color : Colors.grey,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              )),
        ],
      ),
    );
  }
}
