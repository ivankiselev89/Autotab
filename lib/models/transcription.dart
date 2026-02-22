class Transcription {
  final String id;
  final String name;
  final String instrumentType;
  final List<String> notes;
  final Map<String, dynamic> metadata;

  Transcription({
    required this.id,
    required this.name,
    required this.instrumentType,
    required this.notes,
    required this.metadata,
  });

  // JSON serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'instrumentType': instrumentType,
    'notes': notes,
    'metadata': metadata,
  };

  factory Transcription.fromJson(Map<String, dynamic> json) => Transcription(
    id: json['id'] as String,
    name: json['name'] as String,
    instrumentType: json['instrumentType'] as String,
    notes: (json['notes'] as List).cast<String>(),
    metadata: json['metadata'] as Map<String, dynamic>,
  );
}