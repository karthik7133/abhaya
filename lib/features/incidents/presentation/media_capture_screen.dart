import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/common_widgets/neon_button.dart';

class MediaCaptureScreen extends StatefulWidget {
  const MediaCaptureScreen({super.key});

  @override
  State<MediaCaptureScreen> createState() => _MediaCaptureScreenState();
}

class _MediaCaptureScreenState extends State<MediaCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _capturedMedia;
  bool _isCapturing = false;

  Future<void> _capturePhoto() async {
    HapticFeedback.mediumImpact();
    setState(() => _isCapturing = true);
    
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        setState(() {
          _capturedMedia = file;
          _isCapturing = false;
        });
      } else if (mounted) {
        setState(() => _isCapturing = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _recordVideo() async {
    HapticFeedback.mediumImpact();
    setState(() => _isCapturing = true);
    
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
      );
      if (file != null && mounted) {
        setState(() {
          _capturedMedia = file;
          _isCapturing = false;
        });
      } else if (mounted) {
        setState(() => _isCapturing = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    HapticFeedback.lightImpact();
    setState(() => _isCapturing = true);
    
    try {
      final file = await _picker.pickMedia();
      if (file != null && mounted) {
        setState(() {
          _capturedMedia = file;
          _isCapturing = false;
        });
      } else if (mounted) {
        setState(() => _isCapturing = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _proceedToReport() {
    if (_capturedMedia != null) {
      context.push('/incident-report?mediaPath=${_capturedMedia!.path}');
    }
  }

  void _retake() {
    HapticFeedback.lightImpact();
    setState(() => _capturedMedia = null);
  }

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
              Expanded(
                child: _capturedMedia == null 
                    ? _buildCaptureOptions()
                    : _buildPreview(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Capture Evidence',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureOptions() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Choose capture method',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          
          _captureOption(
            icon: Icons.camera_alt_rounded,
            label: 'Take Photo',
            description: 'Capture a photo instantly',
            color: AppColors.accentTeal,
            onTap: _isCapturing ? null : _capturePhoto,
            isLoading: _isCapturing,
          ),
          const SizedBox(height: 16),
          
          _captureOption(
            icon: Icons.videocam_rounded,
            label: 'Record Video',
            description: 'Record up to 60 seconds',
            color: AppColors.accentAmber,
            onTap: _isCapturing ? null : _recordVideo,
            isLoading: _isCapturing,
          ),
          const SizedBox(height: 16),
          
          _captureOption(
            icon: Icons.photo_library_rounded,
            label: 'From Gallery',
            description: 'Choose from your device',
            color: AppColors.textSecondary,
            onTap: _isCapturing ? null : _pickFromGallery,
            isLoading: _isCapturing,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _captureOption({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GlassCard(
      borderRadius: 20,
      borderColor: color.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
                        ),
                      )
                    : Icon(
                        icon,
                        color: color,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Review your capture',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: GlassCard(
              borderRadius: 20,
              borderColor: AppColors.accentTeal.withValues(alpha: 0.2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _capturedMedia != null
                    ? Image.file(
                        File(_capturedMedia!.path),
                        fit: BoxFit.contain,
                      )
                    : const SizedBox(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  label: 'RETAKE',
                  leadingIcon: Icons.refresh_rounded,
                  variant: NeonButtonVariant.ghost,
                  height: 52,
                  onPressed: _retake,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeonButton(
                  label: 'CONTINUE TO REPORT',
                  leadingIcon: Icons.arrow_forward_rounded,
                  variant: NeonButtonVariant.primary,
                  height: 52,
                  onPressed: _proceedToReport,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}
