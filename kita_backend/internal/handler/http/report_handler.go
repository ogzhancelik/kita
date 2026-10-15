package http

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/errors"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"github.com/oguzhancelik/kita/internal/game"
)

type ReportHandler struct {
	db                  *gorm.DB
	dmService           ports.DirectMessageService
	notificationService ports.NotificationService
	hub                 *game.Hub
}

func NewReportHandler(
	db *gorm.DB,
	dmService ports.DirectMessageService,
	notificationService ports.NotificationService,
	hub *game.Hub,
) *ReportHandler {
	return &ReportHandler{
		db:                  db,
		dmService:           dmService,
		notificationService: notificationService,
		hub:                 hub,
	}
}

type CreateReportDTO struct {
	Reason           string `json:"reason" binding:"required"`
	Description      string `json:"description"`
	MatchID          string `json:"match_id"`
	ReportedUsername string `json:"reported_username"`
}

func (h *ReportHandler) CreateReport(c *gin.Context) {
	var req CreateReportDTO
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.Reason) == "" {
		SendError(c, http.StatusBadRequest, errors.ErrMissingField, "Reason is required")
		return
	}

	ctx := c.Request.Context()

	// 1. Determine reporter identity
	reporterUsername := "Guest"
	userID := c.GetString("userID")
	if userID != "" {
		var user domain.User
		if err := h.db.WithContext(ctx).First(&user, "id = ?", userID).Error; err == nil && user.Username != "" {
			reporterUsername = user.Username
		}
	}

	// 2. Ensure "Report" system user exists
	var reportBot domain.User
	if err := h.db.WithContext(ctx).Where("LOWER(username) = ?", "report").First(&reportBot).Error; err != nil {
		reportBot = domain.User{
			ID:           uuid.New().String(),
			Username:     "Report",
			Email:        "report-system@kita.gg",
			PasswordHash: "*",
			AvatarIndex:  0,
			AvatarCustom: "🚨",
			Roles:        []string{"system"},
		}
		if err := h.db.WithContext(ctx).Create(&reportBot).Error; err != nil {
			_ = h.db.WithContext(ctx).Where("LOWER(username) = ?", "report").First(&reportBot).Error
		}
	} else if reportBot.AvatarCustom != "🚨" {
		reportBot.AvatarCustom = "🚨"
		_ = h.db.WithContext(ctx).Model(&reportBot).Update("avatar_custom", "🚨").Error
	}

	// 3. Find all users with admin role
	var admins []domain.User
	_ = h.db.WithContext(ctx).Where("roles::text ILIKE ?", "%\"admin\"%").Find(&admins).Error

	// Format report message
	var sb strings.Builder
	sb.WriteString("🚨 [REPORT RECEIVED]\n")
	sb.WriteString(fmt.Sprintf("• Reporter: %s\n", reporterUsername))
	if strings.TrimSpace(req.ReportedUsername) != "" {
		sb.WriteString(fmt.Sprintf("• Reported Player: %s\n", req.ReportedUsername))
	}
	if strings.TrimSpace(req.MatchID) != "" {
		sb.WriteString(fmt.Sprintf("• Match ID: %s\n", req.MatchID))
	}
	sb.WriteString(fmt.Sprintf("• Reason: %s", req.Reason))
	if strings.TrimSpace(req.Description) != "" {
		sb.WriteString(fmt.Sprintf("\n• Details: %s", req.Description))
	}
	messageContent := sb.String()

	// 4. Send DM to each admin user from "Report"
	for _, admin := range admins {
		if admin.ID == reportBot.ID {
			continue
		}

		saved, err := h.dmService.Send(ctx, reportBot.ID, admin.ID, messageContent)
		if err != nil {
			continue
		}

		if h.hub != nil {
			broadcast := game.DmBroadcastDTO{
				ID:                    saved.ID,
				ConversationID:        saved.ConversationID,
				SenderID:              reportBot.ID,
				SenderUsername:        reportBot.Username,
				SenderAvatarIndex:     reportBot.AvatarIndex,
				SenderAvatarCustom:    reportBot.AvatarCustom,
				RecipientID:           admin.ID,
				RecipientUsername:     admin.Username,
				RecipientAvatarIndex:  admin.AvatarIndex,
				RecipientAvatarCustom: admin.AvatarCustom,
				Content:               saved.Content,
				CreatedAt:             saved.CreatedAt,
			}
			h.hub.SendToUser(admin.ID, game.TypeDmBroadcast, broadcast)

			if h.notificationService != nil {
				notifID := fmt.Sprintf("chat_%s_%s", saved.ConversationID, admin.ID)
				payloadMap := map[string]interface{}{
					"conversation_id": saved.ConversationID,
					"sender_id":       reportBot.ID,
					"sender_username": reportBot.Username,
					"sender_avatar":   reportBot.AvatarIndex,
				}
				payloadBytes, _ := json.Marshal(payloadMap)

				notif := &domain.Notification{
					ID:        notifID,
					UserID:    admin.ID,
					ActorID:   reportBot.ID,
					ActorName: reportBot.Username,
					Type:      domain.NotificationTypeChat,
					Status:    domain.NotificationStatusPending,
					Title:     "Report: " + reporterUsername,
					Subtitle:  req.Reason,
					Payload:   string(payloadBytes),
					CreatedAt: saved.CreatedAt,
					UpdatedAt: time.Now(),
				}
				_, _ = h.notificationService.UpsertNotification(context.Background(), notif)
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"status":  "success",
		"message": "Report received",
	})
}
