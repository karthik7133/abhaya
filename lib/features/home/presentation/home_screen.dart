import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/common_widgets/neon_button.dart';
import '../../../core/common_widgets/hold_to_sos_button.dart';
import '../../../core/providers/telemetry_provider.dart';
import '../../../core/services/backend_service.dart';
import '../../../core/services/fcm_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/night_safety_provider.dart';
import '../../../core/providers/service_availability_provider.dart';
import '../../../core/providers/battery_provider.dart';
import '../../../core/services/ble_service.dart';
import '../../journey/providers/journey_history_provider.dart';
import 'dart:convert';
import '../../../l10n/app_localizations.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _threatController;

  @override
  void initState() {
    super.initState();
    _threatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _threatController.forward();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.camera,
      Permission.microphone,
      Permission.sensors,
    ].request();
  }

  @override
  void dispose() {
    _threatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guardian = ref.watch(guardianProvider);
    final notifier = ref.read(guardianProvider.notifier);
    final fcmAlert = ref.watch(fcmAlertProvider);
    final nightSafety = ref.watch(nightSafetyProvider);
    final l10n = AppLocalizations.of(context)!;
    ref.watch(serviceAvailabilityProvider); // keep alive for banner in shell

    // ── Motion alert snackbar ──────────────────────────────────────────────
    ref.listen<GuardianState>(guardianProvider, (prev, next) {
      if (next.lastMotionAlert != null &&
          next.lastMotionAlert != prev?.lastMotionAlert) {
        final alert = next.lastMotionAlert!;
        // Clear immediately so this doesn't re-fire on next rebuild
        notifier.clearMotionAlert();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.accentCrimson,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(children: [
              const Icon(Icons.warning_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                '${alert.type == "impact" ? "⚡ Sudden Impact" : "🔄 Rapid Rotation"}: ${alert.magnitude.toStringAsFixed(1)} m/s²',
                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        );
      }
    });

    // ── Auto-dismiss FCM alert after 8 seconds ────────────────────────────
    ref.listen<FcmAlert?>(fcmAlertProvider, (prev, next) {
      if (next != null) {
        Future.delayed(const Duration(seconds: 8), () {
          if (mounted) {
            ref.read(fcmAlertProvider.notifier).state = null;
          }
        });
      }
    });

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
              // Ambient glow — shifts colour with threat level
              Positioned(
                top: -50, right: -70,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  height: 240, width: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      _threatColor(guardian).withValues(alpha: 0.12),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),

              Column(
                children: [
                  _buildAppBar(guardian, ref, nightSafety.isNightModeActive),
                  // ── FCM foreground alert banner ──────────────────────────
                  if (fcmAlert != null)
                    _FcmAlertBanner(
                      alert: fcmAlert,
                      onDismiss: () =>
                          ref.read(fcmAlertProvider.notifier).state = null,
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildThreatGauge(guardian, l10n),
                          const SizedBox(height: 16),
                          HoldToSosButton(
                            onTrigger: () {
                              // Trigger SOS on backend (sends FCM to guardians)
                              final tel = guardian.telemetry;
                              BackendService.triggerSos(
                                lat: tel.latitude,
                                lng: tel.longitude,
                              ).catchError((e) => debugPrint('[SOS] $e'));
                              // Mark emergency locally so UI reacts immediately
                              notifier.triggerEmergency(); // set emergency state
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildGuardianToggle(guardian, notifier, l10n),
                          const SizedBox(height: 16),
                          if (guardian.isActive) ...[
                            _buildTelemetryGrid(guardian, l10n).animate().fadeIn(duration: 400.ms),
                            const SizedBox(height: 16),
                          ],
                          _buildStatusGrid(guardian),
                          const SizedBox(height: 16),
                          _buildQuickActions(context, l10n),
                        ],
                      ),
                    ),
                  ),

                ],
              ),

              // ── Phase 3: Emergency Overlay ──────────────────────────────
              if (guardian.isEmergency)
                _buildEmergencyOverlay(guardian, notifier),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(GuardianState guardian, WidgetRef ref, bool isNightModeActive) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ABHAYA', style: TextStyle(
              fontFamily: 'PlusJakartaSans', fontSize: 22,
              fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 3,
            )),
            Row(children: [
              Text(
                guardian.isEmergency
                    ? l10n.sosDispatchActive
                    : guardian.isActive ? l10n.guardianActive : l10n.guardianOffline,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w500,
                  color: guardian.isEmergency 
                      ? AppColors.accentCrimson
                      : guardian.isActive ? AppColors.accentTeal : AppColors.textMuted,
                ),
              ),
              if (isNightModeActive) ...[
                const SizedBox(width: 6),
                const Text('🌙', style: TextStyle(fontSize: 11)),
              ],
            ]),
          ]),
          const Spacer(),

          // Status chip
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: guardian.isEmergency
                  ? AppColors.accentCrimson.withValues(alpha: 0.12)
                  : guardian.isActive
                      ? AppColors.accentTeal.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: guardian.isEmergency
                    ? AppColors.accentCrimson.withValues(alpha: 0.4)
                    : guardian.isActive
                        ? AppColors.accentTeal.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(height: 7, width: 7, decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: guardian.isEmergency 
                    ? AppColors.accentCrimson 
                    : guardian.isActive ? AppColors.accentTeal : AppColors.textMuted,
                boxShadow: guardian.isEmergency || guardian.isActive ? [BoxShadow(
                  color: guardian.isEmergency ? AppColors.accentCrimson.withValues(alpha: 0.8) : AppColors.accentTeal.withValues(alpha: 0.8), 
                  blurRadius: 6,
                )] : [],
              )),
              const SizedBox(width: 6),
              Text(
                guardian.isEmergency ? 'SOS ACTIVE' : guardian.isActive ? 'ACTIVE' : 'IDLE',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: guardian.isEmergency 
                      ? AppColors.accentCrimson 
                      : guardian.isActive ? AppColors.accentTeal : AppColors.textMuted,
                ),
              ),
            ]),
          ),

          const SizedBox(width: 10),

          // User avatar + navigation to profile
          GestureDetector(
            onTap: () {
              context.go('/profile');
            },
            child: Tooltip(
              message: 'Profile (${user?.displayName ?? user?.email ?? "user"})',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accentTeal.withValues(alpha: 0.15),
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person_outline, color: AppColors.accentTeal, size: 18)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Threat colour helper ───────────────────────────────────────────────────
  Color _threatColor(GuardianState g) {
    if (!g.isActive) return AppColors.bgSurface;
    if (g.threatScore >= 90) return AppColors.accentCrimson;
    if (g.threatScore >= 75) return AppColors.accentAmber;
    return AppColors.accentTeal;
  }

  Widget _buildThreatGauge(GuardianState guardian, AppLocalizations l10n) {
    final score = guardian.isActive ? (guardian.threatScore / 100.0).clamp(0.0, 1.0) : 0.0;
    final accent = _threatColor(guardian);
    final label  = guardian.isActive
        ? (guardian.threatScore >= 90
            ? 'CRITICAL'
            : guardian.threatScore >= 75
                ? 'ELEVATED'
                : 'SAFE')
        : 'OFFLINE';
    return GlassCard(
      borderRadius: 20,
      borderColor: accent.withValues(alpha: 0.25),
      shadows: guardian.isActive ? [
        BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 16)),
      ] : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Row(children: [
            Flexible(
              child: Text(l10n.threatAndMood, style: const TextStyle(
                fontFamily: 'PlusJakartaSans', fontSize: 14,
                fontWeight: FontWeight.w700, color: AppColors.textPrimary,
              )),
            ),
            const SizedBox(width: 8),
            // Mood chip
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('🌿 CALM', style: TextStyle(
                fontFamily: 'PlusJakartaSans', fontSize: 9,
                fontWeight: FontWeight.w700, color: AppColors.accentTeal, letterSpacing: 0.8,
              )),
            ),
            const SizedBox(width: 6),
            // Threat status chip
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(label, style: TextStyle(
                fontFamily: 'PlusJakartaSans', fontSize: 9,
                fontWeight: FontWeight.w700, color: accent, letterSpacing: 1.2,
              )),
            ),
          ]),

          const SizedBox(height: 20),
          Row(children: [
            SizedBox(
              height: 120, width: 120,
              child: CustomPaint(
                painter: _ThreatGaugePainter(
                  progress:    score,
                  accentColor: accent,
                ),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '${guardian.threatScore.toInt()}',
                      key: ValueKey(guardian.threatScore.toInt()),
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans', fontSize: 34,
                        fontWeight: FontWeight.w800, color: accent, height: 1,
                      ),
                    ),
                  ),
                  const Text('%', style: TextStyle(
                    fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary,
                  )),
                ])),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(child: Column(children: [
              _signalRow('Audio Distress', guardian.isActive ? 0.05 : 0.0, AppColors.accentTeal),
              const SizedBox(height: 10),
              _signalRow('Motion', guardian.isActive
                  ? ((guardian.lastMotionAlert != null ? 0.6 : 0.08)) : 0.0, AppColors.accentAmber),
              const SizedBox(height: 10),
              _signalRow('Location Risk', guardian.isActive ? (guardian.threatScore / 200) : 0.0, AppColors.accentTeal),
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final ble = ref.watch(bleProvider);
                final hrValue = ble.isConnected && ble.heartRate != null
                    ? (ble.heartRate! / 200.0).clamp(0.0, 1.0)
                    : guardian.isActive
                        ? (DateTime.now().hour >= 22 || DateTime.now().hour <= 5 ? 1.0 : 0.15)
                        : 0.0;
                final label = ble.isConnected ? 'Heart Rate ❤️' : 'Time Context';
                return _signalRow(label, hrValue, AppColors.accentAmber);
              }),
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final ble = ref.watch(bleProvider);
                final stepsValue = ble.steps != null
                    ? (ble.steps! % 10000 / 10000.0).clamp(0.0, 1.0)
                    : 0.0;
                final label = ble.steps != null ? 'Steps 👣 ${ble.steps}' : 'Steps';
                return _signalRow(label, stepsValue, AppColors.accentTeal);
              }),
            ])),
          ]),
        ]),
      ),
    );
  }

  Widget _signalRow(String label, double value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
        fontFamily: 'PlusJakartaSans', fontSize: 11, color: AppColors.textSecondary,
      )),
      const SizedBox(height: 4),
      AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value, minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.07),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ),
    ]);
  }

  Widget _buildGuardianToggle(GuardianState guardian, GuardianNotifier notifier, AppLocalizations l10n) {
    final isStarting = guardian.status == GuardianStatus.starting;
    return GlassCard(
      borderRadius: 20,
      borderColor: guardian.isActive
          ? AppColors.accentTeal.withValues(alpha: 0.35)
          : Colors.white.withValues(alpha: 0.1),
      shadows: guardian.isActive ? [
        BoxShadow(color: AppColors.accentTeal.withValues(alpha: 0.1), blurRadius: 40, offset: const Offset(0, 16)),
        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8)),
      ] : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              height: 44, width: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: (guardian.isActive ? AppColors.accentTeal : AppColors.textMuted).withValues(alpha: 0.1),
              ),
              child: Icon(
                guardian.isActive ? Icons.radar : Icons.sensors_off_outlined,
                color: guardian.isActive ? AppColors.accentTeal : AppColors.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                guardian.isActive ? l10n.guardianActive : l10n.guardianOffline,
                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Text(
                guardian.isActive
                    ? 'GPS · Accelerometer · Gyroscope live'
                    : 'Tap below to enable sensor monitoring',
                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textSecondary),
              ),
            ])),
          ]),

          if (guardian.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentCrimson.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accentCrimson.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.accentCrimson, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(guardian.errorMessage!, style: const TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.accentCrimson,
                ))),
              ]),
            ),
          ],

          const SizedBox(height: 16),
          NeonButton(
            label: guardian.isActive
                ? 'DEACTIVATE GUARDIAN'
                : isStarting ? 'INITIALIZING...' : 'INITIATE TRACKING',
            isLoading: isStarting,
            variant: guardian.isActive ? NeonButtonVariant.danger : NeonButtonVariant.primary,
            leadingIcon: guardian.isActive ? Icons.stop_circle_outlined : Icons.play_circle_outlined,
            onPressed: isStarting ? null : () async {
              if (guardian.isActive) {
                await notifier.stopGuardian();
              } else {
                await notifier.startGuardian();
                final updatedGuardian = ref.read(guardianProvider);
                if (updatedGuardian.status == GuardianStatus.error && mounted) {
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
                        Text('Action Required', style: TextStyle(color: Colors.white, fontFamily: 'PlusJakartaSans')),
                      ]),
                      content: Text(
                        updatedGuardian.errorMessage ?? 'Please enable location access to initiate tracking.',
                        style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'PlusJakartaSans'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (updatedGuardian.errorMessage!.contains('permission')) {
                              openAppSettings();
                            } else {
                              Geolocator.openLocationSettings();
                            }
                          },
                          child: const Text('Open Settings', style: TextStyle(color: AppColors.accentTeal, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildTelemetryGrid(GuardianState guardian, AppLocalizations l10n) {
    final t = guardian.telemetry;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.liveTelemetry, style: const TextStyle(
        fontFamily: 'PlusJakartaSans', fontSize: 15,
        fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      )),
      const SizedBox(height: 12),
      GlassCard(
        borderRadius: 16,
        borderColor: AppColors.accentTeal.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _telemetryRow(Icons.location_on_outlined, 'Position',
              t.hasLocation ? t.locationFormatted : 'Acquiring GPS...', AppColors.accentTeal),
            const SizedBox(height: 12),
            _telemetryRow(Icons.speed_outlined, 'Speed', t.speedFormatted, AppColors.accentAmber),
            const SizedBox(height: 12),
            _telemetryRow(Icons.terrain_outlined, 'Altitude',
              t.altitude != null ? '${t.altitude!.toStringAsFixed(0)} m' : '--', AppColors.accentTeal),
            const SizedBox(height: 12),
            _telemetryRow(Icons.gps_fixed_outlined, 'Accuracy',
              t.accuracy != null ? '±${t.accuracy!.toStringAsFixed(0)} m' : '--', AppColors.textSecondary),
          ]),
        ),
      ),
    ]);
  }

  Widget _telemetryRow(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(
        fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary,
      )),
      const Spacer(),
      Text(value, style: TextStyle(
        fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w600, color: color,
      )),
    ]);
  }

  Widget _buildStatusGrid(GuardianState guardian) {
    final t = guardian.telemetry;
    final battery = ref.watch(batteryProvider);
    final battColor = battery.level > 50
        ? AppColors.accentTeal
        : battery.level > 20
            ? AppColors.accentAmber
            : AppColors.accentCrimson;
    final stats = [
      _Stat(
        'Location',
        t.hasLocation ? 'Active' : 'Offline',
        '',
        Icons.location_on_outlined,
        t.hasLocation ? AppColors.accentTeal : AppColors.textMuted,
      ),
      _Stat(
        'Speed',
        t.speed != null ? (t.speed! * 3.6).toStringAsFixed(1) : '--',
        t.speed != null ? 'km/h' : '',
        Icons.speed_outlined,
        t.speed != null ? AppColors.accentAmber : AppColors.textMuted,
      ),
      _Stat(
        'Battery',
        '${battery.level}',
        '%${battery.isCharging ? " ⚡" : ""}',
        battery.isCharging ? Icons.battery_charging_full_rounded : Icons.battery_std_rounded,
        battColor,
      ),
      _Stat(
        'Accuracy',
        t.accuracy != null ? '±${t.accuracy!.toStringAsFixed(0)}' : '--',
        t.accuracy != null ? 'm' : '',
        Icons.gps_fixed_outlined,
        t.accuracy != null
            ? (t.accuracy! < 10 ? AppColors.accentTeal : AppColors.accentAmber)
            : AppColors.textMuted,
      ),
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
      children: stats.map((s) => GlassCard(
        borderRadius: 16, borderColor: s.color.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(s.icon, color: s.color, size: 20),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(s.value, style: TextStyle(
                    fontFamily: 'PlusJakartaSans', fontSize: 22,
                    fontWeight: FontWeight.w800, color: s.color, height: 1,
                  )),
                  const SizedBox(width: 3),
                  if (s.unit.isNotEmpty) Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(s.unit, style: const TextStyle(
                      fontFamily: 'PlusJakartaSans', fontSize: 11, color: AppColors.textSecondary,
                    )),
                  ),
                ]),
                Text(s.label, style: const TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 11,
                  color: AppColors.textSecondary, fontWeight: FontWeight.w500,
                )),
              ]),
            ],
          ),
        ),
      )).toList(),
    );
  }


  Widget _buildQuickActions(BuildContext context, AppLocalizations l10n) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.quickActions, style: const TextStyle(
        fontFamily: 'PlusJakartaSans', fontSize: 15,
        fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      )),
      const SizedBox(height: 12),
      Row(children: [
        _actionTile(
          icon: Icons.chat_bubble_outline,
          label: 'Companion',
          color: AppColors.accentTeal,
          onTap: () => context.push('/ai-assistant'),
        ),
        const SizedBox(width: 12),
        _actionTile(
          icon: Icons.route_outlined,
          label: l10n.safeRoute,
          color: AppColors.accentAmber,
          onTap: () => context.push('/safe-route'),
        ),
        const SizedBox(width: 12),
        _actionTile(
          icon: Icons.history_outlined,
          label: l10n.recent,
          color: AppColors.textSecondary,
          onTap: () => context.push('/incident-history'),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _actionTile(
          icon: Icons.school_outlined,
          label: l10n.safetyLearning,
          color: AppColors.textSecondary,
          onTap: () => context.push('/safety-learning'),
        ),
        const SizedBox(width: 12),
        _actionTile(
          icon: Icons.privacy_tip_outlined,
          label: l10n.privacy,
          color: AppColors.textSecondary,
          onTap: () => context.push('/privacy-settings'),
        ),
        const SizedBox(width: 12),
        _actionTile(
          icon: Icons.nights_stay_outlined,
          label: l10n.nightMode,
          color: AppColors.accentTeal,
          onTap: () => context.push('/night-mode'),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _actionTile(
          icon: Icons.history_edu_rounded,
          label: 'Journeys',
          color: AppColors.accentAmber,
          onTap: () {
            context.push('/journey-history');
          },
        ),
        const SizedBox(width: 12),
        _actionTile(
          icon: Icons.report_problem_outlined,
          label: 'Report',
          color: AppColors.accentCrimson,
          onTap: () => context.push('/incident-report'),
        ),
        const SizedBox(width: 12),
        const Expanded(child: SizedBox.shrink()),
      ]),
    ]);
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          borderRadius: 16, borderColor: color.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(
                fontFamily: 'PlusJakartaSans', fontSize: 11,
                fontWeight: FontWeight.w600, color: AppColors.textSecondary,
              )),
            ]),
          ),
        ),
      ),
    );
  }


  // ── Phase 3: Emergency Overlay ───────────────────────────────────────────────
  Widget _buildEmergencyOverlay(GuardianState guardian, GuardianNotifier notifier) {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: GlassCard(
                borderRadius: 28,
                borderColor: AppColors.accentCrimson.withValues(alpha: 0.6),
                shadows: [
                  BoxShadow(
                    color: AppColors.accentCrimson.withValues(alpha: 0.3),
                    blurRadius: 60, spreadRadius: 4,
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsing icon
                      Container(
                        height: 80, width: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentCrimson.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.accentCrimson.withValues(alpha: 0.6),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.accentCrimson,
                          size: 40,
                        ),
                      ).animate(onPlay: (c) => c.repeat())
                        .scaleXY(end: 1.08, duration: 700.ms, curve: Curves.easeInOut)
                        .then()
                        .scaleXY(end: 1.0,  duration: 700.ms, curve: Curves.easeInOut),

                      const SizedBox(height: 20),
                      Text(AppLocalizations.of(context)!.emergencyDetected, style: const TextStyle(
                        fontFamily: 'PlusJakartaSans', fontSize: 20,
                        fontWeight: FontWeight.w800, color: AppColors.accentCrimson,
                        letterSpacing: 1.5,
                      )),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.aiDetectedThreat,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans', fontSize: 13,
                          color: AppColors.textSecondary, height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      NeonButton(
                        label: AppLocalizations.of(context)!.activateEmergencySos,
                        variant: NeonButtonVariant.danger,
                        height: 52,
                        leadingIcon: Icons.warning_rounded,
                        onPressed: () {
                          final tel = guardian.telemetry;
                          BackendService.triggerSos(
                            lat: tel.latitude,
                            lng: tel.longitude,
                          ).catchError((e) => debugPrint('[SOS] $e'));
                          notifier.dismissEmergency();
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.accentCrimson,
                                behavior: SnackBarBehavior.floating,
                                content: Row(children: [
                                  const Icon(Icons.bolt, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(AppLocalizations.of(context)!.sosDispatched,
                                    style: const TextStyle(color: Colors.white, fontFamily: 'PlusJakartaSans')),
                                ]),
                              ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      NeonButton(
                        label: AppLocalizations.of(context)!.imSafeDismiss,
                        variant: NeonButtonVariant.ghost,
                        height: 48,
                        onPressed: notifier.dismissEmergency,
                      ),
                    ],
                  ),
                ),
              ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat {
  final String label, value, unit;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.unit, this.icon, this.color);
}

class _ThreatGaugePainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  const _ThreatGaugePainter({required this.progress, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const start = -math.pi * 0.8;
    const sweep = math.pi * 1.6;
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, bg);
    if (progress > 0) {
      final fg = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep * progress, false, fg);
      final glow = Paint()
        ..color = accentColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep * progress, false, glow);
    }
  }

  @override
  bool shouldRepaint(_ThreatGaugePainter old) =>
      old.progress != progress || old.accentColor != accentColor;
}

// ─── FCM Foreground Alert Banner ──────────────────────────────────────────────

class _FcmAlertBanner extends StatelessWidget {
  final FcmAlert alert;
  final VoidCallback onDismiss;

  const _FcmAlertBanner({required this.alert, required this.onDismiss});

  Color get _color {
    switch (alert.type) {
      case FcmAlertType.sos:
        return AppColors.accentCrimson;
      case FcmAlertType.threat:
      case FcmAlertType.guardian:
        return AppColors.accentAmber;
      case FcmAlertType.system:
        return AppColors.accentTeal;
    }
  }

  IconData get _icon {
    switch (alert.type) {
      case FcmAlertType.sos:
        return Icons.emergency_rounded;
      case FcmAlertType.threat:
        return Icons.warning_amber_rounded;
      case FcmAlertType.guardian:
        return Icons.shield_outlined;
      case FcmAlertType.system:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.40)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        Icon(_icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.title,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (alert.body.isNotEmpty)
                Text(
                  alert.body,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onDismiss,
          child: Icon(Icons.close, color: color.withValues(alpha: 0.7), size: 18),
        ),
      ]),
    )
        .animate()
        .slideY(begin: -0.5, end: 0, duration: 350.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 300.ms);
  }
}
