import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita_frontend/data/models/friend_models.dart';
import 'package:kita_frontend/data/models/user_model.dart';
import 'package:kita_frontend/data/services/friend_api_service.dart';
import 'package:kita_frontend/presentation/providers/auth_provider.dart';
import 'package:kita_frontend/presentation/providers/friends_provider.dart';
import 'package:kita_frontend/presentation/widgets/friends/player_search_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSearchFriendApiService extends FriendApiService {
  List<PlayerSearchResultModel> mockSearchResults = [];
  bool searchCalled = false;
  String? lastSearchQuery;
  bool sendRequestCalled = false;
  String? lastRequestedUsername;

  @override
  Future<List<FriendItemModel>> getFriends() async => [];

  @override
  Future<List<FriendItemModel>> getPendingRequests() async => [];

  @override
  Future<List<PlayerSearchResultModel>> searchPlayers(String query, [int limit = 20]) async {
    searchCalled = true;
    lastSearchQuery = query;
    return mockSearchResults
        .where((p) => p.username.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Future<void> sendFriendRequest(String username) async {
    sendRequestCalled = true;
    lastRequestedUsername = username;
  }
}

class FakeSearchAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isAuthenticated => true;

  @override
  bool get isGuest => false;

  @override
  UserProfile? get currentUser => const UserProfile(
        id: 'user_searcher_1',
        username: 'SearcherUser',
        rating: 1500,
        avatarIndex: 0,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget buildSearchTestWidget({
    required Widget child,
    required FriendsProvider friendsProv,
    required FakeSearchAuthProvider authProv,
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
            ChangeNotifierProvider<FriendsProvider>.value(value: friendsProv),
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
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

  group('Global Player Search & Friend Requests', () {
    testWidgets('Displays initial search prompt when query is empty', (tester) async {
      final mockApi = MockSearchFriendApiService();
      final friendsProv = FriendsProvider(mockApi);
      final authProv = FakeSearchAuthProvider();

      await tester.runAsync(() async {
        await tester.pumpWidget(
          buildSearchTestWidget(
            child: const PlayerSearchView(isModal: false),
            friendsProv: friendsProv,
            authProv: authProv,
          ),
        );
        await tester.pumpAndSettle();
      });

      expect(find.byIcon(Icons.person_search_rounded), findsOneWidget);
      expect(find.text('Find Players'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Shows no players found when search query yields 0 results', (tester) async {
      final mockApi = MockSearchFriendApiService();
      mockApi.mockSearchResults = [];
      final friendsProv = FriendsProvider(mockApi);
      final authProv = FakeSearchAuthProvider();

      await tester.runAsync(() async {
        await tester.pumpWidget(
          buildSearchTestWidget(
            child: const PlayerSearchView(isModal: false),
            friendsProv: friendsProv,
            authProv: authProv,
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'UnknownPlayer404');
        await Future.delayed(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
      });

      expect(mockApi.searchCalled, isTrue);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      expect(find.text('No players found'), findsOneWidget);
    });

    testWidgets('Renders player tiles and sends friend request with inline button', (tester) async {
      final mockApi = MockSearchFriendApiService();
      mockApi.mockSearchResults = [
        const PlayerSearchResultModel(
          id: 'p1',
          username: 'ValkyrieQueen',
          avatarIndex: 3,
          rating: 1720,
          wins: 45,
          losses: 12,
          friendshipStatus: 'none',
        ),
        const PlayerSearchResultModel(
          id: 'p2',
          username: 'AlreadyFriendBob',
          avatarIndex: 1,
          rating: 1540,
          wins: 10,
          losses: 8,
          friendshipStatus: 'friend',
        ),
      ];
      final friendsProv = FriendsProvider(mockApi);
      final authProv = FakeSearchAuthProvider();

      await tester.runAsync(() async {
        await tester.pumpWidget(
          buildSearchTestWidget(
            child: const PlayerSearchView(isModal: false),
            friendsProv: friendsProv,
            authProv: authProv,
          ),
        );
        await tester.pumpAndSettle();

        // Search for 'Valkyrie'
        await tester.enterText(find.byType(TextField), 'Valkyrie');
        await Future.delayed(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
      });

      expect(find.text('ValkyrieQueen'), findsOneWidget);
      expect(find.text('1720'), findsOneWidget);
      expect(find.text('Add Friend'), findsOneWidget);

      await tester.runAsync(() async {
        // Tap Add Friend on ValkyrieQueen tile
        await tester.tap(find.text('Add Friend'));
        await tester.pumpAndSettle();
      });

      expect(mockApi.sendRequestCalled, isTrue);
      expect(mockApi.lastRequestedUsername, 'ValkyrieQueen');
      // Status changes to Requested
      expect(find.text('Requested'), findsOneWidget);
    });
  });
}
