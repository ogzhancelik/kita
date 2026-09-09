package http

import (
	"github.com/gin-gonic/gin"
	"github.com/oguzhancelik/kita/internal/core/errors"
)

// ErrorResponse standardized JSON response structure for errors.
type ErrorResponsePayload struct {
	Code    errors.ErrorCode `json:"code"`
	Message string           `json:"message"`
}

// SendError formats and sends a standardized JSON error response.
func SendError(c *gin.Context, status int, code errors.ErrorCode, message string) {
	c.JSON(status, ErrorResponsePayload{
		Code:    code,
		Message: message,
	})
}
