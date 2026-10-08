import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EmployeeLayoutVariant { variantAInline, variantBHub }

class AbTestingService {
  AbTestingService();

  static const String experimentKey =
      'exp_farmer_employee_management_layout_v1';

  EmployeeLayoutVariant get activeVariant => EmployeeLayoutVariant.variantBHub;

  final List<Map<String, dynamic>> _loggedEvents = [];
  List<Map<String, dynamic>> get loggedEvents =>
      List.unmodifiable(_loggedEvents);

  void logEvent(String eventName, [Map<String, dynamic>? parameters]) {
    final payload = {
      'event': eventName,
      'experiment': experimentKey,
      'variant': activeVariant.name,
      'timestamp': DateTime.now().toIso8601String(),
      ...?parameters,
    };

    _loggedEvents.add(payload);
    if (kDebugMode) {
      debugPrint('[A/B Testing Telemetry] $payload');
    }
  }

  void clearLogs() {
    _loggedEvents.clear();
  }
}

final abTestingServiceProvider = Provider<AbTestingService>((ref) {
  return AbTestingService();
});
