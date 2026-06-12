import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/providers/vitals_provider.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/services/api_service.dart';
import 'package:medicoscope/services/disease_result_pipeline.dart';
import 'package:medicoscope/core/constants/api_constants.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen>
    with TickerProviderStateMixin {
  String _linkedDoctorId = '';
  String _emergencyContactName = '';
  String _emergencyContactPhone = '';
  double _latitude = 0.0;
  double _longitude = 0.0;
  String _locationName = 'Unknown';
  late AnimationController _pulseController;
  late AnimationController _graphAnimCtrl;

  // Track which alert types have already triggered SMS to avoid duplicates
  final Set<String> _smsTriggeredTypes = {};

  bool _infoReady = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _graphAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadPrerequisites();
  }

  /// Fetch patient info and location in parallel so the user can start fast.
  /// Each task has its own timeout so one slow call never blocks the button.
  Future<void> _loadPrerequisites() async {
    try {
      await Future.wait([
        _fetchPatientInfo().timeout(const Duration(seconds: 8), onTimeout: () {}),
        _fetchLocation().timeout(const Duration(seconds: 8), onTimeout: () {}),
      ]);
    } catch (_) {
      // Never block — proceed with defaults
    }
    _infoReady = true;
    if (mounted) setState(() {});
  }

  Future<void> _fetchPatientInfo() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final api = ApiService(token: authProvider.token);
      // Run doctor + profile calls in parallel, each with a timeout
      final results = await Future.wait([
        api.get(ApiConstants.patientDoctor).timeout(
              const Duration(seconds: 6),
              onTimeout: () => <String, dynamic>{},
            ),
        api.get(ApiConstants.profile).timeout(
              const Duration(seconds: 6),
              onTimeout: () => <String, dynamic>{},
            ),
      ]);
      final doctorRes = results[0];
      final profileRes = results[1];

      if (doctorRes['doctor'] != null) {
        _linkedDoctorId =
            doctorRes['doctor']['_id'] ?? doctorRes['doctor']['id'] ?? '';
      }
      if (profileRes['patient'] != null) {
        final ec = profileRes['patient']['emergencyContact'];
        if (ec != null) {
          _emergencyContactName = ec['name'] ?? '';
          _emergencyContactPhone = ec['phone'] ?? '';
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      // Reverse geocode to get a readable address
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 3), onTimeout: () => []);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[
            if (p.subLocality?.isNotEmpty == true) p.subLocality!,
            if (p.locality?.isNotEmpty == true) p.locality!,
            if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea!,
          ];
          _locationName = parts.isNotEmpty ? parts.join(', ') : 'Unknown';
        }
      } catch (_) {
        _locationName =
            '${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}';
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _startMonitoring() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final vitalsProvider = Provider.of<VitalsProvider>(context, listen: false);

    // Set up SMS callback for new alerts
    vitalsProvider.onNewAlerts = _handleNewAlerts;
    _smsTriggeredTypes.clear();

    vitalsProvider.startMonitoring(
      patientId: authProvider.user?.id ?? 'anonymous',
      patientName: authProvider.user?.name ?? 'Patient',
      doctorId: _linkedDoctorId,
      emergencyContactName: _emergencyContactName,
      emergencyContactPhone: _emergencyContactPhone,
      location: _locationName,
      latitude: _latitude,
      longitude: _longitude,
    );
  }

  void _handleNewAlerts(List<VitalAlert> newAlerts) {
    for (final alert in newAlerts) {
      // Only send SMS once per alert type per session
      if (_smsTriggeredTypes.contains(alert.type)) continue;
      if (alert.emergencyContactPhone.isEmpty) continue;

      _smsTriggeredTypes.add(alert.type);
      _sendEmergencySms(alert);
    }
  }

  Future<void> _sendEmergencySms(VitalAlert alert) async {
    final mapsLink = (_latitude != 0.0 && _longitude != 0.0)
        ? 'https://www.google.com/maps?q=$_latitude,$_longitude'
        : 'Location unavailable';

    final body = Uri.encodeComponent(
      'MEDICOSCOPE ALERT\n'
      'Patient: ${alert.patientName}\n'
      'Alert: ${alert.message}\n'
      'Severity: ${alert.severity.toUpperCase()}\n'
      'Time: ${alert.timestamp}\n'
      'Location: $_locationName\n'
      'Map: $mapsLink',
    );

    final smsUri = Uri.parse('sms:${alert.emergencyContactPhone}?body=$body');

    try {
      await launchUrl(smsUri);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _graphAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final vitals = Provider.of<VitalsProvider>(context);
    final lang = Provider.of<LocaleProvider>(context).languageCode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.darkBackgroundGradient
              : AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(isDark, vitals, lang),

              // Content
              Expanded(
                child: vitals.isMonitoring
                    ? _buildMonitoringView(isDark, vitals, lang)
                    : _buildStartView(isDark, vitals, lang),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, VitalsProvider vitals, String lang) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (vitals.isMonitoring) {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                vitals.stopMonitoring(token: auth.token);
              }
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_ios),
            color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(
              Icons.monitor_heart_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.get('vitals_monitor', lang),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                  ),
                ),
                Text(
                  vitals.isMonitoring
                      ? AppStrings.get('live_monitoring_active', lang)
                      : AppStrings.get('real_time_health', lang),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                  ),
                ),
              ],
            ),
          ),
          if (vitals.isMonitoring)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent
                            .withOpacity(0.4 + _pulseController.value * 0.4),
                        blurRadius: 6 + _pulseController.value * 6,
                        spreadRadius: _pulseController.value * 3,
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStartView(bool isDark, VitalsProvider vitals, String lang) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLarge),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Hero illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 56,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.05, duration: 1500.ms),

          const SizedBox(height: 32),

          Text(
            AppStrings.get('real_time_vitals', lang),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 500.ms),

          const SizedBox(height: 12),

          Text(
            AppStrings.get('vitals_full_desc', lang),
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

          const SizedBox(height: 32),

          // Metric previews
          Row(
            children: [
              _buildMetricPreview(
                AppStrings.get('heart_rate', lang),
                Icons.favorite_rounded,
                AppStrings.get('bpm', lang),
                const [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
                isDark,
              ),
              const SizedBox(width: 12),
              _buildMetricPreview(
                AppStrings.get('blood_pressure', lang),
                Icons.speed_rounded,
                AppStrings.get('mmhg', lang),
                const [Color(0xFF667EEA), Color(0xFF764BA2)],
                isDark,
              ),
              const SizedBox(width: 12),
              _buildMetricPreview(
                AppStrings.get('spo2', lang),
                Icons.air_rounded,
                '%',
                const [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                isDark,
              ),
            ],
          ).animate().fadeIn(delay: 400.ms, duration: 500.ms),

          const SizedBox(height: 40),

          // Start button
          GestureDetector(
            onTap: (vitals.isStarting || !_infoReady) ? null : _startMonitoring,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: (vitals.isStarting || !_infoReady)
                    ? LinearGradient(
                        colors: [Colors.grey.shade400, Colors.grey.shade500],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [
                  if (!vitals.isStarting && _infoReady)
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (vitals.isStarting || !_infoReady)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  else
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    !_infoReady
                        ? AppStrings.get('preparing', lang)
                        : vitals.isStarting
                            ? AppStrings.get('initializing', lang)
                            : AppStrings.get('start_monitoring', lang),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 600.ms, duration: 500.ms),

          if (vitals.error != null) ...[
            const SizedBox(height: 16),
            Text(
              vitals.error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMetricPreview(
    String label,
    IconData icon,
    String unit,
    List<Color> colors,
    bool isDark,
  ) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: AppTheme.radiusMedium,
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? AppTheme.darkTextDim : AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringView(bool isDark, VitalsProvider vitals, String lang) {
    return Column(
      children: [
        // Live metric cards row
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
          child: Row(
            children: [
              _buildLiveMetric(
                AppStrings.get('hr', lang),
                vitals.currentHR.toStringAsFixed(0),
                AppStrings.get('bpm', lang),
                const [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
                Icons.favorite_rounded,
                isDark,
              ),
              const SizedBox(width: 8),
              _buildLiveMetric(
                AppStrings.get('bp', lang),
                '${vitals.currentSystolic.toStringAsFixed(0)}/${vitals.currentDiastolic.toStringAsFixed(0)}',
                AppStrings.get('mmhg', lang),
                const [Color(0xFF667EEA), Color(0xFF764BA2)],
                Icons.speed_rounded,
                isDark,
              ),
              const SizedBox(width: 8),
              _buildLiveMetric(
                AppStrings.get('spo2', lang),
                vitals.currentSpO2.toStringAsFixed(1),
                '%',
                const [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                Icons.air_rounded,
                isDark,
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: 12),

        // Graphs
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
            child: Column(
              children: [
                _buildGraphCard(
                  AppStrings.get('heart_rate', lang),
                  AppStrings.get('bpm', lang),
                  vitals.dataPoints,
                  (p) => p.heartRate,
                  const [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
                  40,
                  160,
                  isDark,
                  lang: lang,
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: 12),

                _buildGraphCard(
                  AppStrings.get('blood_pressure', lang),
                  AppStrings.get('mmhg', lang),
                  vitals.dataPoints,
                  null,
                  const [Color(0xFF667EEA), Color(0xFF764BA2)],
                  60,
                  180,
                  isDark,
                  isBP: true,
                  lang: lang,
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                const SizedBox(height: 12),

                _buildGraphCard(
                  AppStrings.get('spo2', lang),
                  '%',
                  vitals.dataPoints,
                  (p) => p.spo2,
                  const [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                  88,
                  100,
                  isDark,
                  lang: lang,
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                const SizedBox(height: 12),

                // Alerts section
                if (vitals.alerts.isNotEmpty)
                  _buildAlertsSection(isDark, vitals, lang)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 12),

                // Stop button
                GestureDetector(
                  onTap: () async {
                    final auth =
                        Provider.of<AuthProvider>(context, listen: false);
                    await vitals.stopMonitoring(token: auth.token);
                    if (mounted) {
                      await DiseaseResultPipeline.awardCoinsOnly(
                        context,
                        modality: 'og_vitals_session',
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      border:
                          Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.stop_rounded,
                            color: Colors.redAccent, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.get('stop_monitoring', lang),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveMetric(
    String label,
    String value,
    String unit,
    List<Color> gradient,
    IconData icon,
    bool isDark,
  ) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        borderRadius: AppTheme.radiusMedium,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: gradient[0], size: 14),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? AppTheme.darkTextDim : AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphCard(
    String title,
    String unit,
    List<VitalDataPoint> points,
    double Function(VitalDataPoint)? extractor,
    List<Color> gradient,
    double minY,
    double maxY,
    bool isDark, {
    bool isBP = false,
    String lang = 'en',
  }) {
    // Rolling window: show only last 40 points so graph scrolls
    final displayPoints =
        points.length > 40 ? points.sublist(points.length - 40) : points;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: AppTheme.radiusMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                ),
              ),
              const Spacer(),
              if (displayPoints.isNotEmpty) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: gradient[0],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  AppStrings.get('live', lang),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: gradient[0],
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppTheme.darkTextDim : AppTheme.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: displayPoints.isEmpty
                ? Center(
                    child: Text(
                      AppStrings.get('waiting_for_data', lang),
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark ? AppTheme.darkTextDim : AppTheme.textLight,
                      ),
                    ),
                  )
                : AnimatedBuilder(
                    animation: _graphAnimCtrl,
                    builder: (context, _) => CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: _VitalsGraphPainter(
                        points: displayPoints,
                        extractor: extractor,
                        gradient: gradient,
                        minY: minY,
                        maxY: maxY,
                        isDark: isDark,
                        isBP: isBP,
                        animValue: _graphAnimCtrl.value,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(bool isDark, VitalsProvider vitals, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Text(
              AppStrings.get('preventive_alerts', lang),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...vitals.alerts.map((alert) => _buildAlertCard(alert, isDark)),
      ],
    );
  }

  Widget _buildAlertCard(VitalAlert alert, bool isDark) {
    final isCritical = alert.severity == 'critical';
    final alertColor = isCritical ? Colors.redAccent : Colors.amber;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: alertColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCritical ? Icons.emergency_rounded : Icons.warning_amber_rounded,
            color: alertColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: alertColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alert.severity.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: alertColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatAlertTime(alert.timestamp),
                      style: TextStyle(
                        fontSize: 9,
                        color:
                            isDark ? AppTheme.darkTextDim : AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAlertTime(String isoTimestamp) {
    try {
      final dt = DateTime.parse(isoTimestamp).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ── Custom Graph Painter ───────────────────────────────────────────────────

class _VitalsGraphPainter extends CustomPainter {
  final List<VitalDataPoint> points;
  final double Function(VitalDataPoint)? extractor;
  final List<Color> gradient;
  final double minY;
  final double maxY;
  final bool isDark;
  final bool isBP;
  final double animValue; // 0→1 continuous loop

  _VitalsGraphPainter({
    required this.points,
    this.extractor,
    required this.gradient,
    required this.minY,
    required this.maxY,
    required this.isDark,
    this.isBP = false,
    this.animValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final range = maxY - minY;

    // Grid lines
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Subtle sweep scan line (moves left→right based on animValue)
    final scanX = w * animValue;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          gradient[0].withOpacity(0.0),
          gradient[0].withOpacity(0.08),
          gradient[0].withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(scanX - 20, 0, 40, h));
    canvas.drawRect(Rect.fromLTWH(scanX - 20, 0, 40, h), scanPaint);

    if (isBP) {
      _drawLine(canvas, size, points, (p) => p.systolic, range, gradient);
      _drawLine(canvas, size, points, (p) => p.diastolic, range,
          [gradient[1].withOpacity(0.6), gradient[0].withOpacity(0.6)]);
      _drawAreaFill(canvas, size, points, (p) => p.systolic, (p) => p.diastolic,
          range, gradient);
    } else {
      _drawLine(canvas, size, points, extractor!, range, gradient);
      _drawAreaFillSingle(canvas, size, points, extractor!, range, gradient);
    }
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    List<VitalDataPoint> pts,
    double Function(VitalDataPoint) getValue,
    double range,
    List<Color> colors,
  ) {
    if (pts.length < 2) return;

    final w = size.width;
    final h = size.height;
    final step = w / (pts.length - 1).clamp(1, double.infinity);

    // Build main path
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final x = i * step;
      final val = getValue(pts[i]);
      final y = h - ((val - minY) / range * h);
      if (i == 0) {
        path.moveTo(x, y.clamp(0, h));
      } else {
        final prevX = (i - 1) * step;
        final prevVal = getValue(pts[i - 1]);
        final prevY = h - ((prevVal - minY) / range * h);
        final midX = (prevX + x) / 2;
        path.cubicTo(
            midX, prevY.clamp(0, h), midX, y.clamp(0, h), x, y.clamp(0, h));
      }
    }

    // Main line
    final linePaint = Paint()
      ..shader =
          LinearGradient(colors: colors).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Bright trail on last 6 segments
    if (pts.length > 2) {
      final trailCount = pts.length < 6 ? pts.length : 6;
      final trailStart = pts.length - trailCount;
      final trailPath = Path();
      for (int i = trailStart; i < pts.length; i++) {
        final x = i * step;
        final val = getValue(pts[i]);
        final y = (h - ((val - minY) / range * h)).clamp(0.0, h);
        if (i == trailStart) {
          trailPath.moveTo(x, y);
        } else {
          final prevX = (i - 1) * step;
          final prevVal = getValue(pts[i - 1]);
          final prevY = (h - ((prevVal - minY) / range * h)).clamp(0.0, h);
          final midX = (prevX + x) / 2;
          trailPath.cubicTo(midX, prevY, midX, y, x, y);
        }
      }
      final trailPaint = Paint()
        ..color = colors[0]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(trailPath, trailPaint);

      // Glow trail
      final glowTrailPaint = Paint()
        ..color = colors[0].withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(trailPath, glowTrailPaint);
    }

    // Pulsating dot at latest point
    final lastVal = getValue(pts.last);
    final lastY = (h - ((lastVal - minY) / range * h)).clamp(0.0, h);
    final lastX = (pts.length - 1) * step;
    final pulse = (1 - (animValue * 2 - 1).abs()); // 0→1→0 triangle wave

    // Outer glow (pulsating)
    final glowPaint = Paint()
      ..color = colors[0].withOpacity(0.15 + pulse * 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + pulse * 8);
    canvas.drawCircle(Offset(lastX, lastY), 6 + pulse * 6, glowPaint);

    // Solid dot
    canvas.drawCircle(
        Offset(lastX, lastY), 3.5 + pulse * 1.5, Paint()..color = colors[0]);
    // White center
    canvas.drawCircle(Offset(lastX, lastY), 1.5, Paint()..color = Colors.white);
  }

  void _drawAreaFillSingle(
    Canvas canvas,
    Size size,
    List<VitalDataPoint> pts,
    double Function(VitalDataPoint) getValue,
    double range,
    List<Color> colors,
  ) {
    if (pts.length < 2) return;

    final w = size.width;
    final h = size.height;
    final step = w / (pts.length - 1).clamp(1, double.infinity);
    final path = Path();

    for (int i = 0; i < pts.length; i++) {
      final x = i * step;
      final val = getValue(pts[i]);
      final y = h - ((val - minY) / range * h);
      if (i == 0) {
        path.moveTo(x, y.clamp(0, h));
      } else {
        final prevX = (i - 1) * step;
        final prevVal = getValue(pts[i - 1]);
        final prevY = h - ((prevVal - minY) / range * h);
        final midX = (prevX + x) / 2;
        path.cubicTo(
            midX, prevY.clamp(0, h), midX, y.clamp(0, h), x, y.clamp(0, h));
      }
    }

    path.lineTo((pts.length - 1) * step, h);
    path.lineTo(0, h);
    path.close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors[0].withOpacity(0.15), colors[0].withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, areaPaint);
  }

  void _drawAreaFill(
    Canvas canvas,
    Size size,
    List<VitalDataPoint> pts,
    double Function(VitalDataPoint) getUpper,
    double Function(VitalDataPoint) getLower,
    double range,
    List<Color> colors,
  ) {
    if (pts.length < 2) return;

    final w = size.width;
    final h = size.height;
    final step = w / (pts.length - 1).clamp(1, double.infinity);
    final path = Path();

    for (int i = 0; i < pts.length; i++) {
      final x = i * step;
      final val = getUpper(pts[i]);
      final y = (h - ((val - minY) / range * h)).clamp(0.0, h);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    for (int i = pts.length - 1; i >= 0; i--) {
      final x = i * step;
      final val = getLower(pts[i]);
      final y = (h - ((val - minY) / range * h)).clamp(0.0, h);
      path.lineTo(x, y);
    }

    path.close();

    final areaPaint = Paint()..color = colors[0].withOpacity(0.1);
    canvas.drawPath(path, areaPaint);
  }

  @override
  bool shouldRepaint(covariant _VitalsGraphPainter oldDelegate) => true;
}
