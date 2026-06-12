import 'package:medicoscope/core/constants/disease_constants.dart';
import 'package:medicoscope/models/disease_risk_result.dart';
import 'package:medicoscope/services/disease_risk_store.dart';

/// Maps each chronic disease to the list of specialty strings used when
/// ranking nearby hospitals. Ordered by primary → supporting.
///
/// Recommendations are ONLY produced for risk levels `moderate`, `high`,
/// and `critical`. Low-risk (normal) screenings do NOT trigger any
/// specialty suggestion — an all-normal patient gets no recommendation
/// chips, because there's no clinical reason to push them to a doctor.
class SpecialtyRecommender {
  static const Map<DiseaseType, List<String>> diseaseToSpecialties = {
    DiseaseType.diabetes: [
      'Endocrinologist',
      'Diabetologist',
      'Ophthalmologist', // retinopathy follow-up
      'General Physician',
    ],
    DiseaseType.hypertension: [
      'Cardiologist',
      'Nephrologist',
      'General Physician',
    ],
    DiseaseType.anemia: [
      'Hematologist',
      // Gynecologist intentionally excluded from the default list —
      // it was pushing up for male users. It's only added when we have
      // gender context indicating a female patient (see _specsFor).
      'General Physician',
    ],
  };

  /// Returns a ranked list of (specialty, reason) tuples based on the
  /// patient's most recent screenings.
  ///
  /// Rules:
  ///   - Only `moderate` / `high` / `critical` screenings contribute
  ///     specialty suggestions. Low-risk screenings are skipped.
  ///   - Highest-risk disease wins the top slots.
  ///   - Duplicate specialties are deduped across diseases.
  ///   - Anemia adds Gynecologist only when [isFemale] is true.
  static Future<List<SpecialtyRecommendation>> recommend({
    bool? isFemale,
  }) async {
    final latest = await DiseaseRiskStore.latestAll();

    // Only keep results that are clinically actionable (moderate+).
    final actionable = latest.entries
        .where((e) =>
            e.value != null && e.value!.risk != RiskLevel.low)
        .toList()
      ..sort((a, b) {
        final sa = _riskWeight(a.value!.risk) * 100 + a.value!.score;
        final sb = _riskWeight(b.value!.risk) * 100 + b.value!.score;
        return sb.compareTo(sa);
      });

    final out = <SpecialtyRecommendation>[];
    final seen = <String>{};
    for (final entry in actionable) {
      final disease = entry.key;
      final result = entry.value!;
      final specs = _specsFor(disease, isFemale: isFemale);
      for (final spec in specs) {
        if (seen.contains(spec)) continue;
        seen.add(spec);
        out.add(SpecialtyRecommendation(
          specialty: spec,
          disease: disease,
          risk: result.risk,
          reason: _reason(disease, result.risk),
        ));
      }
    }
    return out;
  }

  static List<String> _specsFor(DiseaseType disease, {bool? isFemale}) {
    final base = List<String>.from(diseaseToSpecialties[disease] ?? const []);
    if (disease == DiseaseType.anemia && isFemale == true) {
      // Insert Gynecologist as a secondary pick for anaemia in women
      // (menstrual iron-loss is a major cause).
      base.insert(1, 'Gynecologist');
    }
    return base;
  }

  /// Best single specialty to search first — returns 'General Physician' if
  /// nothing actionable has been screened.
  static Future<String> topSpecialty({bool? isFemale}) async {
    final list = await recommend(isFemale: isFemale);
    if (list.isEmpty) return 'General Physician';
    return list.first.specialty;
  }

  static int _riskWeight(RiskLevel r) {
    switch (r) {
      case RiskLevel.critical:
        return 4;
      case RiskLevel.high:
        return 3;
      case RiskLevel.moderate:
        return 2;
      case RiskLevel.low:
        return 1;
    }
  }

  static String _reason(DiseaseType d, RiskLevel r) {
    final name = DiseaseRegistry.of(d).title;
    switch (r) {
      case RiskLevel.critical:
        return 'Critical $name signal — book urgently';
      case RiskLevel.high:
        return 'High $name risk in recent screening';
      case RiskLevel.moderate:
        return 'Moderate $name risk — advisable';
      case RiskLevel.low:
        return 'Preventive $name follow-up';
    }
  }
}

class SpecialtyRecommendation {
  final String specialty;
  final DiseaseType disease;
  final RiskLevel risk;
  final String reason;

  const SpecialtyRecommendation({
    required this.specialty,
    required this.disease,
    required this.risk,
    required this.reason,
  });
}
