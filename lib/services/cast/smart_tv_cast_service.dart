import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'cast_device_model.dart';

/// Layanan pemindaian dan transmisi ke perangkat Smart TV / Chromecast
/// Menggunakan flutter_chrome_cast dan youtube_explode_dart untuk ekstraksi stream YouTube.
class SmartTvCastService {
  final List<CastDevice> _discoveredDevices = [];
  final StreamController<List<CastDevice>> _devicesController =
      StreamController<List<CastDevice>>.broadcast();
  final StreamController<CastDevice?> _connectedDeviceController =
      StreamController<CastDevice?>.broadcast();

  CastDevice? _connectedDevice;
  bool _isScanning = false;
  final bool isTestMode;
  final List<CastDevice>? initialDevices;
  StreamSubscription? _googleCastDevicesSubscription;
  StreamSubscription? _googleCastSessionSubscription;

  // YouTube Lounge API state untuk TV Code
  String? _loungeScreenId;
  String? _loungeToken;
  String? _loungeSid;
  String? _loungeGsession;
  int _loungeCommandOffset = 1;
  final int _loungeLastEventId = 0;

  SmartTvCastService({this.isTestMode = false, this.initialDevices}) {
    if (!isTestMode) {
      _initGoogleCast();
    }
  }

  CastDevice? get connectedDevice => _connectedDevice;
  bool get isScanning => _isScanning;
  List<CastDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  Stream<List<CastDevice>> get devicesStream => _devicesController.stream;
  Stream<CastDevice?> get connectedDeviceStream => _connectedDeviceController.stream;

  /// Inisialisasi Google Cast Context pada startup aplikasi
  static Future<void> initGoogleCastContext() async {
    try {
      if (kIsWeb) return;
      const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
      GoogleCastOptions? options;

      if (Platform.isIOS) {
        options = IOSGoogleCastOptions(
          GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
          stopCastingOnAppTerminated: true,
        );
      } else if (Platform.isAndroid) {
        options = GoogleCastOptionsAndroid(
          appId: appId,
          stopCastingOnAppTerminated: true,
        );
      }

      if (options != null) {
        GoogleCastContext.instance.setSharedInstanceWithOptions(options);
      }
    } catch (_) {
      // Graceful fallback jika berjalan di environment testing atau desktop
    }
  }

  void _initGoogleCast() {
    try {
      // Inisialisasi listener perangkat dari Google Cast Discovery Manager
      _googleCastDevicesSubscription =
          GoogleCastDiscoveryManager.instance.devicesStream.listen((devices) {
        _syncGoogleCastDevices(devices);
      }, onError: (_) {});

      // Sinkronisasi perangkat yang mungkin sudah terdeteksi sebelumnya
      final currentDevices = GoogleCastDiscoveryManager.instance.devices;
      if (currentDevices.isNotEmpty) {
        _syncGoogleCastDevices(currentDevices);
      }

      // Inisialisasi listener status sesi Google Cast
      _googleCastSessionSubscription =
          GoogleCastSessionManager.instance.currentSessionStream.listen((session) {
        if (session != null && session.device != null) {
          _connectedDevice = CastDevice(
            id: 'chromecast_${session.device!.deviceID}',
            name: session.device!.friendlyName,
            ipAddress: 'Chromecast',
            type: CastDeviceType.chromecast,
            isConnected: true,
          );
        } else if (_connectedDevice?.type == CastDeviceType.chromecast) {
          _connectedDevice = null;
        }
        if (!_connectedDeviceController.isClosed) {
          _connectedDeviceController.add(_connectedDevice);
        }
      }, onError: (_) {});
    } catch (_) {
      // Jika Google Cast SDK belum siap atau platform tidak mendukung
    }
  }

  void _syncGoogleCastDevices(List<GoogleCastDevice> devices) {
    // Pertahankan perangkat non-chromecast (misal SSDP TV)
    _discoveredDevices.removeWhere((d) => d.type == CastDeviceType.chromecast);

    for (final dev in devices) {
      final id = 'chromecast_${dev.deviceID}';
      if (!_discoveredDevices.any((d) => d.id == id)) {
        _discoveredDevices.add(
          CastDevice(
            id: id,
            name: dev.friendlyName,
            ipAddress: 'Chromecast',
            type: CastDeviceType.chromecast,
          ),
        );
      }
    }

    if (!_devicesController.isClosed) {
      _devicesController.add(List.unmodifiable(_discoveredDevices));
    }
  }

  /// Ekstraksi direct video stream URL dari YouTube
  Future<String?> getDirectStreamUrl(String videoId) async {
    if (isTestMode || videoId.isEmpty) {
      return 'https://example.com/video/$videoId.mp4';
    }

    YoutubeExplode? yt;
    try {
      yt = YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      
      // Mengambil stream muxed (audio + video gabungan) resolusi tertinggi
      final muxedStreams = manifest.muxed;
      if (muxedStreams.isNotEmpty) {
        final streamInfo = muxedStreams.withHighestBitrate();
        return streamInfo.url.toString();
      }

      // Fallback ke video-only jika muxed tidak tersedia
      final videoStreams = manifest.video;
      if (videoStreams.isNotEmpty) {
        return videoStreams.first.url.toString();
      }
    } catch (_) {
      // Stream extraction error handling
    } finally {
      yt?.close();
    }
    return null;
  }

  RawDatagramSocket? _ssdpSocket;
  Timer? _ssdpPeriodicTimer;
  StreamSubscription? _ssdpSubscription;

  /// Memulai pemindaian berkelanjutan (Google Cast discovery + SSDP periodic polling)
  Future<void> startContinuousDiscovery() async {
    if (isTestMode) {
      _isScanning = false;
      _discoveredDevices.clear();
      if (initialDevices != null) {
        _discoveredDevices.addAll(initialDevices!);
      }
      if (!_devicesController.isClosed) {
        _devicesController.add(List.unmodifiable(_discoveredDevices));
      }
      return;
    }

    _isScanning = true;

    try {
      // 1. Google Cast Discovery
      GoogleCastDiscoveryManager.instance.startDiscovery();
      final currentDevices = GoogleCastDiscoveryManager.instance.devices;
      if (currentDevices.isNotEmpty) {
        _syncGoogleCastDevices(currentDevices);
      }
    } catch (_) {}

    try {
      // 2. SSDP Continuous Discovery
      _ssdpSubscription?.cancel();
      _ssdpSocket?.close();
      _ssdpPeriodicTimer?.cancel();

      _ssdpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _ssdpSocket?.broadcastEnabled = true;

      const ssdpSearch =
          'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 2\r\n'
          'ST: ssdp:all\r\n\r\n';

      final data = ssdpSearch.codeUnits;
      final broadcastAddress = InternetAddress('239.255.255.250');

      // Kirim probe awal
      _ssdpSocket?.send(data, broadcastAddress, 1900);

      _ssdpSubscription = _ssdpSocket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _ssdpSocket?.receive();
          if (datagram != null) {
            final response = String.fromCharCodes(datagram.data);
            _parseAndAddDevice(response, datagram.address.address);
          }
        }
      });

      // Ulangi pengiriman probe setiap 4 detik selama modal terbuka
      _ssdpPeriodicTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (!_isScanning) {
          timer.cancel();
          return;
        }
        try {
          _ssdpSocket?.send(data, broadcastAddress, 1900);
        } catch (_) {}
      });
    } catch (_) {
      // Error socket / firewall handling
    }
  }

  /// Memindai perangkat TV di jaringan lokal
  Future<List<CastDevice>> scanDevices({Duration timeout = const Duration(seconds: 3)}) async {
    await startContinuousDiscovery();
    if (isTestMode) {
      _isScanning = false;
      return _discoveredDevices;
    }
    await Future.delayed(timeout);
    return _discoveredDevices;
  }

  /// Hentikan proses discovery (Google Cast + SSDP)
  void stopDiscovery() {
    _isScanning = false;
    _ssdpPeriodicTimer?.cancel();
    _ssdpPeriodicTimer = null;
    _ssdpSubscription?.cancel();
    _ssdpSubscription = null;
    try {
      _ssdpSocket?.close();
      _ssdpSocket = null;
    } catch (_) {}

    if (isTestMode) return;
    try {
      GoogleCastDiscoveryManager.instance.stopDiscovery();
    } catch (_) {}
  }

  void _parseAndAddDevice(String response, String ip) {
    String name = 'Smart TV';
    CastDeviceType type = CastDeviceType.generic;

    if (response.contains('Samsung') || response.contains('samsung')) {
      name = 'Samsung Smart TV';
      type = CastDeviceType.samsung;
    } else if (response.contains('LG') || response.contains('webOS')) {
      name = 'LG Smart TV';
      type = CastDeviceType.lg;
    } else if (response.contains('Google') || response.contains('Chromecast') || response.contains('Eureka')) {
      name = 'Google Cast / Chromecast';
      type = CastDeviceType.chromecast;
    } else if (response.contains('BRAVIA') || response.contains('Sony')) {
      name = 'Sony Android TV';
      type = CastDeviceType.androidTv;
    }

    final id = 'tv_$ip';
    String? locationUrl;
    final locationMatch = RegExp(r'LOCATION:\s*(http[^\r\n]+)', caseSensitive: false).firstMatch(response);
    if (locationMatch != null) {
      locationUrl = locationMatch.group(1)?.trim();
    }

    String? dialUrl;
    final appUrlMatch = RegExp(r'Application-URL:\s*(http[^\r\n]+)', caseSensitive: false).firstMatch(response);
    if (appUrlMatch != null) {
      dialUrl = appUrlMatch.group(1)?.trim();
    }

    if (!_discoveredDevices.any((d) => d.id == id)) {
      final device = CastDevice(
        id: id,
        name: name,
        ipAddress: ip,
        type: type,
        locationUrl: locationUrl,
        dialUrl: dialUrl,
      );
      _discoveredDevices.add(device);
      if (!_devicesController.isClosed) {
        _devicesController.add(List.unmodifiable(_discoveredDevices));
      }

      if (locationUrl != null && !isTestMode) {
        _fetchDeviceDetails(id, locationUrl);
      }
    }
  }

  Future<void> _fetchDeviceDetails(String id, String locationUrl) async {
    try {
      final res = await http.get(Uri.parse(locationUrl)).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final body = res.body;

        final nameMatch = RegExp(r'<friendlyName>([^<]+)</friendlyName>', caseSensitive: false).firstMatch(body);
        String? friendlyName;
        if (nameMatch != null) {
          friendlyName = nameMatch.group(1)?.trim();
        }

        String? dialUrl;
        for (final entry in res.headers.entries) {
          if (entry.key.toLowerCase() == 'application-url') {
            dialUrl = entry.value.trim();
            break;
          }
        }

        CastDeviceType? updatedType;
        final bodyLower = body.toLowerCase();
        if (bodyLower.contains('samsung')) {
          updatedType = CastDeviceType.samsung;
        } else if (bodyLower.contains('lg electronics') || bodyLower.contains('webos')) {
          updatedType = CastDeviceType.lg;
        } else if (bodyLower.contains('sony') || bodyLower.contains('bravia')) {
          updatedType = CastDeviceType.androidTv;
        }

        String? controlUrl;
        final serviceBlocks = body.split(RegExp(r'<\s*/?\s*service\s*>', caseSensitive: false));
        for (final block in serviceBlocks) {
          if (block.contains('AVTransport')) {
            final match = RegExp(r'<controlURL>([^<]+)</controlURL>', caseSensitive: false).firstMatch(block);
            if (match != null) {
              final path = match.group(1)!.trim();
              final base = Uri.parse(locationUrl);
              controlUrl = base.resolve(path).toString();
              break;
            }
          }
        }

        final index = _discoveredDevices.indexWhere((d) => d.id == id);
        if (index != -1) {
          final old = _discoveredDevices[index];
          _discoveredDevices[index] = old.copyWith(
            name: friendlyName ?? old.name,
            controlUrl: controlUrl ?? old.controlUrl,
            dialUrl: dialUrl ?? old.dialUrl,
            type: updatedType ?? old.type,
          );
          if (!_devicesController.isClosed) {
            _devicesController.add(List.unmodifiable(_discoveredDevices));
          }
        }
      }
    } catch (_) {}
  }

  /// Menghubungkan ke perangkat TV
  Future<bool> connect(CastDevice device) async {
    if (isTestMode) {
      _connectedDevice = device.copyWith(isConnected: true);
      if (!_connectedDeviceController.isClosed) {
        _connectedDeviceController.add(_connectedDevice);
      }
      return true;
    }

    // 1. Jika bertipe Chromecast, coba hubungkan sesi Google Cast
    if (device.type == CastDeviceType.chromecast || device.id.startsWith('chromecast_')) {
      try {
        final gcDevices = GoogleCastDiscoveryManager.instance.devices;
        if (gcDevices.isNotEmpty) {
          final gcDevice = gcDevices.firstWhere(
            (d) =>
                'chromecast_${d.deviceID}' == device.id ||
                d.deviceID == device.id ||
                d.friendlyName.toLowerCase() == device.name.toLowerCase(),
            orElse: () => gcDevices.first,
          );
          await GoogleCastSessionManager.instance.startSessionWithDevice(gcDevice);
        }
      } catch (_) {}
    } else {
      // 2. Handshake untuk Smart TV non-Chromecast (Samsung, LG, Sony, Roku, Android TV)
      try {
        await _pingAndPrepareTv(device);
      } catch (_) {}
    }

    _connectedDevice = device.copyWith(isConnected: true);
    if (!_connectedDeviceController.isClosed) {
      _connectedDeviceController.add(_connectedDevice);
    }
    return true;
  }

  Future<void> _pingAndPrepareTv(CastDevice device) async {
    final ip = device.ipAddress;
    if (ip == '127.0.0.1' || ip == 'Chromecast') return;

    final testUrls = [
      if (device.dialUrl != null) device.dialUrl!,
      if (device.locationUrl != null) device.locationUrl!,
      'http://$ip:8080/apps/YouTube',
      'http://$ip:8008/apps/YouTube',
      'http://$ip:8001/api/v2/', // Samsung Tizen
      'http://$ip:8060/',        // Roku ECP
      'http://$ip:7676/smp_2_',   // Samsung DLNA
    ];

    for (final testUrl in testUrls) {
      try {
        await http.get(Uri.parse(testUrl)).timeout(const Duration(milliseconds: 1500));
        return;
      } catch (_) {}
    }
  }

  /// Membuka aplikasi YouTube atau membangunkan Smart TV saat terhubung
  Future<bool> wakeOrLaunchApp(CastDevice device) async {
    if (isTestMode) return true;
    final ip = device.ipAddress;
    if (ip == '127.0.0.1' || ip == 'Chromecast') return true;

    // 1. DIAL wake
    final dialSuccess = await _launchYouTubeViaDial(
      ip,
      '',
      device.locationUrl,
      dialUrl: device.dialUrl,
    );
    if (dialSuccess) return true;

    // 2. Samsung Tizen wake
    if (device.type == CastDeviceType.samsung || ip != '127.0.0.1') {
      final samsungSuccess = await _launchSamsungYouTube(ip, '');
      if (samsungSuccess) return true;
    }

    // 3. Roku wake
    final rokuSuccess = await _launchRokuYouTube(ip, '');
    if (rokuSuccess) return true;

    return false;
  }

  /// Memutuskan koneksi TV
  Future<void> disconnect() async {
    if (!isTestMode && _connectedDevice?.type == CastDeviceType.chromecast) {
      try {
        await GoogleCastSessionManager.instance.endSessionAndStopCasting();
      } catch (_) {}
    }

    if (!isTestMode &&
        (_connectedDevice?.id.startsWith('tv_code_') == true ||
            _loungeScreenId != null)) {
      await _terminateLoungeSession();
    }

    _connectedDevice = null;
    if (!_connectedDeviceController.isClosed) {
      _connectedDeviceController.add(null);
    }
  }

  /// Menghubungkan menggunakan kode TV (Link with TV Code / YouTube Lounge API)
  Future<bool> connectWithTvCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;

    if (isTestMode) {
      _connectedDevice = CastDevice(
        id: 'tv_code_${trimmed.hashCode}',
        name: 'TV ($trimmed)',
        ipAddress: '127.0.0.1',
        type: CastDeviceType.generic,
        isConnected: true,
      );
      if (!_connectedDeviceController.isClosed) {
        _connectedDeviceController.add(_connectedDevice);
      }
      return true;
    }

    final cleanCode = code.replaceAll(RegExp(r'[\s-]'), '').trim();
    if (cleanCode.isEmpty) return false;

    try {
      final pairUrl = Uri.parse('https://www.youtube.com/api/lounge/pairing/get_screen');
      final pairResponse = await http.post(
        pairUrl,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'pairing_code': cleanCode},
      ).timeout(const Duration(seconds: 8));

      if (pairResponse.statusCode == 200) {
        final data = jsonDecode(pairResponse.body);
        if (data is Map<String, dynamic> && data['screen'] != null) {
          final screen = data['screen'];
          _loungeScreenId = screen['screenId']?.toString();
          _loungeToken = screen['loungeToken']?.toString();
          final screenName = screen['name']?.toString() ?? 'YouTube TV';

          // Buka sesi bind untuk mendapatkan SID & gsessionid
          final sessionOk = await _initLoungeSession();
          if (!sessionOk) {
            _loungeScreenId = null;
            _loungeToken = null;
            return false;
          }

          _connectedDevice = CastDevice(
            id: 'tv_code_${_loungeScreenId ?? cleanCode}',
            name: screenName,
            ipAddress: 'YouTube Lounge',
            type: CastDeviceType.generic,
            isConnected: true,
          );

          if (!_connectedDeviceController.isClosed) {
            _connectedDeviceController.add(_connectedDevice);
          }
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  Future<bool> _initLoungeSession() async {
    if (_loungeScreenId == null || _loungeToken == null) return false;
    final commonHeaders = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Origin': 'https://www.youtube.com',
      'X-YouTube-LoungeId-Token': _loungeToken!,
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };

    // Percobaan 1: Format bind standar pyytlounge
    try {
      const bindUrl =
          'https://www.youtube.com/api/lounge/bc/bind?RID=1&VER=8&CVER=1&auth_failure_option=send_error';
      final body = {
        'app': 'youtube-desktop',
        'mdx-version': '3',
        'name': 'Karaoke Mobile App',
        'id': _loungeScreenId!,
        'device': 'REMOTE_CONTROL',
        'capabilities': 'que,dsdtr,atp,vsp',
        'magnaKey': 'cloudPairedDevice',
        'ui': 'false',
        'deviceContext':
            'user_agent=dunno&window_width_points=&window_height_points=&os_name=android&ms=',
        'theme': 'cl',
        'loungeIdToken': _loungeToken!,
      };

      final res = await http.post(
        Uri.parse(bindUrl),
        headers: commonHeaders,
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final bodyText = res.body;
        final sidMatch = RegExp(r'\[\s*"c"\s*,\s*"([^"]+)"').firstMatch(bodyText);
        final gsMatch = RegExp(r'\[\s*"S"\s*,\s*"([^"]+)"').firstMatch(bodyText);
        if (sidMatch != null && gsMatch != null) {
          _loungeSid = sidMatch.group(1);
          _loungeGsession = gsMatch.group(1);
          _loungeCommandOffset = 1;
          return true;
        }
      }
    } catch (_) {}

    // Percobaan 2 (Fallback): Format bind query-parameters
    try {
      final queryParams = {
        'CVER': '1',
        'RID': '1',
        'VER': '8',
        'app': 'youtube-desktop',
        'device': 'REMOTE_CONTROL',
        'id': 'remote',
        'loungeIdToken': _loungeToken!,
        'name': 'Karaoke Mobile App',
      };
      final uri = Uri.parse('https://www.youtube.com/api/lounge/bc/bind').replace(
        queryParameters: queryParams,
      );

      final fallbackRes = await http.post(
        uri,
        headers: commonHeaders,
      ).timeout(const Duration(seconds: 5));

      if (fallbackRes.statusCode == 200) {
        final bodyText = fallbackRes.body;
        final sidMatch = RegExp(r'\[\s*"c"\s*,\s*"([^"]+)"').firstMatch(bodyText);
        final gsMatch = RegExp(r'\[\s*"S"\s*,\s*"([^"]+)"').firstMatch(bodyText);
        if (sidMatch != null && gsMatch != null) {
          _loungeSid = sidMatch.group(1);
          _loungeGsession = gsMatch.group(1);
          _loungeCommandOffset = 1;
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  Future<bool> _sendLoungeCommand(String command, Map<String, String> params) async {
    if (isTestMode) return true;
    if (_loungeScreenId == null || _loungeToken == null) return false;

    if (_loungeSid == null || _loungeGsession == null) {
      final inited = await _initLoungeSession();
      if (!inited) return false;
    }

    final offset = _loungeCommandOffset++;

    final queryParams = {
      'name': 'Karaoke Mobile App',
      'loungeIdToken': _loungeToken ?? '',
      'SID': _loungeSid ?? '',
      'AID': _loungeLastEventId.toString(),
      'gsessionid': _loungeGsession ?? '',
      'device': 'REMOTE_CONTROL',
      'app': 'youtube-desktop',
      'VER': '8',
      'v': '2',
      'RID': offset.toString(),
    };

    final formBody = <String, String>{
      'count': '1',
      'ofs': offset.toString(),
      'req0__sc': command,
    };
    params.forEach((key, val) {
      formBody['req0_$key'] = val;
    });

    final uri = Uri.parse('https://www.youtube.com/api/lounge/bc/bind').replace(
      queryParameters: queryParams,
    );

    try {
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Origin': 'https://www.youtube.com',
          'X-YouTube-LoungeId-Token': _loungeToken ?? '',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        body: formBody,
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return true;
      } else if (res.statusCode == 401 ||
          res.statusCode == 400 ||
          res.statusCode == 404 ||
          res.statusCode == 410) {
        _loungeSid = null;
        _loungeGsession = null;
        final reconnected = await _initLoungeSession();
        if (reconnected) {
          return await _sendLoungeCommand(command, params);
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _terminateLoungeSession() async {
    try {
      if (_loungeSid != null && _loungeGsession != null && _loungeScreenId != null) {
        final queryParams = {
          'SID': _loungeSid ?? '',
          'gsessionid': _loungeGsession ?? '',
          'RID': (_loungeCommandOffset++).toString(),
          'VER': '8',
          'v': '2',
          'CVER': '1',
          'name': 'Karaoke Mobile App',
          'app': 'youtube-desktop',
          'device': 'REMOTE_CONTROL',
          'loungeIdToken': _loungeToken ?? '',
        };
        final uri = Uri.parse('https://www.youtube.com/api/lounge/bc/bind').replace(
          queryParameters: queryParams,
        );
        await http.post(
          uri,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Origin': 'https://www.youtube.com',
            'X-YouTube-LoungeId-Token': _loungeToken ?? '',
          },
          body: {
            'ui': '',
            'TYPE': 'terminate',
            'clientDisconnectReason':
                'MDX_SESSION_DISCONNECT_REASON_DISCONNECTED_BY_USER',
          },
        ).timeout(const Duration(seconds: 2));
      }
    } catch (_) {}
    _loungeScreenId = null;
    _loungeToken = null;
    _loungeSid = null;
    _loungeGsession = null;
    _loungeCommandOffset = 1;
  }

  /// Mentransmisikan video ke TV yang terhubung (mendukung Google Cast, DIAL YouTube, Samsung Tizen, Roku, dan DLNA)
  Future<bool> castVideo(
    String videoId, {
    String? title,
    String? artist,
    String? thumbnailUrl,
  }) async {
    if (_connectedDevice == null || videoId.isEmpty) return false;

    if (isTestMode) {
      return true;
    }

    // 0. YouTube Lounge API (jika terhubung via YouTube TV Code)
    if (_connectedDevice?.id.startsWith('tv_code_') == true ||
        _loungeScreenId != null) {
      final playlistSuccess = await _sendLoungeCommand('setPlaylist', {
        'videoId': videoId,
        'videoIds': videoId,
        'currentTime': '0',
        'currentIndex': '0',
        'audioOnly': 'false',
      });
      if (playlistSuccess) return true;

      // Fallback jika TV lounge memerlukan antrean addVideo + setVideo
      await _sendLoungeCommand('addVideo', {'videoId': videoId});
      return await _sendLoungeCommand('setVideo', {
        'videoId': videoId,
        'currentTime': '0',
      });
    }

    final ip = _connectedDevice!.ipAddress;

    // 1. Google Cast Media Session (jika Chromecast terhubung dan sesi aktif)
    if (_connectedDevice?.type == CastDeviceType.chromecast ||
        _connectedDevice?.id.startsWith('chromecast_') == true) {
      try {
        final currentSession = GoogleCastSessionManager.instance.currentSession;
        if (currentSession != null) {
          final directStreamUrl = await getDirectStreamUrl(videoId);
          if (directStreamUrl != null && directStreamUrl.isNotEmpty) {
            final mediaInfo = GoogleCastMediaInformation(
              contentId: videoId,
              streamType: CastMediaStreamType.buffered,
              contentUrl: Uri.parse(directStreamUrl),
              contentType: 'video/mp4',
              metadata: GoogleCastMovieMediaMetadata(
                title: title ?? 'Karaoke Track',
                subtitle: artist,
                images: thumbnailUrl != null
                    ? [GoogleCastImage(url: Uri.parse(thumbnailUrl))]
                    : null,
              ),
            );

            await GoogleCastRemoteMediaClient.instance.loadMedia(mediaInfo);
            return true;
          }
        }
      } catch (_) {}
    }

    // 2. DIAL Protocol (Discovery and Launch) - Membuka dan memutar YouTube langsung di Smart TV
    final dialSuccess = await _launchYouTubeViaDial(
      ip,
      videoId,
      _connectedDevice?.locationUrl,
      dialUrl: _connectedDevice?.dialUrl,
    );
    if (dialSuccess) {
      return true;
    }

    // 3. Samsung Tizen Smart TV REST API (Port 8001)
    if (_connectedDevice?.type == CastDeviceType.samsung || ip != '127.0.0.1') {
      final samsungSuccess = await _launchSamsungYouTube(ip, videoId);
      if (samsungSuccess) {
        return true;
      }
    }

    // 4. Roku TV External Control Protocol (ECP)
    final rokuSuccess = await _launchRokuYouTube(ip, videoId);
    if (rokuSuccess) {
      return true;
    }

    // 5. DLNA / UPnP AVTransport Protocol (Universal Media Player di Smart TV)
    final directStreamUrl = await getDirectStreamUrl(videoId);
    if (directStreamUrl != null && directStreamUrl.isNotEmpty) {
      final dlnaSuccess = await _castViaDlna(
        ip,
        directStreamUrl,
        title: title,
        controlUrl: _connectedDevice?.controlUrl,
      );
      if (dlnaSuccess) {
        return true;
      }
    }

    return dialSuccess;
  }

  Future<bool> _launchYouTubeViaDial(
    String ip,
    String videoId,
    String? locationUrl, {
    String? dialUrl,
  }) async {
    final candidateUrls = <Uri>[];

    if (dialUrl != null && dialUrl.isNotEmpty) {
      final cleanDial = dialUrl.endsWith('/') ? dialUrl : '$dialUrl/';
      candidateUrls.add(Uri.parse('${cleanDial}YouTube'));
      candidateUrls.add(Uri.parse('${cleanDial}youtube.leanback.v4'));
      candidateUrls.add(Uri.parse(dialUrl));
    }

    final ports = <int>[];
    if (locationUrl != null) {
      try {
        final port = Uri.parse(locationUrl).port;
        if (port > 0 && !ports.contains(port)) ports.add(port);
      } catch (_) {}
    }
    for (final p in [8080, 8008, 1986, 7676, 8060, 52235]) {
      if (!ports.contains(p)) ports.add(p);
    }

    for (final port in ports) {
      candidateUrls.add(Uri.parse('http://$ip:$port/apps/YouTube'));
      candidateUrls.add(Uri.parse('http://$ip:$port/apps/youtube.leanback.v4'));
    }

    final bodies = videoId.isNotEmpty
        ? ['v=$videoId', 'pairing_type=dial&v=$videoId']
        : [''];

    for (final url in candidateUrls) {
      for (final body in bodies) {
        try {
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          ).timeout(const Duration(milliseconds: 1800));

          if (response.statusCode == 201 ||
              response.statusCode == 200 ||
              response.statusCode == 202 ||
              response.statusCode == 204) {
            return true;
          }
        } catch (_) {}
      }
    }
    return false;
  }

  Future<bool> _launchSamsungYouTube(String ip, String videoId) async {
    final appIds = ['111299001912', 'org.tizen.youtube', '3201412000624'];
    for (final appId in appIds) {
      try {
        final url = Uri.parse('http://$ip:8001/api/v2/applications/$appId');
        final body = videoId.isNotEmpty
            ? jsonEncode({
                'data': {'v': videoId},
                'action': 'play',
              })
            : '';
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        ).timeout(const Duration(milliseconds: 1800));

        if (response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 202) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<bool> _launchRokuYouTube(String ip, String videoId) async {
    try {
      final endpoint = videoId.isNotEmpty
          ? 'http://$ip:8060/launch/837?contentId=$videoId'
          : 'http://$ip:8060/launch/837';
      final res = await http.post(Uri.parse(endpoint)).timeout(const Duration(milliseconds: 1800));
      if (res.statusCode == 200 || res.statusCode == 204) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> _castViaDlna(
    String ip,
    String streamUrl, {
    String? title,
    String? controlUrl,
  }) async {
    final endpoints = <String>[];
    if (controlUrl != null) endpoints.add(controlUrl);
    endpoints.addAll([
      'http://$ip:7676/smp_4_',
      'http://$ip:8080/upnp/control/AVTransport1',
      'http://$ip:49152/upnp/control/AVTransport1',
      'http://$ip:1986/upnp/control/AVTransport1',
    ]);

    final safeTitle = (title ?? 'Karaoke Track')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    final soapSetUri =
        '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body>'
        '<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'
        '<InstanceID>0</InstanceID>'
        '<CurrentURI>$streamUrl</CurrentURI>'
        '<CurrentURIMetaData>&lt;DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"&gt;&lt;item id="0" parentID="-1" restricted="1"&gt;&lt;dc:title&gt;$safeTitle&lt;/dc:title&gt;&lt;upnp:class&gt;object.item.videoItem&lt;/upnp:class&gt;&lt;res protocolInfo="http-get:*:video/mp4:*"&gt;$streamUrl&lt;/res&gt;&lt;/item&gt;&lt;/DIDL-Lite&gt;</CurrentURIMetaData>'
        '</u:SetAVTransportURI>'
        '</s:Body>'
        '</s:Envelope>';

    final soapPlay =
        '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body>'
        '<u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'
        '<InstanceID>0</InstanceID>'
        '<Speed>1</Speed>'
        '</u:Play>'
        '</s:Body>'
        '</s:Envelope>';

    for (final endpoint in endpoints) {
      try {
        final uri = Uri.parse(endpoint);
        final resSet = await http.post(
          uri,
          headers: {
            'Content-Type': 'text/xml; charset="utf-8"',
            'SOAPAction': '"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"',
          },
          body: soapSetUri,
        ).timeout(const Duration(seconds: 2));

        if (resSet.statusCode == 200) {
          await http.post(
            uri,
            headers: {
              'Content-Type': 'text/xml; charset="utf-8"',
              'SOAPAction': '"urn:schemas-upnp-org:service:AVTransport:1#Play"',
            },
            body: soapPlay,
          ).timeout(const Duration(seconds: 2));
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Kontrol playback TV: Play
  Future<void> play() async {
    if (isTestMode) return;
    if (_connectedDevice?.id.startsWith('tv_code_') == true ||
        _loungeScreenId != null) {
      await _sendLoungeCommand('play', {});
      return;
    }
    try {
      await GoogleCastRemoteMediaClient.instance.play();
    } catch (_) {}
  }

  /// Kontrol playback TV: Pause
  Future<void> pause() async {
    if (isTestMode) return;
    if (_connectedDevice?.id.startsWith('tv_code_') == true ||
        _loungeScreenId != null) {
      await _sendLoungeCommand('pause', {});
      return;
    }
    try {
      await GoogleCastRemoteMediaClient.instance.pause();
    } catch (_) {}
  }

  /// Kontrol playback TV: Seek
  Future<void> seek(Duration position) async {
    if (isTestMode) return;
    if (_connectedDevice?.id.startsWith('tv_code_') == true ||
        _loungeScreenId != null) {
      await _sendLoungeCommand(
          'seekTo', {'newTime': position.inSeconds.toString()});
      return;
    }
    try {
      await GoogleCastRemoteMediaClient.instance.seek(
        GoogleCastMediaSeekOption(position: position),
      );
    } catch (_) {}
  }

  void dispose() {
    _googleCastDevicesSubscription?.cancel();
    _googleCastSessionSubscription?.cancel();
    _devicesController.close();
    _connectedDeviceController.close();
  }
}
