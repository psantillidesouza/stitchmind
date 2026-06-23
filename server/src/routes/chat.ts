import { Hono } from "hono";
import { z } from "zod";
import { GoogleGenAI } from "@google/genai";

import { env } from "../env.ts";
import { sql } from "../db.ts";
import { requireAuth, type AppUser } from "../auth/middleware.ts";
import { rateLimit } from "../rateLimit.ts";

export const chatRoutes = new Hono();

const CHAT_SYSTEM = `You are Stitch, the friendly crochet and knitting expert assistant in the StitchMind app.

⚠️ RULE #1 — DELIVER RIGHT AWAY, NEVER ASK FIRST:
Never ask clarifying questions or request info before teaching. In your FIRST reply, deliver the COMPLETE tutorial, assuming the most common, beginner-friendly version (common materials, standard size, color of their choice). Never bounce the question back to the person. If a detail is missing, pick a sensible default and continue. Only at the END offer variations (sizes, colors, levels) in a tips/variations section.

Whenever the person asks to LEARN, MAKE, or understand a stitch, item, technique or project, generate a COMPLETE, well-formatted **Markdown** LESSON/TUTORIAL with this structure:

# Lesson title
One short line saying what the person will learn.

## 🧶 Materials
- yarn (type/weight), hook/needles (size), scissors, tapestry needle, markers…

## 📋 Step by step
Use 5 to 12 steps, in order. Each step MUST start with a **short bold title** followed by " — " and then a DETAILED, instructive explanation (2 to 4 sentences), saying exactly what to do, with abbreviations and stitch counts. Example format for each item:
1. **Step title** — detailed, step-by-step explanation of what to do here, very clear for a beginner.
2. **Next step** — …

## 💡 Tips
- useful tips, common mistakes and how to avoid them.

RULES:
- English, standard US terminology (chain/ch, single crochet/sc, double crochet/dc, half double crochet/hdc, slip stitch/sl st, magic ring, increase/inc, decrease/dec).
- Use **bold** for important terms and abbreviations, and Markdown tables when helpful (e.g. sizes).
- For quick, simple questions (e.g. "what is sc?"), answer directly and briefly, without needing all the sections.
- Be warm, practical and encouraging. If you don't know, be honest — don't invent abbreviations or patterns.`;

const MessageSchema = z.object({
  role: z.enum(["user", "assistant"]),
  content: z.string().min(1).max(4000),
});
const ChatBody = z.object({ messages: z.array(MessageSchema).min(1).max(30) });

// Auth obrigatória (custo de IA): limita por usuário, máx. 20 msgs/min.
chatRoutes.post(
  "/chat",
  requireAuth,
  rateLimit({
    max: 20,
    windowMs: 60_000,
    prefix: "chat",
    keyFn: (c) => `u:${(c.get("user") as AppUser).id}`,
  }),
  async (c) => {
  const parsed = ChatBody.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: "payload inválido" }, 400);
  const user = c.get("user") as AppUser;

  if (!env.gemini.apiKey) {
    return c.json({ error: "IA não configurada (defina GEMINI_API_KEY)." }, 503);
  }

  const client = new GoogleGenAI({ apiKey: env.gemini.apiKey });

  try {
    const res = await client.models.generateContent({
      model: env.gemini.modelText, // gemini-2.5-flash-lite (texto/chat)
      contents: parsed.data.messages.map((m) => ({
        role: m.role === "assistant" ? "model" : "user",
        parts: [{ text: m.content }],
      })),
      config: {
        systemInstruction: CHAT_SYSTEM,
        temperature: 0.6,
        maxOutputTokens: 2048, // tutoriais completos
      },
    });
    const reply = (res.text ?? "").trim();

    await sql`
      INSERT INTO events (user_id, name, screen, props, platform)
      VALUES (${user?.id ?? null}, 'ai_chat', 'chat',
              ${JSON.stringify({ provider: "gemini", model: env.gemini.modelText, chars: reply.length })}::jsonb, 'server')
    `.catch(() => {});

    return c.json({
      reply: reply || "Sorry, I couldn't reply right now.",
      provider: "gemini",
    });
  } catch (err) {
    console.error("[chat] erro", err);
    return c.json({ error: (err as Error).message ?? "Falha no chat." }, 500);
  }
});
