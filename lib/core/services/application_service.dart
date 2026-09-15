import '../../models/application_model.dart';

abstract class ApplicationService {
  Future<ApplicationModel> getApplicationConfig();
  Future<ApplicationModel> updateApplicationConfig(ApplicationModel config);
}
