// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kita Fullstack';

  @override
  String get errValidationFailed => 'Validation failed.';

  @override
  String get errMissingField => 'A required field is missing.';

  @override
  String get errInvalidFormat => 'Invalid format.';

  @override
  String get errUnauthorized => 'Unauthorized.';

  @override
  String get errInvalidCredentials => 'Invalid credentials.';

  @override
  String get errTokenExpired => 'Token has expired.';

  @override
  String get errUserAlreadyExists => 'User already exists.';

  @override
  String get errNotFound => 'Not found.';

  @override
  String get errMatchNotFound => 'Match not found.';

  @override
  String get errAlreadyInMatch => 'You are already in an active match.';

  @override
  String get errAlreadyInQueue => 'You are already in queue.';

  @override
  String get errInvalidMove => 'Invalid move.';

  @override
  String get errNotYourTurn => 'It is not your turn.';

  @override
  String get errInvalidMessage => 'Invalid message format.';

  @override
  String get errInternalServer => 'Internal server error.';

  @override
  String get errUnknownMessage => 'Unknown message type.';

  @override
  String get reasonNormal => 'Game finished normally by rules.';

  @override
  String get reasonResigned => 'Player resigned.';

  @override
  String get reasonDisconnected => 'Opponent disconnected.';
}
