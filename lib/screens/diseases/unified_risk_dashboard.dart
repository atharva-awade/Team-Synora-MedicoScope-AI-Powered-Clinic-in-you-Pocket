import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:medicoscope/core/constants/disease_constants.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/models/disease_risk_result.dart';
import 'package:medicoscope/screens/diseases/disease_deck_screen.dart';
import 'package:medicoscope/screens/diseases/widgets/modality_chat_fab.dart';
import 'package:medicoscope/services/demo_mode_service.dart';
import 'package:medicoscope/services/disease_risk_store.dart';

class UnifiedRiskDashboard extends StatefulWidget {
  const UnifiedRiskDashboard({super.key});

  @override
  State<UnifiedRiskDashboard> createState() => _UnifiedRiskDashboardState();
}

class _UnifiedRiskDashboardState extends State<UnifiedRiskDashboard> {
  Map<DiseaseType, DiseaseRiskResult?> _latest = {};
  Map<DiseaseType, List<DiseaseRiskResult>> _all = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final latest = await DiseaseRiskStore.latestAll();
    final all = <DiseaseType, List<DiseaseRiskResult>>{};
    for (final d in DiseaseType.values) {
      all[d] = await DiseaseRiskStore.getAll(d);
    }
    if (!mounted) return;
    setState(() {
      _latest = latest;
      _all = all;
      _loading = false;
    });
  }

  Color _riskColor(RiskLevel r) {
    switch (r) {
      case RiskLevel.low:
        return const Color(0xFF4CAF50);
      case RiskLevel.moderate:
        return const Color(0xFFFF9800);
      case RiskLevel.high:
        return const Color(0xFFFF5252);
      case RiskLevel.critical:
        return const Color(0xFFD32F2F);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Scaffold(
      floatingActionButton: const ModalityChatFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.darkBackgroundGradient
              : AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(isDark),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingLarge,
                          ),
                          children: [
                            _overallGauge(isDark),
                            const SizedBox(height: AppTheme.spacingMedium),
                            _impactCard(isDark),
                            const SizedBox(height: AppTheme.spacingMedium),
                            for (final d in DiseaseType.values)
                              _diseaseCard(d, isDark),
                            const SizedBox(height: AppTheme.spacingXLarge),
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

  Future<void> _openDemoMenu() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Demo Mode',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFF5252)),
                title: const Text('Load high-risk patient'),
                subtitle: const Text(
                    'Seed HbA1c 8.1 / BP 154/96 / Hb 11.2 — jury showcase'),
                onTap: () async {
                  await DemoModeService.loadHighRiskProfile();
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  _load();
                },
              ),
              ListTile(
                leading: const Icon(Icons.verified_outlined,
                    color: Color(0xFF4CAF50)),
                title: const Text('Load healthy patient'),
                subtitle:
                    const Text('All markers normal — calm baseline'),
                onTap: () async {
                  await DemoModeService.loadHealthyProfile();
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  _load();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Clear all results'),
                onTap: () async {
                  for (final d in DiseaseType.values) {
                    await DiseaseRiskStore.clear(d);
                  }
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  _load();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios),
            color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: _openDemoMenu,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unified Risk Dashboard',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.darkTextLight
                          : AppTheme.textDark,
                    ),
                  ),
                  Text(
                    'Your diabetes • hypertension • anemia summary',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? AppTheme.darkTextGray
                          : AppTheme.textGray,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Demo mode',
            onPressed: _openDemoMenu,
            icon: Icon(
              Icons.auto_awesome,
              color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overallGauge(bool isDark) {
    // Compose an overall wellness score — 100 = healthy, 0 = critical.
    final scores = <double>[];
    for (final r in _latest.values) {
      if (r != null) scores.add((1 - r.score.clamp(0, 1)) * 100);
    }
    final hasData = scores.isNotEmpty;
    final wellness = hasData
        ? scores.reduce((a, b) => a + b) / scores.length
        : 0;
    final color = !hasData
        ? Colors.grey
        : wellness >= 75
            ? const Color(0xFF4CAF50)
            : wellness >= 50
                ? const Color(0xFFFFA000)
                : wellness >= 25
                    ? const Color(0xFFFF5252)
                    : const Color(0xFFD32F2F);
    final label = !hasData
        ? 'Run a screening'
        : wellness >= 75
            ? 'Excellent'
            : wellness >= 50
                ? 'Stable'
                : wellness >= 25
                    ? 'At risk'
                    : 'Needs attention';

    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: hasData ? wellness / 100 : 0,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor:
                        isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hasData ? wellness.toStringAsFixed(0) : '—',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1,
                      ),
                    ),
                    Text(
                      hasData ? 'Wellness' : 'No data',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkTextGray
                            : AppTheme.textGray,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasData
                      ? 'Composite score across your diabetes, hypertension and anemia screenings.'
                      : 'Run any of the three screening decks below to see your wellness score.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: isDark
                        ? AppTheme.darkTextGray
                        : AppTheme.textGray,
                  ),
                ),
                const SizedBox(height: 10),
                if (hasData)
                  Row(
                    children: _latest.entries
                        .where((e) => e.value != null)
                        .take(3)
                        .map((e) {
                      final meta = DiseaseRegistry.of(e.key);
                      final r = e.value!;
                      final c = _riskColor(r.risk);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(meta.icon, size: 12, color: c),
                                const SizedBox(height: 2),
                                Text(
                                  r.risk.label,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: c,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.05, end: 0, curve: Curves.easeOut);
  }

  Widget _impactCard(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public, color: Color(0xFF4ECDC4)),
              const SizedBox(width: 8),
              Text(
                'Why screening matters',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppTheme.darkTextLight
                      : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '🇮🇳 India: 101M diabetics • 315M hypertensive • 57% women anaemic (NFHS-5, ICMR-INDIAB).\n'
            '🇺🇸 USA: 37M diabetics • 122M hypertensive (CDC, AHA).\n'
            'MedicoScope screens all three in under 2 minutes — no clinic visit required.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.55,
              color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _diseaseCard(DiseaseType d, bool isDark) {
    final meta = DiseaseRegistry.of(d);
    final latest = _latest[d];
    final history = _all[d] ?? const [];
    final color = latest != null ? _riskColor(latest.risk) : Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DiseaseDeckScreen(disease: d),
          ),
        ),
        child: GlassCard(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: meta.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(meta.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppTheme.darkTextLight
                                : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          latest == null
                              ? 'No screenings yet — tap to start'
                              : 'Latest via ${MethodRegistry.of(latest.method).title}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.darkTextGray
                                : AppTheme.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (latest != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withOpacity(0.4)),
                      ),
                      child: Text(
                        latest.risk.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    )
                  else
                    Icon(Icons.chevron_right_rounded,
                        color: isDark
                            ? AppTheme.darkTextGray
                            : AppTheme.textGray),
                ],
              ),
              if (latest != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: latest.score.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  latest.headline,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppTheme.darkTextLight
                        : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.history_rounded,
                        size: 13,
                        color: isDark
                            ? AppTheme.darkTextGray
                            : AppTheme.textGray),
                    const SizedBox(width: 4),
                    Text(
                      '${history.length} screening${history.length == 1 ? '' : 's'} on record',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark
                            ? AppTheme.darkTextGray
                            : AppTheme.textGray,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(latest.timestamp),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark
                            ? AppTheme.darkTextGray
                            : AppTheme.textGray,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(
              delay: Duration(milliseconds: 80 * d.index), duration: 350.ms)
          .slideY(begin: 0.04, end: 0, curve: Curves.easeOut),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
