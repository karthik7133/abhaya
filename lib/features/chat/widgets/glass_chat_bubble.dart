import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// GlassChatBubble — Reusable glassmorphic message bubble.
/// [isMe]      → aligns right with teal glow (user messages)
/// [isAI]      → aligns left with violet glow (AI messages)
/// [isAudio]   → renders an audio waveform player instead of text
class GlassChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final bool isAI;
  final bool isAudio;
  final String? timestamp;

  const GlassChatBubble({
    super.key,
    required this.message,
    this.isMe = false,
    this.isAI = false,
    this.isAudio = false,
    this.timestamp,
  });

  Color get _accentColor {
    if (isMe) return AppColors.accentTeal;
    if (isAI) return const Color(0xFFB5179E); // Electric Violet
    return AppColors.accentAmber; // Guardian
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildBubble(context),
                if (timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Text(
                      timestamp!,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        color: AppColors.textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _accentColor.withValues(alpha: 0.1),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(
        isAI ? Icons.auto_awesome_rounded : Icons.person_outline_rounded,
        color: _accentColor,
        size: 16,
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final accent = _accentColor;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
        bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          padding: isAudio
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe
                ? accent.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft:
                  isMe ? const Radius.circular(18) : const Radius.circular(4),
              bottomRight:
                  isMe ? const Radius.circular(4) : const Radius.circular(18),
            ),
            border: Border.all(
              color: accent.withValues(alpha: isMe ? 0.3 : 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isAudio ? _buildAudioWaveform(accent) : _buildTextContent(accent),
        ),
      ),
    );
  }

  Widget _buildTextContent(Color accent) {
    return Text(
      message,
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: isMe ? AppColors.textPrimary : AppColors.textPrimary.withValues(alpha: 0.9),
        height: 1.45,
      ),
    );
  }

  Widget _buildAudioWaveform(Color accent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play button
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.15),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.play_arrow_rounded, color: accent, size: 18),
        ),
        const SizedBox(width: 10),
        // Waveform bars
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(18, (i) {
            final heights = [12.0, 20.0, 8.0, 24.0, 14.0, 28.0, 10.0, 22.0, 16.0,
                             26.0, 12.0, 20.0, 8.0, 18.0, 24.0, 10.0, 14.0, 8.0];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 2.5,
                height: heights[i],
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: i < 10 ? 0.9 : 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 10),
        Text(
          '0:12',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            color: accent.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
