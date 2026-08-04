import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';

// ─── Evidence Item Model ──────────────────────────────────────────────────────

enum EvidenceType { photo, video }

class EvidenceItem {
  final String path;
  final EvidenceType type;
  final DateTime capturedAt;
  final int sizeBytes;

  const EvidenceItem({
    required this.path,
    required this.type,
    required this.capturedAt,
    required this.sizeBytes,
  });

  String get fileName => path.split(Platform.pathSeparator).last;

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─── Evidence Screen ──────────────────────────────────────────────────────────

class EvidenceScreen extends StatefulWidget {
  const EvidenceScreen({super.key});

  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen>
    with TickerProviderStateMixin {
  final List<EvidenceItem> _items = [];
  bool _isCapturing = false;
  late AnimationController _fabPulse;

  @override
  void initState() {
    super.initState();
    _fabPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _loadExistingEvidence();
  }

  @override
  void dispose() {
    _fabPulse.dispose();
    super.dispose();
  }

  // ── Load existing evidence files from local vault ──────────────────────────

  Future<void> _loadExistingEvidence() async {
    try {
      final dir = await _evidenceDir();
      final entities = dir.listSync();
      final items = <EvidenceItem>[];

      for (final e in entities) {
        if (e is File) {
          final name = e.path.split(Platform.pathSeparator).last.toLowerCase();
          final isPhoto = name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png');
          final isVideo = name.endsWith('.mp4') || name.endsWith('.mov');
          if (!isPhoto && !isVideo) continue;

          final stat = e.statSync();
          items.add(EvidenceItem(
            path: e.path,
            type: isPhoto ? EvidenceType.photo : EvidenceType.video,
            capturedAt: stat.modified,
            sizeBytes: stat.size,
          ));
        }
      }

      items.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      if (mounted) {
        setState(() {
          _items
            ..clear()
            ..addAll(items);
        });
      }
    } catch (_) {}
  }

  Future<Directory> _evidenceDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/abhaya_evidence');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  // ── Capture actions ────────────────────────────────────────────────────────

  Future<void> _capturePhoto() async {
    HapticFeedback.mediumImpact();
    setState(() => _isCapturing = true);
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (photo != null) {
        await _saveToVault(photo.path, EvidenceType.photo);
      }
    } catch (e) {
      _showError('Camera access failed: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _captureVideo() async {
    HapticFeedback.mediumImpact();
    setState(() => _isCapturing = true);
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
      if (video != null) {
        await _saveToVault(video.path, EvidenceType.video);
      }
    } catch (e) {
      _showError('Video capture failed: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _importFromGallery() async {
    HapticFeedback.lightImpact();
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickMedia();
      if (file != null) {
        final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
        final isVideo = name.endsWith('.mp4') || name.endsWith('.mov');
        await _saveToVault(file.path, isVideo ? EvidenceType.video : EvidenceType.photo);
      }
    } catch (e) {
      _showError('Import failed: $e');
    }
  }

  Future<void> _saveToVault(String sourcePath, EvidenceType type) async {
    final dir = await _evidenceDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = type == EvidenceType.photo ? '.jpg' : '.mp4';
    final dest = File('${dir.path}/evidence_$ts$ext');

    await File(sourcePath).copy(dest.path);

    final stat = dest.statSync();
    final item = EvidenceItem(
      path: dest.path,
      type: type,
      capturedAt: DateTime.now(),
      sizeBytes: stat.size,
    );

    if (mounted) {
      setState(() => _items.insert(0, item));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.accentTeal,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(children: [
            const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'Evidence secured in vault',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ]),
        ),
      );
    }
  }

  Future<void> _deleteItem(EvidenceItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Evidence', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently remove this file from the vault.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.accentCrimson)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await File(item.path).delete();
        setState(() => _items.remove(item));
      } catch (_) {}
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.accentCrimson,
          content: Text(msg, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
              _buildHeader(),
              _buildCaptureRow(),
              Expanded(
                child: _items.isEmpty
                    ? _buildEmptyState()
                    : _buildVaultGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Evidence Vault',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              '${_items.length} file${_items.length == 1 ? '' : 's'} secured',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ]),
          const Spacer(),
          // Lock icon badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.security_rounded, color: AppColors.accentTeal, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: _captureButton(
              icon: Icons.camera_alt_rounded,
              label: 'Photo',
              color: AppColors.accentTeal,
              onTap: _capturePhoto,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _captureButton(
              icon: Icons.videocam_rounded,
              label: 'Video',
              color: AppColors.accentAmber,
              onTap: _captureVideo,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _captureButton(
              icon: Icons.photo_library_rounded,
              label: 'Import',
              color: AppColors.textSecondary,
              onTap: _importFromGallery,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
    );
  }

  Widget _captureButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isCapturing ? null : onTap,
      child: GlassCard(
        borderRadius: 16,
        borderColor: color.withValues(alpha: 0.3),
        fillColor: color.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isCapturing
                ? SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: color,
                    ),
                  )
                : Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentTeal.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.folder_open_rounded, color: AppColors.accentTeal, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Vault is Empty',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Capture photos, videos, or import\nfiles to secure them in your vault.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }

  Widget _buildVaultGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        return _EvidenceTile(
          item: _items[i],
          onDelete: () => _deleteItem(_items[i]),
          index: i,
        );
      },
    );
  }
}

// ─── Evidence Tile ────────────────────────────────────────────────────────────

class _EvidenceTile extends StatelessWidget {
  final EvidenceItem item;
  final VoidCallback onDelete;
  final int index;

  const _EvidenceTile({
    required this.item,
    required this.onDelete,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isPhoto = item.type == EvidenceType.photo;
    final color   = isPhoto ? AppColors.accentTeal : AppColors.accentAmber;
    final dt = item.capturedAt;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${months[dt.month - 1]} ${dt.day}, ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

    return GlassCard(
      borderRadius: 16,
      borderColor: color.withValues(alpha: 0.2),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail / preview area
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Actual image preview for photos
                  if (isPhoto)
                    Image.file(
                      File(item.path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(color),
                    )
                  else
                    _placeholder(color),

                  // Type badge
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          isPhoto ? Icons.photo_rounded : Icons.videocam_rounded,
                          color: color, size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPhoto ? 'PHOTO' : 'VIDEO',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ]),
                    ),
                  ),

                  // Delete button
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Info footer
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                dateStr,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.sizeFormatted,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ]),
          ),
        ],
      ),
    ).animate(delay: (index * 50).ms)
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _placeholder(Color color) {
    return Container(
      color: color.withValues(alpha: 0.07),
      child: Center(
        child: Icon(
          item.type == EvidenceType.photo
              ? Icons.photo_rounded
              : Icons.play_circle_outline_rounded,
          color: color.withValues(alpha: 0.5),
          size: 40,
        ),
      ),
    );
  }
}
