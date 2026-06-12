import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:medicoscope/core/constants/disease_constants.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/models/disease_risk_result.dart';
import 'package:medicoscope/screens/diseases/methods/_method_scaffold.dart';
import 'package:medicoscope/screens/diseases/widgets/risk_result_view.dart';
import 'package:medicoscope/services/chat_service.dart';
import 'package:medicoscope/services/disease_result_pipeline.dart';
import 'package:medicoscope/services/lab_report_analyzer.dart';
import 'package:medicoscope/services/pdf_extractor.dart';

enum _Stage { idle, extracting, analyzing, explaining, done, error }

class LabReportScreen extends StatefulWidget {
  final DiseaseType disease;
  final String? patientId;
  const LabReportScreen({super.key, required this.disease, this.patientId});

  @override
  State<LabReportScreen> createState() => _LabReportScreenState();
}

class _LabReportScreenState extends State<LabReportScreen> {
  _Stage _stage = _Stage.idle;
  DiseaseRiskResult? _result;
  String? _fileName;
  String? _errorMessage;

  Future<void> _pickAndAnalyze() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final path = file.path;
    if (path == null) {
      setState(() {
        _stage = _Stage.error;
        _errorMessage = 'Could not access the selected file.';
      });
      return;
    }

    setState(() {
      _fileName = file.name;
      _stage = _Stage.extracting;
      _result = null;
      _errorMessage = null;
    });

    try {
      final text = await PdfExtractor.extractText(path);

      if (!mounted) return;
      setState(() => _stage = _Stage.analyzing);

      final analyzed = LabReportAnalyzer.analyze(
        disease: widget.disease,
        text: text,
      );

      if (!mounted) return;
      setState(() {
        _result = analyzed;
        _stage = analyzed.findings.isEmpty ? _Stage.done : _Stage.explaining;
      });

      if (analyzed.findings.isNotEmpty) {
        final lang = Provider.of<LocaleProvider>(context, listen: false)
            .languageCode;
        final explanation = await ChatService.explainRisk(
          disease: DiseaseRegistry.of(widget.disease).title,
          method: 'lab report',
          riskLevel: analyzed.risk.label,
          headline: analyzed.headline,
          findings: analyzed.findings
              .map((f) =>
                  '${f.name} ${f.value} ${f.unit} (${f.flag}) — ${f.interpretation}')
              .toList(),
          language: lang,
        );

        if (!mounted) return;
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
        setState(() {
          _result = enriched;
          _stage = _Stage.done;
        });
        if (mounted) await DiseaseResultPipeline.persist(context, enriched);
      } else {
        if (mounted) await DiseaseResultPipeline.persist(context, analyzed);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _errorMessage =
            'We couldn\'t read this PDF. Try a lab report with selectable text (not a scanned image).';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = MethodRegistry.of(DetectionMethod.labReportPdf);
    final d = DiseaseRegistry.of(widget.disease);
    return MethodScaffold(
      title: '${d.title} • ${m.title}',
      subtitle: m.subtitle,
      icon: m.icon,
      gradient: m.gradient,
      disease: widget.disease,
      body: _buildBody(context, d, m),
    );
  }

  Widget _buildBody(BuildContext context, DiseaseMeta d, MethodMeta m) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final introCard = GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined, color: d.gradient.first),
              const SizedBox(width: 8),
              Text(
                'Scan a pathlab PDF',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a PDF from any diagnostic lab. MedicoScope parses it fully '
            'on-device and compares markers against ICMR / ADA / AHA / WHO '
            'thresholds — no data leaves your phone during parsing.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
            ),
          ),
        ],
      ),
    );

    final pickButton = ElevatedButton.icon(
      onPressed:
          _stage == _Stage.idle || _stage == _Stage.done || _stage == _Stage.error
              ? _pickAndAnalyze
              : null,
      icon: const Icon(Icons.upload_file_rounded),
      label: Text(_result == null ? 'Select a PDF report' : 'Analyze a new report'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: d.gradient.first,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        introCard,
        const SizedBox(height: AppTheme.spacingMedium),
        pickButton,
        const SizedBox(height: AppTheme.spacingMedium),
        if (_fileName != null && _stage != _Stage.idle)
          _fileChip(isDark, d.gradient.first),
        if (_stage == _Stage.extracting || _stage == _Stage.analyzing ||
            _stage == _Stage.explaining)
          _progressCard(isDark, d.gradient.first),
        if (_stage == _Stage.error) _errorCard(isDark),
        if (_result != null && _stage == _Stage.done)
          RiskResultView(result: _result!, onRetry: _pickAndAnalyze),
      ],
    );
  }

  Widget _fileChip(bool isDark, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.description_outlined, size: 18, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _fileName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressCard(bool isDark, Color accent) {
    String label;
    switch (_stage) {
      case _Stage.extracting:
        label = 'Extracting text from your PDF…';
        break;
      case _Stage.analyzing:
        label = 'Running threshold engine against clinical guidelines…';
        break;
      case _Stage.explaining:
        label = 'Asking MedicoScope AI for a plain-English explanation…';
        break;
      default:
        label = 'Working…';
    }
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _errorCard(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFFF5252)),
              SizedBox(width: 8),
              Text(
                'Could not analyze report',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF5252),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Unknown error.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
