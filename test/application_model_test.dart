import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_app/models/application_model.dart';

void main() {
  group('ApplicationModel click URL', () {
    test('fromJson membaca URL klik untuk semua slot iklan gambar', () {
      final config = ApplicationModel.fromJson({
        'applicationid': 1,
        'applicationcompany': 'PT Karaoke',
        'applicationname': 'Karaoke App',
        'applicationads1': 'https://cdn.example.com/ads/1.jpg',
        'applicationads1type': 'image',
        'applicationads1clickurl': 'https://example.com/promo-1',
        'applicationads2': 'https://cdn.example.com/ads/2.jpg',
        'applicationads2type': 'image',
        'applicationads2clickurl': 'https://example.com/promo-2',
        'applicationadsbottom': 'https://cdn.example.com/ads/bottom.jpg',
        'applicationadsbottomtype': 'image',
        'applicationadsbottomclickurl': 'https://example.com/promo-bottom',
      });

      expect(config.applicationads1clickurl, 'https://example.com/promo-1');
      expect(config.applicationads2clickurl, 'https://example.com/promo-2');
      expect(
        config.applicationadsbottomclickurl,
        'https://example.com/promo-bottom',
      );

      expect(config.ads1Config.clickUrl, 'https://example.com/promo-1');
      expect(config.ads2Config.clickUrl, 'https://example.com/promo-2');
      expect(
        config.adsBottomConfig.clickUrl,
        'https://example.com/promo-bottom',
      );
    });

    test('toJson menyertakan URL klik agar tidak hilang saat disimpan', () {
      const config = ApplicationModel(
        applicationid: 1,
        applicationcompany: 'PT Karaoke',
        applicationname: 'Karaoke App',
        applicationads1clickurl: 'https://example.com/promo-1',
        applicationads2clickurl: 'https://example.com/promo-2',
        applicationadsbottomclickurl: 'https://example.com/promo-bottom',
      );

      final json = config.toJson();

      expect(json['applicationads1clickurl'], 'https://example.com/promo-1');
      expect(json['applicationads2clickurl'], 'https://example.com/promo-2');
      expect(
        json['applicationadsbottomclickurl'],
        'https://example.com/promo-bottom',
      );
    });

    test('hasClickUrl hanya menerima URL http/https yang valid', () {
      expect(
        const AdSlotConfig(clickUrl: 'https://example.com/promo').hasClickUrl,
        isTrue,
      );
      expect(
        const AdSlotConfig(clickUrl: 'http://example.com/promo').hasClickUrl,
        isTrue,
      );
      expect(
        const AdSlotConfig(clickUrl: 'ftp://example.com/promo').hasClickUrl,
        isFalse,
      );
      expect(const AdSlotConfig(clickUrl: 'bukan-url').hasClickUrl, isFalse);
      expect(const AdSlotConfig(clickUrl: '  ').hasClickUrl, isFalse);
      expect(const AdSlotConfig().hasClickUrl, isFalse);
    });
  });
}
