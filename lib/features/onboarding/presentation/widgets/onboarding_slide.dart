import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/common_widgets/glass_card.dart';

// ─── Data Model ────────────────────────────────────────────────────────────────

class OnboardingSlideData {
  final int step;
  final String title;
  final String subtitle;
  final String description;
  final Color accentColor;
  final IconData iconData;
  final List<String> features;

  const OnboardingSlideData({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.accentColor,
    required this.iconData,
    required this.features,
  });
}

// ─── Slide Widget ─────────────────────────────────────────────────────────────

class OnboardingSlide extends StatefulWidget {
  final OnboardingSlideData data;

  const OnboardingSlide({super.key, required this.data});

  @override
  State<OnboardingSlide> createState() => _OnboardingSlideState();
}

class _OnboardingSlideState extends State<OnboardingSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.data.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon hero
          _buildIconHero(accent),
          const SizedBox(height: 40),

          // Step badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              widget.data.subtitle,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
                letterSpacing: 2.0,
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 100.ms)
              .slideY(begin: 0.3, end: 0, duration: 400.ms, delay: 100.ms),

          const SizedBox(height: 16),

          // Title
          Text(
            widget.data.title,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.1,
              letterSpacing: -1.0,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 200.ms)
              .slideY(begin: 0.4, end: 0, duration: 500.ms, delay: 200.ms),

          const SizedBox(height: 16),

          // Description
          Text(
            widget.data.description,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 300.ms),

          const SizedBox(height: 28),

          // Feature chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: widget.data.features.asMap().entries.map((entry) {
              final delay = (entry.key * 80 + 400).ms;
              return _buildFeatureChip(entry.value, accent)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: delay)
                  .slideX(begin: 0.2, end: 0, duration: 400.ms, delay: delay);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIconHero(Color accent) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnim.value,
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            height: 190,
            width: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Mid ring
          Container(
            height: 145,
            width: 145,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(
                color: accent.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
          ),
          // Icon container
          GlassCard(
            borderRadius: 100,
            borderColor: accent.withValues(alpha: 0.5),
            blurSigma: 12,
            child: Container(
              height: 110,
              width: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.2),
                    accent.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Icon(widget.data.iconData, size: 52, color: accent),
            ),
          ),
          // Step number badge
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.5),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${widget.data.step}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 500.ms);
  }

  Widget _buildFeatureChip(String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 6,
            width: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accent.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
