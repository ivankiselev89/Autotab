import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  // Private constructor
  AudioService._();

  // Singleton instance
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;

  // Stream controller for audio levels
  final StreamController<double> _audioLevelController = StreamController<double>.broadcast();
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  
  Timer? _audioLevelTimer;
  bool _isRecording = false;

  // Method to check and request microphone permission
  Future<bool> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      var result = await Permission.microphone.request();
      return result.isGranted;
    }
    return true;
  }

  // Method to start recording
  Future<void> startRecording() async {
    if (await _requestMicrophonePermission()) {
      // Implement the logic to start recording
      // For example: await recorder.start();
      _isRecording = true;
      _startAudioLevelSimulation();
      print('Recording started...');
    } else {
      print('Microphone permission denied.');
    }
  }

  // Simulate audio levels for visualization
  void _startAudioLevelSimulation() {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (_isRecording) {
        // Generate random audio level for demonstration
        final random = Random();
        final level = 0.2 + random.nextDouble() * 0.6; // Range: 0.2 to 0.8
        _audioLevelController.add(level);
      }
    });
  }

  // Method to stop recording
  Future<void> stopRecording() async {
    // Implement the logic to stop recording
    // For example: await recorder.stop();
    _isRecording = false;
    _audioLevelTimer?.cancel();
    _audioLevelController.add(0.0);
    print('Recording stopped.');
  }

  // Method to start playback
  Future<void> playRecording() async {
    // Implement the logic to play the recorded audio
    // For example: await audioPlayer.play();
    print('Playing recording...');
  }

  // Method to stop playback
  Future<void> stopPlayback() async {
    // Implement the logic to stop playback
    // For example: await audioPlayer.stop();
    print('Playback stopped.');
  }

  void dispose() {
    _audioLevelTimer?.cancel();
    _audioLevelController.close();
  }
}