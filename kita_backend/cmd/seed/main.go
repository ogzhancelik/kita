package main

import (
	"fmt"
	"hash/crc32"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/joho/godotenv"
	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/repository/postgres"
	"golang.org/x/crypto/bcrypt"
)

type SeedUser struct {
	Username    string
	Email       string
	AvatarIndex int
	Rating      float64
	Wins        int
	Losses      int
	Draws       int
}

func main() {
	if err := godotenv.Load(); err != nil {
		_ = godotenv.Load("../../.env")
	}

	db, err := postgres.NewDatabase()
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("Failed to hash default password: %v", err)
	}

	usersToSeed := []SeedUser{
		// 1. Grandmaster tier
		{Username: "Grandmaster_K", Email: "gm.k@kita.gg", AvatarIndex: 6, Rating: 2150, Wins: 88, Losses: 12, Draws: 6}, // Dragon
		{Username: "ViperTactics", Email: "viper.tactics@kita.gg", AvatarIndex: 4, Rating: 1980, Wins: 65, Losses: 19, Draws: 8}, // Striker
		{Username: "QueenOfGambits", Email: "queen.gambits@kita.gg", AvatarIndex: 3, Rating: 1850, Wins: 52, Losses: 21, Draws: 7}, // Mage

		// 2. Expert tier
		{Username: "IronVanguard", Email: "iron.vanguard@kita.gg", AvatarIndex: 2, Rating: 1740, Wins: 44, Losses: 22, Draws: 10}, // Guardian
		{Username: "ApexHunter", Email: "apex.hunter@kita.gg", AvatarIndex: 0, Rating: 1690, Wins: 38, Losses: 20, Draws: 4}, // Wolf
		{Username: "SolarisKnight", Email: "solaris.knight@kita.gg", AvatarIndex: 1, Rating: 1610, Wins: 33, Losses: 18, Draws: 5}, // Knight
		{Username: "ShadowFalcon", Email: "shadow.falcon@kita.gg", AvatarIndex: 7, Rating: 1540, Wins: 29, Losses: 19, Draws: 3}, // Oracle

		// 3. Intermediate tier
		{Username: "TitanMaster", Email: "titan.master@kita.gg", AvatarIndex: 5, Rating: 1480, Wins: 26, Losses: 20, Draws: 6}, // Captain
		{Username: "NovaStrike", Email: "nova.strike@kita.gg", AvatarIndex: 4, Rating: 1420, Wins: 24, Losses: 21, Draws: 5}, // Striker
		{Username: "QuantumPawn", Email: "quantum.pawn@kita.gg", AvatarIndex: 3, Rating: 1360, Wins: 21, Losses: 22, Draws: 4}, // Mage
		{Username: "BlitzCrafter", Email: "blitz.crafter@kita.gg", AvatarIndex: 1, Rating: 1310, Wins: 19, Losses: 20, Draws: 3}, // Knight
		{Username: "CelestialKing", Email: "celestial.king@kita.gg", AvatarIndex: 6, Rating: 1250, Wins: 17, Losses: 18, Draws: 4}, // Dragon
		{Username: "MysticRook", Email: "mystic.rook@kita.gg", AvatarIndex: 7, Rating: 1190, Wins: 14, Losses: 18, Draws: 2}, // Oracle

		// 4. Casual & Novice tier
		{Username: "EchoStep", Email: "echo.step@kita.gg", AvatarIndex: 2, Rating: 1120, Wins: 12, Losses: 18, Draws: 3}, // Guardian
		{Username: "CopperShield", Email: "copper.shield@kita.gg", AvatarIndex: 5, Rating: 1060, Wins: 10, Losses: 19, Draws: 2}, // Captain
		{Username: "PawnSeeker", Email: "pawn.seeker@kita.gg", AvatarIndex: 0, Rating: 990, Wins: 8, Losses: 21, Draws: 1}, // Wolf
		{Username: "NoviceRanger", Email: "novice.ranger@kita.gg", AvatarIndex: 1, Rating: 920, Wins: 6, Losses: 22, Draws: 2}, // Knight
		{Username: "WanderingKnight", Email: "wandering.knight@kita.gg", AvatarIndex: 4, Rating: 850, Wins: 5, Losses: 24, Draws: 1}, // Striker
		{Username: "BoardExplorer", Email: "board.explorer@kita.gg", AvatarIndex: 3, Rating: 780, Wins: 3, Losses: 20, Draws: 0}, // Mage
		{Username: "StarterSpark", Email: "starter.spark@kita.gg", AvatarIndex: 6, Rating: 690, Wins: 2, Losses: 18, Draws: 1}, // Dragon
	}

	fmt.Println("=== Seeding 20 Diverse Player Profiles with Randomized Avatars (690 - 2150 ELO) ===")

	seededUsers := make(map[string]domain.User)

	for i, u := range usersToSeed {
		var existing domain.User
		res := db.Where("username = ? OR email = ?", u.Username, u.Email).First(&existing)
		if res.Error == nil {
			existing.AvatarIndex = u.AvatarIndex
			existing.Rating = u.Rating
			existing.Wins = u.Wins
			existing.Losses = u.Losses
			existing.Draws = u.Draws
			existing.UpdatedAt = time.Now()
			if err := db.Save(&existing).Error; err != nil {
				log.Printf("[%02d] Failed to update %s: %v", i+1, u.Username, err)
			} else {
				fmt.Printf("[%02d] Updated user: %-18s | Avatar: %d | ELO: %4.0f\n", i+1, existing.Username, existing.AvatarIndex, existing.Rating)
				seededUsers[u.Username] = existing
			}
		} else {
			newUser := domain.User{
				ID:              uuid.New().String(),
				Username:        u.Username,
				Email:           u.Email,
				PasswordHash:    string(hashedPassword),
				AvatarIndex:     u.AvatarIndex,
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
				fmt.Printf("[%02d] Created user: %-18s | Avatar: %d | ELO: %4.0f\n", i+1, newUser.Username, newUser.AvatarIndex, newUser.Rating)
				seededUsers[u.Username] = newUser
			}
		}
	}

	fmt.Println("\n=== Seeding Completed Successfully! All default passwords set to: password123 ===")

	// Now link friendships for any human registered users in the database
	var humanUsers []domain.User
	db.Where("email NOT LIKE '%@kita.gg'").Find(&humanUsers)

	friendsPool := []string{
		"ViperTactics",
		"QueenOfGambits",
		"ApexHunter",
		"SolarisKnight",
		"TitanMaster",
		"EchoStep",
		"CopperShield",
		"PawnSeeker",
		"NoviceRanger",
	}

	for _, human := range humanUsers {
		fmt.Printf("\n=== Linking Friends for '%s' ===\n", human.Username)
		for _, friendUsername := range friendsPool {
			friendUser, ok := seededUsers[friendUsername]
			if !ok {
				continue
			}

			var existingFriendship domain.Friendship
			err := db.Where(
				"(requester_id = ? AND addressee_id = ?) OR (requester_id = ? AND addressee_id = ?)",
				human.ID, friendUser.ID, friendUser.ID, human.ID,
			).First(&existingFriendship).Error

			if err == nil {
				existingFriendship.Status = domain.FriendshipStatusAccepted
				existingFriendship.UpdatedAt = time.Now()
				db.Save(&existingFriendship)
				fmt.Printf("Friendship verified: %s <-> %s\n", human.Username, friendUsername)
			} else {
				newFriendship := domain.Friendship{
					ID:          uuid.New().String(),
					RequesterID: human.ID,
					AddresseeID: friendUser.ID,
					Status:      domain.FriendshipStatusAccepted,
					CreatedAt:   time.Now(),
					UpdatedAt:   time.Now(),
				}
				if err := db.Create(&newFriendship).Error; err != nil {
					log.Printf("Failed to create friendship with %s: %v", friendUsername, err)
				} else {
					fmt.Printf("Friendship created: %s <-> %s\n", human.Username, friendUsername)
				}
			}
		}
	}

	// Randomize any users who currently have avatar 0
	var allUsers []domain.User
	db.Find(&allUsers)
	for _, usr := range allUsers {
		if usr.AvatarIndex == 0 {
			newAvatar := (int(crc32.ChecksumIEEE([]byte(usr.Username))) % 7) + 1
			db.Model(&domain.User{}).Where("id = ?", usr.ID).Update("avatar_index", newAvatar)
			fmt.Printf("Randomized avatar for user: %s -> %d\n", usr.Username, newAvatar)
		}
	}

	fmt.Println("=== Seeding & Friendship Setup Complete! ===")
}
