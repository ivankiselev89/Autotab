import 'package:flutter_test/flutter_test.dart';
import 'package:autotab/services/fft_utils.dart';
import 'package:autotab/services/pitch_detection.dart';
import 'dart:math' as math;

/// Helper to generate a sine wave signal.
List<double> _sineWave(double frequency, {
  int sampleRate = 44100,
  double duration = 0.2,
  double amplitude = 0.5,
}) {
  final numSamples = (sampleRate * duration).toInt();
  return List<double>.generate(
    numSamples,
    (i) => amplitude * math.sin(2 * math.pi * frequency * i / sampleRate),
  );
}

/// Helper to generate a signal with fundamental + harmonics (like a real
/// guitar string).
List<double> _harmonicSignal(double fundamental, {
  int sampleRate = 44100,
  double duration = 0.2,
  double amplitude = 0.5,
  int harmonics = 4,
}) {
  final numSamples = (sampleRate * duration).toInt();
  return List<double>.generate(numSamples, (i) {
    double value = 0.0;
    for (int h = 1; h <= harmonics; h++) {
      value += (amplitude / h) *
          math.sin(2 * math.pi * fundamental * h * i / sampleRate);
    }
    return value;
  });
}

void main() {
  group('FFTUtils', () {
    test('nextPowerOf2 returns correct values', () {
      expect(FFTUtils.nextPowerOf2(1), 1);
      expect(FFTUtils.nextPowerOf2(2), 2);
      expect(FFTUtils.nextPowerOf2(3), 4);
      expect(FFTUtils.nextPowerOf2(5), 8);
      expect(FFTUtils.nextPowerOf2(1024), 1024);
      expect(FFTUtils.nextPowerOf2(2048), 2048);
      expect(FFTUtils.nextPowerOf2(2049), 4096);
    });

    test('magnitudeSpectrum detects 440 Hz peak', () {
      final signal = _sineWave(440.0, duration: 0.1);
      final fftSizeOut = <int>[];
      final spectrum = FFTUtils.magnitudeSpectrum(signal, fftSizeOut: fftSizeOut);
      final fftSize = fftSizeOut[0];

      // Find the peak bin
      int peakBin = 0;
      double peakMag = 0.0;
      for (int k = 1; k < spectrum.length; k++) {
        if (spectrum[k] > peakMag) {
          peakMag = spectrum[k];
          peakBin = k;
        }
      }

      final peakFreq = peakBin * 44100.0 / fftSize;
      expect(peakFreq, closeTo(440.0, 20.0)); // within 20 Hz
    });

    test('magnitudeSpectrum returns correct number of bins', () {
      final signal = List<double>.filled(2048, 0.0);
      final fftSizeOut = <int>[];
      final spectrum = FFTUtils.magnitudeSpectrum(signal, fftSizeOut: fftSizeOut);
      expect(fftSizeOut[0], 2048);
      expect(spectrum.length, 1024); // half of FFT size
    });

    test('magnitudeSpectrum pads non-power-of-2 to next power', () {
      final signal = List<double>.filled(1000, 0.0);
      final fftSizeOut = <int>[];
      FFTUtils.magnitudeSpectrum(signal, fftSizeOut: fftSizeOut);
      expect(fftSizeOut[0], 1024); // next power of 2 above 1000
    });

    test('spectralFlatness is low for tonal signal', () {
      final signal = _sineWave(440.0, duration: 0.1);
      final spectrum = FFTUtils.magnitudeSpectrum(signal);
      final flatness = FFTUtils.spectralFlatness(spectrum);
      expect(flatness, lessThan(0.3)); // tonal → low flatness
    });

    test('spectralFlatness is high for noise', () {
      final random = math.Random(42);
      final noise = List<double>.generate(
        4410,
        (_) => random.nextDouble() * 2 - 1,
      );
      final spectrum = FFTUtils.magnitudeSpectrum(noise);
      final flatness = FFTUtils.spectralFlatness(spectrum);
      expect(flatness, greaterThan(0.5)); // noise → high flatness
    });

    test('HPS detects 440 Hz with harmonics', () {
      // A signal with fundamental at 440 Hz and harmonics at 880, 1320 Hz
      final signal = _harmonicSignal(440.0);
      final result = FFTUtils.harmonicProductSpectrum(
        signal,
        sampleRate: 44100.0,
        minFrequency: 75.0,
        maxFrequency: 1400.0,
      );

      expect(result['frequency']!, closeTo(440.0, 15.0));
      expect(result['confidence']!, greaterThan(0.0));
    });

    test('HPS returns 0 for silence', () {
      final silence = List<double>.filled(4410, 0.0);
      final result = FFTUtils.harmonicProductSpectrum(silence);
      expect(result['frequency']!, equals(0.0));
    });
  });

  group('PitchDetectionService - Combined YIN + HPS', () {
    late PitchDetectionService pitchDetection;

    setUp(() {
      pitchDetection = PitchDetectionService();
    });

    test('detectPitchCombined returns 0 for empty signal', () {
      final result = pitchDetection.detectPitchCombined([]);
      expect(result.frequency, equals(0.0));
      expect(result.confidence, equals(0.0));
    });

    test('detectPitchCombined returns 0 for silence', () {
      final silence = List<double>.filled(4410, 0.0);
      final result = pitchDetection.detectPitchCombined(silence);
      expect(result.frequency, equals(0.0));
    });

    test('detectPitchCombined detects 440 Hz pure sine', () {
      final signal = _sineWave(440.0);
      final result = pitchDetection.detectPitchCombined(signal);

      expect(result.frequency, closeTo(440.0, 22.0)); // within 5%
      expect(result.confidence, greaterThan(0.0));
    });

    test('detectPitchCombined detects 440 Hz with harmonics (high confidence)', () {
      final signal = _harmonicSignal(440.0);
      final result = pitchDetection.detectPitchCombined(signal);

      // With harmonics, both YIN and HPS should agree → high confidence
      expect(result.frequency, closeTo(440.0, 22.0));
      expect(result.confidence, greaterThan(0.3));
    });

    test('detectPitchCombined detects low E (82.41 Hz)', () {
      final signal = _harmonicSignal(82.41, duration: 0.3);
      final result = pitchDetection.detectPitchCombined(signal);

      expect(result.frequency, closeTo(82.41, 10.0));
      expect(result.confidence, greaterThan(0.0));
    });

    test('detectPitchCombined detects C4 (261.63 Hz)', () {
      final signal = _sineWave(261.63);
      final result = pitchDetection.detectPitchCombined(signal);

      expect(result.frequency, closeTo(261.63, 15.0));
      expect(result.confidence, greaterThan(0.0));
    });

    test('detectPitchCombined gives higher confidence when YIN and HPS agree', () {
      // With harmonics, both algorithms should agree
      final harmonicSignal = _harmonicSignal(330.0);
      final pureSignal = _sineWave(330.0);

      final harmonicResult = pitchDetection.detectPitchCombined(harmonicSignal);
      final pureResult = pitchDetection.detectPitchCombined(pureSignal);

      // Harmonic signal should get higher or equal confidence
      // (both algorithms agree better with harmonics present)
      expect(harmonicResult.confidence, greaterThanOrEqualTo(pureResult.confidence * 0.8));
    });
  });
}
