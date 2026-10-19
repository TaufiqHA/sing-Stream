import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_app/models/application_model.dart';
import 'package:karaoke_app/widgets/ad_slot_view.dart';

Widget _buildSlot(AdSlotConfig ad, {Future<bool> Function(Uri)? urlOpener}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 320,
        height: 120,
        child: AdSlotView(
          ad: ad,
          padding: EdgeInsets.zero,
          urlOpener: urlOpener,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('mengetuk banner gambar membuka URL klik', (tester) async {
    Uri? openedUri;

    await tester.pumpWidget(
      _buildSlot(
        const AdSlotConfig(
          image: 'https://cdn.example.com/ads/banner.jpg',
          clickUrl: 'https://example.com/promo',
        ),
        urlOpener: (uri) async {
          openedUri = uri;
          return true;
        },
      ),
    );
    await tester.pump();

    final gesture = tester.widget<GestureDetector>(
      find.byType(GestureDetector),
    );
    expect(gesture.onTap, isNotNull);

    gesture.onTap!();
    await tester.pump();

    expect(openedUri, Uri.parse('https://example.com/promo'));
  });

  testWidgets('banner tanpa URL klik tidak memiliki handler ketuk', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSlot(
        const AdSlotConfig(image: 'https://cdn.example.com/ads/banner.jpg'),
      ),
    );
    await tester.pump();

    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('URL klik tidak valid diabaikan', (tester) async {
    await tester.pumpWidget(
      _buildSlot(
        const AdSlotConfig(
          image: 'https://cdn.example.com/ads/banner.jpg',
          clickUrl: 'javascript:alert(1)',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(GestureDetector), findsNothing);
  });
}
