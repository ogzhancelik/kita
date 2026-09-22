# UI Overhaul Specification
Buradaki pek çok şey hali hazırda UI'da var, ve birkaç istisna dışında hepsinin Backend'i hazır. Bunu, sadece UI'ları güncellemek (ve gerekiyorsa yeni UI'lar eklemek) için yol haritası olarak kullanacaksın. Burada spesifik olarak belirtilmemiş UI'ları eklerken yine buradaki aynı dizayn dilini kullan.

## 0. Ana Palet
- **Karanlık Mod Arkaplan:** #
- **Aydınlık Mod Arkaplan:** #
- **Ana Renk:** #
- **Ana Renk 2:**
- **Accent Renk:** #
- **Accent Renk 2:** #
Temel renkler bunlar ve bunların tonları kullanılacak.

---

## 1. Ana Ekran (Landscape)
- **Sketch:** `docs/sketches/main_menu.png`
### Üst Panel
  - Sol üstte profil fotoğrafı, isim, ELO.
  - Sağ üstte Ayarlar butonu.
### Scrollable Orta Panel
  - Bir bildirim gelirse buranın en üstünde floating olarak çıkacak. Bu paneldeki elemanlar yukarıdan aşağı sırasıyla şöyle:
  - **Leaderboard**
    - Arkadaşlar ve Global olarak listelenebilir.
  - **Açık Odalar**
    - Ayrıca "Oda Kur" butonu.
  - **Arkadaşlar ve Quick Invitation**
  - **Maç Geçmişi Listesi**
### Aşağıdaki Floating Buttonlar
  - **Solda Home**
  - **Sağda Play**
    - Basıldığında açılan menu dialogda Oda kurma/katılma, AI ile oynama, Offline coop, Arkadaş davet etme, Matchmaking seçenekleri olacak. Matchmakingde oyuncu sayısı konusunda uyarı.

---

## 2. Tahta ve Hamleler
- Tahtanın etrafında sayılar yazmayacak (zaten tahtanın içinde yazıyor). Tahtanın çevresi boş olacak panele konulduğunda kenarlarına değebilecek.
- İlk sütunda karelerin sol atlında A B C D, son satırda karelerin sağ altında 1 2 3 4 5 6 7 yazacak.
- Hamleler "A2C3" formatında yazacak. Krallar için "Kral Simgesi + hamle" yazacak. 

---

## 3. Oyun Ekranı (Portrait/Default)
- **Sketch:** `docs/sketches/match.png`
### Layout & Elemanlar (Yukarıdan Aşağı):
- **Üst Panel**
  - Sol üst: Ayarlar
  - Orta: Total Zaman
- **Hamleler**
  - Maçtaki hamleler listesi. Horizontal scrollable ribbon.
- **Rakip Kullanıcı Bilgisi**
  - Solda profil fotoğrafı, ismi ve ELO. Sağda kalan zamanı
- **Tahta**
  - Tahtanın kenarları ekranın kenarına değecek.
- **Kullanıcı Bilgisi**
  - Sağda profil fotoğrafı, ismi ve ELO. Solda kalan zamanı
- **Chat**
  - Klavye açıldığında chat klavyeyle beraber yukarı kayacak. Diğer widgetlar yok olacak. Tahta ekrana sığması için küçülecek.
- **Alt Panel**
  - Solda maçtan çekilme vb. menü butonu.
  - Yanında chati tam boyutlu açma.
  - Sağda hamle ileri ve geri butonları.

---

## 4. Oyun Ekranı (Landscape)
- **Sketch:** `docs/sketches/match_landscape.png`
### Layout & Elemanlar:
  - **Hamleler**
    - Ekranın en üstünde, horizontal scrollable ribbon.
    - Sağında ve solunda ileri/geri butonları var.
  - **Tahta**: Ortada
  - **Kullanıcı Bilgileri**
    - Sağda ve solda. Solda rakip, sağda oyuncu.
    - Profil, isim, elo, kalan zaman.
  - **Diğer Butonlar**
    - Kullanıcı bilgilerinin hemen altında.
    - Solda (rakip oyuncunun altında) maçtan çekilme ve ayarlar vb. menü.
    - Sağda chati tam boyutlu açma.
  - **Total Süre**: Tahtanın altında
