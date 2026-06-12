import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
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

/// Shared image-based screening screen. Caller supplies the analyzer function
/// plus scaffold chrome.
class ImageScreeningScreen extends StatefulWidget {
  final DiseaseType disease;
  final DetectionMethod method;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String captureHint;
  final DiseaseRiskResult Function(List<int> imageBytes) analyzer;
  final String? patientId;

  const ImageScreeningScreen({
    super.key,
    required this.disease,
    required this.method,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.captureHint,
    required this.analyzer,
    this.patientId,
  });

  @override
  State<ImageScreeningScreen> createState() => _ImageScreeningScreenState();
}

class _ImageScreeningScreenState extends State<ImageScreeningScreen> {
  File? _imageFile;
  DiseaseRiskResult? _result;
  bool _busy = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pick(ImageSource src) async {
    final xf = await _picker.pickImage(
      source: src,
      maxWidth: 1600,
      imageQuality: 92,
    );
    if (xf == null) return;
    setState(() {
      _imageFile = File(xf.path);
      _result = null;
      _busy = true;
    });
    await _analyze();
  }

  Future<void> _analyze() async {
    final file = _imageFile;
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final base = widget.analyzer(bytes);
    if (!mounted) return;
    setState(() => _result = base);

    final lang =
        Provider.of<LocaleProvider>(context, listen: false).languageCode;
    final explanation = await ChatService.explainRisk(
      disease: DiseaseRegistry.of(widget.disease).title,
      method: widget.title.toLowerCase(),
      riskLevel: base.risk.label,
      headline: base.headline,
      findings: base.findings
          .map((f) =>
              '${f.name} ${f.value} ${f.unit} (${f.flag}) — ${f.interpretation}')
          .toList(),
      language: lang,
    );

    final enriched = DiseaseRiskResult(
      disease: base.disease,
      method: base.method,
      risk: base.risk,
      score: base.score,
      headline: base.headline,
      findings: base.findings,
      topContributors: base.topContributors,
      recommendations: base.recommendations,
      dataSource: base.dataSource,
      timestamp: base.timestamp,
      llmExplanation: explanation,
    );
    if (!mounted) return;
    setState(() {
      _result = enriched;
      _busy = false;
    });
    if (mounted) await DiseaseResultPipeline.persist(context, enriched);
  }

  void _reset() {
    setState(() {
      _imageFile = null;
      _result = null;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MethodScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      icon: widget.icon,
      gradient: widget.gradient,
      disease: widget.disease,
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final accent = widget.gradient.first;

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
                  Icon(Icons.camera_alt_outlined, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    'Capture hint',
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
                widget.captureHint,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color:
                      isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        if (_imageFile != null)
          Container(
            height: 220,
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              image: DecorationImage(
                image: FileImage(_imageFile!),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
        if (_busy)
          _progressCard(isDark, accent)
        else if (_result == null)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: accent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (_result != null)
          RiskResultView(result: _result!, onRetry: _reset),
      ],
    );
  }

  Widget _progressCard(bool isDark, Color accent) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Analysing image on-device…',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
