import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_app/screens/user/widgets/cast_device_modal.dart';
import 'package:karaoke_app/services/cast/cast_device_model.dart';
import 'package:karaoke_app/services/cast/smart_tv_cast_service.dart';

void main() {
  group('CastDeviceModal Single Progress and Continuous Discovery Tests', () {
    testWidgets('Displays only 1 progress indicator (LinearProgressIndicator) and continuous searching state', (WidgetTester tester) async {
      final castService = SmartTvCastService(isTestMode: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CastDeviceModal.show(
                    context,
                    castService: castService,
                  );
                },
                child: const Text('Open Cast Modal'),
              ),
            ),
          ),
        ),
      );

      // Buka modal
      await tester.tap(find.text('Open Cast Modal'));
      await tester.pumpAndSettle();

      // Verifikasi judul modal
      expect(find.text('Cast ke TV'), findsOneWidget);

      // Verifikasi HANYA ADA 1 progress indicator di modal (LinearProgressIndicator)
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Header bersih tanpa badge 'Mencari...'
      expect(find.text('Mencari...'), findsNothing);

      // Body menampilkan status pencarian TV aktif secara minimalis
      expect(find.text('Mencari Smart TV di jaringan Wi-Fi...'), findsOneWidget);

      // Tombol reload telah dihilangkan sepenuhnya
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      castService.dispose();
    });

    testWidgets('Displays discovered devices while keeping single progress indicator for continuous discovery', (WidgetTester tester) async {
      final castService = SmartTvCastService(
        isTestMode: true,
        initialDevices: const [
          CastDevice(
            id: 'tv_living_room',
            name: 'Living Room Android TV',
            ipAddress: '192.168.1.100',
            type: CastDeviceType.androidTv,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CastDeviceModal.show(
                    context,
                    castService: castService,
                  );
                },
                child: const Text('Open Cast Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Cast Modal'));
      await tester.pumpAndSettle();

      // Perangkat terdeteksi ditampilkan pada daftar
      expect(find.text('Living Room Android TV'), findsOneWidget);

      // Tetap hanya 1 progress indicator (LinearProgressIndicator) di bagian atas
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Tidak ada progress bar / teks sekunder yang berlebih
      expect(find.text('Mencari TV lainnya...'), findsNothing);

      castService.dispose();
    });
  });
}
