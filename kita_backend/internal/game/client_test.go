package game

import (
	"sync"
	"testing"
)

func TestClient_CloseIdempotencyAndConcurrentSend(t *testing.T) {
	client := &Client{
		Send:   make(chan []byte, 10),
		UserID: "test-user-1",
	}

	// 1. Concurrent sends and close
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func(val int) {
			defer wg.Done()
			client.SendJSON("test_type", map[string]int{"val": val})
		}(i)
	}

	wg.Add(1)
	go func() {
		defer wg.Done()
		client.Close()
	}()

	wg.Wait()

	if !client.IsClosed() {
		t.Fatal("Expected client to be marked as closed")
	}

	// 2. Calling Close() a second time must not panic
	client.Close()

	// 3. Sending on a closed client must not panic and must safely discard
	client.SendJSON("after_close", map[string]string{"status": "ok"})
}
