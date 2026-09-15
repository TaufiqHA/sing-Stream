import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_app/core/utils/youtube_helper.dart';

void main() {
  group('YoutubeHelper.extractVideoId', () {
    test('Extracts video ID from standard watch URL', () {
      expect(
        YoutubeHelper.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('Extracts video ID from watch URL with extra query params', () {
      expect(
        YoutubeHelper.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=45s&feature=share'),
        'dQw4w9WgXcQ',
      );
    });

    test('Extracts video ID from youtu.be short URL', () {
      expect(
        YoutubeHelper.extractVideoId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('Extracts video ID from youtu.be with timestamp', () {
      expect(
        YoutubeHelper.extractVideoId('https://youtu.be/dQw4w9WgXcQ?t=30'),
        'dQw4w9WgXcQ',
      );
    });

    test('Extracts video ID from embed URL', () {
      expect(
        YoutubeHelper.extractVideoId('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('Extracts video ID from shorts URL', () {
      expect(
        YoutubeHelper.extractVideoId('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('Extracts video ID from mobile m.youtube.com URL', () {
      expect(
        YoutubeHelper.extractVideoId('https://m.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('Accepts raw 11-char video ID', () {
      expect(
        YoutubeHelper.extractVideoId('dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('Returns null for non-youtube URLs or empty string', () {
      expect(YoutubeHelper.extractVideoId('https://example.com/audio/song.mp3'), isNull);
      expect(YoutubeHelper.extractVideoId(''), isNull);
      expect(YoutubeHelper.extractVideoId(null), isNull);
    });
  });

  group('YoutubeHelper.getThumbnailUrl', () {
    test('Generates correct high-quality thumbnail URL', () {
      expect(
        YoutubeHelper.getThumbnailUrl('dQw4w9WgXcQ'),
        'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );
    });
  });
}
