import Anthropic from "@anthropic-ai/sdk";
import { GoogleGenAI } from "@google/genai";

import {
  SYSTEM_PROMPT,
  TOOL_INPUT_SCHEMA,
  USER_PROMPT,
} from "./prompts.ts";

export interface AnalysisResult {
  raw: unknown;
  latencyMs: number;
  model: string;
  provider: "anthropic" | "gemini";
}

export interface AnalysisProvider {
  analyze(image: Uint8Array, mimeType: string): Promise<AnalysisResult>;
}

// ─── Anthropic ────────────────────────────────────────────────────────────

class AnthropicProvider implements AnalysisProvider {
  private client = new Anthropic({
    apiKey: Bun.env.ANTHROPIC_API_KEY,
  });
  private model = Bun.env.ANTHROPIC_MODEL ?? "claude-sonnet-4-6";

  async analyze(image: Uint8Array, mimeType: string): Promise<AnalysisResult> {
    const b64 = Buffer.from(image).toString("base64");
    const startedAt = performance.now();
    const msg = await this.client.messages.create({
      model: this.model,
      max_tokens: 4096,
      system: SYSTEM_PROMPT,
      tools: [
        {
          name: "submit_analysis",
          description:
            "Submete a análise estruturada da imagem em três camadas.",
          input_schema: TOOL_INPUT_SCHEMA as never,
        },
      ],
      tool_choice: { type: "tool", name: "submit_analysis" },
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: mimeType as
                  | "image/jpeg"
                  | "image/png"
                  | "image/gif"
                  | "image/webp",
                data: b64,
              },
            },
            { type: "text", text: USER_PROMPT },
          ],
        },
      ],
    });
    const latencyMs = Math.round(performance.now() - startedAt);

    for (const block of msg.content) {
      if (block.type === "tool_use" && block.name === "submit_analysis") {
        return {
          raw: block.input,
          latencyMs,
          model: this.model,
          provider: "anthropic",
        };
      }
    }
    throw new Error("Claude não chamou a tool submit_analysis.");
  }
}

// ─── Gemini ───────────────────────────────────────────────────────────────

class GeminiProvider implements AnalysisProvider {
  private client = new GoogleGenAI({ apiKey: Bun.env.GEMINI_API_KEY ?? "" });
  private model = Bun.env.GEMINI_MODEL_VISION ?? "gemini-2.5-pro";

  async analyze(image: Uint8Array, mimeType: string): Promise<AnalysisResult> {
    const prompt = `${SYSTEM_PROMPT}

Responda APENAS um JSON válido com este schema:
${JSON.stringify(TOOL_INPUT_SCHEMA)}

${USER_PROMPT}`;

    const b64 = Buffer.from(image).toString("base64");
    const startedAt = performance.now();
    const response = await this.client.models.generateContent({
      model: this.model,
      contents: [
        {
          role: "user",
          parts: [
            { inlineData: { mimeType, data: b64 } },
            { text: prompt },
          ],
        },
      ],
      config: {
        responseMimeType: "application/json",
        temperature: 0.3,
      },
    });
    const latencyMs = Math.round(performance.now() - startedAt);
    const text = response.text ?? "";
    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch (err) {
      throw new Error(
        `Gemini não devolveu JSON válido: ${(err as Error).message}\n${text.slice(0, 500)}`,
      );
    }
    return {
      raw: parsed,
      latencyMs,
      model: this.model,
      provider: "gemini",
    };
  }
}

// ─── Factory ──────────────────────────────────────────────────────────────

export function getProvider(): AnalysisProvider {
  // Provider de visão: Gemini quando há GEMINI_API_KEY (padrão), senão Anthropic.
  const explicit = (Bun.env.PROVIDER ?? "").toLowerCase();
  if (explicit === "anthropic") return new AnthropicProvider();
  if (explicit === "gemini") return new GeminiProvider();
  if (Bun.env.GEMINI_API_KEY) return new GeminiProvider();
  if (Bun.env.ANTHROPIC_API_KEY) return new AnthropicProvider();
  throw new Error("Nenhum provider de IA configurado (defina GEMINI_API_KEY).");
}
