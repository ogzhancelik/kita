package service

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrUserAlreadyExists = errors.New("username or email already in use")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrInvalidToken      = errors.New("invalid or expired token")
)

type authService struct {
	userRepo  ports.UserRepository
	jwtSecret []byte
}

func NewAuthService(userRepo ports.UserRepository) ports.AuthService {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "kita-secret-key-change-in-production-12345"
	}
	return &authService{
		userRepo:  userRepo,
		jwtSecret: []byte(secret),
	}
}

func (s *authService) Register(ctx context.Context, username, email, password string) (*domain.User, string, error) {
	username = strings.TrimSpace(username)
	email = strings.ToLower(strings.TrimSpace(email))

	if username == "" || email == "" || len(password) < 6 {
		return nil, "", errors.New("username, valid email, and password (min 6 chars) are required")
	}

	existingUser, _ := s.userRepo.FindByUsername(ctx, username)
	if existingUser != nil {
		return nil, "", ErrUserAlreadyExists
	}

	existingEmail, _ := s.userRepo.FindByEmail(ctx, email)
	if existingEmail != nil {
		return nil, "", ErrUserAlreadyExists
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, "", fmt.Errorf("failed to hash password: %w", err)
	}

	newUser := &domain.User{
		ID:           uuid.New().String(),
		Username:     username,
		Email:        email,
		PasswordHash: string(hash),
		Rating:       1200,
		Wins:         0,
		Losses:       0,
		Draws:        0,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if err := s.userRepo.Create(ctx, newUser); err != nil {
		return nil, "", fmt.Errorf("failed to create user: %w", err)
	}

	token, err := s.generateToken(newUser.ID, newUser.Username)
	if err != nil {
		return nil, "", err
	}

	return newUser, token, nil
}

func (s *authService) Login(ctx context.Context, usernameOrEmail, password string) (*domain.User, string, error) {
	usernameOrEmail = strings.TrimSpace(usernameOrEmail)

	var user *domain.User
	var err error

	if strings.Contains(usernameOrEmail, "@") {
		user, err = s.userRepo.FindByEmail(ctx, strings.ToLower(usernameOrEmail))
	} else {
		user, err = s.userRepo.FindByUsername(ctx, usernameOrEmail)
	}

	if err != nil || user == nil {
		return nil, "", ErrInvalidCredentials
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return nil, "", ErrInvalidCredentials
	}

	token, err := s.generateToken(user.ID, user.Username)
	if err != nil {
		return nil, "", err
	}

	return user, token, nil
}

func (s *authService) ValidateToken(tokenString string) (string, error) {
	token, err := jwt.Parse(tokenString, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return s.jwtSecret, nil
	})

	if err != nil || !token.Valid {
		return "", ErrInvalidToken
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", ErrInvalidToken
	}

	userID, ok := claims["sub"].(string)
	if !ok || userID == "" {
		return "", ErrInvalidToken
	}

	return userID, nil
}

func (s *authService) generateToken(userID, username string) (string, error) {
	claims := jwt.MapClaims{
		"sub":      userID,
		"username": username,
		"exp":      time.Now().Add(7 * 24 * time.Hour).Unix(),
		"iat":      time.Now().Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(s.jwtSecret)
}
