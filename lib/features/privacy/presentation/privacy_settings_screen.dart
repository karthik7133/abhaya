import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/common_widgets/neon_button.dart';
import '../../../core/providers/accessibility_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/night_safety_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/services/backend_service.dart';
import '../../../l10n/app_localizations.dart';

// ─── Privacy Settings Screen ──────────────────────────────────────────────────

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState
    extends ConsumerState<PrivacySettingsScreen> {

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: AppColors.accentCrimson.withValues(alpha: 0.4)),
        ),
        title: const Row(children: [
          Icon(Icons.delete_forever_rounded,
              color: AppColors.accentCrimson),
          SizedBox(width: 10),
          Text('Delete All Data',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w800)),
        ]),
        content: const Text(
          'This will permanently delete all your Abhaya data including location history, incidents, and guardian links. This action cannot be undone.',
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
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await BackendService.deleteAllData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.accentTeal,
                      behavior: SnackBarBehavior.floating,
                      margin:
                          const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      content: const Text('All data deleted.',
                          style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              color: Colors.white)),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.accentCrimson,
                      content: Text('Error: $e',
                          style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              color: Colors.white)),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete Everything',
                style: TextStyle(
                    color: AppColors.accentCrimson,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = ref.watch(accessibilityProvider);
    final nightSafety = ref.watch(nightSafetyProvider);
    final locale = ref.watch(localeProvider);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Privacy & Data Section ─────────────────────────────
                      _SectionHeader(title: l10n.privacy.toUpperCase()),
                      const SizedBox(height: 12),
                      GlassCard(
                        borderRadius: 20,
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.share_location_outlined,
                              color: AppColors.primaryBlue,
                              title: l10n.shareLocation,
                              subtitle: l10n.shareLocationDesc,
                              trailing: Switch.adaptive(
                                value: settings.shareLocation,
                                onChanged: settingsNotifier.toggleShareLocation,
                                activeThumbColor: AppColors.primaryBlue,
                              ),
                            ),
                            const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
                            _SettingsTile(
                              icon: Icons.mic_outlined,
                              color: AppColors.primaryBlue,
                              title: l10n.audioDetection,
                              subtitle: l10n.audioDetectionDesc,
                              trailing: Switch.adaptive(
                                value: settings.audioDetection,
                                onChanged: settingsNotifier.toggleAudioDetection,
                                activeThumbColor: AppColors.primaryBlue,
                              ),
                            ),
                            const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
                            _SettingsTile(
                              icon: Icons.analytics_outlined,
                              color: AppColors.textSecondary,
                              title: l10n.anonymousAnalytics,
                              subtitle: l10n.anonymousAnalyticsDesc,
                              trailing: Switch.adaptive(
                                value: settings.usageAnalytics,
                                onChanged: settingsNotifier.toggleUsageAnalytics,
                                activeThumbColor: AppColors.primaryBlue,
                              ),
                            ),
                            const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
                            _SettingsTile(
                              icon: Icons.fingerprint_rounded,
                              color: AppColors.primaryBlue,
                              title: 'Biometric Unlock',
                              subtitle: 'Lock app when closed',
                              trailing: Switch.adaptive(
                                value: settings.requireBiometric,
                                onChanged: settingsNotifier.toggleBiometric,
                                activeThumbColor: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05),

                      const SizedBox(height: 24),
                      
                      // ── App Preferences Section ──────────────────────────────
                      _SectionHeader(title: l10n.settings.toUpperCase()),
                      const SizedBox(height: 12),
                      GlassCard(
                        borderRadius: 20,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Row(
                                children: [
                                  const Icon(Icons.language_outlined, color: AppColors.primaryBlue, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(l10n.language, style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans', fontSize: 14,
                                        fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                                      )),
                                      Text(l10n.selectLanguage, style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textSecondary,
                                      )),
                                    ]),
                                  ),
                                  DropdownButton<String>(
                                    value: locale.languageCode,
                                    dropdownColor: AppColors.bgMid,
                                    underline: const SizedBox(),
                                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                                    items: const [
                                      DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(color: Colors.white, fontFamily: 'PlusJakartaSans'))),
                                      DropdownMenuItem(value: 'hi', child: Text('हिन्दी', style: TextStyle(color: Colors.white, fontFamily: 'PlusJakartaSans'))),
                                      DropdownMenuItem(value: 'te', child: Text('తెలుగు', style: TextStyle(color: Colors.white, fontFamily: 'PlusJakartaSans'))),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        ref.read(localeProvider.notifier).setLocale(Locale(val));
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05),

                      const SizedBox(height: 24),

                      // ── Accessibility Section ───────────────────────────────
                      _SectionHeader(title: l10n.highContrastMode.split(' ').first.toUpperCase()),
                      const SizedBox(height: 12),
                      GlassCard(
                        borderRadius: 20,
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.contrast_outlined,
                              color: AppColors.primaryBlue,
                              title: l10n.highContrastMode,
                              subtitle: l10n.enhancedColors,
                              trailing: Switch.adaptive(
                                value: accessibility.highContrastEnabled,
                                onChanged: (v) => ref.read(accessibilityProvider.notifier).toggleHighContrast(),
                                activeThumbColor: AppColors.primaryBlue,
                              ),
                            ),
                            const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.text_fields_outlined, color: AppColors.primaryBlue, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(l10n.textSize, style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans', fontSize: 14,
                                          fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                                        )),
                                        Text(l10n.adjustTextScale, style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textSecondary,
                                        )),
                                      ]),
                                    ),
                                    Text(
                                      '${(accessibility.textScaleFactorOverride * 100).toInt()}%',
                                      style: const TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.primaryBlue, fontWeight: FontWeight.w700),
                                    ),
                                  ]),
                                  Slider(
                                    value: accessibility.textScaleFactorOverride,
                                    min: 0.8,
                                    max: 1.4,
                                    divisions: 6,
                                    activeColor: AppColors.primaryBlue,
                                    inactiveColor: Colors.white12,
                                    onChanged: (v) => ref.read(accessibilityProvider.notifier).setTextScale(v),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),

                      const SizedBox(height: 24),

                      // ── Night Safety ────────────────────────────────────────
                      _SectionHeader(title: l10n.nightSafetyMode.toUpperCase()),
                      const SizedBox(height: 12),
                      GlassCard(
                        borderRadius: 20,
                        borderColor: nightSafety.isNightModeActive
                            ? AppColors.primaryBlue.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.1),
                        child: _SettingsTile(
                          icon: Icons.nights_stay_outlined,
                          color: AppColors.primaryBlue,
                          title: l10n.nightSafetyMode,
                          subtitle: nightSafety.isNightModeActive
                              ? l10n.enhancedProtection
                              : l10n.autoActivates,
                          trailing: Switch.adaptive(
                            value: nightSafety.isNightModeActive,
                            onChanged: (v) => ref.read(nightSafetyProvider.notifier).toggle(),
                            activeThumbColor: AppColors.primaryBlue,
                          ),
                        ),
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),

                      const SizedBox(height: 24),

                      // ── Data Deletion ────────────────────────────────────────
                      GlassCard(
                        borderRadius: 20,
                        borderColor: AppColors.accentCrimson.withValues(alpha: 0.2),
                        child: _SettingsTile(
                          icon: Icons.delete_outline_rounded,
                          color: AppColors.accentCrimson,
                          title: l10n.deleteAllData,
                          subtitle: l10n.deleteAllDataDesc,
                          trailing: TextButton(
                            onPressed: () => _showDeleteConfirmation(context),
                            child: Text(l10n.deleteAllData.split(' ').first, style: const TextStyle(color: AppColors.accentCrimson, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05),
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const GlassCard(
              borderRadius: 12,
              padding: EdgeInsets.all(10),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.privacy,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 20,
                  fontWeight: FontWeight.w800, color: AppColors.textPrimary,
                ),
              ),
              Text(
                l10n.selectLanguage,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'PlusJakartaSans', fontSize: 11,
        fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 14,
                  fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                )),
                Text(subtitle, style: const TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textSecondary,
                )),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

// Removed unused Language and Permission tiles.
