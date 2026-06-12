import 'dart:convert';

import 'package:medicoscope/core/constants/disease_constants.dart';

enum RiskLevel { low, moderate, high, critical }

extension RiskLevelX on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'LOW';
      case RiskLevel.moderate:
        return 'MODERATE';
      case RiskLevel.high:
        return 'HIGH';
      case RiskLevel.critical:
        return 'CRITICAL';
    }
  }

  /// How this maps into the unified alert severity our backend already supports.
  String get alertSeverity {
    switch (this) {
      case RiskLevel.low:
        return 'info';
      case RiskLevel.moderate:
        return 'warning';
      case RiskLevel.high:
        return 'warning';
      case RiskLevel.critical:
        return 'critical';
    }
  }

  bool get shouldAlertDoctor =>
      this == RiskLevel.high || this == RiskLevel.critical;
}

RiskLevel parseRiskLevel(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'CRITICAL':
      return RiskLevel.critical;
    case 'HIGH':
      return RiskLevel.high;
    case 'MODERATE':
    case 'MEDIUM':
      return RiskLevel.moderate;
    default:
      return RiskLevel.low;
  }
}

/// A single measured marker from a lab report / vitals reading / model output
/// with its reference range and the flag produced by our threshold engine.
class MarkerFinding {
  final String name;
  final String value;
  final String unit;
  final String referenceRange;
  final String flag; // 'normal', 'low', 'high', 'critical'
  final String interpretation;

  const MarkerFinding({
    required this.name,
    required this.value,
    required this.unit,
    required this.referenceRange,
    required this.flag,
    required this.interpretation,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'unit': unit,
        'referenceRange': referenceRange,
        'flag': flag,
        'interpretation': interpretation,
      };

  factory MarkerFinding.fromJson(Map<String, dynamic> j) => MarkerFinding(
        name: j['name'] ?? '',
        value: j['value']?.toString() ?? '',
        unit: j['unit'] ?? '',
        referenceRange: j['referenceRange'] ?? '',
        flag: j['flag'] ?? 'normal',
        interpretation: j['interpretation'] ?? '',
      );
}

/// Unified result for any detection method (PDF / questionnaire / vitals / image)
class DiseaseRiskResult {
  final DiseaseType disease;
  final DetectionMethod method;
  final RiskLevel risk;
  final double score; // 0.0..1.0
  final String headline; // short human-readable conclusion
  final List<MarkerFinding> findings;
  final List<String> topContributors; // for explainability
  final List<String> recommendations;
  final String dataSource; // which dataset/guideline we anchored to
  final DateTime timestamp;
  final String? llmExplanation; // optional natural-language paragraph

  const DiseaseRiskResult({
    required this.disease,
    required this.method,
    required this.risk,
    required this.score,
    required this.headline,
    required this.findings,
    required this.topContributors,
    required this.recommendations,
    required this.dataSource,
    required this.timestamp,
    this.llmExplanation,
  });

  Map<String, dynamic> toJson() => {
        'disease': disease.name,
        'method': method.name,
        'risk': risk.label,
        'score': score,
        'headline': headline,
        'findings': findings.map((f) => f.toJson()).toList(),
        'topContributors': topContributors,
        'recommendations': recommendations,
        'dataSource': dataSource,
        'timestamp': timestamp.toIso8601String(),
        'llmExplanation': llmExplanation,
      };

  String toJsonString() => jsonEncode(toJson());

  factory DiseaseRiskResult.fromJson(Map<String, dynamic> j) =>
      DiseaseRiskResult(
        disease: DiseaseType.values
            .firstWhere((d) => d.name == j['disease'], orElse: () => DiseaseType.diabetes),
        method: DetectionMethod.values
            .firstWhere((m) => m.name == j['method'], orElse: () => DetectionMethod.labReportPdf),
        risk: parseRiskLevel(j['risk']),
        score: (j['score'] as num?)?.toDouble() ?? 0.0,
        headline: j['headline'] ?? '',
        findings: (j['findings'] as List?)
                ?.map((e) => MarkerFinding.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        topContributors: List<String>.from(j['topContributors'] ?? const []),
        recommendations: List<String>.from(j['recommendations'] ?? const []),
        dataSource: j['dataSource'] ?? '',
        timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
        llmExplanation: j['llmExplanation'],
      );
}
