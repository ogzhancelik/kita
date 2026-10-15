package service

import (
	"bufio"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"
)

const defaultFallbackReserved = `
admin
guest
system
kita
bot
moderator
support
report
`

var (
	reservedMu           sync.RWMutex
	reservedUsernamesMap map[string]struct{}
	lastLoadedModTime    time.Time
	activeConfigPath     string
	usernameRegex        = regexp.MustCompile(`^[a-zA-Z0-9_-]{2,15}$`)
)

func findConfigFilePath() (string, time.Time, error) {
	paths := []string{
		"configs/reserved_usernames.txt",
		"../configs/reserved_usernames.txt",
		"../../configs/reserved_usernames.txt",
	}
	for _, p := range paths {
		if fi, err := os.Stat(p); err == nil {
			return p, fi.ModTime(), nil
		}
	}
	return "", time.Time{}, os.ErrNotExist
}

// reloadIfNeeded checks if configs/reserved_usernames.txt has been modified since last load
func reloadIfNeeded() {
	filePath, modTime, err := findConfigFilePath()

	reservedMu.RLock()
	if reservedUsernamesMap != nil && (err != nil || (filePath == activeConfigPath && modTime.Equal(lastLoadedModTime))) {
		reservedMu.RUnlock()
		return
	}
	reservedMu.RUnlock()

	reservedMu.Lock()
	defer reservedMu.Unlock()

	// Double check under write lock
	if reservedUsernamesMap != nil && (err != nil || (filePath == activeConfigPath && modTime.Equal(lastLoadedModTime))) {
		return
	}

	m := make(map[string]struct{})
	var content string

	if err == nil {
		if data, readErr := os.ReadFile(filePath); readErr == nil {
			content = string(data)
			activeConfigPath = filePath
			lastLoadedModTime = modTime
		}
	}

	if content == "" {
		content = defaultFallbackReserved
	}

	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		m[strings.ToLower(line)] = struct{}{}
	}

	reservedUsernamesMap = m
}

// IsReservedUsername returns true if the username matches any reserved system keyword.
// Automatically reloads on the fly whenever configs/reserved_usernames.txt is updated.
func IsReservedUsername(username string) bool {
	reloadIfNeeded()

	reservedMu.RLock()
	defer reservedMu.RUnlock()

	_, exists := reservedUsernamesMap[strings.ToLower(strings.TrimSpace(username))]
	return exists
}

// GetReservedUsernames returns the list of all currently active reserved usernames.
func GetReservedUsernames() []string {
	reloadIfNeeded()

	reservedMu.RLock()
	defer reservedMu.RUnlock()

	list := make([]string, 0, len(reservedUsernamesMap))
	for name := range reservedUsernamesMap {
		list = append(list, name)
	}
	return list
}

// ValidateUsername validates that the username satisfies:
// - Length between 2 and 15 characters
// - Contains only a-z, A-Z, 0-9, _, -
// - Contains no whitespace
// - Is not a reserved word
func ValidateUsername(username string) error {
	if !usernameRegex.MatchString(username) {
		return ErrInvalidUsername
	}
	if IsReservedUsername(username) {
		return ErrUsernameReserved
	}
	return nil
}
