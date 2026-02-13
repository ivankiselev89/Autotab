import 'package:flutter/material.dart';

class AppStateProvider extends ChangeNotifier {
  Map<String, dynamic> _settings = {};
  List<String> _transcriptions = [];
  String _currentTranscription = '';

  Map<String, dynamic> get settings => _settings;
  List<String> get transcriptions => _transcriptions;
  String get currentTranscription => _currentTranscription;

  void updateSettings(Map<String, dynamic> newSettings) {
    _settings = newSettings;
    notifyListeners();
  }

  void addTranscription(String transcription) {
    _transcriptions.add(transcription);
    notifyListeners();
  }

  void setCurrentTranscription(String transcription) {
    _currentTranscription = transcription;
    notifyListeners();
  }
}