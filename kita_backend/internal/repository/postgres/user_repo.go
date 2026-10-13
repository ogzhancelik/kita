package postgres

import (
	"context"
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"gorm.io/gorm"
)

type userRepo struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) ports.UserRepository {
	return &userRepo{db: db}
}

func (r *userRepo) Create(ctx context.Context, user *domain.User) error {
	return r.db.WithContext(ctx).Create(user).Error
}

func (r *userRepo) FindByID(ctx context.Context, id string) (*domain.User, error) {
	if _, err := uuid.Parse(strings.TrimSpace(id)); err != nil {
		return nil, nil
	}
	var user domain.User
	if err := r.db.WithContext(ctx).First(&user, "id = ?", strings.TrimSpace(id)).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &user, nil
}

func (r *userRepo) FindByUsername(ctx context.Context, username string) (*domain.User, error) {
	var user domain.User
	if err := r.db.WithContext(ctx).First(&user, "LOWER(username) = LOWER(?)", username).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &user, nil
}

func (r *userRepo) FindByEmail(ctx context.Context, email string) (*domain.User, error) {
	var user domain.User
	if err := r.db.WithContext(ctx).First(&user, "email = ?", email).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &user, nil
}

func (r *userRepo) Update(ctx context.Context, user *domain.User) error {
	return r.db.WithContext(ctx).Save(user).Error
}

func (r *userRepo) Delete(ctx context.Context, id string) error {
	trimmedID := strings.TrimSpace(id)
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// Clean up friendships, notifications and settings while preserving matches and chat messages
		_ = tx.Where("requester_id = ? OR addressee_id = ?", trimmedID, trimmedID).Delete(&domain.Friendship{}).Error
		_ = tx.Where("user_id = ? OR actor_id = ?", trimmedID, trimmedID).Delete(&domain.Notification{}).Error
		_ = tx.Where("user_id = ?", trimmedID).Delete(&domain.UserSettings{}).Error
		// Delete the user record
		return tx.Where("id = ?", trimmedID).Delete(&domain.User{}).Error
	})
}

func (r *userRepo) GetLeaderboard(ctx context.Context, limit int, userIDs []string) ([]domain.User, error) {
	var users []domain.User
	query := r.db.WithContext(ctx)
	if len(userIDs) > 0 {
		query = query.Where("id IN ?", userIDs)
	}
	if err := query.Order("rating DESC, wins DESC").Limit(limit).Find(&users).Error; err != nil {
		return nil, err
	}
	return users, nil
}
