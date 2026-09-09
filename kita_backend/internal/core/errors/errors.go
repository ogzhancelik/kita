package errors

type ErrorCode string

const (
	// Validation
	ErrValidationFailed ErrorCode = "ERR_VALIDATION_FAILED"
	ErrMissingField     ErrorCode = "ERR_MISSING_FIELD"
	ErrInvalidFormat    ErrorCode = "ERR_INVALID_FORMAT"

	// Auth
	ErrUnauthorized        ErrorCode = "ERR_UNAUTHORIZED"
	ErrInvalidCredentials  ErrorCode = "ERR_INVALID_CREDENTIALS"
	ErrTokenExpired        ErrorCode = "ERR_TOKEN_EXPIRED"
	ErrUserAlreadyExists   ErrorCode = "ERR_USER_ALREADY_EXISTS"

	// Resource
	ErrNotFound ErrorCode = "ERR_NOT_FOUND"

	// Game / Match
	ErrMatchNotFound   ErrorCode = "ERR_MATCH_NOT_FOUND"
	ErrAlreadyInMatch  ErrorCode = "ERR_ALREADY_IN_MATCH"
	ErrAlreadyInQueue  ErrorCode = "ERR_ALREADY_IN_QUEUE"
	ErrInvalidMove     ErrorCode = "ERR_INVALID_MOVE"
	ErrNotYourTurn     ErrorCode = "ERR_NOT_YOUR_TURN"
	ErrInvalidMessage  ErrorCode = "ERR_INVALID_MESSAGE"

	// System
	ErrInternalServer ErrorCode = "ERR_INTERNAL_SERVER"
	ErrUnknownMessage ErrorCode = "ERR_UNKNOWN_MESSAGE"
)

// AppError is a custom error type that includes an ErrorCode.
type AppError struct {
	Code    ErrorCode
	Message string
}

func (e *AppError) Error() string {
	return e.Message
}

// New creates a new AppError
func New(code ErrorCode, message string) *AppError {
	return &AppError{
		Code:    code,
		Message: message,
	}
}
