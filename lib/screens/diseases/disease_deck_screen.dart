import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:medicoscope/core/constants/disease_constants.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/screens/diseases/methods/lab_report_screen.dart';
import 'package:medicoscope/screens/diseases/methods/symptom_questionnaire_screen.dart';
import 'package:medicoscope/screens/diseases/methods/disease_vitals_screen.dart';
import 'package:medicoscope/screens/diseases/methods/retinal_fundus_screen.dart';
import 'package:medicoscope/screens/diseases/methods/conjunctival_pallor_screen.dart';
import 'package:medicoscope/screens/diseases/methods/ppg_blood_pressure_screen.dart';
import 'package:medicoscope/models/disease_risk_result.dart';
import 'package:medicoscope/screens/diseases/dataset_citations_screen.dart';
import 'package:medicoscope/screens/diseases/widgets/book_appointment_sheet.dart';
import 'package:medicoscope/screens/diseases/widgets/modality_chat_fab.dart';
import 'package:medicoscope/services/disease_risk_store.dart';

/// Generic deck screen — given a DiseaseType, renders a hero header,
/// a grid/list of detection method tiles, dataset citations, and impact stats.
class DiseaseDeckScreen extends StatelessWidget {
  final DiseaseType disease;
  final String? patientId;

  const DiseaseDeckScreen({
    super.key,
    required this.disease,
    this.patientId,
  });

  DiseaseMeta get _meta => DiseaseRegistry.of(disease);

  void _openMethod(BuildContext context, DetectionMethod method) {
    final disease = this.disease;
    final pid = patientId;
    Widget screen;
    switch (method) {
      case DetectionMethod.labReportPdf:
        screen = LabReportScreen(disease: disease, patientId: pid);
        break;
      case DetectionMethod.symptomQuestionnaire:
        screen = SymptomQuestionnaireScreen(disease: disease, patientId: pid);
        break;
      case DetectionMethod.vitalsWearable:
        screen = DiseaseVitalsScreen(disease: disease, patientId: pid);
        break;
      case DetectionMethod.retinalFundus:
        screen = RetinalFundusScreen(patientId: pid);
        break;
      case DetectionMethod.conjunctivalPallor:
        screen = ConjunctivalPallorScreen(patientId: pid);
        break;
      case DetectionMethod.ppgBloodPressure:
        screen = PpgBloodPressureScreen(patientId: pid);
        break;
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final meta = _meta;

    return Scaffold(
      floatingActionButton: ModalityChatFab(disease: disease),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.darkBackgroundGradient
              : AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context, isDark),
              SliverToBoxAdapter(child: _buildHero(context, meta, isDark)),
              SliverToBoxAdapter(
                child: _buildLatestSummary(context, meta, isDark),
              ),
              SliverToBoxAdapter(
                child: _buildBookAppointmentCTA(context, meta, isDark),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingLarge,
                  AppTheme.spacingMedium,
                  AppTheme.spacingLarge,
                  AppTheme.spacingXLarge,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _buildMethodCard(
                      context,
                      meta.methods[i],
                      isDark,
                      i,
                    ),
                    childCount: meta.methods.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildFooter(context, meta, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: false,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_ios),
        color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
      ),
      title: Text(
        _meta.title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Data sources',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DatasetCitationsScreen(disease: disease),
            ),
          ),
          icon: Icon(
            Icons.info_outline,
            color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildLatestSummary(BuildContext context, DiseaseMeta meta, bool isDark) {
    return FutureBuilder<DiseaseRiskResult?>(
      future: DiseaseRiskStore.latest(disease),
      builder: (ctx, snap) {
        final r = snap.data;
        if (r == null) return const SizedBox.shrink();
        final color = _riskColor(r.risk);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingLarge,
            0,
            AppTheme.spacingLarge,
            AppTheme.spacingSmall,
          ),
          child: GlassCard(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.4), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${(r.score * 100).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: color.withOpacity(0.4)),
                            ),
                            child: Text(
                              r.risk.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              MethodRegistry.of(r.method).title,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppTheme.darkTextGray
                                    : AppTheme.textGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.headline,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: isDark
                              ? AppTheme.darkTextLight
                              : AppTheme.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 350.ms)
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
        );
      },
    );
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

  Widget _buildBookAppointmentCTA(
      BuildContext context, DiseaseMeta meta, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingLarge, 6, AppTheme.spacingLarge, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showBookAppointmentSheet(context, disease: disease),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: meta.gradient.first.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: meta.gradient.first.withOpacity(0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: meta.gradient),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: meta.gradient.first.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.event_available,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book appointment with your doctor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.darkTextLight
                              : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Share this ${meta.title.toLowerCase()} screening with your linked doctor',
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
                Icon(Icons.chevron_right_rounded,
                    color:
                        isDark ? AppTheme.darkTextGray : AppTheme.textGray),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, DiseaseMeta meta, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLarge,
        vertical: AppTheme.spacingSmall,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: meta.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: meta.gradient.first.withOpacity(0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Icon(meta.icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meta.shortDesc,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withOpacity(0.88),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                meta.longDesc,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Row(
              children: [
                _heroStat(
                  flag: '🇮🇳',
                  label: 'India',
                  value: meta.prevalenceIndia,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _heroStat(
                  flag: '🇺🇸',
                  label: 'USA',
                  value: meta.prevalenceUSA,
                ),
              ],
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 500.ms)
          .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
    );
  }

  Widget _heroStat({
    required String flag,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              '$label:',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodCard(
    BuildContext context,
    DetectionMethod method,
    bool isDark,
    int index,
  ) {
    final m = MethodRegistry.of(method);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: GestureDetector(
        onTap: () => _openMethod(context, method),
        child: GlassCard(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: m.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: m.gradient.first.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(m.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.darkTextLight
                            : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      m.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextGray
                            : AppTheme.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: Duration(milliseconds: 80 * index), duration: 350.ms)
            .slideX(begin: 0.03, end: 0, curve: Curves.easeOut),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, DiseaseMeta meta, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLarge,
        0,
        AppTheme.spacingLarge,
        AppTheme.spacingXLarge,
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined,
                    size: 18, color: meta.gradient.first),
                const SizedBox(width: 6),
                Text(
                  'Powered by validated medical datasets',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'MedicoScope screens for ${meta.title.toLowerCase()} using '
              'peer-reviewed research data from Indian and US medical institutions. '
              'Tap the info icon to view all sources.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Screening tool only — not a diagnosis. Always confirm with a clinician.',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.orange.shade200 : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
