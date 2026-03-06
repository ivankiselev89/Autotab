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

    /// Step 1: Calculate the difference function for tau in [1, maxTau].
    /// Computing from tau=1 (not minTau) is required so that the cumulative
    /// mean normalisation in step 2 uses the correct running sum.
    /// Using buffer.length/2 (not yinBuffer.length/2) as the correlation
    /// window gives many more reference samples, which is critical for low
    /// fundamental frequencies whose period can exceed yinBuffer.length/2.
    void _differenceFunction(List<double> buffer, List<double> yinBuffer, int minTau, int maxTau) {
        final halfSize = buffer.length ~/ 2;

        for (int tau = 1; tau <= maxTau; tau++) {
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
        // Accept if the minimum is reasonably low (stricter than threshold to
        // reduce false detections when there is no clear pitch).
        return yinBuffer[bestTau] < 0.35 ? bestTau : -1;
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