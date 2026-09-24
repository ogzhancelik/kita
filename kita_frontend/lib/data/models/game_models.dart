// ─── Enums ───────────────────────────────────────────────────────────

enum PieceTeam { black, white }
enum PieceKind { king, pawn }

enum GameStatus { ongoing, whiteWins, blackWins, draw }

enum EndReason {
  kingCaptured,        // Captured king and opponent could not retaliate
  doubleKingCaptured,  // Both kings captured in sequence → Draw
  noMovesLeft,         // Player has 0 legal moves on their turn
  threefoldRepetition, // Same state reached 3 times → Draw
}

// ─── Position (matches backend board.go Pos) ─────────────────────────

class KitaPos {
  final int col;
  final int row;

  const KitaPos(this.col, this.row);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KitaPos &&
          runtimeType == other.runtimeType &&
          col == other.col &&
          row == other.row;

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => '($col, $row)';
}

// ─── Pieces (matches backend pieces.go) ──────────────────────────────

class KitaPiece {
  final String id;
  final PieceTeam team;
  final PieceKind kind;

  const KitaPiece({
    required this.id,
    required this.team,
    required this.kind,
  });

  bool get isKing => kind == PieceKind.king;
  bool get isPawn => kind == PieceKind.pawn;
  bool get isWhite => team == PieceTeam.white;
  bool get isBlack => team == PieceTeam.black;

  static const KitaPiece bk = KitaPiece(id: 'BK', team: PieceTeam.black, kind: PieceKind.king);
  static const KitaPiece bp1 = KitaPiece(id: 'BP1', team: PieceTeam.black, kind: PieceKind.pawn);
  static const KitaPiece bp2 = KitaPiece(id: 'BP2', team: PieceTeam.black, kind: PieceKind.pawn);
  static const KitaPiece wk = KitaPiece(id: 'WK', team: PieceTeam.white, kind: PieceKind.king);
  static const KitaPiece wp1 = KitaPiece(id: 'WP1', team: PieceTeam.white, kind: PieceKind.pawn);
  static const KitaPiece wp2 = KitaPiece(id: 'WP2', team: PieceTeam.white, kind: PieceKind.pawn);

  static const Map<String, KitaPiece> allPieces = {
    'BK': bk, 'BP1': bp1, 'BP2': bp2,
    'WK': wk, 'WP1': wp1, 'WP2': wp2,
  };

  /// Matches backend AllPieceIDs, BlackPieces, WhitePieces
  static const List<String> allPieceIds = ['BK', 'BP1', 'BP2', 'WK', 'WP1', 'WP2'];
  static const List<String> blackPieceIds = ['BK', 'BP1', 'BP2'];
  static const List<String> whitePieceIds = ['WK', 'WP1', 'WP2'];
}

// ─── Move (matches backend pieces.go Move) ───────────────────────────

class KitaMove {
  final String pieceId;
  final KitaPos fromPos;
  final KitaPos toPos;

  const KitaMove({
    required this.pieceId,
    required this.fromPos,
    required this.toPos,
  });

  /// Matches backend Move.IsReverseOf
  bool isReverseOf(KitaMove? other) {
    if (other == null) return false;
    return pieceId == other.pieceId && fromPos == other.toPos && toPos == other.fromPos;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KitaMove &&
          runtimeType == other.runtimeType &&
          pieceId == other.pieceId &&
          fromPos == other.fromPos &&
          toPos == other.toPos;

  @override
  int get hashCode => Object.hash(pieceId, fromPos, toPos);

  /// Formats coordinate (col, row) to standard notation (e.g. col 0, row 3 -> 'A1', col 0, row 0 -> 'D1')
  static String formatPos(KitaPos pos) {
    const rowLabels = ['D', 'C', 'B', 'A'];
    final r = (pos.row >= 0 && pos.row < rowLabels.length) ? rowLabels[pos.row] : '${pos.row}';
    return '$r${pos.col + 1}';
  }

  /// Algebraic move notation according to UI spec (e.g. "A2C3" or "♚A2C3")
  String get notation {
    final fromStr = formatPos(fromPos);
    final toStr = formatPos(toPos);
    final isKing = pieceId == 'WK' || pieceId == 'BK' || KitaPiece.allPieces[pieceId]?.isKing == true;
    final prefix = isKing ? '♚' : '';
    return '$prefix$fromStr$toStr';
  }

  @override
  String toString() => notation;
}

// ─── Board Configuration (matches backend board.go) ──────────────────

/// Internal stack entry for iterative DFS — matches backend StackEntry
class _StackEntry {
  final KitaPos pos;
  final int rem;
  final Set<KitaPos> visited;
  _StackEntry({required this.pos, required this.rem, required this.visited});
}

class KitaBoardConfig {
  KitaBoardConfig._();

  /// 7 cols x 4 rows cross-shaped board — matches backend Tiles
  static final Map<KitaPos, int> tiles = {
    const KitaPos(0, 0): 2, const KitaPos(1, 0): 3, const KitaPos(2, 0): 1,
    const KitaPos(3, 0): 2, const KitaPos(4, 0): 1, const KitaPos(5, 0): 3,
    const KitaPos(6, 0): 2,
    const KitaPos(0, 1): 3, const KitaPos(3, 1): 1, const KitaPos(6, 1): 3,
    const KitaPos(0, 2): 3, const KitaPos(3, 2): 1, const KitaPos(6, 2): 3,
    const KitaPos(0, 3): 2, const KitaPos(1, 3): 3, const KitaPos(2, 3): 1,
    const KitaPos(3, 3): 2, const KitaPos(4, 3): 1, const KitaPos(5, 3): 3,
    const KitaPos(6, 3): 2,
  };

  /// Precomputed 4-way orthogonal adjacency — matches backend Adjacency + init()
  static final Map<KitaPos, List<KitaPos>> adjacency = _buildAdjacency();

  static Map<KitaPos, List<KitaPos>> _buildAdjacency() {
    final map = <KitaPos, List<KitaPos>>{};
    const directions = [
      KitaPos(1, 0), KitaPos(-1, 0), KitaPos(0, 1), KitaPos(0, -1),
    ];
    for (final pos in tiles.keys) {
      final neighbors = <KitaPos>[];
      for (final d in directions) {
        final nb = KitaPos(pos.col + d.col, pos.row + d.row);
        if (tiles.containsKey(nb)) neighbors.add(nb);
      }
      map[pos] = neighbors;
    }
    return map;
  }

  static bool isValidTile(int col, int row) =>
      tiles.containsKey(KitaPos(col, row));

  static int getTileValue(int col, int row) =>
      tiles[KitaPos(col, row)] ?? 0;

  /// Matches backend TileValue(pos)
  static int tileValue(KitaPos pos) => tiles[pos] ?? 0;

  /// Initial piece placements — matches backend InitialPositions
  static Map<String, KitaPos?> initialPositions() => {
    'BK':  const KitaPos(0, 0),
    'BP1': const KitaPos(3, 0),
    'BP2': const KitaPos(0, 1),
    'WK':  const KitaPos(6, 3),
    'WP1': const KitaPos(3, 3),
    'WP2': const KitaPos(6, 2),
  };

  /// Graph traversal — matches backend FindReachable (iterative stack-based DFS)
  /// Walks step-by-step strictly along valid adjacent tiles.
  /// Cannot jump over holes or pass through occupied squares on intermediate steps.
  /// On the final step, can land on unoccupied tiles OR tiles in the landable set.
  static Set<KitaPos> findReachable({
    required KitaPos start,
    required int steps,
    required Set<KitaPos> occupied,
    required Set<KitaPos> landable,
  }) {
    if (steps <= 0) return {start};

    final destinations = <KitaPos>{};
    final stack = [
      _StackEntry(pos: start, rem: steps, visited: {start}),
    ];

    while (stack.isNotEmpty) {
      final entry = stack.removeLast();
      final neighbors = adjacency[entry.pos] ?? [];

      for (final nb in neighbors) {
        if (entry.visited.contains(nb)) continue;

        if (entry.rem == 1) {
          // Landing step: can land on unoccupied or landable (opponent king)
          if (!occupied.contains(nb) || landable.contains(nb)) {
            destinations.add(nb);
          }
        } else {
          // Intermediate step: cannot pass through occupied tiles
          if (occupied.contains(nb)) continue;
          final newVisited = Set<KitaPos>.from(entry.visited)..add(nb);
          stack.add(_StackEntry(
            pos: nb,
            rem: entry.rem - 1,
            visited: newVisited,
          ));
        }
      }
    }

    return destinations;
  }
}

// ─── Game State for 3-fold repetition (matches backend state.go) ─────

class KitaGameState {
  final String positions;
  final PieceTeam turn;
  final KitaMove? lastMoveWhite;
  final KitaMove? lastMoveBlack;
  final String kingEatenBy;

  const KitaGameState({
    required this.positions,
    required this.turn,
    this.lastMoveWhite,
    this.lastMoveBlack,
    this.kingEatenBy = '',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KitaGameState &&
          runtimeType == other.runtimeType &&
          positions == other.positions &&
          turn == other.turn &&
          lastMoveWhite == other.lastMoveWhite &&
          lastMoveBlack == other.lastMoveBlack &&
          kingEatenBy == other.kingEatenBy;

  @override
  int get hashCode =>
      Object.hash(positions, turn, lastMoveWhite, lastMoveBlack, kingEatenBy);
}

// ─── Private helpers (matches backend rules.go) ──────────────────────

/// Matches backend GetPositionsHash
String _getPositionsHash(Map<String, KitaPos?> positions) {
  final parts = <String>[];
  for (final entry in positions.entries) {
    final pos = entry.value;
    if (pos != null) {
      parts.add('${entry.key}:${pos.col},${pos.row}');
    }
  }
  parts.sort();
  return parts.join(';');
}

/// Matches backend getOpponentKingID
String _getOpponentKingId(PieceTeam turn) =>
    turn == PieceTeam.black ? 'WK' : 'BK';

/// Matches backend getTeamPieces
List<String> _getTeamPieceIds(PieceTeam turn) =>
    turn == PieceTeam.black ? KitaPiece.blackPieceIds : KitaPiece.whitePieceIds;

/// Matches backend getOpponentPieces
List<String> _getOpponentPieceIds(PieceTeam turn) =>
    turn == PieceTeam.black ? KitaPiece.whitePieceIds : KitaPiece.blackPieceIds;

/// Matches backend GetStepCount
int _getStepCount(PieceTeam turn, Map<String, KitaPos?> positions) {
  final oppKingId = _getOpponentKingId(turn);
  final oppKingPos = positions[oppKingId];
  if (oppKingPos == null) {
    throw StateError('Opponent king is not on the board');
  }
  return KitaBoardConfig.tileValue(oppKingPos);
}

/// Matches backend isReversalPossible
bool _isReversalPossible(
  Map<String, KitaPos?> positions,
  PieceTeam turn,
  KitaMove? lastMove,
) {
  if (lastMove == null) return false;

  final currentPos = positions[lastMove.pieceId];
  if (currentPos == null || currentPos != lastMove.toPos) return false;

  final oppKingId = _getOpponentKingId(turn);
  final oppKingPos = positions[oppKingId];
  if (oppKingPos == null) return false;

  final steps = KitaBoardConfig.tileValue(oppKingPos);
  final target = lastMove.fromPos;

  // Check if any own piece occupies the target
  for (final pid in _getTeamPieceIds(turn)) {
    final pos = positions[pid];
    if (pos != null && pos == target) return false;
  }

  // Check if any opponent pawn occupies the target
  for (final pid in _getOpponentPieceIds(turn)) {
    if (KitaPiece.allPieces[pid]?.isPawn == true) {
      final pos = positions[pid];
      if (pos != null && pos == target) return false;
    }
  }

  // Check if the piece can physically reach the target
  final allOccupied = <KitaPos>{};
  for (final pos in positions.values) {
    if (pos != null) allOccupied.add(pos);
  }

  final occupiedExclSelf = Set<KitaPos>.from(allOccupied)..remove(currentPos);
  final landable = <KitaPos>{oppKingPos};

  final dests = KitaBoardConfig.findReachable(
    start: currentPos,
    steps: steps,
    occupied: occupiedExclSelf,
    landable: landable,
  );

  return dests.contains(target);
}

/// Matches backend NormalizeLastMoves
(KitaMove?, KitaMove?) _normalizeLastMoves(
  Map<String, KitaPos?> positions,
  PieceTeam turn,
  KitaMove? lastMoveWhite,
  KitaMove? lastMoveBlack,
) {
  KitaMove? lmw = lastMoveWhite;
  KitaMove? lmb = lastMoveBlack;

  if (turn == PieceTeam.white) {
    if (!_isReversalPossible(positions, PieceTeam.white, lmw)) lmw = null;
  } else {
    if (!_isReversalPossible(positions, PieceTeam.black, lmb)) lmb = null;
  }

  return (lmw, lmb);
}

/// Matches backend GetLegalMoves (package-level function in rules.go)
List<KitaMove> _getLegalMovesStatic(
  Map<String, KitaPos?> positions,
  PieceTeam turn,
  KitaMove? lastMoveBlack,
  KitaMove? lastMoveWhite,
) {
  final steps = _getStepCount(turn, positions);

  final allOccupied = <KitaPos>{};
  for (final pos in positions.values) {
    if (pos != null) allOccupied.add(pos);
  }

  final ownIds = _getTeamPieceIds(turn);
  final ownOccupied = <KitaPos>{};
  for (final pid in ownIds) {
    final pos = positions[pid];
    if (pos != null) ownOccupied.add(pos);
  }

  final oppIds = _getOpponentPieceIds(turn);
  final oppPawnTiles = <KitaPos>{};
  for (final pid in oppIds) {
    if (KitaPiece.allPieces[pid]?.isPawn == true) {
      final pos = positions[pid];
      if (pos != null) oppPawnTiles.add(pos);
    }
  }

  final oppKingId = _getOpponentKingId(turn);
  final landable = <KitaPos>{};
  final oppKingPos = positions[oppKingId];
  if (oppKingPos != null) landable.add(oppKingPos);

  // Get current player's OWN last move for reversal checking
  final lastMove = turn == PieceTeam.black ? lastMoveBlack : lastMoveWhite;

  final normalMoves = <KitaMove>[];
  final undoMoves = <KitaMove>[];

  for (final pid in ownIds) {
    final pos = positions[pid];
    if (pos == null) continue;

    final occupiedExclSelf = Set<KitaPos>.from(allOccupied)..remove(pos);

    final dests = KitaBoardConfig.findReachable(
      start: pos,
      steps: steps,
      occupied: occupiedExclSelf,
      landable: landable,
    );

    for (final dest in dests) {
      // Cannot land on own pieces or opponent pawns
      if (ownOccupied.contains(dest) || oppPawnTiles.contains(dest)) continue;

      final move = KitaMove(pieceId: pid, fromPos: pos, toPos: dest);

      // Reversal rule: separate undo moves from normal moves
      if (lastMove != null && move.isReverseOf(lastMove)) {
        undoMoves.add(move);
      } else {
        normalMoves.add(move);
      }
    }
  }

  // If normal moves exist, player CANNOT play the reversal!
  final result = normalMoves.isNotEmpty ? normalMoves : undoMoves;

  // Sort matching backend sort order
  result.sort((a, b) {
    int cmp = a.pieceId.compareTo(b.pieceId);
    if (cmp != 0) return cmp;
    cmp = a.fromPos.col.compareTo(b.fromPos.col);
    if (cmp != 0) return cmp;
    cmp = a.fromPos.row.compareTo(b.fromPos.row);
    if (cmp != 0) return cmp;
    cmp = a.toPos.col.compareTo(b.toPos.col);
    if (cmp != 0) return cmp;
    return a.toPos.row.compareTo(b.toPos.row);
  });

  return result;
}

// ─── Complete Kita Game Engine — 1:1 port of backend pkg/game ────────

class KitaGameEngine {
  final Map<String, KitaPos?> positions;
  final PieceTeam turn;
  final KitaMove? lastMoveWhite;
  final KitaMove? lastMoveBlack;
  final String kingEatenBy; // '', 'white', 'black', 'both'
  final Map<KitaGameState, int> stateHistory;
  final int moveCount;

  KitaGameEngine._({
    required this.positions,
    required this.turn,
    this.lastMoveWhite,
    this.lastMoveBlack,
    this.kingEatenBy = '',
    required this.stateHistory,
    this.moveCount = 0,
  });

  /// Creates a new game — matches backend NewGame()
  factory KitaGameEngine() {
    final positions = KitaBoardConfig.initialPositions();
    final history = <KitaGameState, int>{};

    final engine = KitaGameEngine._(
      positions: positions,
      turn: PieceTeam.white,
      kingEatenBy: '',
      stateHistory: history,
    );
    history[engine.toGameState()] = 1;
    return engine;
  }

  /// Creates a custom game configuration (useful for testing and puzzles)
  factory KitaGameEngine.custom({
    required Map<String, KitaPos?> positions,
    PieceTeam turn = PieceTeam.white,
    KitaMove? lastMoveWhite,
    KitaMove? lastMoveBlack,
    String kingEatenBy = '',
    Map<KitaGameState, int>? stateHistory,
    int moveCount = 0,
  }) {
    final history = stateHistory ?? <KitaGameState, int>{};
    final engine = KitaGameEngine._(
      positions: positions,
      turn: turn,
      lastMoveWhite: lastMoveWhite,
      lastMoveBlack: lastMoveBlack,
      kingEatenBy: kingEatenBy,
      stateHistory: history,
      moveCount: moveCount,
    );
    if (history.isEmpty) {
      history[engine.toGameState()] = 1;
    }
    return engine;
  }

  // ─── Computed Properties ────────────────────────────────────────────

  bool get isGameOver => getStatus() != GameStatus.ongoing;

  /// True when one king has been eaten but game continues for last stand
  bool get isLastStand => kingEatenBy.isNotEmpty && kingEatenBy != 'both';

  KitaMove? get currentLastMove =>
      turn == PieceTeam.white ? lastMoveWhite : lastMoveBlack;

  /// Step count for current turn based on opponent king's tile value
  int get currentStepCount {
    final oppKingId = _getOpponentKingId(turn);
    final oppKingPos = positions[oppKingId];
    if (oppKingPos == null) return 0; // Game already over
    return KitaBoardConfig.tileValue(oppKingPos);
  }

  /// Non-null positions for UI rendering (filters out captured pieces)
  Map<String, KitaPos> get activePositions => Map.fromEntries(
    positions.entries
        .where((e) => e.value != null)
        .map((e) => MapEntry(e.key, e.value!)),
  );

  // ─── State Hashing — matches backend ToGameState() ──────────────────

  KitaGameState toGameState() {
    final (lmw, lmb) = _normalizeLastMoves(
      positions, turn, lastMoveWhite, lastMoveBlack,
    );
    return KitaGameState(
      positions: _getPositionsHash(positions),
      turn: turn,
      lastMoveWhite: lmw,
      lastMoveBlack: lmb,
      kingEatenBy: kingEatenBy,
    );
  }

  /// When one king has been eaten, checks if the current player has a move that can capture
  /// the opposing king in retaliation. Returns the first capturing move, or null if none.
  KitaMove? getKingRetaliationMove() {
    if (!isLastStand) return null;
    final oppKingId = _getOpponentKingId(turn);
    final oppKingPos = positions[oppKingId];
    if (oppKingPos == null) return null;

    final rawMoves = _getLegalMovesStatic(
      positions, turn, lastMoveBlack, lastMoveWhite,
    );
    for (final m in rawMoves) {
      if (m.toPos == oppKingPos) {
        return m;
      }
    }
    return null;
  }

  bool get hasKingRetaliation => getKingRetaliationMove() != null;

  // ─── Status — matches backend GetStatus() ───────────────────────────

  /// Matches backend kingEndStatus()
  GameStatus? _kingEndStatus() {
    if (kingEatenBy == 'both') return GameStatus.draw;
    if (kingEatenBy == 'white' && turn == PieceTeam.white) {
      return GameStatus.whiteWins;
    }
    if (kingEatenBy == 'black' && turn == PieceTeam.black) {
      return GameStatus.blackWins;
    }
    // If one king is eaten and it's the victim's turn:
    // If victim cannot retaliate by capturing the opposing king, attacker wins immediately!
    if (isLastStand) {
      if (!hasKingRetaliation) {
        return kingEatenBy == 'white' ? GameStatus.whiteWins : GameStatus.blackWins;
      }
    }
    return null;
  }

  /// Matches backend GetStatus() — checks king end → 3-fold → no moves
  GameStatus getStatus() {
    final kingStatus = _kingEndStatus();
    if (kingStatus != null) return kingStatus;

    final state = toGameState();
    if ((stateHistory[state] ?? 0) >= 3) return GameStatus.draw;

    final rawMoves = _getLegalMovesStatic(
      positions, turn, lastMoveBlack, lastMoveWhite,
    );
    if (rawMoves.isEmpty) {
      return turn == PieceTeam.black
          ? GameStatus.whiteWins
          : GameStatus.blackWins;
    }

    return GameStatus.ongoing;
  }

  /// Derives end reason from current game state (for UI display)
  EndReason? getEndReason() {
    if (!isGameOver) return null;

    if (kingEatenBy == 'both') return EndReason.doubleKingCaptured;
    if (kingEatenBy.isNotEmpty) return EndReason.kingCaptured;

    final state = toGameState();
    if ((stateHistory[state] ?? 0) >= 3) return EndReason.threefoldRepetition;

    return EndReason.noMovesLeft;
  }

  // ─── Legal Moves — matches backend Game.GetLegalMoves() ─────────────

  List<KitaMove> getLegalMoves() {
    if (getStatus() != GameStatus.ongoing) return [];
    final allMoves = _getLegalMovesStatic(positions, turn, lastMoveBlack, lastMoveWhite);
    if (isLastStand) {
      final oppKingId = _getOpponentKingId(turn);
      final oppKingPos = positions[oppKingId];
      if (oppKingPos == null) return [];
      return allMoves.where((m) => m.toPos == oppKingPos).toList();
    }
    return allMoves;
  }

  /// Gets legal moves for a specific team on the current board state.
  /// When [team] == [turn], this is equivalent to [getLegalMoves].
  /// When called for the non-active team, it calculates hypothetical legal moves
  /// that team could make based on the current opponent king position.
  List<KitaMove> getLegalMovesForTeam(PieceTeam team) {
    if (getStatus() != GameStatus.ongoing) return [];
    final allMoves = _getLegalMovesStatic(positions, team, lastMoveBlack, lastMoveWhite);
    if (isLastStand && turn == team) {
      final oppKingId = _getOpponentKingId(team);
      final oppKingPos = positions[oppKingId];
      if (oppKingPos == null) return [];
      return allMoves.where((m) => m.toPos == oppKingPos).toList();
    }
    return allMoves;
  }

  /// Gets legal destination positions for a single piece
  Set<KitaPos> getLegalMovesForPiece(String pieceId) {
    if (isGameOver) return {};
    final piece = KitaPiece.allPieces[pieceId];
    if (piece == null || piece.team != turn) return {};

    return getLegalMoves()
        .where((m) => m.pieceId == pieceId)
        .map((m) => m.toPos)
        .toSet();
  }

  /// Gets valid destination positions for a piece regardless of whose turn it is.
  /// During opponent turn, this allows players to inspect their pieces and see
  /// hypothetical move ranges based on the opponent king position.
  Set<KitaPos> getMovesForPiece(String pieceId) {
    if (isGameOver) return {};
    final piece = KitaPiece.allPieces[pieceId];
    if (piece == null) return {};

    return getLegalMovesForTeam(piece.team)
        .where((m) => m.pieceId == pieceId)
        .map((m) => m.toPos)
        .toSet();
  }

  // ─── Apply Move — matches backend Game.ApplyMove() (immutable) ──────

  /// Executes a move and returns a NEW game state.
  /// Matches backend ApplyMove which returns *Game.
  KitaGameEngine applyMove(KitaMove move) {
    // Deep copy positions
    final newPos = Map<String, KitaPos?>.from(positions);
    KitaMove? newLmw = lastMoveWhite;
    KitaMove? newLmb = lastMoveBlack;
    String newKeb = kingEatenBy;

    // Move the piece
    newPos[move.pieceId] = move.toPos;

    // Record last move for current team
    if (turn == PieceTeam.white) {
      newLmw = move;
    } else {
      newLmb = move;
    }

    // Check opponent king capture
    final oppKingId = _getOpponentKingId(turn);
    final oppKingPos = positions[oppKingId]; // Check against ORIGINAL positions
    if (oppKingPos != null && move.toPos == oppKingPos) {
      newPos[oppKingId] = null; // Remove captured king
      if (newKeb.isEmpty) {
        newKeb = turn == PieceTeam.white ? 'white' : 'black';
      } else {
        newKeb = 'both';
      }
    }

    // Flip turn
    final newTurn = turn == PieceTeam.white
        ? PieceTeam.black
        : PieceTeam.white;

    // Normalize last moves for state hashing
    final (normalizedLmw, normalizedLmb) = _normalizeLastMoves(
      newPos, newTurn, newLmw, newLmb,
    );

    // Copy state history
    final newHistory = Map<KitaGameState, int>.from(stateHistory);

    final newGame = KitaGameEngine._(
      positions: newPos,
      turn: newTurn,
      lastMoveWhite: normalizedLmw,
      lastMoveBlack: normalizedLmb,
      kingEatenBy: newKeb,
      stateHistory: newHistory,
      moveCount: moveCount + 1,
    );

    // Increment state count for 3-fold repetition tracking
    final newState = newGame.toGameState();
    newHistory[newState] = (newHistory[newState] ?? 0) + 1;

    return newGame;
  }

  // ─── Clone (deep copy for AI tree exploration) ──────────────────────

  KitaGameEngine clone() {
    return KitaGameEngine._(
      positions: Map<String, KitaPos?>.from(positions),
      turn: turn,
      lastMoveWhite: lastMoveWhite,
      lastMoveBlack: lastMoveBlack,
      kingEatenBy: kingEatenBy,
      stateHistory: Map<KitaGameState, int>.from(stateHistory),
      moveCount: moveCount,
    );
  }
}
