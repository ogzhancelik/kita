import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'game_models.dart';
import 'kita_neural_net.dart';

// ─── Board Tile Mapping (must match Python training pipeline exactly) ─────

/// Sorted list of all 20 valid tile positions on the Kita cross-shaped board.
/// Order must match the Python VALID_TILES = sorted(list(TILES_INFO.keys())).
/// Python sorts tuples lexicographically: (col, row) ascending.
const List<List<int>> _validTiles = [
  [0, 0], [0, 1], [0, 2], [0, 3],
  [1, 0], [1, 3],
  [2, 0], [2, 3],
  [3, 0], [3, 1], [3, 2], [3, 3],
  [4, 0], [4, 3],
  [5, 0], [5, 3],
  [6, 0], [6, 1], [6, 2], [6, 3],
];

/// Tile values matching KitaBoardConfig.tiles, normalized by /3.0
const Map<int, double> _tileValuesNormalized = {
  // Indexed by _validTiles index
  0: 2 / 3, 1: 3 / 3, 2: 3 / 3, 3: 2 / 3,       // col 0
  4: 3 / 3, 5: 3 / 3,                               // col 1
  6: 1 / 3, 7: 1 / 3,                               // col 2
  8: 2 / 3, 9: 1 / 3, 10: 1 / 3, 11: 2 / 3,       // col 3
  12: 1 / 3, 13: 1 / 3,                             // col 4
  14: 3 / 3, 15: 3 / 3,                             // col 5
  16: 2 / 3, 17: 3 / 3, 18: 3 / 3, 19: 2 / 3,     // col 6
};

/// Map from (col, row) → index in the 20-tile array.
final Map<int, int> _tileToIdx = () {
  final map = <int, int>{};
  for (int i = 0; i < _validTiles.length; i++) {
    final key = _validTiles[i][0] * 10 + _validTiles[i][1];
    map[key] = i;
  }
  return map;
}();

int? _posToIdx(KitaPos pos) => _tileToIdx[pos.col * 10 + pos.row];

// ─── Row labels for opening book coordinate parsing ──────────────────

const _rowLabels = ['A', 'B', 'C', 'D'];

// ─── Difficulty Presets ──────────────────────────────────────────────

class AIDifficulty {
  final int depth;
  final double temperature;
  final String label;

  const AIDifficulty({
    required this.depth,
    required this.temperature,
    required this.label,
  });

  static const easy = AIDifficulty(depth: 1, temperature: 0.5, label: 'Easy');
  static const medium = AIDifficulty(depth: 2, temperature: 0.2, label: 'Medium');
  static const hard = AIDifficulty(depth: 3, temperature: 0.1, label: 'Hard');

  static const all = [easy, medium, hard];
}

// ─── Scored Move ─────────────────────────────────────────────────────

class ScoredMove {
  final KitaMove move;
  final double score;

  const ScoredMove(this.move, this.score);
}

// ─── Main AI Player ──────────────────────────────────────────────────

class KitaAI {
  static final KitaAI instance = KitaAI();

  final KitaNeuralNet _net = KitaNeuralNet();
  Map<String, List<String>> _openingBook = {};
  bool _initialized = false;
  Future<void>? _initFuture;

  bool get isInitialized => _initialized;

  /// Initialize the AI by loading model weights and opening book.
  Future<void> initialize() async {
    if (_initialized) return;
    _initFuture ??= _doInitialize();
    await _initFuture;
  }

  Future<void> _doInitialize() async {
    if (_initialized) return;

    await _net.loadWeights('assets/ai/kita_model_weights.json');

    try {
      final bookJson =
          await rootBundle.loadString('assets/ai/opening_book.json');
      final Map<String, dynamic> bookData = json.decode(bookJson);
      _openingBook = _parseOpeningBookData(bookData);
    } catch (_) {
      // Opening book is optional — continue without it
      _openingBook = {};
    }

    _initialized = true;
  }

  /// Initialize the AI directly with JSON strings (useful for unit tests & offline bundles).
  void initializeWithStrings(String weightsJson, [String? openingBookJson]) {
    _net.loadWeightsFromJson(weightsJson);
    if (openingBookJson != null) {
      try {
        final Map<String, dynamic> bookData = json.decode(openingBookJson);
        _openingBook = _parseOpeningBookData(bookData);
      } catch (_) {
        _openingBook = {};
      }
    }
    _initialized = true;
  }

  Map<String, List<String>> _parseOpeningBookData(Map<String, dynamic> data) {
    final result = <String, List<String>>{};
    for (final entry in data.entries) {
      if (entry.value is List) {
        result[entry.key] =
            (entry.value as List).map((e) => e.toString()).toList();
      } else if (entry.value is String) {
        result[entry.key] = [entry.value as String];
      }
    }
    return result;
  }

  // ─── Feature Encoding ──────────────────────────────────────────────

  /// Convert a KitaGameEngine state into a 140-element feature vector.
  /// Matches Python game_to_tensor() exactly.
  ///
  /// 7 channels × 20 tiles = 140 features:
  ///   Channel 0: My king positions
  ///   Channel 1: My pawn positions
  ///   Channel 2: Opponent king positions
  ///   Channel 3: Opponent pawn positions
  ///   Channel 4: Opponent's last move (src=-1, dst=+1)
  ///   Channel 5: My last move (src=-1, dst=+1)
  ///   Channel 6: Static tile values (normalized)
  List<double> gameToTensor(KitaGameEngine engine) {
    final features = List<double>.filled(140, 0.0);

    // Channel 6: Static tile channel (precomputed)
    for (int i = 0; i < 20; i++) {
      features[6 * 20 + i] = _tileValuesNormalized[i] ?? 0.0;
    }

    final isWhiteTurn = engine.turn == PieceTeam.white;
    final myColor = isWhiteTurn ? PieceTeam.white : PieceTeam.black;

    final myLastMove =
        isWhiteTurn ? engine.lastMoveWhite : engine.lastMoveBlack;
    final oppLastMove =
        isWhiteTurn ? engine.lastMoveBlack : engine.lastMoveWhite;

    // Channels 0-3: Piece positions
    for (final entry in engine.positions.entries) {
      final pos = entry.value;
      if (pos == null) continue;
      final idx = _posToIdx(pos);
      if (idx == null) continue;

      final piece = KitaPiece.allPieces[entry.key];
      if (piece == null) continue;

      final isMine = piece.team == myColor;
      final isKing = piece.isKing;

      if (isMine && isKing) {
        features[0 * 20 + idx] = 1.0;
      } else if (isMine && !isKing) {
        features[1 * 20 + idx] = 1.0;
      } else if (!isMine && isKing) {
        features[2 * 20 + idx] = 1.0;
      } else {
        features[3 * 20 + idx] = 1.0;
      }
    }

    // Channel 4: Opponent's last move
    if (oppLastMove != null) {
      final srcIdx = _posToIdx(oppLastMove.fromPos);
      final dstIdx = _posToIdx(oppLastMove.toPos);
      if (srcIdx != null) features[4 * 20 + srcIdx] = -1.0;
      if (dstIdx != null) features[4 * 20 + dstIdx] = 1.0;
    }

    // Channel 5: My last move
    if (myLastMove != null) {
      final srcIdx = _posToIdx(myLastMove.fromPos);
      final dstIdx = _posToIdx(myLastMove.toPos);
      if (srcIdx != null) features[5 * 20 + srcIdx] = -1.0;
      if (dstIdx != null) features[5 * 20 + dstIdx] = 1.0;
    }

    return features;
  }

  /// Create a FEN-like string for opening book lookup.
  /// Matches Python game_to_fen() exactly.
  String gameToFen(KitaGameEngine engine) {
    final turnChar =
        engine.turn == PieceTeam.white ? 'W' : 'B';
    final posStrs = <String>[];

    // Sort by piece ID to match Python sorted(game.positions.items())
    final sortedEntries = engine.positions.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedEntries) {
      if (entry.value != null) {
        posStrs.add('${entry.key}:${entry.value!.col},${entry.value!.row}');
      }
    }

    return '$turnChar|${posStrs.join(';')}';
  }

  /// Look up the current position in the opening book.
  /// If found, randomly selects one of the valid candidate moves.
  /// Returns null if not found or no moves can be parsed.
  KitaMove? _lookupBookMove(KitaGameEngine engine) {
    if (_openingBook.isEmpty) return null;

    final fen = gameToFen(engine);
    final bookMoveList = _openingBook[fen];
    if (bookMoveList == null || bookMoveList.isEmpty) return null;

    final legalMoves = engine.getLegalMoves();
    final candidateMoves = <KitaMove>[];
    for (final moveStr in bookMoveList) {
      final parsed = _parseBookMoveString(moveStr, legalMoves);
      if (parsed != null) {
        candidateMoves.add(parsed);
      }
    }

    if (candidateMoves.isEmpty) return null;
    return candidateMoves[_rng.nextInt(candidateMoves.length)];
  }

  /// Parse an opening book move string into a KitaMove.
  /// Format: "WK: D7 -> D5" where D=row label, 7=1-indexed column.
  KitaMove? _parseBookMoveString(String moveStr, List<KitaMove> legalMoves) {
    for (final m in legalMoves) {
      final fStr =
          '${_rowLabels[m.fromPos.row]}${m.fromPos.col + 1}';
      final tStr =
          '${_rowLabels[m.toPos.row]}${m.toPos.col + 1}';
      final formatted = '${m.pieceId}: $fStr -> $tStr';
      if (formatted == moveStr) return m;
    }
    return null;
  }

  // ─── Evaluation ────────────────────────────────────────────────────

  /// Evaluate the position from the current player's perspective.
  /// Returns a value in [-1.0, 1.0] for ongoing games, or ±10.0 for terminal states.
  double evaluateState(KitaGameEngine engine) {
    final status = engine.getStatus();
    if (status != GameStatus.ongoing) {
      if (status == GameStatus.draw) return 0.0;
      final isWhiteTurn = engine.turn == PieceTeam.white;
      if (status == GameStatus.whiteWins) {
        return isWhiteTurn ? 10.0 : -10.0;
      }
      return isWhiteTurn ? -10.0 : 10.0;
    }

    final tensor = gameToTensor(engine);
    double score = _net.forward(tensor);

    // Normalize the opening phase to keep the advantage closer to 0.0
    // Applies during the first 6 plies (3 full turns)
    if (engine.moveCount < 6) {
      // Starts at ~16% of the real score and scales up to 100% by move 6
      double factor = (engine.moveCount + 1) / 6.0;
      score *= factor;
    }

    return score;
  }

  /// Evaluates the state using a shallow search (Quiescence Search)
  /// to resolve immediate tactical blunders before passing to the static evaluator.
  double evaluateStateWithSearch(KitaGameEngine engine, {int depth = 1}) {
    return _negamax(engine, depth, -double.infinity, double.infinity);
  }

  // ─── Negamax Search ────────────────────────────────────────────────

  /// Recursive negamax with alpha-beta pruning.
  /// Returns evaluation from the perspective of engine.turn.
  /// Terminal wins/losses incorporate depth bonus (±10.0 ± depth).
  double _negamax(KitaGameEngine engine, int depth, double alpha, double beta) {
    final status = engine.getStatus();
    if (status != GameStatus.ongoing) {
      if (status == GameStatus.draw) return 0.0;
      final isWhiteTurn = engine.turn == PieceTeam.white;
      if (status == GameStatus.whiteWins) {
        return isWhiteTurn ? (10.0 + depth) : (-10.0 - depth);
      }
      return isWhiteTurn ? (-10.0 - depth) : (10.0 + depth);
    }

    if (depth <= 0) {
      return evaluateState(engine);
    }

    final moves = engine.getLegalMoves();
    if (moves.isEmpty) return -10.0 - depth;

    double bestVal = -double.infinity;
    for (final move in moves) {
      final nextEngine = engine.applyMove(move);
      final val = -_negamax(nextEngine, depth - 1, -beta, -alpha);
      if (val > bestVal) bestVal = val;
      if (bestVal > alpha) alpha = bestVal;
      if (alpha >= beta) break; // Beta cutoff
    }

    return bestVal;
  }

  /// Evaluate a single candidate move from the current player's perspective.
  double _evaluateMove(KitaGameEngine engine, KitaMove move, int depth) {
    final player = engine.turn;
    final nextEngine = engine.applyMove(move);
    final status = nextEngine.getStatus();

    if (status != GameStatus.ongoing) {
      if (status == GameStatus.draw) return 0.0;
      final isWhiteWins = status == GameStatus.whiteWins;
      final playerIsWhite = player == PieceTeam.white;
      return (isWhiteWins == playerIsWhite) ? (10.0 + depth) : (-10.0 - depth);
    }

    if (depth <= 1) {
      return -evaluateState(nextEngine);
    }

    return -_negamax(nextEngine, depth - 1, -double.infinity, double.infinity);
  }

  // ─── Move Ranking ──────────────────────────────────────────────────

  /// Score and rank all legal moves, best first.
  List<ScoredMove> getRankedMoves(KitaGameEngine engine, int depth) {
    final moves = engine.getLegalMoves();
    if (moves.isEmpty) return [];

    // Check opening book first
    final bookMove = _lookupBookMove(engine);
    if (bookMove != null) {
      return [ScoredMove(bookMove, 1.0)];
    }

    final scored = <ScoredMove>[];
    for (final m in moves) {
      final score = _evaluateMove(engine, m, depth);
      scored.add(ScoredMove(m, score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  /// Choose a move with optional temperature-based softmax sampling.
  /// If temperature <= 0: greedy (best move).
  /// If temperature > 0: softmax sampling for variety.
  /// If [addDirichletNoise] is enabled (default true) and it is the very first move
  /// of the game for White (ply 0: engine.moveCount == 0 && turn == white),
  /// Dirichlet noise is blended into the move probabilities (AlphaZero style).
  KitaMove? chooseMove(
    KitaGameEngine engine, {
    int depth = 2,
    double temperature = 0.2,
    bool addDirichletNoise = true,
    double dirichletAlpha = 0.3,
    double dirichletEpsilon = 0.4,
  }) {
    final ranked = getRankedMoves(engine, depth);
    if (ranked.isEmpty) return null;

    final isWhiteFirstMove =
        engine.moveCount == 0 && engine.turn == PieceTeam.white;

    // Instant/forced win check: always take guaranteed victory immediately
    if (ranked.first.score >= 10.0) {
      final bestScore = ranked.first.score;
      final bestMoves = ranked
          .where((sm) => (sm.score - bestScore).abs() < 1e-4)
          .toList();
      return bestMoves[_rng.nextInt(bestMoves.length)].move;
    }

    // Softmax sampling with asymmetric penalty for negative scores
    final scores = ranked.map((sm) => sm.score).toList();

    // Penalize negative scores more heavily (matches Python play_ai.py)
    final adjusted = scores.map((s) => s < 0 ? s * 3.0 : s).toList();

    // Use a baseline temperature for White's opening move if temp is too low or greedy
    final effectiveTemp = (isWhiteFirstMove && addDirichletNoise && temperature <= 1e-4)
        ? 0.3
        : temperature;

    if (effectiveTemp <= 1e-4) {
      // Greedy / deterministic
      final bestScore = ranked.first.score;
      final bestMoves = ranked
          .where((sm) => (sm.score - bestScore).abs() < 1e-4)
          .toList();
      return bestMoves[_rng.nextInt(bestMoves.length)].move;
    }

    final maxAdj = adjusted.reduce((a, b) => a > b ? a : b);
    final logits =
        adjusted.map((s) => (s - maxAdj) / effectiveTemp).toList();
    final expLogits = logits.map((l) => math.exp(l)).toList();
    final sumExp = expLogits.reduce((a, b) => a + b);
    var probs = expLogits.map((e) => e / sumExp).toList();

    // Apply Dirichlet noise for the very first move of White bot (ply = 0)
    if (isWhiteFirstMove && addDirichletNoise && probs.length > 1) {
      final noise = _sampleDirichlet(probs.length, dirichletAlpha);
      probs = List<double>.generate(probs.length, (i) {
        return (1.0 - dirichletEpsilon) * probs[i] +
            dirichletEpsilon * noise[i];
      });
      final pSum = probs.reduce((a, b) => a + b);
      if (pSum > 0) {
        probs = probs.map((p) => p / pSum).toList();
      }
    }

    // Weighted random selection
    final r = _rng.nextDouble();
    double cumulative = 0.0;
    for (int i = 0; i < ranked.length; i++) {
      cumulative += probs[i];
      if (r <= cumulative) return ranked[i].move;
    }

    return ranked.last.move;
  }

  /// Samples a vector of probabilities from a symmetric Dirichlet distribution Dir(alpha).
  /// Generated via independent Gamma(alpha, 1) variates normalized by their sum.
  static List<double> _sampleDirichlet(int k, double alpha) {
    if (k <= 0) return [];
    if (k == 1) return [1.0];

    final samples = List<double>.generate(k, (_) => _sampleGamma(alpha, 1.0));
    final sum = samples.reduce((a, b) => a + b);
    if (sum <= 0 || sum.isNaN || sum.isInfinite) {
      return List<double>.filled(k, 1.0 / k);
    }
    return samples.map((s) => s / sum).toList();
  }

  /// Samples from Gamma(shape, scale) using Marsaglia and Tsang method (2000).
  static double _sampleGamma(double shape, double scale) {
    if (shape < 1.0) {
      // Gamma(a) = Gamma(a + 1) * U^(1/a)
      final u = _rng.nextDouble();
      return _sampleGamma(shape + 1.0, scale) * math.pow(u, 1.0 / shape);
    }

    final d = shape - 1.0 / 3.0;
    final c = 1.0 / math.sqrt(9.0 * d);

    while (true) {
      double z;
      double v;
      do {
        // Standard normal variate via Box-Muller
        final u1 = _rng.nextDouble().clamp(1e-15, 1.0);
        final u2 = _rng.nextDouble();
        z = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
        v = 1.0 + c * z;
      } while (v <= 0.0);

      v = v * v * v;
      final u = _rng.nextDouble().clamp(1e-15, 1.0);

      // Fast squeeze check
      if (u < 1.0 - 0.0331 * z * z * z * z) {
        return d * v * scale;
      }

      if (math.log(u) < 0.5 * z * z + d * (1.0 - v + math.log(v))) {
        return d * v * scale;
      }
    }
  }

  /// Choose a move using a preset difficulty tier.
  KitaMove? chooseMoveWithDifficulty(
    KitaGameEngine engine,
    AIDifficulty difficulty, {
    bool addDirichletNoise = true,
  }) {
    return chooseMove(
      engine,
      depth: difficulty.depth,
      temperature: difficulty.temperature,
      addDirichletNoise: addDirichletNoise,
    );
  }

  static final _rng = math.Random();
}
