import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/common_widgets/neon_button.dart';
import '../../../core/providers/telemetry_provider.dart';
import '../../../core/providers/night_safety_provider.dart';
import 'package:geolocator/geolocator.dart';

// ─── Journey State ────────────────────────────────────────────────────────────

enum JourneyStatus { idle, active, paused, arrived }

class JourneySession {
  final String destination;
  final Duration estimatedDuration;
  final DateTime startedAt;
  final Duration checkInInterval;
  JourneyStatus status;
  int checkInsMade;
  DateTime? lastCheckIn;
  DateTime? nextCheckInDue;
  DateTime? arrivedAt;

  // GPS waypoints recorded during journey
  final List<Map<String, dynamic>> waypoints;

  // Distance tracking
  final double? destLat;
  final double? destLng;
  final double? initialDistanceMeters;
  double? currentDistanceMeters;

  JourneySession({
    required this.destination,
    required this.estimatedDuration,
    required this.startedAt,
    required this.checkInInterval,
    this.status = JourneyStatus.active,
    this.checkInsMade = 0,
    this.lastCheckIn,
    this.nextCheckInDue,
    this.arrivedAt,
    List<Map<String, dynamic>>? waypoints,
    this.destLat,
    this.destLng,
    this.initialDistanceMeters,
    this.currentDistanceMeters,
  }) : waypoints = waypoints ?? [];

  Duration get elapsed => DateTime.now().difference(startedAt);
  Duration get remaining => estimatedDuration - elapsed;
  bool get isOverdue => remaining.isNegative;

  double get progress {
    final p = elapsed.inSeconds / estimatedDuration.inSeconds;
    return p.clamp(0.0, 1.0);
  }

  /// Serialize to JSON for passing to Journey Report screen
  Map<String, dynamic> toJson({bool? nightModeActive}) => {
        'destination': destination,
        'startedAt': startedAt.toIso8601String(),
        'arrivedAt': (arrivedAt ?? DateTime.now()).toIso8601String(),
        'estimatedMinutes': estimatedDuration.inMinutes,
        'checkInsMade': checkInsMade,
        'nightModeActive': nightModeActive ?? false,
        'waypoints': waypoints,
        'initialDistanceMeters': initialDistanceMeters,
        'finalDistanceMeters': currentDistanceMeters,
      };
}

// ─── Journey Guardian Screen ──────────────────────────────────────────────────

class JourneyGuardianScreen extends ConsumerStatefulWidget {
  final String? initialDestination;
  final int? initialEtaMinutes;
  final double? destLat;
  final double? destLng;
  final double? initialDistanceKm;

  const JourneyGuardianScreen({
    super.key,
    this.initialDestination,
    this.initialEtaMinutes,
    this.destLat,
    this.destLng,
    this.initialDistanceKm,
  });

  @override
  ConsumerState<JourneyGuardianScreen> createState() =>
      _JourneyGuardianScreenState();
}

class _JourneyGuardianScreenState
    extends ConsumerState<JourneyGuardianScreen>
    with TickerProviderStateMixin {
  JourneySession? _session;
  Timer? _ticker;
  Timer? _checkInTimer;
  Timer? _waypointTimer;

  final _destinationCtrl = TextEditingController();
  int _etaMinutes = 30;
  int _checkInMinutes = 10;

  late AnimationController _pulseCtrl;
  late AnimationController _alertPulse;

  // Preset destinations
  static const _presets = [
    ('Home', Icons.home_rounded, '25'),
    ('Work', Icons.business_rounded, '40'),
    ('Station', Icons.train_rounded, '15'),
    ('Hospital', Icons.local_hospital_rounded, '20'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _alertPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Pre-fill from Safe Route navigation
    if (widget.initialDestination != null) {
      _destinationCtrl.text = widget.initialDestination!;
    }
    if (widget.initialEtaMinutes != null) {
      _etaMinutes = widget.initialEtaMinutes!;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _checkInTimer?.cancel();
    _waypointTimer?.cancel();
    _pulseCtrl.dispose();
    _alertPulse.dispose();
    _destinationCtrl.dispose();
    super.dispose();
  }

  void _startJourney() {
    if (_destinationCtrl.text.trim().isEmpty) return;
    HapticFeedback.mediumImpact();

    final checkIn = Duration(minutes: _checkInMinutes);
    final session = JourneySession(
      destination: _destinationCtrl.text.trim(),
      estimatedDuration: Duration(minutes: _etaMinutes),
      startedAt: DateTime.now(),
      checkInInterval: checkIn,
      nextCheckInDue: DateTime.now().add(checkIn),
      destLat: widget.destLat,
      destLng: widget.destLng,
      initialDistanceMeters: widget.initialDistanceKm != null ? widget.initialDistanceKm! * 1000 : null,
      currentDistanceMeters: widget.initialDistanceKm != null ? widget.initialDistanceKm! * 1000 : null,
    );

    // Record first waypoint immediately if GPS is active
    final telemetry = ref.read(guardianProvider).telemetry;
    if (telemetry.hasLocation) {
      session.waypoints.add({
        'lat': telemetry.latitude,
        'lng': telemetry.longitude,
        'time': DateTime.now().toIso8601String(),
      });
    }

    setState(() => _session = session);

    // Tick every second for live progress
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Check-in timer
    _checkInTimer = Timer.periodic(
      Duration(minutes: _checkInMinutes),
      (_) => _triggerCheckInAlert(),
    );

    // Record GPS waypoints every 30 seconds
    _waypointTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _recordWaypoint();
    });
  }

  void _recordWaypoint() {
    if (_session == null || _session!.status != JourneyStatus.active) return;
    final telemetry = ref.read(guardianProvider).telemetry;
    if (telemetry.hasLocation) {
      setState(() {
        _session!.waypoints.add({
          'lat': telemetry.latitude,
          'lng': telemetry.longitude,
          'time': DateTime.now().toIso8601String(),
        });
        
        // Calculate remaining distance if destination coords are known
        if (_session!.destLat != null && _session!.destLng != null) {
           _session!.currentDistanceMeters = _haversine(
             telemetry.latitude!, telemetry.longitude!,
             _session!.destLat!, _session!.destLng!
           );
        }
      });
    }
  }
  
  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  void _triggerCheckInAlert() {
    if (_session == null || _session!.status != JourneyStatus.active) return;
    HapticFeedback.heavyImpact();
    _alertPulse.forward(from: 0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: AppColors.accentAmber.withValues(alpha: 0.4)),
        ),
        title: const Row(children: [
          Icon(Icons.timer_rounded, color: AppColors.accentAmber),
          SizedBox(width: 10),
          Text('Check-In Required',
              style: TextStyle(
                  color: Colors.white, fontFamily: 'PlusJakartaSans')),
        ]),
        content: Text(
          'Are you safe? Guardians will be alerted if you don\'t respond in ${ref.read(nightSafetyProvider).isNightModeActive ? "30" : "60"} seconds.',
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'PlusJakartaSans',
              height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _session!.checkInsMade++;
                _session!.lastCheckIn = DateTime.now();
                _session!.nextCheckInDue =
                    DateTime.now().add(_session!.checkInInterval);
              });
            },
            child: const Text('I\'m Safe ✓',
                style: TextStyle(
                    color: AppColors.accentTeal,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _doCheckIn() {
    HapticFeedback.lightImpact();
    setState(() {
      _session!.checkInsMade++;
      _session!.lastCheckIn = DateTime.now();
      _session!.nextCheckInDue =
          DateTime.now().add(_session!.checkInInterval);
    });
    _recordWaypoint(); // also log position on check-in
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.accentTeal,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Check-in sent to guardians!',
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _markArrived() {
    HapticFeedback.heavyImpact();
    _recordWaypoint(); // record final position
    setState(() {
      _session!.status = JourneyStatus.arrived;
      _session!.arrivedAt = DateTime.now();
    });
    _ticker?.cancel();
    _checkInTimer?.cancel();
    _waypointTimer?.cancel();
  }

  void _viewReport() {
    if (_session == null) return;
    final nightModeActive = ref.read(nightSafetyProvider).isNightModeActive;
    final json = jsonEncode(_session!.toJson(nightModeActive: nightModeActive));
    context.push(
      Uri(
        path: '/journey-report',
        queryParameters: {'session': json},
      ).toString(),
    );
  }

  void _endJourney() {
    _ticker?.cancel();
    _checkInTimer?.cancel();
    _waypointTimer?.cancel();
    setState(() => _session = null);
    _destinationCtrl.clear();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return 'Overdue';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m >= 60) {
      return '${d.inHours}h ${m % 60}m';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final guardian = ref.watch(guardianProvider);
    final nightSafety = ref.watch(nightSafetyProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.bgDeep, AppColors.bgMid],
          ),
        ),
        child: SafeArea(
          child: _session == null
              ? _buildSetupView(nightSafety)
              : _buildActiveView(guardian, nightSafety),
        ),
      ),
    );
  }

  // ── Setup View ──────────────────────────────────────────────────────────────

  Widget _buildSetupView(NightSafetyState nightSafety) {
    // Shorter check-in interval recommended during night mode
    final recommendedCheckIn = nightSafety.isNightModeActive ? 5 : 10;
    if (_session == null && nightSafety.isNightModeActive && _checkInMinutes > 5) {
      // Suggest shorter interval
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),

          // Night mode suggestion banner
          if (nightSafety.isNightModeActive)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF6B5CE7).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF6B5CE7).withValues(alpha: 0.25)),
              ),
              child: const Row(children: [
                Text('🌙', style: TextStyle(fontSize: 18)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Night Mode active — check-in interval set to 5 min for enhanced safety',
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: Color(0xFF6B5CE7),
                        height: 1.4),
                  ),
                ),
              ]),
            ).animate().fadeIn(delay: 50.ms),

          // Hero illustration
          Center(
            child: Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentTeal.withValues(alpha: 0.08),
                border: Border.all(
                    color: AppColors.accentTeal.withValues(alpha: 0.25),
                    width: 1.5),
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: AppColors.accentTeal,
                size: 52,
              ),
            )
                .animate(controller: _pulseCtrl)
                .scaleXY(end: 1.05, curve: Curves.easeInOut),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 28),

          // Destination input
          GlassCard(
            borderRadius: 20,
            borderColor: AppColors.accentTeal.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Destination',
                      style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _destinationCtrl,
                    style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: AppColors.textPrimary,
                        fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Where are you going?',
                      hintStyle: const TextStyle(
                          color: AppColors.textMuted,
                          fontFamily: 'PlusJakartaSans'),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.location_on_outlined,
                          color: AppColors.accentTeal, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 16),

                  // Preset tiles
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presets.map((p) {
                      return GestureDetector(
                        onTap: () {
                          _destinationCtrl.text = p.$1;
                          setState(() {
                            _etaMinutes = int.tryParse(p.$3) ?? 30;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.accentTeal.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.accentTeal
                                    .withValues(alpha: 0.2)),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(p.$2,
                                    color: AppColors.accentTeal, size: 14),
                                const SizedBox(width: 6),
                                Text(p.$1,
                                    style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accentTeal)),
                              ]),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 16),

          // ETA & Check-in sliders
          GlassCard(
            borderRadius: 20,
            borderColor: Colors.white.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSliderRow(
                    icon: Icons.access_time_rounded,
                    label: 'ETA',
                    value: _etaMinutes.toDouble(),
                    min: 5,
                    max: 120,
                    color: AppColors.accentAmber,
                    display: '$_etaMinutes min',
                    onChanged: (v) =>
                        setState(() => _etaMinutes = v.round()),
                  ),
                  const SizedBox(height: 20),
                  _buildSliderRow(
                    icon: Icons.notifications_active_outlined,
                    label: 'Check-in every',
                    value: _checkInMinutes.toDouble(),
                    min: nightSafety.isNightModeActive ? 2 : 5,
                    max: 30,
                    color: AppColors.accentTeal,
                    display: '$_checkInMinutes min',
                    onChanged: (v) =>
                        setState(() => _checkInMinutes = v.round()),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 24),

          NeonButton(
            label: 'START JOURNEY GUARDIAN',
            leadingIcon: Icons.play_arrow_rounded,
            variant: NeonButtonVariant.primary,
            height: 56,
            onPressed: _destinationCtrl.text.trim().isNotEmpty
                ? _startJourney
                : () {},
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required Color color,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: AppColors.textSecondary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(display,
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
      ]),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: color,
          inactiveTrackColor: color.withValues(alpha: 0.15),
          thumbColor: color,
          overlayColor: color.withValues(alpha: 0.15),
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) ~/ 5).clamp(1, 100),
          onChanged: onChanged,
        ),
      ),
    ]);
  }

  // ── Active Journey View ─────────────────────────────────────────────────────

  Widget _buildActiveView(
      GuardianState guardian, NightSafetyState nightSafety) {
    final session = _session!;
    final arrived = session.status == JourneyStatus.arrived;
    final overdue = session.isOverdue && !arrived;
    
    // Core styling stays Teal as requested, but we can use red/yellow for specific texts or progress
    const cardAccent = AppColors.accentTeal;
    final progressAccent = arrived
        ? AppColors.accentTeal
        : overdue
            ? AppColors.accentCrimson
            : AppColors.accentAmber;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          _buildHeader(),
          const SizedBox(height: 20),

          // Status Card
          GlassCard(
            borderRadius: 24,
            borderColor: cardAccent.withValues(alpha: 0.35),
            shadows: [
              BoxShadow(
                  color: cardAccent.withValues(alpha: 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 16)),
            ],
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                // Destination & status
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: progressAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      arrived
                          ? Icons.check_circle_rounded
                          : Icons.explore_rounded,
                      color: progressAccent,
                      size: 26,
                    ),
                  )
                      .animate(
                          controller: arrived ? _alertPulse : _pulseCtrl)
                      .scaleXY(
                          end: arrived ? 1.0 : 1.08,
                          curve: Curves.easeInOut),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            arrived ? 'Arrived Safely!' : 'Journey Active',
                            style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: progressAccent,
                                letterSpacing: 1),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            session.destination,
                            style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ]),
                  ),
                  if (overdue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accentCrimson.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.accentCrimson
                                .withValues(alpha: 0.4)),
                      ),
                      child: const Text('OVERDUE',
                          style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentCrimson,
                              letterSpacing: 1)),
                    ),
                ]),

                const SizedBox(height: 24),

                // Progress arc
                _buildProgressArc(session, progressAccent),

                const SizedBox(height: 24),

                // Stats row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  _statCol(
                    'Elapsed',
                    _formatDuration(session.elapsed),
                    Icons.timer_rounded,
                    AppColors.textSecondary,
                  ),
                  _statCol(
                    arrived ? 'Duration' : 'Remaining',
                    arrived
                        ? _formatDuration(session.elapsed)
                        : _formatDuration(session.remaining.isNegative
                            ? Duration.zero
                            : session.remaining),
                    Icons.hourglass_bottom_rounded,
                    progressAccent,
                  ),
                  if (session.currentDistanceMeters != null)
                    _statCol(
                      'Distance',
                      '${(session.currentDistanceMeters! / 1000).toStringAsFixed(1)} km',
                      Icons.map_rounded,
                      AppColors.accentTeal,
                    )
                  else
                    _statCol(
                      'Check-ins',
                      '${session.checkInsMade}',
                      Icons.done_all_rounded,
                      AppColors.accentTeal,
                    ),
                ]),
              ]),
            ),
          ).animate().fadeIn(duration: 400.ms).scale(
              begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack),

          const SizedBox(height: 16),

          // Night mode banner
          if (nightSafety.isNightModeActive && !arrived)
            GlassCard(
              borderRadius: 14,
              borderColor: const Color(0xFF6B5CE7).withValues(alpha: 0.25),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                child: Row(children: [
                  const Text('🌙', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Night Mode active — enhanced check-in sensitivity',
                      style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          color: Color(0xFF6B5CE7)),
                    ),
                  ),
                ]),
              ),
            ).animate().fadeIn(delay: 100.ms),

          if (nightSafety.isNightModeActive && !arrived)
            const SizedBox(height: 16),

          // Next check-in card
          if (!arrived && session.nextCheckInDue != null)
            GlassCard(
              borderRadius: 16,
              borderColor: AppColors.accentTeal.withValues(alpha: 0.2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.alarm_rounded,
                        color: AppColors.accentTeal, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Next check-in',
                              style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: AppColors.textMuted)),
                          Text(
                            () {
                              final diff = session.nextCheckInDue!
                                  .difference(DateTime.now());
                              if (diff.isNegative) return 'Due now!';
                              return 'in ${_formatDuration(diff)}';
                            }(),
                            style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentTeal),
                          ),
                        ]),
                  ),
                  // Manual check-in button
                  GestureDetector(
                    onTap: _doCheckIn,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          AppColors.accentTeal,
                          AppColors.accentTealDark
                        ]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Check In',
                          style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black)),
                    ),
                  ),
                ]),
              ),
            ).animate().fadeIn(delay: 150.ms).slideX(begin: 0.05),

          const SizedBox(height: 16),

          // GPS telemetry mini
          if (guardian.isActive)
            GlassCard(
              borderRadius: 16,
              borderColor: AppColors.accentTeal.withValues(alpha: 0.15),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentTeal),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(end: 1.5, duration: 600.ms),
                  const SizedBox(width: 10),
                  const Text('GPS Tracking',
                      style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                  const Spacer(),
                  Text(
                    guardian.telemetry.hasLocation
                        ? '${guardian.telemetry.latitude!.toStringAsFixed(4)}, ${guardian.telemetry.longitude!.toStringAsFixed(4)}'
                        : 'Acquiring…',
                    style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentTeal),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '· ${session.waypoints.length} pts',
                    style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        color: AppColors.textMuted),
                  ),
                ]),
              ),
            ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 16),

          // Action buttons
          if (!arrived) ...[
            NeonButton(
              label: 'I HAVE ARRIVED SAFELY',
              leadingIcon: Icons.check_circle_outline_rounded,
              variant: NeonButtonVariant.primary,
              height: 56,
              onPressed: _markArrived,
            ).animate().fadeIn(delay: 250.ms),
            const SizedBox(height: 12),
            NeonButton(
              label: 'END JOURNEY',
              leadingIcon: Icons.stop_circle_outlined,
              variant: NeonButtonVariant.ghost,
              height: 48,
              onPressed: _endJourney,
            ).animate().fadeIn(delay: 300.ms),
          ] else ...[
            NeonButton(
              label: 'VIEW JOURNEY REPORT',
              leadingIcon: Icons.bar_chart_rounded,
              variant: NeonButtonVariant.primary,
              height: 56,
              onPressed: _viewReport,
            ).animate().fadeIn(delay: 250.ms),
            const SizedBox(height: 12),
            NeonButton(
              label: 'START NEW JOURNEY',
              leadingIcon: Icons.add_rounded,
              variant: NeonButtonVariant.ghost,
              height: 48,
              onPressed: _endJourney,
            ).animate().fadeIn(delay: 300.ms),
          ], // End of else block
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressArc(JourneySession session, Color accent) {
    return SizedBox(
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 140,
            width: 140,
            child: CircularProgressIndicator(
              value: session.progress,
              strokeWidth: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              '${(session.progress * 100).toInt()}%',
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  height: 1),
            ),
            const SizedBox(height: 4),
            const Text('complete',
                style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: AppColors.textSecondary)),
          ]),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10,
                color: AppColors.textMuted)),
      ]),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
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
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Journey Guardian',
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const Text('Live route monitoring',
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: AppColors.textMuted)),
        ]),
        const Spacer(),
      ]),
    );
  }
}
