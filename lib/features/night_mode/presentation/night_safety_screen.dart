import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:torch_light/torch_light.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/common_widgets/neon_button.dart';
import '../../../core/providers/night_safety_provider.dart';
import '../../../core/providers/telemetry_provider.dart';
import '../../../core/providers/night_contacts_provider.dart';
import '../../../core/providers/night_settings_provider.dart';
import '../../../core/services/backend_service.dart';
import '../../../l10n/app_localizations.dart';

class NightSafetyScreen extends ConsumerStatefulWidget {
  const NightSafetyScreen({super.key});

  @override
  ConsumerState<NightSafetyScreen> createState() => _NightSafetyScreenState();
}

class _NightSafetyScreenState extends ConsumerState<NightSafetyScreen>
    with TickerProviderStateMixin {
  late AnimationController _moonCtrl;
  late AnimationController _starCtrl;
  late AnimationController _sosCtrl;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _sirenActive = false;
  bool _flashlightActive = false;
  bool _fakeCallActive = false;
  Timer? _sirenTimer;
  Timer? _strobeTimer;
  int _sirenCount = 0;

  @override
  void initState() {
    super.initState();
    _moonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _sosCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _moonCtrl.dispose();
    _starCtrl.dispose();
    _sosCtrl.dispose();
    _sirenTimer?.cancel();
    _strobeTimer?.cancel();
    _audioPlayer.dispose();
    // Turn off flashlight if active
    if (_flashlightActive) {
      TorchLight.disableTorch();
    }
    super.dispose();
  }

  void _toggleSiren() async {
    HapticFeedback.heavyImpact();
    if (_sirenActive) {
      _sirenTimer?.cancel();
      _sosCtrl.stop();
      FlutterRingtonePlayer().stop();
      setState(() {
        _sirenActive = false;
        _sirenCount = 0;
      });
    } else {
      setState(() => _sirenActive = true);
      _sosCtrl.repeat(reverse: true);
      
      // Play siren sound using system ringtone
      FlutterRingtonePlayer().playAlarm(
        looping: true,
        volume: 1.0,
      );
      
      _sirenTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
        HapticFeedback.heavyImpact();
        if (mounted) setState(() => _sirenCount++);
      });
    }
  }

  void _toggleFlashlight() async {
    HapticFeedback.lightImpact();
    
    if (_flashlightActive) {
      // Turn off strobe/flashlight
      _strobeTimer?.cancel();
      try {
        await TorchLight.disableTorch();
      } catch (e) {
        debugPrint('Error disabling torch: $e');
      }
      setState(() => _flashlightActive = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.bgMid,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
          content: const Text(
            'Strobe deactivated',
            style: TextStyle(fontFamily: 'PlusJakartaSans', color: Colors.white),
          ),
        ),
      );
    } else {
      // Turn on strobe mode
      setState(() => _flashlightActive = true);
      
      try {
        await TorchLight.enableTorch();
        // Start strobe effect
        _strobeTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
          if (!mounted) {
            timer.cancel();
            return;
          }
          try {
            await TorchLight.enableTorch();
            await Future.delayed(const Duration(milliseconds: 100));
            await TorchLight.disableTorch();
          } catch (e) {
            debugPrint('Strobe error: $e');
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.bgMid,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
            content: const Text(
              'Strobe activated',
              style: TextStyle(fontFamily: 'PlusJakartaSans', color: Colors.white),
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error enabling torch: $e');
        setState(() => _flashlightActive = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.accentCrimson,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
            content: Text(
              'Flashlight not available: $e',
              style: const TextStyle(fontFamily: 'PlusJakartaSans', color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  void _triggerFakeCall() {
    if (_fakeCallActive) return;
    HapticFeedback.mediumImpact();
    final contacts = ref.read(nightContactsProvider);
    // Use first enabled contact name, fallback to generic
    final callerName = contacts.isNotEmpty
        ? contacts.firstWhere((c) => c.enabled,
                orElse: () => contacts.first)
            .name
        : 'Priya Sharma';

    setState(() => _fakeCallActive = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) => _FakeCallDialog(
        callerName: callerName,
        onEnd: () {
          Navigator.pop(ctx);
          if (mounted) setState(() => _fakeCallActive = false);
        },
      ),
    );
  }

  void _sendSilentSos() {
    HapticFeedback.heavyImpact();
    final guardian = ref.read(guardianProvider);
    BackendService.triggerSos(
      lat: guardian.telemetry.latitude,
      lng: guardian.telemetry.longitude,
    ).catchError((e) => debugPrint('[SilentSOS] $e'));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.accentCrimson,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        content: const Row(children: [
          Icon(Icons.warning_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Silent SOS sent to all guardians!',
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
      ),
    );
  }

  void _showAddContactSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.bgMid,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
                color: AppColors.accentTeal.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Add Safe Contact',
                  style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text(
                  'This contact will receive SOS alerts during Night Mode.',
                  style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: AppColors.textSecondary)),

              const SizedBox(height: 24),

              _inputField(nameCtrl, 'Full Name', Icons.person_outline_rounded),
              const SizedBox(height: 12),
              _inputField(phoneCtrl, 'Phone Number', Icons.phone_outlined,
                  keyboardType: TextInputType.phone),

              const SizedBox(height: 24),

              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Center(
                        child: Text('Cancel',
                            style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                color: AppColors.textSecondary)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (nameCtrl.text.isNotEmpty &&
                          phoneCtrl.text.isNotEmpty) {
                        await ref
                            .read(nightContactsProvider.notifier)
                            .addContact(nameCtrl.text, phoneCtrl.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                        HapticFeedback.lightImpact();
                      }
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [
                              AppColors.accentTeal,
                              AppColors.accentTealDark
                            ]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(AppLocalizations.of(context)!.addContact,
                            style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black)),
                      ),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: AppColors.textPrimary,
          fontSize: 14),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: AppColors.textMuted, fontFamily: 'PlusJakartaSans'),
        prefixIcon: Icon(icon, color: AppColors.accentTeal, size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppColors.accentTeal.withValues(alpha: 0.5)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nightSafety = ref.watch(nightSafetyProvider);
    final notifier = ref.read(nightSafetyProvider.notifier);
    final guardian = ref.watch(guardianProvider);
    final contacts = ref.watch(nightContactsProvider);
    final nightSettings = ref.watch(nightSettingsProvider);
    final settingsNotifier = ref.read(nightSettingsProvider.notifier);
    final hour = DateTime.now().hour;
    final isActuallyNight = hour >= 20 || hour <= 6;

    return Scaffold(
      backgroundColor: const Color(0xFF05060F),
      body: Stack(
        children: [
          // Night sky background with stars
          ..._buildStarField(context),

          // Moon glow ambient
          Positioned(
            top: -60,
            right: -30,
            child: AnimatedBuilder(
              animation: _moonCtrl,
              builder: (_, __) => Container(
                height: 250,
                width: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF1E3A5F)
                          .withValues(alpha: 0.15 + 0.05 * _moonCtrl.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(nightSafety, notifier),
                  const SizedBox(height: 16),

                  _buildNightModeCard(nightSafety, notifier, isActuallyNight),
                  const SizedBox(height: 16),

                  _buildEmergencyToolsCard(guardian),
                  const SizedBox(height: 16),

                  _buildSafeContactsCard(contacts),
                  const SizedBox(height: 16),

                  _buildSettingsCard(nightSettings, settingsNotifier),
                ],
              ),
            ),
          ),

          // Siren overlay
          if (_sirenActive) _buildSirenOverlay(),
        ],
      ),
    );
  }

  List<Widget> _buildStarField(BuildContext context) {
    final rng = math.Random(42);
    final width = MediaQuery.sizeOf(context).width;
    return List.generate(40, (i) {
      final x = rng.nextDouble();
      final y = rng.nextDouble() * 0.5;
      final size = rng.nextDouble() * 2 + 0.5;
      return Positioned(
        left: x * width,
        top: y * 400,
        child: AnimatedBuilder(
          animation: _starCtrl,
          builder: (_, __) => Opacity(
            opacity: 0.3 +
                0.4 *
                    (math.sin(_starCtrl.value * math.pi * 2 + i)).abs(),
            child: Container(
              height: size,
              width: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.6),
                    blurRadius: size * 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildHeader(dynamic nightSafety, dynamic notifier) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary, size: 20),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.nightSafetyMode,
                    style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                Text(
                  DateTime.now().hour >= 20 || DateTime.now().hour <= 6
                      ? '🌙 Night mode recommended'
                      : 'Stealth safety tools',
                  style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: AppColors.textMuted),
                ),
              ]),
        ),
        AnimatedBuilder(
          animation: _moonCtrl,
          builder: (_, __) => Transform.rotate(
            angle: _moonCtrl.value * 0.1,
            child: const Text('🌙', style: TextStyle(fontSize: 28)),
          ),
        ),
      ]),
    );
  }

  Widget _buildNightModeCard(
      NightSafetyState nightSafety, NightSafetyProvider notifier, bool isActuallyNight) {
    final isActive = nightSafety.isNightModeActive;
    return GlassCard(
      borderRadius: 20,
      borderColor: isActive
          ? const Color(0xFF6B5CE7).withValues(alpha: 0.4)
          : Colors.white.withValues(alpha: 0.08),
      shadows: isActive
          ? [
              BoxShadow(
                color: const Color(0xFF6B5CE7).withValues(alpha: 0.15),
                blurRadius: 40,
                offset: const Offset(0, 16),
              )
            ]
          : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF6B5CE7).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.nights_stay_rounded,
                    color: isActive
                        ? const Color(0xFF6B5CE7)
                        : AppColors.textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context)!.nightMode,
                            style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        Text(
                          isActive
                              ? 'Enhanced protection active'
                              : 'Tap to enable night protection',
                          style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              color: isActive
                                  ? const Color(0xFF6B5CE7)
                                  : AppColors.textSecondary),
                        ),
                      ]),
                ),
                Switch(
                  value: isActive,
                  onChanged: (_) {
                    HapticFeedback.lightImpact();
                    notifier.toggle();
                  },
                  activeThumbColor: const Color(0xFF6B5CE7),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                ),
              ]),

              if (isActive) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B5CE7).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            const Color(0xFF6B5CE7).withValues(alpha: 0.2)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded,
                        color: Color(0xFF6B5CE7), size: 16),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sensor sensitivity increased · Auto-SOS armed · Guardians notified',
                        style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: Color(0xFF6B5CE7),
                            height: 1.4),
                      ),
                    ),
                  ]),
                ),
              ],

              if (isActuallyNight && !isActive) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            AppColors.accentAmber.withValues(alpha: 0.25)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.accentAmber, size: 16),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'It\'s night time — enabling Night Mode is recommended',
                        style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: AppColors.accentAmber,
                            height: 1.4),
                      ),
                    ),
                  ]),
                ),
              ],
            ]),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildEmergencyToolsCard(GuardianState guardian) {
    return GlassCard(
      borderRadius: 20,
      borderColor: AppColors.accentCrimson.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.emergency_rounded,
                    color: AppColors.accentCrimson, size: 18),
                SizedBox(width: 8),
                Text('Emergency Tools',
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ]),
              const SizedBox(height: 20),

              Row(children: [
                _emergencyTool(
                  icon: _sirenActive
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  label: _sirenActive ? 'Stop Siren' : 'Loud Siren',
                  color: AppColors.accentCrimson,
                  active: _sirenActive,
                  onTap: _toggleSiren,
                ),
                const SizedBox(width: 12),
                _emergencyTool(
                  icon: Icons.call_rounded,
                  label: 'Fake Call',
                  color: AppColors.accentTeal,
                  active: _fakeCallActive,
                  onTap: _triggerFakeCall,
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _emergencyTool(
                  icon: Icons.shield_outlined,
                  label: 'Silent SOS',
                  color: AppColors.accentAmber,
                  active: false,
                  onTap: _sendSilentSos,
                ),
                const SizedBox(width: 12),
                _emergencyTool(
                  icon: Icons.flashlight_on_rounded,
                  label: _flashlightActive ? 'Flash Off' : 'Strobe',
                  color: Colors.white70,
                  active: _flashlightActive,
                  onTap: () => _toggleFlashlight(),
                ),
              ]),

              const SizedBox(height: 20),

              NeonButton(
                label: 'SEND EMERGENCY SOS NOW',
                leadingIcon: Icons.warning_rounded,
                variant: NeonButtonVariant.danger,
                height: 54,
                onPressed: _sendSilentSos,
              ),
            ]),
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _emergencyTool({
    required IconData icon,
    required String label,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.07),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.25), blurRadius: 16)
                  ]
                : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                color: active ? color : AppColors.textSecondary, size: 26),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? color : AppColors.textSecondary),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Widget _buildSafeContactsCard(List<NightContact> contacts) {
    return GlassCard(
      borderRadius: 20,
      borderColor: AppColors.accentTeal.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.group_rounded,
                color: AppColors.accentTeal, size: 18),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.safeContacts,
                style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: _showAddContactSheet,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('+ Add',
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentTeal)),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          if (contacts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Row(children: [
                const Icon(Icons.person_add_outlined,
                    color: AppColors.textMuted, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No contacts added yet. Add trusted contacts to receive your SOS alerts.',
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.4),
                  ),
                ),
              ]),
            )
          else
            ...contacts.map((c) => _contactTile(c)),
        ]),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _contactTile(NightContact c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentTeal.withValues(alpha: 0.1),
            border: Border.all(
                color: AppColors.accentTeal.withValues(alpha: 0.2)),
          ),
          child: Center(
            child: Text(
              c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentTeal),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name,
                style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            Text(c.phone,
                style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: AppColors.textMuted)),
          ]),
        ),
        // Toggle
        Switch(
          value: c.enabled,
          onChanged: (_) =>
              ref.read(nightContactsProvider.notifier).toggleContact(c.id),
          activeThumbColor: AppColors.accentTeal,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        // Delete
        GestureDetector(
          onTap: () => ref
              .read(nightContactsProvider.notifier)
              .removeContact(c.id),
          child: Container(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.close_rounded,
                color: AppColors.textMuted.withValues(alpha: 0.5), size: 16),
          ),
        ),
      ]),
    );
  }

  Widget _buildSettingsCard(
      NightSettings settings, NightSettingsNotifier notifier) {
    return GlassCard(
      borderRadius: 20,
      borderColor: Colors.white.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.tune_rounded, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.nightSettings,
                style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 20),

          // Siren volume slider (persisted)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.volume_up_outlined,
                  color: AppColors.textSecondary, size: 15),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.sirenVolume,
                  style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: AppColors.textSecondary)),
              const Spacer(),
              Text('${settings.sirenVolume.toInt()}%',
                  style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentTeal)),
            ]),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.accentTeal,
                inactiveTrackColor:
                    AppColors.accentTeal.withValues(alpha: 0.15),
                thumbColor: AppColors.accentTeal,
                overlayColor: AppColors.accentTeal.withValues(alpha: 0.1),
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: settings.sirenVolume,
                min: 0,
                max: 100,
                onChanged: notifier.setSirenVolume,
              ),
            ),
          ]),

          const Divider(color: Colors.white12),
          const SizedBox(height: 4),

          // Auto SOS delay selector
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.timer_outlined,
                  color: AppColors.accentCrimson, size: 15),
              const SizedBox(width: 8),
              const Text('Auto-SOS delay',
                  style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: AppColors.textSecondary)),
              const Spacer(),
              DropdownButton<int>(
                value: settings.autoSosDelaySeconds,
                dropdownColor: AppColors.bgMid,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down,
                    color: AppColors.accentTeal, size: 18),
                items: const [
                  DropdownMenuItem(
                      value: 30,
                      child: Text('30s',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12))),
                  DropdownMenuItem(
                      value: 60,
                      child: Text('60s',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12))),
                  DropdownMenuItem(
                      value: 90,
                      child: Text('90s',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12))),
                  DropdownMenuItem(
                      value: 120,
                      child: Text('2 min',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12))),
                ],
                onChanged: (v) {
                  if (v != null) notifier.setAutoSosDelay(v);
                },
              ),
            ]),
          ]),

          const Divider(color: Colors.white12),
          const SizedBox(height: 4),

          _settingsTile(
            icon: Icons.security_rounded,
            title: 'Auto SOS on no response',
            subtitle:
                'Alert guardians after ${settings.autoSosDelaySeconds}s of no check-in',
            value: settings.autoSosOnNoResponse,
            onChanged: notifier.toggleAutoSos,
            color: AppColors.accentCrimson,
          ),
          const SizedBox(height: 8),
          _settingsTile(
            icon: Icons.visibility_off_rounded,
            title: 'Stealth Mode',
            subtitle: 'Hide SOS triggers from screen (silent)',
            value: settings.stealthMode,
            onChanged: notifier.toggleStealthMode,
            color: AppColors.accentAmber,
          ),
        ]),
      ),
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
  }) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          Text(subtitle,
              style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.3)),
        ]),
      ),
      Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: color,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ]);
  }


  Widget _buildSirenOverlay() {
    return AnimatedBuilder(
      animation: _sosCtrl,
      builder: (_, __) => Positioned.fill(
        child: IgnorePointer(
          ignoring: false,
          child: GestureDetector(
            onTap: _toggleSiren,
            child: Container(
              color: AppColors.accentCrimson
                  .withValues(alpha: 0.05 + 0.08 * _sosCtrl.value),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          AppColors.accentCrimson.withValues(alpha: 0.15),
                      border: Border.all(
                          color:
                              AppColors.accentCrimson.withValues(alpha: 0.6),
                          width: 2),
                    ),
                    child: const Icon(Icons.volume_up_rounded,
                        color: AppColors.accentCrimson, size: 60),
                  ),
                  const SizedBox(height: 24),
                  const Text('SIREN ACTIVE',
                      style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentCrimson,
                          letterSpacing: 3)),
                  const SizedBox(height: 8),
                  const Text('Tap anywhere to stop',
                      style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          color: AppColors.textSecondary)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Fake Call Dialog ─────────────────────────────────────────────────────────

class _FakeCallDialog extends StatefulWidget {
  final String callerName;
  final VoidCallback onEnd;

  const _FakeCallDialog({required this.callerName, required this.onEnd});

  @override
  State<_FakeCallDialog> createState() => _FakeCallDialogState();
}

class _FakeCallDialogState extends State<_FakeCallDialog>
    with TickerProviderStateMixin {
  late AnimationController _ringCtrl;
  bool _answered = false;
  int _callSeconds = 0;
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Play ringtone sound
    _playRingtone();

  }

  void _acceptCall() {
    if (!mounted) return;
    setState(() => _answered = true);
    HapticFeedback.lightImpact();
    _stopRingtone();
    _callTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _callSeconds++),
    );
  }

  Future<void> _playRingtone() async {
    FlutterRingtonePlayer().playRingtone(
      looping: true,
      volume: 1.0,
    );
  }

  Future<void> _stopRingtone() async {
    FlutterRingtonePlayer().stop();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _callTimer?.cancel();
    _stopRingtone();
    super.dispose();
  }

  String get _callTime {
    final m = _callSeconds ~/ 60;
    final s = _callSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: AppColors.accentTeal.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: AppColors.accentTeal.withValues(alpha: 0.15),
                blurRadius: 40),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _ringCtrl,
            builder: (_, __) => Transform.scale(
              scale: _answered ? 1.0 : 1.0 + 0.05 * _ringCtrl.value,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentTeal.withValues(alpha: 0.15),
                  border: Border.all(
                      color: AppColors.accentTeal.withValues(alpha: 0.4),
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accentTeal.withValues(alpha: 0.3),
                        blurRadius: 24),
                  ],
                ),
                child: const Center(
                  child: Text('👤', style: TextStyle(fontSize: 36)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.callerName,
              style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            _answered ? _callTime : 'Incoming call...',
            style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          if (!_answered)
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _callButton(Icons.call_end_rounded, AppColors.accentCrimson,
                  'Decline', widget.onEnd),
              _callButton(Icons.call_rounded, AppColors.accentTeal, 'Answer',
                  _acceptCall),
            ])
          else
            _callButton(Icons.call_end_rounded, AppColors.accentCrimson,
                'End Call', widget.onEnd),
        ]),
      ),
    );
  }

  Widget _callButton(
      IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 16)
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: AppColors.textSecondary)),
      ]),
    );
  }
}
