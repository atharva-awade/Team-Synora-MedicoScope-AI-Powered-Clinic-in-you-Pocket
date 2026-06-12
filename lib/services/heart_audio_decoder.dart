import 'dart:io';
import 'dart:typed_data';

/// Decoded audio, always mono Float32 in range roughly [-1, 1].
class DecodedAudio {
  final Float32List samples;
  final int sampleRate;
  const DecodedAudio({required this.samples, required this.sampleRate});

  double get durationSeconds => samples.length / sampleRate;
}

/// Minimal WAV decoder — the `record` package produces 16-bit PCM WAV files
/// so that's the primary format we support. Also handles 32-bit float WAV
/// and mono/stereo.
class HeartAudioDecoder {
  static Future<DecodedAudio> decodeWavFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return decodeWavBytes(bytes);
  }

  static DecodedAudio decodeWavBytes(Uint8List bytes) {
    if (bytes.length < 44) {
      throw Exception('WAV too small');
    }
    final data = ByteData.sublistView(bytes);

    // RIFF header
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
      throw Exception('Not a valid WAV file');
    }

    // Walk sub-chunks to find fmt + data.
    int sampleRate = 0;
    int channels = 1;
    int bitsPerSample = 16;
    int audioFormat = 1; // 1=PCM, 3=IEEE float
    int dataOffset = 0;
    int dataSize = 0;

    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = data.getUint32(offset + 4, Endian.little);
      if (id == 'fmt ') {
        audioFormat = data.getUint16(offset + 8, Endian.little);
        channels = data.getUint16(offset + 10, Endian.little);
        sampleRate = data.getUint32(offset + 12, Endian.little);
        bitsPerSample = data.getUint16(offset + 22, Endian.little);
      } else if (id == 'data') {
        dataOffset = offset + 8;
        dataSize = size;
        break;
      }
      offset += 8 + size;
      // Chunks are word-aligned
      if (size.isOdd) offset += 1;
    }

    if (sampleRate == 0 || dataOffset == 0) {
      throw Exception('Could not parse WAV fmt/data chunks');
    }

    final samplesPerChannel = dataSize ~/ (channels * (bitsPerSample ~/ 8));
    final mono = Float32List(samplesPerChannel);

    if (audioFormat == 1 && bitsPerSample == 16) {
      // 16-bit signed little-endian PCM
      for (int i = 0; i < samplesPerChannel; i++) {
        int sum = 0;
        for (int c = 0; c < channels; c++) {
          sum += data.getInt16(
              dataOffset + (i * channels + c) * 2, Endian.little);
        }
        mono[i] = (sum / channels) / 32768.0;
      }
    } else if (audioFormat == 1 && bitsPerSample == 8) {
      for (int i = 0; i < samplesPerChannel; i++) {
        int sum = 0;
        for (int c = 0; c < channels; c++) {
          sum += bytes[dataOffset + i * channels + c] - 128;
        }
        mono[i] = (sum / channels) / 128.0;
      }
    } else if (audioFormat == 3 && bitsPerSample == 32) {
      for (int i = 0; i < samplesPerChannel; i++) {
        double sum = 0;
        for (int c = 0; c < channels; c++) {
          sum += data.getFloat32(
              dataOffset + (i * channels + c) * 4, Endian.little);
        }
        mono[i] = sum / channels;
      }
    } else if (audioFormat == 1 && bitsPerSample == 32) {
      for (int i = 0; i < samplesPerChannel; i++) {
        int sum = 0;
        for (int c = 0; c < channels; c++) {
          sum += data.getInt32(
              dataOffset + (i * channels + c) * 4, Endian.little);
        }
        mono[i] = (sum / channels) / 2147483648.0;
      }
    } else {
      throw Exception(
          'Unsupported WAV format: fmt=$audioFormat bits=$bitsPerSample');
    }

    return DecodedAudio(samples: mono, sampleRate: sampleRate);
  }

  /// Linear-interpolation resample to [targetRate]. Good enough for speech /
  /// PCG classification where we don't need anti-aliasing precision.
  static Float32List resample(Float32List src, int srcRate, int targetRate) {
    if (srcRate == targetRate) return src;
    final ratio = targetRate / srcRate;
    final outLen = (src.length * ratio).floor();
    final out = Float32List(outLen);
    for (int i = 0; i < outLen; i++) {
      final srcIdx = i / ratio;
      final i0 = srcIdx.floor();
      final i1 = i0 + 1 >= src.length ? i0 : i0 + 1;
      final frac = srcIdx - i0;
      out[i] = src[i0] * (1 - frac) + src[i1] * frac;
    }
    return out;
  }
}
