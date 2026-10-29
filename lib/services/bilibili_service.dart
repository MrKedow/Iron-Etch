import 'dart:convert';

import 'package:http/http.dart' as http;

class BilibiliVideo {
  final String bvid;
  final String title;
  final String author;
  final String duration;
  final int play;

  const BilibiliVideo({
    required this.bvid,
    required this.title,
    required this.author,
    required this.duration,
    required this.play,
  });
}

class BilibiliService {
  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Mobile Safari/537.36',
    'Referer': 'https://search.bilibili.com/',
    'Accept': 'application/json, text/plain, */*',
  };

  Future<List<BilibiliVideo>> fetchCreatorVideos({
    required String query,
    required int mid,
    int limit = 6,
  }) async {
    final uri = Uri.https(
      'api.bilibili.com',
      '/x/web-interface/search/type',
      {
        'search_type': 'video',
        'keyword': query,
        'page': '1',
        'order': 'totalrank',
      },
    );

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          await _backoff(attempt);
          continue;
        }
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map<String, dynamic>) {
          await _backoff(attempt);
          continue;
        }
        final code = (decoded['code'] as num?)?.toInt() ?? -1;
        if (code != 0) {
          await _backoff(attempt);
          continue;
        }
        final payload = decoded['data'];
        final rawResult =
            payload is Map ? payload['result'] as List<dynamic>? : null;
        if (rawResult == null) return const [];

        final videos = <BilibiliVideo>[];
        final seen = <String>{};
        for (final raw in rawResult) {
          if (raw is! Map) continue;
          final itemMid = int.tryParse('${raw['mid']}');
          if (itemMid != mid) continue;
          final bvid = raw['bvid']?.toString() ?? '';
          if (bvid.isEmpty || !seen.add(bvid)) continue;
          videos.add(
            BilibiliVideo(
              bvid: bvid,
              title: _cleanTitle(raw['title']?.toString() ?? ''),
              author: raw['author']?.toString() ?? '',
              duration: raw['duration']?.toString() ?? '',
              play: (raw['play'] as num?)?.toInt() ?? 0,
            ),
          );
          if (videos.length >= limit) break;
        }
        return videos;
      } catch (_) {
        await _backoff(attempt);
      }
    }
    return const [];
  }

  Future<void> _backoff(int attempt) {
    return Future<void>.delayed(
      Duration(milliseconds: 1200 * (attempt + 1)),
    );
  }

  String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}
