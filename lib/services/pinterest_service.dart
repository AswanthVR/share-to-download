import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

class PinterestVideoInfo {
  final String title;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? quality;

  PinterestVideoInfo({
    required this.title,
    required this.videoUrl,
    this.thumbnailUrl,
    this.quality,
  });
}

class PinterestService {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  /// Extracts the first HTTP/HTTPS URL from user input or shared text.
  static String? extractUrl(String text) {
    final match = RegExp(r'https?://[^\s]+').firstMatch(text);
    return match?.group(0);
  }

  /// Extracts Pinterest video information client-side.
  static Future<PinterestVideoInfo> extractVideo(String inputUrl) async {
    final client = http.Client();
    try {
      final cleanUrl = extractUrl(inputUrl);
      if (cleanUrl == null) {
        throw Exception('No valid Pinterest URL found in input.');
      }

      // Step 1: Fetch the webpage (http follows 301/302 redirects automatically)
      final response = await client.get(Uri.parse(cleanUrl), headers: _headers);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load Pinterest page (HTTP ${response.statusCode}).');
      }

      final html = response.body;
      final finalUrl = response.request?.url.toString() ?? cleanUrl;

      // Step 2: Try Open Graph og:video tags
      final ogMatch = RegExp(
        r'<meta\s+property=["' "'" r']og:video(?::secure_url)?["' "'" r']\s+content=["' "'" r']([^"' "'" r']+)["' "'" r']',
        caseSensitive: false,
      ).firstMatch(html);

      String? title;
      final titleMatch = RegExp(
        r'<meta\s+property=["' "'" r']og:title["' "'" r']\s+content=["' "'" r']([^"' "'" r']+)["' "'" r']',
        caseSensitive: false,
      ).firstMatch(html);
      if (titleMatch != null) {
        title = titleMatch.group(1);
      }

      String? thumbUrl;
      final imageMatch = RegExp(
        r'<meta\s+property=["' "'" r']og:image["' "'" r']\s+content=["' "'" r']([^"' "'" r']+)["' "'" r']',
        caseSensitive: false,
      ).firstMatch(html);
      if (imageMatch != null) {
        thumbUrl = imageMatch.group(1);
      }

      if (ogMatch != null) {
        final ogVideo = ogMatch.group(1)!;
        if (ogVideo.endsWith('.mp4')) {
          return PinterestVideoInfo(
            title: title ?? 'Pinterest Video',
            videoUrl: ogVideo,
            thumbnailUrl: thumbUrl,
            quality: 'HD',
          );
        }
      }

      // Step 3: Extract from embedded JSON scripts (__PWS_DATA__ or ld+json)
      final jsonVideo = _extractFromJson(html);
      if (jsonVideo != null) {
        return PinterestVideoInfo(
          title: title ?? jsonVideo['title'] ?? 'Pinterest Video',
          videoUrl: jsonVideo['url']!,
          thumbnailUrl: thumbUrl ?? jsonVideo['thumbnail'],
          quality: jsonVideo['quality'] ?? 'HD',
        );
      }

      // Step 4: Direct Regex for video URLs on pinimg CDN
      final mp4Regex = RegExp(
        r'https?://[^\s"<>]+?\.pinimg\.com/videos/[^\s"<>]+?\.mp4',
        caseSensitive: false,
      );
      final allMp4s =
          mp4Regex.allMatches(html).map((m) => m.group(0)!).toSet().toList();

      if (allMp4s.isNotEmpty) {
        // Prefer 720p or 1080p if available
        allMp4s.sort((a, b) {
          int score(String url) {
            if (url.contains('1080p')) return 4;
            if (url.contains('720p')) return 3;
            if (url.contains('480p')) return 2;
            if (url.contains('exp')) return 1;
            return 0;
          }

          return score(b).compareTo(score(a));
        });

        return PinterestVideoInfo(
          title: title ?? 'Pinterest Video',
          videoUrl: allMp4s.first,
          thumbnailUrl: thumbUrl,
          quality: allMp4s.first.contains('720p') ? '720p HD' : 'SD',
        );
      }

      // Step 5: Fallback to PinResource API if pinId can be parsed
      final pinIdMatch = RegExp(r'/pin/(\d+)').firstMatch(finalUrl);
      if (pinIdMatch != null) {
        final pinId = pinIdMatch.group(1)!;
        final apiInfo =
            await _fetchFromPinResource(client, pinId, title, thumbUrl);
        if (apiInfo != null) {
          return apiInfo;
        }
      }

      // Step 6: Check for .m3u8 HLS and convert to mp4
      final m3u8Match = RegExp(
        r'https?://[^\s"<>]+?\.pinimg\.com/videos/hls/[^\s"<>]+?\.m3u8',
        caseSensitive: false,
      ).firstMatch(html);
      if (m3u8Match != null) {
        final m3u8Url = m3u8Match.group(0)!;
        // Pinterest CDN standard pattern converts /hls/ to /mc/720p/ and .m3u8 to .mp4
        final convertedMp4 = m3u8Url
            .replaceAll('/videos/hls/', '/videos/mc/720p/')
            .replaceAll('.m3u8', '.mp4');
        return PinterestVideoInfo(
          title: title ?? 'Pinterest Video',
          videoUrl: convertedMp4,
          thumbnailUrl: thumbUrl,
          quality: '720p',
        );
      }

      throw Exception(
          'Could not find a video on this Pin. It might be an image, story, or private.');
    } finally {
      client.close();
    }
  }

  static Map<String, String>? _extractFromJson(String html) {
    try {
      // Find JSON blocks in script tags
      final scriptMatches = RegExp(
        r'<script[^>]*type=["' "'" r']application/ld\+json["' "'" r'][^>]*>(.*?)</script>',
        dotAll: true,
      ).allMatches(html);

      for (final match in scriptMatches) {
        final content = match.group(1);
        if (content == null) continue;
        final data = jsonDecode(content);
        if (data is Map && data.containsKey('contentUrl')) {
          final url = data['contentUrl'] as String?;
          if (url != null && url.isNotEmpty) {
            return {
              'url': url,
              'title': data['name']?.toString() ?? 'Pinterest Video',
              'thumbnail': data['thumbnailUrl']?.toString() ?? '',
              'quality': 'HD',
            };
          }
        }
      }

      // Check __PWS_DATA__
      final pwsMatch = RegExp(
        r'<script[^>]*id=["' "'" r']__PWS_DATA__["' "'" r'][^>]*>(.*?)</script>',
        dotAll: true,
      ).firstMatch(html);

      if (pwsMatch != null) {
        final content = pwsMatch.group(1);
        if (content != null) {
          final mp4Match = RegExp(
            r'https?://[^\s"<>]+?\.pinimg\.com/videos/[^\s"<>]+?\.mp4',
          ).firstMatch(content);
          if (mp4Match != null) {
            return {'url': mp4Match.group(0)!, 'quality': 'HD'};
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<PinterestVideoInfo?> _fetchFromPinResource(
    http.Client client,
    String pinId,
    String? title,
    String? thumbUrl,
  ) async {
    try {
      final apiUrl =
          'https://www.pinterest.com/resource/PinResource/get/?data=%7B%22options%22%3A%7B%22id%22%3A%22$pinId%22%2C%22field_set_key%22%3A%22detailed%22%7D%7D';
      final response = await client.get(
        Uri.parse(apiUrl),
        headers: {
          ..._headers,
          'X-Pinterest-PWS-Handler': 'www/[username].js',
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final pinData = json['resource_response']?['data'];
        final videoList = pinData?['videos']?['video_list'];
        if (videoList is Map) {
          // Look for 720p or highest available format
          for (final key in ['V_720P', 'V_EXP720P', 'V_480P', 'V_EXP480P']) {
            final format = videoList[key];
            if (format is Map && format['url'] != null) {
              return PinterestVideoInfo(
                title: title ?? pinData['title'] ?? 'Pinterest Video',
                videoUrl: format['url'],
                thumbnailUrl: thumbUrl,
                quality: key.contains('720') ? '720p HD' : '480p',
              );
            }
          }
          // Any url in video_list
          for (final entry in videoList.values) {
            if (entry is Map && entry['url'] != null) {
              return PinterestVideoInfo(
                title: title ?? 'Pinterest Video',
                videoUrl: entry['url'],
                thumbnailUrl: thumbUrl,
                quality: 'HD',
              );
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Downloads video from [videoUrl] with progress reporting and saves it to Android Gallery.
  static Future<void> downloadAndSaveToGallery({
    required String videoUrl,
    required void Function(double progress) onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(videoUrl));
      _headers.forEach((k, v) => request.headers[k] = v);

      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to download video file (HTTP ${response.statusCode}).');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/pin_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      final sink = tempFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes);
        }
      }
      await sink.flush();
      await sink.close();

      // Check permission & save to gallery using Gal
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          throw Exception('Storage/Gallery permission was denied.');
        }
      }

      await Gal.putVideo(tempFile.path, album: 'Pinterest');

      // Clean up temp file
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    } finally {
      client.close();
    }
  }
}
