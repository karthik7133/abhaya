import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/services/backend_service.dart';
import '../../../core/providers/trusted_contacts_provider.dart';
import '../../../l10n/app_localizations.dart';

class GuardiansScreen extends ConsumerStatefulWidget {
  const GuardiansScreen({super.key});

  @override
  ConsumerState<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends ConsumerState<GuardiansScreen> {
  int _selectedTab = 0; // 0: Emergency Contacts to Notify, 1: Linked App Guardians
  bool _filterOnlyTrusted = false;
  final TextEditingController _searchCtrl = TextEditingController();

  // App guardians network state
  bool _isLoadingGuardians = true;
  List<dynamic> _guardians = [];

  @override
  void initState() {
    super.initState();
    _fetchNetwork();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trustedContactsProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchNetwork() async {
    try {
      final res = await BackendService.getMyNetwork();
      BackendService.getPendingRequests().then((_) {}).catchError((_) {});
      if (mounted) {
        setState(() {
          _guardians = res['guardians'] ?? [];
          _isLoadingGuardians = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingGuardians = false);
    }
  }

  Future<void> _showAddGuardianDialog() async {
    final phoneCtrl = TextEditingController();
    const role = 'guardian';
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.addGuardian, style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: l10n.guardianPhoneHint,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.accentTeal.withValues(alpha: 0.5)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.accentTeal),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentTeal),
            onPressed: () async {
              if (phoneCtrl.text.isEmpty) return;
              try {
                await BackendService.sendConnectionRequest(phoneCtrl.text.trim(), role);
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.connectionRequestSent)),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Text(l10n.sendRequest, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Bottom Sheet to customize alert notification settings per contact ─────────
  void _openContactAlertSettingsSheet(BuildContext context, String name, String phone) {
    final state = ref.read(trustedContactsProvider);
    final item = state.getTrustedItem(phone);
    if (item == null) return;

    bool sos = item.notifyOnSos;
    bool threat = item.notifyOnThreat;
    bool night = item.notifyOnNightMode;
    String relationship = item.relationship;

    const relationships = [
      'Family',
      'Parent',
      'Spouse',
      'Sibling',
      'Friend',
      'Colleague',
      'Emergency Contact'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentTeal.withValues(alpha: 0.15),
                          border: Border.all(color: AppColors.accentTeal, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppColors.accentTeal,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              phone,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'WHEN SHOULD THIS CONTACT BE NOTIFIED?',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // SOS Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentCrimson.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.emergency_rounded, color: AppColors.accentCrimson, size: 20),
                    ),
                    title: const Text('Notify on Emergency SOS',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Dispatches urgent alert & GPS location',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    activeThumbColor: AppColors.accentCrimson,
                    value: sos,
                    onChanged: (v) {
                      setModalState(() => sos = v);
                      ref.read(trustedContactsProvider.notifier).updateNotificationFlags(
                            item.id,
                            notifyOnSos: v,
                          );
                    },
                  ),
                  // Threat Anomaly Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: AppColors.accentAmber, size: 20),
                    ),
                    title: const Text('Notify on High Threat Score',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Alerts if screaming or fall anomaly is detected',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    activeThumbColor: AppColors.accentAmber,
                    value: threat,
                    onChanged: (v) {
                      setModalState(() => threat = v);
                      ref.read(trustedContactsProvider.notifier).updateNotificationFlags(
                            item.id,
                            notifyOnThreat: v,
                          );
                    },
                  ),
                  // Night Escort Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B5CE7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.nights_stay_rounded, color: Color(0xFF6B5CE7), size: 20),
                    ),
                    title: const Text('Notify on Night Safety Escort',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Alerts contact when night journey is started',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    activeThumbColor: const Color(0xFF6B5CE7),
                    value: night,
                    onChanged: (v) {
                      setModalState(() => night = v);
                      ref.read(trustedContactsProvider.notifier).updateNotificationFlags(
                            item.id,
                            notifyOnNightMode: v,
                          );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'RELATIONSHIP',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: relationships.map((r) {
                      final isSelected = relationship == r;
                      return ChoiceChip(
                        label: Text(r),
                        selected: isSelected,
                        selectedColor: AppColors.accentTeal.withValues(alpha: 0.25),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        side: BorderSide(
                          color: isSelected ? AppColors.accentTeal : Colors.white.withValues(alpha: 0.1),
                        ),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.accentTeal : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => relationship = r);
                            ref.read(trustedContactsProvider.notifier).updateNotificationFlags(
                                  item.id,
                                  relationship: r,
                                );
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // Remove from trusted button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentCrimson,
                      side: BorderSide(color: AppColors.accentCrimson.withValues(alpha: 0.5)),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.person_remove_rounded, size: 18),
                    label: const Text('Remove from Trusted Contacts'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref.read(trustedContactsProvider.notifier).toggleTrusted(
                            name: name,
                            phone: phone,
                          );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final contactsState = ref.watch(trustedContactsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/home');
      },
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          children: [
            _buildHeader(contactsState),
            const SizedBox(height: 20),

            // Segmented Pill Tab Switcher
            _buildSegmentedTabSwitcher(contactsState),
            const SizedBox(height: 20),

            if (_selectedTab == 0) ...[
              // ── EMERGENCY CONTACTS TO NOTIFY TAB ──
              _buildEmergencyContactsSection(contactsState),
            ] else ...[
              // ── LINKED APP GUARDIANS TAB ──
              _buildAppGuardiansSection(l10n),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(TrustedContactsState contactsState) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Trust Circle',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose which contacts are notified during emergencies and link trusted guardians.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Sync Phone Contacts Action Pill
        InkWell(
          onTap: contactsState.isSyncingPhonebook
              ? null
              : () async {
                  HapticFeedback.mediumImpact();
                  try {
                    final count = await ref
                        .read(trustedContactsProvider.notifier)
                        .syncPhonebookNow();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.accentTeal,
                          content: Text(
                            count >= 0
                                ? '✅ Successfully synced $count contacts to MongoDB'
                                : '⚠️ Contacts permission needed to sync',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sync error: $e')),
                      );
                    }
                  }
                },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                contactsState.isSyncingPhonebook
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentTeal,
                        ),
                      )
                    : const Icon(Icons.sync_rounded, color: AppColors.accentTeal, size: 16),
                const SizedBox(width: 6),
                Text(
                  contactsState.isSyncingPhonebook ? 'Syncing...' : 'Sync Phone',
                  style: const TextStyle(
                    color: AppColors.accentTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedTabSwitcher(TrustedContactsState contactsState) {
    final trustedCount = contactsState.trustedContacts.length;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = 0);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? AppColors.accentTeal.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedTab == 0
                        ? AppColors.accentTeal.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.contact_phone_rounded,
                      size: 16,
                      color: _selectedTab == 0 ? AppColors.accentTeal : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Emergency Contacts',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w600,
                        color: _selectedTab == 0 ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                    if (trustedCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentTeal,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$trustedCount',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = 1);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? AppColors.accentTeal.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedTab == 1
                        ? AppColors.accentTeal.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      size: 16,
                      color: _selectedTab == 1 ? AppColors.accentTeal : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'App Guardians',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w600,
                        color: _selectedTab == 1 ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── EMERGENCY CONTACTS LIST & SELECTION UI ──────────────────────────────────
  Widget _buildEmergencyContactsSection(TrustedContactsState state) {
    final lastSyncText = state.lastSyncTime != null
        ? 'Last synced: ${DateFormat('MMM d, h:mm a').format(state.lastSyncTime!)}'
        : 'Uploaded to DB';

    // Filter contacts based on search and toggle
    List<Map<String, dynamic>> displayed = state.deviceContacts;
    if (_filterOnlyTrusted) {
      displayed = displayed.where((c) {
        final phone = (c['primaryPhone'] ?? c['phone'] ?? '').toString();
        return state.isPhoneTrusted(phone);
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        GlassCard(
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          borderColor: Colors.white.withValues(alpha: 0.1),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              icon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
              hintText: 'Search phone contacts...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              border: InputBorder.none,
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref.read(trustedContactsProvider.notifier).setSearchQuery('');
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              ref.read(trustedContactsProvider.notifier).setSearchQuery(val);
            },
          ),
        ),
        const SizedBox(height: 12),

        // Subheader filter row & status
        Row(
          children: [
            Text(
              lastSyncText,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // Filter chip
            FilterChip(
              label: Text(
                _filterOnlyTrusted ? 'Showing: To Notify' : 'All Uploaded (${state.deviceContacts.length})',
                style: TextStyle(
                  color: _filterOnlyTrusted ? AppColors.accentTeal : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: _filterOnlyTrusted,
              selectedColor: AppColors.accentTeal.withValues(alpha: 0.2),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              side: BorderSide(
                color: _filterOnlyTrusted ? AppColors.accentTeal : Colors.white.withValues(alpha: 0.1),
              ),
              onSelected: (val) => setState(() => _filterOnlyTrusted = val),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (state.isLoading && state.deviceContacts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: AppColors.accentTeal),
            ),
          )
        else if (displayed.isEmpty)
          _buildEmptyContactsCard(state)
        else
          ...displayed.map((c) {
            final name = (c['name'] ?? 'Unknown').toString();
            final phone = (c['primaryPhone'] ?? c['phone'] ?? '').toString();
            final isTrusted = state.isPhoneTrusted(phone);
            final trustedItem = state.getTrustedItem(phone);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildContactCard(
                name: name,
                phone: phone,
                isTrusted: isTrusted,
                trustedItem: trustedItem,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildContactCard({
    required String name,
    required String phone,
    required bool isTrusted,
    required TrustedContactItem? trustedItem,
  }) {
    return GlassCard(
      borderRadius: 18,
      fillColor: isTrusted
          ? AppColors.accentTeal.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.02),
      borderColor: isTrusted
          ? AppColors.accentTeal.withValues(alpha: 0.35)
          : Colors.white.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: () {
          if (isTrusted) {
            _openContactAlertSettingsSheet(context, name, phone);
          } else {
            HapticFeedback.lightImpact();
            ref.read(trustedContactsProvider.notifier).toggleTrusted(
                  name: name,
                  phone: phone,
                );
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isTrusted
                    ? AppColors.accentTeal.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: isTrusted ? AppColors.accentTeal : Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isTrusted ? AppColors.accentTeal : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Name & Phone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    phone,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (isTrusted && trustedItem != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (trustedItem.notifyOnSos)
                          _buildAlertBadge('SOS', AppColors.accentCrimson),
                        if (trustedItem.notifyOnThreat)
                          _buildAlertBadge('THREAT', AppColors.accentAmber),
                        if (trustedItem.notifyOnNightMode)
                          _buildAlertBadge('NIGHT', const Color(0xFF6B5CE7)),
                        const Spacer(),
                        const Text(
                          'Tap to configure',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Toggle Notify Button / Switch
            IconButton(
              icon: Icon(
                isTrusted ? Icons.notifications_active_rounded : Icons.notification_add_outlined,
                color: isTrusted ? AppColors.accentTeal : AppColors.textMuted,
                size: 24,
              ),
              tooltip: isTrusted ? 'Remove from Notify list' : 'Choose to notify',
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(trustedContactsProvider.notifier).toggleTrusted(
                      name: name,
                      phone: phone,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildEmptyContactsCard(TrustedContactsState state) {
    return GlassCard(
      borderRadius: 20,
      borderColor: Colors.white.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.contacts_rounded, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 14),
          Text(
            _filterOnlyTrusted
                ? 'No Trusted Contacts Selected'
                : 'No Contacts Found',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _filterOnlyTrusted
                ? 'Toggle any contact above to include them in your emergency SOS circle.'
                : 'Tap "Sync Phone" above to upload your device contacts to the database.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── APP GUARDIANS TAB (PEER-TO-PEER MESH) ──────────────────────────────────
  Widget _buildAppGuardiansSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLiveLocationCard(l10n),
        const SizedBox(height: 20),

        // Status bar
        GlassCard(
          borderRadius: 16,
          borderColor: AppColors.accentTeal.withValues(alpha: 0.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _guardians.isNotEmpty ? AppColors.accentTeal : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _isLoadingGuardians
                    ? l10n.loadingGuardianNetwork
                    : _guardians.isEmpty
                        ? l10n.noNodesLinked
                        : '${_guardians.length} ${l10n.nodesLinkedActive}',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  color: _guardians.isNotEmpty ? AppColors.accentTeal : AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() => _isLoadingGuardians = true);
                  _fetchNetwork();
                },
                child: const Icon(Icons.refresh_rounded, color: AppColors.textMuted, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          l10n.linkedNodes,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        if (_isLoadingGuardians)
          const Center(child: CircularProgressIndicator(color: AppColors.accentTeal))
        else if (_guardians.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              l10n.noGuardians,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._guardians.map((g) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildGuardianNode(
                g['displayName'] ?? 'Unknown',
                g['phone'] ?? g['email'] ?? '',
                true,
                '🛡️',
                g['photoUrl'],
              ),
            );
          }),

        const SizedBox(height: 16),

        // Add guardian button
        GlassCard(
          borderRadius: 20,
          blurSigma: 16,
          fillColor: AppColors.accentTeal.withValues(alpha: 0.05),
          borderColor: AppColors.accentTeal.withValues(alpha: 0.3),
          child: InkWell(
            onTap: _showAddGuardianDialog,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_link_rounded, color: AppColors.accentTeal, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    l10n.securelyLinkNewNode,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentTeal,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuardianNode(
    String name,
    String email,
    bool isSynced,
    String fallbackAvatar,
    String? photoUrl,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = isSynced ? AppColors.accentTeal : AppColors.statusOffline;

    return GlassCard(
      borderRadius: 20,
      blurSigma: 16,
      fillColor: Colors.white.withValues(alpha: 0.03),
      borderColor: isSynced
          ? AppColors.accentTeal.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.1),
              border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
              image: photoUrl != null
                  ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: photoUrl == null
                ? Center(child: Text(fallbackAvatar, style: const TextStyle(fontSize: 22)))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              isSynced ? l10n.synced : l10n.offlineStatus,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: statusColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLocationCard(AppLocalizations l10n) {
    return GlassCard(
      borderRadius: 24,
      borderColor: AppColors.accentAmber.withValues(alpha: 0.3),
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              color: Colors.black.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentAmber.withValues(alpha: 0.2),
                      border: Border.all(color: AppColors.accentAmber, width: 2),
                    ),
                    child: const Icon(Icons.location_on, color: AppColors.accentAmber, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Live Guardian Mesh Active',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.visibility, color: AppColors.accentAmber, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.liveGuardianView,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        l10n.locationSharingEnabled,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
