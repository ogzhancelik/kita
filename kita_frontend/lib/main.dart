import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/feedback/sound_service.dart';
import 'core/feedback/toast_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/friends_provider.dart';
import 'presentation/providers/game_settings_provider.dart';
import 'presentation/providers/notification_provider.dart';
import 'presentation/providers/online_game_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'dart:async';

import 'data/models/ws_message_models.dart';
import 'presentation/screens/game/online_match_screen.dart';
import 'presentation/screens/splash_gate_screen.dart';
import 'presentation/widgets/matchmaking/top_match_invite_banner.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  SoundService.instance.initialize(); // fire-and-forget pre-warm

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('tr')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      useOnlyLangCode: true,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => GameSettingsProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => OnlineGameProvider()),
          ChangeNotifierProvider(create: (_) => FriendsProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: const KitaApp(),
      ),
    ),
  );
}

class KitaApp extends StatefulWidget {
  const KitaApp({super.key});

  @override
  State<KitaApp> createState() => _KitaAppState();
}

class _KitaAppState extends State<KitaApp> {
  OnlineGameProvider? _onlineProv;
  FriendsProvider? _friendsProv;
  bool _isInviteDialogShowing = false;
  bool _isMatchScreenOpen = false;
  Timer? _friendsPollTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final online = context.read<OnlineGameProvider>();
    if (_onlineProv != online) {
      _onlineProv?.incomingMatchRequest.removeListener(_onIncomingRequestChanged);
      _onlineProv?.onWsNotificationEvent.removeListener(_onWsNotificationEvent);
      _onlineProv?.matchState.removeListener(_onMatchStateChanged);
      _onlineProv = online;
      _onlineProv?.incomingMatchRequest.addListener(_onIncomingRequestChanged);
      _onlineProv?.onWsNotificationEvent.addListener(_onWsNotificationEvent);
      _onlineProv?.matchState.addListener(_onMatchStateChanged);
    }

    final friends = context.read<FriendsProvider>();
    if (_friendsProv != friends) {
      _friendsProv?.removeListener(_onFriendsChanged);
      _friendsProv = friends;
      _friendsProv?.addListener(_onFriendsChanged);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().loadNotifications();
      }
    });

    _friendsPollTimer?.cancel();
    _friendsPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _friendsProv?.loadAll();
        context.read<NotificationProvider>().loadNotifications();
      }
    });
  }

  @override
  void dispose() {
    _onlineProv?.incomingMatchRequest.removeListener(_onIncomingRequestChanged);
    _onlineProv?.onWsNotificationEvent.removeListener(_onWsNotificationEvent);
    _onlineProv?.matchState.removeListener(_onMatchStateChanged);
    _friendsProv?.removeListener(_onFriendsChanged);
    _friendsPollTimer?.cancel();
    super.dispose();
  }

  void _onFriendsChanged() {
    final incoming = _friendsProv?.incomingRequests;
    if (incoming != null && incoming.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<NotificationProvider>().syncFromFriendRequests(incoming);
        }
      });
    }
  }

  void _onWsNotificationEvent() {
    final event = _onlineProv?.onWsNotificationEvent.value;
    if (event == null || !mounted) return;

    final type = event['type'] as String?;
    final notifProv = context.read<NotificationProvider>();

    if (type == 'rematch_declined') {
      notifProv.addRematchDeclinedNotification(event['decliner'] as String?);
    } else if (type == 'invitation_declined') {
      notifProv.addChallengeDeclinedNotification(event['decliner'] as String?);
    } else if (type == 'friend_request') {
      final payload = event['payload'] as Map<String, dynamic>?;
      if (payload != null) {
        notifProv.syncFromWsFriendRequest(payload);
        _friendsProv?.loadAll();
      }
    } else if (type == 'friend_request_declined') {
      notifProv.addFriendRequestDeclinedNotification(event['decliner'] as String?);
      _friendsProv?.loadAll();
    } else if (type == 'friend_request_accepted') {
      notifProv.addFriendRequestAcceptedNotification(event['accepter'] as String?);
      _friendsProv?.loadAll();
    } else if (type == 'invitation_cancelled') {
      final inviteId = event['invite_id'] as String?;
      final inviterId = event['inviter_id'] as String?;
      notifProv.removeOrExpireChallenge(inviteId: inviteId, inviterId: inviterId);
    }
  }

  void _onMatchStateChanged() {
    if (_onlineProv?.matchState.value == OnlineMatchState.inMatch && !_isMatchScreenOpen) {
      if (_onlineProv?.isReconnectedMatch.value == true) {
        // Player reconnected to an existing match on startup; stay on dashboard to let user Rejoin via card
        return;
      }
      _isMatchScreenOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => const OnlineMatchScreen(),
            settings: const RouteSettings(name: '/online_match'),
          ),
        ).then((_) {
          _isMatchScreenOpen = false;
        });
      });
    }
  }

  void _onIncomingRequestChanged() {
    final req = _onlineProv?.incomingMatchRequest.value;
    if (req != null) {
      if (mounted) {
        context.read<NotificationProvider>().syncFromIncomingMatchRequest(req);
      }

      // Do NOT show floating dialog on home dashboard screen.
      // Only show it when user is navigated away to a subscreen (canPop == true).
      final isSubScreenActive = appNavigatorKey.currentState?.canPop() ?? false;
      if (!isSubScreenActive) {
        return;
      }

      // If rematch offer arrives while GameOverDialog is active on screen,
      // let GameOverDialog handle accept/decline internally without popping top dialog.
      if (req.type == IncomingMatchRequestType.rematch &&
          (_onlineProv?.isGameOverDialogActive.value ?? false)) {
        return;
      }

      if (!_isInviteDialogShowing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _isInviteDialogShowing) return;
          final navContext = appNavigatorKey.currentContext;
          if (navContext == null) return;

          _isInviteDialogShowing = true;
          TopMatchInviteDialog.show(
            context: navContext,
            request: req,
            onAccept: () {
              _onlineProv?.acceptIncomingRequest();
            },
            onDecline: () {
              _onlineProv?.declineIncomingRequest();
            },
          ).then((_) {
            _isInviteDialogShowing = false;
          });
        });
      }
    } else {
      if (_isInviteDialogShowing) {
        final navContext = appNavigatorKey.currentContext;
        if (navContext != null && Navigator.of(navContext, rootNavigator: true).canPop()) {
          Navigator.of(navContext, rootNavigator: true).pop();
        }
        _isInviteDialogShowing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Kita Fullstack',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: KitaToast.messengerKey,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashGateScreen(),
    );
  }
}
