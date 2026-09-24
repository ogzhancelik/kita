package http

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/oguzhancelik/kita/internal/core/domain"
)

type mockSettingsService struct {
	settings map[string]*domain.UserSettings
}

func newMockSettingsService() *mockSettingsService {
	return &mockSettingsService{
		settings: make(map[string]*domain.UserSettings),
	}
}

func (m *mockSettingsService) GetSettings(ctx context.Context, userID string) (*domain.UserSettings, error) {
	if s, ok := m.settings[userID]; ok {
		return s, nil
	}
	defaults := domain.DefaultSettings(userID)
	return &defaults, nil
}

func (m *mockSettingsService) UpdateSettings(ctx context.Context, userID string, dto *domain.UpdateSettingsDTO) (*domain.UserSettings, error) {
	if err := dto.Validate(); err != nil {
		return nil, err
	}
	s, ok := m.settings[userID]
	if !ok {
		defaults := domain.DefaultSettings(userID)
		s = &defaults
	}
	dto.ApplyTo(s)
	m.settings[userID] = s
	return s, nil
}

func (m *mockSettingsService) ResetSettings(ctx context.Context, userID string) (*domain.UserSettings, error) {
	defaults := domain.DefaultSettings(userID)
	m.settings[userID] = &defaults
	return &defaults, nil
}

func (m *mockSettingsService) GetDefaultSettings() domain.UserSettings {
	return domain.DefaultSettings("")
}

func setupTestRouter(svc *mockSettingsService) *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	handler := NewSettingsHandler(svc)

	// Auth simulation middleware
	authMiddleware := func(c *gin.Context) {
		uid := c.GetHeader("X-Test-User-ID")
		if uid != "" {
			c.Set("userID", uid)
		}
		c.Next()
	}

	api := r.Group("/api/settings")
	{
		api.GET("/defaults", handler.GetDefaults)
		api.GET("", authMiddleware, handler.GetSettings)
		api.PUT("", authMiddleware, handler.UpdateSettings)
		api.POST("/reset", authMiddleware, handler.ResetSettings)
	}

	return r
}

func TestSettingsHandler_GetDefaults(t *testing.T) {
	svc := newMockSettingsService()
	router := setupTestRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/settings/defaults", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d", w.Code)
	}

	var res domain.UserSettings
	if err := json.Unmarshal(w.Body.Bytes(), &res); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if res.BoardTheme != domain.DefaultBoardTheme {
		t.Errorf("expected %s, got %s", domain.DefaultBoardTheme, res.BoardTheme)
	}
}

func TestSettingsHandler_GetSettings_Auth(t *testing.T) {
	svc := newMockSettingsService()
	router := setupTestRouter(svc)

	// Unauthenticated
	req := httptest.NewRequest(http.MethodGet, "/api/settings", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 Unauthorized, got %d", w.Code)
	}

	// Authenticated
	reqAuth := httptest.NewRequest(http.MethodGet, "/api/settings", nil)
	reqAuth.Header.Set("X-Test-User-ID", "test-user-id")
	wAuth := httptest.NewRecorder()
	router.ServeHTTP(wAuth, reqAuth)

	if wAuth.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d", wAuth.Code)
	}

	var res domain.UserSettings
	if err := json.Unmarshal(wAuth.Body.Bytes(), &res); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if res.BoardTheme != domain.DefaultBoardTheme {
		t.Errorf("expected board_theme '%s', got %s", domain.DefaultBoardTheme, res.BoardTheme)
	}
}

func TestSettingsHandler_UpdateSettings(t *testing.T) {
	svc := newMockSettingsService()
	router := setupTestRouter(svc)

	theme := "ocean_azure"
	soundOff := false
	payload, _ := json.Marshal(domain.UpdateSettingsDTO{
		BoardTheme:   &theme,
		SoundEnabled: &soundOff,
	})

	req := httptest.NewRequest(http.MethodPut, "/api/settings", bytes.NewBuffer(payload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Test-User-ID", "test-user-id")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d. Body: %s", w.Code, w.Body.String())
	}

	var res domain.UserSettings
	if err := json.Unmarshal(w.Body.Bytes(), &res); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if res.BoardTheme != "ocean_azure" {
		t.Errorf("expected ocean_azure, got %s", res.BoardTheme)
	}
	if res.SoundEnabled != false {
		t.Errorf("expected soundEnabled false, got %v", res.SoundEnabled)
	}
}
