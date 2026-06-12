import 'package:medicoscope/core/constants/disease_constants.dart';
import 'package:medicoscope/models/disease_risk_result.dart';
import 'package:medicoscope/services/disease_risk_store.dart';

/// Pre-loaded "Patient A" / "Patient B" profiles to guarantee a demo never
/// fails in front of a jury. Seeds the local store with realistic results so
/// every dashboard, chart, and summary has data on screen.
class DemoModeService {
  static Future<void> loadHighRiskProfile() async {
    await _clearAll();

    // Diabetes — HIGH (PDF + fundus + vitals)
    await DiseaseRiskStore.save(DiseaseRiskResult(
      disease: DiseaseType.diabetes,
      method: DetectionMethod.labReportPdf,
      risk: RiskLevel.high,
      score: 0.72,
      headline:
          'Report indicates HIGH risk for diabetes — HbA1c 8.1%, FBS 168 mg/dL.',
      findings: const [
        MarkerFinding(
          name: 'HbA1c',
          value: '8.1',
          unit: '%',
          referenceRange:
              '< 5.7% normal • 5.7–6.4% prediabetes • ≥ 6.5% diabetes',
          flag: 'high',
          interpretation: 'Diabetic range per ADA / ICMR thresholds',
        ),
        MarkerFinding(
          name: 'Fasting Blood Sugar',
          value: '168',
          unit: 'mg/dL',
          referenceRange:
              '70–99 normal • 100–125 prediabetes • ≥ 126 diabetes mg/dL',
          flag: 'high',
          interpretation: 'Diabetic range (ADA)',
        ),
        MarkerFinding(
          name: 'Postprandial Blood Sugar',
          value: '234',
          unit: 'mg/dL',
          referenceRange:
              '< 140 normal • 140–199 prediabetes • ≥ 200 diabetes mg/dL',
          flag: 'high',
          interpretation: 'Diabetic range (ADA)',
        ),
      ],
      topContributors: [
        'HbA1c: 8.1 %',
        'Fasting Blood Sugar: 168 mg/dL',
        'Postprandial Blood Sugar: 234 mg/dL',
      ],
      recommendations: const [
        'URGENT: Book an in-person consult with a Diabetes specialist',
        'Maintain a glycemic-controlled diet (low-GI carbs, adequate protein)',
        'Daily 30-minute moderate activity (walking / cycling)',
        'Repeat HbA1c every 3–6 months',
      ],
      dataSource: 'ADA Standards of Care + ICMR-INDIAB thresholds',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      llmExplanation:
          'Your HbA1c of 8.1% and fasting glucose of 168 mg/dL both fall in the '
          'diabetic range. The most important next step is a clinical visit '
          'within the next week to start or adjust medication.',
    ));

    // Hypertension — CRITICAL (PPG-BP)
    await DiseaseRiskStore.save(DiseaseRiskResult(
      disease: DiseaseType.hypertension,
      method: DetectionMethod.ppgBloodPressure,
      risk: RiskLevel.high,
      score: 0.68,
      headline: 'Stage 2 hypertension range.',
      findings: const [
        MarkerFinding(
          name: 'Estimated Systolic BP',
          value: '154',
          unit: 'mmHg',
          referenceRange:
              '< 120 normal • ≥ 130 stage 1 • ≥ 140 stage 2',
          flag: 'high',
          interpretation: 'Meets hypertension criteria',
        ),
        MarkerFinding(
          name: 'Estimated Diastolic BP',
          value: '96',
          unit: 'mmHg',
          referenceRange: '< 80 normal • ≥ 90 stage 2',
          flag: 'high',
          interpretation: 'Hypertension range',
        ),
        MarkerFinding(
          name: 'Pulse Rate (PPG)',
          value: '92',
          unit: 'bpm',
          referenceRange: '60–100 bpm resting',
          flag: 'normal',
          interpretation: 'Normal heart rate',
        ),
      ],
      topContributors: [
        'Estimated BP 154/96 mmHg',
        'Heart rate 92 bpm',
        'HRV 22 ms',
      ],
      recommendations: const [
        'URGENT: Confirm with a traditional cuff BP monitor and see a clinician.',
        'Cuff-less estimates are screening-grade. Validate with a calibrated monitor.',
        'Reduce sodium, manage stress, 30-min daily walk.',
      ],
      dataSource:
          'PPG-BP regression (Wu 2009 / Teng 2003) — MIMIC-III calibrated',
      timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
      llmExplanation:
          'Your cuff-less estimate of 154/96 mmHg is in stage 2 hypertension '
          'territory. Confirm with a calibrated arm cuff and book a clinical '
          'follow-up this week.',
    ));

    // Anemia — MODERATE (conjunctival pallor)
    await DiseaseRiskStore.save(DiseaseRiskResult(
      disease: DiseaseType.anemia,
      method: DetectionMethod.conjunctivalPallor,
      risk: RiskLevel.moderate,
      score: 0.42,
      headline: 'Mild pallor — possible mild anaemia',
      findings: const [
        MarkerFinding(
          name: 'Estimated Hb',
          value: '11.2',
          unit: 'g/dL',
          referenceRange: 'Men ≥ 13 • Women ≥ 12 (WHO)',
          flag: 'low',
          interpretation: 'Mild pallor — possible mild anaemia',
        ),
        MarkerFinding(
          name: 'R/G redness ratio',
          value: '1.27',
          unit: '',
          referenceRange: '> 1.4 typical healthy conjunctiva',
          flag: 'low',
          interpretation: 'Reduced red-channel dominance',
        ),
        MarkerFinding(
          name: 'HSV Saturation',
          value: '32.4',
          unit: '%',
          referenceRange: '> 40% healthy conjunctiva',
          flag: 'low',
          interpretation: 'Muted colour saturation — classic anaemia sign',
        ),
      ],
      topContributors: [
        'Estimated Hb 11.2 g/dL',
        'R/G ratio 1.27',
        'Saturation 32%',
      ],
      recommendations: const [
        'Include iron-rich foods (leafy greens, pulses, jaggery, red meat).',
        'Vitamin C with meals boosts iron absorption.',
        'Re-scan after 4–6 weeks of dietary change to track improvement.',
      ],
      dataSource:
          'Emory University smartphone-anemia method + AIIMS validation + WHO cutoffs',
      timestamp: DateTime.now().subtract(const Duration(hours: 9)),
      llmExplanation:
          'The photograph of your inner eyelid suggests mild pallor consistent '
          'with a haemoglobin around 11 g/dL. This is an early sign — confirm '
          'with a CBC and start iron-rich foods.',
    ));
  }

  static Future<void> loadHealthyProfile() async {
    await _clearAll();

    await DiseaseRiskStore.save(DiseaseRiskResult(
      disease: DiseaseType.diabetes,
      method: DetectionMethod.labReportPdf,
      risk: RiskLevel.low,
      score: 0.08,
      headline: 'Markers in the normal range for diabetes.',
      findings: const [
        MarkerFinding(
          name: 'HbA1c',
          value: '5.2',
          unit: '%',
          referenceRange:
              '< 5.7% normal • 5.7–6.4% prediabetes • ≥ 6.5% diabetes',
          flag: 'normal',
          interpretation: 'Normal glycemic control',
        ),
        MarkerFinding(
          name: 'Fasting Blood Sugar',
          value: '92',
          unit: 'mg/dL',
          referenceRange:
              '70–99 normal • 100–125 prediabetes • ≥ 126 diabetes mg/dL',
          flag: 'normal',
          interpretation: 'Normal fasting glucose',
        ),
      ],
      topContributors: const [],
      recommendations: const [
        'Maintain a glycemic-controlled diet (low-GI carbs, adequate protein)',
        'Daily 30-minute moderate activity (walking / cycling)',
        'Repeat HbA1c every 3–6 months',
      ],
      dataSource: 'ADA Standards of Care + ICMR-INDIAB thresholds',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ));

    await DiseaseRiskStore.save(DiseaseRiskResult(
      disease: DiseaseType.hypertension,
      method: DetectionMethod.vitalsWearable,
      risk: RiskLevel.low,
      score: 0.12,
      headline: '(live) Wearable signals are within normal range for hypertension.',
      findings: const [
        MarkerFinding(
          name: 'Systolic BP',
          value: '118',
          unit: 'mmHg',
          referenceRange:
              '< 120 normal • ≥ 130 stage 1 • ≥ 140 stage 2',
          flag: 'normal',
          interpretation: 'Normal systolic',
        ),
        MarkerFinding(
          name: 'Diastolic BP',
          value: '76',
          unit: 'mmHg',
          referenceRange: '< 80 normal • ≥ 90 stage 2',
          flag: 'normal',
          interpretation: 'Normal diastolic',
        ),
      ],
      topContributors: const [],
      recommendations: const [
        'Home BP log: morning + evening for 7 days',
        'Reduce sodium to < 2 g / day and manage stress',
      ],
      dataSource: 'Health Connect / HealthKit (live wearable data)',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
    ));

    await DiseaseRiskStore.save(DiseaseRiskResult(
      disease: DiseaseType.anemia,
      method: DetectionMethod.symptomQuestionnaire,
      risk: RiskLevel.low,
      score: 0.15,
      headline: 'Symptom burden for anemia is low right now.',
      findings: const [],
      topContributors: const [],
      recommendations: const [
        'Get a CBC (Complete Blood Count) and ferritin test',
        'Include iron-rich foods + vitamin C with meals',
      ],
      dataSource: 'Validated clinical questionnaire + ICMR / ADA guidance',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ));
  }

  static Future<void> _clearAll() async {
    for (final d in DiseaseType.values) {
      await DiseaseRiskStore.clear(d);
    }
  }
}
