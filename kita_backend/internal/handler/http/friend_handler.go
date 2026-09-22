package http

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/errors"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type FriendHandler struct {
	friendService ports.FriendService
}

func NewFriendHandler(friendService ports.FriendService) *FriendHandler {
	return &FriendHandler{friendService: friendService}
}

// GetFriends handles GET /api/friends
func (h *FriendHandler) GetFriends(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	friends, err := h.friendService.GetFriends(c.Request.Context(), userID)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{"friends": friends})
}

// GetPendingRequests handles GET /api/friends/requests
func (h *FriendHandler) GetPendingRequests(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	requests, err := h.friendService.GetPendingRequests(c.Request.Context(), userID)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{"requests": requests})
}

// SendRequest handles POST /api/friends/request
func (h *FriendHandler) SendRequest(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	var dto domain.SendFriendRequestDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		SendError(c, http.StatusBadRequest, errors.ErrValidationFailed, "Invalid request payload")
		return
	}

	friendship, err := h.friendService.SendRequest(c.Request.Context(), userID, dto.TargetUsername)
	if err != nil {
		if appErr, ok := err.(*errors.AppError); ok {
			status := http.StatusBadRequest
			if appErr.Code == errors.ErrNotFound {
				status = http.StatusNotFound
			}
			SendError(c, status, appErr.Code, appErr.Message)
			return
		}
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusCreated, gin.H{"friendship": friendship})
}

// AcceptRequest handles POST /api/friends/:id/accept
func (h *FriendHandler) AcceptRequest(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	id := c.Param("id")
	if id == "" {
		SendError(c, http.StatusBadRequest, errors.ErrMissingField, "Friendship ID required")
		return
	}

	if err := h.friendService.AcceptRequest(c.Request.Context(), userID, id); err != nil {
		if appErr, ok := err.(*errors.AppError); ok {
			SendError(c, http.StatusBadRequest, appErr.Code, appErr.Message)
			return
		}
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "accepted"})
}

// DeclineRequest handles POST /api/friends/:id/decline
func (h *FriendHandler) DeclineRequest(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	id := c.Param("id")
	if id == "" {
		SendError(c, http.StatusBadRequest, errors.ErrMissingField, "Friendship ID required")
		return
	}

	if err := h.friendService.DeclineRequest(c.Request.Context(), userID, id); err != nil {
		if appErr, ok := err.(*errors.AppError); ok {
			SendError(c, http.StatusBadRequest, appErr.Code, appErr.Message)
			return
		}
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "declined"})
}

// RemoveFriend handles DELETE /api/friends/:id
func (h *FriendHandler) RemoveFriend(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	friendID := c.Param("id")
	if friendID == "" {
		SendError(c, http.StatusBadRequest, errors.ErrMissingField, "Friend ID required")
		return
	}

	if err := h.friendService.RemoveFriend(c.Request.Context(), userID, friendID); err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "removed"})
}
