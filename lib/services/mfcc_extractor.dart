import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

/// On-device MFCC feature extractor.
///
/// Produces a fixed [nMfcc] × [nFrames] grid (flattened row-major to a 1-D
/// Float32List of length `nMfcc * nFrames`).
///
/// Pipeline — matches librosa.feature.mfcc default behaviour closely enough
/// for a screening-grade PCG classifier:
///   1. Pre-emphasis filter (0.97 coefficient).
///   2. Frame the signal using a Hann window.
///   3. FFT each frame.
///   4. Power spectrum → mel filterbank → log → DCT-II.
///
/// Design: the heart_model.tflite shipped with MedicoScope expects 2000
/// raw MFCC values. We use 40 coefficients × 50 frames = 2000 as a standard
/// PhysioNet-2016 baseline configuration; sample rate target is 8 kHz.
class MfccExtractor {
  final int sampleRate;
  final int nMfcc;
  final int nFrames;
  final int frameSize;
  final int hopSize;
  final int nMels;
  final double fMin;
  final double fMax;

  late final List<List<double>> _melFilterbank; // [nMels][frameSize/2+1]
  late final List<List<double>> _dctMatrix;     // [nMfcc][nMels]
  late final Float64List _hannWindow;
  late final FFT _fft;

  MfccExtractor({
    this.sampleRate = 8000,
    this.nMfcc = 40,
    this.nFrames = 50,
    this.frameSize = 512,
    this.hopSize = 160,
    this.nMels = 40,
    this.fMin = 0,
    double? fMax,
  }) : fMax = fMax ?? sampleRate / 2 {
    _hannWindow = _hann(frameSize);
    _melFilterbank = _buildMelFilterbank();
    _dctMatrix = _buildDctMatrix();
    _fft = FFT(frameSize);
  }

  /// Compute MFCC features for the full waveform, returning `nMfcc * nFrames`
  /// Float32 values laid out in frame-major order:
  /// `[mfcc0_frame0, mfcc1_frame0, ..., mfcc0_frame1, mfcc1_frame1, ...]`.
  Float32List compute(Float32List samples) {
    final out = Float32List(nMfcc * nFrames);

    // Pre-emphasis y[n] = x[n] - 0.97 * x[n-1]
    final pre = Float32List(samples.length);
    pre[0] = samples[0];
    for (int i = 1; i < samples.length; i++) {
      pre[i] = samples[i] - 0.97 * samples[i - 1];
    }

    // Need nFrames × hopSize + frameSize samples. Pad with zeros if short.
    final totalNeeded = (nFrames - 1) * hopSize + frameSize;
    final Float32List padded;
    if (pre.length >= totalNeeded) {
      padded = pre;
    } else {
      padded = Float32List(totalNeeded);
      for (int i = 0; i < pre.length; i++) {
        padded[i] = pre[i];
      }
      // Rest is zero-filled — classifier will see silence, which is fine.
    }

    // Frame + FFT + mel + log + DCT.
    final frame = Float64List(frameSize);
    final melEnergies = Float64List(nMels);

    for (int f = 0; f < nFrames; f++) {
      final start = f * hopSize;
      // Window × frame
      for (int n = 0; n < frameSize; n++) {
        frame[n] = padded[start + n] * _hannWindow[n];
      }

      // FFT
      final spectrum = _fft.realFft(frame);
      // Power spectrum (|Z|^2). fftea returns Float64x2List (complex).
      final halfLen = frameSize ~/ 2 + 1;
      final power = Float64List(halfLen);
      for (int k = 0; k < halfLen; k++) {
        final re = spectrum[k].x;
        final im = spectrum[k].y;
        power[k] = re * re + im * im;
      }

      // Mel filterbank × power → sum → log.
      for (int m = 0; m < nMels; m++) {
        double sum = 0;
        final filter = _melFilterbank[m];
        for (int k = 0; k < halfLen; k++) {
          sum += filter[k] * power[k];
        }
        // log with floor to avoid log(0).
        melEnergies[m] = math.log(sum + 1e-10);
      }

      // DCT-II → nMfcc coefficients.
      for (int i = 0; i < nMfcc; i++) {
        double s = 0;
        final basis = _dctMatrix[i];
        for (int m = 0; m < nMels; m++) {
          s += basis[m] * melEnergies[m];
        }
        out[f * nMfcc + i] = s;
      }
    }

    return out;
  }

  static Float64List _hann(int n) {
    final w = Float64List(n);
    for (int i = 0; i < n; i++) {
      w[i] = 0.5 * (1 - math.cos(2 * math.pi * i / (n - 1)));
    }
    return w;
  }

  List<List<double>> _buildMelFilterbank() {
    final halfLen = frameSize ~/ 2 + 1;
    final melMin = _hzToMel(fMin);
    final melMax = _hzToMel(fMax);
    // nMels + 2 mel points (to bracket each triangular filter).
    final melPoints = List<double>.generate(
        nMels + 2, (i) => melMin + (melMax - melMin) * i / (nMels + 1));
    final hzPoints = melPoints.map(_melToHz).toList();
    // Convert to FFT bin indices.
    final binPoints = hzPoints
        .map((hz) => (hz * frameSize / sampleRate).floor())
        .toList();

    final filterbank = List<List<double>>.generate(
        nMels, (_) => List<double>.filled(halfLen, 0.0));
    for (int m = 0; m < nMels; m++) {
      final left = binPoints[m];
      final center = binPoints[m + 1];
      final right = binPoints[m + 2];
      for (int k = left; k < center; k++) {
        if (k < halfLen && center > left) {
          filterbank[m][k] = (k - left) / (center - left);
        }
      }
      for (int k = center; k < right; k++) {
        if (k < halfLen && right > center) {
          filterbank[m][k] = (right - k) / (right - center);
        }
      }
    }
    return filterbank;
  }

  List<List<double>> _buildDctMatrix() {
    // Orthonormal DCT-II (matches librosa default `dct_type=2, norm='ortho'`).
    final matrix = List<List<double>>.generate(
        nMfcc, (_) => List<double>.filled(nMels, 0.0));
    for (int k = 0; k < nMfcc; k++) {
      for (int n = 0; n < nMels; n++) {
        matrix[k][n] = math.cos(math.pi * k * (2 * n + 1) / (2 * nMels));
      }
      final scale = k == 0
          ? math.sqrt(1 / nMels)
          : math.sqrt(2 / nMels);
      for (int n = 0; n < nMels; n++) {
        matrix[k][n] *= scale;
      }
    }
    return matrix;
  }

  static double _hzToMel(double hz) => 2595 * (math.log(1 + hz / 700) / math.ln10);
  static double _melToHz(double mel) => 700 * (math.pow(10, mel / 2595) - 1);
}
