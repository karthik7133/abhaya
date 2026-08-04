import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/common_widgets/emergency_interaction_manager.dart';
import '../../../core/providers/service_availability_provider.dart';
import '../../../core/providers/telemetry_provider.dart';
import '../../../l10n/app_localizations.dart';

class NavigationShell extends ConsumerWidget {
  final Widget child;
  const NavigationShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/guardians')) return 1;
    if (location.startsWith('/community')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/home'); break;
      case 1: context.go('/guardians'); break;
      case 2: context.go('/community'); break;
      case 3: context.go('/profile'); break;
    }
  }

  void _openIncidentReport(BuildContext context) {
    HapticFeedback.heavyImpact();
    context.push('/incident-report');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final serviceMode = ref.watch(serviceAvailabilityProvider).mode;
    final guardian = ref.watch(guardianProvider);
    final isEmergency = guardian.isEmergency;
    final l10n = AppLocalizations.of(context)!;

    return EmergencyInteractionManager(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.bgDeep,
        body: Stack(
          children: [
          // ── Ambient background gradient ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.bgDeep, AppColors.bgMid],
              ),
            ),
          ),

          // ── Ambient SOS Pulse ──
          if (isEmergency)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [
                      AppColors.accentCrimson.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 1.seconds),
            ),

          // ── Ambient threat glow (top left) ──
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accentCrimson.withValues(alpha: 0.05),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── Ambient glow orbs ──
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accentTeal.withValues(alpha: 0.06),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accentCrimson.withValues(alpha: 0.05),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── Page content with bottom clearance ──
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: 100 + bottomPad),
              child: child,
            ),
          ),

          // ── Floating Nav Dock ──
          Positioned(
            bottom: 16 + bottomPad,
            left: 16,
            right: 16,
            child: SizedBox(
              height: 68,
              child: GlassCard(
                borderRadius: 26,
                borderColor: Colors.white.withValues(alpha: 0.08),
                fillColor: AppColors.bgCard.withValues(alpha: 0.7),
                blurSigma: 20,
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.accentTeal.withValues(alpha: 0.04),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNavItem(context, index: 0, activeIndex: selectedIndex, icon: Icons.grid_view_rounded, label: l10n.engine),
                      _buildNavItem(context, index: 1, activeIndex: selectedIndex, icon: Icons.supervised_user_circle_outlined, label: l10n.guardianNetwork),
                      const SizedBox(width: 60), // spacer for SOS button
                      _buildNavItem(context, index: 2, activeIndex: selectedIndex, icon: Icons.sensors_outlined, label: l10n.alertsIntel),
                      _buildNavItem(context, index: 3, activeIndex: selectedIndex, icon: Icons.manage_accounts_outlined, label: l10n.profileTitle),
                    ],
                  ),
                ),
              ),
            ).animate().slideY(begin: 1, end: 0, duration: 500.ms, curve: Curves.easeOutBack).fadeIn(duration: 400.ms),
          ),

          // ── Elevated Camera Button (above dock plane) ──
          Positioned(
            bottom: 28 + bottomPad,
            left: MediaQuery.of(context).size.width / 2 - 30,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.heavyImpact();
                context.push('/media-capture');
              },
              child: const _CameraButton(),
            ).animate().scale(begin: const Offset(0, 0), end: const Offset(1, 1), duration: 600.ms, delay: 200.ms, curve: Curves.easeOutBack),
          ),
          // ── AI Orb — bottom-right, above dock ──
          Positioned(
            bottom: 90 + bottomPad,
            right: 20,
            child: GestureDetector(
              onTap: () => context.push('/ai-assistant'),
              child: _AIOrb(),
            ).animate()
                .scale(begin: const Offset(0, 0), end: const Offset(1, 1),
                    duration: 600.ms, delay: 350.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 400.ms, delay: 350.ms),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, {
    required int index,
    required int activeIndex,
    required IconData icon,
    required String label,
  }) {
    final isActive = index == activeIndex;
    final color = isActive ? AppColors.accentTeal : AppColors.textMuted;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onItemTapped(index, context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isActive
                      ? AppColors.accentTeal.withValues(alpha: 0.12)
                      : Colors.transparent,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: 0.3,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Camera Pulse Button ──────────────────────────────────────────────────────────

class _CameraButton extends StatefulWidget {
  const _CameraButton();

  @override
  State<_CameraButton> createState() => _CameraButtonState();
}

class _CameraButtonState extends State<_CameraButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final pulse = _pulseCtrl.value;
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentTeal.withValues(alpha: 0.2 + pulse * 0.2),
                blurRadius: 12 + pulse * 12,
                spreadRadius: 1 + pulse * 3,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accentTeal.withValues(alpha: 0.95),
                  const Color(0xFF007A8C),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 26),
          ),
        );
      },
    );
  }
}

// ── AI Orb ────────────────────────────────────────────────────────────────────

const _kViolet = Color(0xFFB5179E);

class _AIOrb extends StatefulWidget {
  @override
  State<_AIOrb> createState() => _AIorbState();
}

class _AIorbState extends State<_AIOrb> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final p = _ctrl.value;
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _kViolet.withValues(alpha: 0.25 + p * 0.3),
                blurRadius: 16 + p * 14,
                spreadRadius: 1 + p * 3,
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kViolet.withValues(alpha: 0.15),
                  border: Border.all(
                    color: _kViolet.withValues(alpha: 0.3 + p * 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _kViolet,
                  size: 22,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
