import 'dart:typed_data';
import 'dart:io';
import '../models/note.dart';
import 'dart:math' as math;

class MidiGeneratorService {
  /// Converts a list of notes to a MIDI file and saves it to the specified path.
  /// 
  /// [notes] - List of Note objects to convert
  /// [outputPath] - Path where the MIDI file will be saved
  /// [bpm] - Tempo in beats per minute (default: 120)
  /// [instrument] - MIDI instrument number (default: 0 for Acoustic Grand Piano)
  static Future<void> generateMidiFromNotes(
    List<Note> notes,
    String outputPath, {
    int bpm = 120,
    int instrument = 0,
  }) async {
    if (notes.isEmpty) {
      throw ArgumentError('Cannot generate MIDI from empty note list');
    }
    
    final midiData = _createMidiFile(notes, bpm: bpm, instrument: instrument);
    final file = File(outputPath);
    await file.writeAsBytes(midiData);
  }
  
  /// Creates a complete MIDI file as a byte array
  static Uint8List _createMidiFile(List<Note> notes, {int bpm = 120, int instrument = 0}) {
    final buffer = BytesBuilder();
    
    // MIDI Header Chunk
    buffer.add(_createHeaderChunk());
    
    // MIDI Track Chunk
    buffer.add(_createTrackChunk(notes, bpm: bpm, instrument: instrument));
    
    return buffer.toBytes();
  }
  
  /// Creates the MIDI header chunk
  /// Format: MThd <length> <format> <tracks> <division>
  static Uint8List _createHeaderChunk() {
    final buffer = BytesBuilder();
    
    // "MThd" chunk identifier
    buffer.add([0x4D, 0x54, 0x68, 0x64]);
    
    // Header length (always 6 bytes)
    buffer.add([0x00, 0x00, 0x00, 0x06]);
    
    // Format type (0 = single track)
    buffer.add([0x00, 0x00]);
    
    // Number of tracks (1)
    buffer.add([0x00, 0x01]);
    
    // Division (ticks per quarter note) - 480 is standard
    buffer.add([0x01, 0xE0]); // 480 in big-endian
    
    return buffer.toBytes();
  }
  
  /// Creates a MIDI track chunk with note events
  static Uint8List _createTrackChunk(List<Note> notes, {int bpm = 120, int instrument = 0}) {
    final trackData = BytesBuilder();
    
    // Set tempo meta event
    trackData.add(_createTempoEvent(bpm));
    
    // Set instrument (Program Change)
    trackData.add(_createProgramChangeEvent(instrument));
    
    // Sort notes by start time
    final sortedNotes = List<Note>.from(notes)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    
    // Convert notes to MIDI events
    int lastTicks = 0;
    for (final note in sortedNotes) {
      final startTicks = _secondsToTicks(note.startTime, bpm);
      final endTicks = _secondsToTicks(note.endTime, bpm);
      final duration = endTicks - startTicks;
      
      // Delta time from last event
      final deltaTime = startTicks - lastTicks;
      
      // Note On event
      trackData.add(_createNoteOnEvent(
        deltaTime,
        _frequencyToMidiNote(note.frequency.toDouble()),
        _confidenceToVelocity(note.confidence),
      ));
      
      // Note Off event
      trackData.add(_createNoteOffEvent(
        duration,
        _frequencyToMidiNote(note.frequency.toDouble()),
      ));
      
      lastTicks = endTicks;
    }
    
    // End of track meta event
    trackData.add([0x00, 0xFF, 0x2F, 0x00]);
    
    // Create track chunk header
    final buffer = BytesBuilder();
    
    // "MTrk" chunk identifier
    buffer.add([0x4D, 0x54, 0x72, 0x6B]);
    
    // Track length (4 bytes, big-endian)
    final trackBytes = trackData.toBytes();
    final length = trackBytes.length;
    buffer.add([
      (length >> 24) & 0xFF,
      (length >> 16) & 0xFF,
      (length >> 8) & 0xFF,
      length & 0xFF,
    ]);
    
    // Track data
    buffer.add(trackBytes);
    
    return buffer.toBytes();
  }
  
  /// Creates a tempo meta event
  /// Tempo is specified in microseconds per quarter note
  static List<int> _createTempoEvent(int bpm) {
    final microsecondsPerBeat = (60000000 / bpm).round();
    
    return [
      0x00, // Delta time
      0xFF, // Meta event
      0x51, // Tempo meta event type
      0x03, // Length (always 3 bytes)
      (microsecondsPerBeat >> 16) & 0xFF,
      (microsecondsPerBeat >> 8) & 0xFF,
      microsecondsPerBeat & 0xFF,
    ];
  }
  
  /// Creates a program change event to set the instrument
  static List<int> _createProgramChangeEvent(int instrument) {
    return [
      0x00, // Delta time
      0xC0, // Program change on channel 0
      instrument & 0x7F, // Instrument number (0-127)
    ];
  }
  
  /// Creates a Note On event
  static List<int> _createNoteOnEvent(int deltaTime, int midiNote, int velocity) {
    final delta = _encodeVariableLength(deltaTime);
    return [
      ...delta,
      0x90, // Note On, channel 0
      midiNote & 0x7F, // Note number (0-127)
      velocity & 0x7F, // Velocity (0-127)
    ];
  }
  
  /// Creates a Note Off event
  static List<int> _createNoteOffEvent(int deltaTime, int midiNote) {
    final delta = _encodeVariableLength(deltaTime);
    return [
      ...delta,
      0x80, // Note Off, channel 0
      midiNote & 0x7F, // Note number (0-127)
      0x40, // Velocity (64 - standard)
    ];
  }
  
  /// Encodes a value as a variable-length quantity (MIDI standard)
  static List<int> _encodeVariableLength(int value) {
    final buffer = <int>[];
    
    // Process from least significant to most significant
    buffer.add(value & 0x7F);
    value >>= 7;
    
    while (value > 0) {
      buffer.insert(0, (value & 0x7F) | 0x80);
      value >>= 7;
    }
    
    return buffer;
  }
  
  /// Converts seconds to MIDI ticks (using 480 ticks per quarter note)
  static int _secondsToTicks(double seconds, int bpm) {
    const ticksPerQuarterNote = 480;
    final secondsPerBeat = 60.0 / bpm;
    final ticksPerSecond = ticksPerQuarterNote / secondsPerBeat;
    
    return (seconds * ticksPerSecond).round();
  }
  
  /// Converts frequency to MIDI note number
  static int _frequencyToMidiNote(double frequency) {
    if (frequency <= 0) return 60; // Default to middle C
    
    // A4 = 440 Hz = MIDI note 69
    const a4Frequency = 440.0;
    const a4MidiNote = 69;
    
    final midiNote = (12 * (math.log(frequency / a4Frequency) / math.log(2)) + a4MidiNote).round();
    
    // Clamp to valid MIDI range (0-127)
    return midiNote.clamp(0, 127);
  }
  
  /// Converts confidence (0.0-1.0) to MIDI velocity (0-127)
  static int _confidenceToVelocity(double confidence) {
    // Map confidence to velocity range 40-127 (avoid very quiet notes)
    final velocity = (40 + (confidence * 87)).round();
    return velocity.clamp(40, 127);
  }
}