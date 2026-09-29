package http

import (
	"net/http"
	"strconv"

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

	c.JSON(http.StatusOK, gin.H{
		"user_id": userID,
		"count":   len(matches),
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

