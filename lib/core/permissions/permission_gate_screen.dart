import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../common_widgets/glass_card.dart';
import '../common_widgets/neon_button.dart';

// ─── Permission State Provider ────────────────────────────────────────────────

class PermissionStatus2 {
  final bool locationGranted;
  final bool microphoneGranted;
  final bool notificationGranted;
  final bool isChecking;

  const PermissionStatus2({
    this.locationGranted = false,
    this.microphoneGranted = false,
    this.notificationGranted = false,
    this.isChecking = false,
  });

  bool get allCriticalGranted => locationGranted;
  bool get allGranted =>
      locationGranted && microphoneGranted && notificationGranted;

  PermissionStatus2 copyWith({
    bool? locationGranted,
    bool? microphoneGranted,
    bool? notificationGranted,
    bool? isChecking,
  }) {
    return PermissionStatus2(
      locationGranted: locationGranted ?? this.locationGranted,
      microphoneGranted: microphoneGranted ?? this.microphoneGranted,
      notificationGranted: notificationGranted ?? this.notificationGranted,
      isChecking: isChecking ?? this.isChecking,
    );
  }
}

class PermissionNotifier extends StateNotifier<PermissionStatus2> {
  PermissionNotifier() : super(const PermissionStatus2());

  Future<void> checkCurrentStatus() async {
    state = state.copyWith(isChecking: true);
    final loc = await Permission.locationWhenInUse.status;
    final mic = await Permission.microphone.status;
    final notif = await Permission.notification.status;
    state = PermissionStatus2(
      locationGranted: loc.isGranted,
      microphoneGranted: mic.isGranted,
      notificationGranted: notif.isGranted,
      isChecking: false,
    );
  }

  Future<bool> requestAll() async {
    state = state.copyWith(isChecking: true);
    HapticFeedback.mediumImpact();

    // Request location first (critical)
    final locStatus = await Permission.locationWhenInUse.request();
    state = state.copyWith(locationGranted: locStatus.isGranted);

    if (locStatus.isGranted) {
      // Try background location silently
      await Permission.locationAlways.request();
    }

    // Microphone
    final micStatus = await Permission.microphone.request();
    state = state.copyWith(microphoneGranted: micStatus.isGranted);

    // Notifications
    final notifStatus = await Permission.notification.request();
    state = state.copyWith(
      notificationGranted: notifStatus.isGranted,
      isChecking: false,
    );

    return locStatus.isGranted; // location is critical
  }

  Future<void> requestSingle(Permission perm) async {
    final status = await perm.request();
    if (perm == Permission.locationWhenInUse ||
        perm == Permission.location) {
      state = state.copyWith(locationGranted: status.isGranted);
    } else if (perm == Permission.microphone) {
      state = state.copyWith(microphoneGranted: status.isGranted);
    } else if (perm == Permission.notification) {
      state = state.copyWith(notificationGranted: status.isGranted);
    }
  }
}

final permissionProvider =
    StateNotifierProvider<PermissionNotifier, PermissionStatus2>((ref) {
  return PermissionNotifier();
});

// ─── Permission Gate Screen ───────────────────────────────────────────────────

class PermissionGateScreen extends ConsumerStatefulWidget {
  const PermissionGateScreen({super.key});

  @override
  ConsumerState<PermissionGateScreen> createState() =>
      _PermissionGateScreenState();
}

class _PermissionGateScreenState extends ConsumerState<PermissionGateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shieldCtrl;
  bool _requesting = false;

  static const _permissions = [
    _PermissionItem(
      icon: Icons.location_on_rounded,
      color: AppColors.accentTeal,
      title: 'Precise Location',
      description:
          'Enables safe routing, live guardian tracking, and auto-SOS with your exact coordinates.',
      critical: true,
    ),
    _PermissionItem(
      icon: Icons.mic_rounded,
      color: AppColors.accentAmber,
      title: 'Microphone',
      description:
          'Powers AI distress detection — processes audio locally, never recorded or uploaded.',
      critical: false,
    ),
    _PermissionItem(
      icon: Icons.notifications_active_rounded,
      color: Color(0xFF6B5CE7),
      title: 'Notifications',
      description:
          'Delivers emergency alerts, guardian check-ins, and safety updates instantly.',
      critical: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _shieldCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Check existing status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(permissionProvider.notifier).checkCurrentStatus();
    });
  }

  @override
  void dispose() {
    _shieldCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestAll() async {
    setState(() => _requesting = true);
    final granted =
        await ref.read(permissionProvider.notifier).requestAll();
    setState(() => _requesting = false);

    if (granted) {
      await _markDoneAndProceed();
    } else {
      // Location denied — show instructions
      _showLocationRequiredDialog();
    }
  }

  Future<void> _markDoneAndProceed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_granted', true);
    if (mounted) context.go('/home');
  }

  void _skipOptional() async {
    // Only allow skip if location is already granted
    final status = ref.read(permissionProvider);
    if (status.locationGranted) {
      await _markDoneAndProceed();
    } else {
      _showLocationRequiredDialog();
    }
  }

  void _showLocationRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.accentCrimson.withValues(alpha: 0.3)),
        ),
        title: const Row(children: [
          Icon(Icons.location_off_rounded, color: AppColors.accentCrimson),
          SizedBox(width: 10),
          Text('Location Required',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'Abhaya needs location access to protect you. Please enable it in your device Settings.',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'PlusJakartaSans',
              height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings',
                style: TextStyle(color: AppColors.accentTeal)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(permissionProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.bgDeep, Color(0xFF0D1B2A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Hero icon
                AnimatedBuilder(
                  animation: _shieldCtrl,
                  builder: (_, __) => Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentTeal
                          .withValues(alpha: 0.06 + 0.04 * _shieldCtrl.value),
                      border: Border.all(
                        color: AppColors.accentTeal
                            .withValues(alpha: 0.2 + 0.1 * _shieldCtrl.value),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentTeal
                              .withValues(alpha: 0.1 + 0.1 * _shieldCtrl.value),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AppColors.accentTeal,
                      size: 56,
                    ),
                  ),
                ).animate().fadeIn(delay: 100.ms).scale(),

                const SizedBox(height: 32),

                const Text(
                  'Abhaya needs a few\npermissions to protect you',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                const SizedBox(height: 8),

                const Text(
                  'These are used only to keep you safe.\nAll processing is private and on-device where possible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 250.ms),

                const SizedBox(height: 36),

                // Permission tiles
                ..._permissions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final perm = entry.value;
                  final isGranted = i == 0
                      ? status.locationGranted
                      : i == 1
                          ? status.microphoneGranted
                          : status.notificationGranted;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PermissionTile(
                      item: perm,
                      isGranted: isGranted,
                    )
                        .animate()
                        .fadeIn(delay: (300 + i * 80).ms)
                        .slideX(begin: 0.05),
                  );
                }),

                const SizedBox(height: 32),

                // Grant all button
                NeonButton(
                  label: _requesting ? 'Requesting...' : 'GRANT ALL PERMISSIONS',
                  leadingIcon: _requesting
                      ? Icons.hourglass_empty_rounded
                      : Icons.security_rounded,
                  variant: NeonButtonVariant.primary,
                  height: 56,
                  onPressed: _requesting ? () {} : _requestAll,
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),

                const SizedBox(height: 12),

                // Skip optional (only if location already granted)
                if (status.locationGranted)
                  GestureDetector(
                    onTap: _skipOptional,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Continue without optional permissions',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: AppColors.textMuted,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 700.ms),

                const SizedBox(height: 24),

                // Privacy assurance
                GlassCard(
                  borderRadius: 16,
                  borderColor: Colors.white.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const Icon(Icons.lock_outline_rounded,
                          color: AppColors.accentTeal, size: 18),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Your data is encrypted end-to-end and never sold. '
                          'Location is only shared with your chosen guardians when you activate protection.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ).animate().fadeIn(delay: 750.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Permission Tile ──────────────────────────────────────────────────────────

class _PermissionTile extends StatelessWidget {
  final _PermissionItem item;
  final bool isGranted;

  const _PermissionTile({required this.item, required this.isGranted});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 16,
      borderColor: isGranted
          ? item.color.withValues(alpha: 0.35)
          : item.critical
              ? item.color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: isGranted ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon,
                color: isGranted ? item.color : item.color.withValues(alpha: 0.6),
                size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(item.title,
                      style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(width: 6),
                  if (item.critical)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Required',
                          style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: item.color,
                              letterSpacing: 0.5)),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(item.description,
                    style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isGranted
                ? Container(
                    key: const ValueKey('granted'),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: AppColors.accentTeal, size: 16),
                  )
                : Container(
                    key: const ValueKey('pending'),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.radio_button_unchecked_rounded,
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                        size: 16),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ─── Data Class ───────────────────────────────────────────────────────────────

class _PermissionItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final bool critical;

  const _PermissionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.critical,
  });
}
