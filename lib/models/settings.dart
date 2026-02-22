class AppSettings {
  String selectedInstrument;
  int noiseThreshold;
  Map<String, dynamic> uiPreferences;

  AppSettings({
    required this.selectedInstrument,
    required this.noiseThreshold,
    required this.uiPreferences,
  });

  // JSON serialization
  Map<String, dynamic> toJson() => {
    'selectedInstrument': selectedInstrument,
    'noiseThreshold': noiseThreshold,
    'uiPreferences': uiPreferences,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    selectedInstrument: json['selectedInstrument'] as String,
    noiseThreshold: json['noiseThreshold'] as int,
    uiPreferences: json['uiPreferences'] as Map<String, dynamic>,
  );

  // Default settings
  factory AppSettings.defaultSettings() => AppSettings(
    selectedInstrument: 'Guitar',
    noiseThreshold: 50,
    uiPreferences: {},
  );
}