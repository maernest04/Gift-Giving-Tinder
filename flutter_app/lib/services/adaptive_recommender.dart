import 'dart:math';

import '../models/swipe_item.dart';

/// A tiny on-device "ML" model: contextual bandit via Thompson sampling
/// with Bayesian linear regression on your existing 10-D item vectors.
///
/// - Features: item.vector (length = d)
/// - Reward: like => 1.0, dislike => 0.0
/// - Model: theta ~ N(mu, sigma^2 * A^-1), where mu = A^-1 b
/// - Update: A += x x^T, b += r x
///
/// This gives adaptive recommendations with built-in exploration.
class AdaptiveRecommender {
  final int d;
  final Random _rng;

  /// Exploration strength (higher explores more).
  final double priorVariance;

  /// Small chance to pick a random unseen item (keeps variety).
  final double epsilon;

  late List<List<double>> _A; // d x d
  late List<double> _b; // d

  AdaptiveRecommender({
    required this.d,
    int? seed,
    this.priorVariance = 0.6,
    this.epsilon = 0.15,
  }) : _rng = Random(seed) {
    reset();
  }

  void reset() {
    _A = List.generate(
      d,
      (i) => List.generate(d, (j) => i == j ? 1.0 : 0.0),
    );
    _b = List.filled(d, 0.0);
  }

  void update(List<double> x, {required bool liked}) {
    final r = liked ? 1.0 : 0.0;
    if (x.length != d) {
      throw ArgumentError('Expected feature vector length $d, got ${x.length}');
    }

    // A += x x^T
    for (int i = 0; i < d; i++) {
      for (int j = 0; j < d; j++) {
        _A[i][j] += x[i] * x[j];
      }
    }

    // b += r x
    for (int i = 0; i < d; i++) {
      _b[i] += r * x[i];
    }
  }

  /// Picks the next item from candidates.
  /// Uses Thompson sampling + a little epsilon-randomness.
  SwipeItem? selectNext(List<SwipeItem> candidates) {
    if (candidates.isEmpty) return null;

    // Cheap exploration: random pick with probability epsilon.
    if (_rng.nextDouble() < epsilon) {
      return candidates[_rng.nextInt(candidates.length)];
    }

    final invA = _invert(_A);
    final mu = _matVec(invA, _b); // A^-1 b

    // Sample theta ~ N(mu, priorVariance^2 * invA)
    final z = List<double>.generate(d, (_) => _stdNormal());
    final L = _cholesky(_scale(invA, priorVariance * priorVariance));
    final noise = _matVec(L, z);
    final theta = List<double>.generate(d, (i) => mu[i] + noise[i]);

    double bestScore = double.negativeInfinity;
    SwipeItem? best;

    for (final item in candidates) {
      final x = item.vector;
      if (x.length != d) continue;
      final score = _dot(theta, x);
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }

    return best ?? candidates.first;
  }

  // -----------------------
  // Linear algebra helpers
  // -----------------------

  double _dot(List<double> a, List<double> b) {
    double s = 0.0;
    for (int i = 0; i < a.length; i++) {
      s += a[i] * b[i];
    }
    return s;
  }

  List<double> _matVec(List<List<double>> M, List<double> v) {
    final out = List<double>.filled(M.length, 0.0);
    for (int i = 0; i < M.length; i++) {
      double s = 0.0;
      for (int j = 0; j < v.length; j++) {
        s += M[i][j] * v[j];
      }
      out[i] = s;
    }
    return out;
  }

  List<List<double>> _scale(List<List<double>> M, double s) {
    return List.generate(
      M.length,
      (i) => List.generate(M.length, (j) => M[i][j] * s),
    );
  }

  /// Cholesky decomposition for symmetric PSD matrices.
  /// Returns lower-triangular L such that L L^T = M.
  List<List<double>> _cholesky(List<List<double>> M) {
    final n = M.length;
    final L = List.generate(n, (_) => List.filled(n, 0.0));

    for (int i = 0; i < n; i++) {
      for (int j = 0; j <= i; j++) {
        double sum = M[i][j];
        for (int k = 0; k < j; k++) {
          sum -= L[i][k] * L[j][k];
        }

        if (i == j) {
          // Guard tiny negative due to numeric error.
          L[i][j] = sqrt(max(sum, 1e-12));
        } else {
          L[i][j] = sum / L[j][j];
        }
      }
    }
    return L;
  }

  /// Inverts a matrix using Gauss-Jordan elimination (fine for d=10).
  List<List<double>> _invert(List<List<double>> M) {
    final n = M.length;
    final a = List.generate(n, (i) => List<double>.from(M[i]));
    final inv = List.generate(n, (i) {
      final row = List<double>.filled(n, 0.0);
      row[i] = 1.0;
      return row;
    });

    for (int i = 0; i < n; i++) {
      // Pivot (partial)
      int pivot = i;
      double best = a[i][i].abs();
      for (int r = i + 1; r < n; r++) {
        final v = a[r][i].abs();
        if (v > best) {
          best = v;
          pivot = r;
        }
      }

      if (best < 1e-12) {
        // Add a tiny ridge to diagonal and continue.
        a[i][i] += 1e-6;
      }

      if (pivot != i) {
        final tmp = a[i];
        a[i] = a[pivot];
        a[pivot] = tmp;
        final tmp2 = inv[i];
        inv[i] = inv[pivot];
        inv[pivot] = tmp2;
      }

      final diag = a[i][i];
      final invDiag = 1.0 / diag;
      for (int j = 0; j < n; j++) {
        a[i][j] *= invDiag;
        inv[i][j] *= invDiag;
      }

      for (int r = 0; r < n; r++) {
        if (r == i) continue;
        final factor = a[r][i];
        if (factor == 0.0) continue;
        for (int c = 0; c < n; c++) {
          a[r][c] -= factor * a[i][c];
          inv[r][c] -= factor * inv[i][c];
        }
      }
    }
    return inv;
  }

  // -----------------------
  // Random helpers
  // -----------------------

  /// Standard normal via Box-Muller.
  double _stdNormal() {
    // Avoid log(0)
    final u1 = max(_rng.nextDouble(), 1e-12);
    final u2 = _rng.nextDouble();
    return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
  }

  /// Gets the learned user preference vector (mean of posterior).
  /// This represents what the model has learned about user preferences.
  List<double> getLearnedPreferenceVector() {
    try {
      final invA = _invert(_A);
      return _matVec(invA, _b); // mu = A^-1 b
    } catch (_) {
      // Fallback if matrix inversion fails
      return List.filled(d, 0.0);
    }
  }

  /// Gets the current model state for persistence/analysis.
  Map<String, dynamic> getModelState() {
    return {
      'preferenceVector': getLearnedPreferenceVector(),
      'observationCount': _b.length > 0 ? _b.map((x) => x.abs()).reduce((a, b) => a + b).round() : 0,
    };
  }
}

