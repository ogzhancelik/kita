package service

import (
	"context"
	"log"
)

// PushProvider defines the transport contract for delivering push notifications to devices.
// It returns a list of unregistered/invalid tokens so callers can prune them.
type PushProvider interface {
	Send(ctx context.Context, tokens []string, title, body string, data map[string]string, tag string) (unregisteredTokens []string, err error)
}

// NoOpPushProvider is a fallback provider when no external push credentials (e.g. Firebase) are configured.
type NoOpPushProvider struct{}

func NewNoOpPushProvider() PushProvider {
	return &NoOpPushProvider{}
}

func (p *NoOpPushProvider) Send(ctx context.Context, tokens []string, title, body string, data map[string]string, tag string) ([]string, error) {
	log.Printf("[PushProvider:NoOp] Simulating push to %d device(s) | Title: %q | Tag: %q | Data: %v", len(tokens), title, tag, data)
	return nil, nil
}
