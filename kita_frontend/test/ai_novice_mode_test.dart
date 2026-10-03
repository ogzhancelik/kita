import 'package:flutter_test/flutter_test.dart';
import 'package:kita_frontend/data/models/game_models.dart';
import 'package:kita_frontend/data/models/kita_ai.dart';
import 'package:kita_frontend/presentation/providers/offline_game_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Novice AI Tactical & Random Engine Tests', () {
    late KitaAI ai;

    setUp(() {
      ai = KitaAI.instance;
    });

    test('AIDifficulty.novice is defined correctly as 4th tier below beginner', () {
      expect(AIDifficulty.all.length, 4);
      expect(AIDifficulty.all.first, equals(AIDifficulty.novice));
      expect(AIDifficulty.novice.depth, equals(3));
      expect(AIDifficulty.novice.isTacticalRandom, isTrue);
      expect(AIDifficulty.novice.label, equals('Novice'));
    });

    test('Direct win: executes immediate winning move (captures opponent King)', () {
      // White King at (3, 0), Black King at (4, 0).
      // Since BK is at (4, 0) which is a 1-value tile, White must take exactly 1 step.
      // WK can step directly from (3, 0) to (4, 0) to capture BK.
      // BP1 is far away at (6, 3) and cannot retaliate.
      // White also has WP1 at (0, 0) which can move to (1, 0).
      final positions = <String, KitaPos?>{
        'WK': const KitaPos(3, 0),
        'WP1': const KitaPos(0, 0),
        'BK': const KitaPos(4, 0),
        'BP1': const KitaPos(6, 3),
      };

      final engine = KitaGameEngine.custom(
        positions: positions,
        turn: PieceTeam.white,
      );

      final move = ai.chooseMoveWithDifficulty(engine, AIDifficulty.novice);

      expect(move, isNotNull);
      expect(move!.pieceId, equals('WK'));
      expect(move.toPos, equals(const KitaPos(4, 0)));
    });

    test('Direct win: pawn captures opponent King for victory', () {
      // White Pawn WP1 at (3, 0), Black King at (4, 0) (tile value 1).
      // WP1 can capture BK directly by moving from (3, 0) to (4, 0).
      // White King is safe at (0, 0).
      final positions = <String, KitaPos?>{
        'WK': const KitaPos(0, 0),
        'WP1': const KitaPos(3, 0),
        'BK': const KitaPos(4, 0),
        'BP1': const KitaPos(6, 3),
      };

      final engine = KitaGameEngine.custom(
        positions: positions,
        turn: PieceTeam.white,
      );

      final move = ai.chooseMoveTacticalRandom(engine, depth: 3);

      expect(move, isNotNull);
      expect(move!.pieceId, equals('WP1'));
      expect(move.toPos, equals(const KitaPos(4, 0)));
    });

    test('Direct loss avoidance: avoids moves that allow opponent to capture King on next turn', () {
      // White King at (3, 0).
      // Black King at (5, 0). Black King can reach (4, 0) if White moves there.
      // If White King moves to (4, 0), Black King at (5, 0) can capture White King on the very next turn!
      // But White also has WP1 at (0, 0) that can move safely to (1, 0) or WK can move to (2, 0).
      final positions = <String, KitaPos?>{
        'WK': const KitaPos(3, 0),
        'WP1': const KitaPos(0, 0),
        'BK': const KitaPos(5, 0),
        'BP1': const KitaPos(6, 3),
      };

      final engine = KitaGameEngine.custom(
        positions: positions,
        turn: PieceTeam.white,
      );

      // Run multiple times to verify randomness does not pick the suicidal move
      for (int i = 0; i < 20; i++) {
        final move = ai.chooseMoveTacticalRandom(engine, depth: 3);
        expect(move, isNotNull);
        // Suicidal move would be WK moving to (4, 0) right into BK's capture range
        final isSuicidal = move!.pieceId == 'WK' && move.toPos == const KitaPos(4, 0);
        expect(isSuicidal, isFalse,
            reason: 'Novice AI must avoid moving directly into an immediate loss');
      }
    });

    test('Plays randomly among non-losing moves when no direct win/loss exists', () {
      // In initial position, no one can win or lose within 3 plies.
      final engine = KitaGameEngine();
      final movesChosen = <String>{};

      // Sample 30 moves from initial state
      for (int i = 0; i < 30; i++) {
        final move = ai.chooseMoveTacticalRandom(engine, depth: 3);
        expect(move, isNotNull);
        movesChosen.add('${move!.pieceId}:${move.toPos.col},${move.toPos.row}');
      }

      // Randomness ensures multiple distinct legal moves are picked
      expect(movesChosen.length, greaterThan(1),
          reason: 'Novice AI should play randomly when no win or loss is detected');
    });

    test('OfflineGameProvider integration with Novice tier', () {
      SharedPreferences.setMockInitialValues({});
      final prov = OfflineGameProvider();

      prov.startOfflineMatch(
        mode: PlayMode.vsAi,
        botDifficulty: 0, // Novice
      );

      expect(prov.offlineBotDifficulty, equals(0));
      expect(prov.opponentInfo?.rating, equals(800));
      expect(prov.offlineBotDifficultyLabel, isNotEmpty);

      prov.setOfflineBotDifficulty(1); // Easy/Beginner
      expect(prov.offlineBotDifficulty, equals(1));
      expect(prov.opponentInfo?.rating, equals(1000));

      prov.setOfflineBotDifficulty(2); // Medium/Intermediate
      expect(prov.offlineBotDifficulty, equals(2));
      expect(prov.opponentInfo?.rating, equals(1200));

      prov.setOfflineBotDifficulty(3); // Hard/Grandmaster
      expect(prov.offlineBotDifficulty, equals(3));
      expect(prov.opponentInfo?.rating, equals(1400));

      prov.dispose();
    });
  });
}
