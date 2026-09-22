package main

import (
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/repository/postgres"
	"golang.org/x/crypto/bcrypt"
)

type SeedUser struct {
	Username string
	Email    string
	Rating   float64
	Wins     int
	Losses   int
	Draws    int
}

func main() {
	db, err := postgres.NewDatabase()
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("Failed to hash default password: %v", err)
	}

	usersToSeed := []SeedUser{
		// 10 users with 1400 ELO
		{Username: "ViperTactics", Email: "viper.tactics@kita.gg", Rating: 1400, Wins: 18, Losses: 8, Draws: 3},
		{Username: "GrandStrategist", Email: "grand.strategist@kita.gg", Rating: 1400, Wins: 22, Losses: 10, Draws: 4},
		{Username: "ApexHunter", Email: "apex.hunter@kita.gg", Rating: 1400, Wins: 15, Losses: 6, Draws: 2},
		{Username: "IronVanguard", Email: "iron.vanguard@kita.gg", Rating: 1400, Wins: 19, Losses: 9, Draws: 5},
		{Username: "SolarisKnight", Email: "solaris.knight@kita.gg", Rating: 1400, Wins: 14, Losses: 5, Draws: 1},
		{Username: "CelestialKing", Email: "celestial.king@kita.gg", Rating: 1400, Wins: 20, Losses: 9, Draws: 2},
		{Username: "QuantumPawn", Email: "quantum.pawn@kita.gg", Rating: 1400, Wins: 16, Losses: 7, Draws: 4},
		{Username: "ShadowFalcon", Email: "shadow.falcon@kita.gg", Rating: 1400, Wins: 25, Losses: 12, Draws: 6},
		{Username: "NovaStrike", Email: "nova.strike@kita.gg", Rating: 1400, Wins: 17, Losses: 8, Draws: 3},
		{Username: "TitanMaster", Email: "titan.master@kita.gg", Rating: 1400, Wins: 21, Losses: 10, Draws: 2},

		// 10 users with 1000 ELO
		{Username: "PawnSeeker", Email: "pawn.seeker@kita.gg", Rating: 1000, Wins: 4, Losses: 14, Draws: 2},
		{Username: "NoviceRanger", Email: "novice.ranger@kita.gg", Rating: 1000, Wins: 6, Losses: 16, Draws: 1},
		{Username: "SilentDrifter", Email: "silent.drifter@kita.gg", Rating: 1000, Wins: 5, Losses: 15, Draws: 3},
		{Username: "CopperShield", Email: "copper.shield@kita.gg", Rating: 1000, Wins: 7, Losses: 18, Draws: 2},
		{Username: "CasualGamer", Email: "casual.gamer@kita.gg", Rating: 1000, Wins: 3, Losses: 12, Draws: 1},
		{Username: "BoardExplorer", Email: "board.explorer@kita.gg", Rating: 1000, Wins: 8, Losses: 20, Draws: 4},
		{Username: "RustyBlade", Email: "rusty.blade@kita.gg", Rating: 1000, Wins: 4, Losses: 13, Draws: 0},
		{Username: "WanderingKnight", Email: "wandering.knight@kita.gg", Rating: 1000, Wins: 6, Losses: 17, Draws: 2},
		{Username: "EchoStep", Email: "echo.step@kita.gg", Rating: 1000, Wins: 5, Losses: 14, Draws: 1},
		{Username: "StarterSpark", Email: "starter.spark@kita.gg", Rating: 1000, Wins: 2, Losses: 10, Draws: 1},
	}

	fmt.Println("=== Seeding 20 Accounts (10 with 1400 ELO, 10 with 1000 ELO) ===")

	for i, u := range usersToSeed {
		var existing domain.User
		res := db.Where("username = ? OR email = ?", u.Username, u.Email).First(&existing)
		if res.Error == nil {
			// Update existing user rating and stats
			existing.Rating = u.Rating
			existing.Wins = u.Wins
			existing.Losses = u.Losses
			existing.Draws = u.Draws
			existing.UpdatedAt = time.Now()
			if err := db.Save(&existing).Error; err != nil {
				log.Printf("[%02d] Failed to update %s: %v", i+1, u.Username, err)
			} else {
				fmt.Printf("[%02d] Updated existing user: %-18s | ELO: %4.0f | Record: %dW-%dL-%dD\n", i+1, existing.Username, existing.Rating, existing.Wins, existing.Losses, existing.Draws)
			}
		} else {
			// Create new user
			newUser := domain.User{
				ID:              uuid.New().String(),
				Username:        u.Username,
				Email:           u.Email,
				PasswordHash:    string(hashedPassword),
				Rating:          u.Rating,
				RatingDeviation: 150,
				Volatility:      0.06,
				Wins:            u.Wins,
				Losses:          u.Losses,
				Draws:           u.Draws,
				CreatedAt:       time.Now(),
				UpdatedAt:       time.Now(),
			}
			if err := db.Create(&newUser).Error; err != nil {
				log.Printf("[%02d] Failed to create %s: %v", i+1, u.Username, err)
			} else {
				fmt.Printf("[%02d] Created new user:      %-18s | ELO: %4.0f | Record: %dW-%dL-%dD\n", i+1, newUser.Username, newUser.Rating, newUser.Wins, newUser.Losses, newUser.Draws)
			}
		}
	}

	fmt.Println("\n=== Seeding Completed Successfully! All default passwords set to: password123 ===")

	// Now add 5 friends for user 'zaazaa'
	var zaazaa domain.User
	if err := db.Where("username = ?", "zaazaa").First(&zaazaa).Error; err != nil {
		log.Printf("User 'zaazaa' not found in database: %v", err)
		return
	}

	friendsToAdd := []string{
		"ViperTactics",
		"GrandStrategist",
		"ApexHunter",
		"PawnSeeker",
		"NoviceRanger",
	}

	fmt.Println("\n=== Adding 5 Friends for 'zaazaa' ===")
	for _, friendUsername := range friendsToAdd {
		var friendUser domain.User
		if err := db.Where("username = ?", friendUsername).First(&friendUser).Error; err != nil {
			log.Printf("Friend '%s' not found: %v", friendUsername, err)
			continue
		}

		var existingFriendship domain.Friendship
		err := db.Where(
			"(requester_id = ? AND addressee_id = ?) OR (requester_id = ? AND addressee_id = ?)",
			zaazaa.ID, friendUser.ID, friendUser.ID, zaazaa.ID,
		).First(&existingFriendship).Error

		if err == nil {
			existingFriendship.Status = domain.FriendshipStatusAccepted
			existingFriendship.UpdatedAt = time.Now()
			db.Save(&existingFriendship)
			fmt.Printf("Friendship updated to accepted: zaazaa <-> %s\n", friendUsername)
		} else {
			newFriendship := domain.Friendship{
				ID:          uuid.New().String(),
				RequesterID: zaazaa.ID,
				AddresseeID: friendUser.ID,
				Status:      domain.FriendshipStatusAccepted,
				CreatedAt:   time.Now(),
				UpdatedAt:   time.Now(),
			}
			if err := db.Create(&newFriendship).Error; err != nil {
				log.Printf("Failed to create friendship with %s: %v", friendUsername, err)
			} else {
				fmt.Printf("Friendship created: zaazaa <-> %s (Status: accepted)\n", friendUsername)
			}
		}
	}
	fmt.Println("=== Friends Seeding Completed! ===")
}
