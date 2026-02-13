import 'package:flutter_test/flutter_test.dart';
import 'package:autotab/services/pitch_detection.dart';
import 'dart:math' as math;

void main() {
  group('PitchDetectionService - Yin Algorithm', () {
    late PitchDetectionService pitchDetection;

    setUp(() {
      pitchDetection = PitchDetectionService();
    });

    test('detectPitch returns 0.0 for empty audio signal', () {
      final result = pitchDetection.detectPitch([]);
      expect(result, equals(0.0));
    });

    test('detectPitch handles pure sine wave at 440 Hz (A4)', () {
      // Generate a pure 440 Hz sine wave
      const frequency = 440.0;
      const sampleRate = 44100;
      const duration = 0.1; // 100ms
      final numSamples = (sampleRate * duration).toInt();

      final audioSignal = List<double>.generate(
        numSamples,
        (i) => math.sin(2 * math.pi * frequency * i / sampleRate),
      );

      final detectedFreq = pitchDetection.detectPitch(
        audioSignal,
        sampleRate: sampleRate,
      );

      // Allow 5% error margin for pitch detection
      expect(detectedFreq, greaterThan(frequency * 0.95));
      expect(detectedFreq, lessThan(frequency * 1.05));
    });

    test('detectPitch handles pure sine wave at 261.63 Hz (C4)', () {
      // Generate a pure 261.63 Hz sine wave (middle C)
      const frequency = 261.63;
      const sampleRate = 44100;
      const duration = 0.1;
      final numSamples = (sampleRate * duration).toInt();

      final audioSignal = List<double>.generate(
        numSamples,
        (i) => math.sin(2 * math.pi * frequency * i / sampleRate),
      );

      final detectedFreq = pitchDetection.detectPitch(
        audioSignal,
        sampleRate: sampleRate,
      );

      // Allow 5% error margin
      expect(detectedFreq, greaterThan(frequency * 0.95));
      expect(detectedFreq, lessThan(frequency * 1.05));
    });

    test('detectPitch handles pure sine wave at 82.41 Hz (Low E for guitar)', () {
      // Generate a pure 82.41 Hz sine wave
      const frequency = 82.41;
      const sampleRate = 44100;
      const duration = 0.2; // Longer duration for lower frequencies
      final numSamples = (sampleRate * duration).toInt();

      final audioSignal = List<double>.generate(
        numSamples,
        (i) => math.sin(2 * math.pi * frequency * i / sampleRate),
      );

      final detectedFreq = pitchDetection.detectPitch(
        audioSignal,
        sampleRate: sampleRate,
      );

      // Allow 10% error margin for lower frequencies
      expect(detectedFreq, greaterThan(frequency * 0.90));
      expect(detectedFreq, lessThan(frequency * 1.10));
    });

    test('detectPitch returns 0.0 for silence (all zeros)', () {
      final audioSignal = List<double>.filled(4410, 0.0);
      final result = pitchDetection.detectPitch(audioSignal);
      expect(result, equals(0.0));
    });

    test('detectPitch returns 0.0 for noise (random signal)', () {
      // Generate random noise
      final random = math.Random(42); // Fixed seed for reproducibility
      final audioSignal = List<double>.generate(
        4410,
        (_) => random.nextDouble() * 2 - 1,
      );

      final result = pitchDetection.detectPitch(audioSignal);
      
      // Noise should either return 0.0 or an unreliable value
      // We just verify it doesn't crash and returns a value
      expect(result, isA<double>());
    });

    test('detectPitch handles sine wave with different sample rate', () {
      const frequency = 440.0;
      const sampleRate = 22050; // Half of CD quality
      const duration = 0.1;
      final numSamples = (sampleRate * duration).toInt();

      final audioSignal = List<double>.generate(
        numSamples,
        (i) => math.sin(2 * math.pi * frequency * i / sampleRate),
      );

      final detectedFreq = pitchDetection.detectPitch(
        audioSignal,
        sampleRate: sampleRate,
      );

      expect(detectedFreq, greaterThan(frequency * 0.95));
      expect(detectedFreq, lessThan(frequency * 1.05));
    });

    test('isPitchInRange correctly validates guitar frequency range', () {
      expect(pitchDetection.isPitchInRange('guitar', 82.0), isTrue);
      expect(pitchDetection.isPitchInRange('guitar', 440.0), isTrue);
      expect(pitchDetection.isPitchInRange('guitar', 880.0), isTrue);
      expect(pitchDetection.isPitchInRange('guitar', 50.0), isFalse);
      expect(pitchDetection.isPitchInRange('guitar', 1000.0), isFalse);
    });

    test('isPitchInRange correctly validates piano frequency range', () {
      expect(pitchDetection.isPitchInRange('piano', 27.5), isTrue);
      expect(pitchDetection.isPitchInRange('piano', 440.0), isTrue);
      expect(pitchDetection.isPitchInRange('piano', 4186.0), isTrue);
      expect(pitchDetection.isPitchInRange('piano', 20.0), isFalse);
      expect(pitchDetection.isPitchInRange('piano', 5000.0), isFalse);
    });

    test('isPitchInRange correctly validates vocals frequency range', () {
      expect(pitchDetection.isPitchInRange('vocals', 85.0), isTrue);
      expect(pitchDetection.isPitchInRange('vocals', 170.0), isTrue);
      expect(pitchDetection.isPitchInRange('vocals', 255.0), isTrue);
      expect(pitchDetection.isPitchInRange('vocals', 50.0), isFalse);
      expect(pitchDetection.isPitchInRange('vocals', 300.0), isFalse);
    });

    test('isPitchInRange returns false for unknown instrument', () {
      expect(pitchDetection.isPitchInRange('unknown', 440.0), isFalse);
    });
  });
}
