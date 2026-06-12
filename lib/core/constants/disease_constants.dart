import 'package:flutter/material.dart';

/// The three chronic-disease screening decks supported by MedicoScope.
enum DiseaseType { diabetes, hypertension, anemia }

/// Ways a user can get screened for a given disease.
enum DetectionMethod {
  labReportPdf,
  symptomQuestionnaire,
  vitalsWearable,
  retinalFundus,
  conjunctivalPallor,
  ppgBloodPressure,
}

class DiseaseMeta {
  final DiseaseType type;
  final String id;
  final String title;
  final String shortDesc;
  final String longDesc;
  final IconData icon;
  final List<Color> gradient;
  final List<DetectionMethod> methods;
  final List<DatasetCitation> datasets;
  final String alertType;
  final String prevalenceIndia;
  final String prevalenceUSA;

  const DiseaseMeta({
    required this.type,
    required this.id,
    required this.title,
    required this.shortDesc,
    required this.longDesc,
    required this.icon,
    required this.gradient,
    required this.methods,
    required this.datasets,
    required this.alertType,
    required this.prevalenceIndia,
    required this.prevalenceUSA,
  });
}

class DatasetCitation {
  final String name;
  final String institution;
  final String country;
  final String usedFor;

  const DatasetCitation({
    required this.name,
    required this.institution,
    required this.country,
    required this.usedFor,
  });
}

class DiseaseRegistry {
  static const Map<DiseaseType, DiseaseMeta> meta = {
    DiseaseType.diabetes: DiseaseMeta(
      type: DiseaseType.diabetes,
      id: 'diabetes',
      title: 'Diabetes',
      shortDesc: 'Screen for Type 2 diabetes via multiple methods',
      longDesc:
          'Diabetes mellitus is a chronic metabolic condition marked by high blood glucose. '
          'MedicoScope uses ADA and ICMR-INDIAB thresholds to screen via lab report, '
          'symptoms, wearable vitals, and retinal fundus imaging (diabetic retinopathy).',
      icon: Icons.bloodtype_outlined,
      gradient: [Color(0xFF667EEA), Color(0xFF764BA2)],
      methods: [
        DetectionMethod.labReportPdf,
        DetectionMethod.symptomQuestionnaire,
        DetectionMethod.vitalsWearable,
        DetectionMethod.retinalFundus,
      ],
      datasets: [
        DatasetCitation(
          name: 'ICMR-INDIAB Study',
          institution: 'Indian Council of Medical Research',
          country: 'India',
          usedFor: 'HbA1c / FBS / PPBS thresholds & population risk baselines',
        ),
        DatasetCitation(
          name: 'APTOS 2019 Blindness Detection',
          institution: 'Aravind Eye Hospital, Madurai',
          country: 'India',
          usedFor: 'Diabetic retinopathy retinal fundus classifier',
        ),
        DatasetCitation(
          name: 'Kaggle EyePACS',
          institution: 'UC Berkeley / EyePACS LLC',
          country: 'USA',
          usedFor: 'Diabetic retinopathy fine-tuning set',
        ),
        DatasetCitation(
          name: 'ADA Standards of Medical Care in Diabetes',
          institution: 'American Diabetes Association',
          country: 'USA',
          usedFor: 'Clinical cutoffs and staging',
        ),
      ],
      alertType: 'diabetes_high_risk',
      prevalenceIndia: '101M adults (ICMR-INDIAB 2023)',
      prevalenceUSA: '37.3M adults (CDC 2022)',
    ),
    DiseaseType.hypertension: DiseaseMeta(
      type: DiseaseType.hypertension,
      id: 'hypertension',
      title: 'Hypertension',
      shortDesc: 'Screen for high blood pressure & organ-damage risk',
      longDesc:
          'Hypertension is persistently elevated arterial blood pressure. '
          'MedicoScope screens via lab report (renal & lipid markers), symptoms, '
          'live vitals from smartwatch, and cuff-less PPG blood pressure estimation '
          'using the smartphone camera (MIMIC-III-inspired waveform analysis).',
      icon: Icons.favorite_outline,
      gradient: [Color(0xFFF093FB), Color(0xFFF5576C)],
      methods: [
        DetectionMethod.labReportPdf,
        DetectionMethod.symptomQuestionnaire,
        DetectionMethod.vitalsWearable,
        DetectionMethod.ppgBloodPressure,
      ],
      datasets: [
        DatasetCitation(
          name: 'MIMIC-III Waveform Database',
          institution: 'MIT Laboratory for Computational Physiology',
          country: 'USA',
          usedFor: 'PPG-to-BP waveform feature regression',
        ),
        DatasetCitation(
          name: 'AHA/ACC 2017 Hypertension Guidelines',
          institution: 'American Heart Association / American College of Cardiology',
          country: 'USA',
          usedFor: 'BP classification thresholds',
        ),
        DatasetCitation(
          name: 'ICMR Hypertension Guidelines',
          institution: 'Indian Council of Medical Research',
          country: 'India',
          usedFor: 'India-specific BP thresholds & end-organ markers',
        ),
      ],
      alertType: 'hypertension_high_risk',
      prevalenceIndia: '315M adults (ICMR 2023)',
      prevalenceUSA: '122.4M adults (AHA 2024)',
    ),
    DiseaseType.anemia: DiseaseMeta(
      type: DiseaseType.anemia,
      id: 'anemia',
      title: 'Anemia',
      shortDesc: 'Non-invasive anemia screening from multiple signals',
      longDesc:
          'Anemia is reduced hemoglobin or red blood cell count, often from iron '
          'deficiency. MedicoScope screens via lab report (CBC, ferritin), symptoms, '
          'vitals (SpO₂ + resting HR), and conjunctival pallor analysis '
          '(photograph the inner eyelid — research-grade non-invasive Hb estimation).',
      icon: Icons.water_drop_outlined,
      gradient: [Color(0xFFFF8C61), Color(0xFFFF6B35)],
      methods: [
        DetectionMethod.labReportPdf,
        DetectionMethod.symptomQuestionnaire,
        DetectionMethod.vitalsWearable,
        DetectionMethod.conjunctivalPallor,
      ],
      datasets: [
        DatasetCitation(
          name: 'Conjunctival Pallor Anemia Dataset',
          institution: 'Emory University School of Medicine',
          country: 'USA',
          usedFor: 'Non-invasive Hb estimation from eye-lid images',
        ),
        DatasetCitation(
          name: 'AIIMS Conjunctival Pallor Validation',
          institution: 'All India Institute of Medical Sciences, New Delhi',
          country: 'India',
          usedFor: 'India-population validation of pallor-based Hb estimates',
        ),
        DatasetCitation(
          name: 'WHO Anemia Thresholds',
          institution: 'World Health Organization',
          country: 'Global',
          usedFor: 'Age-/sex-adjusted Hb cutoffs',
        ),
        DatasetCitation(
          name: 'NFHS-5',
          institution: 'Ministry of Health & Family Welfare, Govt. of India',
          country: 'India',
          usedFor: 'Prevalence baselines; 57% of Indian women are anemic',
        ),
      ],
      alertType: 'anemia_high_risk',
      prevalenceIndia: '57% of women, 67% of children (NFHS-5)',
      prevalenceUSA: '~5.6% general population (NHANES)',
    ),
  };

  static DiseaseMeta of(DiseaseType t) => meta[t]!;
}

class MethodMeta {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;

  const MethodMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });
}

class MethodRegistry {
  static const Map<DetectionMethod, MethodMeta> meta = {
    DetectionMethod.labReportPdf: MethodMeta(
      title: 'Lab Report Scanner',
      subtitle: 'Upload your pathlab PDF — we parse the markers',
      icon: Icons.picture_as_pdf_outlined,
      gradient: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
    ),
    DetectionMethod.symptomQuestionnaire: MethodMeta(
      title: 'Symptom Check',
      subtitle: 'Quick guided Q&A analysed by our medical AI',
      icon: Icons.psychology_alt_outlined,
      gradient: [Color(0xFFFFA751), Color(0xFFFFE259)],
    ),
    DetectionMethod.vitalsWearable: MethodMeta(
      title: 'Vitals / Smartwatch',
      subtitle: 'Live data from your wearable — simulation fallback',
      icon: Icons.watch_outlined,
      gradient: [Color(0xFF667EEA), Color(0xFF764BA2)],
    ),
    DetectionMethod.retinalFundus: MethodMeta(
      title: 'Retinal Fundus Scan',
      subtitle: 'Upload a retinal image for diabetic retinopathy',
      icon: Icons.remove_red_eye_outlined,
      gradient: [Color(0xFFE84A5F), Color(0xFF2A363B)],
    ),
    DetectionMethod.conjunctivalPallor: MethodMeta(
      title: 'Eyelid Pallor Scan',
      subtitle: 'Photo of your inner eyelid estimates hemoglobin',
      icon: Icons.visibility_outlined,
      gradient: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
    ),
    DetectionMethod.ppgBloodPressure: MethodMeta(
      title: 'Cuff-less BP',
      subtitle: 'Place finger on camera — PPG estimates BP',
      icon: Icons.fingerprint,
      gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    ),
  };

  static MethodMeta of(DetectionMethod m) => meta[m]!;
}
