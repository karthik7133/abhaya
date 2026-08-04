import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

enum NeonButtonVariant { primary, warning, danger, ghost }

/// NeonButton — Premium animated CTA button with glow, scale tap, and loading shimmer.
class NeonButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final NeonButtonVariant variant;
  final double height;
  final double? width;
  final IconData? leadingIcon;

  const NeonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = NeonButtonVariant.primary,
    this.height = 56,
    this.width,
    this.leadingIcon,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Color get _primaryColor {
    switch (widget.variant) {
      case NeonButtonVariant.primary:
        return AppColors.accentTeal;
      case NeonButtonVariant.warning:
        return AppColors.accentAmber;
      case NeonButtonVariant.danger:
        return AppColors.accentCrimson;
      case NeonButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color get _labelColor {
    if (widget.variant == NeonButtonVariant.ghost) return AppColors.accentTeal;
    return Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: (_) {
        if (!isDisabled) {
          setState(() => _isPressed = true);
          _scaleController.forward();
        }
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _scaleController.reverse();
        if (!isDisabled) widget.onPressed?.call();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _scaleController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            height: widget.height,
            width: widget.width ?? double.infinity,
            decoration: BoxDecoration(
              gradient: widget.variant != NeonButtonVariant.ghost
                  ? LinearGradient(
                      colors: [
                        _primaryColor,
                        _primaryColor.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: widget.variant == NeonButtonVariant.ghost
                  ? Border.all(color: AppColors.accentTeal, width: 1.5)
                  : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDisabled || widget.variant == NeonButtonVariant.ghost
                  ? []
                  : [
                      BoxShadow(
                        color: _primaryColor.withValues(alpha: _isPressed ? 0.5 : 0.3),
                        blurRadius: _isPressed ? 20 : 32,
                        spreadRadius: _isPressed ? 0 : -2,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _labelColor,
                      ),
                    ).animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 1000.ms, color: Colors.white38)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.leadingIcon != null) ...[
                          Icon(widget.leadingIcon, color: _labelColor, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _labelColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
