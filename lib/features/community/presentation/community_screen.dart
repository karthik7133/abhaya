import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/services/backend_service.dart';
import '../../../core/providers/telemetry_provider.dart';
import '../../../l10n/app_localizations.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  bool _isLoading = true;
  List<dynamic> _events = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final events = await BackendService.getIncidentHistory();
      if (mounted) setState(() { _events = events; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardian = ref.watch(guardianProvider);
    final score = guardian.threatScore;
    final l10n = AppLocalizations.of(context)!;
    final scoreLabel = score >= 90
        ? l10n.criticalThreat
        : score >= 60
            ? l10n.elevatedHazard
            : score >= 30
                ? l10n.moderateContext
                : l10n.safeZone;
    final scoreColor = score >= 90
        ? AppColors.accentCrimson
        : score >= 60
            ? AppColors.accentAmber
            : AppColors.accentTeal;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/home');
      },
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAlerts,
          color: AppColors.accentTeal,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            children: [
              // Header
            Text(
              l10n.alertsIntel,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.safetyIntelDesc,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Live risk index card
            GlassCard(
              borderRadius: 20,
              borderColor: scoreColor.withValues(alpha: 0.25),
              shadows: [
                BoxShadow(
                  color: scoreColor.withValues(alpha: 0.08),
                  blurRadius: 32, offset: const Offset(0, 8),
                ),
              ],
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.radar, color: scoreColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.liveThreatLevel,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans', fontSize: 11,
                        fontWeight: FontWeight.w700, color: scoreColor, letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${score.toInt()}%',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans', fontSize: 20,
                        fontWeight: FontWeight.w800, color: scoreColor,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text(
                    scoreLabel,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans', fontSize: 18,
                      fontWeight: FontWeight.w800, color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    guardian.isActive
                        ? l10n.guardianActiveMonitoring
                        : l10n.guardianOfflineEnable,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans', fontSize: 13,
                      color: AppColors.textSecondary, height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (score / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(scoreColor),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 28),

            // Incident Feed Section
            Row(children: [
              Text(
                l10n.incidentFeed,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 11,
                  fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (!_isLoading)
                Text(
                  '${_events.length} ${l10n.records}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans', fontSize: 11, color: AppColors.textMuted,
                  ),
                ),
            ]),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: AppColors.accentTeal),
              ))
            else if (_events.isEmpty)
              GlassCard(
                borderRadius: 16,
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.verified_rounded, color: AppColors.accentTeal, size: 40),
                      const SizedBox(height: 12),
                      Text(l10n.noIncidentsYouAreSafe,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14, color: AppColors.textSecondary, height: 1.5,
                        )),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms)
            else
              ..._events.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildAlertCard(e).animate()
                      .fadeIn(delay: (i * 60).ms, duration: 350.ms)
                      .slideY(begin: 0.1, end: 0, delay: (i * 60).ms),
                );
              }),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildAlertCard(Map<String, dynamic> e) {
    final l10n = AppLocalizations.of(context)!;
    final type    = e['type']   as String? ?? 'unknown';
    final status  = e['status'] as String? ?? 'active';
    final score   = (e['threatScore'] as num?)?.toDouble() ?? 0;
    final createdAt = e['createdAt'] as String?;

    final Color accent;
    final IconData icon;
    final String title;

    switch (type) {
      case 'sos':
        accent = AppColors.accentCrimson; icon = Icons.emergency_rounded;
        title = l10n.manualSos; break;
      case 'chat_crisis':
        accent = AppColors.accentAmber; icon = Icons.chat_bubble_outline_rounded;
        title = l10n.crisisChatAlert; break;
      case 'audio_distress':
        accent = AppColors.accentTeal; icon = Icons.mic_none_rounded;
        title = l10n.audioDistressAlertLabel; break;
      case 'motion':
        accent = AppColors.accentAmber; icon = Icons.screen_rotation_rounded;
        title = l10n.motionAnomaly; break;
      default:
        accent = AppColors.textSecondary; icon = Icons.warning_amber_rounded;
        title = type.replaceAll('_', ' ');
    }

    String timeStr = '--';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) { timeStr = '${diff.inMinutes}m ago'; }
        else if (diff.inHours < 24) { timeStr = '${diff.inHours}h ago'; }
        else { timeStr = '${diff.inDays}d ago'; }
      } catch (_) {}
    }

    final Color statusColor = status == 'resolved'
        ? AppColors.accentTeal
        : status == 'dismissed'
            ? AppColors.textMuted
            : AppColors.accentCrimson;

    return GlassCard(
      borderRadius: 16,
      borderColor: accent.withValues(alpha: 0.15),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accent, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(
              fontFamily: 'PlusJakartaSans', fontSize: 14,
              fontWeight: FontWeight.w700, color: AppColors.textPrimary,
            ))),
            Text(timeStr, style: const TextStyle(
              fontFamily: 'PlusJakartaSans', fontSize: 11, color: AppColors.textMuted,
            )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(status.toUpperCase(), style: TextStyle(
                fontFamily: 'PlusJakartaSans', fontSize: 10,
                fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5,
              )),
            ),
            const SizedBox(width: 10),
            Text('Threat: ${score.toInt()}%', style: const TextStyle(
              fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textSecondary,
            )),
          ]),
        ],
      ),
    );
  }
}
