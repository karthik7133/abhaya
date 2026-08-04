import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';

class SafetyLearningScreen extends ConsumerWidget {
  const SafetyLearningScreen({super.key});

  static const List<_SafetyTopic> _topics = [
    _SafetyTopic(
      icon: Icons.warning_amber_rounded,
      color: AppColors.accentCrimson,
      title: 'Recognizing Threats',
      subtitle: 'How to identify and respond to dangerous situations quickly.',
      lessons: [
        _Lesson(
          title: 'Situational Awareness',
          content: 'Always be aware of your surroundings. Scan the area regularly, identify exits, and trust your instincts. If something feels wrong, it probably is.',
          duration: '5 min',
        ),
        _Lesson(
          title: 'Reading Body Language',
          content: 'Learn to recognize aggressive postures, intense staring, or someone following you. Cross the street if you feel threatened.',
          duration: '7 min',
        ),
        _Lesson(
          title: 'Threat Assessment',
          content: 'Quickly assess: Is the threat immediate? Do you have an escape route? Should you call for help or hide?',
          duration: '10 min',
        ),
      ],
    ),
    _SafetyTopic(
      icon: Icons.route_outlined,
      color: AppColors.accentAmber,
      title: 'Safe Travel Habits',
      subtitle: 'Best practices for staying safe while commuting or traveling.',
      lessons: [
        _Lesson(
          title: 'Planning Safe Routes',
          content: 'Use well-lit, populated streets. Avoid shortcuts through isolated areas. Share your route with trusted contacts.',
          duration: '6 min',
        ),
        _Lesson(
          title: 'Nighttime Travel Tips',
          content: 'Walk confidently, stay in well-lit areas, keep your phone charged, and have emergency contacts ready.',
          duration: '8 min',
        ),
        _Lesson(
          title: 'Public Transport Safety',
          content: 'Sit near the driver or conductor, stay awake, and know your stops. Have your exit planned before boarding.',
          duration: '7 min',
        ),
      ],
    ),
    _SafetyTopic(
      icon: Icons.people_outline,
      color: AppColors.accentTeal,
      title: 'Community Safety',
      subtitle: 'How community networks make everyone safer.',
      lessons: [
        _Lesson(
          title: 'Building Trust Circles',
          content: 'Create a network of trusted friends, family, and neighbors who can support each other during emergencies.',
          duration: '5 min',
        ),
        _Lesson(
          title: 'Sharing Intel',
          content: 'Report suspicious activities to your community. Information sharing helps prevent crimes in your area.',
          duration: '6 min',
        ),
        _Lesson(
          title: 'Emergency Coordination',
          content: 'Establish emergency protocols with your community. Know who to call and what information to share.',
          duration: '8 min',
        ),
      ],
    ),
    _SafetyTopic(
      icon: Icons.phone_android_outlined,
      color: AppColors.accentTeal,
      title: 'Using Abhaya Effectively',
      subtitle: 'Get the most out of your AI safety guardian.',
      lessons: [
        _Lesson(
          title: 'SOS Button Mastery',
          content: 'Practice using the SOS button. In emergencies, muscle memory helps. Know how to cancel if triggered accidentally.',
          duration: '4 min',
        ),
        _Lesson(
          title: 'Guardian Setup',
          content: 'Add trusted guardians who will receive your alerts. Keep their information updated and test the system regularly.',
          duration: '6 min',
        ),
        _Lesson(
          title: 'Live Protection Settings',
          content: 'Configure sensitivity levels, notification preferences, and automatic features for your safety needs.',
          duration: '7 min',
        ),
      ],
    ),
    _SafetyTopic(
      icon: Icons.medical_services_outlined,
      color: AppColors.accentAmber,
      title: 'Emergency First Aid',
      subtitle: 'Essential first aid knowledge for common emergencies.',
      lessons: [
        _Lesson(
          title: 'Basic First Aid Steps',
          content: 'Remember DRABC: Danger, Response, Airway, Breathing, Circulation. Call emergency services immediately.',
          duration: '10 min',
        ),
        _Lesson(
          title: 'Calling for Help',
          content: 'Know emergency numbers. Speak clearly, state your location, describe the situation, and don\'t hang up first.',
          duration: '5 min',
        ),
        _Lesson(
          title: 'Stabilizing an Injured Person',
          content: 'Keep the person calm and warm. Don\'t move them if spine injury is suspected. Control bleeding with pressure.',
          duration: '12 min',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAppBar(context),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: _topics.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) =>
                      _TopicCard(topic: _topics[i]).animate().fadeIn(delay: Duration(milliseconds: i * 80)).slideY(begin: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Safety Learning',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 20,
                  fontWeight: FontWeight.w800, color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Knowledge is your best shield',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Lesson {
  final String title;
  final String content;
  final String duration;

  const _Lesson({
    required this.title,
    required this.content,
    required this.duration,
  });
}

class _SafetyTopic {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<_Lesson> lessons;

  const _SafetyTopic({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.lessons,
  });
}

class _TopicCard extends StatefulWidget {
  final _SafetyTopic topic;
  const _TopicCard({required this.topic});

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: GlassCard(
        borderRadius: 20,
        borderColor: widget.topic.color.withValues(alpha: 0.25),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 48, width: 48,
                    decoration: BoxDecoration(
                      color: widget.topic.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.topic.icon, color: widget.topic.color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.topic.title, style: const TextStyle(
                          fontFamily: 'PlusJakartaSans', fontSize: 16, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                        const SizedBox(height: 4),
                        Text(widget.topic.subtitle, style: const TextStyle(
                          fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textSecondary,
                        )),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.topic.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: widget.topic.color,
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 20),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 16),
                ...widget.topic.lessons.asMap().entries.map((entry) {
                  final index = entry.key;
                  final lesson = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LessonDetailScreen(
                              lesson: lesson,
                              topicColor: widget.topic.color,
                              topicTitle: widget.topic.title,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.topic.color.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: widget.topic.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: widget.topic.color,
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
                                    lesson.title,
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.schedule, color: AppColors.textMuted, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        lesson.duration,
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: widget.topic.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: widget.topic.color,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LessonDetailScreen extends StatelessWidget {
  final _Lesson lesson;
  final Color topicColor;
  final String topicTitle;

  const LessonDetailScreen({
    super.key,
    required this.lesson,
    required this.topicColor,
    required this.topicTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          topicTitle,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: topicColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: topicColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school_rounded, color: topicColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          lesson.title,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: topicColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.schedule, color: AppColors.textMuted, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        lesson.duration,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Lesson Content',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              lesson.content,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: topicColor, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    'Mark as complete',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: false,
                    onChanged: (value) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: topicColor,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          content: const Text(
                            'Lesson marked as complete!',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                    activeColor: topicColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
