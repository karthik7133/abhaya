import { Router, Request, Response } from 'express';
import { Message, User, EmergencyEvent, MoodTrend } from '../models';
import { authMiddleware } from '../middleware/auth';
import { generateCompanionResponse } from '../services/ollamaService';
import { broadcastPush } from '../config/firebase';

const router = Router();

// ─── GET /api/chat/history ──────────────────────────────────────────────────
// Fetch chat history for the user (paginated)

router.get('/history', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const page = parseInt(req.query['page'] as string || '1');
  const limit = parseInt(req.query['limit'] as string || '50');

  try {
    const messages = await Message.find({ userId })
      .sort({ sentAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .lean();

    res.json(messages.reverse()); // return in chronological order
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch chat history' });
  }
});

// ─── POST /api/chat/send ────────────────────────────────────────────────────
// Send a message to the AI Companion.
// 1. Stores user message.
// 2. Calls Ollama for reply + risk assessment.
// 3. Stores AI reply.
// 4. Updates daily mood trend.
// 5. If high risk, surfaces crisis resources and optionally notifies guardians.

router.post('/send', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const { text } = req.body as { text: string };

  if (!text || text.trim() === '') {
    res.status(400).json({ error: 'Message text cannot be empty' });
    return;
  }

  try {
    // 1. Store user message
    const userMsg = await Message.create({
      userId,
      text,
      isUser: true,
    });

    // 2. Get recent history for context
    const recentMsgs = await Message.find({ userId })
      .sort({ sentAt: -1 })
      .limit(10)
      .lean();
    
    recentMsgs.reverse();
    const history = recentMsgs.map(m => ({
      role: m.isUser ? 'user' as const : 'assistant' as const,
      content: m.text,
    }));

    // 3. Call Ollama (reply + risk assessment)
    const { reply, riskLevel } = await generateCompanionResponse(text, history);

    // 4. Update Mood Trend (today)
    const today = new Date().toISOString().split('T')[0];
    await updateMoodTrend(userId, today, riskLevel);

    let crisisResourcesShown = false;

    // 5. Handle high risk (Crisis)
    if (riskLevel === 'high') {
      crisisResourcesShown = true;
      
      const user = await User.findOne({ uid: userId });
      if (user && user.settings.notifyGuardianOnCrisisChat && user.guardianIds.length > 0) {
        // Create an emergency event (chat_crisis type)
        await EmergencyEvent.create({
          userId,
          type: 'chat_crisis',
          threatScore: 85, // Assigned a nominal high threat score for crisis
          status: 'active',
          notifiedGuardianIds: user.guardianIds,
        });

        // Notify Guardians
        const guardians = await User.find({ uid: { $in: user.guardianIds } });
        const fcmTokens = guardians.map(g => g.fcmToken).filter((t): t is string => !!t);

        await broadcastPush({
          fcmTokens,
          title: '🚨 Crisis Alert',
          body: `${user.displayName} is experiencing a crisis and may need immediate emotional support.`,
          data: { type: 'chat_crisis', fromUid: userId },
        });
      }
    }

    // 6. Store AI reply
    const aiMsg = await Message.create({
      userId,
      text: reply,
      isUser: false,
      riskLevel,
      crisisResourcesShown,
    });

    res.json({
      userMessage: userMsg,
      aiMessage: aiMsg,
    });

  } catch (err) {
    console.error('[Chat] Error sending message:', err);
    res.status(500).json({ error: 'Failed to process chat message' });
  }
});

// Helper: Update daily mood trend
async function updateMoodTrend(userId: string, date: string, currentRisk: 'low' | 'moderate' | 'high') {
  const trend = await MoodTrend.findOne({ userId, date });
  
  if (!trend) {
    await MoodTrend.create({
      userId,
      date,
      avgRiskLevel: currentRisk,
      messageCount: 1,
      crisisTriggered: currentRisk === 'high'
    });
    return;
  }

  // Very simplistic risk averaging: if high, keep high. If moderate and previous was low, make it moderate.
  let newAvg = trend.avgRiskLevel;
  if (currentRisk === 'high') newAvg = 'high';
  else if (currentRisk === 'moderate' && trend.avgRiskLevel === 'low') newAvg = 'moderate';

  trend.avgRiskLevel = newAvg;
  trend.messageCount += 1;
  if (currentRisk === 'high') trend.crisisTriggered = true;

  await trend.save();
}

export default router;
