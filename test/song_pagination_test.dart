import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_app/core/services/dummy_category_service.dart';
import 'package:karaoke_app/core/services/dummy_song_service.dart';
import 'package:karaoke_app/core/services/youtube_song_service.dart';
import 'package:karaoke_app/models/song_model.dart';
import 'package:karaoke_app/screens/user/user_main_layout.dart';
import 'package:karaoke_app/screens/user/widgets/song_catalog_playlist_section.dart';
import 'package:karaoke_app/screens/user/widgets/song_search_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<SongModel> buildSongs(int count) {
  return List.generate(
    count,
    (index) => SongModel(
      songid: index + 1,
      songtitle: 'Lagu ${index + 1}',
      songsinger: 'Penyanyi ${index + 1}',
      songurl: 'https://www.youtube.com/watch?v=video$index',
      songcategory: 1,
      karaokeFlag: true,
      songduration: '03:30',
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SongService pagination', () {
    test('DummySongService memotong hasil per 20 lagu', () async {
      final service = DummySongService(buildSongs(45));

      final page1 = await service.getSongsPage(page: 1, pageSize: 20);
      expect(page1.songs.length, 20);
      expect(page1.hasMore, isTrue);

      final page2 = await service.getSongsPage(page: 2, pageSize: 20);
      expect(page2.songs.length, 20);
      expect(page2.hasMore, isTrue);
      expect(
        page1.songs
            .map((s) => s.songid)
            .toSet()
            .intersection(page2.songs.map((s) => s.songid).toSet()),
        isEmpty,
      );

      final page3 = await service.getSongsPage(page: 3, pageSize: 20);
      expect(page3.songs.length, 5);
      expect(page3.hasMore, isFalse);
    });

    test('YoutubeSongService mode test mendukung pagination lokal', () async {
      final service = YoutubeSongService(
        isTestMode: true,
        initialSongs: buildSongs(45),
      );

      final page1 = await service.getSongsPage(page: 1, pageSize: 20);
      expect(page1.songs.length, 20);
      expect(page1.hasMore, isTrue);

      final page3 = await service.getSongsPage(page: 3, pageSize: 20);
      expect(page3.songs.length, 5);
      expect(page3.hasMore, isFalse);
    });

    test('halaman melewati total data mengembalikan hasil kosong', () async {
      final service = DummySongService(buildSongs(10));
      final page = await service.getSongsPage(page: 5, pageSize: 20);
      expect(page.songs, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });

  group('SongSearchPanel infinite scroll', () {
    testWidgets('memuat halaman berikutnya saat digulir ke bawah', (
      tester,
    ) async {
      var loadMoreCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 600,
              child: SongSearchPanel(
                songs: buildSongs(20),
                categories: const [],
                queue: const [],
                currentPlayingSong: null,
                onPlaySong: (_) {},
                onAddToQueue: (_) {},
                onLoadMore: () async {
                  loadMoreCalls++;
                },
              ),
            ),
          ),
        ),
      );

      expect(loadMoreCalls, 0);

      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();

      expect(loadMoreCalls, 1);
    });

    testWidgets('menampilkan indikator saat memuat halaman berikutnya', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 600,
              child: SongSearchPanel(
                songs: buildSongs(3),
                categories: const [],
                queue: const [],
                currentPlayingSong: null,
                onPlaySong: (_) {},
                onAddToQueue: (_) {},
                onLoadMore: () async {},
                isLoadingMore: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Memuat lagu lainnya...'), findsOneWidget);
    });
  });

  group('UserMainLayout pagination', () {
    testWidgets('menambahkan 20 lagu berikutnya saat digulir ke bawah', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: UserMainLayout(
            songService: DummySongService(buildSongs(45)),
            categoryService: DummyCategoryService(),
            isTestMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      SongCatalogPlaylistSection section() =>
          tester.widget<SongCatalogPlaylistSection>(
            find.byType(SongCatalogPlaylistSection),
          );

      expect(section().songs.length, 20);

      final searchList = find.descendant(
        of: find.byType(SongCatalogPlaylistSection),
        matching: find.byType(ListView),
      );
      expect(searchList, findsOneWidget);

      await tester.drag(searchList, const Offset(0, -2500));
      await tester.pumpAndSettle();

      expect(section().songs.length, 40);
    });
  });
}
