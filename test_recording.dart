import 'dart:io';
import 'package:record/record.dart';

/// Test script to verify WAV recording works
void main() async {
  print('Testing WAV recording on Windows...');
  
  final recorder = AudioRecorder();
  
  // Check if we have permission
  if (!await recorder.hasPermission()) {
    print('ERROR: No microphone permission');
    return;
  }
  
  print('Permission granted');
  
  // Try to record in WAV format
  final testPath = 'test_recording.wav';
  
  try {
    print('Starting recording...');
    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
      ),
      path: testPath,
    );
    
    print('Recording for 2 seconds...');
    await Future.delayed(Duration(seconds: 2));
    
    final path = await recorder.stop();
    print('Recording stopped. File: $path');
    
    if (path != null && File(path).existsSync()) {
      final size = await File(path).length();
      print('SUCCESS: File created, size: $size bytes');
      
      // Read first few bytes
      final bytes = await File(path).readAsBytes();
      if (bytes.length >= 12) {
        print('First 12 bytes: ${bytes.sublist(0, 12)}');
        print('As string: ${String.fromCharCodes(bytes.sublist(0, 4))}');
      }
    } else {
      print('ERROR: File not created');
    }
  } catch (e, stackTrace) {
    print('ERROR: $e');
    print('Stack trace: $stackTrace');
  }
}
