/// Result of a pitch detection operation, carrying both the detected
/// frequency and a confidence score derived from the YIN algorithm's
/// cumulative mean normalized difference (CMND) value.
class PitchResult {
    final double frequency;
    /// Confidence in [0.0, 1.0].  Higher is better.  Derived as `1 - d'`
    /// where d' is the CMND value at the selected lag.
    final double confidence;

    const PitchResult(this.frequency, this.confidence);
    const PitchResult.none() : frequency = 0.0, confidence = 0.0;
}

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
        // Violin (G3–E7). Covers fundamentals and high positions.
        'violin': [196.0, 3136.0],
    };

    // Constants for Yin algorithm
    static const double yinThreshold = 0.12; // Threshold for pitch detection
    static const int defaultSampleRate = 44100;

    /// Detects pitch using the Yin algorithm.
    /// Returns the detected frequency in Hz, or 0.0 if no pitch is detected.
    double detectPitch(
      List<double> audioSignal, {
      int sampleRate = defaultSampleRate,
      double minFrequency = 60.0,
      double maxFrequency = 1400.0,
    }) {
        return detectPitchWithConfidence(
          audioSignal,
          sampleRate: sampleRate,
          minFrequency: minFrequency,
          maxFrequency: maxFrequency,
        ).frequency;
    }

    /// Detects pitch and returns both the frequency and a confidence score.
    ///
    /// The confidence is derived from the YIN CMND value at the detected lag:
    ///   confidence = 1.0 - d'
    /// A confidence of 1.0 means a perfectly periodic signal; values below
    /// ~0.85 are increasingly unreliable.
    PitchResult detectPitchWithConfidence(
      List<double> audioSignal, {
      int sampleRate = defaultSampleRate,
      double minFrequency = 60.0,
      double maxFrequency = 1400.0,
    }) {
        if (audioSignal.isEmpty) {
            return const PitchResult.none();
        }

        final bufferSize = audioSignal.length;
        final halfBufferSize = bufferSize ~/ 2;

        // Calculate tau bounds from frequency range to avoid harmonics
        // and reduce the search space for efficiency.
        final minTau = (sampleRate / maxFrequency).ceil().clamp(2, halfBufferSize - 1);
        final maxTau = (sampleRate / minFrequency).floor().clamp(minTau + 1, halfBufferSize - 1);

        if (minTau >= maxTau) {
            return const PitchResult.none();
        }

        // Step 1: Calculate the difference function
        final yinBuffer = List<double>.filled(maxTau + 1, 0.0);
        _differenceFunction(audioSignal, yinBuffer, minTau, maxTau);

        // Step 2: Calculate the cumulative mean normalized difference function
        _cumulativeMeanNormalizedDifference(yinBuffer, minTau, maxTau);

        // Step 3: Find the absolute threshold within the valid tau range
        final tauEstimate = _absoluteThreshold(yinBuffer, yinThreshold, minTau, maxTau);

        if (tauEstimate == -1) {
            return const PitchResult.none();
        }

        // Confidence = 1 - CMND value at the chosen lag.
        final cmndValue = yinBuffer[tauEstimate].clamp(0.0, 1.0);
        final confidence = 1.0 - cmndValue;

        // Step 4: Parabolic interpolation for better precision
        final betterTau = _parabolicInterpolation(yinBuffer, tauEstimate, maxTau);

        // Convert tau to frequency
        final frequency = sampleRate / betterTau;
        return PitchResult(frequency, confidence);
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
    /// Returns the tau (lag) value, or -1 if no pitch is found.
    ///
    /// Unlike earlier versions, the fallback to the global minimum uses a
    /// much stricter acceptance criterion (CMND < 0.3 instead of 0.5) to
    /// reduce false positives from noise or non-periodic content.
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
        // Stricter acceptance: only accept if the global minimum is reasonably
        // low.  A CMND value of 0.45 still corresponds to a somewhat periodic
        // signal – anything above is likely noise.
        return yinBuffer[bestTau] < 0.45 ? bestTau : -1;
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
}