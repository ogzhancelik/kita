import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Pure-Dart forward pass for KitaValueNet.
///
/// Architecture:
///   Linear(140→256) → LayerNorm(256) → ReLU
///   Linear(256→128) → LayerNorm(128) → ReLU
///   Linear(128→64)  → ReLU
///   Linear(64→1)    → Tanh
///
/// Zero external dependencies — just arithmetic on flat double arrays.
class KitaNeuralNet {
  // Linear layers: weight matrices [outDim][inDim] and bias vectors [outDim]
  late final List<List<double>> _fc0w; // [256][140]
  late final List<double> _fc0b;       // [256]
  late final List<List<double>> _fc1w; // [128][256]
  late final List<double> _fc1b;       // [128]
  late final List<List<double>> _fc2w; // [64][128]
  late final List<double> _fc2b;       // [64]
  late final List<List<double>> _fc3w; // [1][64]
  late final List<double> _fc3b;       // [1]

  // LayerNorm parameters: gamma (weight) and beta (bias)
  late final List<double> _ln0w; // [256]
  late final List<double> _ln0b; // [256]
  late final List<double> _ln1w; // [128]
  late final List<double> _ln1b; // [128]

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Load weights from a JSON asset file.
  Future<void> loadWeights(String assetPath) async {
    final jsonStr = await rootBundle.loadString(assetPath);
    loadWeightsFromJson(jsonStr);
  }

  /// Load weights directly from a JSON string.
  void loadWeightsFromJson(String jsonStr) {
    final Map<String, dynamic> data = json.decode(jsonStr);
    loadWeightsFromMap(data);
  }

  /// Load weights from a pre-parsed map.
  void loadWeightsFromMap(Map<String, dynamic> data) {
    _fc0w = _parseMatrix(data['fc0_weight']);
    _fc0b = _parseVector(data['fc0_bias']);
    _ln0w = _parseVector(data['ln0_weight']);
    _ln0b = _parseVector(data['ln0_bias']);

    _fc1w = _parseMatrix(data['fc1_weight']);
    _fc1b = _parseVector(data['fc1_bias']);
    _ln1w = _parseVector(data['ln1_weight']);
    _ln1b = _parseVector(data['ln1_bias']);

    _fc2w = _parseMatrix(data['fc2_weight']);
    _fc2b = _parseVector(data['fc2_bias']);

    _fc3w = _parseMatrix(data['fc3_weight']);
    _fc3b = _parseVector(data['fc3_bias']);

    _loaded = true;
  }

  /// Run the full forward pass.
  /// [input] must be a 140-element flat feature vector.
  /// Returns a scalar value in [-1.0, 1.0].
  double forward(List<double> input) {
    assert(_loaded, 'Call loadWeights() before forward()');
    assert(input.length == 140, 'Input must be 140 elements, got ${input.length}');

    // Layer 0: Linear(140→256) + LayerNorm + ReLU
    var x = _linear(input, _fc0w, _fc0b);
    x = _layerNorm(x, _ln0w, _ln0b);
    _reluInPlace(x);

    // Layer 1: Linear(256→128) + LayerNorm + ReLU
    x = _linear(x, _fc1w, _fc1b);
    x = _layerNorm(x, _ln1w, _ln1b);
    _reluInPlace(x);

    // Layer 2: Linear(128→64) + ReLU
    x = _linear(x, _fc2w, _fc2b);
    _reluInPlace(x);

    // Layer 3: Linear(64→1) + Tanh
    x = _linear(x, _fc3w, _fc3b);
    return _tanh(x[0]);
  }

  // ─── Math Helpers ───────────────────────────────────────────────────

  /// Matrix-vector multiply + bias: out[i] = sum_j(W[i][j] * x[j]) + b[i]
  List<double> _linear(
      List<double> x, List<List<double>> w, List<double> b) {
    final outDim = w.length;
    final result = List<double>.filled(outDim, 0.0);
    for (int i = 0; i < outDim; i++) {
      double sum = b[i];
      final row = w[i];
      for (int j = 0; j < row.length; j++) {
        sum += row[j] * x[j];
      }
      result[i] = sum;
    }
    return result;
  }

  /// LayerNorm: normalize, then scale by gamma and shift by beta.
  /// eps = 1e-5 (PyTorch default).
  List<double> _layerNorm(
      List<double> x, List<double> gamma, List<double> beta) {
    final n = x.length;
    double mean = 0.0;
    for (int i = 0; i < n; i++) {
      mean += x[i];
    }
    mean /= n;

    double variance = 0.0;
    for (int i = 0; i < n; i++) {
      final d = x[i] - mean;
      variance += d * d;
    }
    variance /= n;

    final invStd = 1.0 / math.sqrt(variance + 1e-5);
    final result = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      result[i] = (x[i] - mean) * invStd * gamma[i] + beta[i];
    }
    return result;
  }

  /// ReLU in-place: x[i] = max(0, x[i])
  void _reluInPlace(List<double> x) {
    for (int i = 0; i < x.length; i++) {
      if (x[i] < 0.0) x[i] = 0.0;
    }
  }

  /// Tanh activation
  double _tanh(double x) {
    // Dart's math doesn't have tanh, compute manually
    if (x > 20.0) return 1.0;
    if (x < -20.0) return -1.0;
    final e2x = math.exp(2.0 * x);
    return (e2x - 1.0) / (e2x + 1.0);
  }

  // ─── JSON Parsing ───────────────────────────────────────────────────

  List<List<double>> _parseMatrix(dynamic data) {
    return (data as List)
        .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();
  }

  List<double> _parseVector(dynamic data) {
    return (data as List).map((v) => (v as num).toDouble()).toList();
  }
}
