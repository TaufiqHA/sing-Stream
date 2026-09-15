import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_app/services/cast/cast_device_model.dart';
import 'package:karaoke_app/services/cast/smart_tv_cast_service.dart';

void main() {
  group('SmartTvCastService tests', () {
    late SmartTvCastService service;

    setUp(() {
      service = SmartTvCastService(isTestMode: true);
    });

    tearDown(() {
      service.dispose();
    });

    test('Initial state has no connected device and not scanning', () {
      expect(service.connectedDevice, isNull);
      expect(service.isScanning, isFalse);
      expect(service.discoveredDevices, isEmpty);
    });

    test('scanDevices returns empty list when no devices are discovered (no dummy data)', () async {
      final emptyService = SmartTvCastService(isTestMode: true);
      final devices = await emptyService.scanDevices();
      expect(devices, isEmpty);
      emptyService.dispose();
    });

    test('scanDevices returns initialDevices when provided in test mode', () async {
      final testService = SmartTvCastService(
        isTestMode: true,
        initialDevices: const [
          CastDevice(
            id: 'tv_samsung_1',
            name: 'Samsung Smart TV',
            ipAddress: '192.168.1.101',
            type: CastDeviceType.samsung,
          ),
        ],
      );
      final devices = await testService.scanDevices();
      expect(devices, isNotEmpty);
      expect(devices.length, 1);
      expect(devices.first.name, 'Samsung Smart TV');
      testService.dispose();
    });

    test('connect and disconnect updates connectedDevice', () async {
      const device = CastDevice(
        id: 'tv_1',
        name: 'Living Room TV',
        ipAddress: '192.168.1.50',
        type: CastDeviceType.androidTv,
      );

      final connected = await service.connect(device);
      expect(connected, isTrue);
      expect(service.connectedDevice, isNotNull);
      expect(service.connectedDevice!.name, 'Living Room TV');
      expect(service.connectedDevice!.isConnected, isTrue);

      await service.disconnect();
      expect(service.connectedDevice, isNull);
    });

    test('connectWithTvCode sets TV with code as connected device', () async {
      final result = await service.connectWithTvCode('123 456');
      expect(result, isTrue);
      expect(service.connectedDevice, isNotNull);
      expect(service.connectedDevice!.name, contains('123 456'));
      expect(service.connectedDevice!.isConnected, isTrue);
    });

    test('connectWithTvCode returns false for empty code', () async {
      final result = await service.connectWithTvCode('   ');
      expect(result, isFalse);
      expect(service.connectedDevice, isNull);
    });

    test('castVideo returns true when device is connected and videoId provided', () async {
      expect(await service.castVideo('dQw4w9WgXcQ'), isFalse);

      await service.connectWithTvCode('999');
      expect(
        await service.castVideo(
          'dQw4w9WgXcQ',
          title: 'Never Gonna Give You Up',
          artist: 'Rick Astley',
        ),
        isTrue,
      );
      expect(await service.castVideo(''), isFalse);
    });

    test('getDirectStreamUrl returns test URL in test mode', () async {
      final url = await service.getDirectStreamUrl('dQw4w9WgXcQ');
      expect(url, contains('dQw4w9WgXcQ.mp4'));
    });

    test('play, pause, and seek execute cleanly in test mode', () async {
      await service.play();
      await service.pause();
      await service.seek(const Duration(seconds: 30));
      expect(service.isTestMode, isTrue);
    });
  });
}
