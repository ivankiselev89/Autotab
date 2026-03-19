import 'dart:math' as math;

/// FFT and spectral analysis utilities using radix-2 Cooley-Tukey FFT.
///
/// Replaces naive O(N²) DFT with O(N log N) FFT for dramatically faster
/// spectral analysis.  Also provides Harmonic Product Spectrum (HPS) for
/// robust fundamental-frequency detection (Rocksmith-style) and spectral
/// flatness for noise vs. pitched-signal discrimination.
class FFTUtils {
  // Floor value used in log-domain when a magnitude bin is effectively zero.
  // Equivalent to log(1e-10) ≈ -23.03.
  static const double _logFloor = -23.0;

  // Divisor used to normalise the HPS peak-above-median gap into a 0–1
  // confidence score.  Chosen empirically so that clean single-instrument
  // signals score close to 1.0.
  static const double _hpsConfidenceScale = 20.0;
  /// Returns the smallest power of 2 that is >= [n].
  static int nextPowerOf2(int n) {
    int p = 1;
    while (p < n) {
      p <<= 1;
    }
    return p;
  }

  /// In-place radix-2 Cooley-Tukey FFT.
  ///
  /// [real] and [imag] must have the same length, which must be a power of 2.
  static void fft(List<double> real, List<double> imag) {
    final n = real.length;
    if (n <= 1) return;

    // Bit-reversal permutation
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        double t = real[i];
        real[i] = real[j];
        real[j] = t;
        t = imag[i];
        imag[i] = imag[j];
        imag[j] = t;
      }
      int m = n >> 1;
      while (m >= 1 && j >= m) {
        j -= m;
        m >>= 1;
      }
      j += m;
    }

    // Cooley-Tukey butterfly operations
    for (int size = 2; size <= n; size *= 2) {
      final halfSize = size ~/ 2;
      final angle = -2.0 * math.pi / size;
      final wR = math.cos(angle);
      final wI = math.sin(angle);

      for (int i = 0; i < n; i += size) {
        double cR = 1.0, cI = 0.0;
        for (int k = 0; k < halfSize; k++) {
          final e = i + k;
          final o = e + halfSize;
          final tR = cR * real[o] - cI * imag[o];
          final tI = cR * imag[o] + cI * real[o];
          real[o] = real[e] - tR;
          imag[o] = imag[e] - tI;
          real[e] += tR;
          imag[e] += tI;
          final nr = cR * wR - cI * wI;
          cI = cR * wI + cI * wR;
          cR = nr;
        }
      }
    }
  }

  /// Computes the magnitude spectrum of a real-valued signal using FFT.
  ///
  /// Returns the first half (positive frequencies) of the spectrum.  The
  /// input is zero-padded to the next power of 2 when necessary.  The
  /// actual FFT size is written to [fftSizeOut] if provided so callers
  /// can convert bin indices to frequencies.
  static List<double> magnitudeSpectrum(
    List<double> frame, {
    List<int>? fftSizeOut,
  }) {
    final n = nextPowerOf2(frame.length);
    if (fftSizeOut != null) {
      if (fftSizeOut.isEmpty) {
        fftSizeOut.add(n);
      } else {
        fftSizeOut[0] = n;
      }
    }
    final real = List<double>.filled(n, 0.0);
    final imag = List<double>.filled(n, 0.0);
    for (int i = 0; i < frame.length; i++) {
      real[i] = frame[i];
    }
    fft(real, imag);
    final half = n ~/ 2;
    return List<double>.generate(
      half,
      (k) => math.sqrt(real[k] * real[k] + imag[k] * imag[k]),
    );
  }

  /// Computes a Hann-windowed magnitude spectrum via FFT.
  static List<double> windowedMagnitudeSpectrum(
    List<double> frame, {
    List<int>? fftSizeOut,
  }) {
    if (frame.length <= 1) return [0.0];
    final windowed = List<double>.generate(frame.length, (i) {
      final w =
          0.5 * (1.0 - math.cos(2.0 * math.pi * i / (frame.length - 1)));
      return frame[i] * w;
    });
    return magnitudeSpectrum(windowed, fftSizeOut: fftSizeOut);
  }

  /// Harmonic Product Spectrum (HPS) – Rocksmith-inspired pitch detection.
  ///
  /// Multiplies down-sampled copies of the magnitude spectrum to suppress
  /// harmonics and emphasise the fundamental.  Returns a map with keys
  /// `'frequency'` (Hz, or 0.0 if no pitch) and `'confidence'` (0.0–1.0).
  static Map<String, double> harmonicProductSpectrum(
    List<double> frame, {
    double sampleRate = 44100.0,
    double minFrequency = 60.0,
    double maxFrequency = 1400.0,
    int harmonics = 5,
  }) {
    final n = nextPowerOf2(frame.length);
    final real = List<double>.filled(n, 0.0);
    final imag = List<double>.filled(n, 0.0);

    // Apply Hann window
    for (int i = 0; i < frame.length; i++) {
      final w =
          0.5 * (1.0 - math.cos(2.0 * math.pi * i / (frame.length - 1)));
      real[i] = frame[i] * w;
    }

    fft(real, imag);

    final half = n ~/ 2;
    final magnitudes = List<double>.generate(
      half,
      (k) => math.sqrt(real[k] * real[k] + imag[k] * imag[k]),
    );

    // HPS: work in log-domain to avoid over/underflow
    final hpsLength = half ~/ harmonics;
    if (hpsLength < 2) {
      return {'frequency': 0.0, 'confidence': 0.0};
    }

    final hps = List<double>.filled(hpsLength, 0.0);
    for (int k = 0; k < hpsLength; k++) {
      double logSum = 0.0;
      for (int h = 1; h <= harmonics; h++) {
        final mag = magnitudes[k * h];
        logSum += mag > 1e-10 ? math.log(mag) : _logFloor;
      }
      hps[k] = logSum;
    }

    // Determine valid bin range from the frequency bounds.
    final minBin =
        math.max(1, (minFrequency * n / sampleRate).round());
    final maxBin =
        math.min(hpsLength - 1, (maxFrequency * n / sampleRate).round());
    if (minBin >= maxBin) {
      return {'frequency': 0.0, 'confidence': 0.0};
    }

    // Find the peak bin
    int bestBin = minBin;
    double bestValue = hps[minBin];
    for (int k = minBin + 1; k <= maxBin; k++) {
      if (hps[k] > bestValue) {
        bestValue = hps[k];
        bestBin = k;
      }
    }

    // Confidence: how much the peak stands out above the median level.
    final sortedSlice = List<double>.from(hps.sublist(minBin, maxBin + 1))
      ..sort();
    final median = sortedSlice[sortedSlice.length ~/ 2];
    final confidence = ((bestValue - median) / _hpsConfidenceScale).clamp(0.0, 1.0);

    if (confidence < 0.05) {
      return {'frequency': 0.0, 'confidence': 0.0};
    }

    // Parabolic interpolation for sub-bin accuracy
    double freq = bestBin * sampleRate / n;
    if (bestBin > minBin && bestBin < maxBin) {
      final s0 = hps[bestBin - 1];
      final s1 = hps[bestBin];
      final s2 = hps[bestBin + 1];
      final denom = 2.0 * (2.0 * s1 - s2 - s0);
      if (denom.abs() > 1e-10) {
        final adjustment = (s2 - s0) / denom;
        freq = (bestBin + adjustment) * sampleRate / n;
      }
    }

    return {'frequency': freq, 'confidence': confidence};
  }

  /// Spectral flatness (Wiener entropy) of a magnitude spectrum.
  ///
  /// Returns a value between 0.0 (strongly tonal / pitched) and 1.0
  /// (noise-like).  Used to distinguish pitched content from noise so
  /// that noisy segments can be rejected before pitch detection.
  static double spectralFlatness(List<double> magnitudes) {
    if (magnitudes.isEmpty) return 1.0;

    double logSum = 0.0;
    double linearSum = 0.0;
    int count = 0;

    for (final m in magnitudes) {
      if (m > 1e-10) {
        logSum += math.log(m);
        linearSum += m;
        count++;
      }
    }

    if (count == 0 || linearSum <= 0.0) return 1.0;

    final geometricMean = math.exp(logSum / count);
    final arithmeticMean = linearSum / count;

    return (geometricMean / arithmeticMean).clamp(0.0, 1.0);
  }
}
