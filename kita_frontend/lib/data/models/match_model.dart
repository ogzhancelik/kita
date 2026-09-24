import 'game_models.dart';
import 'user_model.dart';

class MoveRecordModel {
  final int ply;
  final String playerId;
  final String piece;
  final int fromCol;
  final int fromRow;
  final int toCol;
  final int toRow;
  final int timeMs;
  final DateTime? createdAt;

  const MoveRecordModel({
    required this.ply,
    required this.playerId,
    required this.piece,
    required this.fromCol,
    required this.fromRow,
    required this.toCol,
    required this.toRow,
    this.timeMs = 0,
    this.createdAt,
  });

  KitaMove toKitaMove() => KitaMove(
        pieceId: piece,
        fromPos: KitaPos(fromCol, fromRow),
        toPos: KitaPos(toCol, toRow),
      );

  String get notation => toKitaMove().notation;

  factory MoveRecordModel.fromJson(Map<String, dynamic> json) {
    return MoveRecordModel(
      ply: (json['ply'] as num?)?.toInt() ?? 0,
      playerId: json['player_id'] as String? ?? '',
      piece: json['piece'] as String? ?? '',
      fromCol: (json['from_col'] as num?)?.toInt() ?? 0,
      fromRow: (json['from_row'] as num?)?.toInt() ?? 0,
      toCol: (json['to_col'] as num?)?.toInt() ?? 0,
      toRow: (json['to_row'] as num?)?.toInt() ?? 0,
      timeMs: (json['time_ms'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'ply': ply,
        'player_id': playerId,
        'piece': piece,
        'from_col': fromCol,
        'from_row': fromRow,
        'to_col': toCol,
        'to_row': toRow,
        'time_ms': timeMs,
        'created_at': createdAt?.toIso8601String(),
      };
}

class MatchRecordModel {
  final String id;
  final String whitePlayerId;
  final String blackPlayerId;
  final UserProfile? whitePlayer;
  final UserProfile? blackPlayer;
  final String? winnerId;
  final String result;
  final int totalMoves;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<MoveRecordModel> moves;
  final bool isOffline;

  const MatchRecordModel({
    required this.id,
    required this.whitePlayerId,
    required this.blackPlayerId,
    this.whitePlayer,
    this.blackPlayer,
    this.winnerId,
    required this.result,
    required this.totalMoves,
    required this.startedAt,
    this.endedAt,
    this.moves = const [],
    this.isOffline = false,
  });

  bool get isWhiteWinner => winnerId != null && winnerId == whitePlayerId;
  bool get isBlackWinner => winnerId != null && winnerId == blackPlayerId;
  bool get isDraw => result == 'draw';

  factory MatchRecordModel.fromJson(Map<String, dynamic> json) {
    final rawMoves = json['moves'] as List<dynamic>? ?? [];
    final matchId = json['id'] as String? ?? '';
    return MatchRecordModel(
      id: matchId,
      whitePlayerId: json['white_player_id'] as String? ?? '',
      blackPlayerId: json['black_player_id'] as String? ?? '',
      whitePlayer: json['white_player'] != null
          ? UserProfile.fromJson(json['white_player'] as Map<String, dynamic>)
          : null,
      blackPlayer: json['black_player'] != null
          ? UserProfile.fromJson(json['black_player'] as Map<String, dynamic>)
          : null,
      winnerId: json['winner_id'] as String?,
      result: json['result'] as String? ?? 'ongoing',
      totalMoves: (json['total_moves'] as num?)?.toInt() ?? rawMoves.length,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())
          : null,
      moves: rawMoves
          .map((m) => MoveRecordModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      isOffline: json['is_offline'] == true || matchId.startsWith('offline'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'white_player_id': whitePlayerId,
        'black_player_id': blackPlayerId,
        'white_player': whitePlayer?.toJson(),
        'black_player': blackPlayer?.toJson(),
        'winner_id': winnerId,
        'result': result,
        'total_moves': totalMoves,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'moves': moves.map((m) => m.toJson()).toList(),
        'is_offline': isOffline,
      };

  /// Creates an exciting, verified demo match for demonstration & testing
  static MatchRecordModel sampleDemoMatch() {
    final now = DateTime.now().subtract(const Duration(hours: 3));
    return MatchRecordModel(
      id: 'demo-match-sample-1',
      whitePlayerId: 'player-white-demo',
      blackPlayerId: 'player-black-demo',
      whitePlayer: const UserProfile(
        id: 'player-white-demo',
        username: 'Grandmaster_Kita',
        rating: 1540,
        wins: 48,
        losses: 12,
        draws: 5,
        totalGames: 65,
        winRate: 73.8,
      ),
      blackPlayer: const UserProfile(
        id: 'player-black-demo',
        username: 'TacticalRook',
        rating: 1495,
        wins: 39,
        losses: 20,
        draws: 8,
        totalGames: 67,
        winRate: 58.2,
      ),
      winnerId: 'player-white-demo',
      result: 'white_wins',
      totalMoves: 8,
      startedAt: now,
      endedAt: now.add(const Duration(minutes: 6, seconds: 15)),
      moves: [
        // Ply 1: White WP2 moves
        MoveRecordModel(
          ply: 1,
          playerId: 'player-white-demo',
          piece: 'WP2',
          fromCol: 6,
          fromRow: 3,
          toCol: 6,
          toRow: 1,
          timeMs: 1240,
        ),
        // Ply 2: Black BP1 moves
        MoveRecordModel(
          ply: 2,
          playerId: 'player-black-demo',
          piece: 'BP1',
          fromCol: 0,
          fromRow: 0,
          toCol: 0,
          toRow: 2,
          timeMs: 2450,
        ),
        // Ply 3: White WP1 moves
        MoveRecordModel(
          ply: 3,
          playerId: 'player-white-demo',
          piece: 'WP1',
          fromCol: 6,
          fromRow: 0,
          toCol: 6,
          toRow: 2,
          timeMs: 1800,
        ),
        // Ply 4: Black BP2 moves
        MoveRecordModel(
          ply: 4,
          playerId: 'player-black-demo',
          piece: 'BP2',
          fromCol: 0,
          fromRow: 3,
          toCol: 0,
          toRow: 1,
          timeMs: 3100,
        ),
        // Ply 5: White WK moves towards center
        MoveRecordModel(
          ply: 5,
          playerId: 'player-white-demo',
          piece: 'WK',
          fromCol: 6,
          fromRow: 1,
          toCol: 5,
          toRow: 0,
          timeMs: 4200,
        ),
        // Ply 6: Black BK advances
        MoveRecordModel(
          ply: 6,
          playerId: 'player-black-demo',
          piece: 'BK',
          fromCol: 0,
          fromRow: 1,
          toCol: 1,
          toRow: 0,
          timeMs: 2900,
        ),
        // Ply 7: White WP1 pushes inward
        MoveRecordModel(
          ply: 7,
          playerId: 'player-white-demo',
          piece: 'WP1',
          fromCol: 6,
          fromRow: 2,
          toCol: 5,
          toRow: 3,
          timeMs: 1560,
        ),
        // Ply 8: Black BP1 maneuvers
        MoveRecordModel(
          ply: 8,
          playerId: 'player-black-demo',
          piece: 'BP1',
          fromCol: 0,
          fromRow: 2,
          toCol: 1,
          toRow: 3,
          timeMs: 2100,
        ),
      ],
    );
  }
}
