import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaoke_app/core/services/dummy_category_service.dart';
import 'package:karaoke_app/core/services/youtube_song_service.dart';
import 'package:karaoke_app/models/song_model.dart';
import 'package:karaoke_app/screens/user/user_main_layout.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('YoutubeSongService tests', () {
    test('returns default popular songs when query is empty', () async {
      final service = YoutubeSongService(isTestMode: true);
      final songs = await service.getSongs();
      expect(songs.isNotEmpty, isTrue);
      expect(songs.first.songtitle, contains('Ari Lasso'));
    });

    test('filters songs properly by search query', () async {
      final service = YoutubeSongService(
        isTestMode: true,
        initialSongs: [
          const SongModel(
            songid: 1,
            songtitle: 'Kemesraan',
            songsinger: 'Iwan Fals',
            songurl: 'https://www.youtube.com/watch?v=3JZ_D3ELwOQ',
            songcategory: 1,
          ),
          const SongModel(
            songid: 2,
            songtitle: 'Hampa',
            songsinger: 'Ari Lasso',
            songurl: 'https://www.youtube.com/watch?v=kXYiU_JCYtU',
            songcategory: 1,
          ),
        ],
      );

      final results = await service.getSongs(search: 'iwan');
      expect(results.length, 1);
      expect(results.first.songtitle, 'Kemesraan');
    });

    test('formatKaraokeQuery formats queries correctly to target karaoke tracks', () {
      expect(YoutubeSongService.formatKaraokeQuery(null), 'karaoke hits indonesia');
      expect(YoutubeSongService.formatKaraokeQuery(''), 'karaoke hits indonesia');
      expect(YoutubeSongService.formatKaraokeQuery('   '), 'karaoke hits indonesia');
      expect(YoutubeSongService.formatKaraokeQuery('Dewa 19'), 'Dewa 19 karaoke');
      expect(YoutubeSongService.formatKaraokeQuery('Pupus Karaoke'), 'Pupus Karaoke');
      expect(YoutubeSongService.formatKaraokeQuery('sheila on 7 karaoke version'), 'sheila on 7 karaoke version');
    });
  });

  group('UserMainLayout with YoutubeSongService Integration Tests', () {
    testWidgets('searches song and adds to playlist queue', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final customSongs = [
        const SongModel(
          songid: 201,
          songtitle: 'Pupus - Dewa 19 (Karaoke)',
          songsinger: 'Dewa 19',
          songurl: 'https://www.youtube.com/watch?v=pupus123',
          songcategory: 1,
        ),
        const SongModel(
          songid: 202,
          songtitle: 'Separuh Nafas - Dewa 19 (Karaoke)',
          songsinger: 'Dewa 19',
          songurl: 'https://www.youtube.com/watch?v=separuh123',
          songcategory: 1,
        ),
      ];

      final youtubeService = YoutubeSongService(
        isTestMode: true,
        initialSongs: customSongs,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UserMainLayout(
            songService: youtubeService,
            categoryService: DummyCategoryService(),
            isTestMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi lagu awal tampil
      expect(find.text('Pupus - Dewa 19 (Karaoke)'), findsOneWidget);
      expect(find.text('Separuh Nafas - Dewa 19 (Karaoke)'), findsOneWidget);

      // Cari lagu via TextField
      final searchFinder = find.widgetWithText(TextField, 'Cari lagu karaoke...');
      await tester.enterText(searchFinder, 'Pupus');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Verifikasi hasil filter
      expect(find.text('Pupus - Dewa 19 (Karaoke)'), findsOneWidget);
      expect(find.text('Separuh Nafas - Dewa 19 (Karaoke)'), findsNothing);

      // Tambahkan lagu ke antrean / playlist via tombol tambah playlist
      final addButtons = find.byIcon(Icons.playlist_add_rounded);
      expect(addButtons, findsWidgets);
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      // Verifikasi notifikasi snackbar
      expect(find.text('"Pupus - Dewa 19 (Karaoke)" ditambahkan ke playlist'), findsOneWidget);

      // Verifikasi lagu muncul di antrean playlist
      final playlistCard = find.byKey(const ValueKey('queue_201_0'));
      expect(playlistCard, findsOneWidget);
    });
  });
}
