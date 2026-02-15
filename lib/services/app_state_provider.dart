import 'package:flutter/material.dart';
import '../models/note.dart';

class AppStateProvider extends ChangeNotifier {
  Map<String, dynamic> _settings = {};
  List<String> _transcriptions = [];
  String _currentTranscription = '';
  
  // Store notes corresponding to each transcription
  Map<String, List<Note>> _transcriptionNotes = {};
  List<Note> _currentNotes = [];

  Map<String, dynamic> get settings => _settings;
  List<String> get transcriptions => _transcriptions;
  String get currentTranscription => _currentTranscription;
  List<Note> get currentNotes => _currentNotes;
  
  // Get notes for a specific transcription
  List<Note> getNotesForTranscription(String transcription) {
    return _transcriptionNotes[transcription] ?? [];
  }

  void updateSettings(Map<String, dynamic> newSettings) {
    _settings = newSettings;
    notifyListeners();
  }

  void addTranscription(String transcription, {List<Note>? notes}) {
    _transcriptions.add(transcription);
    if (notes != null && notes.isNotEmpty) {
      _transcriptionNotes[transcription] = notes;
    }
    notifyListeners();
  }

  void removeTranscription(int index) {
    if (index >= 0 && index < _transcriptions.length) {
      _transcriptions.removeAt(index);
      notifyListeners();
    }
  }

  void setCurrentTranscription(String transcription, {List<Note>? notes}) {
    _currentTranscription = transcription;
    if (notes != null && notes.isNotEmpty) {
      _currentNotes = notes;
    } else {
      // Try to get notes from stored transcriptions
      _currentNotes = _transcriptionNotes[transcription] ?? [];
    }
    notifyListeners();
  }
}