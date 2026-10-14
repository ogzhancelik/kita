import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/models/game_models.dart';
import '../../data/models/kita_ai.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/widgets/game/ai_advantage_bar.dart';

/// Temporary experimental mode helper specifically for player "iroztel".
/// Generates 10 random valid board states, evaluates depth 3 advantage for each
/// (matching the match replay advantage evaluation), and selects the state
/// whose score is closest to 0 (most balanced).
class IroztelExpMode {
  IroztelExpMode._();

  /// Returns true if the logged-in user or guest nickname is "iroztel".
  static bool isIroztelUser(AuthProvider? authProv) {
    if (authProv == null) return false;
    final username = authProv.currentUser?.username ??
        authProv.guestProfile?.nickname ??
        '';
    return username.trim().toLowerCase() == 'iroztel';
  }

  /// Generates a single valid, ongoing board state with pieces placed on random distinct tiles.
  static KitaGameEngine generateRandomValidBoard({Random? rng}) {
    final rand = rng ?? Random();
    final allTiles = KitaBoardConfig.tiles.keys.toList();

    int attempts = 0;
    while (attempts < 200) {
      attempts++;
      allTiles.shuffle(rand);

      final positions = <String, KitaPos?>{
        'WK': allTiles[0],
        'WP1': allTiles[1],
        'WP2': allTiles[2],
        'BK': allTiles[3],
        'BP1': allTiles[4],
        'BP2': allTiles[5],
      };

      final engine = KitaGameEngine.custom(
        positions: positions,
        turn: PieceTeam.white,
      );

      // Verify the board is playable, ongoing, and both teams have legal moves
      if (engine.getStatus() == GameStatus.ongoing &&
          engine.getLegalMoves().isNotEmpty &&
          engine.getLegalMovesForTeam(PieceTeam.black).isNotEmpty) {
        return engine;
      }
    }

    // Fallback safe starting state
    return KitaGameEngine();
  }

  /// Generates [candidateCount] random board states, evaluates each with depth 3 search,
  /// and returns the engine closest to 0.0 (most balanced).
  static Future<KitaGameEngine> generateBalancedBoard({
    int candidateCount = 10,
    int depth = 3,
  }) async {
    // Ensure AI weights are loaded before evaluating
    await KitaAI.instance.initialize();

    KitaGameEngine? bestEngine;
    double bestAbsDiff = double.infinity;
    double bestScore = 0.0;

    for (int i = 0; i < candidateCount; i++) {
      final engine = generateRandomValidBoard();
      final score = AiAdvantageBar.computeWhiteAdvantageScore(
        engine,
        KitaAI.instance,
        depth,
      );
      final absDiff = score.abs();

      debugPrint(
        '[IroztelExp] Candidate #${i + 1}/$candidateCount: score = ${score.toStringAsFixed(3)} (abs diff = ${absDiff.toStringAsFixed(3)})',
      );

      if (absDiff < bestAbsDiff) {
        bestAbsDiff = absDiff;
        bestScore = score;
        bestEngine = engine;
      }

      // Small async yield to keep UI responsive
      await Future.delayed(Duration.zero);
    }

    debugPrint(
      '[IroztelExp] Selected most balanced board: score = ${bestScore.toStringAsFixed(3)} (abs diff = ${bestAbsDiff.toStringAsFixed(3)})',
    );

    return bestEngine ?? generateRandomValidBoard();
  }
}
