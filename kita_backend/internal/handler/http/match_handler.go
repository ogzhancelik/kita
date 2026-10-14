package http

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/errors"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type MatchHandler struct {
	matchService   ports.MatchService
	messageService ports.MessageService
}

func NewMatchHandler(matchService ports.MatchService, messageService ...ports.MessageService) *MatchHandler {
	var ms ports.MessageService
	if len(messageService) > 0 {
		ms = messageService[0]
	}
	return &MatchHandler{matchService: matchService, messageService: ms}
}


func (h *MatchHandler) GetMatch(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		SendError(c, http.StatusBadRequest, errors.ErrMissingField, "Match ID is required")
		return
	}

	match, err := h.matchService.GetMatchDetails(c.Request.Context(), id)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}
	if match == nil {
		SendError(c, http.StatusNotFound, errors.ErrMatchNotFound, "Match not found")
		return
	}

	c.JSON(http.StatusOK, match)
}

// GetMatchMoves: Maçın baştan sona tüm hamle dizisini döner.
// Flutter veya Web istemcisi bu hamleleri alarak maçı adım adım (Replay) oynatabilir.
func (h *MatchHandler) GetMatchMoves(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		SendError(c, http.StatusBadRequest, errors.ErrMissingField, "Match ID is required")
		return
	}

	moves, err := h.matchService.GetMatchMoves(c.Request.Context(), id)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"match_id": id,
		"count":    len(moves),
		"moves":    moves,
	})
}

func (h *MatchHandler) GetUserMatches(c *gin.Context) {
	userID := c.Param("userId")
	if userID == "" {
		SendError(c, http.StatusBadRequest, errors.ErrMissingField, "User ID is required")
		return
	}

	if _, err := uuid.Parse(userID); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"user_id": userID,
			"count":   0,
			"total":   0,
			"matches": []domain.Match{},
		})
		return
	}

	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		limit = 20
	}
	offset, err := strconv.Atoi(offsetStr)
	if err != nil {
		offset = 0
	}

	matches, err := h.matchService.GetUserMatches(c.Request.Context(), userID, limit, offset)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	total, err := h.matchService.CountUserMatches(c.Request.Context(), userID)
	if err != nil {
		total = int64(len(matches))
	}

	c.JSON(http.StatusOK, gin.H{
		"user_id": userID,
		"count":   len(matches),
		"total":   total,
		"matches": matches,
	})
}

// GetMatchMessages returns the in-game chat messages for a match.
// Used by the DM chat screen to show the integrated game-chat card.
func (h *MatchHandler) GetMatchMessages(c *gin.Context) {
	if h.messageService == nil {
		c.JSON(http.StatusOK, gin.H{"messages": []struct{}{}})
		return
	}
	id := c.Param("id")
	if id == "" {
		SendError(c, http.StatusBadRequest, errors.ErrMissingField, "Match ID is required")
		return
	}

	limitStr := c.DefaultQuery("limit", "100")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 {
		limit = 100
	}

	msgs, err := h.messageService.GetMatchMessages(c.Request.Context(), id, limit)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{"match_id": id, "messages": msgs})
}

func parseFlexibleTime(val *string) time.Time {
	if val == nil || *val == "" {
		return time.Now()
	}
	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02T15:04:05.999999999",
		"2006-01-02T15:04:05.999999",
		"2006-01-02T15:04:05.999",
		"2006-01-02T15:04:05",
		"2006-01-02 15:04:05",
	}
	for _, layout := range layouts {
		if t, err := time.Parse(layout, *val); err == nil {
			return t
		}
	}
	return time.Now()
}

type SharePlayerDTO struct {
	ID           string  `json:"id"`
	Username     string  `json:"username"`
	AvatarIndex  int     `json:"avatar_index"`
	AvatarCustom string  `json:"avatar_custom,omitempty"`
	Rating       float64 `json:"rating"`
}

type ShareMoveDTO struct {
	PlyIndex  int     `json:"ply"`
	PlayerID  string  `json:"player_id"`
	PieceID   string  `json:"piece"`
	FromCol   int     `json:"from_col"`
	FromRow   int     `json:"from_row"`
	ToCol     int     `json:"to_col"`
	ToRow     int     `json:"to_row"`
	TimeMs    int     `json:"time_ms,omitempty"`
	CreatedAt *string `json:"created_at,omitempty"`
	Action    string  `json:"action,omitempty"`
}

type ShareMatchDTO struct {
	ID            string          `json:"id"`
	WhitePlayerID string          `json:"white_player_id"`
	BlackPlayerID string          `json:"black_player_id"`
	WhitePlayer   *SharePlayerDTO `json:"white_player,omitempty"`
	BlackPlayer   *SharePlayerDTO `json:"black_player,omitempty"`
	WinnerID      *string         `json:"winner_id"`
	Result        string          `json:"result"`
	Reason        string          `json:"reason,omitempty"`
	TotalMoves    int             `json:"total_moves"`
	StartedAt     *string         `json:"started_at"`
	EndedAt       *string         `json:"ended_at"`
	Moves         []ShareMoveDTO  `json:"moves"`
	IsOffline     bool            `json:"is_offline,omitempty"`
}

type ShareReplayRequest struct {
	Match ShareMatchDTO `json:"match"`
}

// ShareReplay saves or resolves a match replay and returns a shareable code and URL.
func (h *MatchHandler) ShareReplay(c *gin.Context) {
	var req ShareReplayRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		SendError(c, http.StatusBadRequest, errors.ErrInvalidFormat, "Invalid match replay payload: "+err.Error())
		return
	}

	moves := make([]domain.MoveRecord, len(req.Match.Moves))
	for i, m := range req.Match.Moves {
		createdAt := parseFlexibleTime(m.CreatedAt)
		moves[i] = domain.MoveRecord{
			PlyIndex:  m.PlyIndex,
			PlayerID:  m.PlayerID,
			PieceID:   m.PieceID,
			FromCol:   m.FromCol,
			FromRow:   m.FromRow,
			ToCol:     m.ToCol,
			ToRow:     m.ToRow,
			TimeMs:    m.TimeMs,
			CreatedAt: createdAt,
		}
	}

	startedAt := parseFlexibleTime(req.Match.StartedAt)
	var endedAt *time.Time
	if req.Match.EndedAt != nil && *req.Match.EndedAt != "" {
		t := parseFlexibleTime(req.Match.EndedAt)
		endedAt = &t
	}

	matchRecord := domain.Match{
		ID:            req.Match.ID,
		WhitePlayerID: req.Match.WhitePlayerID,
		BlackPlayerID: req.Match.BlackPlayerID,
		WinnerID:      req.Match.WinnerID,
		Result:        domain.MatchResult(req.Match.Result),
		Reason:        req.Match.Reason,
		TotalMoves:    req.Match.TotalMoves,
		StartedAt:     startedAt,
		EndedAt:       endedAt,
		Moves:         moves,
	}

	if req.Match.WhitePlayer != nil {
		matchRecord.WhitePlayer = &domain.User{
			ID:           req.Match.WhitePlayer.ID,
			Username:     req.Match.WhitePlayer.Username,
			AvatarIndex:  req.Match.WhitePlayer.AvatarIndex,
			AvatarCustom: req.Match.WhitePlayer.AvatarCustom,
			Rating:       req.Match.WhitePlayer.Rating,
		}
		if req.Match.WhitePlayer.Rating > 0 {
			wr := int(req.Match.WhitePlayer.Rating)
			matchRecord.WhiteRating = &wr
		}
	}
	if req.Match.BlackPlayer != nil {
		matchRecord.BlackPlayer = &domain.User{
			ID:           req.Match.BlackPlayer.ID,
			Username:     req.Match.BlackPlayer.Username,
			AvatarIndex:  req.Match.BlackPlayer.AvatarIndex,
			AvatarCustom: req.Match.BlackPlayer.AvatarCustom,
			Rating:       req.Match.BlackPlayer.Rating,
		}
		if req.Match.BlackPlayer.Rating > 0 {
			br := int(req.Match.BlackPlayer.Rating)
			matchRecord.BlackRating = &br
		}
	}

	matchID, err := h.matchService.SaveReplay(c.Request.Context(), &matchRecord)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	shortCode := matchID
	if len(matchID) >= 8 && strings.Contains(matchID, "-") && !strings.HasPrefix(matchID, "KITA-") {
		shortCode = strings.ToUpper(strings.Split(matchID, "-")[0])
	}

	c.JSON(http.StatusOK, gin.H{
		"match_id":  matchID,
		"code":      shortCode,
		"share_url": "https://kita.app/replay/" + shortCode,
	})
}

