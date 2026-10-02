import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/game_models.dart';
import '../../providers/game_settings_provider.dart';
import 'kita_board_theme.dart';
import 'kita_board_widget.dart';

/// Unified interactive game board component used for both Online and Offline gameplay.
///
/// Wraps [KitaBoardWidget] with full gameplay interaction logic:
/// - Tap to select pieces and execute moves
/// - Drag and drop pieces with live highlighting and cancel support
/// - Legal move highlights and move inspection (even during opponent's turn)
/// - Auto-rotation for 2-player local co-op
/// - Clean history scrubbing (disables interaction when viewing history)
/// - Automatic state reconciliation when turns or engine positions change
class KitaGameBoard extends StatefulWidget {
  /// The engine snapshot to display (live engine or historical snapshot)
  final KitaGameEngine displayEngine;

  /// Player's team: 'white' or 'black'
  final String myTeam;

  /// Whether it is currently this player's active turn to make a move
  final bool isMyTurn;

  /// Whether the board is interactive (false when viewing history, game over, or AI thinking)
  final bool isInteractive;

  /// True for 2-player local pass-and-play matches on the same device
  final bool isLocalCoop;

  /// Legal moves available for the active player's turn
  final List<KitaMove> legalMoves;

  /// Whether the board layout is flipped (e.g. Black player perspective)
  final bool flipBoard;

  /// True for horizontal (7x4) or false for vertical (4x7)
  final bool isHorizontal;

  /// Piece rotation override in turns (0.0 to 1.0). If null, computed automatically for local coop.
  final double? pieceRotation;

  /// Optional theme override (if null, resolved via [GameSettingsProvider])
  final KitaBoardTheme? theme;

  /// Callback when a valid move is made by the player
  final void Function(KitaMove move)? onMakeMove;

  const KitaGameBoard({
    super.key,
    required this.displayEngine,
    required this.myTeam,
    required this.isMyTurn,
    this.isInteractive = true,
    this.isLocalCoop = false,
    this.legalMoves = const [],
    this.flipBoard = false,
    this.isHorizontal = true,
    this.pieceRotation,
    this.theme,
    this.onMakeMove,
  });

  @override
  State<KitaGameBoard> createState() => _KitaGameBoardState();
}

class _KitaGameBoardState extends State<KitaGameBoard> {
  KitaPos? _selectedPos;
  Set<KitaPos> _validMoves = {};

  @override
  void didUpdateWidget(covariant KitaGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isInteractive) {
      if (_selectedPos != null) {
        setState(() {
          _selectedPos = null;
          _validMoves = {};
        });
      }
      return;
    }

    if (oldWidget.displayEngine != widget.displayEngine ||
        oldWidget.isMyTurn != widget.isMyTurn ||
        oldWidget.legalMoves != widget.legalMoves ||
        oldWidget.isInteractive != widget.isInteractive) {
      if (_selectedPos != null) {
        setState(() {
          _updateOrReselectPiece();
        });
      }
    }
  }

  bool _isOurPiece(KitaPiece piece) {
    if (widget.isLocalCoop) {
      return piece.team == widget.displayEngine.turn;
    }
    final normalizedTeam = widget.myTeam.toLowerCase();
    return (normalizedTeam == 'white' && piece.isWhite) ||
        (normalizedTeam == 'black' && piece.isBlack);
  }

  void _updateOrReselectPiece() {
    if (_selectedPos == null) return;
    final pos = _selectedPos!;
    final activePositions = widget.displayEngine.activePositions;
    String? pieceId;
    for (final entry in activePositions.entries) {
      if (entry.value == pos) {
        pieceId = entry.key;
        break;
      }
    }
    if (pieceId == null) {
      _selectedPos = null;
      _validMoves = {};
      return;
    }
    final piece = KitaPiece.allPieces[pieceId];
    if (piece == null || !_isOurPiece(piece)) {
      _selectedPos = null;
      _validMoves = {};
      return;
    }

    final Set<KitaPos> movesForPiece;
    if (widget.isMyTurn &&
        piece.team == widget.displayEngine.turn &&
        widget.legalMoves.isNotEmpty) {
      movesForPiece = widget.legalMoves
          .where((m) => m.pieceId == pieceId)
          .map((m) => m.toPos)
          .toSet();
    } else {
      movesForPiece = widget.displayEngine.getMovesForPiece(pieceId);
    }

    _selectedPos = pos;
    _validMoves = movesForPiece;
  }

  bool get _isCurrentTurnSelection {
    if (!widget.isMyTurn) return false;
    if (_selectedPos == null) return true;
    final activePositions = widget.displayEngine.activePositions;
    for (final entry in activePositions.entries) {
      if (entry.value == _selectedPos) {
        final piece = KitaPiece.allPieces[entry.key];
        return piece?.team == widget.displayEngine.turn;
      }
    }
    return true;
  }

  bool _isPieceDraggable(KitaPos pos) {
    if (!widget.isInteractive || !widget.isMyTurn) {
      return false;
    }

    final activePositions = widget.displayEngine.activePositions;
    String? pieceId;
    for (final entry in activePositions.entries) {
      if (entry.value == pos) {
        pieceId = entry.key;
        break;
      }
    }
    if (pieceId == null) return false;
    final piece = KitaPiece.allPieces[pieceId];
    if (piece == null) return false;

    if (piece.team != widget.displayEngine.turn) {
      return false;
    }

    return _isOurPiece(piece);
  }

  void _onPieceDragStarted(KitaPos pos) {
    if (_selectedPos != pos) {
      _selectPiece(pos);
    }
  }

  void _onPieceDragCancelled(KitaPos pos) {
    // Keep the piece selected so that tap-to-move continues to work seamlessly
    // even if a tap had a tiny drag jitter or the user changed their mind about dragging.
    if (_selectedPos != pos) {
      _selectPiece(pos);
    }
  }

  void _executeMove(KitaPos fromPos, KitaPos toPos) {
    if (fromPos == toPos) return;
    if (!widget.isInteractive || !widget.isMyTurn) return;

    final activePositions = widget.displayEngine.activePositions;
    String? selectedPieceId;
    for (final entry in activePositions.entries) {
      if (entry.value == fromPos) {
        selectedPieceId = entry.key;
        break;
      }
    }
    final selectedPiece = selectedPieceId != null
        ? KitaPiece.allPieces[selectedPieceId]
        : null;
    final canMove = selectedPiece != null &&
        selectedPiece.team == widget.displayEngine.turn &&
        _isOurPiece(selectedPiece);

    if (canMove) {
      final candidateMoves = widget.legalMoves.isNotEmpty
          ? widget.legalMoves
          : widget.displayEngine.getLegalMoves();
      final matchingMoves = candidateMoves.where(
        (m) => m.fromPos == fromPos && m.toPos == toPos,
      );

      if (matchingMoves.isNotEmpty) {
        widget.onMakeMove?.call(matchingMoves.first);
      }
    }

    setState(() {
      _selectedPos = null;
      _validMoves = {};
    });
  }

  void _selectPiece(KitaPos pos) {
    final activePositions = widget.displayEngine.activePositions;
    String? tappedPieceId;
    for (final entry in activePositions.entries) {
      if (entry.value == pos) {
        tappedPieceId = entry.key;
        break;
      }
    }

    if (tappedPieceId != null) {
      final piece = KitaPiece.allPieces[tappedPieceId];
      if (piece != null && _isOurPiece(piece)) {
        final Set<KitaPos> movesForPiece;
        if (widget.isMyTurn &&
            piece.team == widget.displayEngine.turn &&
            widget.legalMoves.isNotEmpty) {
          movesForPiece = widget.legalMoves
              .where((m) => m.pieceId == tappedPieceId)
              .map((m) => m.toPos)
              .toSet();
        } else {
          movesForPiece = widget.displayEngine.getMovesForPiece(tappedPieceId);
        }

        setState(() {
          _selectedPos = pos;
          _validMoves = movesForPiece;
        });
        return;
      }
    }

    setState(() {
      _selectedPos = null;
      _validMoves = {};
    });
  }

  void _onTileTap(KitaPos pos) {
    if (!widget.isInteractive) return;

    // 1. If tapping the already selected tile → deselect it
    if (_selectedPos != null && _selectedPos == pos) {
      setState(() {
        _selectedPos = null;
        _validMoves = {};
      });
      return;
    }

    // 2. If tapping a valid move destination → make move if our turn, otherwise deselect
    if (_selectedPos != null && _validMoves.contains(pos)) {
      if (widget.isMyTurn) {
        _executeMove(_selectedPos!, pos);
      } else {
        setState(() {
          _selectedPos = null;
          _validMoves = {};
        });
      }
      return;
    }

    // 3. If tapping a piece → check if it is our piece to select, otherwise deselect
    final activePositions = widget.displayEngine.activePositions;
    String? pieceAtPos;
    for (final entry in activePositions.entries) {
      if (entry.value == pos) {
        pieceAtPos = entry.key;
        break;
      }
    }

    if (pieceAtPos != null) {
      final piece = KitaPiece.allPieces[pieceAtPos];
      if (piece != null && _isOurPiece(piece)) {
        _selectPiece(pos);
        return;
      }
    }

    // 4. Empty space or unselectable piece → deselect
    setState(() {
      _selectedPos = null;
      _validMoves = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameSettings = context.watch<GameSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boardTheme = widget.theme ?? gameSettings.currentBoardTheme(isDark);

    final double effectiveRotation;
    if (widget.pieceRotation != null) {
      effectiveRotation = widget.pieceRotation!;
    } else if (widget.isLocalCoop) {
      final isBlackTurn = widget.displayEngine.turn == PieceTeam.black;
      final activePlayerIsAtTop = widget.flipBoard ? !isBlackTurn : isBlackTurn;
      final double baseRotation = gameSettings.isLocalCoopHorizontal ? 0.25 : 0.0;
      effectiveRotation = gameSettings.localCoopAutoRotate
          ? (baseRotation + (activePlayerIsAtTop ? 0.5 : 0.0))
          : baseRotation;
    } else {
      effectiveRotation = 0.0;
    }

    return KitaBoardWidget(
      pieces: widget.displayEngine.activePositions,
      selectedPos: _selectedPos,
      validMoves: _validMoves,
      flipBoard: widget.flipBoard,
      isHorizontal: widget.isHorizontal,
      pieceRotation: effectiveRotation,
      isCurrentTurn: _isCurrentTurnSelection,
      theme: boardTheme,
      onTileTap: widget.isInteractive ? _onTileTap : null,
      onPieceDropped: widget.isInteractive ? (from, to) => _executeMove(from, to) : null,
      onPieceDragStarted: widget.isInteractive ? _onPieceDragStarted : null,
      onPieceDragCancelled: widget.isInteractive ? _onPieceDragCancelled : null,
      isPieceDraggable: widget.isInteractive ? _isPieceDraggable : null,
    );
  }
}
