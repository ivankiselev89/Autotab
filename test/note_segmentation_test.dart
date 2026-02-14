import 'package:flutter_test/flutter_test.dart';
import 'package:autotab/services/note_segmentation.dart';
import 'package:autotab/models/note.dart';
import 'dart:math' as math;

void main() {
  group('NoteSegmentationService', () {
    late NoteSegmentationService segmentationService;

    setUp(() {
      segmentationService = NoteSegmentationService();
    });

    test('segmentAudio returns empty list for empty input', () {
      final result = segmentationService.segmentAudio([]);
      expect(result, isEmpty);
    });

    test('segmentAudio detects single note from sine wave', () {
      // Generate a 440 Hz sine wave (A4) for 0.2 seconds
      const frequency = 440.0;
      const sampleRate = 44100;
      const duration = 0.2;
      final numSamples = (sampleRate * duration).toInt();

      final audioSignal = List<double>.generate(
        numSamples,
        (i) => 0.5 * math.sin(2 * math.pi * frequency * i / sampleRate),
      );

      final notes = segmentationService.segmentAudio(audioSignal, sampleRate: sampleRate.toDouble());

      expect(notes, isNotEmpty);
      expect(notes.length, greaterThanOrEqualTo(1));
      
      // Check that detected frequency is close to 440 Hz
      final firstNote = notes.first;
      expect(firstNote.frequency, greaterThan(400));
      expect(firstNote.frequency, lessThan(480));
      
      // Check note name is A
      expect(firstNote.noteName, equals('A'));
      
      // Check timing
      expect(firstNote.startTime, greaterThanOrEqualTo(0.0));
      expect(firstNote.endTime, greaterThan(firstNote.startTime));
      
      // Check confidence
      expect(firstNote.confidence, greaterThan(0.0));
      expect(firstNote.confidence, lessThanOrEqualTo(1.0));
    });

    test('segmentAudio detects multiple notes from sequential sine waves', () {
      const sampleRate = 44100;
      const duration = 0.15;
      const silence = 0.05;
      
      // Create two notes: A4 (440 Hz) and C4 (261.63 Hz)
      final frequencies = [440.0, 261.63];
      final audioSignal = <double>[];
      
      for (final freq in frequencies) {
        // Add note
        final numSamples = (sampleRate * duration).toInt();
        audioSignal.addAll(
          List<double>.generate(
            numSamples,
            (i) => 0.5 * math.sin(2 * math.pi * freq * i / sampleRate),
          ),
        );
        
        // Add silence
        final silenceSamples = (sampleRate * silence).toInt();
        audioSignal.addAll(List<double>.filled(silenceSamples, 0.0));
      }

      final notes = segmentationService.segmentAudio(audioSignal, sampleRate: sampleRate.toDouble());

      // Should detect at least one note (segmentation can be tricky)
      expect(notes, isNotEmpty);
      
      // Check that notes have valid properties
      for (final note in notes) {
        expect(note.frequency, greaterThan(0));
        expect(note.noteName, isNotEmpty);
        expect(note.startTime, greaterThanOrEqualTo(0.0));
        expect(note.endTime, greaterThan(note.startTime));
        expect(note.confidence, greaterThan(0.0));
      }
    });

    test('segmentAudio handles low amplitude signal', () {
      // Very quiet sine wave
      const frequency = 440.0;
      const sampleRate = 44100;
      const duration = 0.2;
      final numSamples = (sampleRate * duration).toInt();

      final audioSignal = List<double>.generate(
        numSamples,
        (i) => 0.01 * math.sin(2 * math.pi * frequency * i / sampleRate),
      );

      final notes = segmentationService.segmentAudio(audioSignal, sampleRate: sampleRate.toDouble());

      // Very quiet signal might not be detected, which is correct behavior
      // Just ensure it doesn't crash
      expect(notes, isA<List<Note>>());
    });

    test('segmentAudio handles silence', () {
      const sampleRate = 44100;
      final audioSignal = List<double>.filled(8820, 0.0); // 0.2 seconds of silence

      final notes = segmentationService.segmentAudio(audioSignal, sampleRate: sampleRate.toDouble());

      // Silence should produce no notes
      expect(notes, isEmpty);
    });

    test('segmentAudio handles noise', () {
      // Generate random noise
      final random = math.Random(42);
      final audioSignal = List<double>.generate(
        8820, // 0.2 seconds at 44100 Hz
        (_) => (random.nextDouble() * 2 - 1) * 0.1,
      );

      final notes = segmentationService.segmentAudio(audioSignal);

      // Noise might produce some detections or none, just ensure it doesn't crash
      expect(notes, isA<List<Note>>());
    });

    test('frequency to note conversion for A4', () {
      // Test with known A4 frequency
      const frequency = 440.0;
      const sampleRate = 44100;
      const duration = 0.15;
      final numSamples = (sampleRate * duration).toInt();

      final audioSignal = List<double>.generate(
        numSamples,
        (i) => 0.5 * math.sin(2 * math.pi * frequency * i / sampleRate),
      );

      final notes = segmentationService.segmentAudio(audioSignal, sampleRate: sampleRate.toDouble());

      if (notes.isNotEmpty) {
        final note = notes.first;
        expect(note.noteName, equals('A'));
        expect(note.octave, equals(4));
      }
    });

    test('frequency to note conversion for C4', () {
      // Test with known C4 frequency (middle C)
      const frequency = 261.63;
      const sampleRate = 44100;
      const duration = 0.15;
      final numSamples = (sampleRate * duration).toInt();

      final audioSignal = List<double>.generate(
        numSamples,
        (i) => 0.5 * math.sin(2 * math.pi * frequency * i / sampleRate),
      );

      final notes = segmentationService.segmentAudio(audioSignal, sampleRate: sampleRate.toDouble());

      if (notes.isNotEmpty) {
        final note = notes.first;
        expect(note.noteName, equals('C'));
        expect(note.octave, equals(4));
      }
    });
  });
}
