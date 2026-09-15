class ApplicationModel {
  final int applicationid;
  final String applicationcompany;
  final String applicationname;
  final String? applicationads1;
  final String? applicationads2;
  final String applicationadsactive; // 'Y' or 'N'
  final String? applicationadsbottom;
  final String applicationadsbottomactive; // 'Y' or 'N'

  const ApplicationModel({
    required this.applicationid,
    required this.applicationcompany,
    required this.applicationname,
    this.applicationads1,
    this.applicationads2,
    this.applicationadsactive = 'Y',
    this.applicationadsbottom,
    this.applicationadsbottomactive = 'Y',
  });

  bool get isAdsActive => applicationadsactive.toUpperCase() == 'Y';
  bool get isAdsBottomActive => applicationadsbottomactive.toUpperCase() == 'Y';

  ApplicationModel copyWith({
    int? applicationid,
    String? applicationcompany,
    String? applicationname,
    String? applicationads1,
    String? applicationads2,
    String? applicationadsactive,
    String? applicationadsbottom,
    String? applicationadsbottomactive,
  }) {
    return ApplicationModel(
      applicationid: applicationid ?? this.applicationid,
      applicationcompany: applicationcompany ?? this.applicationcompany,
      applicationname: applicationname ?? this.applicationname,
      applicationads1: applicationads1 ?? this.applicationads1,
      applicationads2: applicationads2 ?? this.applicationads2,
      applicationadsactive: applicationadsactive ?? this.applicationadsactive,
      applicationadsbottom: applicationadsbottom ?? this.applicationadsbottom,
      applicationadsbottomactive: applicationadsbottomactive ?? this.applicationadsbottomactive,
    );
  }

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    return ApplicationModel(
      applicationid: json['applicationid'] is int
          ? json['applicationid'] as int
          : int.tryParse(json['applicationid']?.toString() ?? '1') ?? 1,
      applicationcompany: json['applicationcompany'] as String? ?? '',
      applicationname: json['applicationname'] as String? ?? '',
      applicationads1: json['applicationads1'] as String?,
      applicationads2: json['applicationads2'] as String?,
      applicationadsactive: json['applicationadsactive'] as String? ?? 'Y',
      applicationadsbottom: json['applicationadsbottom'] as String?,
      applicationadsbottomactive: json['applicationadsbottomactive'] as String? ?? 'Y',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'applicationid': applicationid,
      'applicationcompany': applicationcompany,
      'applicationname': applicationname,
      'applicationads1': applicationads1,
      'applicationads2': applicationads2,
      'applicationadsactive': applicationadsactive,
      'applicationadsbottom': applicationadsbottom,
      'applicationadsbottomactive': applicationadsbottomactive,
    };
  }
}
