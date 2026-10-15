package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/url"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/gorilla/websocket"
)

type GhostBot struct {
	Nickname     string
	Rating       int
	AvatarIndex  int
	AvatarCustom string
	TimeControl  int // in ms: 60000, 180000, 300000, 0
}

var bots = []GhostBot{
	{Nickname: "MagnusK", Rating: 2150, AvatarIndex: 6, TimeControl: 180000},
	{Nickname: "HikaruN", Rating: 2090, AvatarIndex: 4, TimeControl: 60000},
	{Nickname: "ViperTactics", Rating: 1980, AvatarIndex: 4, TimeControl: 300000},
	{Nickname: "QueenOfGambits", Rating: 1850, AvatarIndex: 3, TimeControl: 180000},
	{Nickname: "IronVanguard", Rating: 1740, AvatarIndex: 2, TimeControl: 300000},
	{Nickname: "ApexHunter", Rating: 1690, AvatarIndex: 0, TimeControl: 180000},
	{Nickname: "SolarisKnight", Rating: 1610, AvatarIndex: 1, TimeControl: 60000},
	{Nickname: "ShadowFalcon", Rating: 1540, AvatarIndex: 7, TimeControl: 180000},
	{Nickname: "TitanMaster", Rating: 1480, AvatarIndex: 5, TimeControl: 300000},
	{Nickname: "NovaStrike", Rating: 1420, AvatarIndex: 4, TimeControl: 180000},
	{Nickname: "QuantumPawn", Rating: 1360, AvatarIndex: 3, TimeControl: 60000},
	{Nickname: "BlitzCrafter", Rating: 1310, AvatarIndex: 1, TimeControl: 180000},
	{Nickname: "CelestialKing", Rating: 1250, AvatarIndex: 6, TimeControl: 300000},
	{Nickname: "MysticRook", Rating: 1190, AvatarIndex: 7, TimeControl: 180000},
	{Nickname: "PawnStormer", Rating: 1140, AvatarIndex: 0, TimeControl: 60000},
	{Nickname: "KaptanPenguen", Rating: 1280, AvatarCustom: "🐧", TimeControl: 180000},
	{Nickname: "EfsaneOyuncu", Rating: 1520, AvatarCustom: "⚡", TimeControl: 300000},
	{Nickname: "BordoBereli", Rating: 1640, AvatarCustom: "🎯", TimeControl: 180000},
	{Nickname: "GeceKusu", Rating: 1380, AvatarCustom: "🦉", TimeControl: 60000},
	{Nickname: "SavasciPiyon", Rating: 1210, AvatarCustom: "⚔️", TimeControl: 180000},
	{Nickname: "SatrancUstad", Rating: 1790, AvatarCustom: "👑", TimeControl: 300000},
	{Nickname: "HizliHamle", Rating: 1460, AvatarCustom: "🚀", TimeControl: 60000},
	{Nickname: "GizliKral", Rating: 1320, AvatarCustom: "🦊", TimeControl: 180000},
	{Nickname: "ZekaKupu", Rating: 1570, AvatarCustom: "🧠", TimeControl: 300000},
	{Nickname: "AtesliPiyon", Rating: 1230, AvatarCustom: "🔥", TimeControl: 180000},
}

func main() {
	serverURL := "ws://127.0.0.1:8080/ws"
	if len(os.Args) > 1 {
		serverURL = os.Args[1]
	}

	log.Printf("Connecting %d ghost bots to %s...", len(bots), serverURL)

	var conns []*websocket.Conn
	var mu sync.Mutex
	var wg sync.WaitGroup

	for i, bot := range bots {
		wg.Add(1)
		go func(idx int, b GhostBot) {
			defer wg.Done()
			q := url.Values{}
			q.Set("nickname", b.Nickname)
			q.Set("rating", fmt.Sprintf("%d", b.Rating))
			q.Set("is_provisional", "false")
			if b.AvatarCustom != "" {
				q.Set("avatar_custom", b.AvatarCustom)
			} else {
				q.Set("avatar_index", fmt.Sprintf("%d", b.AvatarIndex))
			}

			u, err := url.Parse(serverURL)
			if err != nil {
				log.Printf("[%s] Invalid URL: %v", b.Nickname, err)
				return
			}
			u.RawQuery = q.Encode()

			var c *websocket.Conn
			for attempt := 0; attempt < 3; attempt++ {
				c, _, err = websocket.DefaultDialer.Dial(u.String(), nil)
				if err == nil {
					break
				}
				time.Sleep(300 * time.Millisecond)
			}
			if err != nil || c == nil {
				log.Printf("[%s] Connection failed: %v", b.Nickname, err)
				return
			}

			mu.Lock()
			conns = append(conns, c)
			mu.Unlock()

			// Send create_room message
			createMsg := map[string]interface{}{
				"type": "create_room",
				"payload": map[string]interface{}{
					"time_control": b.TimeControl,
					"is_private":   false,
				},
			}
			data, _ := json.Marshal(createMsg)
			if err := c.WriteMessage(websocket.TextMessage, data); err != nil {
				log.Printf("[%s] Failed to send create_room: %v", b.Nickname, err)
				return
			}

			// Read loop to handle ping/pong and room confirmation
			go func() {
				for {
					_, msg, err := c.ReadMessage()
					if err != nil {
						return
					}
					var parsed struct {
						Type    string          `json:"type"`
						Payload json.RawMessage `json:"payload"`
					}
					if err := json.Unmarshal(msg, &parsed); err == nil {
						if parsed.Type == "room_created" {
							var rc struct {
								RoomCode string `json:"room_code"`
							}
							_ = json.Unmarshal(parsed.Payload, &rc)
							log.Printf("[%02d/25] Room created: %s | Host: %s (%d) | TC: %dms",
								idx+1, rc.RoomCode, b.Nickname, b.Rating, b.TimeControl)
						}
					}
				}
			}()
		}(i, bot)

		// Small jitter so all 25 rooms connect smoothly
		time.Sleep(40 * time.Millisecond)
	}

	wg.Wait()
	log.Printf("\n>>> All %d ghost rooms are ACTIVE and waiting in lobby! <<<", len(conns))
	log.Printf(">>> Test in frontend now. Press Ctrl+C anytime to close all ghost rooms. <<<")

	// Wait for OS interrupt (Ctrl+C)
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)
	<-sigCh

	log.Println("\nStopping ghost bots and cleaning up rooms...")
	mu.Lock()
	for _, c := range conns {
		_ = c.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, "bye"))
		_ = c.Close()
	}
	mu.Unlock()

	time.Sleep(500 * time.Millisecond)
	log.Println("All ghost rooms closed. Done!")
}
