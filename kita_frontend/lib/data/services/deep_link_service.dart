import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../main.dart';
import '../../presentation/screens/game/match_replay_screen.dart';
import '../models/match_model.dart';
import 'replay_file_service.dart';

/// Centralized service managing universal deep links, custom schemes (`kita://`),
/// and `.kita` file associations across all supported platforms.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const MethodChannel _nativeChannel =
      MethodChannel('com.example.kita_frontend/content_resolver');

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  bool _isInitialized = false;

  /// Initializes deep link listeners and processes the cold-start initial URI.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Listen for incoming links while the app is running in background or foreground
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('[DeepLinkService] Received URI stream: $uri');
        handleUri(uri);
      },
      onError: (err) {
        debugPrint('[DeepLinkService] Stream error: $err');
      },
    );

    // 2. Check for cold-start initial link (when opened from a terminated state)
    try {
      Uri? initialUri = await _appLinks.getInitialLink();
      // On Android, if app_links didn't capture the initial intent (e.g. content:// from file manager),
      // fallback to querying the native MainActivity intent data.
      if (initialUri == null && !kIsWeb && Platform.isAndroid) {
        final nativeUriStr = await _getNativeInitialUri();
        if (nativeUriStr != null && nativeUriStr.isNotEmpty) {
          initialUri = Uri.tryParse(nativeUriStr);
        }
      }

      if (initialUri != null) {
        debugPrint('[DeepLinkService] Cold start initial URI: $initialUri');
        handleUri(initialUri);
      } else if (kIsWeb) {
        _checkWebUrl();
      }
    } catch (e) {
      debugPrint('[DeepLinkService] Failed to get initial link: $e');
    }
  }

  /// Calls native MainActivity to read the content of an Android content:// URI.
  Future<String?> _readContentUri(String uriStr) async {
    try {
      if (!Platform.isAndroid) return null;
      final String? content = await _nativeChannel.invokeMethod<String>(
        'readContentUri',
        {'uri': uriStr},
      );
      return content;
    } catch (e) {
      debugPrint('[DeepLinkService] Native readContentUri error: $e');
      return null;
    }
  }

  /// Queries native MainActivity for any cold-start intent URI.
  Future<String?> _getNativeInitialUri() async {
    try {
      if (!Platform.isAndroid) return null;
      final String? uri = await _nativeChannel.invokeMethod<String>('getInitialUri');
      return uri;
    } catch (e) {
      debugPrint('[DeepLinkService] Native getInitialUri error: $e');
      return null;
    }
  }

  /// Checks the current web browser URL hash or path on initial load.
  void _checkWebUrl() {
    if (!kIsWeb) return;
    try {
      final base = Uri.base;
      if (base.fragment.isNotEmpty) {
        final frag = base.fragment.startsWith('/') ? base.fragment : '/${base.fragment}';
        final fragUri = Uri.tryParse(frag);
        if (fragUri != null) {
          handleUri(fragUri);
          return;
        }
      }
      if (base.pathSegments.isNotEmpty) {
        handleUri(base);
      }
    } catch (e) {
      debugPrint('[DeepLinkService] Error checking web URL: $e');
    }
  }

  /// Parses and routes any supported URI.
  Future<void> handleUri(Uri uri) async {
    final uriStr = uri.toString();
    debugPrint('[DeepLinkService] Handling URI: $uriStr');

    // Case 1: Direct .kita file opening (File Association)
    if (uri.scheme == 'file' ||
        uri.scheme == 'content' ||
        uriStr.toLowerCase().endsWith('.kita') ||
        uri.path.toLowerCase().endsWith('.kita')) {
      await _handleReplayFileUri(uri);
      return;
    }

    // Case 2: Custom URL scheme: kita://replay/:id
    if (uri.scheme == 'kita') {
      final host = uri.host.toLowerCase();
      // Format A: kita://replay/0A34B219 -> host is 'replay', pathSegments contains '0A34B219'
      if (host == 'replay') {
        final id = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first
            : uri.path.replaceAll('/', '');
        if (id.isNotEmpty) {
          _navigateToReplay(id);
          return;
        }
      }
      // Format B: kita:///replay/0A34B219 -> host is empty, pathSegments has ['replay', '0A34B219']
      if (uri.pathSegments.contains('replay')) {
        final idx = uri.pathSegments.indexOf('replay');
        if (idx + 1 < uri.pathSegments.length) {
          final id = uri.pathSegments[idx + 1];
          if (id.isNotEmpty) {
            _navigateToReplay(id);
            return;
          }
        }
      }
    }

    // Case 3: Universal / Web links: https://kita.app/replay/:id
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final segments = uri.pathSegments;
      final replayIdx = segments.indexOf('replay');
      if (replayIdx != -1 && replayIdx + 1 < segments.length) {
        final id = segments[replayIdx + 1];
        if (id.isNotEmpty) {
          _navigateToReplay(id);
          return;
        }
      }
    }
  }

  /// Reads and opens a `.kita` replay file from a file/content URI.
  Future<void> _handleReplayFileUri(Uri uri) async {
    try {
      if (kIsWeb) return;

      String? content;
      if (uri.scheme == 'content') {
        content = await _readContentUri(uri.toString());
      } else if (uri.scheme == 'file') {
        try {
          final file = File(uri.toFilePath());
          if (await file.exists()) {
            content = await file.readAsString();
          }
        } catch (e) {
          debugPrint('[DeepLinkService] Direct file read failed: $e');
        }
        if (content == null && Platform.isAndroid) {
          content = await _readContentUri(uri.toString());
        }
      } else {
        // Generic scheme or raw path
        try {
          final file = File(uri.toFilePath());
          if (await file.exists()) {
            content = await file.readAsString();
          }
        } catch (_) {
          if (Platform.isAndroid) {
            content = await _readContentUri(uri.toString());
          }
        }
      }

      if (content != null && content.isNotEmpty) {
        final match = ReplayFileService.instance.parseReplayJson(content);
        _navigateToReplayModel(match);
      } else {
        debugPrint('[DeepLinkService] Replay file content is empty or unreadable.');
      }
    } catch (e) {
      debugPrint('[DeepLinkService] Failed to read/parse replay file: $e');
    }
  }

  /// Navigates to [MatchReplayScreen] by match ID (fetching from server).
  void _navigateToReplay(String matchId) {
    _whenNavigatorReady((navigator) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => MatchReplayScreen(
            matchId: matchId,
            isWatchedReplay: true,
          ),
        ),
      );
    });
  }

  /// Navigates to [MatchReplayScreen] with an already-parsed [MatchRecordModel].
  void _navigateToReplayModel(MatchRecordModel match) {
    _whenNavigatorReady((navigator) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => MatchReplayScreen(
            match: match,
            isWatchedReplay: true,
          ),
        ),
      );
    });
  }

  /// Safely executes navigation as soon as [appNavigatorKey] is attached and ready.
  void _whenNavigatorReady(void Function(NavigatorState navigator) action) {
    final navigator = appNavigatorKey.currentState;
    if (navigator != null) {
      action(navigator);
      return;
    }

    // If app is still initializing (cold start), poll briefly until navigator is mounted
    int attempts = 0;
    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      attempts++;
      final nav = appNavigatorKey.currentState;
      if (nav != null) {
        timer.cancel();
        action(nav);
      } else if (attempts > 30) {
        timer.cancel();
        debugPrint('[DeepLinkService] Timed out waiting for NavigatorState');
      }
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _isInitialized = false;
  }
}
