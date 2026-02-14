import '../models/note.dart';

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
  
  /// Generates a guitar tab from a list of notes.
  /// Returns a formatted string representing guitar tablature.
  String generateTab(List<Note> notes) {
    if (notes.isEmpty) {
      return 'No notes to generate tab from.';
    }
    
    // Initialize tab lines for each string
    final tabLines = List<String>.generate(6, (i) => '${guitarStrings[i]}|');
    
    // Group notes by time for simultaneous notes (chords)
    final groupedNotes = _groupNotesByTime(notes);
    
    // Process each time group
    for (final noteGroup in groupedNotes) {
      final fretPositions = List<String>.filled(6, '-');
      
      for (final note in noteGroup) {
        final stringFret = _findBestStringAndFret(note.frequency.toDouble());
        if (stringFret != null) {
          fretPositions[stringFret['string']!] = stringFret['fret'].toString();
        }
      }
      
      // Add positions to tab lines
      for (int i = 0; i < 6; i++) {
        tabLines[i] += fretPositions[i].padRight(3, '-');
      }
    }
    
    // Close tab lines
    for (int i = 0; i < 6; i++) {
      tabLines[i] += '|';
    }
    
    return tabLines.join('\n');
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
  Map<String, int>? _findBestStringAndFret(double frequency) {
    const maxFret = 24;
    const fretRatio = 1.059463094359; // 12th root of 2
    
    Map<String, int>? bestMatch;
    double minDifference = double.infinity;
    
    // Try each string
    for (int stringNum = 0; stringNum < 6; stringNum++) {
      final openStringFreq = guitarStringFrequencies[stringNum];
      
      // Try each fret on this string
      for (int fret = 0; fret <= maxFret; fret++) {
        final fretFreq = openStringFreq * pow(fretRatio, fret);
        final difference = (frequency - fretFreq).abs();
        
        // Find closest match
        if (difference < minDifference) {
          minDifference = difference;
          bestMatch = {'string': stringNum, 'fret': fret};
        }
      }
    }
    
    // Only return if the match is reasonably close (within 5%)
    if (bestMatch != null && minDifference / frequency < 0.05) {
      return bestMatch;
    }
    
    return null;
  }
  
  /// Helper function to calculate power
  double pow(double base, int exponent) {
    double result = 1.0;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}