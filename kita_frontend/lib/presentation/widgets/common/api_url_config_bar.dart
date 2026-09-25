import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/feedback/toast_service.dart';
import '../../../data/services/websocket_service.dart';
import '../../providers/auth_provider.dart';

/// A compact bottom bar for overriding the API URL at runtime.
/// Only rendered when [ApiConstants.showApiConfig] is true.
class ApiUrlConfigBar extends StatefulWidget {
  const ApiUrlConfigBar({super.key});

  @override
  State<ApiUrlConfigBar> createState() => _ApiUrlConfigBarState();
}

class _ApiUrlConfigBarState extends State<ApiUrlConfigBar> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ApiConstants.baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _controller.text = data.text!.trim();
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  Future<void> _saveUrl() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;

    // Clean and normalize URL (strip trailing slashes, enforce https:// scheme if missing)
    String cleanUrl = url;
    while (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    _controller.text = cleanUrl;

    setState(() => _isSaving = true);

    // 1. Update ApiConstants static baseUrl and persist to SharedPreferences
    await ApiConstants.setAndPersistBaseUrl(cleanUrl);

    // 2. Update singleton ApiClient's Dio instance baseUrl
    ApiClient.instance.updateBaseUrl(cleanUrl);

    // 3. Reset WebSocket so it reconnects with the new wsUrl
    WebSocketService.instance.disconnect();

    // 4. Verify reachability via /health endpoint with 10s timeout
    final isReachable = await ConnectivityService.checkApiHealth(cleanUrl);

    // 5. Trigger AuthProvider re-check so the app moves from offline/checking to proper state
    if (mounted) {
      context.read<AuthProvider>().checkInitialState();
    }

    setState(() => _isSaving = false);

    if (mounted) {
      if (isReachable) {
        KitaToast.success('apiConfig.saved'.tr());
      } else {
        KitaToast.error('apiConfig.savedButUnreachable'.tr());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              Icon(
                Icons.dns_rounded,
                size: 14,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
              const SizedBox(width: 6),
              Text(
                'apiConfig.label'.tr(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Input row: [Paste] [TextField] [Save]
          Row(
            children: [
              // Paste button
              _ActionIconButton(
                icon: Icons.content_paste_rounded,
                tooltip: 'apiConfig.paste'.tr(),
                onPressed: _isSaving ? null : _pasteFromClipboard,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              // URL text field
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _controller,
                    enabled: !_isSaving,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'apiConfig.hint'.tr(),
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onSubmitted: (_) => _saveUrl(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Save button
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveUrl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'apiConfig.save'.tr(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isDark;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: Icon(
              icon,
              size: 20,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
