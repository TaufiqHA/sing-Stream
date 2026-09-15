class YoutubeHelper {
  /// Ekstraksi YouTube Video ID dari berbagai variasi format link YouTube atau ID langsung.
  /// Mengembalikan `null` jika URL tidak valid atau bukan link YouTube.
  static String? extractVideoId(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    // 1. Cek apakah langsung berupa 11-karakter video ID
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) {
      return trimmed;
    }

    // 2. Cek pola-pola URL YouTube
    final patterns = [
      RegExp(r'youtu\.be\/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/embed\/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})'),
      RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'(?:v=|\/)([a-zA-Z0-9_-]{11})(?:\?|&|$)'),
    ];

    for (final regex in patterns) {
      final match = regex.firstMatch(trimmed);
      if (match != null && match.groupCount >= 1) {
        final id = match.group(1);
        if (id != null && id.length == 11) {
          return id;
        }
      }
    }

    // 3. Fallback Uri query parameter & host parsing
    try {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        if (uri.queryParameters.containsKey('v')) {
          final vParam = uri.queryParameters['v'];
          if (vParam != null && vParam.length == 11) {
            return vParam;
          }
        }
        if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
          final seg = uri.pathSegments.first;
          if (seg.length == 11) {
            return seg;
          }
        }
        if (uri.pathSegments.contains('embed') || uri.pathSegments.contains('shorts')) {
          final lastSeg = uri.pathSegments.last;
          if (lastSeg.length == 11) {
            return lastSeg;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Cek apakah URL merupakan URL YouTube yang valid
  static bool isYoutubeUrl(String? url) {
    return extractVideoId(url) != null;
  }

  /// Mendapatkan URL thumbnail resmi YouTube dengan kualitas tinggi (hqdefault)
  static String getThumbnailUrl(String videoId) {
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  /// Mendapatkan URL thumbnail kualitas standar (mqdefault)
  static String getMediumThumbnailUrl(String videoId) {
    return 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
  }
}
