import 'package:flutter/material.dart';
import '../models/note.dart';
import '../models/detection_params.dart';

class AppStateProvider extends ChangeNotifier {
  Map<String, dynamic> _settings = {};
  final List<String> _transcriptions = [];
  String _currentTranscription = '';
  String _currentInstrument = 'Guitar';
  
  // Store notes corresponding to each transcription
  final Map<String, List<Note>> _transcriptionNotes = {};
  final Map<String, String> _transcriptionInstruments = {};
  List<Note> _currentNotes = [];

  // Custom detection parameters (initialised from the default preset).
  DetectionParams _detectionParams = DetectionParams.high();

  Map<String, dynamic> get settings => _settings;
  List<String> get transcriptions => _transcriptions;
  String get currentTranscription => _currentTranscription;
  List<Note> get currentNotes => _currentNotes;
  String get currentInstrument => _currentInstrument;
  DetectionParams get detectionParams => _detectionParams;
  
  // Get stored instrument for a specific transcription, defaulting to Guitar
  String getInstrumentForTranscription(String transcription) {
    return _transcriptionInstruments[transcription] ?? 'Guitar';
  }
  
  // Get notes for a specific transcription
  List<Note> getNotesForTranscription(String transcription) {
    return _transcriptionNotes[transcription] ?? [];
  }

  void updateSettings(Map<String, dynamic> newSettings) {
    _settings = newSettings;
    notifyListeners();
  }

  // Detection sensitivity setting (Low/Medium/High), defaulting to High.
  String get detectionSensitivity =>
      (_settings['detectionSensitivity'] as String?) ?? 'High';

  void setDetectionSensitivity(String value) {
    _settings = {
      ..._settings,
      'detectionSensitivity': value,
    };
    // Reset custom params to the selected preset.
    _detectionParams = DetectionParams.fromPreset(value);
    notifyListeners();
  }

  /// Replace the full set of detection parameters (used for per-slider edits).
  void setDetectionParams(DetectionParams params) {
    _detectionParams = params;
    notifyListeners();
  }

  void addTranscription(String transcription, {List<Note>? notes, String? instrument}) {
    _transcriptions.add(transcription);
    if (notes != null && notes.isNotEmpty) {
      _transcriptionNotes[transcription] = notes;
    }
    if (instrument != null && instrument.isNotEmpty) {
      _transcriptionInstruments[transcription] = instrument;
      _currentInstrument = instrument;
    }
    notifyListeners();
  }

  void removeTranscription(int index) {
    if (index >= 0 && index < _transcriptions.length) {
      _transcriptions.removeAt(index);
      notifyListeners();
    }
  }

  void setCurrentTranscription(String transcription, {List<Note>? notes, String? instrument}) {
    _currentTranscription = transcription;
    if (notes != null && notes.isNotEmpty) {
      _currentNotes = notes;
    } else {
      // Try to get notes from stored transcriptions
      _currentNotes = _transcriptionNotes[transcription] ?? [];
    }
    if (instrument != null && instrument.isNotEmpty) {
      _currentInstrument = instrument;
      _transcriptionInstruments[transcription] = instrument;
    } else {
      // Fallback to stored instrument if available
      _currentInstrument = _transcriptionInstruments[transcription] ?? _currentInstrument;
    }
    notifyListeners();
  }
}