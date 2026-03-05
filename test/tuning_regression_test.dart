import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:autotab/services/audio_analysis_service.dart';

// Global accumulators for a simple summary at the end of the run.
final List<String> _successfulTests = <String>[];
final List<String> _failedTests = <String>[];
final Map<String, List<String>> _detectedNotesByTest = <String, List<String>>{};

class TuningTestCase {
  final String description;
  final String wavPath;
  final String instrument; // e.g. 'Guitar', 'Bass', 'Banjo'
  final String sensitivity; // 'low' | 'medium' | 'high'
  final List<String> expectedNotes; // e.g. ['E2', 'F#2', 'G2']
  // Optional expected chords: each inner list is a set of simultaneous
  // notes that should appear together in at least one detected chord,
  // for example ['C4', 'E4', 'G4'].
  final List<List<String>> expectedChords;

  const TuningTestCase({
    required this.description,
    required this.wavPath,
    required this.instrument,
    required this.sensitivity,
    required this.expectedNotes,
    this.expectedChords = const [],
  });
}

void main() {
  group('End‑to‑end tuning regression', () {
    final analysisService = AudioAnalysisService();

    // Configure your real test cases here. Each case should point to a WAV
    // file under test_resources/tuning and list the expected note names in
    // order (note name + octave, like 'E2', 'A2', 'D3'). You can also
    // specify chords via expectedChords where each inner list is a
    // simultaneous set of notes that should be present (e.g. ['C4','E4','G4']).
    //
    const cases = <TuningTestCase>[
       TuningTestCase(
         description: 'Guitar open E string High',
         wavPath: 'test_resources/tuning/E2.wav',
         instrument: 'Guitar',
         sensitivity: 'high',
         expectedNotes: ['E2'],
       ),
       TuningTestCase(
         description: 'Guitar open E string Medium',
         wavPath: 'test_resources/tuning/E2.wav',
         instrument: 'Guitar',
         sensitivity: 'medium',
         expectedNotes: ['E2'],
       ),
       TuningTestCase(
         description: 'Guitar open E string Low',
         wavPath: 'test_resources/tuning/E2.wav',
         instrument: 'Guitar',
         sensitivity: 'low',
         expectedNotes: ['E2'],
       ),
       TuningTestCase(
         description: 'Guitar open E2 B3 High',
         wavPath: 'test_resources/tuning/E2B3.wav',
         instrument: 'Guitar',
         sensitivity: 'high',
         expectedNotes: ['E2', 'B3'],
       ),
        TuningTestCase(
         description: 'Guitar open E2 B3 medium',
         wavPath: 'test_resources/tuning/E2B3.wav',
         instrument: 'Guitar',
         sensitivity: 'medium',
         expectedNotes: ['E2', 'B3'],
       ),
       TuningTestCase(
         description: 'Guitar open E2 B3 low',
         wavPath: 'test_resources/tuning/E2B3.wav',
         instrument: 'Guitar',
         sensitivity: 'low',
         expectedNotes: ['E2', 'B3'],
       ),
         TuningTestCase(
         description: 'Guitar open B3E4C5 low',
         wavPath: 'test_resources/tuning/B3E4C5.wav',
         instrument: 'Guitar',
         sensitivity: 'low',
         expectedNotes: ['B3', 'E4', 'C5'],
       ),
        TuningTestCase(
         description: 'Guitar open B3E4C5 high',
         wavPath: 'test_resources/tuning/B3E4C5.wav',
         instrument: 'Guitar',
         sensitivity: 'high',
         expectedNotes: ['B3', 'E4', 'C5'],
       ),
        TuningTestCase(
         description: 'Guitar open B4D5E5 high',
         wavPath: 'test_resources/tuning/B4D5E5.wav',
         instrument: 'Guitar',
         sensitivity: 'high',
         expectedNotes: ['B4', 'D5', 'E5'],
       ),
        TuningTestCase(
         description: 'Guitar open B4D5E5 medium',
         wavPath: 'test_resources/tuning/B4D5E5.wav',
         instrument: 'Guitar',
         sensitivity: 'medium',
         expectedNotes: ['B4', 'D5', 'E5'],
       ),
        TuningTestCase(
         description: 'Guitar open E2A2D3G3B3E4.wav medium',
         wavPath: 'test_resources/tuning/E2A2D3G3B3E4.wav',
         instrument: 'Guitar',
         sensitivity: 'medium',
         expectedNotes: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
       ),
        TuningTestCase(
         description: 'Guitar open E2A2D3G3B3E4.wav high',
         wavPath: 'test_resources/tuning/E2A2D3G3B3E4.wav',
         instrument: 'Guitar',
         sensitivity: 'high',
         expectedNotes: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
       ),
        TuningTestCase(
         description: 'Guitar open E2A2D3G3B3E4.wav medium',
         wavPath: 'test_resources/tuning/E2A2D3G3B3E4.wav',
         instrument: 'Guitar',
         sensitivity: 'medium',
         expectedNotes: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
       ),
       TuningTestCase(
         description: 'Guitar open E2A2D3G3B3E4.wav low',
         wavPath: 'test_resources/tuning/E2A2D3G3B3E4.wav',
         instrument: 'Guitar',
         sensitivity: 'low',
         expectedNotes: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
       ),
         TuningTestCase(
         description: 'Guitar open f#4G4a4 B5C5D5 E4F4G4 A4A 4C5.wav high',
         wavPath: 'test_resources/tuning/f 4G4a4 B5C5D5 E4F4G4 A4A 4C5.wav',
         instrument: 'Guitar',
         sensitivity: 'high',
         expectedNotes: ['F#4', 'G4', 'A4', 'B5', 'C5', 'D5', 'E4', 'F4', 'G4', 'A4', 'A4', 'C5'],
       ),
         TuningTestCase(
         description: 'Guitar open f#4G4a4 B5C5D5 E4F4G4 A4A 4C5.wav medium',
         wavPath: 'test_resources/tuning/f 4G4a4 B5C5D5 E4F4G4 A4A 4C5.wav',
         instrument: 'Guitar',
         sensitivity: 'medium',
         expectedNotes: ['F#4', 'G4', 'A4', 'B5', 'C5', 'D5', 'E4', 'F4', 'G4', 'A4', 'A4', 'C5'],
       ),
       TuningTestCase(
         description: 'Guitar EM AM DM Hm.wav',
         wavPath: 'test_resources/tuning/EM AM DM Hm.wav',
         instrument: 'Guitar',
         sensitivity: 'high',
         expectedNotes: [],
         expectedChords: [
           ['E2', 'G2', 'B3'],
           ['A2', 'C3', 'E3'],
           ['A3', 'D3', 'F4'],
           ['B2', 'D3', 'F#3'],
         ],
       ),
       TuningTestCase(
         description: 'Guitar Em Gm Am Hm.wav',
         wavPath: 'test_resources/tuning/Em Gm Am Hm.wav',
         instrument: 'Guitar',
         sensitivity: 'high',
         expectedNotes: [],
         expectedChords: [
           ['E2', 'B2', 'E3'],
           ['E2', 'B2', 'E3'],
           ['G2', 'D3', 'G3'],
           ['G2', 'D3', 'G3'],
           ['A2', 'E3', 'A3'],
           ['A2', 'E3', 'A3'],
           ['B2', 'D3', 'F#3'],
           ['B2', 'D3', 'F#3'],
             ['E2', 'B2', 'E3'],
           ['E2', 'B2', 'E3'],
           ['G2', 'D3', 'G3'],
           ['G2', 'D3', 'G3'],
           ['A2', 'E3', 'A3'],
           ['A2', 'E3', 'A3'],
           ['B2', 'D3', 'F#3'],
         ],
       ),
      TuningTestCase(
         description: 'Bass E1 G1 C2 D2.wav high',
         wavPath: 'test_resources/tuning/E1 G1 C2 D2.wav',
         instrument: 'Bass',
         sensitivity: 'high',
         expectedNotes: ['E1', 'G1', 'C2', 'D2'],
       ),
        TuningTestCase(
         description: 'Bass B0E1A1D2G2.wav high',
         wavPath: 'test_resources/tuning/B0E1A1D2G2.wav',
         instrument: 'Bass',
         sensitivity: 'high',
         expectedNotes: ['B0', 'E1', 'A1', 'D2', 'G2'],
       ),
        TuningTestCase(
         description: 'Bass A1 A1 A2 A2 A1 A1 A2 A2.wav high',
         wavPath: 'test_resources/tuning/A1 A1 A2 A2 A1 A1 A2 A2.wav',
         instrument: 'Bass',
         sensitivity: 'high',
         expectedNotes: ['A1', 'A1', 'A2', 'A2', 'A1', 'A1', 'A2', 'A2'],
       ),
        TuningTestCase(
         description: 'Bass D3 E3 F3 C3 D3 E3 B2 C3 B2.wav high',
         wavPath: 'test_resources/tuning/D3 E3 F3 C3 D3 E3 B2 C3 B2.wav',
         instrument: 'Bass',
         sensitivity: 'high',
         expectedNotes: ['D3', 'E3', 'F3', 'C3', 'D3', 'E3', 'B2', 'C3', 'B2'],
       )
    ];

    if (cases.isEmpty) {
      test('no tuning regression cases configured yet', () {
        expect(cases, isEmpty,
            reason:
                'Add WAV fixtures under test_resources/tuning and populate cases in tuning_regression_test.dart');
      });
      return;
    }

    for (final testCase in cases) {
      test(testCase.description, () async {
        final file = File(testCase.wavPath);
        expect(await file.exists(), isTrue,
            reason: 'Missing WAV fixture: ${testCase.wavPath}');

        final result = await analysisService.analyzeRecording(
          testCase.wavPath,
          instrument: testCase.instrument,
          sensitivity: testCase.sensitivity,
        );

        expect(result.notes, isNotEmpty,
            reason: 'No notes detected for ${testCase.description}');

        // Capture all detected notes for this test (for logging/summary).
        final detectedSequence =
            result.notes.map((n) => '${n.noteName}${n.octave}').toList();
        _detectedNotesByTest[testCase.description] = detectedSequence;

        // Validate expected single-note sequence (if provided)
        bool notesMatch = true;
        final reasons = <String>[];

        if (testCase.expectedNotes.isNotEmpty) {
          notesMatch = _containsOrderedSubsequence(
            haystack: detectedSequence,
            needle: testCase.expectedNotes,
          );

          if (!notesMatch) {
            reasons.add(
                'Expected sequence ${testCase.expectedNotes} not found. Detected: $detectedSequence');
          }
        }

        // Validate expected chords (simultaneous notes) if provided.
        bool chordsMatch = true;
        if (testCase.expectedChords.isNotEmpty) {
          final chordGroups = _groupNotesByTime(result.notes);

          final detectedChordSets = chordGroups
              .map((group) => group
                  .map((n) => '${n.noteName}${n.octave}')
                  .toSet())
              .toList();

          for (final expectedChord in testCase.expectedChords) {
            final expectedSet = expectedChord.toSet();

            final foundMatch = detectedChordSets.any(
              (detectedSet) => expectedSet.every(detectedSet.contains),
            );

            if (!foundMatch) {
              chordsMatch = false;
              reasons.add(
                  'Expected chord $expectedChord not found. Detected chord sets: $detectedChordSets');
            }
          }
        }

        final success = notesMatch && chordsMatch;

        if (success) {
          _successfulTests.add(testCase.description);
          // Print detected notes on success to make it easy to see what
          // the pipeline produced.
          // This also serves as a quick sanity check when tuning.
          // Example output: SUCCESS [TestName]: E2, A2, D3
          //
          // Using print instead of debug log so it always shows in test
          // output.
          print('SUCCESS [${testCase.description}]: $detectedSequence');
        } else {
          _failedTests.add(testCase.description);
          print('FAIL    [${testCase.description}]: $detectedSequence');
        }

        expect(
          success,
          isTrue,
          reason: reasons.isEmpty
              ? 'Tuning regression failed for ${testCase.description}'
              : reasons.join('\n'),
        );
      });
    }

    tearDownAll(() {
      print('');
      print('==== TUNING REGRESSION SUMMARY ====');
      print('Total tests   : ${_successfulTests.length + _failedTests.length}');
      print('Succeeded     : ${_successfulTests.length}');
      print('Failed        : ${_failedTests.length}');

      if (_successfulTests.isNotEmpty) {
        print('\nSuccessful tests and detected notes:');
        for (final name in _successfulTests) {
          final notes = _detectedNotesByTest[name] ?? const <String>[];
          print('  ✔ $name -> $notes');
        }
      }

      if (_failedTests.isNotEmpty) {
        print('\nFailed tests and detected notes:');
        for (final name in _failedTests) {
          final notes = _detectedNotesByTest[name] ?? const <String>[];
          print('  ✘ $name -> $notes');
        }
      }

      print('====================================');
    });
  });
}

// Simple time-based grouping similar to what the tab generator uses:
// notes whose start times are within 50 ms of each other are
// considered part of the same chord.
List<List<dynamic>> _groupNotesByTime(List<dynamic> notes) {
  if (notes.isEmpty) return [];

  final sorted = List<dynamic>.from(notes)
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  final groups = <List<dynamic>>[];
  var currentGroup = <dynamic>[sorted.first];

  for (var i = 1; i < sorted.length; i++) {
    final note = sorted[i];
    final prev = sorted[i - 1];

    if ((note.startTime - prev.startTime) < 0.05) {
      currentGroup.add(note);
    } else {
      groups.add(currentGroup);
      currentGroup = <dynamic>[note];
    }
  }

  groups.add(currentGroup);
  return groups;
}

bool _containsOrderedSubsequence({
  required List<String> haystack,
  required List<String> needle,
}) {
  if (needle.isEmpty) return true;
  int i = 0;
  for (final value in haystack) {
    if (value == needle[i]) {
      i++;
      if (i == needle.length) return true;
    }
  }
  return false;
}
