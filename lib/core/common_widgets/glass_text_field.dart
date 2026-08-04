import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

/// GlassTextField — Focus-reactive input with animated neon border glow.
/// The border color transitions from muted → accentTeal on focus.
/// Error state overrides to accentCrimson glow.
class GlassTextField extends StatefulWidget {
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final String? errorText;
  final Widget? suffixWidget;
  final TextInputAction textInputAction;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final int? maxLength;
  final bool readOnly;

  const GlassTextField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.controller,
    this.errorText,
    this.suffixWidget,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.readOnly = false,
  });

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnim;
  bool _isFocused = false;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _glowAnim = CurvedAnimation(parent: _glowController, curve: Curves.easeOut);
    _obscureText = widget.isPassword;
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Color get _activeBorderColor {
    if (widget.errorText != null) return AppColors.accentCrimson;
    if (_isFocused) return AppColors.accentTeal;
    return AppColors.glassBorder;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: _activeBorderColor.withValues(alpha: 0.25 * _glowAnim.value),
                          blurRadius: 24,
                          spreadRadius: -2,
                        )
                      ]
                    : [],
              ),
              child: child,
            );
          },
          child: Focus(
            onFocusChange: (hasFocus) {
              setState(() => _isFocused = hasFocus);
              if (hasFocus) {
                _glowController.forward();
              } else {
                _glowController.reverse();
              }
            },
            child: GlassCard(
              borderRadius: 16,
              blurSigma: 8,
              borderColor: _activeBorderColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        widget.prefixIcon,
                        color: _isFocused
                            ? _activeBorderColor
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        obscureText: widget.isPassword ? _obscureText : false,
                        keyboardType: widget.keyboardType,
                        textInputAction: widget.textInputAction,
                        readOnly: widget.readOnly,
                        maxLength: widget.maxLength,
                        onChanged: widget.onChanged,
                        onSubmitted: widget.onSubmitted,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: AppColors.accentTeal,
                        cursorWidth: 1.5,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: widget.hintText,
                          counterText: '',
                          hintStyle: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    if (widget.isPassword)
                      GestureDetector(
                        onTap: () => setState(() => _obscureText = !_obscureText),
                        child: Icon(
                          _obscureText
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      )
                    else if (widget.suffixWidget != null)
                      widget.suffixWidget!,
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: AppColors.accentCrimson,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
