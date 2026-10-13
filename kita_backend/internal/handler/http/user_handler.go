package http

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/errors"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"github.com/oguzhancelik/kita/internal/service"
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
	AvatarIndex     *int    `json:"avatar_index"`
	AltAvatarIndex  *int    `json:"avatarIndex"`
	AvatarCustom    *string `json:"avatar_custom"`
	AltAvatarCustom *string `json:"avatarCustom"`
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

	var targetCustom string
	hasCustom := false
	if req.AvatarCustom != nil {
		targetCustom = *req.AvatarCustom
		hasCustom = true
	} else if req.AltAvatarCustom != nil {
		targetCustom = *req.AltAvatarCustom
		hasCustom = true
	}

	if targetIndex < 0 || targetIndex > 256 {
		SendError(c, http.StatusBadRequest, errors.ErrValidationFailed, "avatar index out of range")
		return
	}

	if len(targetCustom) > 32 {
		SendError(c, http.StatusBadRequest, errors.ErrValidationFailed, "avatar custom too long")
		return
	}

	var profile *domain.UserProfile
	var err error
	if hasCustom {
		profile, err = h.userService.UpdateAvatar(c.Request.Context(), userID.(string), targetIndex, targetCustom)
	} else {
		profile, err = h.userService.UpdateAvatar(c.Request.Context(), userID.(string), targetIndex)
	}

	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, profile)
}

type UpdateUsernameRequest struct {
	Username string `json:"username" binding:"required,min=2,max=15"`
}

func (h *UserHandler) UpdateUsername(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Unauthorized")
		return
	}

	var req UpdateUsernameRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		SendError(c, http.StatusBadRequest, errors.ErrValidationFailed, err.Error())
		return
	}

	profile, err := h.userService.UpdateUsername(c.Request.Context(), userID.(string), req.Username)
	if err != nil {
		if err == service.ErrUserAlreadyExists {
			SendError(c, http.StatusConflict, errors.ErrUserAlreadyExists, err.Error())
			return
		}
		if err == service.ErrUsernameReserved {
			SendError(c, http.StatusBadRequest, errors.ErrUsernameReserved, err.Error())
			return
		}
		if err == service.ErrInvalidUsername {
			SendError(c, http.StatusBadRequest, errors.ErrUsernameInvalid, err.Error())
			return
		}
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, profile)
}

type deleteAccountRequest struct {
	Password string `json:"password" binding:"required"`
}

func (h *UserHandler) DeleteAccount(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Unauthorized")
		return
	}

	var req deleteAccountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		SendError(c, http.StatusBadRequest, errors.ErrValidationFailed, "Password is required")
		return
	}

	if err := h.userService.DeleteAccount(c.Request.Context(), userID.(string), req.Password); err != nil {
		if err == service.ErrWrongPassword {
			SendError(c, http.StatusBadRequest, errors.ErrWrongPassword, err.Error())
			return
		}
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "account deleted successfully",
	})
}

func (h *UserHandler) SearchUsers(c *gin.Context) {
	query := c.Query("q")
	limitStr := c.DefaultQuery("limit", "20")
	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		limit = 20
	}

	var currentUserID string
	if val, exists := c.Get("userID"); exists {
		if id, ok := val.(string); ok {
			currentUserID = id
		}
	}

	results, err := h.userService.SearchUsers(c.Request.Context(), query, currentUserID, limit)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{"users": results})
}




