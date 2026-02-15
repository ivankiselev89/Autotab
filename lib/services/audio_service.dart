import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

/// Audio recording service singleton
/// Handles audio recording, amplitude monitoring, and file management
/// Records in WAV format (uncompressed PCM) for direct audio analysis
class AudioService {
  // Private constructor
  AudioService._();

  // Singleton instance
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;

  // Audio recorder instance
  final AudioRecorder _recorder = AudioRecorder();
  
  // Stream controller for audio levels
  final StreamController<double> _audioLevelController = StreamController<double>.broadcast();
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  bool _isRecording = false;
  bool _isInitialized = false;
  String? _currentRecordingPath;
  
  // Getters
  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;
  
  // Get the recordings directory path
  Future<String> getRecordingsDirectory() async {
    String recordingsDir;
    
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '.';
      recordingsDir = '$userProfile\\Documents\\Autotab\\Recordings';
    } else if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '.';
      recordingsDir = '$home/Documents/Autotab/Recordings';
    } else {
      // For Android/iOS, use app documents directory
      recordingsDir = Directory.systemTemp.path;
    }
    
    // Create directory if it doesn't exist
    final directory = Directory(recordingsDir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    return recordingsDir;
  }

  // Initialize the recorder
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      if (await _recorder.hasPermission()) {
        _isInitialized = true;
        print('AudioService initialized successfully');
      } else {
        print('No recording permission');
      }
    } catch (e) {
      print('Error initializing AudioService: $e');
      rethrow;
    }
  }

  // Method to check and request microphone permission
  Future<bool> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      var result = await Permission.microphone.request();
      return result.isGranted;
    }
    return true;
  }
  
  // Get a path for saving the recording permanently
  Future<String> _getRecordingPath([String? customName]) async {
    final recordingsDir = await getRecordingsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Use custom name or default timestamp-based name
    final fileName = customName ?? 'recording_$timestamp';
    final sanitizedName = fileName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    
    if (Platform.isWindows) {
      return '$recordingsDir\\$sanitizedName.wav';
    } else {
      return '$recordingsDir/$sanitizedName.wav';
    }
  }

  // Method to start recording
  Future<void> startRecording() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isRecording) {
      print('Already recording');
      return;
    }

    if (!await _requestMicrophonePermission()) {
      print('Microphone permission denied.');
      throw Exception('Microphone permission denied');
    }

    try {
      _currentRecordingPath = await _getRecordingPath();
      
      print('Attempting to start recording...');
      print('Path: $_currentRecordingPath');
      
      // Start recording in WAV format (uncompressed PCM - no FFmpeg needed!)
      try {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav, // WAV format - direct PCM access
            sampleRate: 44100,
            numChannels: 1, // Mono for easier processing
          ),
          path: _currentRecordingPath!,
        );
        print('Recording started successfully in WAV format');
      } catch (e) {
        print('WARNING: WAV recording failed: $e');
        print('Error type: ${e.runtimeType}');
        print('This may be a platform limitation. Trying without explicit config...');
        
        // Fallback: try without numChannels parameter
        try {
          await _recorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 44100,
            ),
            path: _currentRecordingPath!,
          );
          print('Recording started with fallback config');
        } catch (e2) {
          print('ERROR: Could not start recording: $e2');
          print('Stack trace: ${StackTrace.current}');
          rethrow;
        }
      }

      _isRecording = true;

      // Listen to real-time amplitude for visualization
      _amplitudeSubscription = _recorder.onAmplitudeChanged(
        const Duration(milliseconds: 100),
      ).listen((amplitude) {
        // Convert amplitude to normalized level (0.0 to 1.0)
        // Amplitude.current is typically between -160 and 0 dB
        final normalizedLevel = ((amplitude.current + 160) / 160).clamp(0.0, 1.0);
        _audioLevelController.add(normalizedLevel);
      });

      print('Recording started: $_currentRecordingPath');
    } catch (e) {
      _isRecording = false;
      _currentRecordingPath = null;
      print('Error starting recording: $e');
      rethrow;
    }
  }

  // Method to stop recording
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      print('Not currently recording');
      return null;
    }

    try {
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      
      final path = await _recorder.stop();
      _isRecording = false;
      _audioLevelController.add(0.0);
      
      print('Recording stopped: $path');
      return path;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      _currentRecordingPath = null;
      rethrow;
    }
  }

  // Method to start playback (requires additional audio player package)
  Future<void> playRecording([String? filePath]) async {
    final pathToPlay = filePath ?? _currentRecordingPath;
    
    if (pathToPlay == null) {
      print('No recording to play');
      throw Exception('No recording available to play');
    }

    if (!File(pathToPlay).existsSync()) {
      print('Recording file does not exist: $pathToPlay');
      throw Exception('Recording file not found');
    }

    // Note: Add 'just_audio' or 'audioplayers' package for playback functionality
    print('Playback requires just_audio or audioplayers package');
    print('Recording saved at: $pathToPlay');
  }

  // Method to stop playback
  Future<void> stopPlayback() async {
    print('Playback requires just_audio or audioplayers package');
  }
  
  // Check if currently playing
  Future<bool> isPlaying() async {
    return false;
  }
  
  // Save current recording with a custom name
  Future<String?> saveRecordingAs(String name) async {
    if (_currentRecordingPath == null) {
      throw Exception('No recording to save');
    }
    
    if (!File(_currentRecordingPath!).existsSync()) {
      throw Exception('Recording file not found');
    }
    
    final newPath = await _getRecordingPath(name);
    final currentFile = File(_currentRecordingPath!);
    
    // Copy file to new location with custom name
    await currentFile.copy(newPath);
    
    print('Recording saved as: $newPath');
    return newPath;
  }
  
  // Get list of all saved recordings
  Future<List<RecordingInfo>> getSavedRecordings() async {
    final recordingsDir = await getRecordingsDirectory();
    final directory = Directory(recordingsDir);
    
    if (!await directory.exists()) {
      return [];
    }
    
    final files = directory.listSync()
        .where((item) => item is File && item.path.endsWith('.m4a'))
        .cast<File>()
        .toList();
    
    final recordings = <RecordingInfo>[];
    
    for (final file in files) {
      final stat = await file.stat();
      final fileName = file.path.split(Platform.isWindows ? '\\' : '/').last;
      
      recordings.add(RecordingInfo(
        path: file.path,
        name: fileName,
        size: stat.size,
        created: stat.modified,
      ));
    }
    
    // Sort by date, newest first
    recordings.sort((a, b) => b.created.compareTo(a.created));
    
    return recordings;
  }
  
  // Delete a saved recording
  Future<void> deleteRecording(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      print('Recording deleted: $path');
    }
  }
  
  // Get file size of a recording
  Future<int> getRecordingSize(String path) async {
    final file = File(path);
    if (await file.exists()) {
      final stat = await file.stat();
      return stat.size;
    }
    return 0;
  }
  
  // Format file size to human-readable string
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Note: This is a singleton service that persists for the app's lifetime.
  // The dispose method is provided for potential cleanup during app termination
  // but is typically not called in normal Flutter app usage. In scenarios where
  // explicit cleanup is needed (e.g., when monitoring AppLifecycleState.detached),
  // this method can be called manually to cancel subscriptions and close streams.
  void dispose() {
    _amplitudeSubscription?.cancel();
    _recorder.dispose();
    _audioLevelController.close();
    _isInitialized = false;
  }
}

/// Information about a saved recording
class RecordingInfo {
  final String path;
  final String name;
  final int size;
  final DateTime created;

  RecordingInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.created,
  });
  
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  String get formattedDate {
    return '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')} '
           '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
  }
}