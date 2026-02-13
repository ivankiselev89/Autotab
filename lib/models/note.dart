class Note {
  int frequency;
  String noteName;
  int octave;
  double startTime;
  double endTime;
  double confidence;

  Note({
    required this.frequency,
    required this.noteName,
    required this.octave,
    required this.startTime,
    required this.endTime,
    required this.confidence,
  });
}