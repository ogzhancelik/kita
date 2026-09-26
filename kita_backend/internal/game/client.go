package game

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/oguzhancelik/kita/internal/core/errors"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 4096
)

type Client struct {
	Hub            *Hub
	Conn           *websocket.Conn
	Send           chan []byte
	UserID         string
	Username       string
	Rating         int
	CurrentMatchID string
	AvatarIndex    int

	// Rematch and invite tracking
	LastFinishedMatchID      string
	PendingRematchID         string
	PendingRematchTimeControl int64
	PendingInviteID          string
	PendingInviteFriendID    string
	PendingInviteTimeControl int64
	PendingInviteColor       string

	isClosed bool
	mu       sync.RWMutex
}

func NewClient(hub *Hub, conn *websocket.Conn, userID, username string, rating int, avatarIndex ...int) *Client {
	av := 0
	if len(avatarIndex) > 0 {
		av = avatarIndex[0]
	}
	return &Client{
		Hub:         hub,
		Conn:        conn,
		Send:        make(chan []byte, 256),
		UserID:      userID,
		Username:    username,
		Rating:      rating,
		AvatarIndex: av,
	}
}

// Close safely closes the Send channel and marks the client as closed.
func (c *Client) Close() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.isClosed {
		return
	}
	c.isClosed = true
	close(c.Send)
}

// IsClosed returns true if the client's Send channel has been closed.
func (c *Client) IsClosed() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.isClosed
}

func (c *Client) ReadPump() {
	defer func() {
		c.Hub.Unregister <- c
		c.Conn.Close()
	}()

	c.Conn.SetReadLimit(maxMessageSize)
	_ = c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error {
		_ = c.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("ws read error: %v", err)
			}
			break
		}

		var wsMsg WSMessage
		if err := json.Unmarshal(message, &wsMsg); err != nil {
			c.SendError(errors.ErrInvalidMessage, "Invalid message format")
			continue
		}

		c.Hub.RouteClientMessage(c, wsMsg)
	}
}

func (c *Client) WritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.Send:
			_ = c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.Conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			_, _ = w.Write(message)

			// Flush queued messages in the channel
			n := len(c.Send)
			for i := 0; i < n; i++ {
				_, _ = w.Write([]byte{'\n'})
				_, _ = w.Write(<-c.Send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			_ = c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (c *Client) SendJSON(msgType string, payload any) {
	if c == nil {
		return
	}

	c.mu.RLock()
	closed := c.isClosed
	c.mu.RUnlock()
	if closed {
		return
	}

	bytes, err := json.Marshal(payload)
	if err != nil {
		log.Printf("json marshal error: %v", err)
		return
	}

	msg := WSMessage{
		Type:    msgType,
		Payload: bytes,
	}

	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("ws msg marshal error: %v", err)
		return
	}

	bufferFull := false
	func() {
		c.mu.RLock()
		defer c.mu.RUnlock()
		if c.isClosed {
			return
		}

		defer func() {
			if r := recover(); r != nil {
				log.Printf("[Client %s] Recovered from send panic: %v", c.UserID, r)
			}
		}()

		select {
		case c.Send <- data:
		default:
			bufferFull = true
		}
	}()

	if bufferFull {
		log.Printf("client %s buffer full, closing connection", c.UserID)
		select {
		case c.Hub.Unregister <- c:
		default:
		}
	}
}

func (c *Client) SendError(code errors.ErrorCode, msg string) {
	c.SendJSON(TypeError, ErrorDTO{Code: code, Message: msg})
}
