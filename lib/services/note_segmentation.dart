import '../models/note.dart';
import 'pitch_detection.dart';
import 'dart:math' as math;

class NoteSegmentationService {
  final PitchDetectionService _pitchDetection = PitchDetectionService();
  
  // Configuration parameters for onset detection
  static const double onsetThreshold = 0.1; // Amplitude threshold for note onset
  static const int hopSize = 512; // Number of samples to skip between frames
  static const int frameSize = 2048; // Window size for analysis
  static const double minNoteDuration = 0.05; // Minimum note duration in seconds
  
  /// Segments continuous audio into individual notes with timing and frequency information.
  /// 
  /// Uses onset detection to identify note boundaries and pitch detection to determine frequencies.
  /// Returns a list of Note objects with timing, frequency, and pitch information.
  List<Note> segmentAudio(List<double> audioData, {double sampleRate = 44100.0}) {
    if (audioData.isEmpty) {
      return [];
    }
    
    List<Note> notes = [];
    
    // Step 1: Detect note onsets using energy-based method
    final onsets = _detectOnsets(audioData, sampleRate);
    
    // Step 2: For each onset, extract the note segment and detect its pitch
    for (int i = 0; i < onsets.length; i++) {
      final startSample = onsets[i];
      final endSample = (i < onsets.length - 1) 
          ? onsets[i + 1] 
          : audioData.length;
      
      // Extract the segment
      final segment = audioData.sublist(startSample, endSample);
      
      // Skip very short segments
      final duration = (endSample - startSample) / sampleRate;
      if (duration < minNoteDuration) {
        continue;
      }
      
      // Detect pitch for this segment
      final frequency = _pitchDetection.detectPitch(segment, sampleRate: sampleRate.toInt());
      
      // Skip segments with no detectable pitch
      if (frequency == 0.0) {
        continue;
      }
      
      // Convert frequency to note name and octave
      final noteInfo = _frequencyToNote(frequency);
      
      // Calculate confidence based on signal strength
      final confidence = _calculateConfidence(segment);
      
      notes.add(Note(
        frequency: frequency.round(),
        noteName: noteInfo['name']!,
        octave: int.parse(noteInfo['octave']!),
        startTime: startSample / sampleRate,
        endTime: endSample / sampleRate,
        confidence: confidence,
      ));
    }
    
    return notes;
  }
  
  /// Detects note onsets using energy-based method
  /// Returns list of sample indices where onsets occur
  List<int> _detectOnsets(List<double> audioData, double sampleRate) {
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
    
    // Calculate adaptive threshold based on local energy
    final meanEnergy = energies.reduce((a, b) => a + b) / energies.length;
    final threshold = meanEnergy * onsetThreshold;
    
    // Detect onsets as points where energy exceeds threshold
    bool inNote = false;
    for (int i = 1; i < energies.length; i++) {
      final currentEnergy = energies[i];
      final prevEnergy = energies[i - 1];
      
      // Onset: energy increases above threshold
      if (!inNote && currentEnergy > threshold && currentEnergy > prevEnergy * 1.5) {
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
    final octave = (midiNote / 12) - 1;
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