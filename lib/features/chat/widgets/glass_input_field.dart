import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// GlassInputField — Sleek bottom input dock for chat screens.
/// Transitions send icon ↔ mic icon based on text state.
class GlassInputField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onMicTap;
  final VoidCallback? onAttachTap;
  final String hintText;
  final bool showAttachment;
  final Color accentColor;

  const GlassInputField({
    super.key,
    required this.controller,
    required this.onSend,
    this.onMicTap,
    this.onAttachTap,
    this.hintText = 'Type a message...',
    this.showAttachment = false,
    this.accentColor = AppColors.accentTeal,
  });

  @override
  State<GlassInputField> createState() => _GlassInputFieldState();
}

class _GlassInputFieldState extends State<GlassInputField>
    with SingleTickerProviderStateMixin {
  bool _hasText = false;
  late AnimationController _micPulse;

  @override
  void initState() {
    super.initState();
    _micPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    widget.controller.addListener(() {
      final has = widget.controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _micPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF151B28).withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          child: Row(
            children: [
              // Attachment icon (optional)
              if (widget.showAttachment) ...[
                GestureDetector(
                  onTap: widget.onAttachTap,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Icon(Icons.attach_file_rounded,
                        color: AppColors.textMuted, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Text field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: _hasText
                          ? accent.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        color: AppColors.textMuted.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) {
                      if (_hasText) widget.onSend();
                    },
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Send / Mic button
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: _hasText
                    ? _SendButton(
                        key: const ValueKey('send'),
                        accent: accent,
                        onTap: widget.onSend,
                      )
                    : _MicButton(
                        key: const ValueKey('mic'),
                        accent: accent,
                        pulseCtrl: _micPulse,
                        onTap: widget.onMicTap,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  const _SendButton({super.key, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [accent, accent.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final Color accent;
  final AnimationController pulseCtrl;
  final VoidCallback? onTap;
  const _MicButton(
      {super.key,
      required this.accent,
      required this.pulseCtrl,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseCtrl,
        builder: (_, __) => Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.1),
            border: Border.all(
              color: accent.withValues(alpha: 0.3 + pulseCtrl.value * 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08 + pulseCtrl.value * 0.12),
                blurRadius: 10 + pulseCtrl.value * 8,
              ),
            ],
          ),
          child: Icon(Icons.mic_none_rounded, color: accent, size: 20),
        ),
      ),
    );
  }
}
