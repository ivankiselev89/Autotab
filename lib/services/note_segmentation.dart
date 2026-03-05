import '../models/note.dart';
import 'pitch_detection.dart';
import 'dart:math' as math;

class NoteSegmentationService {
  final PitchDetectionService _pitchDetection = PitchDetectionService();
  
  // Configuration parameters for onset detection
  static const int hopSize = 512; // Number of samples to skip between frames
  static const int frameSize = 2048; // Window size for analysis
  // Use a larger window for pitch detection to support low-frequency notes
  // (e.g. B0 = 30.87 Hz needs >= ~3110 samples at 48 kHz for two full periods).
  static const int maxPitchSamples = 8192;
  
  /// Segments continuous audio into individual notes with timing and frequency information.
  List<Note> segmentAudio(
    List<double> audioData, {
    double sampleRate = 44100.0,
    String sensitivity = 'high',
    String instrument = 'guitar',
  }) {
    if (audioData.isEmpty) {
      return [];
    }
    
    // Derive instrument-specific frequency range for pitch detection.
    final freqRange = _instrumentFrequencyRange(instrument);
    final minFreq = freqRange[0];
    final maxFreq = freqRange[1];

    List<Note> notes = [];
    
    // Detect note onsets using a combination of energy and spectral flux.
    final onsets = _detectOnsets(audioData, sampleRate, sensitivity: sensitivity);
    
    for (int i = 0; i < onsets.length; i++) {
      final startSample = onsets[i];
      final endSample = (i < onsets.length - 1) 
          ? onsets[i + 1] 
          : audioData.length;
      
      var segment = audioData.sublist(startSample, endSample);
      
      final duration = (endSample - startSample) / sampleRate;
      double minDuration;
      switch (sensitivity.toLowerCase()) {
        case 'low':
          minDuration = 0.04;
          break;
        case 'medium':
          minDuration = 0.03;
          break;
        case 'high':
        default:
          minDuration = 0.02;
          break;
      }
      final bool isEdgeSegment = (i == 0 || i == onsets.length - 1);
      final double effectiveMinDuration = isEdgeSegment ? (minDuration * 0.5) : minDuration;

      if (duration < effectiveMinDuration) {
        continue;
      }
      
      // For pitch detection, use a centered window within the segment to
      // analyze the stable sustain portion rather than the transient attack.
      // This gives more reliable pitch estimates for notes with slow attacks.
      if (segment.length > maxPitchSamples) {
        final center = segment.length ~/ 2;
        final halfWindow = maxPitchSamples ~/ 2;
        final start = math.max(0, center - halfWindow);
        final end = math.min(segment.length, start + maxPitchSamples);
        segment = segment.sublist(start, end);
      }

      // Try multi-pitch (chord) detection first.
      final chordFrequencies = _detectChordFrequencies(
        segment,
        sampleRate: sampleRate,
        minFreq: minFreq,
        maxFreq: maxFreq,
      );

      final confidence = _calculateConfidence(segment);

      if (chordFrequencies.isNotEmpty) {
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
        // Fall back to monophonic YIN pitch detection.
        final frequency = _pitchDetection.detectPitch(
          segment,
          sampleRate: sampleRate.toInt(),
          minFrequency: minFreq,
          maxFrequency: maxFreq,
        );
        
        if (frequency == 0.0) {
          continue;
        }
        
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
  
  /// Returns [minFreq, maxFreq] for the given instrument.
  List<double> _instrumentFrequencyRange(String instrument) {
    switch (instrument.toLowerCase()) {
      case 'guitar':
        return [75.0, 1400.0];
      case 'bass':
      case 'bass guitar':
        return [28.0, 400.0];
      case 'banjo':
        return [146.8, 1760.0];
      case 'piano':
        return [27.5, 4186.0];
      default:
        return [60.0, 2000.0];
    }
  }

  /// Detects note onsets using a combination of energy-based and spectral-flux methods.
  List<int> _detectOnsets(
    List<double> audioData,
    double sampleRate, {
    String sensitivity = 'high',
  }) {
    // --- Energy-based onset detection ---
    final energies = <double>[];
    for (int i = 0; i < audioData.length - frameSize; i += hopSize) {
      final end = math.min(i + frameSize, audioData.length);
      final frame = audioData.sublist(i, end);
      energies.add(_calculateEnergy(frame));
    }

    if (energies.isEmpty) return [0];

    final meanEnergy = energies.reduce((a, b) => a + b) / energies.length;
    double onsetFactor;
    switch (sensitivity.toLowerCase()) {
      case 'low':
        onsetFactor = 1.4;
        break;
      case 'medium':
        onsetFactor = 1.0;
        break;
      case 'high':
      default:
        onsetFactor = 0.7;
        break;
    }
    final energyThreshold = meanEnergy * 0.05 * onsetFactor;

    final energyOnsets = <int>[];
    bool inNote = false;
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
    for (int i = 1; i < energies.length; i++) {
      final curr = energies[i];
      final prev = energies[i - 1];
      if (!inNote && curr > energyThreshold && curr > prev * jumpFactor) {
        energyOnsets.add(i * hopSize);
        inNote = true;
      } else if (inNote && curr < energyThreshold * 0.5) {
        inNote = false;
      }
    }

    // --- Spectral-flux onset detection ---
    // Half-wave rectified spectral flux: captures onset of new notes even when
    // the overall energy does not drop between consecutive notes.
    final spectralFluxOnsets = <int>[];
    List<double>? prevSpectrum;
    final fluxValues = <double>[];
    final fluxIndices = <int>[];
    for (int i = 0; i < audioData.length - frameSize; i += hopSize) {
      final end = math.min(i + frameSize, audioData.length);
      final frame = audioData.sublist(i, end);
      final spectrum = _computeMagnitudeSpectrum(frame);
      if (prevSpectrum != null) {
        double flux = 0.0;
        for (int k = 0; k < spectrum.length && k < prevSpectrum.length; k++) {
          final diff = spectrum[k] - prevSpectrum[k];
          if (diff > 0) flux += diff;
        }
        fluxValues.add(flux);
        fluxIndices.add(i);
      }
      prevSpectrum = spectrum;
    }

    if (fluxValues.isNotEmpty) {
      final maxFlux = fluxValues.reduce(math.max);
      if (maxFlux > 0) {
        final localWindow = (0.5 * sampleRate / hopSize).round().clamp(5, 40);
        double fluxFactor;
        switch (sensitivity.toLowerCase()) {
          case 'low':
            fluxFactor = 2.0;
            break;
          case 'medium':
            fluxFactor = 1.2;
            break;
          case 'high':
          default:
            fluxFactor = 0.7;
            break;
        }

        for (int i = 1; i < fluxValues.length - 1; i++) {
          final winStart = math.max(0, i - localWindow);
          final winEnd = math.min(fluxValues.length, i + localWindow + 1);
          double localMean = 0.0;
          for (int j = winStart; j < winEnd; j++) {
            localMean += fluxValues[j];
          }
          localMean /= (winEnd - winStart);

          final localThreshold = localMean * fluxFactor + maxFlux * 0.02;

          if (fluxValues[i] > localThreshold &&
              fluxValues[i] >= fluxValues[i - 1] &&
              fluxValues[i] >= fluxValues[i + 1]) {
            spectralFluxOnsets.add(fluxIndices[i]);
          }
        }
      }
    }

    // --- Merge both onset sets ---
    final minGapSamples = (0.08 * sampleRate).round();
    final allOnsets = <int>{...energyOnsets, ...spectralFluxOnsets}.toList()
      ..sort();

    final merged = <int>[];
    for (final o in allOnsets) {
      if (merged.isEmpty || (o - merged.last) >= minGapSamples) {
        merged.add(o);
      }
    }

    // Always ensure we consider the very beginning of the recording.
    if (merged.isEmpty || merged.first > 0) {
      merged.insert(0, 0);
    }

    return merged;
  }

  /// Computes half-spectrum magnitudes using a DFT on the given frame.
  List<double> _computeMagnitudeSpectrum(List<double> frame) {
    final n = frame.length;
    final half = n ~/ 2;
    final magnitudes = List<double>.filled(half, 0.0);
    for (int k = 0; k < half; k++) {
      double real = 0.0;
      double imag = 0.0;
      final twoPiKOverN = 2.0 * math.pi * k / n;
      for (int t = 0; t < n; t++) {
        final angle = twoPiKOverN * t;
        real += frame[t] * math.cos(angle);
        imag -= frame[t] * math.sin(angle);
      }
      magnitudes[k] = math.sqrt(real * real + imag * imag);
    }
    return magnitudes;
  }
  
  /// Calculates the energy (RMS) of a signal frame
  double _calculateEnergy(List<double> frame) {
    if (frame.isEmpty) return 0.0;
    double sum = 0.0;
    for (final sample in frame) {
      sum += sample * sample;
    }
    return math.sqrt(sum / frame.length);
  }
  
  /// Calculates confidence score based on signal strength (0.0 to 1.0)
  double _calculateConfidence(List<double> segment) {
    final energy = _calculateEnergy(segment);
    return math.min(energy * 2.0, 1.0);
  }

  /// Detect simultaneous fundamental frequencies (chord support) using a
  /// DFT-based spectral peak analysis with harmonic filtering.
  ///
  /// Returns an empty list when no clear chord structure is found; in that
  /// case the caller should fall back to monophonic YIN detection.
  List<double> _detectChordFrequencies(
    List<double> segment, {
    double sampleRate = 44100.0,
    double minFreq = 60.0,
    double maxFreq = 2000.0,
  }) {
    final length = math.min(maxPitchSamples, segment.length);
    if (length < 512) return [];

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
      final twoPiKOverN = 2.0 * math.pi * k / length;
      for (int n = 0; n < length; n++) {
        real += windowed[n] * math.cos(twoPiKOverN * n);
        imag -= windowed[n] * math.sin(twoPiKOverN * n);
      }
      magnitudes[k] = math.sqrt(real * real + imag * imag);
    }

    final maxMag = magnitudes.fold<double>(0.0, (m, v) => v > m ? v : m);
    if (maxMag <= 0.0) return [];

    // Collect spectral peaks within the instrument's frequency range.
    // Use a lower relative threshold (10%) so that fundamentals are not
    // missed when their harmonics dominate the spectrum.
    final candidates = <Map<String, double>>[];
    for (int k = 1; k < half - 1; k++) {
      final freq = k * sampleRate / length;
      if (freq < minFreq || freq > maxFreq) continue;

      final mag = magnitudes[k];
      if (mag <= maxMag * 0.10) continue;

      if (mag > magnitudes[k - 1] && mag >= magnitudes[k + 1]) {
        candidates.add({'freq': freq, 'mag': mag});
      }
    }

    if (candidates.isEmpty) return [];

    candidates.sort((a, b) => (b['mag']! - a['mag']!).sign.toInt());

    final fundamentals = <double>[];

    bool isHarmonicOfExisting(double f) {
      for (final base in fundamentals) {
        final ratio = f / base;
        for (int n = 2; n <= 8; n++) {
          if ((ratio - n).abs() < 0.08) return true;
        }
      }
      return false;
    }

    bool isTooCloseToExisting(double f) {
      for (final base in fundamentals) {
        final semitoneDiff = (12.0 * (math.log(f / base) / math.log(2))).abs();
        if (semitoneDiff < 0.8) return true;
      }
      return false;
    }

    for (final c in candidates) {
      final f = c['freq']!;
      if (isHarmonicOfExisting(f) || isTooCloseToExisting(f)) continue;
      fundamentals.add(f);
      if (fundamentals.length >= 4) break;
    }

    // Only return chord results when 2 or more independent fundamentals are
    // found.  A single candidate should be handled by the YIN fallback which
    // is more reliable for monophonic content.
    if (fundamentals.length < 2) return [];

    // Check whether any pair of found fundamentals is better explained as
    // harmonics of a single common sub-fundamental.  When that sub-fundamental
    // falls within the instrument's valid frequency range, the signal is a
    // single note (not a chord) and YIN should handle it.
    for (int i = 0; i < fundamentals.length; i++) {
      for (int j = i + 1; j < fundamentals.length; j++) {
        if (_findCommonFundamental(fundamentals[i], fundamentals[j], minFreq) != null) {
          return [];
        }
      }
    }

    return fundamentals;
  }

  /// If [f1] and [f2] are both harmonics of a single sub-fundamental that is
  /// at least [minFreq] Hz, returns that sub-fundamental frequency.
  /// Returns null if no such relationship is found within the search bounds.
  double? _findCommonFundamental(double f1, double f2, double minFreq) {
    final lower = f1 < f2 ? f1 : f2;
    final upper = f1 < f2 ? f2 : f1;
    const double tolerance = 0.06;
    for (int m = 1; m < 10; m++) {
      for (int n = m + 1; n < 12; n++) {
        final ratio = n / m;
        if ((upper / lower - ratio).abs() < tolerance * ratio) {
          final f0 = lower / m;
          if (f0 >= minFreq) return f0;
        }
      }
    }
    return null;
  }
  
  /// Converts frequency to musical note name and octave
  Map<String, String> _frequencyToNote(double frequency) {
    if (frequency <= 0) {
      return {'name': 'N/A', 'octave': '0'};
    }
    
    const double a4Frequency = 440.0;
    const int a4MidiNote = 69;
    
    final midiNote = (12 * (math.log(frequency / a4Frequency) / math.log(2)) + a4MidiNote).round();
    
    final octave = (midiNote ~/ 12) - 1;
    final noteIndex = midiNote % 12;
    
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final noteName = noteNames[noteIndex];
    
    return {
      'name': noteName,
      'octave': octave.toString(),
    };
  }
}
