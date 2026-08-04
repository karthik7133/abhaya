import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';

class HoldToSosButton extends StatefulWidget {
  final VoidCallback onTrigger;

  const HoldToSosButton({super.key, required this.onTrigger});

  @override
  State<HoldToSosButton> createState() => _HoldToSosButtonState();
}

class _HoldToSosButtonState extends State<HoldToSosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // 3 seconds to trigger
    );
    _controller.addListener(() {
      if (_controller.isCompleted) {
        widget.onTrigger();
        _controller.reset();
        setState(() => _isHolding = false);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanDown(_) {
    setState(() => _isHolding = true);
    _controller.forward();
  }

  void _onPanEnd(_) {
    if (_controller.isAnimating) {
      _controller.reverse();
      setState(() => _isHolding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'SOS Emergency Button',
      hint: 'Hold for 3 seconds to trigger an emergency SOS dispatch',
      onLongPress: widget.onTrigger,
      child: GestureDetector(
        onPanDown: _onPanDown,
        onPanCancel: () => _onPanEnd(null),
        onPanEnd: _onPanEnd,
        child: AnimatedScale(
          scale: _isHolding ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: AppColors.accentCrimson.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.accentCrimson.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: _isHolding
                  ? [
                      BoxShadow(
                        color: AppColors.accentCrimson.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      )
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Progress fill
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _controller.value,
                        child: Container(
                          color: AppColors.accentCrimson.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ),
                // Content
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emergency,
                      size: 40,
                      color: _isHolding ? Colors.white : AppColors.accentCrimson,
                    )
                        .animate(target: _isHolding ? 1 : 0)
                        .shake(duration: 500.ms, hz: 4),
                    const SizedBox(width: 16),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isHolding ? 'HOLDING...' : 'HOLD TO SOS',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: _isHolding ? Colors.white : AppColors.accentCrimson,
                          ),
                        ),
                        Text(
                          _isHolding
                              ? 'Release to cancel'
                              : 'Triggers instant alert to all guardians',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: _isHolding
                                ? Colors.white.withValues(alpha: 0.8)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
