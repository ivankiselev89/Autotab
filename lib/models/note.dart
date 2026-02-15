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

  // JSON serialization
  Map<String, dynamic> toJson() => {
    'frequency': frequency,
    'noteName': noteName,
    'octave': octave,
    'startTime': startTime,
    'endTime': endTime,
    'confidence': confidence,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    frequency: json['frequency'] as int,
    noteName: json['noteName'] as String,
    octave: json['octave'] as int,
    startTime: json['startTime'] as double,
    endTime: json['endTime'] as double,
    confidence: json['confidence'] as double,
  );
}