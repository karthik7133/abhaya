import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/services/backend_service.dart';
import '../../../l10n/app_localizations.dart';

class GuardiansScreen extends StatefulWidget {
  const GuardiansScreen({super.key});

  @override
  State<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends State<GuardiansScreen> {
  bool _isLoading = true;
  List<dynamic> _guardians = [];

  @override
  void initState() {
    super.initState();
    _fetchNetwork();
  }

  Future<void> _fetchNetwork() async {
    try {
      final res = await BackendService.getMyNetwork();
      // Fetch pending too but just ignore for now — future UI feature
      BackendService.getPendingRequests().then((_) {}).catchError((_) {});
      if (mounted) {
        setState(() {
          _guardians = res['guardians'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        title: Text(l10n.addGuardian, style: TextStyle(color: AppColors.textPrimary)),
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
            child: Text(l10n.cancel, style: TextStyle(color: AppColors.textSecondary)),
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
            child: Text(l10n.sendRequest, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          _buildHeader(),
          const SizedBox(height: 24),
          _buildLiveLocationCard(),
          const SizedBox(height: 24),
          const SizedBox(height: 28),

          // Dynamic status bar
          GlassCard(
            borderRadius: 16,
            borderColor: AppColors.accentTeal.withValues(alpha: 0.2),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _guardians.isNotEmpty ? AppColors.accentTeal : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _isLoading
                      ? l10n.loadingGuardianNetwork
                      : _guardians.isEmpty
                          ? l10n.noNodesLinked
                          : '${_guardians.length} ${l10n.nodesLinkedActive}',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans', fontSize: 13,
                    color: _guardians.isNotEmpty ? AppColors.accentTeal : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () { setState(() { _isLoading = true; }); _fetchNetwork(); },
                  child: const Icon(Icons.refresh_rounded, color: AppColors.textMuted, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            l10n.linkedNodes,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          const SizedBox(height: 12),

          if (_isLoading)
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
                  true, // connected
                  '🛡️',
                  g['photoUrl'],
                ),
              );
            }),
          
          const SizedBox(height: 16),

          // Add guardian
          GlassCard(
            borderRadius: 20,
            blurSigma: 16,
            fillColor: AppColors.accentTeal.withValues(alpha: 0.05),
            borderColor: AppColors.accentTeal.withValues(alpha: 0.3),
            shadows: [
              BoxShadow(
                color: AppColors.accentTeal.withValues(alpha: 0.1),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
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
      ),
    ),
  );
}

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.myTrustCircle,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.trustCircleDesc,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildGuardianNode(String name, String email, bool isSynced, String fallbackAvatar, String? photoUrl) {
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
      shadows: [
        BoxShadow(
          color: statusColor.withValues(alpha: 0.05),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ],
      child: Row(
        children: [
          // Avatar
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

          // Info
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

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: [
                      BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isSynced ? l10n.synced : l10n.offlineStatus,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLocationCard() {
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      borderRadius: 24,
      borderColor: AppColors.accentAmber.withValues(alpha: 0.3),
      shadows: [
        BoxShadow(
          color: AppColors.accentAmber.withValues(alpha: 0.1),
          blurRadius: 30,
          spreadRadius: 2,
        ),
      ],
      child: Column(
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              color: Colors.black.withValues(alpha: 0.2),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MockGridPainter(),
                  ),
                ),
                Center(
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
                          'Karthik • Moving (14 km/h)',
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
              ],
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

class _MockGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
