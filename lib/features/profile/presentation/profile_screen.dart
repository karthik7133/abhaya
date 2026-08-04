import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/services/backend_service.dart';
import '../../../core/services/ble_service.dart';
import '../../../core/providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = true;
  String _name = '';
  String _email = '';
  String _phone = '';
  int? _age;
  String? _gender;
  String? _photoUrl;
  
  bool _avoidCrimeHotspots = true;
  bool _prioritizeCCTVs = true;
  bool _nightModeRouting = false;
  bool _backgroundSensing = true;
  bool _moodSharing = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Show Firebase data immediately so screen isn't blank
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      setState(() {
        _name = firebaseUser.displayName ?? '';
        _email = firebaseUser.email ?? '';
        _phone = firebaseUser.phoneNumber ?? '';
        _photoUrl = firebaseUser.photoURL;
      });
    }

    try {
      final data = await BackendService.getMe();
      if (mounted) {
        setState(() {
          _name = data['displayName'] ?? _name;
          final beEmail = data['email'] as String? ?? '';
          if (beEmail.endsWith('@abhaya.local')) {
            _email = '';
          } else {
            _email = beEmail;
          }
          _phone = data['phone'] ?? _phone;
          _age = data['age'] as int?;
          _gender = data['gender'] as String?;
          _photoUrl = data['photoUrl'] ?? _photoUrl;
          final settings = data['settings'] ?? {};
          _backgroundSensing = settings['backgroundSensing'] ?? true;
          _moodSharing = settings['moodSharingWithGuardians'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      // If 404 — user not yet in DB, call sync then retry
      if (e.toString().contains('404')) {
        try {
          await BackendService.syncUser();
          final data = await BackendService.getMe();
          if (mounted) {
            setState(() {
              _name = data['displayName'] ?? _name;
              final beEmail = data['email'] as String? ?? '';
              if (beEmail.endsWith('@abhaya.local')) {
                _email = '';
              } else {
                _email = beEmail;
              }
              _phone = data['phone'] ?? _phone;
              _age = data['age'] as int?;
              _gender = data['gender'] as String?;
              _photoUrl = data['photoUrl'] ?? _photoUrl;
              _isLoading = false;
            });
          }
          return;
        } catch (_) {}
      }
      if (mounted) setState(() => _isLoading = false);
      // No scary snackbar — Firebase data is already shown
      debugPrint('[Profile] Backend load failed: $e');
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BackendService.updateSettings({key: value});
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update settings: $e')),
      );
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _isLoading = true);
      try {
        final url = await BackendService.uploadAvatar(File(picked.path));
        await FirebaseAuth.instance.currentUser?.updatePhotoURL(url);
        setState(() {
          _photoUrl = url;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        title: const Text('Edit Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentTeal)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save', style: TextStyle(color: AppColors.accentTeal))),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && newName != _name) {
      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(newName.trim());
        await BackendService.syncUser(name: newName.trim());
        setState(() => _name = newName.trim());
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update name: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentTeal));
    }

    final l10n = AppLocalizations.of(context)!;
    final requireBiometric = ref.watch(settingsProvider).requireBiometric;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/home');
      },
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          children: [
            // Profile header
          GlassCard(
            borderRadius: 20,
            borderColor: AppColors.accentTeal.withValues(alpha: 0.15),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentTeal.withValues(alpha: 0.08),
                          border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.4), width: 2),
                          image: _photoUrl != null
                              ? DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _photoUrl == null
                            ? const Icon(Icons.person_rounded, color: AppColors.accentTeal, size: 30)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accentTeal,
                          ),
                          child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _name.isNotEmpty ? _name : 'User',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _editName,
                            child: const Icon(Icons.edit, size: 16, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const SizedBox(height: 2),
                      if (_phone.isNotEmpty)
                        Text(
                          _phone,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (_email.isNotEmpty)
                        Text(
                          _email,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (_age != null || (_gender != null && _gender!.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [
                              if (_age != null) '$_age yrs',
                              if (_gender != null && _gender!.isNotEmpty) _gender,
                            ].join(' • '),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accentTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          l10n.userRole,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentTeal,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // AI routing section
          Text(
            l10n.aiSafeRouteWeights,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          GlassCard(
            borderRadius: 18,
            child: Column(
              children: [
                _buildSwitchTile(
                  title: l10n.isolateCrimeHotspots,
                  subtitle: l10n.isolateCrimeHotspotsDesc,
                  value: _avoidCrimeHotspots,
                  onChanged: (v) => setState(() => _avoidCrimeHotspots = v),
                  showDivider: true,
                ),
                _buildSwitchTile(
                  title: l10n.prioritizeCctv,
                  subtitle: l10n.prioritizeCctvDesc,
                  value: _prioritizeCCTVs,
                  onChanged: (v) => setState(() => _prioritizeCCTVs = v),
                  showDivider: true,
                ),
                _buildSwitchTile(
                  title: l10n.nightModeThreatElevation,
                  subtitle: l10n.nightModeThreatElevationDesc,
                  value: _nightModeRouting,
                  onChanged: (v) => setState(() => _nightModeRouting = v),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Privacy section
          Text(
            l10n.privacySensing,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          GlassCard(
            borderRadius: 18,
            child: Column(
              children: [
                _buildSwitchTile(
                  title: l10n.backgroundSensing,
                  subtitle: l10n.backgroundSensingDesc,
                  value: _backgroundSensing,
                  onChanged: (v) {
                    setState(() => _backgroundSensing = v);
                    _updateSetting('backgroundSensing', v);
                  },
                  showDivider: true,
                ),
                _buildSwitchTile(
                  title: l10n.moodSharing,
                  subtitle: l10n.moodSharingDesc,
                  value: _moodSharing,
                  onChanged: (v) {
                    setState(() => _moodSharing = v);
                    _updateSetting('moodSharingWithGuardians', v);
                  },
                  showDivider: true,
                ),
                _buildSwitchTile(
                  title: l10n.biometricAppLock,
                  subtitle: l10n.biometricAppLockDesc,
                  value: requireBiometric,
                  onChanged: (v) {
                    ref.read(settingsProvider.notifier).toggleBiometric(v);
                  },
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            l10n.hardwareSync,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildBleSection(context),
          const SizedBox(height: 24),

          // Quick navigation links
          Text(
            l10n.toolsResources,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans', fontSize: 11,
              fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            borderRadius: 18,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_outlined, color: AppColors.accentTeal, size: 22),
                  ),
                  title: const Text('Safety Learning', style: TextStyle(
                    fontFamily: 'PlusJakartaSans', fontSize: 15,
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                  )),
                  subtitle: Text(l10n.safetyLearningDesc, style: const TextStyle(
                    fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textSecondary,
                  )),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () => context.push('/safety-learning'),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.05), height: 1, indent: 20, endIndent: 20),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.privacy_tip_outlined, color: AppColors.primaryBlue, size: 22),
                  ),
                  title: Text(l10n.privacySettings, style: const TextStyle(
                    fontFamily: 'PlusJakartaSans', fontSize: 15,
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                  )),
                  subtitle: Text(l10n.privacySettingsDesc, style: const TextStyle(
                    fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textSecondary,
                  )),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () => context.push('/privacy-settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sign out
          GlassCard(
            borderRadius: 18,
            borderColor: AppColors.accentCrimson.withValues(alpha: 0.12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentCrimson.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout_rounded, color: AppColors.accentCrimson, size: 22),
              ),
              title: Text(
                l10n.signOut,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentCrimson,
                ),
              ),
              subtitle: Text(
                l10n.signOutDesc,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () {
                ref.read(authNotifierProvider.notifier).signOut();
              },
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildBleSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ble = ref.watch(bleProvider);
    final bleNotifier = ref.read(bleProvider.notifier);

    // ── Connected State ─────────────────────────────────────────────────────
    if (ble.isConnected && ble.connectedDevice != null) {
      final device = ble.connectedDevice!;
      return GlassCard(
        borderRadius: 18,
        borderColor: AppColors.accentTeal.withValues(alpha: 0.3),
        shadows: [
          BoxShadow(
            color: AppColors.accentTeal.withValues(alpha: 0.08),
            blurRadius: 24, spreadRadius: 2,
          ),
        ],
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.bluetooth_connected_rounded, color: AppColors.accentTeal, size: 22),
              ),
              title: Text(
                device.name,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                device.macAddress,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.paired,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans', fontSize: 10,
                    fontWeight: FontWeight.w700, color: AppColors.accentTeal,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            // Heart rate display
            if (ble.heartRate != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.favorite_rounded, color: AppColors.accentCrimson, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${ble.heartRate} bpm',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans', fontSize: 16,
                        fontWeight: FontWeight.w800, color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: bleNotifier.disconnect,
                      child: Text(
                        l10n.disconnectLabel,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans', fontSize: 13,
                          color: AppColors.accentCrimson,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    // ── Scanning State ──────────────────────────────────────────────────────
    if (ble.isScanning || ble.connectionState == BleConnectionState.connecting) {
      return GlassCard(
        borderRadius: 18,
        borderColor: AppColors.accentTeal.withValues(alpha: 0.15),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentTeal),
              ),
              const SizedBox(width: 12),
              Text(
                ble.connectionState == BleConnectionState.connecting
                    ? l10n.connectingStatus
                    : l10n.scanningDevices,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 14,
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (ble.isScanning)
                TextButton(
                  onPressed: bleNotifier.stopScan,
                  child: Text(l10n.cancel, style: const TextStyle(color: AppColors.textMuted)),
                ),
            ]),

            // Discovered devices
            if (ble.discoveredDevices.isNotEmpty) ...[ 
              const SizedBox(height: 12),
              Text(
                l10n.foundDevices,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 10,
                  fontWeight: FontWeight.w700, color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              ...ble.discoveredDevices.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => bleNotifier.connect(d),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.bluetooth_rounded, color: AppColors.accentTeal, size: 18),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.name, style: const TextStyle(
                          fontFamily: 'PlusJakartaSans', fontSize: 13,
                          fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                        )),
                        Text(d.macAddress, style: const TextStyle(
                          fontFamily: 'PlusJakartaSans', fontSize: 11,
                          color: AppColors.textMuted,
                        )),
                      ])),
                      Text(d.signalBars, style: TextStyle(
                        fontSize: 10, color: AppColors.accentTeal.withValues(alpha: 0.7),
                        letterSpacing: 1,
                      )),
                    ]),
                  ),
                ),
              )),
            ],
          ],
        ),
      );
    }

    // ── Disconnected State ──────────────────────────────────────────────────
    return GlassCard(
      borderRadius: 18,
      borderColor: Colors.white.withValues(alpha: 0.06),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.textMuted.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.bluetooth_disabled_rounded, color: AppColors.textMuted, size: 22),
        ),
        title: Text(
          l10n.noBandConnected,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans', fontSize: 15,
            fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          l10n.scanForBand,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans', fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: TextButton(
          onPressed: bleNotifier.startScan,
          style: TextButton.styleFrom(
            backgroundColor: AppColors.accentTeal.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(l10n.scan, style: const TextStyle(
            fontFamily: 'PlusJakartaSans', fontSize: 12,
            fontWeight: FontWeight.w700, color: AppColors.accentTeal,
          )),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool showDivider,
  }) {
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.accentTeal,
          activeTrackColor: AppColors.accentTeal.withValues(alpha: 0.4),
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (showDivider)
          Divider(
            color: Colors.white.withValues(alpha: 0.05),
            height: 1,
            indent: 20,
            endIndent: 20,
          ),
      ],
    );
  }
}
