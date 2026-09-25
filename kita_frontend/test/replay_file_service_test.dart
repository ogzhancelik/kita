import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita_frontend/data/models/match_model.dart';
import 'package:kita_frontend/data/services/replay_file_service.dart';
import 'package:kita_frontend/presentation/providers/auth_provider.dart';
import 'package:kita_frontend/presentation/providers/game_settings_provider.dart';
import 'package:kita_frontend/presentation/providers/theme_provider.dart';
import 'package:kita_frontend/presentation/screens/game/match_replay_screen.dart';
import 'package:kita_frontend/presentation/screens/home/match_history_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReplayFileService Unit Tests', () {
    test('serializeReplay creates valid Kita replay JSON envelope', () {
      final sample = MatchRecordModel.sampleDemoMatch();
      final jsonString = ReplayFileService.instance.serializeReplay(sample);

      expect(jsonString, isNotEmpty);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['format'], 'kita_replay');
      expect(decoded['version'], 1);
      expect(decoded['match'], isNotNull);

      final matchData = decoded['match'] as Map<String, dynamic>;
      expect(matchData['id'], sample.id);
      expect(matchData['white_player_id'], sample.whitePlayerId);
      expect(matchData['moves'], isNotEmpty);
      expect((matchData['moves'] as List).length, 8);
    });

    test('parseReplayJson successfully deserializes wrapped replay JSON', () {
      final sample = MatchRecordModel.sampleDemoMatch();
      final jsonString = ReplayFileService.instance.serializeReplay(sample);

      final parsed = ReplayFileService.instance.parseReplayJson(jsonString);
      expect(parsed.id, sample.id);
      expect(parsed.whitePlayer?.username, sample.whitePlayer?.username);
      expect(parsed.blackPlayer?.username, sample.blackPlayer?.username);
      expect(parsed.moves.length, sample.moves.length);
      expect(parsed.moves.first.piece, sample.moves.first.piece);
      expect(parsed.moves.last.toCol, sample.moves.last.toCol);
    });

    test('parseReplayJson successfully deserializes raw MatchRecordModel JSON', () {
      final sample = MatchRecordModel.sampleDemoMatch();
      final rawJson = jsonEncode(sample.toJson());

      final parsed = ReplayFileService.instance.parseReplayJson(rawJson);
      expect(parsed.id, sample.id);
      expect(parsed.moves.length, sample.moves.length);
      expect(parsed.whitePlayerId, sample.whitePlayerId);
    });

    test('parseReplayJson throws FormatException on empty or corrupted data', () {
      expect(
        () => ReplayFileService.instance.parseReplayJson(''),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => ReplayFileService.instance.parseReplayJson('{"hello": "world"}'),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => ReplayFileService.instance.parseReplayJson('not a json at all'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Replay UI Integration Tests', () {
    testWidgets('MatchReplayScreen info button opens dialog with Download Replay button',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final sampleMatch = MatchRecordModel.sampleDemoMatch();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<GameSettingsProvider>(create: (_) => GameSettingsProvider()),
          ],
          child: MaterialApp(
            home: MatchReplayScreen(match: sampleMatch),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find info button in top bar
      final infoButton = find.byIcon(Icons.info_outline_rounded);
      expect(infoButton, findsOneWidget);

      // Tap info button to open dialog
      await tester.tap(infoButton);
      await tester.pumpAndSettle();

      // Verify AlertDialog is displayed with Download Replay button
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.text('replay.downloadReplay'), findsOneWidget);
    });

    testWidgets('MatchHistoryScreen app bar contains Load Replay button',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<GameSettingsProvider>(create: (_) => GameSettingsProvider()),
          ],
          child: const MaterialApp(
            home: MatchHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Load Replay action button in top bar
      expect(find.byIcon(Icons.file_open_rounded), findsOneWidget);
    });
  });
}
