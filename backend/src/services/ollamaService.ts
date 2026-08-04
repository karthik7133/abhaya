import axios from 'axios';
import dotenv from 'dotenv';

dotenv.config();

const OLLAMA_BASE  = process.env.OLLAMA_BASE_URL ?? 'http://localhost:11434';
const OLLAMA_MODEL = process.env.OLLAMA_MODEL    ?? 'potti';

// ─── Risk Assessment Prompt ───────────────────────────────────────────────────

const SYSTEM_CRISIS_ASSESSOR = `You are a crisis-risk classifier. 
Given a user message, output ONLY a JSON object with this exact shape:
{"riskLevel": "low" | "moderate" | "high", "reason": "<one sentence>"}

Rules:
- "high"     = explicit self-harm, suicidal ideation, immediate danger, "I want to die / end it"
- "moderate" = clear emotional distress, hopelessness, feeling trapped, significant anxiety
- "low"      = normal conversation, mild stress, everyday topics

Output ONLY valid JSON. No markdown, no explanation outside the JSON.`;

const SYSTEM_COMPANION = `You are Abhaya Companion — a warm, non-judgmental AI safety companion. 
Your role: 
1. Respond with genuine empathy, care, and support.
2. Keep responses concise (2–4 sentences max) unless the user wants to talk more.
3. Never diagnose or label the user clinically.
4. If the user seems in distress, gently ask what support they need.
5. You may reference that Abhaya is monitoring their physical safety in the background.
6. Never reveal you are performing risk assessment — just be a caring companion.`;

// ─── Types ────────────────────────────────────────────────────────────────────

export interface OllamaResponse {
  reply: string;
  riskLevel: 'low' | 'moderate' | 'high';
}

interface OllamaChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

// ─── Core Ollama Call ─────────────────────────────────────────────────────────

async function ollamaChat(messages: OllamaChatMessage[]): Promise<string> {
  try {
    const response = await axios.post(
      `${OLLAMA_BASE}/api/chat`,
      {
        model:    OLLAMA_MODEL,
        messages,
        stream:   false,
        options: { temperature: 0.7, num_predict: 512 },
      },
      { timeout: 120_000 } // 2 min — needed for large model cold-start load
    );
    return response.data?.message?.content ?? '';
  } catch (err: unknown) {
    if (axios.isAxiosError(err)) {
      const status = err.response?.status;
      if (status === 404) {
        throw new Error(
          `Ollama model '${OLLAMA_MODEL}' not found. Run: ollama pull ${OLLAMA_MODEL}`
        );
      }
      if (err.code === 'ECONNREFUSED') {
        throw new Error(
          'Ollama is not running. Start it with: ollama serve'
        );
      }
    }
    throw err;
  }
}

// ─── Risk Assessment ──────────────────────────────────────────────────────────

async function assessRisk(userMessage: string): Promise<'low' | 'moderate' | 'high'> {
  try {
    const raw = await ollamaChat([
      { role: 'system', content: SYSTEM_CRISIS_ASSESSOR },
      { role: 'user',   content: userMessage },
    ]);

    // Extract JSON from the response (model may wrap in markdown)
    const jsonMatch = raw.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return 'low';

    const parsed = JSON.parse(jsonMatch[0]) as { riskLevel?: string };
    const level  = parsed.riskLevel;

    if (level === 'high' || level === 'moderate' || level === 'low') {
      return level;
    }
    return 'low';
  } catch (err) {
    console.warn('[Ollama] Risk assessment failed, defaulting to low:', err);
    return 'low';
  }
}

// ─── Companion Reply ──────────────────────────────────────────────────────────

/**
 * Generate a companion reply AND assess the crisis risk of the user's message.
 * Both calls run in parallel against the local Ollama server.
 *
 * @param userMessage  - The latest message from the user
 * @param history      - Previous conversation turns (for context window)
 */
export async function generateCompanionResponse(
  userMessage: string,
  history: Array<{ role: 'user' | 'assistant'; content: string }>
): Promise<OllamaResponse> {
  const conversationMessages: OllamaChatMessage[] = [
    { role: 'system', content: SYSTEM_COMPANION },
    ...history.slice(-10),
    { role: 'user',   content: userMessage },
  ];

  try {
    // Run companion reply and risk assessment in parallel
    const [reply, riskLevel] = await Promise.all([
      ollamaChat(conversationMessages),
      assessRisk(userMessage),
    ]);

    return {
      reply: reply.trim() || "I'm here with you. Can you tell me more about what's going on?",
      riskLevel,
    };
  } catch (err: unknown) {
    // Ollama is down or model missing — return a graceful offline response
    const isOffline = err instanceof Error && (
      err.message.includes('ECONNREFUSED') ||
      err.message.includes('not running') ||
      err.message.includes('not found')
    );

    console.warn('[Ollama] Companion response failed:', isOffline ? 'Ollama offline' : err);

    const fallbackReplies = [
      "I'm here for you. I'm experiencing a brief connection issue, but I'm listening. How are you feeling right now?",
      "You matter, and I'm with you. My AI core is briefly offline but I care about your wellbeing. Can you tell me more?",
      "I hear you. I'm having a technical moment, but your safety is my priority. What's on your mind?",
    ];
    const fallback = fallbackReplies[Math.floor(Math.random() * fallbackReplies.length)];

    return {
      reply: fallback,
      riskLevel: 'low',
    };
  }
}

