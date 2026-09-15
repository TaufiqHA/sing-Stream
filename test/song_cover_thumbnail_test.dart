import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_app/models/category_model.dart';
import 'package:karaoke_app/models/song_model.dart';
import 'package:karaoke_app/screens/user/widgets/song_catalog_playlist_section.dart';
import 'package:karaoke_app/screens/user/widgets/song_cover_thumbnail.dart';
import 'package:karaoke_app/screens/user/widgets/song_search_panel.dart';

void main() {
  group('SongCoverThumbnail Widget Tests', () {
    testWidgets('renders Image.network when valid YouTube URL is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SongCoverThumbnail(
              songUrl: 'https://www.youtube.com/watch?v=0kFh_0l33rM',
              width: 62,
              height: 38,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<NetworkImage>());
      final networkImage = imageWidget.image as NetworkImage;
      expect(networkImage.url, contains('0kFh_0l33rM'));
      expect(networkImage.url, contains('mqdefault.jpg'));
    });

    testWidgets('renders fallback placeholder when songUrl is null or invalid', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SongCoverThumbnail(
              songUrl: 'https://not-youtube.com/audio.mp3',
              width: 62,
              height: 38,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    });

    testWidgets('renders custom fallback when provided and songUrl is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SongCoverThumbnail(
              songUrl: '',
              width: 62,
              height: 38,
              fallback: Text('Custom Fallback'),
            ),
          ),
        ),
      );

      expect(find.text('Custom Fallback'), findsOneWidget);
    });

    testWidgets('renders AspectRatio widget when aspectRatio is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 160,
              child: SongCoverThumbnail(
                songUrl: 'https://www.youtube.com/watch?v=0kFh_0l33rM',
                aspectRatio: 16 / 9,
              ),
            ),
          ),
        ),
      );

      final aspectFinder = find.byType(AspectRatio);
      expect(aspectFinder, findsOneWidget);
      final aspectWidget = tester.widget<AspectRatio>(aspectFinder);
      expect(aspectWidget.aspectRatio, 16 / 9);

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
    });
  });

  group('SongCatalogPlaylistSection & SongSearchPanel with Cover Tests', () {
    final testSongs = [
      const SongModel(
        songid: 1,
        songtitle: 'Sial',
        songsinger: 'Mahalini',
        songurl: 'https://www.youtube.com/watch?v=0kFh_0l33rM',
        songcategory: 1,
        songnada: 'Wanita',
        songduration: '04:03',
      ),
      const SongModel(
        songid: 2,
        songtitle: 'Separuh Nafas',
        songsinger: 'Dewa 19',
        songurl: 'https://www.youtube.com/watch?v=vVj44t-j3tA',
        songcategory: 1,
        songnada: 'Pria',
        songduration: '03:45',
      ),
    ];

    final testCategories = [
      CategoryModel(id: 'cat_1', name: 'Pop', createdAt: DateTime.now()),
    ];

    testWidgets('SongCatalogPlaylistSection renders SongCoverThumbnail for each search result', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: SongCatalogPlaylistSection(
                songs: testSongs,
                categories: testCategories,
                queue: const [],
                currentPlayingSong: null,
                onPlaySong: (_) {},
                onAddToQueue: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SongCoverThumbnail), findsNWidgets(2));
      expect(find.text('Sial'), findsOneWidget);
      expect(find.text('Separuh Nafas'), findsOneWidget);
    });

    testWidgets('SongSearchPanel renders SongCoverThumbnail in catalog tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 600,
              child: SongSearchPanel(
                songs: testSongs,
                categories: testCategories,
                queue: const [],
                currentPlayingSong: null,
                onPlaySong: (_) {},
                onAddToQueue: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SongCoverThumbnail), findsNWidgets(2));
    });
  });
}
