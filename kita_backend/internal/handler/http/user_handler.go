package http

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/oguzhancelik/kita/internal/core/errors"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type UserHandler struct {
	userService ports.UserService
}

func NewUserHandler(userService ports.UserService) *UserHandler {
	return &UserHandler{userService: userService}
}

func (h *UserHandler) GetProfile(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		SendError(c, http.StatusBadRequest, errors.ErrMissingField, "User ID is required")
		return
	}

	profile, err := h.userService.GetProfile(c.Request.Context(), id)
	if err != nil {
		SendError(c, http.StatusNotFound, errors.ErrNotFound, err.Error())
		return
	}

	c.JSON(http.StatusOK, profile)
}

func (h *UserHandler) GetLeaderboard(c *gin.Context) {
	limitStr := c.DefaultQuery("limit", "20")
	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		limit = 20
	}

	filter := c.DefaultQuery("filter", "global")
	var currentUserID string
	if val, exists := c.Get("userID"); exists {
		if id, ok := val.(string); ok {
			currentUserID = id
		}
	}

	leaderboard, err := h.userService.GetLeaderboard(c.Request.Context(), limit, filter, currentUserID)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{"leaderboard": leaderboard})
}

type UpdateAvatarRequest struct {
	AvatarIndex    *int `json:"avatar_index"`
	AltAvatarIndex *int `json:"avatarIndex"`
}

func (h *UserHandler) UpdateAvatar(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Unauthorized")
		return
	}

	var req UpdateAvatarRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		SendError(c, http.StatusBadRequest, errors.ErrValidationFailed, err.Error())
		return
	}

	targetIndex := 0
	if req.AvatarIndex != nil {
		targetIndex = *req.AvatarIndex
	} else if req.AltAvatarIndex != nil {
		targetIndex = *req.AltAvatarIndex
	}

	if targetIndex < 0 || targetIndex > 64 {
		SendError(c, http.StatusBadRequest, errors.ErrValidationFailed, "avatar index out of range")
		return
	}

	profile, err := h.userService.UpdateAvatar(c.Request.Context(), userID.(string), targetIndex)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, profile)
}

