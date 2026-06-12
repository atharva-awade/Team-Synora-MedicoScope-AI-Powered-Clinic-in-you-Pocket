import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/models/cardio_result.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';

class HeartResultsScreen extends StatefulWidget {
  final CardioResult result;

  const HeartResultsScreen({super.key, required this.result});

  @override
  State<HeartResultsScreen> createState() => _HeartResultsScreenState();
}

class _HeartResultsScreenState extends State<HeartResultsScreen>
    with TickerProviderStateMixin {
  // Phase 1: Progressive draw (play once)
  late AnimationController _hrDrawCtrl;
  late AnimationController _ecgDrawCtrl;
  late AnimationController _waveformDrawCtrl;

  // Phase 2: Continuous live sweep (loop forever)
  late AnimationController _hrSweepCtrl;
  late AnimationController _ecgSweepCtrl;

  bool _hrLive = false;
  bool _ecgLive = false;

  @override
  void initState() {
    super.initState();

    _hrDrawCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _ecgDrawCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _waveformDrawCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _hrSweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
    _ecgSweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    // When initial draw finishes, switch to continuous live sweep
    _hrDrawCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _hrLive = true);
        _hrSweepCtrl.repeat();
      }
    });
    _ecgDrawCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _ecgLive = true);
        _ecgSweepCtrl.repeat();
      }
    });

    // Stagger the initial draw animations
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _hrDrawCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _ecgDrawCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) _waveformDrawCtrl.forward();
    });
  }

  @override
  void dispose() {
    _hrDrawCtrl.dispose();
    _ecgDrawCtrl.dispose();
    _waveformDrawCtrl.dispose();
    _hrSweepCtrl.dispose();
    _ecgSweepCtrl.dispose();
    super.dispose();
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'HIGH':
        return const Color(0xFFFF5252);
      case 'MEDIUM':
        return const Color(0xFFFF9800);
      case 'LOW':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final lang = Provider.of<LocaleProvider>(context).languageCode;
    final result = widget.result;
    final sevColor = _severityColor(result.severity);

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
              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSmall,
                  vertical: AppTheme.spacingSmall,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios, size: 20),
                      color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    ),
                    Text(
                      AppStrings.get('heart_analysis', lang),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable Content ──
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMedium,
                    0,
                    AppTheme.spacingMedium,
                    AppTheme.spacingXLarge,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Prediction + BPM row ──
                      Row(
                        children: [
                          // Prediction card
                          Expanded(
                            flex: 3,
                            child: GlassCard(
                              padding: const EdgeInsets.all(AppTheme.spacingMedium),
                              child: Column(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: sevColor.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.favorite_rounded,
                                      color: sevColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    result.prediction,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: sevColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      result.severity,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: sevColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms)
                                .scale(begin: const Offset(0.9, 0.9)),
                          ),
                          const SizedBox(width: AppTheme.spacingSmall),
                          // BPM card
                          Expanded(
                            flex: 2,
                            child: GlassCard(
                              padding: const EdgeInsets.all(AppTheme.spacingMedium),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.monitor_heart_rounded,
                                    color: Color(0xFFFF5252),
                                    size: 28,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    result.avgHeartRate.toStringAsFixed(0),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFF5252),
                                      height: 1,
                                    ),
                                  ),
                                  Text(
                                    AppStrings.get('bpm', lang),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                                    ),
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 200.ms, duration: 500.ms)
                                .scale(begin: const Offset(0.9, 0.9)),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppTheme.spacingMedium),

                      // ── Heart Rate Over Time (Live sweep) ──
                      if (result.heartRateData.isNotEmpty) ...[
                        Row(
                          children: [
                            _sectionTitle(AppStrings.get('heart_rate_over_time', lang), isDark),
                            const Spacer(),
                            if (_hrLive) _liveBadge(),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingSmall),
                        GlassCard(
                          padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
                          child: SizedBox(
                            height: 200,
                            child: AnimatedBuilder(
                              animation: _hrLive ? _hrSweepCtrl : _hrDrawCtrl,
                              builder: (context, _) => _HeartRateChart(
                                data: result.heartRateData,
                                avgBpm: result.avgHeartRate,
                                isDark: isDark,
                                isLive: _hrLive,
                                progress: _hrLive
                                    ? _hrSweepCtrl.value
                                    : _hrDrawCtrl.value,
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 400.ms),
                        const SizedBox(height: AppTheme.spacingMedium),
                      ],

                      // ── ECG Signal (Animated sweep) ──
                      if (result.ecgData.isNotEmpty) ...[
                        _sectionTitle(AppStrings.get('ecg_signal', lang), isDark),
                        const SizedBox(height: AppTheme.spacingSmall),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1117),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            border: Border.all(
                              color: const Color(0xFF00FF00).withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ECG label row
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF00FF00),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      AppStrings.get('ecg', lang),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF00FF00),
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_ecgLive) _liveBadge(),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 160,
                                child: AnimatedBuilder(
                                  animation: _ecgLive
                                      ? _ecgSweepCtrl
                                      : _ecgDrawCtrl,
                                  builder: (context, _) => _EcgChart(
                                    data: result.ecgData,
                                    isLive: _ecgLive,
                                    progress: _ecgLive
                                        ? _ecgSweepCtrl.value
                                        : _ecgDrawCtrl.value,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 700.ms, duration: 400.ms),
                        const SizedBox(height: AppTheme.spacingMedium),
                      ],

                      // ── Audio Waveform (Animated) ──
                      if (result.audioWaveform.amplitude.isNotEmpty) ...[
                        _sectionTitle(AppStrings.get('audio_waveform', lang), isDark),
                        const SizedBox(height: AppTheme.spacingSmall),
                        GlassCard(
                          padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
                          child: SizedBox(
                            height: 140,
                            child: AnimatedBuilder(
                              animation: _waveformDrawCtrl,
                              builder: (context, _) => _WaveformChart(
                                waveform: result.audioWaveform,
                                isDark: isDark,
                                progress: _waveformDrawCtrl.value,
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 1000.ms, duration: 400.ms),
                        const SizedBox(height: AppTheme.spacingMedium),
                      ],

                      // ── Clinical Info ──
                      GlassCard(
                        padding: const EdgeInsets.all(AppTheme.spacingMedium),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF667EEA).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.medical_information_outlined,
                                    color: Color(0xFF667EEA),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  AppStrings.get('recommendation', lang),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              result.recommendation,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 1300.ms, duration: 500.ms)
                          .slideY(begin: 0.05, end: 0),

                      const SizedBox(height: AppTheme.spacingLarge),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _liveBadge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFFF5252),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5252).withOpacity(0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'LIVE',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFF5252),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
        ),
      ),
    );
  }
}

// ─── Heart Rate Line Chart (Draw → Live Sweep) ─────────────────────────────

class _HeartRateChart extends StatelessWidget {
  final List<HeartRatePoint> data;
  final double avgBpm;
  final bool isDark;
  final bool isLive;
  final double progress;

  const _HeartRateChart({
    required this.data,
    required this.avgBpm,
    required this.isDark,
    required this.isLive,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final allSpots = data
        .map((p) => FlSpot(p.time.toDouble(), p.bpm.toDouble()))
        .toList();

    final maxBpm = data.map((p) => p.bpm).reduce(max).toDouble();
    final minBpm = data.map((p) => p.bpm).reduce(min).toDouble();
    // If min == max (truly flat HR), open up the y-axis so the line is
    // visible centred — otherwise fl_chart renders a zero-height band.
    final bpmRange = maxBpm - minBpm;
    final yMin = (bpmRange < 1
            ? minBpm - 15
            : minBpm - 10)
        .clamp(0.0, double.infinity);
    final yMax = bpmRange < 1 ? maxBpm + 15 : maxBpm + 10;
    final xMin = allSpots.first.x;
    final xMax = allSpots.last.x;

    if (!isLive) {
      // ─ Phase 1: Progressive draw ─
      final visibleCount =
          (allSpots.length * progress).ceil().clamp(1, allSpots.length);
      final spots = allSpots.sublist(0, visibleCount);

      return LineChart(
        LineChartData(
          minY: yMin, maxY: yMax, minX: xMin, maxX: xMax,
          clipData: const FlClipData.all(),
          gridData: _grid(),
          titlesData: _titles(),
          borderData: FlBorderData(show: false),
          extraLinesData: _extraLines(showAvg: progress > 0.5),
          lineBarsData: [
            _line(spots, const Color(0xFFFF5252), 2.5,
                trailingDot: progress < 1.0),
          ],
          lineTouchData: LineTouchData(
            enabled: progress >= 1.0,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (s) => s
                  .map((sp) => LineTooltipItem('${sp.y.toInt()} BPM',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)))
                  .toList(),
            ),
          ),
        ),
        duration: Duration.zero,
      );
    }

    // ─ Phase 2: Live sweep ─
    final n = allSpots.length;
    // Sweep head with interpolation for smooth motion
    final exactPos = progress * (n - 1);
    final headIdx = exactPos.floor().clamp(0, n - 2);
    final frac = exactPos - headIdx;

    // Interpolated sweep-head point
    final interpX = allSpots[headIdx].x +
        frac * (allSpots[headIdx + 1].x - allSpots[headIdx].x);
    final interpY = allSpots[headIdx].y +
        frac * (allSpots[headIdx + 1].y - allSpots[headIdx].y);
    final sweepPt = FlSpot(interpX, interpY);

    // Fresh trace: start → sweep head (bright)
    final fresh = <FlSpot>[...allSpots.sublist(0, headIdx + 1), sweepPt];
    // Stale trace: sweep head → end (dim)
    final stale = <FlSpot>[sweepPt, ...allSpots.sublist(headIdx + 1)];

    return LineChart(
      LineChartData(
        minY: yMin, maxY: yMax, minX: xMin, maxX: xMax,
        clipData: const FlClipData.all(),
        gridData: _grid(),
        titlesData: _titles(),
        borderData: FlBorderData(show: false),
        extraLinesData: _extraLines(showAvg: true),
        lineBarsData: [
          if (stale.length > 1)
            _line(stale, const Color(0xFFFF5252).withOpacity(0.2), 1.5,
                trailingDot: false, showArea: false),
          _line(fresh, const Color(0xFFFF5252), 2.5, trailingDot: true),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
      duration: Duration.zero,
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color, double width,
      {bool trailingDot = false, bool showArea = true}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: width,
      dotData: FlDotData(
        show: trailingDot,
        getDotPainter: (spot, pct, bar, i) {
          if (i == spots.length - 1) {
            return FlDotCirclePainter(
                radius: 4,
                color: const Color(0xFFFF5252),
                strokeWidth: 2,
                strokeColor: Colors.white);
          }
          return FlDotCirclePainter(
              radius: 0, color: Colors.transparent,
              strokeWidth: 0, strokeColor: Colors.transparent);
        },
      ),
      belowBarData: BarAreaData(
        show: showArea,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
        ),
      ),
    );
  }

  FlGridData _grid() => FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 20,
        getDrawingHorizontalLine: (v) => FlLine(
          color: isDark ? Colors.white10 : Colors.black12,
          strokeWidth: 0.5,
        ),
      );

  FlTitlesData _titles() => FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, reservedSize: 32, interval: 20,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextDim : AppTheme.textLight)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, reservedSize: 22,
            getTitlesWidget: (v, meta) {
              if (v == meta.min || v == meta.max) return const SizedBox.shrink();
              return Text('${v.toInt()}s',
                  style: TextStyle(fontSize: 9, color: isDark ? AppTheme.darkTextDim : AppTheme.textLight));
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      );

  ExtraLinesData _extraLines({required bool showAvg}) => ExtraLinesData(
        horizontalLines: [
          HorizontalLine(y: 60, color: const Color(0xFF4CAF50).withOpacity(0.2),
              strokeWidth: 0.8, dashArray: [4, 4]),
          HorizontalLine(y: 100, color: const Color(0xFF4CAF50).withOpacity(0.2),
              strokeWidth: 0.8, dashArray: [4, 4]),
          if (showAvg)
            HorizontalLine(
              y: avgBpm,
              color: const Color(0xFFFF9800).withOpacity(0.5),
              strokeWidth: 1, dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true, alignment: Alignment.topRight,
                style: const TextStyle(fontSize: 9, color: Color(0xFFFF9800), fontWeight: FontWeight.w600),
                labelResolver: (_) => 'Avg ${avgBpm.toStringAsFixed(0)}',
              ),
            ),
        ],
      );
}

// ─── ECG Chart (Draw → Live Sweep with gap) ─────────────────────────────────

class _EcgChart extends StatelessWidget {
  final List<double> data;
  final bool isLive;
  final double progress;

  const _EcgChart({
    required this.data,
    required this.isLive,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final displayData = data.length > 400
        ? List.generate(400, (i) => data[(i * data.length / 400).floor()])
        : List<double>.from(data);

    final n = displayData.length;
    final maxVal = displayData.isEmpty ? 1.0 : displayData.reduce(max);
    final minVal = displayData.isEmpty ? -1.0 : displayData.reduce(min);
    final rawRange = (maxVal - minVal).abs();
    // Guarantee a non-zero range so the chart doesn't render flat.
    final range = rawRange < 1e-3 ? 0.2 : rawRange;
    final pad = range * 0.15;
    final yMin = (rawRange < 1e-3 ? -0.1 : minVal - pad);
    final yMax = (rawRange < 1e-3 ? 0.1 : maxVal + pad);

    final grid = FlGridData(
      show: true, drawVerticalLine: true,
      horizontalInterval: range / 4,
      verticalInterval: n / 6,
      getDrawingHorizontalLine: (v) => FlLine(
          color: const Color(0xFF00FF00).withOpacity(0.07), strokeWidth: 0.5),
      getDrawingVerticalLine: (v) => FlLine(
          color: const Color(0xFF00FF00).withOpacity(0.07), strokeWidth: 0.5),
    );

    if (!isLive) {
      // ─ Phase 1: Progressive sweep ─
      final cnt = (n * progress).ceil().clamp(1, n);
      final spots =
          List.generate(cnt, (i) => FlSpot(i.toDouble(), displayData[i]));

      return LineChart(
        LineChartData(
          minY: yMin, maxY: yMax, minX: 0, maxX: n.toDouble(),
          clipData: const FlClipData.all(),
          gridData: grid,
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _ecgLine(spots, const Color(0xFF00FF00), 1.5,
                sweepDot: progress < 1.0),
          ],
          lineTouchData: const LineTouchData(enabled: false),
        ),
        duration: Duration.zero,
      );
    }

    // ─ Phase 2: Live sweep with blank gap ─
    final gapSize = max(3, (n * 0.02).ceil());
    final headIdx = (n * progress).ceil().clamp(1, n - 1);

    // Fresh trace: 0 → headIdx (bright)
    final fresh =
        List.generate(headIdx, (i) => FlSpot(i.toDouble(), displayData[i]));
    // Stale trace: headIdx+gap → end (dim, previous cycle)
    final staleStart = min(headIdx + gapSize, n);
    final stale = staleStart < n
        ? List.generate(n - staleStart,
            (i) => FlSpot((staleStart + i).toDouble(), displayData[staleStart + i]))
        : <FlSpot>[];

    return LineChart(
      LineChartData(
        minY: yMin, maxY: yMax, minX: 0, maxX: n.toDouble(),
        clipData: const FlClipData.all(),
        gridData: grid,
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          if (stale.length > 1)
            _ecgLine(stale, const Color(0xFF00FF00).withOpacity(0.18), 1.0,
                sweepDot: false, glow: false),
          if (fresh.isNotEmpty)
            _ecgLine(fresh, const Color(0xFF00FF00), 1.5, sweepDot: true),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
      duration: Duration.zero,
    );
  }

  LineChartBarData _ecgLine(List<FlSpot> spots, Color color, double width,
      {bool sweepDot = false, bool glow = true}) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: width,
      dotData: FlDotData(
        show: sweepDot,
        getDotPainter: (spot, pct, bar, i) {
          if (i == spots.length - 1) {
            return FlDotCirclePainter(
                radius: 3,
                color: const Color(0xFF00FF00),
                strokeWidth: 1.5,
                strokeColor: const Color(0xFF00FF00).withOpacity(0.5));
          }
          return FlDotCirclePainter(
              radius: 0, color: Colors.transparent,
              strokeWidth: 0, strokeColor: Colors.transparent);
        },
      ),
      shadow: glow
          ? Shadow(
              color: const Color(0xFF00FF00).withOpacity(0.4), blurRadius: 6)
          : const Shadow(color: Colors.transparent, blurRadius: 0),
    );
  }
}

// ─── Audio Waveform Chart (Animated reveal) ──────────────────────────────────

class _WaveformChart extends StatelessWidget {
  final AudioWaveform waveform;
  final bool isDark;
  final double progress; // 0.0 → 1.0

  const _WaveformChart({
    required this.waveform,
    required this.isDark,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final maxPoints = 400;
    final step = waveform.amplitude.length > maxPoints
        ? (waveform.amplitude.length / maxPoints).ceil()
        : 1;

    final allSpots = <FlSpot>[];
    for (int i = 0; i < waveform.amplitude.length; i += step) {
      final t = i < waveform.time.length ? waveform.time[i] : i.toDouble();
      allSpots.add(FlSpot(t, waveform.amplitude[i]));
    }

    if (allSpots.isEmpty) return const SizedBox.shrink();

    final visibleCount = (allSpots.length * progress).ceil().clamp(1, allSpots.length);
    final spots = allSpots.sublist(0, visibleCount);

    // Use a robust max (95th percentile of |amp|) to avoid one spike
    // dominating the y-axis and flattening the rest of the waveform.
    final absAmps = waveform.amplitude.map((a) => a.abs()).toList()
      ..sort();
    final robustMax = absAmps.isEmpty
        ? 0.0
        : absAmps[(absAmps.length * 0.95).floor().clamp(0, absAmps.length - 1)];
    // If the signal is near-silent, pin y-bound to a visible floor so the
    // line doesn't render as a flat dead zone.
    final yBound = robustMax < 0.02 ? 0.05 : robustMax * 1.15;

    return LineChart(
      LineChartData(
        minY: -yBound,
        maxY: yBound,
        minX: allSpots.first.x,
        maxX: allSpots.last.x,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yBound,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.black12,
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                return Text(
                  '${value.toStringAsFixed(1)}s',
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? AppTheme.darkTextDim : AppTheme.textLight,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: const Color(0xFF00BCD4),
            barWidth: 1,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF00BCD4).withOpacity(0.12),
                  const Color(0xFF00BCD4).withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
      duration: const Duration(milliseconds: 80),
    );
  }
}
