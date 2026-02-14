import 'package:flutter_test/flutter_test.dart';
import 'package:autotab/services/tab_generator.dart';
import 'package:autotab/models/note.dart';

void main() {
  group('TabGeneratorService', () {
    late TabGeneratorService tabGenerator;

    setUp(() {
      tabGenerator = TabGeneratorService();
    });

    test('generateTab returns message for empty note list', () {
      final result = tabGenerator.generateTab([]);
      expect(result, contains('No notes'));
    });

    test('generateTab generates valid tab structure', () {
      final notes = [
        Note(
          frequency: 330, // E4
          noteName: 'E',
          octave: 4,
          startTime: 0.0,
          endTime: 0.5,
          confidence: 0.9,
        ),
      ];

      final tab = tabGenerator.generateTab(notes);

      // Check that tab has 6 lines (one for each guitar string)
      final lines = tab.split('\n');
      expect(lines.length, equals(6));

      // Check that each line starts with a string name
      expect(lines[0], startsWith('E|'));
      expect(lines[1], startsWith('A|'));
      expect(lines[2], startsWith('D|'));
      expect(lines[3], startsWith('G|'));
      expect(lines[4], startsWith('B|'));
      expect(lines[5], startsWith('E|'));

      // Check that lines end with |
      for (final line in lines) {
        expect(line, endsWith('|'));
      }
    });

    test('generateTab handles multiple notes', () {
      final notes = [
        Note(
          frequency: 330, // E4
          noteName: 'E',
          octave: 4,
          startTime: 0.0,
          endTime: 0.5,
          confidence: 0.9,
        ),
        Note(
          frequency: 440, // A4
          noteName: 'A',
          octave: 4,
          startTime: 0.6,
          endTime: 1.0,
          confidence: 0.85,
        ),
      ];

      final tab = tabGenerator.generateTab(notes);
      
      // Should have 6 lines
      final lines = tab.split('\n');
      expect(lines.length, equals(6));

      // Each line should have content between the pipes
      for (final line in lines) {
        expect(line.length, greaterThan(3)); // More than just "X|"
      }
    });

    test('generateTab handles chord (simultaneous notes)', () {
      // Create a C major chord: C E G
      final notes = [
        Note(
          frequency: 262, // C4
          noteName: 'C',
          octave: 4,
          startTime: 0.0,
          endTime: 0.5,
          confidence: 0.9,
        ),
        Note(
          frequency: 330, // E4
          noteName: 'E',
          octave: 4,
          startTime: 0.01, // Almost simultaneous
          endTime: 0.5,
          confidence: 0.9,
        ),
        Note(
          frequency: 392, // G4
          noteName: 'G',
          octave: 4,
          startTime: 0.02, // Almost simultaneous
          endTime: 0.5,
          confidence: 0.9,
        ),
      ];

      final tab = tabGenerator.generateTab(notes);
      
      // Should have 6 lines
      final lines = tab.split('\n');
      expect(lines.length, equals(6));
    });

    test('generateTextNotation returns message for empty note list', () {
      final result = tabGenerator.generateTextNotation([]);
      expect(result, contains('No notes'));
    });

    test('generateTextNotation generates valid notation', () {
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

      final notation = tabGenerator.generateTextNotation(notes);

      // Check for header
      expect(notation, contains('Musical Notation'));
      expect(notation, contains('Time(s)'));
      expect(notation, contains('Note'));
      expect(notation, contains('Duration(s)'));
      expect(notation, contains('Confidence'));

      // Check for note data
      expect(notation, contains('A4'));
      expect(notation, contains('0.50')); // Duration
      expect(notation, contains('%')); // Confidence percentage
    });

    test('generateTextNotation handles multiple notes', () {
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
          endTime: 1.2,
          confidence: 0.8,
        ),
      ];

      final notation = tabGenerator.generateTextNotation(notes);

      // Check that both notes are present
      expect(notation, contains('A4'));
      expect(notation, contains('C4'));

      // Should have multiple lines (header + notes)
      final lines = notation.split('\n');
      expect(lines.length, greaterThanOrEqualTo(6)); // Header (4 lines) + 2 notes
    });

    test('generateTextNotation formats durations correctly', () {
      final notes = [
        Note(
          frequency: 440,
          noteName: 'A',
          octave: 4,
          startTime: 0.0,
          endTime: 1.234,
          confidence: 0.75,
        ),
      ];

      final notation = tabGenerator.generateTextNotation(notes);

      // Duration should be formatted to 2 decimal places
      expect(notation, contains('1.23'));
    });

    test('generateTextNotation formats confidence as percentage', () {
      final notes = [
        Note(
          frequency: 440,
          noteName: 'A',
          octave: 4,
          startTime: 0.0,
          endTime: 0.5,
          confidence: 0.853,
        ),
      ];

      final notation = tabGenerator.generateTextNotation(notes);

      // Confidence should be shown as percentage (85%)
      expect(notation, contains('85%'));
    });

    test('generateTextNotation handles various note names', () {
      final notes = [
        Note(
          frequency: 277,
          noteName: 'C#',
          octave: 4,
          startTime: 0.0,
          endTime: 0.5,
          confidence: 0.9,
        ),
      ];

      final notation = tabGenerator.generateTextNotation(notes);

      // Check that sharp notes are displayed correctly
      expect(notation, contains('C#4'));
    });
  });
}
