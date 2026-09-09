package ws

import (
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"github.com/oguzhancelik/kita/internal/game"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		// Can be restricted in production
		return true
	},
}

type WSHandler struct {
	hub         *game.Hub
	authService ports.AuthService
	userService ports.UserService
}

func NewWSHandler(hub *game.Hub, authService ports.AuthService, userService ports.UserService) *WSHandler {
	return &WSHandler{
		hub:         hub,
		authService: authService,
		userService: userService,
	}
}

func (h *WSHandler) HandleConnection(c *gin.Context) {
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("Failed to upgrade connection to WebSocket: %v", err)
		return
	}

	// Token'ı query param veya header'dan al
	token := c.Query("token")
	if token == "" {
		authHeader := c.GetHeader("Authorization")
		if authHeader != "" {
			parts := strings.Split(authHeader, " ")
			if len(parts) == 2 && strings.ToLower(parts[0]) == "bearer" {
				token = parts[1]
			}
		}
	}

	var userID string
	var username string
	rating := 1200

	if token != "" {
		if uid, err := h.authService.ValidateToken(token); err == nil {
			userID = uid
			if profile, err := h.userService.GetProfile(c.Request.Context(), userID); err == nil {
				username = profile.Username
				rating = profile.Rating
			}
		}
	}

	// Eğer kimliği doğrulanmamışsa Guest olarak bağla
	if userID == "" {
		rnd := rand.New(rand.NewSource(time.Now().UnixNano())).Intn(9000) + 1000
		guestUUID := uuid.New().String()[:8]
		userID = fmt.Sprintf("guest-%s", guestUUID)
		username = fmt.Sprintf("Guest%d", rnd)
	}

	client := game.NewClient(h.hub, conn, userID, username, rating)
	h.hub.Register <- client

	go client.WritePump()
	go client.ReadPump()
}
