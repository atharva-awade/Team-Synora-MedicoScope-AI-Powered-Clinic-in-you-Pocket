import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:medicoscope/core/constants/disease_constants.dart';
import 'package:medicoscope/screens/diseases/methods/_image_picker_screen.dart';
import 'package:medicoscope/services/image_pallor_analyzer.dart';

class ConjunctivalPallorScreen extends StatelessWidget {
  final String? patientId;
  const ConjunctivalPallorScreen({super.key, this.patientId});

  @override
  Widget build(BuildContext context) {
    final m = MethodRegistry.of(DetectionMethod.conjunctivalPallor);
    return ImageScreeningScreen(
      disease: DiseaseType.anemia,
      method: DetectionMethod.conjunctivalPallor,
      title: 'Eyelid Pallor Scan',
      subtitle: m.subtitle,
      icon: m.icon,
      gradient: m.gradient,
      captureHint:
          'Gently pull down your lower eyelid and capture the pink inner '
          'surface in good light. MedicoScope analyses R/G/B and HSV '
          'saturation to estimate haemoglobin using the Emory University '
          'smartphone-anemia method, validated by AIIMS. Runs on-device.',
      analyzer: (bytes) => ImagePallorAnalyzer.analyzeConjunctivalPallor(
          Uint8List.fromList(bytes)),
      patientId: patientId,
    );
  }
}
