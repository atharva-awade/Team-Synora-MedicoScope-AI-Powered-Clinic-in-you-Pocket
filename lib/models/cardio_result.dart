class HeartRatePoint {
  final int time;
  final int bpm;

  HeartRatePoint({required this.time, required this.bpm});

  factory HeartRatePoint.fromJson(Map<String, dynamic> json) {
    return HeartRatePoint(
      time: (json['time'] ?? 0) as int,
      bpm: (json['bpm'] ?? 0) as int,
    );
  }
}

class AudioWaveform {
  final List<double> time;
  final List<double> amplitude;

  AudioWaveform({required this.time, required this.amplitude});

  factory AudioWaveform.fromJson(Map<String, dynamic> json) {
    return AudioWaveform(
      time: List<double>.from(
        (json['time'] ?? []).map((v) => (v as num).toDouble()),
      ),
      amplitude: List<double>.from(
        (json['amplitude'] ?? []).map((v) => (v as num).toDouble()),
      ),
    );
  }
}

class CardioResult {
  final String prediction;
  final double avgHeartRate;
  final List<HeartRatePoint> heartRateData;
  final AudioWaveform audioWaveform;
  final List<double> ecgData;

  CardioResult({
    required this.prediction,
    required this.avgHeartRate,
    required this.heartRateData,
    required this.audioWaveform,
    required this.ecgData,
  });

  factory CardioResult.fromJson(Map<String, dynamic> json) {
    // The API may return class ID as string ("0"-"4") or label
    String pred = json['prediction']?.toString() ?? 'Unknown';
    pred = _mapClassIdToLabel(pred);

    return CardioResult(
      prediction: pred,
      avgHeartRate: (json['avg_heart_rate'] ?? 0).toDouble(),
      heartRateData: (json['heart_rate_data'] as List? ?? [])
          .map((p) => HeartRatePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      audioWaveform: json['audio_waveform'] != null
          ? AudioWaveform.fromJson(json['audio_waveform'] as Map<String, dynamic>)
          : AudioWaveform(time: [], amplitude: []),
      ecgData: List<double>.from(
        (json['ecg_data'] ?? []).map((v) => (v as num).toDouble()),
      ),
    );
  }

  static String _mapClassIdToLabel(String pred) {
    switch (pred) {
      case '0':
        return 'Normal Heart Sound';
      case '1':
        return 'Aortic Stenosis';
      case '2':
        return 'Mitral Stenosis';
      case '3':
        return 'Mitral Regurgitation';
      case '4':
        return 'Mitral Valve Prolapse';
      default:
        return pred;
    }
  }

  String get severity {
    switch (prediction) {
      case 'Aortic Stenosis':
      case 'Mitral Stenosis':
        return 'HIGH';
      case 'Mitral Regurgitation':
        return 'MEDIUM';
      case 'Normal Heart Sound':
      case 'Mitral Valve Prolapse':
        return 'LOW';
      default:
        return 'UNKNOWN';
    }
  }

  String get recommendation {
    switch (prediction) {
      case 'Normal Heart Sound':
        return 'No action needed. Continue regular checkups.';
      case 'Aortic Stenosis':
        return 'Consult cardiologist. May need echocardiogram or valve replacement.';
      case 'Mitral Regurgitation':
        return 'Follow up with cardiologist. Monitoring and possible medication may be needed.';
      case 'Mitral Stenosis':
        return 'Urgent cardiology consultation. May require percutaneous balloon mitral valvotomy.';
      case 'Mitral Valve Prolapse':
        return 'Usually benign. Regular monitoring recommended.';
      default:
        return 'Consult a healthcare professional for further evaluation.';
    }
  }
}
