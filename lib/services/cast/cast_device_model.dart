enum CastDeviceType {
  chromecast,
  samsung,
  lg,
  androidTv,
  generic,
}

class CastDevice {
  final String id;
  final String name;
  final String ipAddress;
  final CastDeviceType type;
  final bool isConnected;
  final String? locationUrl;
  final String? controlUrl;
  final String? dialUrl;

  const CastDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    this.type = CastDeviceType.generic,
    this.isConnected = false,
    this.locationUrl,
    this.controlUrl,
    this.dialUrl,
  });

  CastDevice copyWith({
    String? id,
    String? name,
    String? ipAddress,
    CastDeviceType? type,
    bool? isConnected,
    String? locationUrl,
    String? controlUrl,
    String? dialUrl,
  }) {
    return CastDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      locationUrl: locationUrl ?? this.locationUrl,
      controlUrl: controlUrl ?? this.controlUrl,
      dialUrl: dialUrl ?? this.dialUrl,
    );
  }
}
