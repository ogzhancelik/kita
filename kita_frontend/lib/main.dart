import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/feedback/sound_service.dart';
import 'core/feedback/toast_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/friends_provider.dart';
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
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => OnlineGameProvider()),
          ChangeNotifierProvider(create: (_) => FriendsProvider()),
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
  bool _isInviteDialogShowing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = context.read<OnlineGameProvider>();
    if (_onlineProv != prov) {
      _onlineProv?.incomingMatchRequest.removeListener(_onIncomingRequestChanged);
      _onlineProv = prov;
      _onlineProv?.incomingMatchRequest.addListener(_onIncomingRequestChanged);
    }
  }

  @override
  void dispose() {
    _onlineProv?.incomingMatchRequest.removeListener(_onIncomingRequestChanged);
    super.dispose();
  }

  void _onIncomingRequestChanged() {
    final req = _onlineProv?.incomingMatchRequest.value;
    if (req != null && !_isInviteDialogShowing) {
      // If rematch offer arrives while GameOverDialog is active on screen,
      // let GameOverDialog handle accept/decline internally without popping top dialog.
      if (req.type == IncomingMatchRequestType.rematch &&
          (_onlineProv?.isGameOverDialogActive.value ?? false)) {
        return;
      }

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
            _listenAndNavigateToMatch();
          },
          onDecline: () {
            _onlineProv?.declineIncomingRequest();
          },
        ).then((_) {
          _isInviteDialogShowing = false;
        });
      });
    }
  }

  void _listenAndNavigateToMatch() {
    void listener() {
      if (_onlineProv?.matchState.value == OnlineMatchState.inMatch) {
        _onlineProv?.matchState.removeListener(listener);
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const OnlineMatchScreen()),
        );
      }
    }

    _onlineProv?.matchState.addListener(listener);
    Timer(const Duration(seconds: 10), () {
      _onlineProv?.matchState.removeListener(listener);
    });
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
