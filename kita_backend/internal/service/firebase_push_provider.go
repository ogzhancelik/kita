package service

import (
	"context"
	"fmt"
	"log"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type firebasePushProvider struct {
	client *messaging.Client
}

// NewFirebasePushProvider initializes a Firebase Cloud Messaging provider using a service account JSON file.
func NewFirebasePushProvider(credentialsPath string) (PushProvider, error) {
	ctx := context.Background()
	opt := option.WithCredentialsFile(credentialsPath)
	app, err := firebase.NewApp(ctx, nil, opt)
	if err != nil {
		return nil, fmt.Errorf("failed to init firebase app: %w", err)
	}

	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to init firebase messaging client: %w", err)
	}

	log.Printf("[FirebasePushProvider] Successfully connected with credentials: %s", credentialsPath)
	return &firebasePushProvider{client: client}, nil
}

func (p *firebasePushProvider) Send(ctx context.Context, tokens []string, title, body string, data map[string]string, tag string) ([]string, error) {
	if len(tokens) == 0 {
		return nil, nil
	}

	message := &messaging.MulticastMessage{
		Tokens: tokens,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
		Android: &messaging.AndroidConfig{
			Priority: "high", // Wakes up Android devices immediately from Doze mode
			Notification: &messaging.AndroidNotification{
				Tag: tag,
			},
		},
		APNS: &messaging.APNSConfig{
			Headers: map[string]string{
				"apns-priority": "10",
			},
		},
		Webpush: &messaging.WebpushConfig{
			Notification: &messaging.WebpushNotification{
				Title: title,
				Body:  body,
				Tag:   tag,
				Icon:  "/icons/Icon-192.png",
			},
		},
	}

	br, err := p.client.SendEachForMulticast(ctx, message)
	if err != nil {
		return nil, fmt.Errorf("failed to send multicast push: %w", err)
	}

	var unregisteredTokens []string
	for idx, resp := range br.Responses {
		if !resp.Success {
			if messaging.IsRegistrationTokenNotRegistered(resp.Error) || messaging.IsInvalidArgument(resp.Error) {
				unregisteredTokens = append(unregisteredTokens, tokens[idx])
			} else {
				log.Printf("[FirebasePushProvider] Delivery warning for token %s: %v", tokens[idx], resp.Error)
			}
		}
	}

	log.Printf("[FirebasePushProvider] %d/%d notifications sent successfully (%d invalid tokens detected)",
		br.SuccessCount, len(tokens), len(unregisteredTokens))
	return unregisteredTokens, nil
}
