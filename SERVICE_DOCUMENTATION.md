# Service Implementation Documentation

This document describes the three core services implemented for the Autotab MVP.

## Services Overview

### 1. NoteSegmentationService

**Purpose**: Segments continuous audio data into individual musical notes.

**Key Features**:
- Energy-based onset detection to identify note boundaries
- Integration with PitchDetectionService for frequency analysis
- Converts frequencies to note names and octaves
- Provides confidence scores for each detected note

**Usage Example**:
```dart
import 'package:autotab/services/note_segmentation.dart';
import 'package:autotab/models/note.dart';

final segmentationService = NoteSegmentationService();

// Audio data should be a List<double> of normalized samples (-1.0 to 1.0)
final List<double> audioData = [...]; // Your audio samples
final double sampleRate = 44100.0;

// Segment the audio
final List<Note> notes = segmentationService.segmentAudio(
  audioData,
  sampleRate: sampleRate,
);

// Process the detected notes
for (final note in notes) {
  print('Note: ${note.noteName}${note.octave}');
  print('Frequency: ${note.frequency} Hz');
  print('Start time: ${note.startTime}s');
  print('Duration: ${note.endTime - note.startTime}s');
  print('Confidence: ${(note.confidence * 100).toStringAsFixed(0)}%');
}
```

**Algorithm Details**:
- Uses a hop size of 512 samples and frame size of 2048 samples
- Detects onsets when energy increases significantly above threshold
- Minimum note duration of 0.05 seconds to filter out noise
- Frequency-to-note conversion based on A4 = 440 Hz

### 2. TabGeneratorService

**Purpose**: Converts musical notes to guitar tablature and text notation.

**Key Features**:
- Generates standard 6-string guitar tablature
- Finds optimal string/fret positions for each note
- Groups simultaneous notes into chords
- Creates formatted text notation with timing and confidence

**Usage Example**:
```dart
import 'package:autotab/services/tab_generator.dart';
import 'package:autotab/models/note.dart';

final tabGenerator = TabGeneratorService();

// Assume we have detected notes from NoteSegmentationService
final List<Note> notes = [...];

// Generate guitar tablature
final String guitarTab = tabGenerator.generateTab(notes);
print(guitarTab);
// Output:
// E|---0---2---|
// B|---1---3---|
// G|---0---2---|
// D|---2---0---|
// A|---3-------|
// E|-----------|

// Generate text notation
final String textNotation = tabGenerator.generateTextNotation(notes);
print(textNotation);
// Output:
// Musical Notation:
// ================
// Time(s)  Note   Duration(s)  Confidence
// -------  -----  -----------  ----------
// 0.00     A4     0.50         90%
// 0.60     C4     0.40         85%
```

**Guitar Tab Details**:
- Uses standard tuning (E A D G B E)
- Finds the best fret position within 5% frequency tolerance
- Groups notes within 50ms as chords
- Maximum fret range: 0-24

### 3. MidiGeneratorService

**Purpose**: Exports musical notes to standard MIDI file format.

**Key Features**:
- Complete MIDI file format implementation (SMF Format 0)
- Configurable tempo (BPM) and instrument
- Proper note timing and velocity based on confidence
- Standard-compliant MIDI output

**Usage Example**:
```dart
import 'package:autotab/services/midi_generator.dart';
import 'package:autotab/models/note.dart';

// Assume we have detected notes from NoteSegmentationService
final List<Note> notes = [...];

// Generate MIDI file
await MidiGeneratorService.generateMidiFromNotes(
  notes,
  '/path/to/output.mid',
  bpm: 120,           // Optional, defaults to 120
  instrument: 0,      // Optional, defaults to 0 (Acoustic Grand Piano)
);

// For guitar sound, use instrument 24
await MidiGeneratorService.generateMidiFromNotes(
  notes,
  '/path/to/guitar_output.mid',
  bpm: 90,
  instrument: 24,     // Acoustic Guitar (nylon)
);
```

**MIDI Details**:
- Format: SMF (Standard MIDI File) Format 0
- Division: 480 ticks per quarter note
- Velocity range: 40-127 (based on note confidence)
- Supports standard MIDI instrument numbers (0-127)

**Common MIDI Instruments**:
- 0: Acoustic Grand Piano
- 24: Acoustic Guitar (nylon)
- 25: Acoustic Guitar (steel)
- 32: Acoustic Bass
- 40: Violin
- 56: Trumpet

## Integration Workflow

Here's how all three services work together in a complete music transcription workflow:

```dart
import 'package:autotab/services/note_segmentation.dart';
import 'package:autotab/services/tab_generator.dart';
import 'package:autotab/services/midi_generator.dart';

Future<void> transcribeAudio(List<double> audioData, double sampleRate) async {
  // Step 1: Segment audio into notes
  final segmentationService = NoteSegmentationService();
  final notes = segmentationService.segmentAudio(
    audioData,
    sampleRate: sampleRate,
  );
  
  print('Detected ${notes.length} notes');
  
  // Step 2: Generate guitar tab
  final tabGenerator = TabGeneratorService();
  final guitarTab = tabGenerator.generateTab(notes);
  print('Guitar Tab:\n$guitarTab');
  
  // Step 3: Generate text notation
  final textNotation = tabGenerator.generateTextNotation(notes);
  print('\n$textNotation');
  
  // Step 4: Export to MIDI
  await MidiGeneratorService.generateMidiFromNotes(
    notes,
    '/tmp/transcription.mid',
    bpm: 120,
    instrument: 24, // Guitar
  );
  
  print('\nMIDI file saved to /tmp/transcription.mid');
}
```

## Testing

Each service has comprehensive unit tests:

- `test/note_segmentation_test.dart`: Tests for audio segmentation
- `test/tab_generator_test.dart`: Tests for tab generation
- `test/midi_generator_test.dart`: Tests for MIDI export

Run tests with:
```bash
flutter test
```

## Future Enhancements

Potential improvements for future versions:

1. **NoteSegmentationService**:
   - Support for polyphonic audio (multiple simultaneous notes)
   - Advanced onset detection using spectral flux
   - Vibrato and bend detection
   - Dynamic threshold adjustment

2. **TabGeneratorService**:
   - Support for different tunings (Drop D, Open G, etc.)
   - Fingering optimization for playability
   - Support for other stringed instruments (bass, ukulele)
   - Rhythm notation (quarter notes, eighth notes, etc.)

3. **MidiGeneratorService**:
   - Support for multiple tracks
   - Pitch bend and modulation events
   - Program change events for different instruments per track
   - Time signature and key signature meta events

## Dependencies

These services depend on:
- `models/note.dart`: Note data model
- `services/pitch_detection.dart`: Yin pitch detection algorithm (for NoteSegmentationService)
- Dart standard library (`dart:math`, `dart:io`, `dart:typed_data`)

No external packages are required for the core functionality.
