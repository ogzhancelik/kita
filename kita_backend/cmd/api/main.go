package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/oguzhancelik/kita/internal/game"
	httpHandler "github.com/oguzhancelik/kita/internal/handler/http"
	"github.com/oguzhancelik/kita/internal/handler/http/middleware"
	wsHandler "github.com/oguzhancelik/kita/internal/handler/ws"
	"github.com/oguzhancelik/kita/internal/repository/postgres"
	"github.com/oguzhancelik/kita/internal/service"
)

func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}

func main() {
	// 1. .env dosyasını proje kökünden yükle
	if err := godotenv.Load(); err != nil {
		log.Println("[Config] .env dosyası bulunamadı, sistem çevre değişkenleri kullanılıyor")
	} else {
		log.Println("[Config] .env dosyası kök dizinden başarıyla yüklendi")
	}

	log.Println("==================================================")
	log.Println("  KITA - ONLINE GAME BACKEND SERVER")
	log.Println("  Clean Architecture & Realtime WebSocket Engine")
	log.Println("==================================================")

	// 2. PostgreSQL Veritabanı Bağlantısı
	db, err := postgres.NewDatabase()
	if err != nil {
		log.Fatalf("Database connection failed: %v", err)
	}

	// 3. Repositories
	userRepo := postgres.NewUserRepository(db)
	matchRepo := postgres.NewMatchRepository(db)
	messageRepo := postgres.NewMessageRepository(db)
	settingsRepo := postgres.NewSettingsRepository(db)
	friendRepo := postgres.NewFriendRepository(db)

	// 4. Services
	authService := service.NewAuthService(userRepo)
	userService := service.NewUserService(userRepo, friendRepo)
	matchService := service.NewMatchService(matchRepo, userRepo)
	messageService := service.NewMessageService(messageRepo)
	settingsService := service.NewSettingsService(settingsRepo, userRepo)
	friendService := service.NewFriendService(friendRepo, userRepo)

	// 5. Realtime Game Hub & Goroutine
	hub := game.NewHub(matchService, messageService)
	go hub.Run()

	// 6. Handlers
	authH := httpHandler.NewAuthHandler(authService, userService)
	userH := httpHandler.NewUserHandler(userService)
	matchH := httpHandler.NewMatchHandler(matchService)
	settingsH := httpHandler.NewSettingsHandler(settingsService)
	friendH := httpHandler.NewFriendHandler(friendService)
	wsH := wsHandler.NewWSHandler(hub, authService, userService)

	// 7. Gin HTTP Engine
	router := gin.Default()
	router.Use(corsMiddleware())

	// Health Check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "healthy",
			"game":   "kita",
		})
	})

	// WebSocket Endpoint
	router.GET("/ws", wsH.HandleConnection)

	// Public API Routes
	api := router.Group("/api")
	{
		authRoutes := api.Group("/auth")
		{
			authRoutes.POST("/register", authH.Register)
			authRoutes.POST("/login", authH.Login)
			authRoutes.GET("/me", middleware.AuthMiddleware(authService), authH.Me)
		}

		userRoutes := api.Group("/users")
		{
			userRoutes.GET("/profile/:id", userH.GetProfile)
			userRoutes.GET("/leaderboard", middleware.OptionalAuthMiddleware(authService), userH.GetLeaderboard)
			userRoutes.GET("/me/settings", middleware.AuthMiddleware(authService), settingsH.GetSettings)
			userRoutes.PUT("/me/settings", middleware.AuthMiddleware(authService), settingsH.UpdateSettings)
		}

		settingsRoutes := api.Group("/settings")
		{
			settingsRoutes.GET("/defaults", settingsH.GetDefaults)
			settingsRoutes.GET("", middleware.AuthMiddleware(authService), settingsH.GetSettings)
			settingsRoutes.PUT("", middleware.AuthMiddleware(authService), settingsH.UpdateSettings)
			settingsRoutes.PATCH("", middleware.AuthMiddleware(authService), settingsH.UpdateSettings)
			settingsRoutes.POST("/reset", middleware.AuthMiddleware(authService), settingsH.ResetSettings)
		}

		matchRoutes := api.Group("/matches")
		{
			matchRoutes.GET("/:id", matchH.GetMatch)
			matchRoutes.GET("/:id/moves", matchH.GetMatchMoves)
			matchRoutes.GET("/user/:userId", matchH.GetUserMatches)
		}

		friendRoutes := api.Group("/friends", middleware.AuthMiddleware(authService))
		{
			friendRoutes.GET("", friendH.GetFriends)
			friendRoutes.GET("/requests", friendH.GetPendingRequests)
			friendRoutes.POST("/request", friendH.SendRequest)
			friendRoutes.POST("/:id/accept", friendH.AcceptRequest)
			friendRoutes.POST("/:id/decline", friendH.DeclineRequest)
			friendRoutes.DELETE("/:id", friendH.RemoveFriend)
		}

		api.GET("/stats/online", func(c *gin.Context) {
			online, inQueue := hub.GetOnlineStats()
			c.JSON(http.StatusOK, gin.H{
				"count":    online,
				"in_queue": inQueue,
			})
		})
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port :%s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}
