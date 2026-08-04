import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/common_widgets/neon_button.dart';
import '../../../core/providers/night_safety_provider.dart';
import '../../../core/services/backend_service.dart';

// ─── Journey Report Screen ────────────────────────────────────────────────────

class JourneyReportScreen extends ConsumerStatefulWidget {
  final String sessionJson;

  const JourneyReportScreen({super.key, required this.sessionJson});

  @override
  ConsumerState<JourneyReportScreen> createState() => _JourneyReportScreenState();
}

class _JourneyReportScreenState extends ConsumerState<JourneyReportScreen> {

  Map<String, dynamic> get _session {
    try {
      return jsonDecode(widget.sessionJson) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  void initState() {
    super.initState();
    _syncJourney();
  }

  Future<void> _syncJourney() async {
    final data = _session;
    if (data.isEmpty) return;

    final destination = data['destination'] as String? ?? 'Unknown destination';
    final startedAt = data['startedAt'] as String? ?? DateTime.now().toIso8601String();
    final arrivedAt = data['arrivedAt'] as String? ?? DateTime.now().toIso8601String();
    
    final start = DateTime.tryParse(startedAt) ?? DateTime.now();
    final end = DateTime.tryParse(arrivedAt) ?? DateTime.now();
    final duration = end.difference(start);
    
    final estimatedMinutes = (data['estimatedMinutes'] as int?) ?? 0;
    final estimatedDuration = Duration(minutes: estimatedMinutes);
    final onTime = !duration.isNegative && duration <= estimatedDuration + const Duration(minutes: 5);
    final checkInsMade = (data['checkInsMade'] as int?) ?? 0;
    final wasNightMode = (data['nightModeActive'] as bool?) ?? false;

    final rawScore = ((onTime ? 40 : 20) + (checkInsMade * 10).clamp(0, 40) + (wasNightMode ? 20 : 0)).clamp(0, 100);

    try {
      await BackendService.saveJourney({
        'destination': destination,
        'startedAt': startedAt,
        'arrivedAt': arrivedAt,
        'durationSeconds': duration.inSeconds,
        'distanceMeters': (data['finalDistanceMeters'] as double? ?? 
                          (data['initialDistanceMeters'] as double? ?? 0)),
        'checkInsCount': checkInsMade,
        'safetyScore': rawScore,
        'nightModeActive': wasNightMode,
        'routeType': data['routeType'] ?? 'standard',
        'waypoints': data['waypoints'] ?? [],
      });
    } catch (e) {
      debugPrint('[JourneyReport] Failed to sync journey: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _session;
    final nightSafety = ref.watch(nightSafetyProvider);

    // Parse session fields
    final destination = data['destination'] as String? ?? 'Unknown destination';
    final startedAt = data['startedAt'] != null
        ? DateTime.tryParse(data['startedAt'] as String) ?? DateTime.now()
        : DateTime.now();
    final arrivedAt = data['arrivedAt'] != null
        ? DateTime.tryParse(data['arrivedAt'] as String) ?? DateTime.now()
        : DateTime.now();
    final checkInsMade = (data['checkInsMade'] as int?) ?? 0;
    final wasNightMode = (data['nightModeActive'] as bool?) ??
        nightSafety.isNightModeActive;
    final waypoints =
        (data['waypoints'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];
    final estimatedMinutes = (data['estimatedMinutes'] as int?) ?? 0;

    final duration = arrivedAt.difference(startedAt);
    final durationStr = _formatDuration(duration);
    final estimatedDuration = Duration(minutes: estimatedMinutes);
    final onTime = !duration.isNegative &&
        duration <= estimatedDuration + const Duration(minutes: 5);

    // Safety score based on: on-time, check-ins, night mode
    final rawScore = ((onTime ? 40 : 20) +
            (checkInsMade * 10).clamp(0, 40) +
            (wasNightMode ? 20 : 0))
        .clamp(0, 100);
    final safetyScore = rawScore.toDouble();

    final dateFormatter = DateFormat('EEE d MMM, h:mm a');

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
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Hero Score ─────────────────────────────────────────
                      _buildScoreCard(safetyScore, destination, wasNightMode)
                          .animate()
                          .fadeIn(delay: 50.ms)
                          .scale(begin: const Offset(0.95, 0.95)),

                      const SizedBox(height: 16),

                      // ── Journey Summary ────────────────────────────────────
                      _buildSummaryCard(
                        startedAt,
                        arrivedAt,
                        duration,
                        durationStr,
                        onTime,
                        estimatedMinutes,
                        dateFormatter,
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),

                      const SizedBox(height: 16),

                      // ── Check-in Stats ─────────────────────────────────────
                      _buildCheckInCard(checkInsMade, duration)
                          .animate()
                          .fadeIn(delay: 150.ms)
                          .slideY(begin: 0.05),

                      const SizedBox(height: 16),

                      // ── Waypoints ──────────────────────────────────────────
                      if (waypoints.isNotEmpty)
                        _buildWaypointCard(waypoints)
                            .animate()
                            .fadeIn(delay: 200.ms)
                            .slideY(begin: 0.05),

                      if (waypoints.isEmpty) ...[
                        _buildNoGpsCard()
                            .animate()
                            .fadeIn(delay: 200.ms)
                            .slideY(begin: 0.05),
                      ],

                      const SizedBox(height: 16),

                      // ── Night Mode Status ──────────────────────────────────
                      if (wasNightMode)
                        _buildNightModeCard()
                            .animate()
                            .fadeIn(delay: 250.ms)
                            .slideY(begin: 0.05),

                      const SizedBox(height: 24),

                      // ── Actions ─────────────────────────────────────────────
                      NeonButton(
                        label: 'SHARE JOURNEY REPORT',
                        leadingIcon: Icons.share_rounded,
                        variant: NeonButtonVariant.ghost,
                        height: 50,
                        onPressed: () => _shareReport(
                          destination,
                          startedAt,
                          arrivedAt,
                          durationStr,
                          checkInsMade,
                          safetyScore,
                          dateFormatter,
                        ),
                      ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 12),

                      NeonButton(
                        label: 'START NEW JOURNEY',
                        leadingIcon: Icons.add_rounded,
                        variant: NeonButtonVariant.primary,
                        height: 52,
                        onPressed: () => context.go('/journey'),
                      ).animate().fadeIn(delay: 350.ms),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/home'),
            child: const GlassCard(
              borderRadius: 12,
              padding: EdgeInsets.all(10),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Journey Report',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Your safety summary',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.accentTeal.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.accentTeal, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(
      double score, String destination, bool wasNightMode) {
    final color = score >= 80
        ? AppColors.accentTeal
        : score >= 50
            ? AppColors.accentAmber
            : AppColors.accentCrimson;

    return GlassCard(
      borderRadius: 24,
      borderColor: color.withValues(alpha: 0.35),
      shadows: [
        BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 40)
      ],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // Safety score ring
          SizedBox(
            height: 130,
            width: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    '${score.toInt()}',
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1),
                  ),
                  Text('/ 100',
                      style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: color.withValues(alpha: 0.7))),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            score >= 80
                ? '✓ Journey Completed Safely'
                : score >= 50
                    ? '⚠ Journey Completed'
                    : 'Journey Completed',
            style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color),
          ),

          const SizedBox(height: 6),

          Text(
            destination,
            style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),

          if (wasNightMode) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6B5CE7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF6B5CE7).withValues(alpha: 0.3)),
              ),
              child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🌙', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('Night Mode Active During Journey',
                        style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B5CE7))),
                  ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildSummaryCard(
    DateTime startedAt,
    DateTime arrivedAt,
    Duration duration,
    String durationStr,
    bool onTime,
    int estimatedMinutes,
    DateFormat formatter,
  ) {
    return GlassCard(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.route_rounded, color: AppColors.accentTeal, size: 18),
            SizedBox(width: 8),
            Text('Journey Summary',
                style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 20),

          _summaryRow(
            'Started',
            formatter.format(startedAt),
            Icons.play_circle_outline_rounded,
            AppColors.accentTeal,
          ),
          const SizedBox(height: 14),
          _summaryRow(
            'Arrived',
            formatter.format(arrivedAt),
            Icons.check_circle_outline_rounded,
            AppColors.accentTeal,
          ),
          const SizedBox(height: 14),
          _summaryRow(
            'Total Duration',
            durationStr,
            Icons.timer_rounded,
            onTime ? AppColors.accentTeal : AppColors.accentAmber,
          ),
          if (estimatedMinutes > 0) ...[
            const SizedBox(height: 14),
            _summaryRow(
              'Estimated ETA',
              '$estimatedMinutes min',
              Icons.hourglass_empty_rounded,
              AppColors.textSecondary,
            ),
          ],
          const SizedBox(height: 14),
          _summaryRow(
            'On-Time Status',
            onTime ? 'Arrived on time ✓' : 'Arrived late',
            Icons.schedule_rounded,
            onTime ? AppColors.accentTeal : AppColors.accentAmber,
          ),
        ]),
      ),
    );
  }

  Widget _buildCheckInCard(int checkIns, Duration duration) {
    final checkInRate = duration.inMinutes > 0
        ? (checkIns / (duration.inMinutes / 10)).clamp(0.0, 1.0)
        : 0.0;
    final rateLabel = checkInRate >= 0.8
        ? 'Excellent'
        : checkInRate >= 0.5
            ? 'Good'
            : 'Low';
    final rateColor = checkInRate >= 0.8
        ? AppColors.accentTeal
        : checkInRate >= 0.5
            ? AppColors.accentAmber
            : AppColors.accentCrimson;

    return GlassCard(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.done_all_rounded, color: AppColors.accentAmber, size: 18),
            SizedBox(width: 8),
            Text('Guardian Check-ins',
                style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 20),

          Row(children: [
            Expanded(
              child: _statBox(
                  checkIns.toString(), 'Check-ins Sent', AppColors.accentTeal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statBox(rateLabel, 'Frequency', rateColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statBox(
                checkIns > 0 ? 'Alerted' : 'Standby',
                'Guardians',
                checkIns > 0 ? AppColors.accentTeal : AppColors.textSecondary,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildWaypointCard(List<Map<String, dynamic>> waypoints) {
    return GlassCard(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.my_location_rounded,
                color: AppColors.accentTeal, size: 18),
            const SizedBox(width: 8),
            Text('GPS Waypoints (${waypoints.length})',
                style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 16),

          // Show first 4 and last waypoint
          ...waypoints
              .take(4)
              .toList()
              .asMap()
              .entries
              .map((e) => _waypointRow(e.value, e.key)),

          if (waypoints.length > 5) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '  ⋮  ${waypoints.length - 5} more points',
                style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: AppColors.textMuted),
              ),
            ),
            _waypointRow(waypoints.last, waypoints.length - 1,
                isLast: true),
          ] else if (waypoints.length == 5)
            _waypointRow(waypoints.last, 4, isLast: true),
        ]),
      ),
    );
  }

  Widget _buildNoGpsCard() {
    return GlassCard(
      borderRadius: 20,
      borderColor: Colors.white.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.gps_off_rounded,
                color: AppColors.textMuted, size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'GPS tracking was not active during this journey. Enable Guardian mode before next trip for waypoint recording.',
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildNightModeCard() {
    return GlassCard(
      borderRadius: 20,
      borderColor: const Color(0xFF6B5CE7).withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.nights_stay_rounded, color: Color(0xFF6B5CE7), size: 18),
            SizedBox(width: 8),
            Text('Night Mode Active',
                style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 12),
          const Text(
            'Enhanced sensor sensitivity and more frequent guardian check-ins were active throughout this journey.',
            style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
        ]),
      ),
    );
  }

  Widget _summaryRow(
      String label, String value, IconData icon, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  color: AppColors.textMuted)),
          Text(value,
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ]),
      ),
    ]);
  }

  Widget _statBox(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10,
                color: AppColors.textMuted),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _waypointRow(Map<String, dynamic> wp, int index,
      {bool isLast = false}) {
    final lat = (wp['lat'] as num?)?.toDouble();
    final lng = (wp['lng'] as num?)?.toDouble();
    final time = wp['time'] != null
        ? DateTime.tryParse(wp['time'] as String)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLast
                ? AppColors.accentTeal.withValues(alpha: 0.2)
                : AppColors.textMuted.withValues(alpha: 0.1),
            border: Border.all(
                color: isLast
                    ? AppColors.accentTeal.withValues(alpha: 0.5)
                    : AppColors.textMuted.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              isLast ? '✓' : '${index + 1}',
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isLast ? AppColors.accentTeal : AppColors.textMuted),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            lat != null && lng != null
                ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                : 'Location not recorded',
            style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                color: AppColors.textSecondary),
          ),
        ),
        if (time != null)
          Text(
            DateFormat('h:mm a').format(time),
            style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10,
                color: AppColors.textMuted),
          ),
      ]),
    );
  }

  void _shareReport(
    String destination,
    DateTime startedAt,
    DateTime arrivedAt,
    String durationStr,
    int checkIns,
    double score,
    DateFormat formatter,
  ) {
    final text = '''
🛡️ Abhaya Journey Report
─────────────────────────
Destination: $destination
Started: ${formatter.format(startedAt)}
Arrived: ${formatter.format(arrivedAt)}
Duration: $durationStr
Check-ins: $checkIns
Safety Score: ${score.toInt()}/100
─────────────────────────
Shared from Abhaya Safety App''';

    Share.share(text, subject: 'Abhaya Journey Report');
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '0m 00s';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m >= 60) return '${d.inHours}h ${m % 60}m';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}
