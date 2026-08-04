import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/common_widgets/neon_button.dart';
import '../providers/auth_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometric();
    });
  }

  Future<void> _triggerBiometric() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    final success = await notifier.biometricUnlock();
    if (!success && mounted) {
      // If it fails or is cancelled, sign out as the fallback
      await notifier.signOut();
      if (mounted) context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // If unlocked, go back to root which will redirect to /home
    if (!authState.isAppLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgDeep, AppColors.bgMid],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_person_rounded,
                  size: 80,
                  color: AppColors.accentTeal,
                ),
                const SizedBox(height: 24),
                const Text(
                  'App Locked',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Verifying your identity to unlock Abhaya...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),
                if (authState.status == AuthStatus.error && authState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: AppColors.accentCrimson,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                GlassCard(
                  borderRadius: 24,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        NeonButton(
                          label: 'Try Again',
                          leadingIcon: Icons.fingerprint_rounded,
                          variant: NeonButtonVariant.primary,
                          isLoading: authState.status == AuthStatus.loading,
                          onPressed: _triggerBiometric,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            ref.read(authNotifierProvider.notifier).signOut();
                            context.go('/auth');
                          },
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
