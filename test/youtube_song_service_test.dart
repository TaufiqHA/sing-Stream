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

    test(
      'formatKaraokeQuery formats queries correctly to target karaoke tracks',
      () {
        expect(
          YoutubeSongService.formatKaraokeQuery(null),
          'karaoke hits indonesia',
        );
        expect(
          YoutubeSongService.formatKaraokeQuery(''),
          'karaoke hits indonesia',
        );
        expect(
          YoutubeSongService.formatKaraokeQuery('   '),
          'karaoke hits indonesia',
        );
        expect(
          YoutubeSongService.formatKaraokeQuery('Dewa 19'),
          'Dewa 19 karaoke',
        );
        expect(
          YoutubeSongService.formatKaraokeQuery('Pupus Karaoke'),
          'Pupus Karaoke',
        );
        expect(
          YoutubeSongService.formatKaraokeQuery('sheila on 7 karaoke version'),
          'sheila on 7 karaoke version',
        );
      },
    );

    test('formatNonKaraokeQuery keeps the query without adding karaoke', () {
      expect(
        YoutubeSongService.formatNonKaraokeQuery(null),
        'lagu indonesia terbaru',
      );
      expect(
        YoutubeSongService.formatNonKaraokeQuery(''),
        'lagu indonesia terbaru',
      );
      expect(
        YoutubeSongService.formatNonKaraokeQuery('   '),
        'lagu indonesia terbaru',
      );
      expect(YoutubeSongService.formatNonKaraokeQuery('Dewa 19'), 'Dewa 19');
      expect(
        YoutubeSongService.formatNonKaraokeQuery('Pupus Dewa 19'),
        'Pupus Dewa 19',
      );
    });

    test('separates karaoke and non-karaoke songs based on title', () async {
      final service = YoutubeSongService(
        isTestMode: true,
        initialSongs: [
          const SongModel(
            songid: 1,
            songtitle: 'Pupus - Dewa 19 (Karaoke)',
            songsinger: 'Dewa 19',
            songurl: 'https://www.youtube.com/watch?v=pupus',
            songcategory: 1,
          ),
          const SongModel(
            songid: 2,
            songtitle: 'Pupus - Dewa 19 (Official Audio)',
            songsinger: 'Dewa 19',
            songurl: 'https://www.youtube.com/watch?v=pupus-official',
            songcategory: 1,
          ),
        ],
      );

      final karaokeSongs = await service.getSongs(isKaraoke: true);
      expect(karaokeSongs.length, 1);
      expect(karaokeSongs.first.songtitle, contains('Karaoke'));

      final nonKaraokeSongs = await service.getSongs(isKaraoke: false);
      expect(nonKaraokeSongs.length, 1);
      expect(nonKaraokeSongs.first.songtitle, contains('Official Audio'));
    });
  });

  group('UserMainLayout with YoutubeSongService Integration Tests', () {
    testWidgets('searches song and adds to playlist queue', (
      WidgetTester tester,
    ) async {
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
      final searchFinder = find.widgetWithText(
        TextField,
        'Cari lagu karaoke...',
      );
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
      expect(
        find.text('"Pupus - Dewa 19 (Karaoke)" ditambahkan ke playlist'),
        findsOneWidget,
      );

      // Verifikasi lagu muncul di antrean playlist
      final playlistCard = find.byKey(const ValueKey('queue_201_0'));
      expect(playlistCard, findsOneWidget);
    });

    testWidgets('switching to Non Karaoke searches non-karaoke songs', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = YoutubeSongService(
        isTestMode: true,
        initialSongs: [
          const SongModel(
            songid: 301,
            songtitle: 'Pupus - Dewa 19 (Karaoke)',
            songsinger: 'Dewa 19',
            songurl: 'https://www.youtube.com/watch?v=pupus-karaoke',
            songcategory: 1,
          ),
          const SongModel(
            songid: 302,
            songtitle: 'Pupus - Dewa 19 (Official Audio)',
            songsinger: 'Dewa 19',
            songurl: 'https://www.youtube.com/watch?v=pupus-official',
            songcategory: 1,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UserMainLayout(
            songService: service,
            categoryService: DummyCategoryService(),
            isTestMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default Karaoke: hanya lagu karaoke yang tampil.
      expect(find.text('Pupus - Dewa 19 (Karaoke)'), findsOneWidget);
      expect(find.text('Pupus - Dewa 19 (Official Audio)'), findsNothing);

      // Buka dropdown filter lalu pilih Non Karaoke.
      await tester.tap(find.text('Karaoke'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Non Karaoke'));
      await tester.pumpAndSettle();

      // Hasil pencarian berganti ke lagu non-karaoke.
      expect(find.text('Pupus - Dewa 19 (Karaoke)'), findsNothing);
      expect(find.text('Pupus - Dewa 19 (Official Audio)'), findsOneWidget);
    });
  });
}
