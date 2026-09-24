package http

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/errors"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type NotificationHandler struct {
	notificationService ports.NotificationService
}

func NewNotificationHandler(notificationService ports.NotificationService) *NotificationHandler {
	return &NotificationHandler{
		notificationService: notificationService,
	}
}

// GetNotifications handles GET /api/notifications
func (h *NotificationHandler) GetNotifications(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	limit := 50
	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	offset := 0
	if o := c.Query("offset"); o != "" {
		if parsed, err := strconv.Atoi(o); err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	notifs, count, err := h.notificationService.GetUserNotifications(c.Request.Context(), userID, limit, offset)
	if err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"notifications": notifs,
		"unread_count":  count,
	})
}

// UpdateStatus handles PATCH /api/notifications/:id/status
func (h *NotificationHandler) UpdateStatus(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	id := c.Param("id")
	if id == "" {
		SendError(c, http.StatusBadRequest, errors.ErrMissingField, "Notification ID required")
		return
	}

	var dto domain.UpdateNotificationStatusDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		SendError(c, http.StatusBadRequest, errors.ErrValidationFailed, "Invalid request payload")
		return
	}

	if err := h.notificationService.UpdateStatus(c.Request.Context(), id, userID, dto.Status); err != nil {
		if appErr, ok := err.(*errors.AppError); ok {
			SendError(c, http.StatusBadRequest, appErr.Code, appErr.Message)
			return
		}
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":              "ok",
		"id":                  id,
		"notification_status": dto.Status,
	})
}

// MarkAllAsRead handles POST /api/notifications/mark-all-read
func (h *NotificationHandler) MarkAllAsRead(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	if err := h.notificationService.MarkAllAsRead(c.Request.Context(), userID); err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

// DeleteNotification handles DELETE /api/notifications/:id
func (h *NotificationHandler) DeleteNotification(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Authentication required")
		return
	}

	id := c.Param("id")
	if id == "" {
		SendError(c, http.StatusBadRequest, errors.ErrMissingField, "Notification ID required")
		return
	}

	if err := h.notificationService.DeleteNotification(c.Request.Context(), id, userID); err != nil {
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "deleted", "id": id})
}
