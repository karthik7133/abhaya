import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/services/backend_service.dart';
import '../widgets/glass_chat_bubble.dart';
import '../widgets/glass_input_field.dart';
import '../../../l10n/app_localizations.dart';

// ── AI accent ─────────────────────────────────────────────────────────────────
const _kViolet = Color(0xFFB5179E);

enum MessageType { text, crisisResources }

class _ChatMessage {
  final String text;
  final bool isMe;
  final MessageType type;
  const _ChatMessage(this.text, {this.isMe = false, this.type = MessageType.text});
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late AnimationController _orbPulse;

  bool _isLoading = true;
  bool _isTyping = false;
  List<_ChatMessage> _messages = [];

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  final List<Map<String, dynamic>> _quickCommands = const [
    {'labelKey': 'iFeelAnxious', 'icon': Icons.favorite_border, 'color': AppColors.accentTeal},
    {'labelKey': 'trackMyRoute', 'icon': Icons.route_rounded, 'color': _kViolet},
    {'labelKey': 'shareLocation', 'icon': Icons.share_location_rounded, 'color': AppColors.accentAmber},
    {'labelKey': 'fakeCall', 'icon': Icons.phone_in_talk_rounded, 'color': AppColors.accentTeal},
  ];


  @override
  void initState() {
    super.initState();
    _orbPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    
    _loadHistory();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _toggleListening() async {
    if (!_speechEnabled) return;

    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _ctrl.text = result.recognizedWords;
          });
          if (result.finalResult) {
            setState(() => _isListening = false);
            // Optional: Auto-send when final result is done
            // _handleSend(); 
          }
        },
      );
    }
  }

  Future<void> _loadHistory() async {
    try {
      final res = await BackendService.getChatHistory(page: 1);
      final List<dynamic> history = res['history'] as List<dynamic>? ?? [];

      // Backend returns flat Message docs: { text, isUser, crisisResourcesShown, ... }
      final List<_ChatMessage> loaded = history.map((msg) {
        final m = msg as Map<String, dynamic>;
        final isCrisis = m['crisisResourcesShown'] == true;
        return _ChatMessage(
          m['text'] as String? ?? '',
          isMe: m['isUser'] as bool? ?? false,
          type: isCrisis && !(m['isUser'] as bool? ?? false)
              ? MessageType.crisisResources
              : MessageType.text,
        );
      }).toList();

      if (loaded.isEmpty) {
        loaded.add(const _ChatMessage(
          'Hi there. I\'m your Abhaya Companion. How are you feeling right now?',
          isMe: false,
        ));
      }

      if (mounted) {
        setState(() {
          _messages = loaded;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chat: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(50.ms, () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 120,
          duration: 300.ms,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _orbPulse.dispose();
    super.dispose();
  }

  Future<void> _handleSend([String? quickText]) async {
    final text = quickText ?? _ctrl.text.trim();
    if (text.isEmpty) return;
    if (quickText == null) _ctrl.clear();

    setState(() {
      _messages.add(_ChatMessage(text, isMe: true));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final res = await BackendService.sendChatMessage(text);
      final aiText = res.aiMessage['text'] as String? ?? 'I am here for you.';
      final showResources = res.crisisResourcesShown;

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(_ChatMessage(
            aiText,
            isMe: false,
            type: showResources ? MessageType.crisisResources : MessageType.text,
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          // Show a friendly AI response instead of a scary error
          final isTimeout = e.toString().contains('warming up') || e.toString().contains('TimeoutException');
          _messages.add(_ChatMessage(
            isTimeout
                ? '⏳ My AI core is still warming up (large model loading). Please send your message again in 30 seconds!'
                : "I'm having a brief connection issue. Please check that the backend is running and try again.",
            isMe: false,
          ));
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!
;
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
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accentTeal))
                    : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _messages.length && _isTyping) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: GlassCard(
                            borderRadius: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Text(l10n.thinking, style: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                          ),
                        ),
                      );
                    }
                    
                    final m = _messages[i];
                    if (m.type == MessageType.crisisResources) {
                      return _buildCrisisResources(m).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
                    }
                    return GlassChatBubble(
                      message: m.text,
                      isMe: m.isMe,
                      isAI: !m.isMe,
                      timestamp: '',
                    ).animate().fadeIn(duration: 350.ms, delay: (i * 60).ms)
                        .slideY(begin: 0.15, end: 0, duration: 300.ms);
                  },
                ),
              ),
              _buildQuickCommands(),
              GlassInputField(
                controller: _ctrl,
                onSend: _handleSend,
                onMicTap: _toggleListening,
                hintText: _isListening ? l10n.thinking : l10n.typeMessage,
                accentColor: _isListening ? AppColors.accentCrimson : _kViolet,
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

          // Pulsing AI orb avatar
          AnimatedBuilder(
            animation: _orbPulse,
            builder: (_, __) => Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kViolet.withValues(alpha: 0.12),
                border: Border.all(
                  color: _kViolet.withValues(alpha: 0.3 + _orbPulse.value * 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kViolet.withValues(alpha: 0.15 + _orbPulse.value * 0.2),
                    blurRadius: 14 + _orbPulse.value * 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: _kViolet, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Abhaya Companion',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
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
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Here for you',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Remove threat badge from chat, keep it focused on companion/mood
        ],
      ),
    );
  }

  Widget _buildCrisisResources(_ChatMessage m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassChatBubble(
            message: m.text,
            isMe: false,
            isAI: true,
            timestamp: '',
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 48, right: 24),
            child: GlassCard(
              borderRadius: 16,
              borderColor: AppColors.accentCrimson.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.support_agent_rounded, color: AppColors.accentCrimson, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Crisis Support Resources',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentCrimson,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'National Emergency Helpline\n112',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mental Health Support (AASRA)\n9820466726',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentCrimson,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text(
                          'Call Helpline Now',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () {},
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

  Widget _buildQuickCommands() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _quickCommands.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cmd = _quickCommands[i];
          final color = cmd['color'] as Color;
          return GestureDetector(
            onTap: () => _handleSend(cmd['label'] as String),
            child: GlassCard(
              borderRadius: 20,
              borderColor: color.withValues(alpha: 0.25),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cmd['icon'] as IconData, color: color, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    cmd['label'] as String,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
