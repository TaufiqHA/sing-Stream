import 'dart:async';
import '../../models/admin_stats_model.dart';

abstract class AdminService {
  Future<AdminStatsModel> getStats();
}
