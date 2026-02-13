class AppSettings {
  String selectedInstrument;
  int bpm;
  int noiseThreshold;
  Map<String, dynamic> uiPreferences;

  AppSettings({
    required this.selectedInstrument,
    required this.bpm,
    required this.noiseThreshold,
    required this.uiPreferences,
  });
}