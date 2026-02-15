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

  // JSON serialization
  Map<String, dynamic> toJson() => {
    'selectedInstrument': selectedInstrument,
    'bpm': bpm,
    'noiseThreshold': noiseThreshold,
    'uiPreferences': uiPreferences,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    selectedInstrument: json['selectedInstrument'] as String,
    bpm: json['bpm'] as int,
    noiseThreshold: json['noiseThreshold'] as int,
    uiPreferences: json['uiPreferences'] as Map<String, dynamic>,
  );

  // Default settings
  factory AppSettings.defaultSettings() => AppSettings(
    selectedInstrument: 'Guitar',
    bpm: 120,
    noiseThreshold: 50,
    uiPreferences: {},
  );
}