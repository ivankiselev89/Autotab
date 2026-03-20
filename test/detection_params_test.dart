import 'package:flutter_test/flutter_test.dart';
import 'package:autotab/models/detection_params.dart';
import 'package:autotab/services/note_segmentation.dart';
import 'dart:math' as math;

void main() {
  group('DetectionParams', () {
    test('presets have distinct values', () {
      final low = DetectionParams.low();
      final medium = DetectionParams.medium();
      final high = DetectionParams.high();

      // Low is strictest (highest confidence threshold)
      expect(low.minYinConfidence, greaterThan(medium.minYinConfidence));
      expect(medium.minYinConfidence, greaterThan(high.minYinConfidence));

      // Low has longest min duration
      expect(low.minNoteDuration, greaterThan(medium.minNoteDuration));
      expect(medium.minNoteDuration, greaterThan(high.minNoteDuration));

      // Low has largest min gap
      expect(low.minGapSeconds, greaterThan(medium.minGapSeconds));
      expect(medium.minGapSeconds, greaterThan(high.minGapSeconds));
    });

    test('fromPreset returns correct preset', () {
      expect(DetectionParams.fromPreset('low').minYinConfidence,
          equals(DetectionParams.low().minYinConfidence));
      expect(DetectionParams.fromPreset('Medium').minYinConfidence,
          equals(DetectionParams.medium().minYinConfidence));
      expect(DetectionParams.fromPreset('HIGH').minYinConfidence,
          equals(DetectionParams.high().minYinConfidence));
      // unknown defaults to high
      expect(DetectionParams.fromPreset('unknown').minYinConfidence,
          equals(DetectionParams.high().minYinConfidence));
    });

    test('copyWith overrides individual fields', () {
      final base = DetectionParams.high();
      final modified = base.copyWith(minYinConfidence: 0.99);
      expect(modified.minYinConfidence, equals(0.99));
      // other fields remain the same
      expect(modified.minNoteDuration, equals(base.minNoteDuration));
      expect(modified.onsetFactor, equals(base.onsetFactor));
      expect(modified.repeatNoteMergeGap, equals(base.repeatNoteMergeGap));
    });

    test('toJson / fromJson round-trips', () {
      final original = DetectionParams.medium();
      final json = original.toJson();
      final restored = DetectionParams.fromJson(json);
      expect(restored.minYinConfidence, equals(original.minYinConfidence));
      expect(restored.minNoteDuration, equals(original.minNoteDuration));
      expect(restored.onsetFactor, equals(original.onsetFactor));
      expect(restored.jumpFactor, equals(original.jumpFactor));
      expect(restored.fluxFactor, equals(original.fluxFactor));
      expect(restored.minGapSeconds, equals(original.minGapSeconds));
      expect(restored.noiseReductionFactor,
          equals(original.noiseReductionFactor));
      expect(restored.noiseGateFactor, equals(original.noiseGateFactor));
      expect(restored.repeatNoteMergeGap,
          equals(original.repeatNoteMergeGap));
    });
  });

  group('Repeated note detection', () {
    late NoteSegmentationService segmentationService;

    setUp(() {
      segmentationService = NoteSegmentationService();
    });

    test('repeated same-pitch notes are not merged with low mergeGap', () {
      // Generate three separate A4 (440 Hz) notes with silence gaps.
      // With a low repeatNoteMergeGap, these should remain as 3 distinct notes.
      const frequency = 440.0;
      const sampleRate = 44100;
      const noteDuration = 0.15; // 150 ms each
      const silenceDuration = 0.08; // 80 ms gap

      final audioSignal = <double>[];
      for (int n = 0; n < 3; n++) {
        final numSamples = (sampleRate * noteDuration).toInt();
        audioSignal.addAll(
          List<double>.generate(
            numSamples,
            (i) => 0.5 * math.sin(2 * math.pi * frequency * i / sampleRate),
          ),
        );
        if (n < 2) {
          final silenceSamples = (sampleRate * silenceDuration).toInt();
          audioSignal.addAll(List<double>.filled(silenceSamples, 0.0));
        }
      }

      // Use a very small merge gap so repeated notes are NOT merged.
      final params = DetectionParams.high().copyWith(repeatNoteMergeGap: 0.0);

      final notes = segmentationService.segmentAudio(
        audioSignal,
        sampleRate: sampleRate.toDouble(),
        params: params,
      );

      // With mergeGap=0, the repeated A4 notes should be kept separate.
      // We expect at least 2 distinct A notes (onset detection may not
      // perfectly split all 3, but must not collapse into 1).
      final aNotes = notes.where((n) => n.noteName == 'A').toList();
      expect(aNotes.length, greaterThanOrEqualTo(2),
          reason: 'Repeated A4 notes should not be merged into one');
    });

    test('segmentAudio still works with explicit DetectionParams', () {
      const frequency = 440.0;
      const sampleRate = 44100;
      const duration = 0.2;
      final numSamples = (sampleRate * duration).toInt();

      final audioSignal = List<double>.generate(
        numSamples,
        (i) => 0.5 * math.sin(2 * math.pi * frequency * i / sampleRate),
      );

      final params = DetectionParams.medium();
      final notes = segmentationService.segmentAudio(
        audioSignal,
        sampleRate: sampleRate.toDouble(),
        params: params,
      );

      expect(notes, isNotEmpty);
      expect(notes.first.noteName, equals('A'));
    });
  });
}
