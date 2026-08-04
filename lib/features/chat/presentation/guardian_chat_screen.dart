import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/glass_chat_bubble.dart';
import '../widgets/glass_input_field.dart';

class _GuardianMessage {
  final String text;
  final bool isMe;
  final bool isAudio;
  final String time;
  const _GuardianMessage(this.text,
      {this.isMe = false, this.isAudio = false, this.time = ''});
}

class GuardianChatScreen extends StatefulWidget {
  final String guardianName;
  final String guardianRole;

  const GuardianChatScreen({
    super.key,
    this.guardianName = 'Primary Node (Father)',
    this.guardianRole = 'Guardian',
  });

  @override
  State<GuardianChatScreen> createState() => _GuardianChatScreenState();
}

class _GuardianChatScreenState extends State<GuardianChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<_GuardianMessage> _messages = const [
    _GuardianMessage('Hey, I activated your tracker. Stay safe tonight.', time: '9:15 PM'),
    _GuardianMessage('Thanks Dad. I\'m at the metro station now.', isMe: true, time: '9:16 PM'),
    _GuardianMessage('', isAudio: true, time: '9:18 PM'),
    _GuardianMessage('Got it. I can see your location on the app. The route looks clear.', time: '9:19 PM'),
    _GuardianMessage('Almost home. Threat score is at 8%, all good!', isMe: true, time: '9:24 PM'),
    _GuardianMessage('Great. I\'ll stay online until you\'re back. Text me when you arrive.', time: '9:24 PM'),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
              _buildAppBar(context),
              _buildDateDivider('Today'),
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    return GlassChatBubble(
                      message: m.text,
                      isMe: m.isMe,
                      isAudio: m.isAudio,
                      timestamp: m.time,
                    ).animate()
                        .fadeIn(duration: 320.ms, delay: (i * 50).ms)
                        .slideY(begin: 0.12, end: 0, duration: 280.ms);
                  },
                ),
              ),
              _buildEncryptedBadge(),
              GlassInputField(
                controller: _ctrl,
                onSend: () {
                  if (_ctrl.text.trim().isNotEmpty) {
                    setState(() {});
                    _ctrl.clear();
                  }
                },
                onMicTap: () {},
                onAttachTap: () {},
                hintText: 'Secure message to ${widget.guardianName.split(' ').first}...',
                showAttachment: true,
                accentColor: AppColors.accentAmber,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textSecondary, size: 16),
            ),
          ),
          const SizedBox(width: 12),

          // Guardian avatar
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentAmber.withValues(alpha: 0.1),
                  border: Border.all(
                      color: AppColors.accentAmber.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Text('👨', style: TextStyle(fontSize: 20)),
                ),
              ),
              // Live indicator
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentTeal,
                    border:
                        Border.all(color: AppColors.bgDeep, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentTeal.withValues(alpha: 0.7),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.guardianName,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentTeal,
                      ),
                    ).animate(onPlay: (c) => c.repeat())
                        .scaleXY(end: 1.4, duration: 700.ms)
                        .then()
                        .scaleXY(end: 1.0, duration: 700.ms),
                    const SizedBox(width: 5),
                    const Text(
                      'Live Sync • Receiving telemetry',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        color: AppColors.accentTeal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Location share button
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentTeal.withValues(alpha: 0.08),
                border: Border.all(
                    color: AppColors.accentTeal.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.share_location_rounded,
                  color: AppColors.accentTeal, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.white.withValues(alpha: 0.07),
              indent: 16,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.white.withValues(alpha: 0.07),
              endIndent: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncryptedBadge() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_rounded,
              size: 11, color: AppColors.textMuted.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Text(
            'End-to-end encrypted · Abhaya Secure Channel',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 10,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
