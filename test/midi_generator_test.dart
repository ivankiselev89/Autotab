import 'package:flutter_test/flutter_test.dart';
import 'package:autotab/services/midi_generator.dart';
import 'package:autotab/models/note.dart';
import 'dart:io';

void main() {
  group('MidiGeneratorService', () {
    late Directory testDir;

    setUpAll(() async {
      // Create test directory using platform-independent temp directory
      testDir = await Directory.systemTemp.createTemp('midi_tests_');
    });

    tearDownAll(() async {
      // Clean up test directory
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('generateMidiFromNotes throws error for empty note list', () async {
      final outputPath = '${testDir.path}/empty_test.mid';

      expect(
        () => MidiGeneratorService.generateMidiFromNotes([], outputPath),
        throwsArgumentError,
      );
    });

    test('generateMidiFromNotes creates a file', () async {
      final notes = [
        Note(
          frequency: 440,
          noteName: 'A',
          octave: 4,
          startTime: 0.0,
          endTime: 0.5,
          confidence: 0.9,
        ),
      ];

      final outputPath = '${testDir.path}/single_note.mid';

      await MidiGeneratorService.generateMidiFromNotes(notes, outputPath);

      // Check that file was created
      final file = File(outputPath);
      expect(await file.exists(), isTrue);

      // Check that file has content
      final bytes = await file.readAsBytes();
      expect(bytes, isNotEmpty);
    });

    test('generateMidiFromNotes creates valid MIDI header', () async {
      final notes = [
        Note(
          frequency: 440,
          noteName: 'A',
          octave: 4,
          startTime: 0.0,
          endTime: 0.5,
          confidence: 0.9,
        ),
      ];

      final outputPath = '${testDir.path}/header_test.mid';

      await MidiGeneratorService.generateMidiFromNotes(notes, outputPath);

      final file = File(outputPath);
      final bytes = await file.readAsBytes();

      // Check MIDI header signature "MThd"
      expect(bytes[0], equals(0x4D)); // 'M'
      expect(bytes[1], equals(0x54)); // 'T'
      expect(bytes[2], equals(0x68)); // 'h'
      expect(bytes[3], equals(0x64)); // 'd'

      // Check header length (should be 6)
      expect(bytes[4], equals(0x00));
      expect(bytes[5], equals(0x00));
      expect(bytes[6], equals(0x00));
      expect(bytes[7], equals(0x06));
    });

    test('generateMidiFromNotes creates valid MIDI track', () async {
      final notes = [
        Note(
          frequency: 440,
          noteName: 'A',
          octave: 4,
          startTime: 0.0,
          endTime: 0.5,
          confidence: 0.9,
        ),
      ];

      final outputPath = '${testDir.path}/track_test.mid';

      await MidiGeneratorService.generateMidiFromNotes(notes, outputPath);

      final file = File(outputPath);
      final bytes = await file.readAsBytes();

      // Find "MTrk" track header
      bool foundTrack = false;
      for (int i = 0; i < bytes.length - 3; i++) {
        if (bytes[i] == 0x4D &&
            bytes[i + 1] == 0x54 &&
            bytes[i + 2] == 0x72 &&
            bytes[i + 3] == 0x6B) {
          foundTrack = true;
          break;
        }
      }

      expect(foundTrack, isTrue, reason: 'MIDI file should contain MTrk chunk');
    });

    test('generateMidiFromNotes handles multiple notes', () async {
      final notes = [
        Note(
          frequency: 440,
          noteName: 'A',
          octave: 4,
          startTime: 0.0,
          endTime: 0.5,
          confidence: 0.9,
        ),
        Note(
          frequency: 262,
          noteName: 'C',
          octave: 4,
          startTime: 0.6,
          endTime: 1.0,
          confidence: 0.85,
        ),
        Note(
          frequency: 330,
          noteName: 'E',
          octave: 4,
          startTime: 1.1,
          endTime: 1.5,
          confidence: 0.8,
        ),
      ];

      final outputPath = '${testDir.path}/multiple_notes.mid';

      await MidiGeneratorService.generateMidiFromNotes(notes, outputPath);

      final file = File(outputPath);
      expect(await file.exists(), isTrue);

      final bytes = await file.readAsBytes();
      // File should be larger with more notes
      expect(bytes.length, greaterThan(100));
    });

    test('generateMidiFromNotes respects BPM setting', () async {
      final notes = [
        Note(
          frequency: 440,
          noteName: 'A',
          octave: 4,
          startTime: 0.0,
          endTime: 0.5,
          confidence: 0.9,
        ),
      ];

      final outputPath1 = '${testDir.path}/bpm_120.mid';
      final outputPath2 = '${testDir.path}/bpm_180.mid';

      await MidiGeneratorService.generateMidiFromNotes(notes, outputPath1, bpm: 120);
      await MidiGeneratorService.generateMidiFromNotes(notes, outputPath2, bpm: 180);

      final file1 = File(outputPath1);
      final file2 = File(outputPath2);

      expect(await file1.exists(), isTrue);
      expect(await file2.exists(), isTrue);

      // Both files should be created successfully
      final bytes1 = await file1.readAsBytes();
      final bytes2 = await file2.readAsBytes();

      expect(bytes1, isNotEmpty);
      expect(bytes2, isNotEmpty);
    });

    test('generateMidiFromNotes respects instrument setting', () async {
      final notes = [
        Note(
          frequency: 440,
          noteName: 'A',
          octave: 4,
          startTime: 0.0,
          endTime: 0.5,
          confidence: 0.9,
        ),
      ];

      final outputPath = '${testDir.path}/instrument_test.mid';

      // Use instrument 24 (Acoustic Guitar)
      await MidiGeneratorService.generateMidiFromNotes(
        notes,
        outputPath,
        instrument: 24,
      );

      final file = File(outputPath);
      expect(await file.exists(), isTrue);
    });

    test('generateMidiFromNotes handles various frequencies', () async {
      final notes = [
        Note(
          frequency: 82, // Low E
          noteName: 'E',
          octave: 2,
          startTime: 0.0,
          endTime: 0.5,
          confidence: 0.9,
        ),
        Note(
          frequency: 4186, // High C
          noteName: 'C',
          octave: 8,
          startTime: 0.6,
          endTime: 1.0,
          confidence: 0.85,
        ),
      ];

      final outputPath = '${testDir.path}/frequency_range.mid';

      await MidiGeneratorService.generateMidiFromNotes(notes, outputPath);

      final file = File(outputPath);
      expect(await file.exists(), isTrue);
    });

    test('generateMidiFromNotes handles overlapping notes', () async {
      final notes = [
        Note(
          frequency: 440,
          noteName: 'A',
          octave: 4,
          startTime: 0.0,
          endTime: 1.0,
          confidence: 0.9,
        ),
        Note(
          frequency: 330,
          noteName: 'E',
          octave: 4,
          startTime: 0.5,
          endTime: 1.5,
          confidence: 0.85,
        ),
      ];

      final outputPath = '${testDir.path}/overlapping_notes.mid';

      await MidiGeneratorService.generateMidiFromNotes(notes, outputPath);

      final file = File(outputPath);
      expect(await file.exists(), isTrue);
    });

    test('generateMidiFromNotes handles different confidence levels', () async {
      final notes = [
        Note(
          frequency: 440,
          noteName: 'A',
          octave: 4,
          startTime: 0.0,
          endTime: 0.5,
          confidence: 0.3, // Low confidence
        ),
        Note(
          frequency: 440,
          noteName: 'A',
          octave: 4,
          startTime: 0.6,
          endTime: 1.0,
          confidence: 1.0, // High confidence
        ),
      ];

      final outputPath = '${testDir.path}/confidence_test.mid';

      await MidiGeneratorService.generateMidiFromNotes(notes, outputPath);

      final file = File(outputPath);
      expect(await file.exists(), isTrue);
    });
  });
}
