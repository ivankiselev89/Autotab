/// Holds all tunable parameters for note detection.
///
/// Users can pick a preset (Low / Medium / High) and then customise
/// individual parameters to taste.
class DetectionParams {
  /// Minimum YIN confidence to accept a detected pitch (0.0–1.0).
  /// Lower = more permissive (catches more notes, more false positives).
  final double minYinConfidence;

  /// Minimum note duration in seconds.  Segments shorter than this are
  /// discarded as noise.
  final double minNoteDuration;

  /// Multiplier applied to the mean-energy onset threshold.
  /// Lower = more sensitive to soft onsets.
  final double onsetFactor;

  /// Factor by which a frame's energy must exceed the previous frame to
  /// trigger an energy-based onset.
  final double jumpFactor;

  /// Multiplier for the local-mean spectral-flux threshold.
  /// Lower = more sensitive to timbral changes.
  final double fluxFactor;

  /// Minimum gap (seconds) between two successive onsets.
  final double minGapSeconds;

  /// Noise-reduction aggressiveness applied during spectral subtraction.
  /// Higher = more noise removed (but more risk of eating quiet notes).
  final double noiseReductionFactor;

  /// Noise-gate threshold factor multiplied by the signal RMS.
  /// Lower = more permissive gate.
  final double noiseGateFactor;

  /// Maximum time (seconds) between two consecutive same-pitch notes for
  /// them to be merged.  Notes separated by more than this are kept
  /// distinct – this prevents repeated notes from being swallowed.
  /// Set to 0 to disable merging entirely.
  final double repeatNoteMergeGap;

  const DetectionParams({
    required this.minYinConfidence,
    required this.minNoteDuration,
    required this.onsetFactor,
    required this.jumpFactor,
    required this.fluxFactor,
    required this.minGapSeconds,
    required this.noiseReductionFactor,
    required this.noiseGateFactor,
    required this.repeatNoteMergeGap,
  });

  /// Low sensitivity – cleaner output, fewer false positives.
  factory DetectionParams.low() => const DetectionParams(
        minYinConfidence: 0.82,
        minNoteDuration: 0.04,
        onsetFactor: 1.4,
        jumpFactor: 1.6,
        fluxFactor: 2.0,
        minGapSeconds: 0.20,
        noiseReductionFactor: 2.3,
        noiseGateFactor: 0.15,
        repeatNoteMergeGap: 0.08,
      );

  /// Medium sensitivity – balanced between accuracy and coverage.
  factory DetectionParams.medium() => const DetectionParams(
        minYinConfidence: 0.70,
        minNoteDuration: 0.03,
        onsetFactor: 1.0,
        jumpFactor: 1.3,
        fluxFactor: 1.2,
        minGapSeconds: 0.14,
        noiseReductionFactor: 1.8,
        noiseGateFactor: 0.10,
        repeatNoteMergeGap: 0.06,
      );

  /// High sensitivity – captures everything, may include more noise.
  factory DetectionParams.high() => const DetectionParams(
        minYinConfidence: 0.55,
        minNoteDuration: 0.02,
        onsetFactor: 0.7,
        jumpFactor: 1.15,
        fluxFactor: 0.7,
        minGapSeconds: 0.10,
        noiseReductionFactor: 1.4,
        noiseGateFactor: 0.06,
        repeatNoteMergeGap: 0.04,
      );

  /// Build from a preset name string.
  factory DetectionParams.fromPreset(String preset) {
    switch (preset.toLowerCase()) {
      case 'low':
        return DetectionParams.low();
      case 'medium':
        return DetectionParams.medium();
      case 'high':
      default:
        return DetectionParams.high();
    }
  }

  /// Create a copy with some fields overridden.
  DetectionParams copyWith({
    double? minYinConfidence,
    double? minNoteDuration,
    double? onsetFactor,
    double? jumpFactor,
    double? fluxFactor,
    double? minGapSeconds,
    double? noiseReductionFactor,
    double? noiseGateFactor,
    double? repeatNoteMergeGap,
  }) {
    return DetectionParams(
      minYinConfidence: minYinConfidence ?? this.minYinConfidence,
      minNoteDuration: minNoteDuration ?? this.minNoteDuration,
      onsetFactor: onsetFactor ?? this.onsetFactor,
      jumpFactor: jumpFactor ?? this.jumpFactor,
      fluxFactor: fluxFactor ?? this.fluxFactor,
      minGapSeconds: minGapSeconds ?? this.minGapSeconds,
      noiseReductionFactor: noiseReductionFactor ?? this.noiseReductionFactor,
      noiseGateFactor: noiseGateFactor ?? this.noiseGateFactor,
      repeatNoteMergeGap: repeatNoteMergeGap ?? this.repeatNoteMergeGap,
    );
  }

  Map<String, dynamic> toJson() => {
        'minYinConfidence': minYinConfidence,
        'minNoteDuration': minNoteDuration,
        'onsetFactor': onsetFactor,
        'jumpFactor': jumpFactor,
        'fluxFactor': fluxFactor,
        'minGapSeconds': minGapSeconds,
        'noiseReductionFactor': noiseReductionFactor,
        'noiseGateFactor': noiseGateFactor,
        'repeatNoteMergeGap': repeatNoteMergeGap,
      };

  factory DetectionParams.fromJson(Map<String, dynamic> json) =>
      DetectionParams(
        minYinConfidence: (json['minYinConfidence'] as num).toDouble(),
        minNoteDuration: (json['minNoteDuration'] as num).toDouble(),
        onsetFactor: (json['onsetFactor'] as num).toDouble(),
        jumpFactor: (json['jumpFactor'] as num).toDouble(),
        fluxFactor: (json['fluxFactor'] as num).toDouble(),
        minGapSeconds: (json['minGapSeconds'] as num).toDouble(),
        noiseReductionFactor: (json['noiseReductionFactor'] as num).toDouble(),
        noiseGateFactor: (json['noiseGateFactor'] as num).toDouble(),
        repeatNoteMergeGap: (json['repeatNoteMergeGap'] as num).toDouble(),
      );
}
