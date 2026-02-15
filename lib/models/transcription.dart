class Transcription {
  final String id;
  final String name;
  final String instrumentType;
  final int bpm;
  final List<String> notes;
  final Map<String, dynamic> metadata;

  Transcription({
    required this.id,
    required this.name,
    required this.instrumentType,
    required this.bpm,
    required this.notes,
    required this.metadata,
  });

  // JSON serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'instrumentType': instrumentType,
    'bpm': bpm,
    'notes': notes,
    'metadata': metadata,
  };

  factory Transcription.fromJson(Map<String, dynamic> json) => Transcription(
    id: json['id'] as String,
    name: json['name'] as String,
    instrumentType: json['instrumentType'] as String,
    bpm: json['bpm'] as int,
    notes: (json['notes'] as List).cast<String>(),
    metadata: json['metadata'] as Map<String, dynamic>,
  );
}