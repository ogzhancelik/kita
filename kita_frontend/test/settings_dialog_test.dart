import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita_frontend/core/network/connectivity_service.dart';
import 'package:kita_frontend/core/storage/secure_storage_service.dart';
import 'package:kita_frontend/data/models/user_model.dart';
import 'package:kita_frontend/presentation/providers/auth_provider.dart';
import 'package:kita_frontend/presentation/providers/game_settings_provider.dart';
import 'package:kita_frontend/presentation/providers/theme_provider.dart';
import 'package:kita_frontend/presentation/widgets/home/settings_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockConnectivity extends ConnectivityService {
  @override
  Future<bool> hasInternet() async => false;

  @override
  Stream<bool> get onConnectivityChanged => const Stream<bool>.empty();
}

class MockStorage extends SecureStorageService {
  GuestProfile? guest;
  String? token;
  UserProfile? user;

  MockStorage({this.guest, this.token, this.user});

  @override
  Future<GuestProfile?> getGuestProfile() async => guest;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<UserProfile?> getUser() async => user;

  @override
  Future<void> saveToken(String token) async {}

  @override
  Future<void> saveUser(UserProfile user) async {}

  @override
  Future<void> saveGuestProfile(String nickname, int avatarIndex) async {}

  @override
  Future<void> deleteToken() async {}

  @override
  Future<void> deleteUser() async {}

  @override
  Future<void> deleteGuestProfile() async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget buildTestableWidget({
    required Widget child,
    required AuthProvider authProv,
  }) {
    return EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('tr')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      saveLocale: false,
      useOnlyLangCode: true,
      child: Builder(
        builder: (context) => MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(),
            ),
            ChangeNotifierProvider<AuthProvider>.value(
              value: authProv,
            ),
            ChangeNotifierProvider<GameSettingsProvider>(
              create: (_) => GameSettingsProvider(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
  }

  testWidgets('SettingsDialog shows How to Play before Logout and excludes About Kita', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final storage = MockStorage(
      user: const UserProfile(
        id: 'u-1',
        username: 'TestPlayer',
        rating: 1200,
        avatarIndex: 0,
      ),
      token: 'fake-token',
    );
    final connectivity = MockConnectivity();
    final authProv = AuthProvider(
      storage: storage,
      connectivity: connectivity,
    );
    await authProv.continueOffline();

    expect(authProv.isAuthenticated, isTrue);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const SettingsDialog(),
          authProv: authProv,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Verify "How to Play" is displayed
    expect(find.text('How to Play'), findsOneWidget);

    // Verify redundant "About Kita" and "Version 1.0.0" are NOT present
    expect(find.text('About Kita'), findsNothing);
    expect(find.text('Version 1.0.0'), findsNothing);

    // Verify "How to Play" is rendered above "Log Out"
    final howToPlayFinder = find.text('How to Play');
    final logoutFinder = find.text('Log Out');
    expect(howToPlayFinder, findsOneWidget);
    expect(logoutFinder, findsOneWidget);

    final howToPlayY = tester.getTopLeft(howToPlayFinder).dy;
    final logoutY = tester.getTopLeft(logoutFinder).dy;
    expect(howToPlayY, lessThan(logoutY));
  });

  testWidgets('SettingsDialog renders Quick Controls row with Theme, Sound, and Vibration and toggles state', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final storage = MockStorage(
      user: const UserProfile(
        id: 'u-1',
        username: 'TestPlayer',
        rating: 1200,
        avatarIndex: 0,
      ),
      token: 'fake-token',
    );
    final connectivity = MockConnectivity();
    final authProv = AuthProvider(
      storage: storage,
      connectivity: connectivity,
    );
    await authProv.continueOffline();

    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const SettingsDialog(),
          authProv: authProv,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Verify Quick Controls titles are present
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Sound'), findsOneWidget);
    expect(find.text('Vibration'), findsOneWidget);

    // Verify no redundant on/off/light/dark status text
    expect(find.text('Dark'), findsNothing);
    expect(find.text('Light'), findsNothing);
    expect(find.text('On'), findsNothing);
    expect(find.text('Off'), findsNothing);

    // Initial icon checks
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.vibration_rounded), findsOneWidget);

    // Toggle Theme
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

    // Toggle Sound
    await tester.tap(find.text('Sound'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

    // Toggle Vibration
    await tester.tap(find.text('Vibration'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.smartphone_rounded), findsOneWidget);
  });
}
