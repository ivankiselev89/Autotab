import '../models/note.dart';
import 'pitch_detection.dart';
import 'dart:math' as math;

class NoteSegmentationService {
  final PitchDetectionService _pitchDetection = PitchDetectionService();
  
  // Configuration parameters for onset detection
  // Make onset detection more sensitive so that quiet or soft notes
  // are still picked up as candidates.
  static const double onsetThreshold = 0.05; // Amplitude threshold for note onset (more sensitive)
  static const int hopSize = 512; // Number of samples to skip between frames
  static const int frameSize = 2048; // Window size for analysis
  static const double minNoteDuration = 0.02; // Allow slightly shorter notes to be considered
  // Maximum number of samples to use for pitch detection per segment to
  // avoid extremely expensive computations on very long segments.
  static const int maxPitchSamples = 4096;
  
  /// Segments continuous audio into individual notes with timing and frequency information.
  /// 
  /// Uses onset detection to identify note boundaries and pitch detection to determine frequencies.
  /// Returns a list of Note objects with timing, frequency, and pitch information.
  List<Note> segmentAudio(
    List<double> audioData, {
    double sampleRate = 44100.0,
    String sensitivity = 'high',
  }) {
    if (audioData.isEmpty) {
      return [];
    }
    
    List<Note> notes = [];
    
    // Step 1: Detect note onsets using energy-based method
    final onsets = _detectOnsets(audioData, sampleRate, sensitivity: sensitivity);
    
    // Step 2: For each onset, extract the note segment and detect its pitch
    for (int i = 0; i < onsets.length; i++) {
      final startSample = onsets[i];
      final endSample = (i < onsets.length - 1) 
          ? onsets[i + 1] 
          : audioData.length;
      
      // Extract the segment
      var segment = audioData.sublist(startSample, endSample);
      
      // Skip very short segments. Sensitivity influences how short
      // a segment we will still keep as a potential note.
      final duration = (endSample - startSample) / sampleRate;
      double minDuration;
      switch (sensitivity.toLowerCase()) {
        case 'low':
          minDuration = 0.04; // prefer longer, cleaner notes
          break;
        case 'medium':
          minDuration = 0.03;
          break;
        case 'high':
        default:
          minDuration = 0.02; // allow very short notes
          break;
      }
      // For the very first and very last segments, be more lenient so we
      // don't accidentally swallow the attack of the first note or the
      // release of the final note.
      final bool isEdgeSegment = (i == 0 || i == onsets.length - 1);
      final double effectiveMinDuration = isEdgeSegment ? (minDuration * 0.5) : minDuration;

      if (duration < effectiveMinDuration) {
        continue;
      }
      
      // Limit the segment length used for pitch detection to keep the
      // Yin algorithm performant even on long sustained notes. For
      // very long segments we analyze only a centered window.
      if (segment.length > maxPitchSamples) {
        final center = segment.length ~/ 2;
        final halfWindow = maxPitchSamples ~/ 2;
        final start = math.max(0, center - halfWindow);
        final end = math.min(segment.length, start + maxPitchSamples);
        segment = segment.sublist(start, end);
      }

      // First, attempt to detect multiple simultaneous pitches (simple chord support)
      final chordFrequencies = _detectChordFrequencies(segment, sampleRate: sampleRate);

      // Calculate confidence based on signal strength once for this segment
      final confidence = _calculateConfidence(segment);

      if (chordFrequencies.isNotEmpty) {
        // Create a note for each detected fundamental in the chord
        for (final freq in chordFrequencies) {
          final noteInfo = _frequencyToNote(freq);
          notes.add(Note(
            frequency: freq.round(),
            noteName: noteInfo['name']!,
            octave: int.parse(noteInfo['octave']!),
            startTime: startSample / sampleRate,
            endTime: endSample / sampleRate,
            confidence: confidence,
          ));
        }
      } else {
        // Fallback to monophonic pitch detection (Yin)
        final frequency = _pitchDetection.detectPitch(segment, sampleRate: sampleRate.toInt());
        
        // Skip segments with no detectable pitch
        if (frequency == 0.0) {
          continue;
        }
        
        // Convert frequency to note name and octave
        final noteInfo = _frequencyToNote(frequency);
        
        notes.add(Note(
          frequency: frequency.round(),
          noteName: noteInfo['name']!,
          octave: int.parse(noteInfo['octave']!),
          startTime: startSample / sampleRate,
          endTime: endSample / sampleRate,
          confidence: confidence,
        ));
      }
    }
    
    return notes;
  }
  
  /// Detects note onsets using energy-based method
  /// Returns list of sample indices where onsets occur
  List<int> _detectOnsets(
    List<double> audioData,
    double sampleRate, {
    String sensitivity = 'high',
  }) {
    List<int> onsets = [];
    
    // Calculate energy for each frame
    final energies = <double>[];
    for (int i = 0; i < audioData.length - frameSize; i += hopSize) {
      final frame = audioData.sublist(i, math.min(i + frameSize, audioData.length));
      final energy = _calculateEnergy(frame);
      energies.add(energy);
    }
    
    if (energies.isEmpty) {
      return onsets;
    }
    
    // Calculate adaptive threshold based on local energy and sensitivity
    final meanEnergy = energies.reduce((a, b) => a + b) / energies.length;
    double onsetFactor;
    switch (sensitivity.toLowerCase()) {
      case 'low':
        onsetFactor = 1.4; // require stronger onsets
        break;
      case 'medium':
        onsetFactor = 1.0;
        break;
      case 'high':
      default:
        onsetFactor = 0.7; // more sensitive
        break;
    }
    final threshold = meanEnergy * onsetThreshold * onsetFactor;
    
    // Detect onsets as points where energy exceeds threshold
    bool inNote = false;
    for (int i = 1; i < energies.length; i++) {
      final currentEnergy = energies[i];
      final prevEnergy = energies[i - 1];
      
      // Onset: energy increases above threshold. Sensitivity influences
      // how much increase over previous frame we require.
      double jumpFactor;
      switch (sensitivity.toLowerCase()) {
        case 'low':
          jumpFactor = 1.6;
          break;
        case 'medium':
          jumpFactor = 1.3;
          break;
        case 'high':
        default:
          jumpFactor = 1.15;
          break;
      }

      if (!inNote && currentEnergy > threshold && currentEnergy > prevEnergy * jumpFactor) {
        onsets.add(i * hopSize);
        inNote = true;
      }
      // Offset: energy drops below threshold
      else if (inNote && currentEnergy < threshold * 0.5) {
        inNote = false;
      }
    }
    
    // Add first onset if not already detected
    if (onsets.isEmpty && energies.first > threshold) {
      onsets.add(0);
    }

    // If we detected at least one onset but the first one starts some
    // distance into the signal, add an onset at 0 so that we do not lose
    // a strong initial note attack.
    if (onsets.isNotEmpty && onsets.first > 0) {
      onsets.insert(0, 0);
    }
    
    return onsets;
  }
  
  /// Calculates the energy (RMS) of a signal frame
  double _calculateEnergy(List<double> frame) {
    if (frame.isEmpty) {
      return 0.0;
    }
    
    double sum = 0.0;
    for (final sample in frame) {
      sum += sample * sample;
    }
    
    return math.sqrt(sum / frame.length);
  }
  
  /// Calculates confidence score based on signal strength (0.0 to 1.0)
  double _calculateConfidence(List<double> segment) {
    final energy = _calculateEnergy(segment);
    // Normalize to 0-1 range (assuming max RMS of 1.0 for normalized audio)
    return math.min(energy * 2.0, 1.0);
  }

  /// Detect up to a few simultaneous fundamental frequencies in a segment
  /// using a simple spectral peak analysis. This provides basic chord
  /// support by allowing multiple Note objects with the same time range.
  List<double> _detectChordFrequencies(List<double> segment, {double sampleRate = 44100.0}) {
    // Use a limited window for analysis to keep things performant
    final length = math.min(maxPitchSamples, segment.length);
    if (length < 512) {
      return [];
    }

    // Apply a Hann window to reduce spectral leakage
    final windowed = List<double>.generate(length, (n) {
      final w = 0.5 * (1.0 - math.cos(2.0 * math.pi * n / (length - 1)));
      return segment[n] * w;
    });

    final half = length ~/ 2;
    final magnitudes = List<double>.filled(half, 0.0);

    for (int k = 0; k < half; k++) {
      double real = 0.0;
      double imag = 0.0;
      final double twoPiKOverN = 2.0 * math.pi * k / length;
      for (int n = 0; n < length; n++) {
        final sample = windowed[n];
        final angle = twoPiKOverN * n;
        real += sample * math.cos(angle);
        imag -= sample * math.sin(angle);
      }
      magnitudes[k] = math.sqrt(real * real + imag * imag);
    }

    final maxMag = magnitudes.fold<double>(0.0, (m, v) => v > m ? v : m);
    if (maxMag <= 0.0) {
      return [];
    }

    const double minFreq = 60.0;  // Ignore very low rumbles
    const double maxFreq = 2000.0; // Focus on typical musical range

    // Find local peaks that are a reasonable fraction of the max
    final candidates = <Map<String, double>>[];
    for (int k = 1; k < half - 1; k++) {
      final freq = k * sampleRate / length;
      if (freq < minFreq || freq > maxFreq) continue;

      final mag = magnitudes[k];
      if (mag <= maxMag * 0.3) continue;

      if (mag > magnitudes[k - 1] && mag >= magnitudes[k + 1]) {
        candidates.add({'freq': freq, 'mag': mag});
      }
    }

    if (candidates.isEmpty) {
      return [];
    }

    // Sort by magnitude descending
    candidates.sort((a, b) => (b['mag']! - a['mag']!).sign.toInt());

    final fundamentals = <double>[];

    bool isHarmonicOfExisting(double f) {
      for (final base in fundamentals) {
        final ratio = f / base;
        for (int n = 1; n <= 6; n++) {
          if ((ratio - n).abs() < 0.08) {
            return true; // likely a harmonic, not a new note
          }
        }
      }
      return false;
    }

    bool isTooCloseToExisting(double f) {
      for (final base in fundamentals) {
        final semitoneDiff = (12.0 * (math.log(f / base) / math.log(2))).abs();
        if (semitoneDiff < 0.8) {
          return true; // within ~1 semitone of an existing note
        }
      }
      return false;
    }

    for (final c in candidates) {
      final f = c['freq']!;
      if (isHarmonicOfExisting(f) || isTooCloseToExisting(f)) {
        continue;
      }
      fundamentals.add(f);
      if (fundamentals.length >= 3) break; // limit chord size
    }

    return fundamentals;
  }
  
  /// Converts frequency to musical note name and octave
  /// Returns a map with 'name' and 'octave' keys
  Map<String, String> _frequencyToNote(double frequency) {
    if (frequency <= 0) {
      return {'name': 'N/A', 'octave': '0'};
    }
    
    // A4 = 440 Hz is our reference
    const double a4Frequency = 440.0;
    const int a4MidiNote = 69;
    
    // Calculate MIDI note number
    final midiNote = (12 * (math.log(frequency / a4Frequency) / math.log(2)) + a4MidiNote).round();
    
    // Calculate octave and note within octave
    final octave = (midiNote ~/ 12) - 1; // Use integer division
    final noteIndex = midiNote % 12;
    
    // Note names
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final noteName = noteNames[noteIndex];
    
    return {
      'name': noteName,
      'octave': octave.toString(),
    };
  }
}