import 'dart:math' as math;
import 'fft_utils.dart';

class PitchDetectionService {
    // Define frequency ranges for different instruments
    static const Map<String, List<double>> frequencyRanges = {
        'vocals': [85.0, 255.0],
        'guitar': [75.0, 1400.0],
        'piano': [27.5, 4186.0],
        // 5-string bass (B0–G4). Allow a bit above fundamentals
        // to capture harmonics used in real recordings.
        'bass': [28.0, 400.0],
        'banjo': [146.8, 1760.0],
    };

    // Constants for Yin algorithm
    static const double yinThreshold = 0.12; // Threshold for pitch detection
    static const int defaultSampleRate = 44100;

    /// Detects pitch using the Yin algorithm
    /// [audioSignal] - The input audio buffer
    /// [sampleRate] - The sample rate of the audio (default: 44100 Hz)
    /// [minFrequency] - Minimum detectable frequency in Hz (default: 60 Hz)
    /// [maxFrequency] - Maximum detectable frequency in Hz (default: 1400 Hz)
    /// Returns the detected frequency in Hz, or 0.0 if no pitch is detected
    double detectPitch(
      List<double> audioSignal, {
      int sampleRate = defaultSampleRate,
      double minFrequency = 60.0,
      double maxFrequency = 1400.0,
    }) {
        if (audioSignal.isEmpty) {
            return 0.0;
        }

        final bufferSize = audioSignal.length;
        final halfBufferSize = bufferSize ~/ 2;

        // Calculate tau bounds from frequency range to avoid harmonics
        // and reduce the search space for efficiency.
        final minTau = (sampleRate / maxFrequency).ceil().clamp(2, halfBufferSize - 1);
        final maxTau = (sampleRate / minFrequency).floor().clamp(minTau + 1, halfBufferSize - 1);

        if (minTau >= maxTau) {
            return 0.0;
        }

        // Step 1: Calculate the difference function
        final yinBuffer = List<double>.filled(maxTau + 1, 0.0);
        _differenceFunction(audioSignal, yinBuffer, minTau, maxTau);

        // Step 2: Calculate the cumulative mean normalized difference function
        _cumulativeMeanNormalizedDifference(yinBuffer, minTau, maxTau);

        // Step 3: Find the absolute threshold within the valid tau range
        final tauEstimate = _absoluteThreshold(yinBuffer, yinThreshold, minTau, maxTau);

        if (tauEstimate == -1) {
            // No pitch detected
            return 0.0;
        }

        // Step 4: Parabolic interpolation for better precision
        final betterTau = _parabolicInterpolation(yinBuffer, tauEstimate, maxTau);

        // Convert tau to frequency
        return sampleRate / betterTau;
    }

    /// Step 1: Calculate the difference function (only for tau in [minTau, maxTau])
    void _differenceFunction(List<double> buffer, List<double> yinBuffer, int minTau, int maxTau) {
        final halfSize = yinBuffer.length ~/ 2;

        for (int tau = minTau; tau <= maxTau; tau++) {
            double sum = 0.0;
            for (int i = 0; i < halfSize; i++) {
                final delta = buffer[i] - buffer[i + tau];
                sum += delta * delta;
            }
            yinBuffer[tau] = sum;
        }
    }

    /// Step 2: Calculate the cumulative mean normalized difference function
    void _cumulativeMeanNormalizedDifference(List<double> yinBuffer, int minTau, int maxTau) {
        yinBuffer[0] = 1.0;
        double runningSum = 0.0;

        // Accumulate from tau=1 to ensure correct normalization
        for (int tau = 1; tau <= maxTau; tau++) {
            runningSum += yinBuffer[tau];
            if (runningSum > 0.0) {
                yinBuffer[tau] *= tau / runningSum;
            } else {
                yinBuffer[tau] = 1.0;
            }
        }
    }

    /// Step 3: Find the first local minimum below the threshold in [minTau, maxTau]
    /// Returns the tau (lag) value, or -1 if no pitch is found
    int _absoluteThreshold(List<double> yinBuffer, double threshold, int minTau, int maxTau) {
        for (int tau = minTau; tau <= maxTau; tau++) {
            if (yinBuffer[tau] < threshold) {
                while (tau + 1 <= maxTau && yinBuffer[tau + 1] < yinBuffer[tau]) {
                    tau++;
                }
                return tau;
            }
        }
        // Fall back to global minimum in range if nothing is below threshold
        int bestTau = minTau;
        for (int tau = minTau + 1; tau <= maxTau; tau++) {
            if (yinBuffer[tau] < yinBuffer[bestTau]) {
                bestTau = tau;
            }
        }
        // Accept if the minimum is reasonably low
        return yinBuffer[bestTau] < 0.5 ? bestTau : -1;
    }

    /// Step 4: Parabolic interpolation for better frequency resolution
    double _parabolicInterpolation(List<double> yinBuffer, int tauEstimate, int maxTau) {
        if (tauEstimate <= 0 || tauEstimate >= maxTau) {
            return tauEstimate.toDouble();
        }

        final s0 = yinBuffer[tauEstimate - 1];
        final s1 = yinBuffer[tauEstimate];
        final s2 = yinBuffer[tauEstimate + 1];

        final denominator = 2 * (2 * s1 - s2 - s0);

        if (denominator.abs() < 1e-10) {
            return tauEstimate.toDouble();
        }

        final adjustment = (s2 - s0) / denominator;

        return tauEstimate + adjustment;
    }

    /// Checks if the detected pitch falls within a specific instrument range
    bool isPitchInRange(String instrument, double pitch) {
        if (frequencyRanges.containsKey(instrument)) {
            final range = frequencyRanges[instrument]!;
            return pitch >= range[0] && pitch <= range[1];
        }
        return false;
    }

    /// Combined YIN + Harmonic Product Spectrum detection (Rocksmith-inspired).
    ///
    /// Uses both autocorrelation (YIN) and spectral analysis (HPS) to detect
    /// pitch.  When both algorithms agree the result is highly confident;
    /// disagreement reduces confidence, and harmonic-relationship analysis
    /// is used to resolve conflicts — similar to the cross-validation
    /// approach used in Rocksmith.
    ///
    /// Returns a [PitchResult] with the detected frequency and a confidence
    /// score in 0.0–1.0.
    PitchResult detectPitchCombined(
      List<double> audioSignal, {
      int sampleRate = defaultSampleRate,
      double minFrequency = 60.0,
      double maxFrequency = 1400.0,
    }) {
        if (audioSignal.isEmpty) {
            return PitchResult(frequency: 0.0, confidence: 0.0);
        }

        // YIN detection (autocorrelation-based)
        final yinFreq = detectPitch(
            audioSignal,
            sampleRate: sampleRate,
            minFrequency: minFrequency,
            maxFrequency: maxFrequency,
        );

        // HPS detection (spectral product — Rocksmith-style)
        final hpsResult = FFTUtils.harmonicProductSpectrum(
            audioSignal,
            sampleRate: sampleRate.toDouble(),
            minFrequency: minFrequency,
            maxFrequency: maxFrequency,
        );
        final hpsFreq = hpsResult['frequency']!;
        final hpsConf = hpsResult['confidence']!;

        // Neither found a pitch
        if (yinFreq == 0.0 && hpsFreq == 0.0) {
            return PitchResult(frequency: 0.0, confidence: 0.0);
        }

        // Only HPS found something — use it with reduced confidence
        if (yinFreq == 0.0) {
            return PitchResult(frequency: hpsFreq, confidence: hpsConf * 0.7);
        }

        // Only YIN found something
        if (hpsFreq == 0.0) {
            return PitchResult(frequency: yinFreq, confidence: 0.4);
        }

        // Both found pitches — measure agreement in semitones
        final semitoneDiff =
            (12.0 * (math.log(yinFreq / hpsFreq) / math.log(2))).abs();

        if (semitoneDiff < 0.5) {
            // Strong agreement — high confidence, use YIN (more precise)
            return PitchResult(
                frequency: yinFreq,
                confidence: (hpsConf + 0.3).clamp(0.0, 1.0),
            );
        } else if (semitoneDiff < 1.0) {
            // Moderate agreement — average
            return PitchResult(
                frequency: (yinFreq + hpsFreq) / 2.0,
                confidence: hpsConf * 0.8,
            );
        }

        // Disagreement — check for harmonic relationship.
        // If the frequencies are related by a small integer ratio, one
        // algorithm likely found a harmonic or sub-harmonic of the true
        // fundamental.  YIN tracks the actual signal periodicity and is
        // resistant to sub-harmonic artefacts; HPS can produce
        // sub-harmonics on pure tones.  Prefer YIN when the ratio
        // shows YIN is an integer multiple of HPS.
        final higher = math.max(yinFreq, hpsFreq);
        final lower = math.min(yinFreq, hpsFreq);
        final ratio = higher / lower;
        final nearestInt = ratio.round();
        final harmonicDev = (ratio - nearestInt).abs();

        if (nearestInt >= 2 && nearestInt <= 6 && harmonicDev < 0.12) {
            // Harmonic relationship detected
            if (yinFreq >= hpsFreq) {
                // HPS likely found a sub-harmonic — trust YIN
                return PitchResult(
                    frequency: yinFreq,
                    confidence: hpsConf * 0.7,
                );
            } else {
                // YIN likely found a harmonic — trust HPS
                return PitchResult(
                    frequency: hpsFreq,
                    confidence: hpsConf * 0.7,
                );
            }
        }

        // No clear harmonic relationship — low confidence, prefer YIN
        return PitchResult(frequency: yinFreq, confidence: hpsConf * 0.4);
    }
}

/// Result of a combined pitch detection pass.
class PitchResult {
    final double frequency;
    final double confidence;

    PitchResult({required this.frequency, required this.confidence});
}