import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:medicoscope/core/constants/disease_constants.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/models/detection_result.dart';
import 'package:medicoscope/models/disease_risk_result.dart';
import 'package:medicoscope/screens/diseases/methods/_method_scaffold.dart';
import 'package:medicoscope/screens/diseases/widgets/risk_result_view.dart';
import 'package:medicoscope/services/chat_service.dart';
import 'package:medicoscope/services/disease_result_pipeline.dart';
import 'package:medicoscope/services/image_retina_analyzer.dart';
import 'package:medicoscope/services/tflite_service.dart';

/// Retinal fundus screen — uses the APTOS 2019 / EyePACS-trained TFLite model
/// shipped at assets/models/eye_float32.tflite. Falls back to the hand-crafted
/// feature pipeline if the model fails to load on the device.
class RetinalFundusScreen extends StatefulWidget {
  final String? patientId;
  const RetinalFundusScreen({super.key, this.patientId});

  @override
  State<RetinalFundusScreen> createState() => _RetinalFundusScreenState();
}

class _RetinalFundusScreenState extends State<RetinalFundusScreen> {
  final TFLiteService _tflite = TFLiteService();
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _busy = false;
  String _status = '';
  DiseaseRiskResult? _result;

  @override
  void initState() {
    super.initState();
    _warmup();
  }

  Future<void> _warmup() async {
    try {
      await _tflite.loadModel('eye');
    } catch (_) {
      // Fall back silently — we'll still offer heuristic-only analysis.
    }
  }

  @override
  void dispose() {
    _tflite.dispose();
    super.dispose();
  }

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
      _status = 'Running TFLite APTOS model…';
    });

    DiseaseRiskResult result;

    try {
      final detection = await _tflite.runInference(_imageFile!);
      if (detection != null) {
        result = _convertToRisk(detection);
      } else {
        setState(() => _status = 'Model returned low confidence — running feature heuristic…');
        final bytes = await _imageFile!.readAsBytes();
        result = ImageRetinaAnalyzer.analyze(Uint8List.fromList(bytes));
      }
    } catch (e) {
      // Model load / inference failed — fall back to the hand-crafted analyser.
      setState(() => _status = 'Falling back to feature heuristic…');
      final bytes = await _imageFile!.readAsBytes();
      result = ImageRetinaAnalyzer.analyze(Uint8List.fromList(bytes));
    }

    if (!mounted) return;
    setState(() {
      _result = result;
      _status = 'Generating explanation…';
    });

    final lang =
        Provider.of<LocaleProvider>(context, listen: false).languageCode;
    final explanation = await ChatService.explainRisk(
      disease: 'Diabetes',
      method: 'retinal fundus scan',
      riskLevel: result.risk.label,
      headline: result.headline,
      findings: result.findings
          .map((f) =>
              '${f.name} ${f.value} ${f.unit} (${f.flag}) — ${f.interpretation}')
          .toList(),
      language: lang,
    );

    final enriched = DiseaseRiskResult(
      disease: result.disease,
      method: result.method,
      risk: result.risk,
      score: result.score,
      headline: result.headline,
      findings: result.findings,
      topContributors: result.topContributors,
      recommendations: result.recommendations,
      dataSource: result.dataSource,
      timestamp: result.timestamp,
      llmExplanation: explanation,
    );

    if (!mounted) return;
    setState(() {
      _result = enriched;
      _busy = false;
      _status = '';
    });
    if (mounted) await DiseaseResultPipeline.persist(context, enriched);
  }

  /// Map an APTOS 5-class classification head output to our unified
  /// DiseaseRiskResult contract. Confidence is the soft-max probability
  /// of the winning grade.
  DiseaseRiskResult _convertToRisk(DetectionResult d) {
    final grade = d.className;
    final conf = d.confidence;
    RiskLevel risk;
    double score;
    String headline;
    switch (grade) {
      case 'No DR':
        risk = RiskLevel.low;
        score = 0.1;
        headline = 'No diabetic retinopathy detected.';
        break;
      case 'Mild DR':
        risk = RiskLevel.moderate;
        score = 0.35;
        headline = 'Mild non-proliferative diabetic retinopathy.';
        break;
      case 'Moderate DR':
        risk = RiskLevel.high;
        score = 0.6;
        headline = 'Moderate non-proliferative diabetic retinopathy.';
        break;
      case 'Severe DR':
        risk = RiskLevel.high;
        score = 0.85;
        headline =
            'Severe non-proliferative diabetic retinopathy — urgent referral.';
        break;
      case 'Proliferative DR':
        risk = RiskLevel.critical;
        score = 0.95;
        headline =
            'Proliferative diabetic retinopathy — sight-threatening, seek care immediately.';
        break;
      default:
        risk = RiskLevel.low;
        score = 0.2;
        headline = grade;
    }

    return DiseaseRiskResult(
      disease: DiseaseType.diabetes,
      method: DetectionMethod.retinalFundus,
      risk: risk,
      score: score,
      headline: headline,
      findings: [
        MarkerFinding(
          name: 'APTOS DR Grade',
          value: grade,
          unit: '',
          referenceRange:
              'No DR / Mild / Moderate / Severe / Proliferative (APTOS 2019)',
          flag: risk == RiskLevel.critical
              ? 'critical'
              : risk == RiskLevel.high
                  ? 'high'
                  : risk == RiskLevel.moderate
                      ? 'low'
                      : 'normal',
          interpretation: d.description,
        ),
        MarkerFinding(
          name: 'Model Confidence',
          value: (conf * 100).toStringAsFixed(1),
          unit: '%',
          referenceRange: 'Higher is better',
          flag: conf >= 0.7
              ? 'normal'
              : conf >= 0.4
                  ? 'low'
                  : 'critical',
          interpretation: conf >= 0.7
              ? 'High model confidence'
              : conf >= 0.4
                  ? 'Moderate model confidence — re-take if possible'
                  : 'Low confidence — a sharper, better-lit image will help',
        ),
      ],
      topContributors: [
        'Grade: $grade',
        'Confidence ${(conf * 100).toStringAsFixed(0)}%',
      ],
      recommendations: [
        if (risk == RiskLevel.critical || risk == RiskLevel.high)
          'URGENT: Book an ophthalmologist appointment within days.',
        'Tight glycaemic control — target HbA1c < 7%.',
        'Annual dilated retinal exam with a specialist.',
        'Control blood pressure and lipids to slow progression.',
      ],
      dataSource:
          'APTOS 2019 (Aravind Eye Hospital) + Kaggle EyePACS — on-device TFLite',
      timestamp: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final m = MethodRegistry.of(DetectionMethod.retinalFundus);
    return MethodScaffold(
      title: 'Diabetic Retinopathy',
      subtitle: m.subtitle,
      icon: m.icon,
      gradient: m.gradient,
      disease: DiseaseType.diabetes,
      body: _body(isDark, m.gradient.first),
    );
  }

  Widget _body(bool isDark, Color accent) {
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
                  Icon(Icons.remove_red_eye_outlined, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    'How this works',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color:
                          isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Upload or capture a retinal fundus image. An on-device TFLite '
                'classifier trained on APTOS 2019 (Aravind Eye Hospital) + '
                'Kaggle EyePACS stages diabetic retinopathy on the standard '
                '0–4 APTOS scale. Fully on-device — no image leaves your phone.',
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
          GlassCard(
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
                    _status.isEmpty ? 'Working…' : _status,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkTextLight
                          : AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
          )
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
          RiskResultView(
            result: _result!,
            onRetry: () => setState(() {
              _imageFile = null;
              _result = null;
              _busy = false;
            }),
          ),
      ],
    );
  }
}
