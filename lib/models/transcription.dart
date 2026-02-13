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
}