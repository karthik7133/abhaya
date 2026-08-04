import { Router, Request, Response } from 'express';
import { MoodTrend, Message } from '../models';
import { authMiddleware } from '../middleware/auth';

const router = Router();

// ─── GET /api/mood/trends ──────────────────────────────────────────────────────
// Returns mood trends for the last N days (default 30)

router.get('/trends', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const days = parseInt(req.query['days'] as string || '30');

  // Build date list for the last N days
  const dateList: string[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    dateList.push(d.toISOString().split('T')[0]!);
  }

  try {
    const trends = await MoodTrend.find({
      userId,
      date: { $in: dateList },
    }).sort({ date: 1 }).lean();

    // Fill in missing days with default 'low' so the chart has a full dataset
    const trendMap = new Map(trends.map(t => [t.date, t]));
    const filled = dateList.map(date => trendMap.get(date) ?? {
      userId,
      date,
      avgRiskLevel: 'low',
      messageCount: 0,
      crisisTriggered: false,
    });

    res.json(filled);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch mood trends' });
  }
});

// ─── GET /api/mood/today ───────────────────────────────────────────────────────
// Summary for today

router.get('/today', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const today = new Date().toISOString().split('T')[0]!;

  try {
    const trend = await MoodTrend.findOne({ userId, date: today }).lean();
    res.json(trend ?? { date: today, avgRiskLevel: 'low', messageCount: 0, crisisTriggered: false });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch today mood' });
  }
});

export default router;
