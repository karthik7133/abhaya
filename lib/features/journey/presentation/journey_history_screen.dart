import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../providers/journey_history_provider.dart';
import '../../../l10n/app_localizations.dart';

class JourneyHistoryScreen extends ConsumerWidget {
  const JourneyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(journeyHistoryProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.journeyHistory,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.bgDeep, AppColors.bgMid],
          ),
        ),
        child: historyState.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentTeal)),
          error: (err, _) => Center(
            child: Text(
              'Failed to load history: $err',
              style: const TextStyle(color: AppColors.accentCrimson, fontFamily: 'PlusJakartaSans'),
            ),
          ),
          data: (journeys) {
            if (journeys.isEmpty) {
              return Center(
                child: Text(
                  l10n.noPastJourneys,
                  style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'PlusJakartaSans'),
                ),
              );
            }

            // Limit to last 10 journeys
            final displayJourneys = journeys.take(10).toList();

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: displayJourneys.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final journey = displayJourneys[index];
                
                final destination = journey['destination'] ?? l10n.unknownDestination;
                final startedAtStr = journey['startedAt'];
                final dateLabel = startedAtStr != null 
                    ? DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.parse(startedAtStr).toLocal())
                    : l10n.unknownDate;
                final distanceMeters = journey['distanceMeters'] ?? 0;
                final durationSecs = journey['durationSeconds'] ?? 0;

                return GestureDetector(
                  onTap: () {
                    final payload = {
                      'destination': journey['destination'],
                      'startedAt': journey['startedAt'],
                      'arrivedAt': journey['arrivedAt'],
                      'checkInsMade': journey['checkInsCount'],
                      'nightModeActive': journey['nightModeActive'],
                      'distanceKm': distanceMeters / 1000.0,
                      'estimatedMinutes': durationSecs ~/ 60,
                      'routeType': journey['routeType']
                    };
                    context.push('/journey-report?session=${Uri.encodeComponent(jsonEncode(payload))}');
                  },
                  child: GlassCard(
                    borderRadius: 16,
                    borderColor: AppColors.accentTeal.withValues(alpha: 0.15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.accentTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.history_edu_rounded, color: AppColors.accentTeal, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  destination,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateLabel,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
