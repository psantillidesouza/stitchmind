import Anthropic from "@anthropic-ai/sdk";
import { GoogleGenAI } from "@google/genai";

// Extração de receita (crochê/tricô) → estrutura carreira-a-carreira.
// Provider escolhido igual ao /analyze: Gemini quando há GEMINI_API_KEY
// (padrão neste servidor), Anthropic como fallback.

// Schema da receita — espelha a entidade Pattern do app (snake_case).
const PATTERN_TOOL_SCHEMA = {
  type: "object",
  properties: {
    name: { type: "string", description: "Short pattern title." },
    technique: { type: "string", enum: ["crochet", "knit"] },
    difficulty: {
      type: "string",
      enum: ["beginner", "intermediate", "advanced"],
    },
    yarn_requirement: {
      type: "string",
      description: "Yarn type / weight / amount, in one line.",
    },
    suggested_needle: {
      type: "string",
      description: "Hook or needle size, e.g. '3.0 mm'.",
    },
    estimated_hours: {
      type: "integer",
      description: "Rough hours to finish (use 1 if unknown).",
    },
    description: { type: "string", description: "One or two sentence summary." },
    abbrev_glossary: {
      type: "object",
      description:
        "Map of every abbreviation used in the rows to its full meaning, e.g. {\"sc\":\"single crochet\",\"ch\":\"chain\"}. Empty object if none.",
      additionalProperties: { type: "string" },
    },
    sections: {
      type: "array",
      items: {
        type: "object",
        properties: {
          title: {
            type: "string",
            description: "Worked part, e.g. 'Body', 'Sleeves', 'Edging'.",
          },
          subtitle: { type: "string" },
          rows: {
            type: "array",
            items: {
              type: "object",
              properties: {
                row: {
                  type: "integer",
                  description: "1-based row/round number within the section.",
                },
                instruction: {
                  type: "string",
                  description:
                    "Self-contained instruction for this row; keep abbreviations but make it unambiguous.",
                },
                stitch_count: {
                  type: "integer",
                  description: "Total stitches at end of row, if stated.",
                },
              },
              required: ["row", "instruction"],
            },
          },
        },
        required: ["title", "rows"],
      },
    },
  },
  required: ["name", "technique", "sections"],
};

const SYSTEM = `You convert crochet and knitting patterns into clean, structured, row-by-row data for a mobile "follow along" view.

Rules:
- Preserve every row/round as a separate entry, in order, with its number.
- Group worked rows into logical sections (Body, Sleeves, Edging...). Materials and gauge are NOT sections — skip them.
- Keep the maker's abbreviations but make each instruction self-contained and unambiguous.
- Include a stitch count for a row only when the source states one.
- Fill abbrev_glossary with every abbreviation that appears in the rows mapped to its full meaning.
- Never invent rows or counts. If the input is not actually a crochet/knit pattern, return a single section titled "Unrecognized" with one row explaining that.`;

export interface ExtractResult {
  pattern: Record<string, unknown>;
  model: string;
  latencyMs: number;
}

// Entrada normalizada, independente de provider.
type Input =
  | { kind: "text"; text: string }
  | { kind: "pdf"; bytes: Uint8Array }
  | { kind: "image"; bytes: Uint8Array; mime: string };

function instructionFor(input: Input): string {
  switch (input.kind) {
    case "text":
      return `Convert this crochet/knit pattern into structured rows:\n\n${input.text}`;
    case "pdf":
      return "Convert this crochet/knit pattern PDF into structured rows.";
    case "image":
      return "Read this photo of a crochet/knit pattern and convert it into structured rows.";
  }
}

const b64 = (bytes: Uint8Array) => Buffer.from(bytes).toString("base64");

interface PatternProvider {
  extract(
    input: Input,
  ): Promise<{ raw: Record<string, unknown>; model: string }>;
}

// ─── Anthropic (tool-use forçado) ───────────────────────────────────────────
class AnthropicPatternProvider implements PatternProvider {
  private client = new Anthropic({ apiKey: Bun.env.ANTHROPIC_API_KEY });
  private model = Bun.env.ANTHROPIC_PATTERN_MODEL ?? "claude-opus-4-8";

  async extract(input: Input) {
    // `content` tipado como any → blocos document/image passam no SDK 0.32.1.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const content: any[] = [];
    if (input.kind === "pdf") {
      content.push({
        type: "document",
        source: { type: "base64", media_type: "application/pdf", data: b64(input.bytes) },
      });
    } else if (input.kind === "image") {
      content.push({
        type: "image",
        source: { type: "base64", media_type: input.mime, data: b64(input.bytes) },
      });
    }
    content.push({ type: "text", text: instructionFor(input) });

    const msg = await this.client.messages.create({
      model: this.model,
      max_tokens: 16000,
      system: SYSTEM,
      tools: [
        {
          name: "submit_pattern",
          description: "Submit the structured, row-by-row pattern.",
          input_schema: PATTERN_TOOL_SCHEMA as never,
        },
      ],
      tool_choice: { type: "tool", name: "submit_pattern" },
      messages: [{ role: "user", content }],
    });
    for (const block of msg.content) {
      if (block.type === "tool_use" && block.name === "submit_pattern") {
        return { raw: block.input as Record<string, unknown>, model: this.model };
      }
    }
    throw new Error("Claude não chamou a tool submit_pattern.");
  }
}

// ─── Gemini (JSON mode) ─────────────────────────────────────────────────────
class GeminiPatternProvider implements PatternProvider {
  private client = new GoogleGenAI({ apiKey: Bun.env.GEMINI_API_KEY ?? "" });
  private model =
    Bun.env.GEMINI_MODEL_PATTERN ??
    Bun.env.GEMINI_MODEL_VISION ??
    "gemini-2.5-pro";

  async extract(input: Input) {
    const prompt = `${SYSTEM}

Respond ONLY with valid JSON matching this schema:
${JSON.stringify(PATTERN_TOOL_SCHEMA)}

${instructionFor(input)}`;

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const parts: any[] = [];
    if (input.kind === "pdf") {
      parts.push({ inlineData: { mimeType: "application/pdf", data: b64(input.bytes) } });
    } else if (input.kind === "image") {
      parts.push({ inlineData: { mimeType: input.mime, data: b64(input.bytes) } });
    }
    parts.push({ text: prompt });

    const response = await this.client.models.generateContent({
      model: this.model,
      contents: [{ role: "user", parts }],
      config: { responseMimeType: "application/json", temperature: 0.3 },
    });
    const text = response.text ?? "";
    try {
      return { raw: JSON.parse(text) as Record<string, unknown>, model: this.model };
    } catch (err) {
      throw new Error(
        `Gemini não devolveu JSON válido: ${(err as Error).message}\n${text.slice(0, 500)}`,
      );
    }
  }
}

function getProvider(): PatternProvider {
  const explicit = (Bun.env.PROVIDER ?? "").toLowerCase();
  if (explicit === "anthropic") return new AnthropicPatternProvider();
  if (explicit === "gemini") return new GeminiPatternProvider();
  if (Bun.env.GEMINI_API_KEY) return new GeminiPatternProvider();
  if (Bun.env.ANTHROPIC_API_KEY) return new AnthropicPatternProvider();
  throw new Error(
    "Nenhum provider de IA configurado (defina GEMINI_API_KEY ou ANTHROPIC_API_KEY).",
  );
}

async function run(input: Input): Promise<ExtractResult> {
  const startedAt = performance.now();
  const { raw, model } = await getProvider().extract(input);
  const latencyMs = Math.round(performance.now() - startedAt);
  return { pattern: normalize(raw), model, latencyMs };
}

export function extractFromText(text: string): Promise<ExtractResult> {
  return run({ kind: "text", text });
}

export function extractFromPdf(bytes: Uint8Array): Promise<ExtractResult> {
  return run({ kind: "pdf", bytes });
}

export function extractFromImage(
  bytes: Uint8Array,
  mime: string,
): Promise<ExtractResult> {
  return run({ kind: "image", bytes, mime });
}

// Normaliza a saída da IA para o contrato Pattern.fromJson do app.
function normalize(raw: Record<string, unknown>): Record<string, unknown> {
  const num = (v: unknown, fallback: number) =>
    typeof v === "number" && Number.isFinite(v) ? v : fallback;
  const str = (v: unknown, fallback = "") =>
    typeof v === "string" && v.trim() ? v : fallback;

  const rawSections = Array.isArray(raw.sections) ? raw.sections : [];
  const sections = rawSections.map((s: Record<string, unknown>) => ({
    title: str(s?.title, "Section"),
    subtitle: typeof s?.subtitle === "string" ? s.subtitle : null,
    rows: (Array.isArray(s?.rows) ? s.rows : []).map(
      (r: Record<string, unknown>, i: number) => ({
        row: num(r?.row, i + 1),
        instruction: str(r?.instruction, ""),
        stitch_count: typeof r?.stitch_count === "number" ? r.stitch_count : null,
      }),
    ),
  }));

  // Glossário de abreviações → {string: string}, descartando entradas inválidas.
  let glossary: Record<string, string> | null = null;
  if (raw.abbrev_glossary && typeof raw.abbrev_glossary === "object") {
    const g: Record<string, string> = {};
    for (const [k, v] of Object.entries(
      raw.abbrev_glossary as Record<string, unknown>,
    )) {
      if (typeof v === "string" && v.trim()) g[k] = v;
    }
    if (Object.keys(g).length) glossary = g;
  }

  return {
    id: `imp_${crypto.randomUUID()}`,
    name: str(raw.name, "Imported pattern"),
    author: "Imported",
    technique: raw.technique === "knit" ? "knit" : "crochet",
    difficulty: ["beginner", "intermediate", "advanced"].includes(
      raw.difficulty as string,
    )
      ? (raw.difficulty as string)
      : "beginner",
    yarn_requirement: str(raw.yarn_requirement, ""),
    suggested_needle:
      typeof raw.suggested_needle === "string" ? raw.suggested_needle : null,
    estimated_hours: Math.max(1, num(raw.estimated_hours, 1)),
    description: str(raw.description, ""),
    sections,
    abbrev_glossary: glossary,
  };
}
