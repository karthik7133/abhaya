import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/common_widgets/neon_button.dart';
import '../../../core/services/backend_service.dart';
import '../../../l10n/app_localizations.dart';

class IncidentHistoryScreen extends StatefulWidget {
  const IncidentHistoryScreen({super.key});
  @override
  State<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends State<IncidentHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isLoading = true;
  List<dynamic> _events = [];
  List<dynamic> _reports = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }
  
  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final futures = await Future.wait([
        BackendService.getIncidentHistory(),
        BackendService.getMyIncidentReports(),
      ]);
      if (mounted) setState(() { 
        _events = futures[0]; 
        _reports = futures[1];
        _isLoading = false; 
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              TabBar(
                controller: _tabCtrl,
                indicatorColor: AppColors.accentTeal,
                labelColor: AppColors.accentTeal,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: l10n.emergenciesTab),
                  Tab(text: l10n.reportsTab),
                ],
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accentTeal))
                    : _error != null
                        ? _buildError()
                        : TabBarView(
                            controller: _tabCtrl,
                            children: [
                              _buildList(_events, _buildHistoryCard, l10n.noEmergenciesRecorded, Icons.history_toggle_off_rounded),
                              _buildList(_reports, _buildReportCard, l10n.noUserReports, Icons.report_gmailerrorred_rounded),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<dynamic> items, Widget Function(Map<String, dynamic>, int) builder, String emptyText, IconData emptyIcon) {
    if (items.isEmpty) return _buildEmpty(emptyText, emptyIcon);
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accentTeal,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final e = items[i] as Map<String, dynamic>;
          return builder(e, i)
              .animate()
              .fadeIn(delay: (i * 60).ms, duration: 350.ms)
              .slideY(begin: 0.1, end: 0, delay: (i * 60).ms);
        },
      ),
    );
  }

  Widget _buildError() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 16),
            Text('${l10n.failedToLoadHistory}\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'PlusJakartaSans')),
            const SizedBox(height: 20),
            NeonButton(label: l10n.retry, onPressed: () { setState(() { _isLoading = true; _error = null; }); _load(); }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String text, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 56),
          const SizedBox(height: 16),
          Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'PlusJakartaSans', height: 1.5)),
        ],
      ),
    ),
  );

  Widget _buildHistoryCard(Map<String, dynamic> e, int index) {
    final l10n = AppLocalizations.of(context)!;
    final type    = e['type']   as String? ?? 'unknown';
    final status  = e['status'] as String? ?? 'active';
    final score   = (e['threatScore'] as num?)?.toDouble() ?? 0;
    final createdAt = e['createdAt'] as String?;
    final notes   = e['resolutionNotes'] as String?;
    final lat     = e['location']?['lat'];
    final lng     = e['location']?['lng'];

    final Color accent;
    final IconData icon;
    final String title;

    switch (type) {
      case 'sos':
        accent = AppColors.accentCrimson;
        icon   = Icons.emergency_rounded;
        title  = l10n.manualSos;
        break;
      case 'chat_crisis':
        accent = AppColors.accentAmber;
        icon   = Icons.chat_bubble_outline_rounded;
        title  = l10n.crisisChatAlert;
        break;
      case 'audio_distress':
        accent = AppColors.accentTeal;
        icon   = Icons.mic_none_rounded;
        title  = l10n.audioDistressAlertLabel;
        break;
      case 'motion':
        accent = AppColors.accentAmber;
        icon   = Icons.screen_rotation_rounded;
        title  = l10n.motionAnomalyDetected;
        break;
      default:
        accent = AppColors.textSecondary;
        icon   = Icons.warning_amber_rounded;
        title  = type.replaceAll('_', ' ').toUpperCase();
    }

    final Color statusColor;
    final String statusLabel;
    switch (status) {
      case 'resolved': statusColor = AppColors.accentTeal;    statusLabel = l10n.resolved;  break;
      case 'dismissed': statusColor = AppColors.textMuted;    statusLabel = l10n.dismissed; break;
      default:          statusColor = AppColors.accentCrimson; statusLabel = l10n.active;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        borderRadius: 20,
        borderColor: accent.withValues(alpha: 0.2),
        padding: const EdgeInsets.all(20),
        child: _ExpandableIncident(
          title: title,
          date: _formatDate(createdAt),
          status: statusLabel,
          statusColor: statusColor,
          description: _buildDescription(type, score, lat, lng),
          resolutionNotes: notes ?? (status == 'active' ? l10n.incidentStillActive : l10n.noNotesProvided),
          icon: icon,
          eventId: e['_id'] as String?,
          isActive: status == 'active',
          onResolved: _load,
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> r, int index) {
    final l10n = AppLocalizations.of(context)!;
    final category = r['category'] as String? ?? 'unknown';
    final severity = r['severity'] as String? ?? 'low';
    final status   = r['status'] as String? ?? 'submitted';
    final createdAt = r['createdAt'] as String?;
    final desc     = r['description'] as String? ?? '';
    final mediaUrl = r['mediaUrl'] as String?;

    Color accent;
    switch(severity) {
      case 'critical': accent = AppColors.accentCrimson; break;
      case 'high': accent = const Color(0xFFFF6B6B); break;
      case 'medium': accent = AppColors.accentAmber; break;
      default: accent = AppColors.accentTeal;
    }

    Color statusColor;
    String statusLabel;
    switch(status) {
      case 'resolved': statusColor = AppColors.accentTeal; statusLabel = l10n.resolved; break;
      case 'under_review': statusColor = AppColors.accentAmber; statusLabel = l10n.reportsTab; break;
      default: statusColor = AppColors.textMuted; statusLabel = l10n.reportsTab;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        borderRadius: 20,
        borderColor: accent.withValues(alpha: 0.2),
        padding: const EdgeInsets.all(20),
        child: _ExpandableIncident(
          title: category.toUpperCase(),
          date: _formatDate(createdAt),
          status: statusLabel,
          statusColor: statusColor,
          description: '${l10n.severity}: ${severity.toUpperCase()}\n\n$desc',
          resolutionNotes: 'Status: $statusLabel',
          icon: Icons.report_problem_rounded,
          mediaUrl: mediaUrl,
          isActive: false,
          onResolved: _load,
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '--';
    final l10n = AppLocalizations.of(context)!;
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        return '${l10n.todayLabel} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      } else if (diff.inDays == 1) {
        return l10n.yesterdayLabel;
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) { return '--'; }
  }

  String _buildDescription(String type, double score, dynamic lat, dynamic lng) {
    final locationStr = (lat != null && lng != null)
        ? 'Location: ${(lat as num).toStringAsFixed(4)}, ${(lng as num).toStringAsFixed(4)}'
        : 'Location not available';
    return 'Type: ${type.replaceAll("_", " ")} | Threat Score: ${score.toInt()}%\n$locationStr';
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
          Text(
            AppLocalizations.of(context)!.incidentHistory,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }
}

// ── Expandable incident card ──────────────────────────────────────────────────

class _ExpandableIncident extends StatefulWidget {
  final String title, date, status, description, resolutionNotes;
  final Color statusColor;
  final IconData icon;
  final String? eventId;
  final bool isActive;
  final VoidCallback onResolved;
  final String? mediaUrl;

  const _ExpandableIncident({
    required this.title, required this.date, required this.status,
    required this.statusColor, required this.description,
    required this.resolutionNotes, required this.icon,
    this.eventId, required this.isActive, required this.onResolved,
    this.mediaUrl,
  });

  @override
  State<_ExpandableIncident> createState() => _ExpandableIncidentState();
}

class _ExpandableIncidentState extends State<_ExpandableIncident> {
  bool _isExpanded = false;
  bool _resolving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44, width: 44,
                decoration: BoxDecoration(
                  color: widget.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.statusColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: const TextStyle(
                      fontFamily: 'PlusJakartaSans', fontSize: 15,
                      fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                    )),
                    const SizedBox(height: 3),
                    Text(widget.date, style: const TextStyle(
                      fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textSecondary,
                    )),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: widget.statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(widget.status, style: TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 10,
                  fontWeight: FontWeight.w800, color: widget.statusColor, letterSpacing: 0.5,
                )),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Colors.white12),
                const SizedBox(height: 10),
                Text(l10n.incidentDetails, style: const TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 10,
                  fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5,
                )),
                const SizedBox(height: 6),
                Text(widget.description, style: const TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 13,
                  color: AppColors.textSecondary, height: 1.5,
                )),
                if (widget.mediaUrl != null && widget.mediaUrl!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(l10n.attachedMedia, style: const TextStyle(
                    fontFamily: 'PlusJakartaSans', fontSize: 10,
                    fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5,
                  )),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.mediaUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, trace) => Container(
                        height: 150,
                        color: Colors.white10,
                        child: const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(l10n.resolutionNotesLabel, style: const TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 10,
                  fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.5,
                )),
                const SizedBox(height: 6),
                Text(widget.resolutionNotes, style: const TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 13,
                  color: AppColors.textSecondary, height: 1.5,
                )),
                if (widget.isActive && widget.eventId != null) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: NeonButton(
                        label: _resolving ? l10n.resolvingStatus : l10n.markResolved,
                        isLoading: _resolving,
                        onPressed: _resolving ? null : () async {
                          setState(() => _resolving = true);
                          try {
                            await BackendService.resolveEvent(widget.eventId!);
                            widget.onResolved();
                          } catch (_) {
                            if (mounted) setState(() => _resolving = false);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NeonButton(
                        label: l10n.dismissed,
                        variant: NeonButtonVariant.ghost,
                        onPressed: () async {
                          try {
                            await BackendService.dismissEvent(widget.eventId!);
                            widget.onResolved();
                          } catch (_) {}
                        },
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }
}
