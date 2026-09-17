import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/feedback/toast_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/kita_ai.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/kita_button.dart';
import '../../widgets/common/kita_card.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/game/kita_board_theme.dart';
import '../../widgets/game/kita_board_widget.dart';

enum PlayMode { localCoop, vsAi }

class OfflineAiScreen extends StatefulWidget {
  const OfflineAiScreen({super.key});

  @override
  State<OfflineAiScreen> createState() => _OfflineAiScreenState();
}

class _OfflineAiScreenState extends State<OfflineAiScreen> {
  // Game Engine
  late KitaGameEngine _engine;

  // Settings
  PlayMode _playMode = PlayMode.localCoop;
  int _selectedDifficulty = 1; // 0: Easy, 1: Medium, 2: Hard
  bool _isHorizontal = true;
  bool _flipBoard = false;
  int _themeIndex = 0; // 0: Emerald, 1: Amber, 2: Ocean, 3: Purple, 4: Slate

  // UI Selection State
  KitaPos? _selectedPos;
  String? _selectedPieceId;
  Set<KitaPos> _validMoves = {};
  bool _isAiThinking = false;

  // AI Player (lazy-loaded)
  KitaAI? _ai;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    setState(() {
      _engine = KitaGameEngine();
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
      _isAiThinking = false;
    });
  }

  KitaBoardTheme _getTheme(bool isDark) {
    switch (_themeIndex) {
      case 1:
        return KitaBoardTheme.amberSunset();
      case 2:
        return KitaBoardTheme.oceanAzure();
      case 3:
        return KitaBoardTheme.cyberPurple();
      case 4:
        return KitaBoardTheme.slateMonochrome();
      default:
        return KitaBoardTheme.emerald(isDark);
    }
  }

  String _getThemeName() {
    switch (_themeIndex) {
      case 0:
        return 'Emerald';
      case 1:
        return 'Amber Sunset';
      case 2:
        return 'Ocean Azure';
      case 3:
        return 'Cyber Purple';
      case 4:
        return 'Slate Mono';
      default:
        return 'Emerald';
    }
  }

  void _onTileTap(KitaPos pos) {
    if (_engine.isGameOver || _isAiThinking) {
      if (_engine.isGameOver) _showGameOverDialog();
      return;
    }

    // In VS AI mode, human plays White, AI plays Black
    if (_playMode == PlayMode.vsAi && _engine.turn != PieceTeam.white) {
      return;
    }

    setState(() {
      // 1. If clicking a valid move target -> Apply move
      if (_selectedPieceId != null && _validMoves.contains(pos)) {
        final startPos = _selectedPos!;
        final move = KitaMove(pieceId: _selectedPieceId!, fromPos: startPos, toPos: pos);

        _engine = _engine.applyMove(move);
        _selectedPos = null;
        _selectedPieceId = null;
        _validMoves = {};

        // Check if game ended
        if (_engine.isGameOver) {
          _showGameOverDialog();
          return;
        }

        // Trigger AI move if in VS AI mode
        if (_playMode == PlayMode.vsAi && _engine.turn == PieceTeam.black) {
          _triggerAiMove();
        }
        return;
      }

      // 2. If clicking on own piece -> Select it & calculate legal moves
      String? clickedPieceId;
      _engine.activePositions.forEach((id, p) {
        if (p == pos) clickedPieceId = id;
      });

      if (clickedPieceId != null) {
        final piece = KitaPiece.allPieces[clickedPieceId];
        if (piece?.team == _engine.turn) {
          _selectedPos = pos;
          _selectedPieceId = clickedPieceId;
          _validMoves = _engine.getLegalMovesForPiece(clickedPieceId!);

          if (_validMoves.isEmpty) {
            KitaToast.warning('No legal ${_engine.currentStepCount}-step moves available (or restricted by reversal rule).');
          }
          return;
        }
      }

      // 3. Deselect
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
    });
  }

  Future<void> _triggerAiMove() async {
    setState(() => _isAiThinking = true);

    // Lazy-load AI model on first use
    if (_ai == null && !_aiLoading) {
      _aiLoading = true;
      _ai = KitaAI();
      await _ai!.initialize();
      _aiLoading = false;
    }

    if (!mounted || _engine.isGameOver || _ai == null) {
      setState(() => _isAiThinking = false);
      return;
    }

    // Map difficulty index 0/1/2 → Easy/Medium/Hard
    final difficulty = AIDifficulty.all[_selectedDifficulty.clamp(0, AIDifficulty.all.length - 1)];

    // Small delay to let the UI update with "thinking" indicator
    await Future.delayed(const Duration(milliseconds: 150));

    final aiMove = _ai!.chooseMoveWithDifficulty(_engine, difficulty);
    if (!mounted) return;

    if (aiMove != null) {
      setState(() {
        _engine = _engine.applyMove(aiMove);
        _isAiThinking = false;
      });

      if (_engine.isGameOver) {
        _showGameOverDialog();
      }
    } else {
      setState(() => _isAiThinking = false);
    }
  }

  void _showGameOverDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String title;
    String subtitle;
    IconData icon;
    Color iconColor;

    final endReason = _engine.getEndReason();
    switch (_engine.getStatus()) {
      case GameStatus.whiteWins:
        title = 'Beyaz Kazandı! (White Wins)';
        icon = Icons.emoji_events_rounded;
        iconColor = AppColors.ratingGold;
        subtitle = endReason == EndReason.kingCaptured
            ? 'Beyaz, Siyah kralı güvenli şekilde avladı (Siyah hemen karşı kralı avlayamadı)!'
            : 'Siyah oyuncunun yapacak hiçbir yasal hamlesi kalmadı!';
        break;
      case GameStatus.blackWins:
        title = 'Siyah Kazandı! (Black Wins)';
        icon = Icons.emoji_events_rounded;
        iconColor = AppColors.ratingGold;
        subtitle = endReason == EndReason.kingCaptured
            ? 'Siyah, Beyaz kralı güvenli şekilde avladı (Beyaz hemen karşı kralı avlayamadı)!'
            : 'Beyaz oyuncunun yapacak hiçbir yasal hamlesi kalmadı!';
        break;
      case GameStatus.draw:
        title = 'Berabere! (Draw)';
        icon = Icons.handshake_rounded;
        iconColor = AppColors.drawGray;
        subtitle = endReason == EndReason.doubleKingCaptured
            ? 'Karşı tarafın kralı yendi ancak hemen ardından kendi kralı da savunmasız kaldığı için kural gereği maç BERABERE bitti!'
            : endReason == EndReason.threefoldRepetition
            ? 'Aynı pozisyon 3 kez tekrarlandı — kural gereği maç berabere!'
            : 'Oyun berabere sonuçlandı!';
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 26.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor, width: 2),
                ),
                child: Icon(icon, color: iconColor, size: 44),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              KitaButton(
                text: 'Yeniden Oyna (Play Again)',
                icon: Icons.replay_rounded,
                variant: KitaButtonVariant.primary,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _resetGame();
                },
              ),
              const SizedBox(height: 10),
              KitaButton(
                text: 'common.close'.tr(),
                variant: KitaButtonVariant.outline,
                height: 42,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boardTheme = _getTheme(isDark);
    final isWhiteTurn = _engine.turn == PieceTeam.white;
    final effectiveFlip = _flipBoard;

    return Scaffold(
      appBar: KitaAppBar(
        showAuthActions: false,
        showBack: true,
        title: _playMode == PlayMode.localCoop ? 'Local 2P Co-op' : 'VS AI Bot',
      ),
      body: ResponsiveLayout(
        maxWidth: _isHorizontal ? 640 : 460,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Column(
              children: [
                // 1. Mode Switcher (Coop Pass & Play vs VS AI)
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildModeTab(
                          title: 'Yerel 2P (Pass & Play)',
                          icon: Icons.people_alt_rounded,
                          isSelected: _playMode == PlayMode.localCoop,
                          onTap: () {
                            setState(() {
                              _playMode = PlayMode.localCoop;
                              _resetGame();
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildModeTab(
                          title: 'VS Yapay Zeka (AI)',
                          icon: Icons.smart_toy_rounded,
                          isSelected: _playMode == PlayMode.vsAi,
                          onTap: () {
                            setState(() {
                              _playMode = PlayMode.vsAi;
                              _resetGame();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Info & Controls Card
                KitaCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Player info & AI difficulty if in VS AI
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _playMode == PlayMode.localCoop
                                        ? Icons.sports_esports_rounded
                                        : Icons.smart_toy_rounded,
                                    color: AppColors.primaryGreen,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _playMode == PlayMode.localCoop ? 'Tek Cihazda Karşılıklı' : 'Kita AI Bot',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                      if (_playMode == PlayMode.vsAi)
                                        DropdownButton<int>(
                                          value: _selectedDifficulty,
                                          isDense: true,
                                          underline: const SizedBox(),
                                          dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                                          items: [
                                            DropdownMenuItem(
                                              value: 0,
                                              child: Text(
                                                'game.easy'.tr(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.primaryGreen,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 1,
                                              child: Text(
                                                'game.medium'.tr(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.ratingGold,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 2,
                                              child: Text(
                                                'game.hard'.tr(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.deepOrangeAccent,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) setState(() => _selectedDifficulty = val);
                                          },
                                        )
                                      else
                                        Text(
                                          'Hamle: ${_engine.moveCount}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 6),

                          // Right: Board options
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Orientation toggle (Horizontal / Vertical)
                              IconButton(
                                tooltip: _isHorizontal ? 'Yatay (7x4)' : 'Dikey (4x7)',
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(5),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: Icon(
                                  _isHorizontal ? Icons.stay_current_landscape_rounded : Icons.stay_current_portrait_rounded,
                                  size: 18,
                                  color: AppColors.primaryGreen,
                                ),
                                onPressed: () => setState(() => _isHorizontal = !_isHorizontal),
                              ),
                              // Manual Flip Board
                              IconButton(
                                tooltip: 'Manuel Çevir',
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(5),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                                onPressed: () => setState(() => _flipBoard = !_flipBoard),
                              ),
                              // Heatmap Palette Cycle
                              IconButton(
                                tooltip: 'Heatmap Teması (${_getThemeName()})',
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(5),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.palette_outlined, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _themeIndex = (_themeIndex + 1) % 5;
                                  });
                                  KitaToast.info('Heatmap: ${_getThemeName()}');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),

                      // Turn & Step Count Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: isWhiteTurn ? Colors.white : Colors.black,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey, width: 1.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isWhiteTurn ? "Beyaz'ın Sırası" : "Siyah'ın Sırası",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              if (_isAiThinking) ...[
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ],
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primaryGreen, width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_walk_rounded, size: 14, color: AppColors.primaryGreen),
                                const SizedBox(width: 4),
                                Text(
                                  'Mesafe: ${_engine.currentStepCount} adım',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Last Stand Warning Banner
                      if (_engine.isLastStand && !_engine.isGameOver)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF5350), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _engine.kingEatenBy == 'white'
                                      ? "Beyaz kralı yedi! Siyah'ın son şansı — kralı avla ya da kaybet!"
                                      : "Siyah kralı yedi! Beyaz'ın son şansı — kralı avla ya da kaybet!",
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEF5350),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Kita Modular Board
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: AspectRatio(
                    aspectRatio: _isHorizontal ? (7 / 4) : (4 / 7),
                    child: KitaBoardWidget(
                      // Pass only non-null positions (captured pieces filtered out)
                      pieces: _engine.activePositions,
                      selectedPos: _selectedPos,
                      validMoves: _validMoves,
                      onTileTap: _onTileTap,
                      isHorizontal: _isHorizontal,
                      flipBoard: effectiveFlip,
                      theme: boardTheme,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Action Controls
                Row(
                  children: [
                    Expanded(
                      child: KitaButton(
                        text: 'game.newGame'.tr(),
                        icon: Icons.replay_rounded,
                        variant: KitaButtonVariant.primary,
                        height: 44,
                        onPressed: () {
                          _resetGame();
                          KitaToast.success('game.newGame'.tr());
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: KitaButton(
                        text: 'game.returnToMenu'.tr(),
                        variant: KitaButtonVariant.secondary,
                        height: 44,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 5. How to Play — Game Rules Section
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: KitaCard(
                    padding: EdgeInsets.zero,
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      leading: const Icon(Icons.help_outline_rounded, size: 20, color: AppColors.primaryGreen),
                      title: Text(
                        'Nasıl Oynanır? (How to Play)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      children: [
                        _buildRuleItem('🎯', 'Amaç (Goal)', 'Rakibin Kralını (Şah) yakala!', isDark),
                        _buildRuleItem('📋', 'Tahta (Board)', 'Haç şeklinde 20 kareden oluşan tahta. Her kare 1, 2 veya 3 değerinde.', isDark),
                        _buildRuleItem('♟️', 'Taşlar (Pieces)', 'Her takımda 1 Kral (Şah) + 2 Piyon. Piyonlar yenilemez.', isDark),
                        _buildRuleItem('🚶', 'Hareket (Movement)', 'Her turda atman gereken adım sayısı = Rakibin Kralının üzerinde durduğu karenin değeri. Tam o kadar adım atmalısın — ne fazla, ne eksik.', isDark),
                        _buildRuleItem('⚔️', 'Yeme (Capture)', 'Sadece Krallar yenebilir — Piyonlar dokunulmaz. Kendi taşlarına veya rakip Piyonlara inemezsin.', isDark),
                        _buildRuleItem('🏆', 'Kazanma (Win)', 'Rakibin Kralını güvenle yakala → Kazan!\nRakibin yasal hamlesi kalmasın → Kazan!', isDark),
                        _buildRuleItem('⚖️', 'Son Şans (Last Stand)', 'Bir Kral yendiğinde karşı takım SON BİR HAMLE yapar. Senin Kralını yerse → Berabere! Yiyemezse → Kaybeder!', isDark),
                        _buildRuleItem('🤝', 'Berabere (Draw)', 'İki Kral da art arda yenilirse → Berabere\nAynı pozisyon 3 kez tekrarlanırsa → Berabere (Threefold Repetition)', isDark),
                        _buildRuleItem('🔄', 'Geri Alma Yasağı (Reversal Rule)', 'Kendi son hamlenin tersini yapamazsın — başka hamle yoksa hariç.', isDark),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String emoji, String title, String desc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
