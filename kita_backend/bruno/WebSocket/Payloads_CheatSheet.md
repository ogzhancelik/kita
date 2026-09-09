# WebSocket Test Senaryoları ve JSON Payload'ları

Bruno'da WebSocket bağlantısı (`ws://localhost:8080/ws?token=...`) açıldıktan sonra **Message** sekmesine aşağıdaki JSON'ları yapıştırıp **Send** butonuna basarak sunucu ile konuşabilirsiniz.

---

### 1. Eşleşme Kuyruğuna Girme (Join Queue)
İki oyuncu da (Player 1 ve Player 2) bu mesajı gönderdiğinde sunucu otomatik olarak maçı başlatır.

```json
{
  "type": "join_queue"
}
```

**Sunucudan Gelen Yanıt (Örnek):**
```json
{
  "type": "match_found",
  "payload": {
    "match_id": "8f03c0b1-4f01-4475-8022-77eb8e473e1c",
    "your_team": "white",
    "opponent_id": "d04a6217-...",
    "opponent_name": "oyuncu2",
    "opponent_rating": 1200
  }
}
```
> **İpucu**: Dönen `match_id` değerini kopyalayıp Bruno'daki `matchId` değişkenine kaydedebilirsiniz!

---

### 2. Hamle Yapma (Make Move)
Sırası gelen oyuncu hamlesini gönderir. Tahta koordinatları: 4 satır (0..3) ve 7 sütun (0..6).

#### Beyaz Oyuncunun Hamlesi (Örnek: WP1'i (3,3)'ten (2,3)'e oynama):
```json
{
  "type": "make_move",
  "payload": {
    "piece_id": "WP1",
    "from_col": 3,
    "from_row": 3,
    "to_col": 2,
    "to_row": 3
  }
}
```

#### Siyah Oyuncunun Hamlesi (Örnek: BP1'i (3,0)'dan (3,1)'e oynama):
```json
{
  "type": "make_move",
  "payload": {
    "piece_id": "BP1",
    "from_col": 3,
    "from_row": 0,
    "to_col": 3,
    "to_row": 1
  }
}
```

**Sunucudan Gelen Yanıt:**
Her başarılı hamlede sunucu güncel tahta durumunu, kalan yasal hamleleri (`legal_moves`) ve ASCII çizimini fırlatır:
```json
{
  "type": "game_state",
  "payload": {
    "match_id": "...",
    "turn": "black",
    "status": "ongoing",
    "move_count": 1,
    "legal_moves": [ ... ],
    "display_board": "..."
  }
}
```

---

### 3. Oyun İçi Sohbet (Chat)
```json
{
  "type": "chat_message",
  "payload": {
    "content": "İyi şanslar dilerim!"
  }
}
```

**Sunucudan Gelen Yanıt:**
```json
{
  "type": "chat_broadcast",
  "payload": {
    "sender_id": "...",
    "username": "oyuncu1",
    "content": "İyi şanslar dilerim!",
    "created_at": "2026-09-09T09:40:00Z"
  }
}
```

---

### 4. Maçtan Çekilme / Terk Etme (Resign)
Oyunculardan biri terk ettiğinde maç sonlanır ve tek transaction ile veritabanına tüm hamleler yazılır:
```json
{
  "type": "resign"
}
```

**Sunucudan Gelen Yanıt:**
```json
{
  "type": "game_over",
  "payload": {
    "match_id": "...",
    "winner_id": "...",
    "result": "resigned",
    "reason": "Player resigned"
  }
}
```
---

### 5. Kuyruktan Çıkma (Leave Queue)
Eğer henüz eşleşme bulunmadıysa kuyruktan çıkmak için:
```json
{
  "type": "leave_queue"
}
```
