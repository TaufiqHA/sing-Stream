import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_app/core/services/dummy_category_service.dart';
import 'package:karaoke_app/core/services/dummy_song_service.dart';
import 'package:karaoke_app/screens/admin/song/admin_song_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Tap right side of category dropdown opens dropdown successfully and selects item', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSongScreen(
            songService: DummySongService(),
            categoryService: DummyCategoryService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Tambah Lagu
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Lagu'));
    await tester.pumpAndSettle();

    final dropdownFinder = find.byType(DropdownButtonFormField<int>);
    expect(dropdownFinder, findsOneWidget);

    // Tap at the right side (where dropdown arrow is)
    final topRight = tester.getTopRight(dropdownFinder);
    await tester.tapAt(topRight.translate(-20, 25));
    await tester.pumpAndSettle();

    // Verifikasi menu dropdown terbuka
    final itemsOpen = find.text('Dangdut & Koplo');
    expect(itemsOpen, findsWidgets);

    // Pilih kategori 'Dangdut & Koplo'
    await tester.tap(itemsOpen.last);
    await tester.pumpAndSettle();

    // Verifikasi kategori terpilih
    expect(find.text('Dangdut & Koplo'), findsWidgets);
  });
}
