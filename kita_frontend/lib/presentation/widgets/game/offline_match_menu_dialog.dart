import 'package:flutter/material.dart';
import 'match_menu_dialog.dart';

/// Modal bottom sheet for offline match actions.
/// Uses the unified [MatchMenuDialog] template with `isOffline: true`.
class OfflineMatchMenuDialog extends StatelessWidget {
  const OfflineMatchMenuDialog({super.key});

  static Future<void> show(BuildContext context) {
    return MatchMenuDialog.show(context, isOffline: true);
  }

  @override
  Widget build(BuildContext context) {
    return const MatchMenuDialog(isOffline: true);
  }
}
