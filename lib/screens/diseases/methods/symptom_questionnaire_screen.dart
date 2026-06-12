import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:medicoscope/core/constants/disease_constants.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/data/symptom_questions.dart';
import 'package:medicoscope/models/disease_risk_result.dart';
import 'package:medicoscope/screens/diseases/methods/_method_scaffold.dart';
import 'package:medicoscope/screens/diseases/widgets/risk_result_view.dart';
import 'package:medicoscope/services/chat_service.dart';
import 'package:medicoscope/services/disease_result_pipeline.dart';
import 'package:medicoscope/services/symptom_analyzer.dart';

class SymptomQuestionnaireScreen extends StatefulWidget {
  final DiseaseType disease;
  final String? patientId;
  const SymptomQuestionnaireScreen(
      {super.key, required this.disease, this.patientId});

  @override
  State<SymptomQuestionnaireScreen> createState() =>
      _SymptomQuestionnaireScreenState();
}

class _SymptomQuestionnaireScreenState
    extends State<SymptomQuestionnaireScreen> {
  final Map<String, double> _answers = {};
  final TextEditingController _noteController = TextEditingController();
  bool _submitting = false;
  DiseaseRiskResult? _result;

  List<SymptomQuestion> get _questions =>
      SymptomQuestionBank.byDisease[widget.disease]!;

  bool get _canSubmit => _answers.length >= _questions.length;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final analyzed = SymptomAnalyzer.analyze(
      disease: widget.disease,
      answers: _answers,
      freeText: _noteController.text,
    );

    setState(() {
      _result = analyzed;
    });

    final lang = Provider.of<LocaleProvider>(context, listen: false)
        .languageCode;
    final explanation = await ChatService.explainRisk(
      disease: DiseaseRegistry.of(widget.disease).title,
      method: 'symptom questionnaire',
      riskLevel: analyzed.risk.label,
      headline: analyzed.headline,
      findings: analyzed.topContributors,
      language: lang,
    );

    final enriched = DiseaseRiskResult(
      disease: analyzed.disease,
      method: analyzed.method,
      risk: analyzed.risk,
      score: analyzed.score,
      headline: analyzed.headline,
      findings: analyzed.findings,
      topContributors: analyzed.topContributors,
      recommendations: analyzed.recommendations,
      dataSource: analyzed.dataSource,
      timestamp: analyzed.timestamp,
      llmExplanation: explanation,
    );

    if (!mounted) return;
    setState(() {
      _result = enriched;
      _submitting = false;
    });
    if (mounted) await DiseaseResultPipeline.persist(context, enriched);
  }

  void _reset() {
    setState(() {
      _answers.clear();
      _noteController.clear();
      _result = null;
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = MethodRegistry.of(DetectionMethod.symptomQuestionnaire);
    final d = DiseaseRegistry.of(widget.disease);

    return MethodScaffold(
      title: '${d.title} • ${m.title}',
      subtitle: m.subtitle,
      icon: m.icon,
      gradient: m.gradient,
      disease: widget.disease,
      body: _result != null
          ? RiskResultView(result: _result!, onRetry: _reset)
          : _buildForm(context, d),
    );
  }

  Widget _buildForm(BuildContext context, DiseaseMeta d) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology_alt_outlined, color: d.gradient.first),
                  const SizedBox(width: 8),
                  Text(
                    'Answer ${_questions.length} quick questions',
                    style: TextStyle(
                      fontSize: 14,
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
                'Tap Yes / Sometimes / No for each. Add context in the notes '
                'box below if you like — our AI will use that too.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        ...List.generate(_questions.length, (i) {
          final q = _questions[i];
          return _questionCard(q, i, isDark, d.gradient.first);
        }),
        const SizedBox(height: AppTheme.spacingMedium),
        GlassCard(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: d.gradient.first),
                  const SizedBox(width: 6),
                  Text(
                    'Anything else to share?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.darkTextLight
                          : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. "chest pain radiating to left arm", "heavy periods for 2 weeks"',
                  hintStyle: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextGray : AppTheme.textGray),
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingLarge),
        ElevatedButton.icon(
          onPressed: !_canSubmit || _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white))
              : const Icon(Icons.analytics_rounded),
          label: Text(_submitting
              ? 'Analyzing…'
              : _canSubmit
                  ? 'See my risk score'
                  : 'Answer all ${_questions.length} questions'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: d.gradient.first,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _questionCard(
      SymptomQuestion q, int index, bool isDark, Color accent) {
    final selected = _answers[q.id] ?? -1.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    q.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: isDark
                          ? AppTheme.darkTextLight
                          : AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _choice('No', 0.0, selected, accent, isDark, q.id),
                const SizedBox(width: 6),
                _choice('Sometimes', 0.5, selected, accent, isDark, q.id),
                const SizedBox(width: 6),
                _choice('Yes', 1.0, selected, accent, isDark, q.id),
              ],
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(delay: Duration(milliseconds: 30 * index), duration: 300.ms)
          .slideY(begin: 0.03, end: 0, curve: Curves.easeOut),
    );
  }

  Widget _choice(
    String label,
    double value,
    double selected,
    Color accent,
    bool isDark,
    String qId,
  ) {
    final active = (selected - value).abs() < 0.01;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _answers[qId] = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? accent : (isDark ? Colors.white10 : Colors.black.withOpacity(0.03)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? accent : Colors.transparent,
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active
                  ? Colors.white
                  : (isDark ? AppTheme.darkTextLight : AppTheme.textDark),
            ),
          ),
        ),
      ),
    );
  }
}
