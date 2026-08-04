import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/telemetry_provider.dart';

/// A wrapper widget that manages UI interaction during an active emergency.
/// Shows a persistent red banner and a subtle tint when [GuardianState.isEmergency] is true.
class EmergencyInteractionManager extends ConsumerWidget {
  final Widget child;

  const EmergencyInteractionManager({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guardianState = ref.watch(guardianProvider);
    final isEmergencyActive = guardianState.isEmergency; // correct field name

    if (!isEmergencyActive) {
      return child;
    }

    return Stack(
      children: [
        // The main app content with a subtle red tint during emergency
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.red.withValues(alpha: 0.05),
            BlendMode.srcOver,
          ),
          child: child,
        ),

        // Persistent Emergency Banner
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Material(
              color: Colors.redAccent,
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'EMERGENCY MODE ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
