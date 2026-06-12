import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:medicoscope/services/vitals_service.dart';

class VitalDataPoint {
  final int tick;
  final String timestamp;
  final double heartRate;
  final double systolic;
  final double diastolic;
  final double spo2;

  VitalDataPoint({
    required this.tick,
    required this.timestamp,
    required this.heartRate,
    required this.systolic,
    required this.diastolic,
    required this.spo2,
  });

  factory VitalDataPoint.fromJson(Map<String, dynamic> json) {
    return VitalDataPoint(
      tick: json['tick'] as int,
      timestamp: json['timestamp'] as String,
      heartRate: (json['heart_rate'] as num).toDouble(),
      systolic: (json['systolic'] as num).toDouble(),
      diastolic: (json['diastolic'] as num).toDouble(),
      spo2: (json['spo2'] as num).toDouble(),
    );
  }
}

class VitalAlert {
  final String type;
  final String severity;
  final String message;
  final String vital;
  final double currentValue;
  final double predictedValue;
  final String timestamp;
  final String location;
  final double latitude;
  final double longitude;
  final String mapsUrl;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String patientName;
  final bool isLocal;

  VitalAlert({
    required this.type,
    required this.severity,
    required this.message,
    required this.vital,
    required this.currentValue,
    required this.predictedValue,
    required this.timestamp,
    this.location = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.mapsUrl = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.patientName = '',
    this.isLocal = false,
  });

  factory VitalAlert.fromJson(Map<String, dynamic> json) {
    return VitalAlert(
      type: json['type'] as String,
      severity: json['severity'] as String,
      message: json['message'] as String,
      vital: json['vital'] as String,
      currentValue: (json['current_value'] as num).toDouble(),
      predictedValue: (json['predicted_value'] as num).toDouble(),
      timestamp: json['timestamp'] as String,
      location: json['location'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      mapsUrl: json['maps_url'] as String? ?? '',
      emergencyContactName: json['emergency_contact_name'] as String? ?? '',
      emergencyContactPhone: json['emergency_contact_phone'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? '',
    );
  }
}

/// Callback type for when new alerts arrive during monitoring.
typedef OnNewAlertsCallback = void Function(List<VitalAlert> newAlerts);

// ── Vital Thresholds for instant client-side alerting ──────────────────────

class _VitalThreshold {
  final double criticalLow;
  final double warningLow;
  final double warningHigh;
  final double criticalHigh;

  const _VitalThreshold({
    required this.criticalLow,
    required this.warningLow,
    required this.warningHigh,
    required this.criticalHigh,
  });
}

class VitalsProvider extends ChangeNotifier {
  String? _sessionId;
  String? _scenario;
  bool _isMonitoring = false;
  bool _isStarting = false;
  String? _error;
  Timer? _tickTimer;
  DateTime? _sessionStart;
  String _sessionLocation = 'Unknown';
  String _patientName = '';
  String _emergencyContactName = '';
  String _emergencyContactPhone = '';
  double _latitude = 0.0;
  double _longitude = 0.0;

  final List<VitalDataPoint> _dataPoints = [];
  final List<VitalDataPoint> _allDataPoints = []; // unclipped for summary
  final List<VitalAlert> _alerts = [];

  /// Optional callback invoked when new alerts arrive (for SMS triggering).
  OnNewAlertsCallback? onNewAlerts;

  // Max points to keep in memory for graph display
  static const int _maxPoints = 100;

  // ── Polling intervals ──────────────────────────────────────────────────
  static const Duration _normalInterval = Duration(seconds: 2);
  static const Duration _urgentInterval = Duration(milliseconds: 800);

  // ── Medical thresholds ─────────────────────────────────────────────────
  static const _hrThreshold = _VitalThreshold(
    criticalLow: 40,
    warningLow: 50,
    warningHigh: 130,
    criticalHigh: 160,
  );
  static const _systolicThreshold = _VitalThreshold(
    criticalLow: 70,
    warningLow: 90,
    warningHigh: 150,
    criticalHigh: 180,
  );
  static const _diastolicThreshold = _VitalThreshold(
    criticalLow: 40,
    warningLow: 60,
    warningHigh: 95,
    criticalHigh: 110,
  );
  static const _spo2Threshold = _VitalThreshold(
    criticalLow: 88,
    warningLow: 92,
    warningHigh: 101,
    criticalHigh: 101,
  );

  // Track which local alert keys have already been fired to avoid spam
  final Set<String> _firedLocalAlertKeys = {};

  // Track if we're in urgent mode (abnormal vitals detected)
  bool _urgentMode = false;

  String? get sessionId => _sessionId;
  String? get scenario => _scenario;
  bool get isMonitoring => _isMonitoring;
  bool get isStarting => _isStarting;
  String? get error => _error;
  List<VitalDataPoint> get dataPoints => _dataPoints;
  List<VitalAlert> get alerts => _alerts;

  VitalDataPoint? get latestPoint =>
      _dataPoints.isNotEmpty ? _dataPoints.last : null;

  double get currentHR => latestPoint?.heartRate ?? 0;
  double get currentSystolic => latestPoint?.systolic ?? 0;
  double get currentDiastolic => latestPoint?.diastolic ?? 0;
  double get currentSpO2 => latestPoint?.spo2 ?? 0;

  Future<void> startMonitoring({
    required String patientId,
    required String patientName,
    required String doctorId,
    String emergencyContactName = '',
    String emergencyContactPhone = '',
    String location = 'Unknown',
    double latitude = 0.0,
    double longitude = 0.0,
  }) async {
    _isStarting = true;
    _error = null;
    notifyListeners();

    try {
      final result = await VitalsService.startSession(
        patientId: patientId,
        patientName: patientName,
        doctorId: doctorId,
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
        location: location,
        latitude: latitude,
        longitude: longitude,
      );

      _sessionId = result['session_id'] as String;
      _scenario = result['scenario'] as String?;
      _isMonitoring = true;
      _isStarting = false;
      _sessionStart = DateTime.now();
      _sessionLocation = location;
      _patientName = patientName;
      _emergencyContactName = emergencyContactName;
      _emergencyContactPhone = emergencyContactPhone;
      _latitude = latitude;
      _longitude = longitude;
      _dataPoints.clear();
      _allDataPoints.clear();
      _alerts.clear();
      _firedLocalAlertKeys.clear();
      _urgentMode = false;
      notifyListeners();

      // Start polling at normal interval (2s instead of old 3s)
      _startTicker(_normalInterval);

      // Fetch first batch immediately
      await _fetchTick();
    } catch (e) {
      _isStarting = false;
      final msg = e.toString();
      if (msg.contains('TimeoutException') || msg.contains('timed out')) {
        _error = 'Server is warming up. Please wait a moment and try again.';
      } else {
        _error = msg;
      }
      notifyListeners();
    }
  }

  void _startTicker(Duration interval) {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(interval, (_) => _fetchTick());
  }

  Future<void> _fetchTick() async {
    if (_sessionId == null || !_isMonitoring) return;

    try {
      final result = await VitalsService.tick(sessionId: _sessionId!);

      final points = (result['data_points'] as List)
          .map((p) => VitalDataPoint.fromJson(p as Map<String, dynamic>))
          .toList();

      _dataPoints.addAll(points);
      _allDataPoints.addAll(points);

      // Trim old points for display
      if (_dataPoints.length > _maxPoints) {
        _dataPoints.removeRange(0, _dataPoints.length - _maxPoints);
      }

      // ── Instant client-side threshold check on every new data point ──
      final localAlerts = <VitalAlert>[];
      for (final point in points) {
        localAlerts.addAll(_checkThresholds(point));
      }

      // ── Process backend alerts ───────────────────────────────────────
      final alertsJson = result['alerts'] as List? ?? [];
      final backendAlerts = <VitalAlert>[];
      for (final a in alertsJson) {
        backendAlerts.add(VitalAlert.fromJson(a as Map<String, dynamic>));
      }

      // Combine: local alerts fire first (instant), then backend alerts
      final allNewAlerts = [...localAlerts, ...backendAlerts];

      for (final alert in allNewAlerts) {
        _alerts.add(alert);
      }

      // ── Adaptive polling: switch to urgent if any alert is critical ──
      final hasCritical = allNewAlerts.any((a) => a.severity == 'critical');

      if (hasCritical && !_urgentMode) {
        _urgentMode = true;
        _startTicker(_urgentInterval);
      } else if (_urgentMode && allNewAlerts.isEmpty && _isRecentVitalsNormal()) {
        _urgentMode = false;
        _startTicker(_normalInterval);
      }

      // Notify callback for SMS triggering
      if (allNewAlerts.isNotEmpty && onNewAlerts != null) {
        onNewAlerts!(allNewAlerts);
      }

      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Check a single data point against medical thresholds and generate
  /// instant local alerts. Uses a cooldown key so the same alert type
  /// doesn't fire repeatedly within a short window.
  List<VitalAlert> _checkThresholds(VitalDataPoint point) {
    final alerts = <VitalAlert>[];
    final now = DateTime.now().toUtc().toIso8601String();
    final mapsUrl = (_latitude != 0.0 && _longitude != 0.0)
        ? 'https://www.google.com/maps?q=$_latitude,$_longitude'
        : '';

    // Heart Rate
    alerts.addAll(_evaluateVital(
      value: point.heartRate,
      vitalName: 'heart_rate',
      displayName: 'Heart Rate',
      unit: 'bpm',
      threshold: _hrThreshold,
      timestamp: now,
      mapsUrl: mapsUrl,
    ));

    // Systolic BP
    alerts.addAll(_evaluateVital(
      value: point.systolic,
      vitalName: 'blood_pressure',
      displayName: 'Systolic BP',
      unit: 'mmHg',
      threshold: _systolicThreshold,
      timestamp: now,
      mapsUrl: mapsUrl,
    ));

    // Diastolic BP
    alerts.addAll(_evaluateVital(
      value: point.diastolic,
      vitalName: 'blood_pressure',
      displayName: 'Diastolic BP',
      unit: 'mmHg',
      threshold: _diastolicThreshold,
      timestamp: now,
      mapsUrl: mapsUrl,
    ));

    // SpO2 (only low is dangerous)
    alerts.addAll(_evaluateVital(
      value: point.spo2,
      vitalName: 'spo2',
      displayName: 'SpO2',
      unit: '%',
      threshold: _spo2Threshold,
      timestamp: now,
      mapsUrl: mapsUrl,
      onlyLow: true,
    ));

    // Sudden spike/drop detection
    alerts.addAll(_checkSuddenChanges(point, now, mapsUrl));

    return alerts;
  }

  List<VitalAlert> _evaluateVital({
    required double value,
    required String vitalName,
    required String displayName,
    required String unit,
    required _VitalThreshold threshold,
    required String timestamp,
    required String mapsUrl,
    bool onlyLow = false,
  }) {
    final alerts = <VitalAlert>[];

    String? severity;
    String? direction;

    if (value <= threshold.criticalLow) {
      severity = 'critical';
      direction = 'dangerously low';
    } else if (value <= threshold.warningLow) {
      severity = 'high';
      direction = 'low';
    } else if (!onlyLow && value >= threshold.criticalHigh) {
      severity = 'critical';
      direction = 'dangerously high';
    } else if (!onlyLow && value >= threshold.warningHigh) {
      severity = 'high';
      direction = 'high';
    }

    if (severity != null && direction != null) {
      // Cooldown: don't fire same alert type+severity within 30 seconds
      final key = '${vitalName}_${severity}_$direction';
      if (!_firedLocalAlertKeys.contains(key)) {
        _firedLocalAlertKeys.add(key);
        Future.delayed(const Duration(seconds: 30), () {
          _firedLocalAlertKeys.remove(key);
        });

        alerts.add(VitalAlert(
          type: 'threshold_breach',
          severity: severity,
          message:
              '$displayName is $direction at ${value.toStringAsFixed(1)} $unit. Immediate attention may be required.',
          vital: vitalName,
          currentValue: value,
          predictedValue: value,
          timestamp: timestamp,
          location: _sessionLocation,
          latitude: _latitude,
          longitude: _longitude,
          mapsUrl: mapsUrl,
          emergencyContactName: _emergencyContactName,
          emergencyContactPhone: _emergencyContactPhone,
          patientName: _patientName,
          isLocal: true,
        ));
      }
    }

    return alerts;
  }

  /// Detect sudden spikes/drops by comparing current reading to the
  /// average of the last 5 readings.
  List<VitalAlert> _checkSuddenChanges(
    VitalDataPoint current,
    String timestamp,
    String mapsUrl,
  ) {
    if (_dataPoints.length < 6) return [];

    final alerts = <VitalAlert>[];
    final recent = _dataPoints.sublist(
      math.max(0, _dataPoints.length - 6),
      _dataPoints.length - 1,
    );

    double avgHR =
        recent.map((p) => p.heartRate).reduce((a, b) => a + b) / recent.length;
    double avgSys =
        recent.map((p) => p.systolic).reduce((a, b) => a + b) / recent.length;
    double avgSpo2 =
        recent.map((p) => p.spo2).reduce((a, b) => a + b) / recent.length;

    // Heart rate sudden change > 30 bpm
    if ((current.heartRate - avgHR).abs() > 30) {
      final dir = current.heartRate > avgHR ? 'spike' : 'drop';
      final key = 'hr_sudden_$dir';
      if (!_firedLocalAlertKeys.contains(key)) {
        _firedLocalAlertKeys.add(key);
        Future.delayed(const Duration(seconds: 20), () {
          _firedLocalAlertKeys.remove(key);
        });
        alerts.add(VitalAlert(
          type: 'sudden_change',
          severity: 'critical',
          message:
              'Sudden heart rate $dir detected: ${current.heartRate.toStringAsFixed(0)} bpm (was ~${avgHR.toStringAsFixed(0)} bpm). This could be life-threatening.',
          vital: 'heart_rate',
          currentValue: current.heartRate,
          predictedValue: avgHR,
          timestamp: timestamp,
          location: _sessionLocation,
          latitude: _latitude,
          longitude: _longitude,
          mapsUrl: mapsUrl,
          emergencyContactName: _emergencyContactName,
          emergencyContactPhone: _emergencyContactPhone,
          patientName: _patientName,
          isLocal: true,
        ));
      }
    }

    // Systolic sudden change > 30 mmHg
    if ((current.systolic - avgSys).abs() > 30) {
      final dir = current.systolic > avgSys ? 'spike' : 'drop';
      final key = 'sys_sudden_$dir';
      if (!_firedLocalAlertKeys.contains(key)) {
        _firedLocalAlertKeys.add(key);
        Future.delayed(const Duration(seconds: 20), () {
          _firedLocalAlertKeys.remove(key);
        });
        alerts.add(VitalAlert(
          type: 'sudden_change',
          severity: 'critical',
          message:
              'Sudden blood pressure $dir: ${current.systolic.toStringAsFixed(0)} mmHg (was ~${avgSys.toStringAsFixed(0)} mmHg).',
          vital: 'blood_pressure',
          currentValue: current.systolic,
          predictedValue: avgSys,
          timestamp: timestamp,
          location: _sessionLocation,
          latitude: _latitude,
          longitude: _longitude,
          mapsUrl: mapsUrl,
          emergencyContactName: _emergencyContactName,
          emergencyContactPhone: _emergencyContactPhone,
          patientName: _patientName,
          isLocal: true,
        ));
      }
    }

    // SpO2 sudden drop > 4%
    if (avgSpo2 - current.spo2 > 4) {
      const key = 'spo2_sudden_drop';
      if (!_firedLocalAlertKeys.contains(key)) {
        _firedLocalAlertKeys.add(key);
        Future.delayed(const Duration(seconds: 20), () {
          _firedLocalAlertKeys.remove(key);
        });
        alerts.add(VitalAlert(
          type: 'sudden_change',
          severity: 'critical',
          message:
              'Rapid SpO2 drop: ${current.spo2.toStringAsFixed(1)}% (was ~${avgSpo2.toStringAsFixed(1)}%). Possible respiratory distress.',
          vital: 'spo2',
          currentValue: current.spo2,
          predictedValue: avgSpo2,
          timestamp: timestamp,
          location: _sessionLocation,
          latitude: _latitude,
          longitude: _longitude,
          mapsUrl: mapsUrl,
          emergencyContactName: _emergencyContactName,
          emergencyContactPhone: _emergencyContactPhone,
          patientName: _patientName,
          isLocal: true,
        ));
      }
    }

    return alerts;
  }

  /// Check if the last 5 data points are all within normal range.
  bool _isRecentVitalsNormal() {
    if (_dataPoints.length < 5) return false;
    final recent = _dataPoints.sublist(_dataPoints.length - 5);
    return recent.every((p) =>
        p.heartRate > _hrThreshold.warningLow &&
        p.heartRate < _hrThreshold.warningHigh &&
        p.systolic > _systolicThreshold.warningLow &&
        p.systolic < _systolicThreshold.warningHigh &&
        p.diastolic > _diastolicThreshold.warningLow &&
        p.diastolic < _diastolicThreshold.warningHigh &&
        p.spo2 > _spo2Threshold.warningLow);
  }

  Future<void> stopMonitoring({String? token}) async {
    _tickTimer?.cancel();
    _tickTimer = null;

    final savedSessionId = _sessionId;

    if (_sessionId != null) {
      try {
        await VitalsService.stopSession(sessionId: _sessionId!);
      } catch (_) {
        // Best effort cleanup
      }
    }

    // Persist session summary to MongoDB
    if (token != null && savedSessionId != null && _allDataPoints.isNotEmpty) {
      try {
        final pts = _allDataPoints;
        final duration = _sessionStart != null
            ? DateTime.now().difference(_sessionStart!).inSeconds
            : 0;

        final hrValues = pts.map((p) => p.heartRate).toList();
        final sysValues = pts.map((p) => p.systolic).toList();
        final diaValues = pts.map((p) => p.diastolic).toList();
        final spo2Values = pts.map((p) => p.spo2).toList();

        double avg(List<double> v) =>
            v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

        await VitalsService.saveSessionSummary(
          token: token,
          sessionData: {
            'sessionId': savedSessionId,
            'duration': duration,
            'dataPointCount': pts.length,
            'avgHeartRate': avg(hrValues),
            'maxHeartRate': hrValues.reduce(math.max),
            'minHeartRate': hrValues.reduce(math.min),
            'avgSystolic': avg(sysValues),
            'maxSystolic': sysValues.reduce(math.max),
            'avgDiastolic': avg(diaValues),
            'avgSpO2': avg(spo2Values),
            'minSpO2': spo2Values.reduce(math.min),
            'alerts': _alerts
                .map((a) => {
                      'type': a.type,
                      'severity': a.severity,
                      'message': a.message,
                      'vital': a.vital,
                      'currentValue': a.currentValue,
                      'predictedValue': a.predictedValue,
                      'timestamp': a.timestamp,
                    })
                .toList(),
            'location': _sessionLocation,
          },
        );
      } catch (_) {
        // Best effort — don't block UI on save failure
      }
    }

    _isMonitoring = false;
    _sessionId = null;
    _sessionStart = null;
    _urgentMode = false;
    onNewAlerts = null;
    _allDataPoints.clear();
    _firedLocalAlertKeys.clear();
    notifyListeners();
  }

  void clearAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }
}
