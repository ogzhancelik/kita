package http

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/errors"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type DeviceTokenHandler struct {
	pushService ports.PushNotificationService
}

// NewDeviceTokenHandler creates an HTTP handler for device push token management.
func NewDeviceTokenHandler(pushService ports.PushNotificationService) *DeviceTokenHandler {
	return &DeviceTokenHandler{
		pushService: pushService,
	}
}

// RegisterToken handles POST /api/users/device-token
func (h *DeviceTokenHandler) RegisterToken(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	var dto domain.RegisterDeviceTokenDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		SendError(c, http.StatusBadRequest, errors.ErrInvalidMessage, "Token and platform are required")
		return
	}

	if err := h.pushService.RegisterToken(c.Request.Context(), userID, dto.Token, dto.Platform); err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, "Failed to register device token")
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Device token registered successfully",
	})
}

// RemoveToken handles DELETE /api/users/device-token
func (h *DeviceTokenHandler) RemoveToken(c *gin.Context) {
	var dto domain.RemoveDeviceTokenDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		SendError(c, http.StatusBadRequest, errors.ErrInvalidMessage, "Token is required")
		return
	}

	if err := h.pushService.RemoveToken(c.Request.Context(), dto.Token); err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, "Failed to remove device token")
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Device token removed successfully",
	})
}
