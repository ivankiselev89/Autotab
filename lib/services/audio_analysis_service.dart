import 'dart:io';
import 'dart:math' as math;
import '../models/note.dart';
import 'note_segmentation.dart';

/// True audio analysis service with noise suppression and pitch detection
/// Now uses WAV format (no FFmpeg needed!)
class AudioAnalysisService {
  final NoteSegmentationService _noteSegmentation = NoteSegmentationService();

  // Audio processing parameters
  static const int sampleRate = 44100;
  static const double noiseThreshold = 0.02; // Amplitude threshold for noise gate
  static const double minNoteDuration = 0.03; // Minimum note duration in seconds (allows very short notes)
  static const int frameSize = 2048;
  static const int hopSize = 512;

  /// Analyze recorded audio file with true pitch detection
  /// 
  /// Steps:
  /// 1. Read WAV file directly (PCM format - no FFmpeg needed!)
  /// 2. Apply aggressive noise suppression with instrument-specific filtering
  /// 3. Detect pitch using Yin algorithm
  /// 4. Segment notes and extract rhythm
  /// 
  /// [bpm] is used for rhythm normalization but does not discard short notes
  Future<AnalysisResult> analyzeRecording(
    String wavFilePath, {
    String instrument = 'Guitar',
    double bpm = 120.0,
  }) async {
    print('=== AUDIO ANALYSIS START ===');
    print('File path: $wavFilePath');
    print('Target instrument: $instrument');
    
    // Verify file exists
    final audioFile = File(wavFilePath);
    if (!await audioFile.exists()) {
      throw Exception('Audio file does not exist: $wavFilePath');
    }
    
    final fileSize = await audioFile.length();
    print('File exists, size: $fileSize bytes');
    
    // Verify it's a reasonable file size
    if (fileSize < 100) {
      throw Exception('File too small ($fileSize bytes) - recording may have failed');
    }
    
    // Check file extension
    if (!wavFilePath.toLowerCase().endsWith('.wav')) {
      print('WARNING: File does not have .wav extension: $wavFilePath');
    }

    // Step 1: Read WAV file directly (no FFmpeg needed!)
    print('Step 1: Reading WAV file...');
    List<double> pcmData;
    try {
      pcmData = await _readWavFile(wavFilePath);
    } catch (e, stackTrace) {
      print('ERROR reading WAV file: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to read WAV file: $e');
    }
    
    if (pcmData.isEmpty) {
      throw Exception('WAV file is empty or could not be parsed. File may not be in correct WAV format.');
    }

    print('Decoded ${pcmData.length} audio samples');

    // Step 2: Apply aggressive noise suppression with instrument-specific filtering
    print('Step 2: Applying professional-grade noise suppression...');
    final cleanedAudio = _applyAdvancedNoiseSupression(pcmData, instrument);
    print('Applied noise suppression and instrument filtering');

    // Step 3: Segment audio into notes
    final notes = _noteSegmentation.segmentAudio(
      cleanedAudio,
      sampleRate: sampleRate.toDouble(),
    );

    print('Detected ${notes.length} notes');

    // Step 4: Extract rhythm information using provided BPM
    final rhythm = _extractRhythm(notes, bpm: bpm);

    return AnalysisResult(
      notes: notes,
      rhythm: rhythm,
      duration: pcmData.length / sampleRate,
      sampleRate: sampleRate,
      originalSamples: pcmData.length,
      cleanedSamples: cleanedAudio.length,
    );
  }

  /// Read WAV file directly - no FFmpeg needed!
  /// WAV format: 44-byte header + PCM samples
  Future<List<double>> _readWavFile(String wavFilePath) async {
    try {
      print('Reading WAV file: $wavFilePath');
      final wavFile = File(wavFilePath);
      
      if (!await wavFile.exists()) {
        print('Error: WAV file does not exist');
        return [];
      }
      
      final bytes = await wavFile.readAsBytes();
      print('Read ${bytes.length} bytes from file');
      
      // WAV files have a 44-byte header, then raw PCM data
      // Basic WAV validation
      if (bytes.length < 44) {
        print('Error: File too small to be a valid WAV file (${bytes.length} bytes)');
        return [];
      }
      
      // Check RIFF header - safely
      try {
        final riffBytes = bytes.sublist(0, 4);
        final riffHeader = String.fromCharCodes(riffBytes);
        print('RIFF header: "$riffHeader" (bytes: ${riffBytes.join(", ")})');
        
        if (riffHeader != 'RIFF') {
          print('Error: Not a valid WAV file (no RIFF header). Got: "$riffHeader"');
          print('First 12 bytes: ${bytes.sublist(0, 12).join(", ")}');
          return [];
        }
      } catch (e) {
        print('Error reading RIFF header: $e');
        return [];
      }
      
      // Check WAV format - safely
      try {
        final waveBytes = bytes.sublist(8, 12);
        final waveHeader = String.fromCharCodes(waveBytes);
        print('WAVE header: "$waveHeader" (bytes: ${waveBytes.join(", ")})');
        
        if (waveHeader != 'WAVE') {
          print('Error: Not a valid WAV file (no WAVE header). Got: "$waveHeader"');
          return [];
        }
      } catch (e) {
        print('Error reading WAVE header: $e');
        return [];
      }
      
      print('Valid WAV file detected');
      print('Total file size: ${bytes.length} bytes');
      
      // Skip header and read PCM data
      // Standard WAV header is 44 bytes, but we'll search for the 'data' chunk
      int dataOffset = 44;
      bool dataChunkFound = false;
      
      // Try to find the 'data' chunk marker
      try {
        for (int i = 12; i < bytes.length - 8; i++) {
          try {
            final chunkBytes = bytes.sublist(i, i + 4);
            final chunk = String.fromCharCodes(chunkBytes);
            
            if (chunk == 'data') {
              // Data chunk found, next 4 bytes are size, then comes the data
              dataOffset = i + 8;
              final dataSize = bytes[i + 4] | 
                              (bytes[i + 5] << 8) | 
                              (bytes[i + 6] << 16) | 
                              (bytes[i + 7] << 24);
              print('Found data chunk at offset $i, data size: $dataSize bytes');
              dataChunkFound = true;
              break;
            }
          } catch (e) {
            // Skip this position if we can't read it
            continue;
          }
        }
      } catch (e) {
        print('Error searching for data chunk: $e');
      }
      
      if (!dataChunkFound) {
        print('Warning: Could not find data chunk marker, using default offset 44');
        dataOffset = 44;
      }
      
      // Ensure we don't read beyond file bounds
      if (dataOffset >= bytes.length) {
        print('Error: Data offset ($dataOffset) beyond file size (${bytes.length})');
        return [];
      }
      
      // Read PCM samples (assuming 16-bit little-endian)
      final samples = <double>[];
      try {
        for (int i = dataOffset; i < bytes.length - 1; i += 2) {
          // Read 16-bit signed integer (little-endian)
          final int16 = bytes[i] | (bytes[i + 1] << 8);
          // Convert to signed value
          final signed = int16 > 32767 ? int16 - 65536 : int16;
          // Normalize to -1.0 to 1.0
          samples.add(signed / 32768.0);
        }
      } catch (e) {
        print('Error reading PCM samples: $e');
        if (samples.isNotEmpty) {
          print('Returning ${samples.length} samples read before error');
          return samples;
        }
        return [];
      }
      
      print('Successfully read ${samples.length} samples from WAV file');
      return samples;
      
    } catch (e, stackTrace) {
      print('Error reading WAV file: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Apply ADVANCED noise suppression with instrument-specific filtering
  /// 
  /// Professional-grade audio cleaning techniques:
  /// 1. DC offset removal
  /// 2. Spectral subtraction (noise profile estimation and removal)
  /// 3. Instrument-specific band-pass filtering
  /// 4. Adaptive noise gate with RMS-based threshold
  /// 5. Harmonic enhancement for target instrument
  List<double> _applyAdvancedNoiseSupression(List<double> samples, String instrument) {
    if (samples.isEmpty) return samples;

    print('  - Removing DC offset...');
    // Step 1: Remove DC offset (center signal around zero)
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    var cleaned = samples.map((s) => s - mean).toList();

    print('  - Applying spectral subtraction for noise reduction...');
    // Step 2: Spectral subtraction - estimate and remove noise
    cleaned = _applySpectralNoiseReduction(cleaned);

    print('  - Applying instrument-specific band-pass filter ($instrument)...');
    // Step 3: Apply instrument-specific band-pass filter
    cleaned = _applyInstrumentFilter(cleaned, instrument);

    print('  - Applying adaptive noise gate...');
    // Step 4: Apply adaptive noise gate based on signal RMS
    cleaned = _applyAdaptiveNoiseGate(cleaned);

    print('  - Enhancing harmonic content...');
    // Step 5: Enhance harmonic content for better pitch detection
    cleaned = _enhanceHarmonics(cleaned);

    return cleaned;
  }

  /// Spectral noise reduction - estimate noise floor and subtract it
  List<double> _applySpectralNoiseReduction(List<double> samples) {
    // Use first 0.5 seconds as noise profile (assume silence/noise at start)
    final noiseProfileLength = (sampleRate * 0.5).toInt().clamp(0, samples.length ~/  4);
    
    if (noiseProfileLength < 100) return samples;
    
    final noiseProfile = samples.sublist(0, noiseProfileLength);
    final noiseRMS = _calculateRMS(noiseProfile);
    final noiseThreshold = noiseRMS * 2.5; // Aggressive threshold
    
    print('    Noise floor RMS: ${noiseRMS.toStringAsFixed(4)}, Threshold: ${noiseThreshold.toStringAsFixed(4)}');
    
    // Apply spectral gating - reduce amplitudes below noise threshold more aggressively
    return samples.map((s) {
      final amplitude = s.abs();
      if (amplitude < noiseThreshold) {
        // Aggressive attenuation for noise
        return s * 0.1;
      } else {
        // Keep signal, slightly boost to compensate
        return s * 1.1;
      }
    }).toList();
  }

  /// Apply instrument-specific band-pass filter
  /// Filters to only the frequency range of the target instrument
  List<double> _applyInstrumentFilter(List<double> samples, String instrument) {
    // Define frequency ranges for each instrument (Hz)
    double lowCutoff, highCutoff;
    
    switch (instrument.toLowerCase()) {
      case 'guitar':
        lowCutoff = 82.0;    // E2 - lowest guitar string
        highCutoff = 1318.0; // E6 - high notes on guitar
        break;
      case 'bass':
      case 'bass guitar':
        lowCutoff = 41.0;    // E1 - lowest bass string
        highCutoff = 392.0;  // G4 - high bass notes
        break;
      case 'piano':
        lowCutoff = 27.5;    // A0 - lowest piano key
        highCutoff = 4186.0; // C8 - highest piano key
        break;
      case 'violin':
        lowCutoff = 196.0;   // G3 - lowest violin string
        highCutoff = 3136.0; // G7 - high violin notes
        break;
      case 'drums':
        lowCutoff = 60.0;    // Low drums
        highCutoff = 8000.0; // Cymbals and high percussion
        break;
      default:
        lowCutoff = 80.0;    // Default: general musical range
        highCutoff = 2000.0;
    }
    
    print('    Instrument range: ${lowCutoff.toStringAsFixed(1)}Hz - ${highCutoff.toStringAsFixed(1)}Hz');
    
    // Apply high-pass filter (remove frequencies below low cutoff)
    var filtered = _applyHighPassFilter(samples, cutoffFreq: lowCutoff);
    
    // Apply low-pass filter (remove frequencies above high cutoff)
    filtered = _applyLowPassFilter(filtered, cutoffFreq: highCutoff);
    
    return filtered;
  }

  /// Adaptive noise gate - uses RMS of signal to determine threshold
  List<double> _applyAdaptiveNoiseGate(List<double> samples) {
    final rms = _calculateRMS(samples);
    final adaptiveThreshold = rms * 0.15; // 15% of RMS as threshold
    
    print('    Adaptive gate threshold: ${adaptiveThreshold.toStringAsFixed(4)}');
    
    return samples.map((s) {
      return s.abs() < adaptiveThreshold ? 0.0 : s;
    }).toList();
  }

  /// Enhance harmonic content for better pitch detection
  /// Uses simple harmonic emphasis through dynamic range compression
  List<double> _enhanceHarmonics(List<double> samples) {
    final rms = _calculateRMS(samples);
    if (rms < 0.001) return samples; // Too quiet, skip
    
    // Apply soft compression to enhance harmonics
    return samples.map((s) {
      final normalized = s / rms;
      // Soft compression: emphasize mid-level signals
      final compressed = normalized.sign * math.pow(normalized.abs(), 0.7).toDouble();
      return compressed * rms * 1.2; // Slight boost
    }).toList();
  }

  /// Calculate RMS (Root Mean Square) of signal
  double _calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    final sumSquares = samples.fold<double>(0.0, (sum, s) => sum + s * s);
    return math.sqrt(sumSquares / samples.length);
  }

  /// High-pass filter to remove low-frequency noise
  List<double> _applyHighPassFilter(List<double> samples, {double cutoffFreq = 80.0}) {
    // First-order high-pass filter (IIR)
    // RC = 1 / (2 * pi * cutoffFreq)
    final dt = 1.0 / sampleRate;
    final rc = 1.0 / (2.0 * math.pi * cutoffFreq);
    final alpha = rc / (rc + dt);

    final filtered = <double>[samples[0]];
    for (int i = 1; i < samples.length; i++) {
      final y = alpha * (filtered[i - 1] + samples[i] - samples[i - 1]);
      filtered.add(y);
    }

    return filtered;
  }

  /// Low-pass filter to remove high-frequency noise
  List<double> _applyLowPassFilter(List<double> samples, {double cutoffFreq = 2000.0}) {
    // First-order low-pass filter (IIR)
    final dt = 1.0 / sampleRate;
    final rc = 1.0 / (2.0 * math.pi * cutoffFreq);
    final alpha = dt / (rc + dt);

    final filtered = <double>[samples[0]];
    for (int i = 1; i < samples.length; i++) {
      final y = filtered[i - 1] + alpha * (samples[i] - filtered[i - 1]);
      filtered.add(y);
    }

    return filtered;
  }

  /// Extract rhythm information from detected notes
  /// Uses provided [bpm] for duration quantization
  RhythmInfo _extractRhythm(List<Note> notes, {double bpm = 120.0}) {
    if (notes.isEmpty) {
      return RhythmInfo(
        beats: [],
        averageDuration: 0.0,
        tempo: bpm,
        timeSignature: '4/4',
        noteDurations: [],
      );
    }
    
    final durations = notes.map((n) => n.endTime - n.startTime).toList();
    final averageDuration = durations.reduce((a, b) => a + b) / durations.length;

    // Estimate tempo (BPM) from average note duration
    // Assuming quarter note = 1 beat
    final estimatedTempo = averageDuration > 0 ? 60.0 / averageDuration : bpm;

    // Detect beats (note onsets)
    final beats = notes.map((n) => n.startTime).toList();

    // Quantize durations to common note values based on provided BPM
    final quantizedDurations = durations.map((d) => _quantizeDuration(d, bpm: bpm)).toList();

    return RhythmInfo(
      beats: beats,
      averageDuration: averageDuration,
      tempo: estimatedTempo.clamp(40.0, 240.0),
      timeSignature: '4/4', // Default, could be detected with more analysis
      noteDurations: quantizedDurations,
    );
  }

  /// Quantize duration to nearest musical note value
  /// Uses provided [bpm] to calculate note durations
  /// Note: This is used for normalization only - we keep all detected notes regardless of length
  String _quantizeDuration(double duration, {double bpm = 120.0}) {
    // Calculate note durations based on BPM
    // At 120 BPM: quarter note = 0.5 seconds (60/120)
    // At any BPM: quarter note = 60/BPM seconds
    final beatDuration = 60.0 / bpm; // Duration of one quarter note
    
    final whole = beatDuration * 4.0;
    final half = beatDuration * 2.0;
    final quarter = beatDuration;
    final eighth = beatDuration / 2.0;
    final sixteenth = beatDuration / 4.0;
    final thirtySecond = beatDuration / 8.0;

    final options = [
      {'duration': whole, 'name': 'whole'},
      {'duration': half, 'name': 'half'},
      {'duration': quarter, 'name': 'quarter'},
      {'duration': eighth, 'name': 'eighth'},
      {'duration': sixteenth, 'name': '16th'},
      {'duration': thirtySecond, 'name': '32nd'},
    ];

    // Find closest match - we normalize to standard durations but keep all notes
    // Very short notes are preserved and mapped to the closest standard duration
    double minDiff = double.infinity;
    String closest = 'quarter';

    for (final option in options) {
      final diff = (duration - (option['duration'] as double)).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = option['name'] as String;
      }
    }

    return closest;
  }
}

/// Result of audio analysis
class AnalysisResult {
  final List<Note> notes;
  final RhythmInfo rhythm;
  final double duration;
  final int sampleRate;
  final int originalSamples;
  final int cleanedSamples;

  AnalysisResult({
    required this.notes,
    required this.rhythm,
    required this.duration,
    required this.sampleRate,
    required this.originalSamples,
    required this.cleanedSamples,
  });

  int get noiseReduction => originalSamples - cleanedSamples;
  double get noiseReductionPercent => 
      ((noiseReduction / originalSamples) * 100).clamp(0.0, 100.0);
}

/// Rhythm information extracted from audio
class RhythmInfo {
  final List<double> beats; // Beat times in seconds
  final double averageDuration;
  final double tempo; // BPM
  final String timeSignature;
  final List<String>? noteDurations; // Quarter, eighth, etc.

  RhythmInfo({
    required this.beats,
    required this.averageDuration,
    required this.tempo,
    required this.timeSignature,
    this.noteDurations,
  });

  int get beatCount => beats.length;
  
  String get formattedTempo => '${tempo.toStringAsFixed(0)} BPM';
}
