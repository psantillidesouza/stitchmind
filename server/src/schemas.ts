import { z } from "zod";

export const StitchGuess = z.object({
  abbrev: z.string().describe("Abreviação PT-BR, ex: 'pb', 'pa', 'mpa'"),
  name_pt: z.string(),
  confidence: z.number().min(0).max(1),
});

export const Tier1Identification = z.object({
  technique: z.enum(["crochet", "knit"]),
  technique_confidence: z.number().min(0).max(1),
  piece_type: z.string(),
  piece_type_confidence: z.number().min(0).max(1),
  main_stitches: z.array(StitchGuess),
  estimated_yarn: z.string(),
  color_palette: z.array(z.string()).default([]),
});

export const Tier2Analysis = z.object({
  structure_notes: z.string(),
  estimated_dimensions_cm: z.array(z.number()).default([]),
  estimated_yarn_grams: z.number().int().nullable().optional(),
  suggested_needle_mm: z.number().nullable().optional(),
  estimated_difficulty: z.enum(["beginner", "intermediate", "advanced"]),
  estimated_hours: z.number().int().nullable().optional(),
  overall_confidence: z.number().min(0).max(1),
});

export const PatternRowDraft = z.object({
  row: z.number().int(),
  instruction: z.string(),
  stitch_count: z.number().int().nullable().optional(),
  confidence: z.number().min(0).max(1),
});

export const PatternSectionDraft = z.object({
  title: z.string(),
  rows: z.array(PatternRowDraft),
});

export const Tier3DraftPattern = z.object({
  warning: z.string(),
  overall_confidence: z.number().min(0).max(1),
  sections: z.array(PatternSectionDraft),
});

export const AnalysisCore = z.object({
  tier1_identification: Tier1Identification,
  tier2_analysis: Tier2Analysis,
  tier3_draft_pattern: Tier3DraftPattern,
});

export type AnalysisCoreT = z.infer<typeof AnalysisCore>;

export const AnalysisResponse = AnalysisCore.extend({
  provider: z.string(),
  model: z.string(),
  latency_ms: z.number().int(),
  analysis_id: z.string(),
});

export const FeedbackPayload = z.object({
  analysis_id: z.string(),
  section: z.string(),
  rating: z.enum(["correct", "partial", "wrong"]),
  note: z.string().optional(),
});

export type FeedbackPayloadT = z.infer<typeof FeedbackPayload>;
