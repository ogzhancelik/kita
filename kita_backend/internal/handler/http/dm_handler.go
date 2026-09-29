package http

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/oguzhancelik/kita/internal/core/errors"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

// DirectMessageHandler exposes REST endpoints for DM history.
// Real-time sending goes through WebSocket (hub).
type DirectMessageHandler struct {
	dmService     ports.DirectMessageService
	friendService ports.FriendService
}

func NewDirectMessageHandler(dmService ports.DirectMessageService, friendService ports.FriendService) *DirectMessageHandler {
	return &DirectMessageHandler{dmService: dmService, friendService: friendService}
}

// GET /api/dm/conversations  — list conversation previews (last message per friend)
func (h *DirectMessageHandler) ListConversations(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	previews, err := h.dmService.GetConversationPreviews(c.Request.Context(), userID)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{"conversations": previews})
}

// GET /api/dm/conversations/:conversationId — paginated message history
func (h *DirectMessageHandler) GetHistory(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	convID := c.Param("conversationId")
	if convID == "" {
		SendError(c, http.StatusBadRequest, errors.ErrMissingField, "conversationId is required")
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	msgs, err := h.dmService.GetConversation(c.Request.Context(), convID, limit, offset)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{"messages": msgs, "conversation_id": convID})
}
