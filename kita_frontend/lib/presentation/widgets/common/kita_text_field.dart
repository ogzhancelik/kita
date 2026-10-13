import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

class KitaTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final bool enabled;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  const KitaTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.focusNode,
    this.validator,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.maxLength,
  });

  @override
  State<KitaTextField> createState() => _KitaTextFieldState();
}

class _KitaTextFieldState extends State<KitaTextField> {
  bool _obscureText = true;
  bool _isFocused = false;
  FocusNode? _internalFocusNode;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(KitaTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)?.removeListener(_handleFocusChange);
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  void _handleFocusChange() {
    if (mounted && _isFocused != _effectiveFocusNode.hasFocus) {
      setState(() => _isFocused = _effectiveFocusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          focusNode: _effectiveFocusNode,
          textInputAction: widget.textInputAction,
          obscureText: widget.isPassword ? _obscureText : false,
          keyboardType: widget.keyboardType,
          enabled: widget.enabled,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: (value) {
            if (widget.onSubmitted != null) {
              widget.onSubmitted!(value);
            } else if (widget.textInputAction == TextInputAction.next) {
              FocusScope.of(context).nextFocus();
            }
          },
          inputFormatters: widget.inputFormatters,
          maxLength: widget.maxLength,
          scrollPadding: const EdgeInsets.all(24.0),
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            counterText: widget.maxLength != null ? '' : null,
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              fontSize: 14,
            ),
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    color: _isFocused
                        ? AppColors.primaryGreen
                        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    size: 20,
                  )
                : null,
            suffixIcon: widget.isPassword
                ? ExcludeFocus(
                    excluding: true,
                    child: IconButton(
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    ),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
