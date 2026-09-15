import 'dart:async';
import '../../models/application_model.dart';
import 'application_service.dart';

class DummyApplicationService implements ApplicationService {
  static const ApplicationModel defaultApplication = ApplicationModel(
    applicationid: 1,
    applicationcompany: 'PT Karaoke Musik Nusantara',
    applicationname: 'Karaoke Mobile App',
    applicationads1: null,
    applicationads2: null,
    applicationadsactive: 'Y',
    applicationadsbottom: null,
    applicationadsbottomactive: 'Y',
  );

  ApplicationModel _config;

  DummyApplicationService([ApplicationModel? initialConfig])
      : _config = initialConfig ?? defaultApplication;

  @override
  Future<ApplicationModel> getApplicationConfig() async {
    return _config;
  }

  @override
  Future<ApplicationModel> updateApplicationConfig(ApplicationModel config) async {
    _config = config;
    return _config;
  }
}

