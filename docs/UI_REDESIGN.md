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
  - Sol üstte profil fotoğrafı, isim, ELO. Bu üçünü barındıran container'ın üzerine tıklandığında kullanıcı profilinin tüm detaylarını içeren bir sayfa açılacak.

  - Sağ üstte Ayarlar butonu. Tıklandığında ayarlar sayfası açılacak. Ayarlar sayfasında yapılabilecek ayarlar profil ayarları, maç ayarları, hesap ayarları, tema ayarları, dil ayarları, bildirim ayarları gibi seçenekler olacak.

  - Ayarlar butonunun yanında oyundaki tüm bildirimleri (rematch isteği, friendship invitation, odaları daveti, vb.) barındıran bir bildirimler sayfası açacak buton olacak. Eper kullanıcının görmediği bildirimler varsa bildirim olduğunu belli eden bir şekilde değişecek butonun stili, iconlar kullanabilirsin.

  - Rematch ve arkadaş maç isteği için gönderilen ygulama içi bildirim yapısını (her sayfanın üzerinde çıkıyor ve belirli bir süre sonra kayboluyor) tüm bildirimler için ortak olacak şekilde kullan. Bildirime ihtiyacı olan durumlar şu anlık: Arkadaşlık isteği, maç daveti, rematch daveti olsa da ileride yeni çeşitler eklenecek o yüzden bildirimin içine yeni widgetlar koyulduğunda da bozulmayacak şekilde modüler olsun.

### Scrollable Orta Panel
  Bu paneldeki elemanlar yukarıdan aşağı sırasıyla şöyle:
  - **Leaderboard**
    - Arkadaşlar ve Global olarak listelenebilir.
    - TOP 3 olarak gözükecek arkadaş ve global toggle'ı olacak. Widget üzerine tıklandığında şu anki gibi tüm listeyi bulunduran sayfa açılacak. O sayfayı olduğu gibi bırakabilirsin renk düzenlemeleri hariç.
  - **Açık Odalar**
    - Şu anda açık olup oyuncu bekleyen odaların 5 tanesini listeleyecek alt alta. Odanın kurucusu ve oyunun türü ve başlangıç şekli minimal şekilde gösterilecek. Bu 5 odayı gösteren tile'a tıklandığında tüm online odaları listeleyen bir sayfa açılacak. Açık oda yoksa açık oda bulunamadı yazacak.
    - Ayrıca "Oda Kur" butonu. 
  - **Arkadaşlar ve Quick Invitation**
    - Arkadaşlar en son online oldukları vakte göre yakından uzağa şekilde yatay olarak listelenecek. Arkadaşların profil bilgilerinden oluşan minimal kartlar olacak. Her kartta o karttaki kullanıcıya doğrudan maç daveti atmak için bir buton olacak. Kaydırmalı olarak 10 arkadaşı gösterecek şekilde ayarla, 10 arkadaşın sonunda tüm arkadaşları görüntülemek için bir buton olup arkadaşlarım sayfasını açsın. 10 arkadaştan daha az arkadaşı varsa bu butona gerek yok.
  - **Maç Geçmişi Listesi**
    - Maç geçmişi en son oynanan maça göre listelenecek. Her maç için bir tile olacak. Tile'da maçın türü, sonucu, rakibin ismi veELO, maçın oynandığı tarih ve saat yazacak. Tile içerisinde maç tekrarını izlemeyi sağlayan bir buton olsun. Burası pagination olmak kaydıyla sonsuza kadar scollanabilsin ama bu alanın header'ına tıklandığında maç geçmişi için ayrı yapılan sayfaya yönlendirsin.
### Aşağıdaki Floating Buttonlar
  - **Solda Home**
  - **Sağda Play**
    - Basıldığında açılan menu dialogda Oda kurma/katılma, AI ile oynama, Offline coop, Arkadaş davet etme, Matchmaking seçenekleri olacak. Matchmakingde oyuncu sayısı konusunda uyarı. Her bir butona tıklandığında şu anki yapıda ona karşılık gelen sayfalar veya dialoglar açılsın.

---

## 2. Tahta ve Hamleler
- Tahtanın etrafında sayılar yazmayacak (zaten tahtanın içinde yazıyor). Tahtanın çevresi boş olacak panele konulduğunda kenarlarına değebilecek. Chess.com'daki dikey ekran kullanımda tahtanın eninin ekranın enine eşit olmasını istiyoruz. Her ekrana uygun olabilmesi için tahta boyutunu ekranın boyutuna göre hesaplaman gerekiyor.
- İlk sütunda karelerin sol atlında A B C D, son satırda karelerin sağ altında 1 2 3 4 5 6 7 yazacak. Karelerin sol üstünde karelerin değerini belirten 1, 2 ve 3'lerden oluşan sayılar olmaya devam edecek onları bozma. Karelerin dışında (yanında solunda üstünde altında) herhangi bir sayı yazmayacak, kareler ekrana sıfır olabilmeli.
- Hamleler "A2C3" formatında yazacak. Krallar için "Kral Simgesi + hamle" yazacak. 

---

## 3. Oyun Ekranı (Portrait/Default)
- **Sketch:** `docs/sketches/match.png`
### Layout & Elemanlar (Yukarıdan Aşağı):
- **Üst Panel**
  - Orta: Oyun içinde geçen toplam süre
- **Hamleler**
  - Maçtaki hamleler listesi. Horizontal scrollable ribbon. Şu anki yapıyı birebir koyabilirsin sadece renkleri güncelleyerek.
- **Rakip Kullanıcı Bilgisi**
  - Solda profil fotoğrafı, ismi ve ELO. Sağda kalan zamanı
- **Tahta**
  - Tahtanın kenarları ekranın kenarına değecek.
- **Kullanıcı Bilgisi**
  - Sağda profil fotoğrafı, ismi ve ELO. Solda kalan zamanı. Kullanıcı profil bilgilerine tıklandığında profillerini gösteren sayfa açılsın, maçın üstüne. Arkaplanda maç oynanmaya devam edecek.
- **Chat**
  - Klavye açıldığında chat klavyeyle beraber yukarı kayacak. Diğer widgetlar yok olacak. Tahta ekrana sığması için küçülecek.
- **Alt Panel**
  - Solda maçtan çekilme, berabere isteği, rakip kullanıcıyı şikayet etme özelliklerini içeren bir menü butonu olacak.
  - Yanında chati tam boyutlu açma için bir buton olacak. Varsayılan olarak chat tam boyutlu olacak dikey kullanımda. Bu butona basılıp kapandığı zaman ekranda kalan diğer dikey elementlerin arasındaki paddingler board tam ortada kalacak şekilde artılarak gösterilsin. Paddingleri manuel ayarlamaktansa columndaki hizalamaları ile aynayarak halledersen daha temiz olur. Ekranlarda taşma olmamasına ve her şeyin safe area içinde olmasına dikkat et.
  - Sağda hamle ileri ve geri butonları. Ribbon ile bu butonların state yönetimi ortak olsun. Buradan ileri geri yapıldığında ribbonda da hamleler ileri geri gidecek, Live'a gitme butonu gelecek vs.

---

## 4. Oyun Ekranı (Landscape)
- **Sketch:** `docs/sketches/match_landscape.png`
### Layout & Elemanlar:
  Landscape modunda tahta ekranın kenarlarına tamamen yaslanmayacak sketch'te olduğu gibi etrafına diğer elemanlar sığacak şekilde ortada bulunmalı. Tahtanın stili bunun dıoşında aynı kalacak. Aşağıdaki elemanların fonksiyonları harici belirtilmediği sürece portrait modundaki ile aynıdır. Landscape ve portrait arasındaki geçiş telefonun tutulma şekline göre işletim sistemi üzerinden otomatik takip edilecek uygulama içerisinden değiştirilmeyecek.
  - **Hamleler**
    - Ekranın en üstünde, horizontal scrollable ribbon.
    - Sağında ve solunda ileri/geri butonları var.
  - **Tahta**: Ortada
  - **Kullanıcı Bilgileri**
    - Sağda ve solda. Solda rakip, sağda oyuncu.
    - Profil, isim, elo, kalan zaman.
    - Yazılar horizontal kalacak taşma olmaması için taşacağı zaman ... koyarak devamını gizle
  - **Diğer Butonlar**
    - Kullanıcı bilgilerinin hemen altında.
    - Solda (rakip oyuncunun altında) maçtan çekilme ve ayarlar vb. menü.
    - Sağda chati tam boyutlu açma.
  - **Total Süre**: Tahtanın altında
