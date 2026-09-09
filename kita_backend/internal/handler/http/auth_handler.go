package http

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/oguzhancelik/kita/internal/core/errors"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"github.com/oguzhancelik/kita/internal/service"
)

type AuthHandler struct {
	authService ports.AuthService
	userService ports.UserService
}

func NewAuthHandler(authService ports.AuthService, userService ports.UserService) *AuthHandler {
	return &AuthHandler{
		authService: authService,
		userService: userService,
	}
}

type RegisterRequest struct {
	Username string `json:"username" binding:"required,min=3,max=30"`
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

type LoginRequest struct {
	UsernameOrEmail string `json:"username_or_email" binding:"required"`
	Password        string `json:"password" binding:"required"`
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		SendError(c, http.StatusBadRequest, errors.ErrValidationFailed, err.Error())
		return
	}

	user, token, err := h.authService.Register(c.Request.Context(), req.Username, req.Email, req.Password)
	if err != nil {
		if err == service.ErrUserAlreadyExists {
			SendError(c, http.StatusConflict, errors.ErrUserAlreadyExists, err.Error())
			return
		}
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	profile := user.ToProfile()
	c.JSON(http.StatusCreated, gin.H{
		"token": token,
		"user":  profile,
	})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		SendError(c, http.StatusBadRequest, errors.ErrValidationFailed, err.Error())
		return
	}

	user, token, err := h.authService.Login(c.Request.Context(), req.UsernameOrEmail, req.Password)
	if err != nil {
		if err == service.ErrInvalidCredentials {
			SendError(c, http.StatusUnauthorized, errors.ErrInvalidCredentials, err.Error())
			return
		}
		SendError(c, http.StatusInternalServerError, errors.ErrInternalServer, err.Error())
		return
	}

	profile := user.ToProfile()
	c.JSON(http.StatusOK, gin.H{
		"token": token,
		"user":  profile,
	})
}

func (h *AuthHandler) Me(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		SendError(c, http.StatusUnauthorized, errors.ErrUnauthorized, "Unauthorized")
		return
	}

	profile, err := h.userService.GetProfile(c.Request.Context(), userID.(string))
	if err != nil {
		SendError(c, http.StatusNotFound, errors.ErrNotFound, err.Error())
		return
	}

	c.JSON(http.StatusOK, profile)
}
