package http

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/errors"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type SettingsHandler struct {
	settingsService ports.SettingsService
}

func NewSettingsHandler(settingsService ports.SettingsService) *SettingsHandler {
	return &SettingsHandler{settingsService: settingsService}
}

// GetSettings handles GET /api/settings (auth required)
func (h *SettingsHandler) GetSettings(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	settings, err := h.settingsService.GetSettings(c.Request.Context(), userID)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, settings)
}

// UpdateSettings handles PUT and PATCH /api/settings (auth required)
func (h *SettingsHandler) UpdateSettings(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	var dto domain.UpdateSettingsDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		SendError(c, http.StatusBadRequest, errors.ErrInvalidFormat, "Invalid JSON payload: "+err.Error())
		return
	}

	updated, err := h.settingsService.UpdateSettings(c.Request.Context(), userID, &dto)
	if err != nil {
		SendError(c, http.StatusBadRequest, errors.ErrValidationFailed, err.Error())
		return
	}

	c.JSON(http.StatusOK, updated)
}

// ResetSettings handles POST /api/settings/reset (auth required)
func (h *SettingsHandler) ResetSettings(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	reset, err := h.settingsService.ResetSettings(c.Request.Context(), userID)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, reset)
}

// GetDefaults handles GET /api/settings/defaults (public)
func (h *SettingsHandler) GetDefaults(c *gin.Context) {
	defaults := h.settingsService.GetDefaultSettings()
	c.JSON(http.StatusOK, defaults)
}
