import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/feedback/toast_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/report_api_service.dart';

class ReportDialog extends StatefulWidget {
  final String? matchId;
  final String? reportedUsername;

  const ReportDialog({
    super.key,
    this.matchId,
    this.reportedUsername,
  });

  static Future<void> show(
    BuildContext context, {
    String? matchId,
    String? reportedUsername,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportDialog(
        matchId: matchId,
        reportedUsername: reportedUsername,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final _reportService = ReportApiService();
  late final TextEditingController _detailsController;
  late final TextEditingController _reportedUserController;

  String? _selectedReason;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _detailsController = TextEditingController();
    _reportedUserController = TextEditingController(
      text: widget.reportedUsername ?? '',
    );
    _selectedReason = 'moderation.reasonOther'.tr();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _reportedUserController.dispose();
    super.dispose();
  }

  List<String> get _reasons {
    if (widget.matchId != null && widget.matchId!.isNotEmpty) {
      return [
        'moderation.reasonCheating'.tr(),
        'moderation.reasonHarassment'.tr(),
        'moderation.reasonStalling'.tr(),
        'moderation.reasonBug'.tr(),
        'moderation.reasonOther'.tr(),
      ];
    }
    return [
      'moderation.reasonBug'.tr(),
      'moderation.reasonPlayerReport'.tr(),
      'moderation.reasonFeedback'.tr(),
      'moderation.reasonOther'.tr(),
    ];
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null || _selectedReason!.isEmpty) {
      KitaToast.show(
        message: 'moderation.reasonRequired'.tr(),
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final reportedUser = _reportedUserController.text.trim();
      await _reportService.submitReport(
        reason: _selectedReason!,
        description: _detailsController.text.trim(),
        matchId: widget.matchId,
        reportedUsername: reportedUser.isNotEmpty ? reportedUser : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        KitaToast.show(
          message: 'moderation.reportSuccess'.tr(),
          type: ToastType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        KitaToast.show(
          message: 'moderation.reportError'.tr(),
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
        maxWidth: 520,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.getBorder(isDark), width: 1),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'moderation.dialogTitle'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'moderation.dialogSubtitle'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
              const SizedBox(height: 16),

              // In-game Match / Opponent Context info
              if (widget.matchId != null && widget.matchId!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.getCard(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.getBorder(isDark),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sports_esports_rounded,
                        size: 16,
                        color: AppColors.primaryAmber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${'moderation.matchId'.tr()}: ${widget.matchId}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Reported Player field (if applicable or prefilled)
              if (widget.reportedUsername != null &&
                  widget.reportedUsername!.isNotEmpty) ...[
                Text(
                  'moderation.reportedPlayer'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _reportedUserController,
                  readOnly: widget.matchId != null,
                  style: TextStyle(
                    color: AppColors.getTextPrimary(isDark),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: AppColors.primaryAmber,
                    ),
                    filled: true,
                    fillColor: AppColors.getCard(isDark),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.getBorder(isDark)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.getBorder(isDark)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Reason Selector
              Text(
                'moderation.reason'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reasons.map((reason) {
                  final isSelected = _selectedReason == reason;
                  return ChoiceChip(
                    showCheckmark: false,
                    label: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.black
                            : AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.accentGold,
                    backgroundColor: AppColors.getCard(isDark),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.accentGold
                          : AppColors.getBorder(isDark),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _selectedReason = val ? reason : 'moderation.reasonOther'.tr();
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Details field
              Text(
                'moderation.details'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _detailsController,
                maxLines: 4,
                style: TextStyle(
                  color: AppColors.getTextPrimary(isDark),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'moderation.detailsHint'.tr(),
                  hintStyle: TextStyle(
                    color: AppColors.getTextSecondary(isDark),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppColors.getCard(isDark),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.getBorder(isDark)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.getBorder(isDark)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryAmber,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Actions: Cancel & Submit
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppColors.getBorder(isDark)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'moderation.cancel'.tr(),
                        style: TextStyle(
                          color: AppColors.getTextSecondary(isDark),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAmber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _submitReport,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : Text(
                              'moderation.submit'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
