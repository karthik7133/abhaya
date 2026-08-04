import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/common_widgets/neon_button.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/onboarding_slide.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<OnboardingSlideData> _slides = [
    OnboardingSlideData(
      step: 1,
      title: 'Threat Fusion\nEngine',
      subtitle: 'AI-DRIVEN PREDICTION',
      description:
          'Continuously monitors voice stress, motion, heart rate, and location to calculate your threat score — before danger escalates.',
      accentColor: AppColors.accentTeal,
      iconData: Icons.psychology_outlined,
      features: ['Voice Distress Analysis', 'Biometric Monitoring', 'Predictive Scoring'],
    ),
    OnboardingSlideData(
      step: 2,
      title: 'Sensor Fusion\nNetwork',
      subtitle: 'PERIPHERAL SYNC',
      description:
          'Seamlessly bridges phone sensors with your smart band — GPS, accelerometer, gyroscope, and heart rate unified in one stream.',
      accentColor: AppColors.accentAmber,
      iconData: Icons.sensors,
      features: ['Smart Band BLE Sync', 'GPS + Motion Fusion', 'Battery-Optimized'],
    ),
    OnboardingSlideData(
      step: 3,
      title: 'Immutable\nEvidence Vault',
      subtitle: 'DECENTRALIZED ARCHIVAL',
      description:
          'The moment threat exceeds threshold, audio, video, and GPS are captured and uploaded instantly — even if your phone is taken.',
      accentColor: AppColors.accentCrimson,
      iconData: Icons.lock_outlined,
      features: ['Auto Capture & Upload', 'Tamper-Proof Logs', 'Cloud Redundancy'],
    ),
  ];

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    await ref.read(onboardingNotifierProvider.notifier).markComplete();
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.bgDeep, AppColors.bgMid],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Ambient glow orbs
              _buildAmbientOrb(
                color: _slides[_currentPage].accentColor,
                top: -80,
                right: -60,
                size: 280,
              ),
              _buildAmbientOrb(
                color: AppColors.bgSurface,
                bottom: -100,
                left: -80,
                size: 320,
              ),

              // Main content
              Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Abhaya wordmark
                        Row(
                          children: [
                            Container(
                              height: 28,
                              width: 28,
                              decoration: BoxDecoration(
                                color: _slides[_currentPage].accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _slides[_currentPage].accentColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Icon(
                                Icons.shield_outlined,
                                size: 16,
                                color: _slides[_currentPage].accentColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'ABHAYA',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: 2.5,
                              ),
                            ),
                          ],
                        ),
                        // Skip button
                        GestureDetector(
                          onTap: _completeOnboarding,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // PageView slides
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        return OnboardingSlide(data: _slides[index]);
                      },
                    ),
                  ),

                  // Bottom controls
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      children: [
                        // Page indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_slides.length, (index) {
                            final isActive = _currentPage == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 6,
                              width: isActive ? 28 : 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? _slides[_currentPage].accentColor
                                    : Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: _slides[_currentPage]
                                              .accentColor
                                              .withValues(alpha: 0.6),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : [],
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 28),

                        // CTA button
                        NeonGlowBorder(
                          glowColor: _slides[_currentPage].accentColor,
                          borderRadius: 16,
                          glowIntensity: 0.5,
                          child: NeonButton(
                            label: _currentPage == _slides.length - 1
                                ? 'GET STARTED'
                                : 'CONTINUE',
                            onPressed: _nextPage,
                            variant: _currentPage == 2
                                ? NeonButtonVariant.danger
                                : (_currentPage == 1
                                    ? NeonButtonVariant.warning
                                    : NeonButtonVariant.primary),
                            leadingIcon: _currentPage == _slides.length - 1
                                ? Icons.arrow_forward_rounded
                                : null,
                          ),
                        ),
                      ],
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

  Widget _buildAmbientOrb({
    required Color color,
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.15),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
