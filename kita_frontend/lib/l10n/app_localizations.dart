import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Kita Fullstack'**
  String get appTitle;

  /// No description provided for @errValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Validation failed.'**
  String get errValidationFailed;

  /// No description provided for @errMissingField.
  ///
  /// In en, this message translates to:
  /// **'A required field is missing.'**
  String get errMissingField;

  /// No description provided for @errInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid format.'**
  String get errInvalidFormat;

  /// No description provided for @errUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized.'**
  String get errUnauthorized;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials.'**
  String get errInvalidCredentials;

  /// No description provided for @errTokenExpired.
  ///
  /// In en, this message translates to:
  /// **'Token has expired.'**
  String get errTokenExpired;

  /// No description provided for @errUserAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'User already exists.'**
  String get errUserAlreadyExists;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get errNotFound;

  /// No description provided for @errMatchNotFound.
  ///
  /// In en, this message translates to:
  /// **'Match not found.'**
  String get errMatchNotFound;

  /// No description provided for @errAlreadyInMatch.
  ///
  /// In en, this message translates to:
  /// **'You are already in an active match.'**
  String get errAlreadyInMatch;

  /// No description provided for @errAlreadyInQueue.
  ///
  /// In en, this message translates to:
  /// **'You are already in queue.'**
  String get errAlreadyInQueue;

  /// No description provided for @errInvalidMove.
  ///
  /// In en, this message translates to:
  /// **'Invalid move.'**
  String get errInvalidMove;

  /// No description provided for @errNotYourTurn.
  ///
  /// In en, this message translates to:
  /// **'It is not your turn.'**
  String get errNotYourTurn;

  /// No description provided for @errInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'Invalid message format.'**
  String get errInvalidMessage;

  /// No description provided for @errInternalServer.
  ///
  /// In en, this message translates to:
  /// **'Internal server error.'**
  String get errInternalServer;

  /// No description provided for @errUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'Unknown message type.'**
  String get errUnknownMessage;

  /// No description provided for @reasonNormal.
  ///
  /// In en, this message translates to:
  /// **'Game finished normally by rules.'**
  String get reasonNormal;

  /// No description provided for @reasonResigned.
  ///
  /// In en, this message translates to:
  /// **'Player resigned.'**
  String get reasonResigned;

  /// No description provided for @reasonDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Opponent disconnected.'**
  String get reasonDisconnected;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
