export const SYSTEM_PROMPT = `You are an expert crochet and knitting analyst who looks at photos of finished or in-progress pieces and returns a structured three-tier analysis. You are meticulous, know standard US terminology, and are HONEST about uncertainty.

GENERAL RULES
- Language: English. Use standard US terminology (sc, dc, hdc, sl st, ch, magic ring, inc, dec). Do not use Brazilian abbreviations (PB, PA, MPA) in the final output.
- Honesty > impressiveness. Assign confidence honestly. If you can't see clearly, use low confidence. If the image is ambiguous, mention it in structure_notes.
- No making things up. Don't invent abbreviations. Only use real stitches.
- The answer MUST come via the 'submit_analysis' tool. Do not reply in free text.

TIER 1 — IDENTIFICATION
- technique: crochet or knit. Usually high confidence.
- piece_type: type of piece (amigurumi, blanket, beanie, scarf, cardigan, top, bikini, etc.).
- main_stitches: 1 to 5 likely stitches used, each with individual confidence.
- estimated_yarn: likely yarn type + weight (e.g. "Fine cotton (sport weight)", "Worsted merino wool").
- color_palette: color names in English.

TIER 2 — STRUCTURED ANALYSIS
- structure_notes: 1-3 sentences about construction (worked in a spiral, in rows, in joined pieces, etc.).
- estimated_dimensions_cm: [width, height] if you can infer it. Empty list if impossible.
- estimated_yarn_grams, suggested_needle_mm, estimated_hours: honest estimates.
- estimated_difficulty: beginner / intermediate / advanced.
- overall_confidence: aggregate for this tier.

TIER 3 — DRAFT PATTERN
- warning: ALWAYS filled in with a draft disclaimer.
- overall_confidence: tends to be LOWER than tier 1 and 2. Rarely above 0.6.
- sections: split into logical sections (Head, Body, Ears / Brim, Body, Crown / etc.).
- rows:
  - For amigurumi: always start with "Magic ring with N sc" on row 1.
  - Early rows (1-5): specific instructions, higher confidence.
  - Middle rows: group them when the piece repeats (e.g. "Rows 6-15: 30 sc per row (no increases)") — use row=6 and mention the range in the instruction.
  - Final rows: decreases and closing, medium confidence.
- If the piece has details you can't see (back, center), state it in tier 2's structure_notes.

GOOD CALIBRATION EXAMPLES
- Sharp image of a simple amigurumi: tier1 conf 0.9, tier2 conf 0.7, tier3 conf 0.5
- Sharp image of a granny-square blanket: tier1 conf 0.95, tier2 conf 0.75, tier3 conf 0.4
- Blurry / bad-angle image: tier1 conf 0.6, tier2 conf 0.4, tier3 conf 0.2

NOTE: the schema field is named "name_pt" for legacy reasons, but its value MUST be the stitch name in ENGLISH.`;

export const USER_PROMPT =
  "Analyze the photo of this crochet or knitting piece and return the analysis via the tool.";

export const TOOL_INPUT_SCHEMA = {
  type: "object",
  required: [
    "tier1_identification",
    "tier2_analysis",
    "tier3_draft_pattern",
  ],
  properties: {
    tier1_identification: {
      type: "object",
      required: [
        "technique",
        "technique_confidence",
        "piece_type",
        "piece_type_confidence",
        "main_stitches",
        "estimated_yarn",
      ],
      properties: {
        technique: { type: "string", enum: ["crochet", "knit"] },
        technique_confidence: { type: "number", minimum: 0, maximum: 1 },
        piece_type: { type: "string" },
        piece_type_confidence: { type: "number", minimum: 0, maximum: 1 },
        main_stitches: {
          type: "array",
          items: {
            type: "object",
            required: ["abbrev", "name_pt", "confidence"],
            properties: {
              abbrev: { type: "string" },
              name_pt: { type: "string" },
              confidence: { type: "number", minimum: 0, maximum: 1 },
            },
          },
        },
        estimated_yarn: { type: "string" },
        color_palette: { type: "array", items: { type: "string" } },
      },
    },
    tier2_analysis: {
      type: "object",
      required: [
        "structure_notes",
        "estimated_difficulty",
        "overall_confidence",
      ],
      properties: {
        structure_notes: { type: "string" },
        estimated_dimensions_cm: {
          type: "array",
          items: { type: "number" },
        },
        estimated_yarn_grams: { type: ["integer", "null"] },
        suggested_needle_mm: { type: ["number", "null"] },
        estimated_difficulty: {
          type: "string",
          enum: ["beginner", "intermediate", "advanced"],
        },
        estimated_hours: { type: ["integer", "null"] },
        overall_confidence: { type: "number", minimum: 0, maximum: 1 },
      },
    },
    tier3_draft_pattern: {
      type: "object",
      required: ["warning", "overall_confidence", "sections"],
      properties: {
        warning: { type: "string" },
        overall_confidence: { type: "number", minimum: 0, maximum: 1 },
        sections: {
          type: "array",
          items: {
            type: "object",
            required: ["title", "rows"],
            properties: {
              title: { type: "string" },
              rows: {
                type: "array",
                items: {
                  type: "object",
                  required: ["row", "instruction", "confidence"],
                  properties: {
                    row: { type: "integer" },
                    instruction: { type: "string" },
                    stitch_count: { type: ["integer", "null"] },
                    confidence: { type: "number", minimum: 0, maximum: 1 },
                  },
                },
              },
            },
          },
        },
      },
    },
  },
} as const;
