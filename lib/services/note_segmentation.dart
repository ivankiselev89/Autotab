import '../models/note.dart';
import 'pitch_detection.dart';
import 'dart:math' as math;
import 'dart:typed_data';

class NoteSegmentationService {
  final PitchDetectionService _pitchDetection = PitchDetectionService();
  
  // Configuration parameters for onset detection
  static const int hopSize = 512; // Number of samples to skip between frames
  static const int frameSize = 2048; // Window size for analysis
  // Use a larger window for pitch detection to support low-frequency notes
  // (e.g. B0 = 30.87 Hz needs >= ~3110 samples at 48 kHz for two full periods).
  static const int maxPitchSamples = 8192;
  
  /// Segments continuous audio into individual notes with timing and frequency information.
  ///
  /// Uses a Rocksmith-inspired approach:
  /// 1. Onset detection splits audio into candidate segments
  /// 2. YIN pitch detection with confidence scoring rejects non-periodic content
  /// 3. FFT spectral validation confirms the YIN result is the dominant frequency
  /// 4. Post-processing merges and cleans results
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

    // Minimum YIN confidence to accept a detected pitch.
    // Inspired by Rocksmith's approach of requiring high confidence before
    // committing to a note detection.
    double minYinConfidence;
    switch (sensitivity.toLowerCase()) {
      case 'low':
        minYinConfidence = 0.82;
        break;
      case 'medium':
        minYinConfidence = 0.70;
        break;
      case 'high':
      default:
        minYinConfidence = 0.55;
        break;
    }

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

      final energyConfidence = _calculateConfidence(segment);

      // Skip segments with very low energy (likely noise or silence).
      if (energyConfidence < 0.01) {
        continue;
      }

      // Try multi-pitch (chord) detection first.
      final chordFrequencies = _detectChordFrequencies(
        segment,
        sampleRate: sampleRate,
        minFreq: minFreq,
        maxFreq: maxFreq,
      );

      if (chordFrequencies.isNotEmpty) {
        for (final freq in chordFrequencies) {
          final noteInfo = _frequencyToNote(freq);
          notes.add(Note(
            frequency: freq.round(),
            noteName: noteInfo['name']!,
            octave: int.parse(noteInfo['octave']!),
            startTime: startSample / sampleRate,
            endTime: endSample / sampleRate,
            confidence: energyConfidence,
          ));
        }
      } else {
        // Rocksmith-inspired monophonic detection:
        // Use YIN with confidence scoring and reject low-confidence results.
        final pitchResult = _pitchDetection.detectPitchWithConfidence(
          segment,
          sampleRate: sampleRate.toInt(),
          minFrequency: minFreq,
          maxFrequency: maxFreq,
        );
        
        if (pitchResult.frequency == 0.0) {
          continue;
        }

        // Gate on YIN confidence – this is the key Rocksmith-inspired filter
        // that eliminates most false positives from noise, harmonics, and
        // non-periodic content.
        if (pitchResult.confidence < minYinConfidence) {
          continue;
        }

        // Cross-validate: for borderline confidence, also check that the
        // frequency is spectrally plausible.  High-confidence detections
        // bypass this check because YIN is very reliable at high confidence.
        if (pitchResult.confidence < 0.90 &&
            !_isFrequencyDominant(segment, pitchResult.frequency, sampleRate, minFreq, maxFreq)) {
          continue;
        }
        
        final noteInfo = _frequencyToNote(pitchResult.frequency);
        final combinedConfidence = math.min(
          energyConfidence * pitchResult.confidence * 2.0,
          1.0,
        );
        
        notes.add(Note(
          frequency: pitchResult.frequency.round(),
          noteName: noteInfo['name']!,
          octave: int.parse(noteInfo['octave']!),
          startTime: startSample / sampleRate,
          endTime: endSample / sampleRate,
          confidence: combinedConfidence,
        ));
      }
    }
    
    return _postProcessNotes(notes);
  }

  /// Validates that [frequency] is the dominant spectral peak (or within one
  /// semitone of it) in the given [segment].
  ///
  /// This acts as a Rocksmith-style cross-check: YIN may lock onto a
  /// sub-harmonic or harmonic; the FFT spectrum quickly verifies whether
  /// that frequency is actually the strongest one present.
  bool _isFrequencyDominant(
    List<double> segment,
    double frequency,
    double sampleRate,
    double minFreq,
    double maxFreq,
  ) {
    // Use a power-of-two FFT size for efficiency.
    final fftSize = _nextPowerOfTwo(math.min(segment.length, 4096));
    if (fftSize < 256) return true; // too short to validate

    // Apply Hann window + zero-pad
    final real = Float64List(fftSize);
    final imag = Float64List(fftSize);
    final len = math.min(segment.length, fftSize);
    for (int n = 0; n < len; n++) {
      final w = 0.5 * (1.0 - math.cos(2.0 * math.pi * n / (len - 1)));
      real[n] = segment[n] * w;
    }

    _fftInPlace(real, imag);

    // Find the magnitude at the YIN frequency and the global peak in range.
    final binRes = sampleRate / fftSize;
    final yinBin = (frequency / binRes).round().clamp(1, fftSize ~/ 2 - 1);

    double yinMag = 0.0;
    // Search a small neighbourhood around the expected bin to account for
    // spectral leakage.
    for (int k = math.max(1, yinBin - 2); k <= math.min(fftSize ~/ 2 - 1, yinBin + 2); k++) {
      final m = math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
      if (m > yinMag) yinMag = m;
    }

    double peakMag = 0.0;
    final minBin = math.max(1, (minFreq / binRes).floor());
    final maxBin = math.min(fftSize ~/ 2 - 1, (maxFreq / binRes).ceil());
    int peakBin = minBin;
    for (int k = minBin; k <= maxBin; k++) {
      final m = math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
      if (m > peakMag) {
        peakMag = m;
        peakBin = k;
      }
    }

    if (peakMag <= 0) return true;

    // Check if the dominant peak is harmonically related to the YIN
    // frequency.  Guitar fundamentals are often weaker than their 2nd or 3rd
    // harmonics, so a harmonic relationship between the peak and the YIN
    // frequency is sufficient to accept the detection even when the
    // fundamental itself is spectrally weak.
    final peakFreq = peakBin * binRes;
    if (peakFreq > 0 && frequency > 0) {
      final ratio = peakFreq / frequency;
      // Check if peak is a harmonic of the YIN frequency
      final nearestHarmonic = ratio.round();
      if (nearestHarmonic >= 1 && nearestHarmonic <= 8) {
        final harmonicError = (ratio - nearestHarmonic).abs();
        if (harmonicError < 0.15) return true;
      }
      // Also check sub-harmonic (YIN frequency is a harmonic of the peak)
      final invRatio = frequency / peakFreq;
      final nearestSubHarmonic = invRatio.round();
      if (nearestSubHarmonic >= 1 && nearestSubHarmonic <= 4) {
        final subError = (invRatio - nearestSubHarmonic).abs();
        if (subError < 0.15) return true;
      }
    }

    // If no harmonic relationship, require the YIN frequency to have
    // reasonable spectral energy relative to the peak.
    if (yinMag < peakMag * 0.20) return false;

    return true;
  }

  /// Merges consecutive identical notes, removes isolated spurious
  /// detections, and cleans up short low-confidence artefacts.
  List<Note> _postProcessNotes(List<Note> notes) {
    if (notes.length <= 1) return notes;

    // Step 1: Merge consecutive notes that have the same name+octave.
    var merged = <Note>[notes.first];
    for (int i = 1; i < notes.length; i++) {
      final prev = merged.last;
      final curr = notes[i];
      if (curr.noteName == prev.noteName && curr.octave == prev.octave) {
        prev.endTime = curr.endTime;
        prev.confidence = math.max(prev.confidence, curr.confidence);
      } else {
        merged.add(curr);
      }
    }

    if (merged.length <= 2) return merged;

    // Step 2: Remove isolated spurious notes.
    final cleaned = <Note>[merged.first];
    for (int i = 1; i < merged.length - 1; i++) {
      final prev = merged[i - 1];
      final curr = merged[i];
      final next = merged[i + 1];

      final currDuration = curr.endTime - curr.startTime;
      final prevDuration = prev.endTime - prev.startTime;
      final nextDuration = next.endTime - next.startTime;

      final neighboursSame =
          prev.noteName == next.noteName && prev.octave == next.octave;

      if (neighboursSame &&
          currDuration < 0.15 &&
          currDuration < prevDuration * 0.5 &&
          currDuration < nextDuration * 0.5) {
        cleaned.last.endTime = next.startTime;
        continue;
      }

      // Drop notes with very low confidence compared to neighbours.
      if (curr.confidence < prev.confidence * 0.3 &&
          curr.confidence < next.confidence * 0.3 &&
          currDuration < 0.2) {
        cleaned.last.endTime = next.startTime;
        continue;
      }

      cleaned.add(curr);
    }
    cleaned.add(merged.last);

    // Step 3: Merge again after cleaning.
    if (cleaned.length <= 1) return cleaned;
    final result = <Note>[cleaned.first];
    for (int i = 1; i < cleaned.length; i++) {
      final prev = result.last;
      final curr = cleaned[i];
      if (curr.noteName == prev.noteName && curr.octave == prev.octave) {
        prev.endTime = curr.endTime;
        prev.confidence = math.max(prev.confidence, curr.confidence);
      } else {
        result.add(curr);
      }
    }

    return result;
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

    // --- Spectral-flux onset detection (using FFT for speed) ---
    final spectralFluxOnsets = <int>[];
    List<double>? prevSpectrum;
    final fluxValues = <double>[];
    final fluxIndices = <int>[];
    final fftFrameSize = _nextPowerOfTwo(frameSize);
    for (int i = 0; i < audioData.length - frameSize; i += hopSize) {
      final end = math.min(i + frameSize, audioData.length);
      final frame = audioData.sublist(i, end);
      final spectrum = _computeMagnitudeSpectrumFFT(frame, fftFrameSize);
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
    double minGapSeconds;
    switch (sensitivity.toLowerCase()) {
      case 'low':
        minGapSeconds = 0.20;
        break;
      case 'medium':
        minGapSeconds = 0.14;
        break;
      case 'high':
      default:
        minGapSeconds = 0.10;
        break;
    }
    final minGapSamples = (minGapSeconds * sampleRate).round();
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

  // ---------------------------------------------------------------------------
  // FFT implementation (radix-2 Cooley–Tukey, in-place)
  // ---------------------------------------------------------------------------

  /// Returns the smallest power of two >= [n].
  static int _nextPowerOfTwo(int n) {
    int p = 1;
    while (p < n) {
      p <<= 1;
    }
    return p;
  }

  /// In-place radix-2 Cooley–Tukey FFT.
  /// [real] and [imag] must have the same length, which must be a power of two.
  static void _fftInPlace(Float64List real, Float64List imag) {
    final n = real.length;
    if (n <= 1) return;

    // Bit-reversal permutation
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        double tr = real[i];
        real[i] = real[j];
        real[j] = tr;
        tr = imag[i];
        imag[i] = imag[j];
        imag[j] = tr;
      }
      int m = n >> 1;
      while (m >= 1 && j >= m) {
        j -= m;
        m >>= 1;
      }
      j += m;
    }

    // Cooley–Tukey butterfly
    for (int size = 2; size <= n; size <<= 1) {
      final halfSize = size >> 1;
      final tableStep = -2.0 * math.pi / size;
      for (int i = 0; i < n; i += size) {
        for (int k = 0; k < halfSize; k++) {
          final angle = tableStep * k;
          final wr = math.cos(angle);
          final wi = math.sin(angle);
          final evenIdx = i + k;
          final oddIdx = i + k + halfSize;
          final tr = wr * real[oddIdx] - wi * imag[oddIdx];
          final ti = wr * imag[oddIdx] + wi * real[oddIdx];
          real[oddIdx] = real[evenIdx] - tr;
          imag[oddIdx] = imag[evenIdx] - ti;
          real[evenIdx] += tr;
          imag[evenIdx] += ti;
        }
      }
    }
  }

  /// Computes half-spectrum magnitudes using FFT.
  /// The input [frame] is zero-padded to [fftSize] (must be power of two).
  List<double> _computeMagnitudeSpectrumFFT(List<double> frame, int fftSize) {
    final real = Float64List(fftSize);
    final imag = Float64List(fftSize);
    final len = math.min(frame.length, fftSize);
    for (int i = 0; i < len; i++) {
      real[i] = frame[i];
    }
    _fftInPlace(real, imag);
    final half = fftSize ~/ 2;
    final magnitudes = List<double>.filled(half, 0.0);
    for (int k = 0; k < half; k++) {
      magnitudes[k] = math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
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

  /// Detect simultaneous fundamental frequencies (chord support) using an
  /// FFT-based spectral peak analysis with harmonic filtering.
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

    final fftSize = _nextPowerOfTwo(length);

    // Apply a Hann window and zero-pad to fftSize
    final real = Float64List(fftSize);
    final imag = Float64List(fftSize);
    for (int n = 0; n < length; n++) {
      final w = 0.5 * (1.0 - math.cos(2.0 * math.pi * n / (length - 1)));
      real[n] = segment[n] * w;
    }

    _fftInPlace(real, imag);

    final half = fftSize ~/ 2;
    final magnitudes = List<double>.filled(half, 0.0);
    for (int k = 0; k < half; k++) {
      magnitudes[k] = math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
    }

    final maxMag = magnitudes.fold<double>(0.0, (m, v) => v > m ? v : m);
    if (maxMag <= 0.0) return [];

    // Collect spectral peaks within the instrument's frequency range.
    // Require 15% of the global peak (slightly stricter to reduce false chord
    // detections from harmonic sidebands).
    final candidates = <Map<String, double>>[];
    for (int k = 1; k < half - 1; k++) {
      final freq = k * sampleRate / fftSize;
      if (freq < minFreq || freq > maxFreq) continue;

      final mag = magnitudes[k];
      if (mag <= maxMag * 0.15) continue;

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
