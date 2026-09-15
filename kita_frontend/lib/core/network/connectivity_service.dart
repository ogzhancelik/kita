import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  Future<bool> hasInternet() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _hasValidConnection(results);
    } catch (_) {
      // In case platform call fails, be optimistic or fallback
      return true;
    }
  }

  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_hasValidConnection);
  }

  bool _hasValidConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
  }
}
