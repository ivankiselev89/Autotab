class PitchDetectionService {
    // Define frequency ranges for different instruments
    static const Map<String, List<double>> frequencyRanges = {
        'vocals': [85.0, 255.0],
        'guitar': [82.0, 880.0],
        'piano': [27.5, 4186.0],
        'bass': [41.2, 400.0],
    };

    // Constants for Yin algorithm
    static const double yinThreshold = 0.15; // Typical threshold value
    static const int defaultSampleRate = 44100;

    /// Detects pitch using the Yin algorithm
    /// [audioSignal] - The input audio buffer
    /// [sampleRate] - The sample rate of the audio (default: 44100 Hz)
    /// Returns the detected frequency in Hz, or 0.0 if no pitch is detected
    double detectPitch(List<double> audioSignal, {int sampleRate = defaultSampleRate}) {
        if (audioSignal.isEmpty) {
            return 0.0;
        }

        final bufferSize = audioSignal.length;
        final halfBufferSize = bufferSize ~/ 2;

        // Step 1: Calculate the difference function
        final yinBuffer = List<double>.filled(halfBufferSize, 0.0);
        _differenceFunction(audioSignal, yinBuffer);

        // Step 2: Calculate the cumulative mean normalized difference function
        _cumulativeMeanNormalizedDifference(yinBuffer);

        // Step 3: Find the absolute threshold
        final tauEstimate = _absoluteThreshold(yinBuffer, yinThreshold);

        if (tauEstimate == -1) {
            // No pitch detected
            return 0.0;
        }

        // Step 4: Parabolic interpolation for better precision
        final betterTau = _parabolicInterpolation(yinBuffer, tauEstimate);

        // Convert tau to frequency
        return sampleRate / betterTau;
    }

    /// Step 1: Calculate the difference function
    /// d_t(tau) = sum of squared differences
    void _differenceFunction(List<double> buffer, List<double> yinBuffer) {
        final yinBufferSize = yinBuffer.length;

        for (int tau = 0; tau < yinBufferSize; tau++) {
            double sum = 0.0;
            for (int i = 0; i < yinBufferSize; i++) {
                final delta = buffer[i] - buffer[i + tau];
                sum += delta * delta;
            }
            yinBuffer[tau] = sum;
        }
    }

    /// Step 2: Calculate the cumulative mean normalized difference function
    /// d'_t(tau) = d_t(tau) / [(1/tau) * sum(d_t(j)) for j=1 to tau]
    void _cumulativeMeanNormalizedDifference(List<double> yinBuffer) {
        yinBuffer[0] = 1.0;
        double runningSum = 0.0;

        for (int tau = 1; tau < yinBuffer.length; tau++) {
            runningSum += yinBuffer[tau];
            yinBuffer[tau] *= tau / runningSum;
        }
    }

    /// Step 3: Find the first local minimum below the threshold
    /// Returns the tau (lag) value, or -1 if no pitch is found
    int _absoluteThreshold(List<double> yinBuffer, double threshold) {
        // Start from tau = 2 to avoid the trivial solution at tau = 0
        for (int tau = 2; tau < yinBuffer.length; tau++) {
            if (yinBuffer[tau] < threshold) {
                // Check if this is a local minimum
                while (tau + 1 < yinBuffer.length && yinBuffer[tau + 1] < yinBuffer[tau]) {
                    tau++;
                }
                return tau;
            }
        }
        return -1;
    }

    /// Step 4: Parabolic interpolation for better frequency resolution
    /// Uses three points around the minimum to estimate a more precise tau
    double _parabolicInterpolation(List<double> yinBuffer, int tauEstimate) {
        if (tauEstimate == 0 || tauEstimate >= yinBuffer.length - 1) {
            return tauEstimate.toDouble();
        }

        final s0 = yinBuffer[tauEstimate - 1];
        final s1 = yinBuffer[tauEstimate];
        final s2 = yinBuffer[tauEstimate + 1];

        // Parabolic interpolation formula
        final adjustment = (s2 - s0) / (2 * (2 * s1 - s2 - s0));
        
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