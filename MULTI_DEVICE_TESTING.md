# Kita — Farklı Cihazlardan Lokal Test Rehberi (Multi-Device Testing Guide)

Bu rehber, bilgisayarınızda çalışan **Kita Backend** (`Go / Gin`) sunucusuna yerel ağınızdaki fiziksel telefonlar, tabletler veya başka bilgisayarlar üzerinden nasıl bağlanacağınızı adım adım açıklar.

---

## 📌 Genel Bakış & Ağ Parametreleri

Backend sunucusu tüm yerel ağ arayüzlerini dinleyecek şekilde (`0.0.0.0:8080`) çalışır.

- **Host (PC) Yerel Wi-Fi IP:** `192.168.1.42` *(Ağınıza göre değişebilir, aşağıda nasıl bulunacağı anlatılmıştır)*
- **Backend Portu:** `8080`
- **HTTP Health Check:** `http://192.168.1.42:8080/health`
- **WebSocket Endpoint:** `ws://192.168.1.42:8080/ws`

---

## 🔍 Adım 0: Bilgisayarınızın Yerel IP Adresini Öğrenme

IP adresiniz modeme yeniden bağlandığınızda değişebilir. Güncel IP'nizi öğrenmek için PowerShell'de:

```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -match 'Wi-Fi|Ethernet' } | Select-Object InterfaceAlias, IPAddress
```
veya klasik olarak:
```cmd
ipconfig
```
*(IPv4 Address / IPv4 Adresi kısmındaki değeri not edin, örn: `192.168.1.42`)*.

---


## 📶 Yöntem 2: Wi-Fi Üzerinden Bağlantı (Kablosuz Test)

Telefonunuz USB ile bağlı değilse veya aynı Wi-Fi ağındaki başka bir cihazdan (iPhone, Android, tablet, 2. bilgisayar) test etmek istiyorsanız bu yöntemi kullanın.

### 1. Aynı Wi-Fi Ağına Bağlanın
Test cihazı ile backend'in çalıştığı bilgisayarın **aynı Wi-Fi modemine** bağlı olduğundan emin olun.

### 2. Cihazdan Bağlantıyı Doğrulayın
Cihazınızın web tarayıcısını (Chrome, Safari vb.) açın ve şu adrese gidin:
```text
http://192.168.1.42:8080/health
```
Ekranda aşağıdaki JSON yanıtını görüyorsanız bağlantı başarılıdır:
```json
{"game":"kita","status":"healthy"}
```

### 3. Flutter Uygulamasını IP ile Çalıştırın
Frontend projesinde `ApiConstants` sınıfı `--dart-define=API_URL` parametresini destekler:

```powershell
cd c:\Code\kita\kita_frontend
flutter run -d <cihaz_id> --dart-define=API_URL=http://192.168.1.42:8080
```

Eğer APK derleyip cihaza yüklemek isterseniz:
```powershell
flutter build apk --dart-define=API_URL=http://192.168.1.42:8080
```

---

## 🛡️ Sorun Giderme (Troubleshooting)

### 1. Tarayıcıdan `http://192.168.1.42:8080/health` Açılmıyor / Zaman Aşımı (Timeout)
Windows Güvenlik Duvarı harici cihazlardan gelen istekleri engelliyor olabilir. 8080 portuna izin vermek için **Yönetici olarak açılmış PowerShell**'de şu komutu çalıştırın:

```powershell
netsh advfirewall firewall add rule name="Kita Backend 8080" dir=in action=allow protocol=TCP localport=8080
```

Kuralı kaldırmak isterseniz:
```powershell
netsh advfirewall firewall delete rule name="Kita Backend 8080"
```

### 2. Wi-Fi İzolasyonu (AP Isolation)
Bazı ev/ofis modemlerinde "Client Isolation" veya "AP Isolation" özelliği açık olabilir. Bu özellik Wi-Fi'a bağlı cihazların birbirleriyle konuşmasını engeller. Eğer ping atılamıyorsa modem arayüzünden bu ayarı kapatın veya **Yöntem 1 (USB / adb reverse)** kullanın.

### 3. Backend Çalışıyor mu?
Bilgisayarınızda terminalde:
```powershell
Invoke-RestMethod -Uri "http://localhost:8080/health"
```
çıktısı `healthy` vermelidir. Eğer vermiyorsa backend'i başlatın:
```powershell
cd c:\Code\kita\kita_backend
go run .\cmd\api\main.go
```
