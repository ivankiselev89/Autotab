import '../models/note.dart';
import 'dart:math' as math;

class TabGeneratorService {
  // Guitar tuning (standard tuning: E A D G B E)
  static const List<String> guitarStrings = ['E', 'A', 'D', 'G', 'B', 'E'];
  static const List<double> guitarStringFrequencies = [
    82.41,  // E2
    110.00, // A2
    146.83, // D3
    196.00, // G3
    246.94, // B3
    329.63, // E4
  ];
  
  // 5-string banjo in standard open G tuning (g D G B D)
  // Internal order is from lowest pitch to highest pitch; rendering
  // reverses this to show highest string on top.
  static const List<String> banjoStrings = ['D', 'G', 'B', 'D', 'g'];
  static const List<double> banjoStringFrequencies = [
    146.83, // D3
    196.00, // G3
    246.94, // B3
    293.66, // D4
    392.00, // g4 (5th string, short drone)
  ];
  
  // 4-string bass guitar in standard tuning (E1 A1 D2 G2)
  // Internal order is from lowest pitch to highest pitch; rendering
  // reverses this to show highest string (G) on top.
  static const List<String> bassStrings = ['E', 'A', 'D', 'G'];
  static const List<double> bassStringFrequencies = [
    41.20,  // E1
    55.00,  // A1
    73.42,  // D2
    98.00,  // G2
  ];
  
  // 4-string violin in standard tuning (G3 D4 A4 E5)
  // Internal order is from lowest pitch to highest pitch; rendering
  // reverses this to show highest string (E) on top.
  static const List<String> violinStrings = ['G', 'D', 'A', 'E'];
  static const List<double> violinStringFrequencies = [
    196.00, // G3
    293.66, // D4
    440.00, // A4
    659.26, // E5
  ];
  
  /// Generates a guitar tab from a list of notes.
  /// Returns a formatted string representing guitar tablature.
  String generateTab(List<Note> notes, {String instrument = 'guitar'}) {
    if (notes.isEmpty) {
      return 'No notes to generate tab from.';
    }
    
    final lowerInstrument = instrument.toLowerCase();
    final isBanjo = lowerInstrument == 'banjo';
    final isBass = lowerInstrument == 'bass' || lowerInstrument == 'bass guitar';
    final isViolin = lowerInstrument == 'violin';

    final List<String> strings;
    final List<double> stringFrequencies;

    if (isBanjo) {
      strings = banjoStrings;
      stringFrequencies = banjoStringFrequencies;
    } else if (isBass) {
      strings = bassStrings;
      stringFrequencies = bassStringFrequencies;
    } else if (isViolin) {
      strings = violinStrings;
      stringFrequencies = violinStringFrequencies;
    } else {
      strings = guitarStrings;
      stringFrequencies = guitarStringFrequencies;
    }
    final stringCount = strings.length;

    // Initialize tab lines for each string
    final tabLines = List<String>.generate(stringCount, (i) => '${strings[i]}|');
    
    // Group notes by time for simultaneous notes (chords)
    final groupedNotes = _groupNotesByTime(notes);
    
    // Process each time group
    for (final noteGroup in groupedNotes) {
      final fretPositions = List<String>.filled(stringCount, '-');
      
      for (final note in noteGroup) {
        final stringFret = _findBestStringAndFret(note.frequency.toDouble(), stringFrequencies);
        if (stringFret != null) {
          fretPositions[stringFret['string']!] = stringFret['fret'].toString();
        }
      }
      
      // Add positions to tab lines
      for (int i = 0; i < stringCount; i++) {
        tabLines[i] += fretPositions[i].padRight(3, '-');
      }
    }
    
    // Close tab lines
    for (int i = 0; i < stringCount; i++) {
      tabLines[i] += '|';
    }

    // Standard guitar/bass tab notation shows the highest-pitched string
    // on the top line and the lowest-pitched string on the bottom line,
    // so for those instruments we render in reverse order.
    //
    // For 5-string banjo, the short high "g" string is physically
    // closest to the player and conventionally shown on the *bottom*
    // line in some tab styles, so we keep the internal low->high order
    // and do NOT reverse.
    if (isBanjo) {
      return tabLines.join('\n');
    }

    return tabLines.reversed.join('\n');
  }
  
  /// Generates simple text notation from a list of notes.
  /// Returns a formatted string with note names, octaves, and timing.
  String generateTextNotation(List<Note> notes) {
    if (notes.isEmpty) {
      return 'No notes to generate notation from.';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('Musical Notation:');
    buffer.writeln('================');
    buffer.writeln('Time(s)  Note   Duration(s)  Confidence');
    buffer.writeln('-------  -----  -----------  ----------');
    
    for (final note in notes) {
      final duration = note.endTime - note.startTime;
      final timeStr = note.startTime.toStringAsFixed(2).padRight(7);
      final noteStr = '${note.noteName}${note.octave}'.padRight(5);
      final durationStr = duration.toStringAsFixed(2).padRight(11);
      final confidenceStr = (note.confidence * 100).toStringAsFixed(0) + '%';
      
      buffer.writeln('$timeStr  $noteStr  $durationStr  $confidenceStr');
    }
    
    return buffer.toString();
  }
  
  /// Groups notes that occur at approximately the same time (within 50ms)
  List<List<Note>> _groupNotesByTime(List<Note> notes) {
    if (notes.isEmpty) return [];
    
    final groups = <List<Note>>[];
    final sortedNotes = List<Note>.from(notes)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    
    List<Note> currentGroup = [sortedNotes[0]];
    
    for (int i = 1; i < sortedNotes.length; i++) {
      final note = sortedNotes[i];
      final prevNote = sortedNotes[i - 1];
      
      // If notes are within 50ms, they're part of the same group (chord)
      if ((note.startTime - prevNote.startTime) < 0.05) {
        currentGroup.add(note);
      } else {
        groups.add(currentGroup);
        currentGroup = [note];
      }
    }
    
    groups.add(currentGroup);
    return groups;
  }
  
  /// Finds the best guitar string and fret position for a given frequency
  /// Returns a map with 'string' (0-5) and 'fret' (0-24) or null if out of range
  Map<String, int>? _findBestStringAndFret(double frequency, List<double> stringFrequencies) {
    const maxFret = 24;
    const fretRatio = 1.059463094359; // 12th root of 2

    // Collect all reasonable candidates (within 5% in frequency)
    final candidates = <Map<String, dynamic>>[];

    // Try each string for the provided tuning
    for (int stringNum = 0; stringNum < stringFrequencies.length; stringNum++) {
      final openStringFreq = stringFrequencies[stringNum];

      // Try each fret on this string
      for (int fret = 0; fret <= maxFret; fret++) {
        final fretFreq = openStringFreq * math.pow(fretRatio, fret);
        final difference = (frequency - fretFreq).abs();
        final relativeDiff = difference / frequency;

        // Only keep reasonably close matches
        if (relativeDiff < 0.05) {
          candidates.add({
            'string': stringNum,
            'fret': fret,
            'difference': difference,
          });
        }
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    // Prefer positions closest to the nut (lowest fret),
    // then the most accurate frequency match, then lower string index.
    candidates.sort((a, b) {
      final fretCompare = (a['fret'] as int).compareTo(b['fret'] as int);
      if (fretCompare != 0) return fretCompare;

      final diffCompare = (a['difference'] as double).compareTo(b['difference'] as double);
      if (diffCompare != 0) return diffCompare;

      return (a['string'] as int).compareTo(b['string'] as int);
    });

    final best = candidates.first;
    return {
      'string': best['string'] as int,
      'fret': best['fret'] as int,
    };
  }
}