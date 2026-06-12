import 'dart:io';
import 'package:health/health.dart';

/// Availability status of Health Connect on this device.
enum HCAvailability {
  /// Health Connect is installed and ready.
  available,

  /// Health Connect needs to be installed from Play Store.
  notInstalled,

  /// This platform doesn't support Health Connect (e.g. iOS handled separately).
  unsupported,
}

/// Service that reads step-count and fitness data from Android Health Connect
/// (Smartwatch → Noise App → Google Fit → Health Connect → MedicoScope).
class HealthConnectService {
  static final Health _health = Health();
  static bool _configured = false;

  // Data types this service accesses
  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
  ];

  // ── Internal helpers ────────────────────────────────────────────────────────

  static Future<void> _configure() async {
    if (_configured) return;
    try {
      await _health.configure();
      _configured = true;
    } catch (_) {
      // configure() may throw on unsupported platforms — swallow silently
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Check whether the Health Connect SDK is available on this device.
  /// Must be called BEFORE any other Health Connect operation.
  static Future<HCAvailability> getAvailability() async {
    if (!Platform.isAndroid) return HCAvailability.unsupported;

    try {
      await _configure();
      final status = await _health.getHealthConnectSdkStatus();
      switch (status) {
        case HealthConnectSdkStatus.sdkAvailable:
          return HCAvailability.available;
        case HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
        case HealthConnectSdkStatus.sdkUnavailable:
        default:
          return HCAvailability.notInstalled;
      }
    } catch (_) {
      return HCAvailability.notInstalled;
    }
  }

  /// Request Health Connect permissions from the user.
  /// Opens the Health Connect permission screen.
  /// Returns `true` when at least step permissions are granted.
  static Future<bool> requestPermissions() async {
    try {
      await _configure();
      final granted = await _health.requestAuthorization(_types);
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Check whether permissions were already granted (avoids re-prompting).
  static Future<bool> hasPermissions() async {
    try {
      await _configure();
      final result = await _health.hasPermissions(_types);
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Data readers ────────────────────────────────────────────────────────────

  /// Total steps from midnight today up to now.
  static Future<int> getTodaySteps() async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(start, now);
      return steps ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Daily step totals for the last [days] days (oldest → newest).
  static Future<List<DailySteps>> getWeeklySteps({int days = 7}) async {
    final List<DailySteps> result = [];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final dayStart =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayEnd =
          i == 0 ? now : dayStart.add(const Duration(days: 1));

      try {
        final steps = await _health.getTotalStepsInInterval(dayStart, dayEnd);
        result.add(DailySteps(date: dayStart, steps: steps ?? 0));
      } catch (_) {
        result.add(DailySteps(date: dayStart, steps: 0));
      }
    }
    return result;
  }

  /// Active calories burned today (kcal).
  static Future<double> getTodayCalories() async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      final dedup = _health.removeDuplicates(data);
      double total = 0;
      for (final p in dedup) {
        final v = p.value;
        if (v is NumericHealthValue) total += v.numericValue.toDouble();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Distance covered today (metres).
  static Future<double> getTodayDistance() async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.DISTANCE_DELTA],
      );
      final dedup = _health.removeDuplicates(data);
      double total = 0;
      for (final p in dedup) {
        final v = p.value;
        if (v is NumericHealthValue) total += v.numericValue.toDouble();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Average heart rate today (bpm).
  static Future<double> getTodayAvgHeartRate() async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.HEART_RATE],
      );
      final dedup = _health.removeDuplicates(data);
      if (dedup.isEmpty) return 0;
      double total = 0;
      for (final p in dedup) {
        final v = p.value;
        if (v is NumericHealthValue) total += v.numericValue.toDouble();
      }
      return total / dedup.length;
    } catch (_) {
      return 0;
    }
  }

  /// Latest resting heart rate reading from the last 7 days.
  static Future<double?> getLatestRestingHeartRate() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.RESTING_HEART_RATE],
      );
      if (data.isEmpty) return null;
      final latest = data.reduce((a, b) =>
          a.dateTo.isAfter(b.dateTo) ? a : b);
      final v = latest.value;
      if (v is NumericHealthValue) return v.numericValue.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Latest SpO2 percentage (0-100).
  static Future<double?> getLatestSpO2() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.BLOOD_OXYGEN],
      );
      if (data.isEmpty) return null;
      final latest =
          data.reduce((a, b) => a.dateTo.isAfter(b.dateTo) ? a : b);
      final v = latest.value;
      if (v is NumericHealthValue) {
        final val = v.numericValue.toDouble();
        // Some providers return 0.98 instead of 98; normalise.
        return val < 1.1 ? val * 100 : val;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Latest systolic / diastolic BP pair.
  static Future<({double systolic, double diastolic})?>
      getLatestBloodPressure() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));
      final sys = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.BLOOD_PRESSURE_SYSTOLIC],
      );
      final dia = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
      );
      if (sys.isEmpty || dia.isEmpty) return null;
      final latestSys = sys.reduce(
          (a, b) => a.dateTo.isAfter(b.dateTo) ? a : b);
      final latestDia = dia.reduce(
          (a, b) => a.dateTo.isAfter(b.dateTo) ? a : b);
      final s = latestSys.value;
      final di = latestDia.value;
      if (s is NumericHealthValue && di is NumericHealthValue) {
        return (
          systolic: s.numericValue.toDouble(),
          diastolic: di.numericValue.toDouble(),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Latest HRV RMSSD reading (ms).
  static Future<double?> getLatestHRV() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
      );
      if (data.isEmpty) return null;
      final latest =
          data.reduce((a, b) => a.dateTo.isAfter(b.dateTo) ? a : b);
      final v = latest.value;
      if (v is NumericHealthValue) return v.numericValue.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// One-shot wearable snapshot — returns everything in parallel.
  static Future<WearableSnapshot> getSnapshot() async {
    final results = await Future.wait([
      getTodaySteps(),
      getTodayAvgHeartRate(),
      getLatestRestingHeartRate(),
      getLatestSpO2(),
      getLatestBloodPressure(),
      getLatestHRV(),
    ]);
    final bp = results[4] as ({double systolic, double diastolic})?;
    return WearableSnapshot(
      steps: results[0] as int,
      avgHeartRate: results[1] as double,
      restingHeartRate: results[2] as double?,
      spO2: results[3] as double?,
      systolic: bp?.systolic,
      diastolic: bp?.diastolic,
      hrvRmssd: results[5] as double?,
      capturedAt: DateTime.now(),
    );
  }
}

class DailySteps {
  final DateTime date;
  final int steps;
  const DailySteps({required this.date, required this.steps});
}

class WearableSnapshot {
  final int steps;
  final double avgHeartRate;
  final double? restingHeartRate;
  final double? spO2;
  final double? systolic;
  final double? diastolic;
  final double? hrvRmssd;
  final DateTime capturedAt;

  const WearableSnapshot({
    required this.steps,
    required this.avgHeartRate,
    this.restingHeartRate,
    this.spO2,
    this.systolic,
    this.diastolic,
    this.hrvRmssd,
    required this.capturedAt,
  });

  /// True when at least one non-step value was read successfully.
  bool get hasClinicalData =>
      restingHeartRate != null ||
      spO2 != null ||
      systolic != null ||
      hrvRmssd != null ||
      avgHeartRate > 0;
}
