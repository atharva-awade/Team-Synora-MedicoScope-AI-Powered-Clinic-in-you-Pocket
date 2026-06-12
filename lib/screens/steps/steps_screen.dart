import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/services/health_connect_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// The different UI states this screen can be in.
enum _ScreenState {
  checkingAvailability,
  loading,
  healthConnectNotInstalled,
  permissionDenied,
  loaded,
  error,
}

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen>
    with TickerProviderStateMixin {
  _ScreenState _state = _ScreenState.checkingAvailability;
  String _errorMessage = '';

  int _todaySteps = 0;
  double _calories = 0;
  double _distanceKm = 0;
  double _avgHeartRate = 0;
  List<DailySteps> _weeklySteps = [];

  late AnimationController _ringController;
  late AnimationController _floatController;

  static const int _dailyGoal = 8000;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    // Defer platform calls until after first frame so widget tree is fully ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFlow());
  }

  @override
  void dispose() {
    _ringController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  // ── Init flow ──────────────────────────────────────────────────────────────

  Future<void> _initFlow() async {
    setState(() => _state = _ScreenState.checkingAvailability);

    // Step 1 — Check Health Connect availability
    HCAvailability availability;
    try {
      availability = await HealthConnectService.getAvailability();
    } catch (e) {
      _setError('Could not check Health Connect:\n$e');
      return;
    }

    if (availability == HCAvailability.notInstalled) {
      setState(() => _state = _ScreenState.healthConnectNotInstalled);
      return;
    }
    if (availability == HCAvailability.unsupported) {
      _setError('Health Connect is only available on Android.');
      return;
    }

    // Step 2 — Check / request permissions
    setState(() => _state = _ScreenState.loading);
    bool hasPerms;
    try {
      hasPerms = await HealthConnectService.hasPermissions();
    } catch (_) {
      hasPerms = false;
    }

    if (!hasPerms) {
      try {
        hasPerms = await HealthConnectService.requestPermissions();
      } catch (e) {
        _setError('Permission request failed:\n$e');
        return;
      }
    }

    if (!hasPerms) {
      setState(() => _state = _ScreenState.permissionDenied);
      return;
    }

    // Step 3 — Load data
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _state = _ScreenState.loading);
    try {
      final results = await Future.wait([
        HealthConnectService.getTodaySteps(),
        HealthConnectService.getTodayCalories(),
        HealthConnectService.getTodayDistance(),
        HealthConnectService.getTodayAvgHeartRate(),
        HealthConnectService.getWeeklySteps(days: 7),
      ]);

      if (!mounted) return;

      setState(() {
        _todaySteps = results[0] as int;
        _calories = results[1] as double;
        _distanceKm = (results[2] as double) / 1000.0; // m → km
        _avgHeartRate = results[3] as double;
        _weeklySteps = results[4] as List<DailySteps>;
        _state = _ScreenState.loaded;
      });
      _ringController.forward(from: 0);
    } catch (e) {
      _setError(e.toString());
    }
  }

  void _setError(String msg) =>
      setState(() { _state = _ScreenState.error; _errorMessage = msg; });

  double get _progress => (_todaySteps / _dailyGoal).clamp(0.0, 1.0);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
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
              _buildHeader(isDark),
              Expanded(child: _buildBody(isDark)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    final busy = _state == _ScreenState.checkingAvailability ||
        _state == _ScreenState.loading;
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios),
            color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF43E97B), Color(0xFF38F9D7)]),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(Icons.directions_walk_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Activity Tracker',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.darkTextLight
                            : AppTheme.textDark)),
                Text('Steps · Calories · Distance',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextGray
                            : AppTheme.textGray)),
              ],
            ),
          ),
          IconButton(
            onPressed: busy ? null : _initFlow,
            icon: Icon(Icons.refresh_rounded,
                color: isDark ? AppTheme.darkTextGray : AppTheme.textGray),
          ),
        ],
      ),
    );
  }

  // ── Body router ────────────────────────────────────────────────────────────

  Widget _buildBody(bool isDark) {
    switch (_state) {
      case _ScreenState.checkingAvailability:
        return _buildSpinner('Checking Health Connect…', isDark);
      case _ScreenState.loading:
        return _buildSpinner('Syncing activity data…', isDark);
      case _ScreenState.healthConnectNotInstalled:
        return _buildNotInstalled(isDark);
      case _ScreenState.permissionDenied:
        return _buildPermissionDenied(isDark);
      case _ScreenState.loaded:
        return _buildContent(isDark);
      case _ScreenState.error:
        return _buildError(isDark);
    }
  }

  // ── Spinner ────────────────────────────────────────────────────────────────

  Widget _buildSpinner(String msg, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Color(0xFF43E97B)),
            ),
          ),
          const SizedBox(height: 20),
          Text(msg,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.darkTextGray : AppTheme.textGray)),
        ],
      ),
    );
  }

  // ── Not installed ──────────────────────────────────────────────────────────

  Widget _buildNotInstalled(bool isDark) {
    return _stateBody(
      isDark: isDark,
      icon: Icons.health_and_safety_outlined,
      colors: const [Color(0xFF4285F4), Color(0xFF34A853)],
      title: 'Health Connect Required',
      body:
          'Health Connect is Google\'s health data hub.\nIt receives steps from your Noise app (connected to your smartwatch) and shares them with MedicoScope.',
      primaryLabel: 'Install Health Connect',
      primaryIcon: Icons.open_in_new_rounded,
      primaryColors: const [Color(0xFF4285F4), Color(0xFF34A853)],
      onPrimary: () => launchUrl(
        Uri.parse(
            'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata'),
        mode: LaunchMode.externalApplication,
      ),
      secondaryLabel: 'Retry after installing',
      onSecondary: _initFlow,
      chain: true,
    );
  }

  // ── Permission denied ──────────────────────────────────────────────────────

  Widget _buildPermissionDenied(bool isDark) {
    return _stateBody(
      isDark: isDark,
      icon: Icons.shield_outlined,
      colors: const [Color(0xFFFF9A9E), Color(0xFFFAD0C4)],
      title: 'Permission Needed',
      body:
          'MedicoScope needs permission to read your Health Connect data.\n\nTap below to open the Health Connect permission screen and allow access to Steps, Calories, Distance, and Heart Rate.',
      primaryLabel: 'Grant Permission',
      primaryIcon: Icons.lock_open_rounded,
      primaryColors: const [Color(0xFF43E97B), Color(0xFF38F9D7)],
      onPrimary: () async {
        final granted = await HealthConnectService.requestPermissions();
        if (granted) {
          await _loadData();
        } else {
          setState(() => _state = _ScreenState.permissionDenied);
        }
      },
      hint:
          'If the dialog doesn\'t appear, open Health Connect → App Permissions → MedicoScope and enable manually.',
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError(bool isDark) {
    return _stateBody(
      isDark: isDark,
      icon: Icons.error_outline_rounded,
      colors: const [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
      title: 'Something Went Wrong',
      body: _errorMessage,
      primaryLabel: 'Try Again',
      primaryIcon: Icons.refresh_rounded,
      primaryColors: const [Color(0xFF667EEA), Color(0xFF764BA2)],
      onPrimary: _initFlow,
    );
  }

  // ── Reusable state body ────────────────────────────────────────────────────

  Widget _stateBody({
    required bool isDark,
    required IconData icon,
    required List<Color> colors,
    required String title,
    required String body,
    required String primaryLabel,
    required IconData primaryIcon,
    required List<Color> primaryColors,
    required VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    String? hint,
    bool chain = false,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _stateIcon(icon, colors),
          const SizedBox(height: 28),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color:
                      isDark ? AppTheme.darkTextLight : AppTheme.textDark)),
          const SizedBox(height: 14),
          Text(body,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark
                      ? AppTheme.darkTextGray
                      : AppTheme.textGray)),
          if (chain) ...[
            const SizedBox(height: 16),
            _chainBadge(),
          ],
          const SizedBox(height: 32),
          _primaryButton(
              label: primaryLabel,
              icon: primaryIcon,
              colors: primaryColors,
              onTap: onPrimary),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 14),
            _secondaryButton(label: secondaryLabel, onTap: onSecondary),
          ],
          if (hint != null) ...[
            const SizedBox(height: 16),
            Text(hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: isDark
                        ? AppTheme.darkTextDim
                        : AppTheme.textLight)),
          ],
        ],
      ),
    );
  }

  // ── Main content (data loaded) ─────────────────────────────────────────────

  Widget _buildContent(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLarge, vertical: 4),
      child: Column(
        children: [
          _buildProgressRing(isDark)
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
          const SizedBox(height: 24),
          _buildStatGrid(isDark)
              .animate()
              .fadeIn(delay: 300.ms, duration: 500.ms)
              .slideY(begin: 0.15, end: 0),
          const SizedBox(height: 24),
          _buildWeeklyChart(isDark)
              .animate()
              .fadeIn(delay: 500.ms, duration: 500.ms)
              .slideY(begin: 0.15, end: 0),
          const SizedBox(height: 24),
          _buildSourceChain(isDark)
              .animate()
              .fadeIn(delay: 700.ms, duration: 500.ms),
          const SizedBox(height: AppTheme.spacingXLarge),
        ],
      ),
    );
  }

  // ── Progress Ring ──────────────────────────────────────────────────────────

  Widget _buildProgressRing(bool isDark) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final dy = math.sin(_floatController.value * math.pi) * 5;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        borderRadius: AppTheme.radiusLarge,
        child: Column(
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _ringController,
                    builder: (_, __) {
                      final t = CurvedAnimation(
                              parent: _ringController,
                              curve: Curves.easeOutCubic)
                          .value;
                      return CustomPaint(
                        size: const Size(200, 200),
                        painter: _RingPainter(
                            progress: _progress * t, isDark: isDark),
                      );
                    },
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmtK(_todaySteps),
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          color: isDark
                              ? AppTheme.darkTextLight
                              : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('steps today',
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppTheme.darkTextGray
                                  : AppTheme.textGray)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color(0xFF43E97B),
                            Color(0xFF38F9D7)
                          ]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${(_progress * 100).toStringAsFixed(0)}% of goal',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_rounded,
                    size: 15,
                    color:
                        isDark ? AppTheme.darkTextGray : AppTheme.textGray),
                const SizedBox(width: 5),
                Text('Daily goal: ${_fmtK(_dailyGoal)} steps',
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.darkTextGray
                            : AppTheme.textGray)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Stat Grid ──────────────────────────────────────────────────────────────

  Widget _buildStatGrid(bool isDark) {
    return Row(
      children: [
        _statCard(
          icon: Icons.local_fire_department_rounded,
          label: 'Calories',
          value: _calories > 0 ? '${_calories.toStringAsFixed(0)} kcal' : '--',
          colors: const [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _statCard(
          icon: Icons.route_rounded,
          label: 'Distance',
          value: _distanceKm > 0
              ? '${_distanceKm.toStringAsFixed(2)} km'
              : '--',
          colors: const [Color(0xFF667EEA), Color(0xFF764BA2)],
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _statCard(
          icon: Icons.favorite_rounded,
          label: 'Avg HR',
          value: _avgHeartRate > 0
              ? '${_avgHeartRate.toStringAsFixed(0)} bpm'
              : '--',
          colors: const [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> colors,
    required bool isDark,
  }) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        borderRadius: AppTheme.radiusMedium,
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.darkTextGray
                        : AppTheme.textGray)),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppTheme.darkTextLight
                        : AppTheme.textDark),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── Weekly Chart ───────────────────────────────────────────────────────────

  Widget _buildWeeklyChart(bool isDark) {
    final maxSteps = _weeklySteps.isEmpty
        ? 1
        : _weeklySteps.map((d) => d.steps).reduce(math.max);
    final maxY = math.max(maxSteps, _dailyGoal);
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      borderRadius: AppTheme.radiusMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF43E97B), Color(0xFF38F9D7)]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text('7-Day History',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.darkTextLight
                          : AppTheme.textDark)),
              const Spacer(),
              Text('Goal: ${_fmtK(_dailyGoal)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextGray
                          : AppTheme.textGray)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_weeklySteps.length, (i) {
                final day = _weeklySteps[i];
                final ratio = maxY == 0 ? 0.0 : day.steps / maxY;
                final isToday = i == _weeklySteps.length - 1;
                final label = dayLabels[day.date.weekday - 1];
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isToday)
                        Text(_fmtK(day.steps),
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF43E97B))),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 3),
                          child: AnimatedBuilder(
                            animation: _ringController,
                            builder: (_, __) {
                              final t = CurvedAnimation(
                                      parent: _ringController,
                                      curve: Curves.easeOutCubic)
                                  .value;
                              return FractionallySizedBox(
                                alignment: Alignment.bottomCenter,
                                heightFactor: ratio * t,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: isToday
                                          ? const [
                                              Color(0xFF43E97B),
                                              Color(0xFF38F9D7)
                                            ]
                                          : [
                                              const Color(0xFF43E97B)
                                                  .withValues(alpha: 0.35),
                                              const Color(0xFF38F9D7)
                                                  .withValues(alpha: 0.35),
                                            ],
                                    ),
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            top: Radius.circular(6)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(label,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isToday
                                  ? const Color(0xFF43E97B)
                                  : isDark
                                      ? AppTheme.darkTextGray
                                      : AppTheme.textGray)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Source chain ───────────────────────────────────────────────────────────

  Widget _buildSourceChain(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      borderRadius: AppTheme.radiusMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data Flow',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? AppTheme.darkTextLight : AppTheme.textDark)),
          const SizedBox(height: 12),
          _chainBadge(),
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _chainBadge() {
    const items = [
      (Icons.watch_rounded, 'Smartwatch'),
      (Icons.noise_control_off_rounded, 'Noise App'),
      (Icons.fitness_center_rounded, 'Google Fit'),
      (Icons.favorite_rounded, 'Health Connect'),
      (Icons.medical_services_rounded, 'MedicoScope'),
    ];
    const green = Color(0xFF43E97B);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: green.withValues(alpha: 0.4), width: 1),
                ),
                child: Icon(items[i].$1, color: green, size: 16),
              ),
              const SizedBox(height: 4),
              Text(items[i].$2,
                  style:
                      const TextStyle(fontSize: 7, color: Colors.grey)),
            ],
          ),
          if (i < items.length - 1)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 10, color: Colors.grey),
            ),
        ]
      ],
    );
  }

  Widget _stateIcon(IconData icon, List<Color> colors) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: colors[0].withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 50),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: [
            BoxShadow(
                color: colors[0].withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _secondaryButton(
      {required String label, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
              color: const Color(0xFF43E97B).withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFF43E97B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  String _fmtK(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : n.toString();
}

// ── Ring Painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  _RingPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;
    const sw = 18.0;

    // Background track
    canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = isDark
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFE0E0E0)
          ..strokeWidth = sw
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: centre, radius: radius);
    final sweep = 2 * math.pi * progress;

    // Gradient arc
    canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..shader = const SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: 3 * math.pi / 2,
            colors: [Color(0xFF43E97B), Color(0xFF38F9D7), Color(0xFF43E97B)],
          ).createShader(rect)
          ..strokeWidth = sw
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    // Glow dot at arc tip
    final angle = -math.pi / 2 + sweep;
    final tip = Offset(
        centre.dx + radius * math.cos(angle),
        centre.dy + radius * math.sin(angle));
    canvas.drawCircle(
        tip,
        12,
        Paint()
          ..color = const Color(0xFF43E97B).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(tip, 6, Paint()..color = const Color(0xFF38F9D7));
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.progress != progress || o.isDark != isDark;
}
