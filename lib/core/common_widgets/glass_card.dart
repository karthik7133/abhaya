import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// GlassCard — Core reusable glassmorphic surface.
///
/// NOTE: This widget uses [BackdropFilter] which is computationally expensive.
/// It is intentionally scoped to key structural surfaces only (auth card,
/// onboarding slides, bottom nav). DO NOT nest multiple GlassCards.
/// On Flutter Web (CanvasKit renderer), this may drop below 60fps on
/// low-end browsers — optimization is scoped to native mobile rasterization.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? borderColor;
  final Color? fillColor;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.borderColor,
    this.fillColor,
    this.blurSigma = 16.0,
    this.padding,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppColors.glassBorder;
    final effectiveFill = fillColor ?? AppColors.glassFill;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveFill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              width: 1.2,
              color: effectiveBorderColor,
            ),
            boxShadow: shadows ??
                [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: effectiveBorderColor.withValues(alpha: 0.08),
                    blurRadius: 1,
                    offset: const Offset(0, 0),
                    spreadRadius: 1,
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// NeonGlowBorder — Animated glowing border wrapper.
/// Use this to add a neon halo around any widget without BackdropFilter cost.
class NeonGlowBorder extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double borderRadius;
  final double glowIntensity;

  const NeonGlowBorder({
    super.key,
    required this.child,
    required this.glowColor,
    this.borderRadius = 16,
    this.glowIntensity = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: glowIntensity * 0.4),
            blurRadius: 24,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: glowIntensity * 0.15),
            blurRadius: 48,
            spreadRadius: -4,
          ),
        ],
      ),
      child: child,
    );
  }
}
