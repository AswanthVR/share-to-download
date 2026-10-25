import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

class YouTubeStreamOption {
  final String label;       // e.g. "1080p MP4", "720p MP4", "Audio only MP3"
  final bool isAudioOnly;
  final int? height;        // null for audio-only
  final String container;   // mp4 / webm / mp3

  // internal: one of these will be set
  final MuxedStreamInfo? muxed;
  final VideoOnlyStreamInfo? videoOnly;
  final AudioOnlyStreamInfo? audio;

  YouTubeStreamOption._({
    required this.label,
    required this.isAudioOnly,
    required this.container,
    this.height,
    this.muxed,
    this.videoOnly,
    this.audio,
  });

  factory YouTubeStreamOption.fromMuxed(MuxedStreamInfo s) =>
      YouTubeStreamOption._(
        label: '${s.videoResolution.height}p ${s.container.name.toUpperCase()} (video+audio)',
        isAudioOnly: false,
        container: s.container.name,
        height: s.videoResolution.height,
        muxed: s,
      );

  factory YouTubeStreamOption.fromVideoOnly(VideoOnlyStreamInfo s) =>
      YouTubeStreamOption._(
        label: '${s.videoResolution.height}p ${s.container.name.toUpperCase()} (video only)',
        isAudioOnly: false,
        container: s.container.name,
        height: s.videoResolution.height,
        videoOnly: s,
      );

  factory YouTubeStreamOption.fromAudio(AudioOnlyStreamInfo s) =>
      YouTubeStreamOption._(
        label: 'Audio only · ${s.bitrate.kiloBitsPerSecond.round()} kbps',
        isAudioOnly: true,
        container: 'm4a',
        audio: s,
      );

  int get sortKey {
    if (isAudioOnly) return -1;
    return height ?? 0;
  }
}

class YouTubeVideoInfo {
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration duration;
  final List<YouTubeStreamOption> streams;

  YouTubeVideoInfo({
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
    required this.streams,
  });
}

class YouTubeService {
  /// Returns true if the URL looks like a YouTube link.
  static bool isYouTubeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.host.contains('youtube.com') ||
        uri.host.contains('youtu.be') ||
        uri.host.contains('yt.be');
  }

  /// Fetches video metadata and available stream qualities.
  static Future<YouTubeVideoInfo> getVideoInfo(String url) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);

      final options = <YouTubeStreamOption>[];

      // Muxed streams (video + audio, lower quality, always safe to save)
      for (final s in manifest.muxed) {
        options.add(YouTubeStreamOption.fromMuxed(s));
      }

      // Audio-only streams
      for (final s in manifest.audioOnly) {
        options.add(YouTubeStreamOption.fromAudio(s));
        break; // Take only the best (first) audio stream
      }

      // Sort: highest video quality first, then audio
      options.sort((a, b) => b.sortKey.compareTo(a.sortKey));

      final thumb = video.thumbnails.highResUrl;

      return YouTubeVideoInfo(
        title: video.title,
        author: video.author,
        thumbnailUrl: thumb,
        duration: video.duration ?? Duration.zero,
        streams: options,
      );
    } finally {
      yt.close();
    }
  }

  /// Downloads the selected stream and saves it to the gallery / files.
  static Future<void> downloadStream({
    required YouTubeVideoInfo info,
    required YouTubeStreamOption option,
    required void Function(double progress) onProgress,
  }) async {
    final yt = YoutubeExplode();
    try {
      Stream<List<int>> stream;
      int? totalBytes;
      String ext;

      if (option.muxed != null) {
        stream = yt.videos.streamsClient.get(option.muxed!);
        totalBytes = option.muxed!.size.totalBytes;
        ext = option.muxed!.container.name; // mp4 / webm
      } else if (option.audio != null) {
        stream = yt.videos.streamsClient.get(option.audio!);
        totalBytes = option.audio!.size.totalBytes;
        ext = 'm4a';
      } else {
        throw Exception('Unsupported stream type. Use muxed or audio streams.');
      }

      final tempDir = await getTemporaryDirectory();
      final safeTitle =
          info.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final fileName =
          '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final tempFile = File('${tempDir.path}/$fileName');

      final sink = tempFile.openWrite();
      int received = 0;

      await for (final chunk in stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          onProgress(received / totalBytes);
        }
      }
      await sink.flush();
      await sink.close();

      // Gallery permission
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) throw Exception('Gallery permission was denied.');
      }

      if (option.isAudioOnly) {
        // Save audio to files (Gal doesn't handle audio; save to Downloads)
        final dl = await _getDownloadsDir();
        final dest = File('$dl/$fileName');
        await tempFile.copy(dest.path);
      } else {
        await Gal.putVideo(tempFile.path, album: 'YouTube');
      }

      // Clean up
      try {
        await tempFile.delete();
      } catch (_) {}
    } finally {
      yt.close();
    }
  }

  static Future<String> _getDownloadsDir() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    }
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }
}
