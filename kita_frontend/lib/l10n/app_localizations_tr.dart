// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Kita Fullstack';

  @override
  String get errValidationFailed => 'Doğrulama başarısız.';

  @override
  String get errMissingField => 'Gerekli bir alan eksik.';

  @override
  String get errInvalidFormat => 'Geçersiz format.';

  @override
  String get errUnauthorized => 'Yetkisiz erişim.';

  @override
  String get errInvalidCredentials => 'Geçersiz kimlik bilgileri.';

  @override
  String get errTokenExpired => 'Oturum süresi doldu.';

  @override
  String get errUserAlreadyExists => 'Kullanıcı zaten mevcut.';

  @override
  String get errNotFound => 'Bulunamadı.';

  @override
  String get errMatchNotFound => 'Maç bulunamadı.';

  @override
  String get errAlreadyInMatch => 'Zaten aktif bir maçtasınız.';

  @override
  String get errAlreadyInQueue => 'Zaten sıradasınız.';

  @override
  String get errInvalidMove => 'Geçersiz hamle.';

  @override
  String get errNotYourTurn => 'Sıra sizde değil.';

  @override
  String get errInvalidMessage => 'Geçersiz mesaj formatı.';

  @override
  String get errInternalServer => 'Sunucu hatası.';

  @override
  String get errUnknownMessage => 'Bilinmeyen mesaj tipi.';

  @override
  String get reasonNormal => 'Oyun kurallara uygun olarak sona erdi.';

  @override
  String get reasonResigned => 'Oyuncu çekildi.';

  @override
  String get reasonDisconnected => 'Rakip bağlantıyı kopardı.';
}
