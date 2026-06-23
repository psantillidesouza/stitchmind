import 'package:flutter/foundation.dart';

@immutable
class StitchGuess {
  final String abbrev;
  final String namePt;
  final double confidence;

  const StitchGuess({
    required this.abbrev,
    required this.namePt,
    required this.confidence,
  });

  factory StitchGuess.fromJson(Map<String, dynamic> j) => StitchGuess(
        abbrev: j['abbrev'] as String,
        namePt: j['name_pt'] as String,
        confidence: (j['confidence'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'abbrev': abbrev,
        'name_pt': namePt,
        'confidence': confidence,
      };
}

@immutable
class Tier1Identification {
  final String technique; // 'crochet' | 'knit'
  final double techniqueConfidence;
  final String pieceType;
  final double pieceTypeConfidence;
  final List<StitchGuess> mainStitches;
  final String estimatedYarn;
  final List<String> colorPalette;

  const Tier1Identification({
    required this.technique,
    required this.techniqueConfidence,
    required this.pieceType,
    required this.pieceTypeConfidence,
    required this.mainStitches,
    required this.estimatedYarn,
    this.colorPalette = const [],
  });

  factory Tier1Identification.fromJson(Map<String, dynamic> j) =>
      Tier1Identification(
        technique: j['technique'] as String,
        techniqueConfidence:
            (j['technique_confidence'] as num).toDouble(),
        pieceType: j['piece_type'] as String,
        pieceTypeConfidence:
            (j['piece_type_confidence'] as num).toDouble(),
        mainStitches: (j['main_stitches'] as List)
            .cast<Map<String, dynamic>>()
            .map(StitchGuess.fromJson)
            .toList(),
        estimatedYarn: j['estimated_yarn'] as String,
        colorPalette:
            ((j['color_palette'] as List?) ?? const []).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'technique': technique,
        'technique_confidence': techniqueConfidence,
        'piece_type': pieceType,
        'piece_type_confidence': pieceTypeConfidence,
        'main_stitches': mainStitches.map((s) => s.toJson()).toList(),
        'estimated_yarn': estimatedYarn,
        'color_palette': colorPalette,
      };
}

@immutable
class Tier2Analysis {
  final String structureNotes;
  final List<double> estimatedDimensionsCm;
  final int? estimatedYarnGrams;
  final double? suggestedNeedleMm;
  final String estimatedDifficulty;
  final int? estimatedHours;
  final double overallConfidence;

  const Tier2Analysis({
    required this.structureNotes,
    this.estimatedDimensionsCm = const [],
    this.estimatedYarnGrams,
    this.suggestedNeedleMm,
    required this.estimatedDifficulty,
    this.estimatedHours,
    required this.overallConfidence,
  });

  factory Tier2Analysis.fromJson(Map<String, dynamic> j) => Tier2Analysis(
        structureNotes: j['structure_notes'] as String,
        estimatedDimensionsCm:
            ((j['estimated_dimensions_cm'] as List?) ?? const [])
                .map((e) => (e as num).toDouble())
                .toList(),
        estimatedYarnGrams: (j['estimated_yarn_grams'] as num?)?.toInt(),
        suggestedNeedleMm: (j['suggested_needle_mm'] as num?)?.toDouble(),
        estimatedDifficulty: j['estimated_difficulty'] as String,
        estimatedHours: (j['estimated_hours'] as num?)?.toInt(),
        overallConfidence: (j['overall_confidence'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'structure_notes': structureNotes,
        'estimated_dimensions_cm': estimatedDimensionsCm,
        'estimated_yarn_grams': estimatedYarnGrams,
        'suggested_needle_mm': suggestedNeedleMm,
        'estimated_difficulty': estimatedDifficulty,
        'estimated_hours': estimatedHours,
        'overall_confidence': overallConfidence,
      };
}

@immutable
class DraftRow {
  final int row;
  final String instruction;
  final int? stitchCount;
  final double confidence;

  const DraftRow({
    required this.row,
    required this.instruction,
    this.stitchCount,
    required this.confidence,
  });

  factory DraftRow.fromJson(Map<String, dynamic> j) => DraftRow(
        row: (j['row'] as num).toInt(),
        instruction: j['instruction'] as String,
        stitchCount: (j['stitch_count'] as num?)?.toInt(),
        confidence: (j['confidence'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'row': row,
        'instruction': instruction,
        'stitch_count': stitchCount,
        'confidence': confidence,
      };
}

@immutable
class DraftSection {
  final String title;
  final List<DraftRow> rows;

  const DraftSection({required this.title, required this.rows});

  factory DraftSection.fromJson(Map<String, dynamic> j) => DraftSection(
        title: j['title'] as String,
        rows: (j['rows'] as List)
            .cast<Map<String, dynamic>>()
            .map(DraftRow.fromJson)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'rows': rows.map((r) => r.toJson()).toList(),
      };
}

@immutable
class Tier3DraftPattern {
  final String warning;
  final double overallConfidence;
  final List<DraftSection> sections;

  const Tier3DraftPattern({
    required this.warning,
    required this.overallConfidence,
    required this.sections,
  });

  factory Tier3DraftPattern.fromJson(Map<String, dynamic> j) =>
      Tier3DraftPattern(
        warning: j['warning'] as String,
        overallConfidence: (j['overall_confidence'] as num).toDouble(),
        sections: (j['sections'] as List)
            .cast<Map<String, dynamic>>()
            .map(DraftSection.fromJson)
            .toList(),
      );

  int get totalRows => sections.fold(0, (sum, s) => sum + s.rows.length);

  Map<String, dynamic> toJson() => {
        'warning': warning,
        'overall_confidence': overallConfidence,
        'sections': sections.map((s) => s.toJson()).toList(),
      };
}

@immutable
class AiAnalysis {
  final String id;
  final DateTime createdAt;
  final String provider;
  final String model;
  final int latencyMs;
  final String imagePath;
  final Tier1Identification tier1;
  final Tier2Analysis tier2;
  final Tier3DraftPattern tier3;

  const AiAnalysis({
    required this.id,
    required this.createdAt,
    required this.provider,
    required this.model,
    required this.latencyMs,
    required this.imagePath,
    required this.tier1,
    required this.tier2,
    required this.tier3,
  });

  factory AiAnalysis.fromJson(Map<String, dynamic> j) => AiAnalysis(
        id: (j['analysis_id'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()) ??
            DateTime.now(),
        provider: (j['provider'] as String?) ?? '',
        model: (j['model'] as String?) ?? '',
        latencyMs: (j['latency_ms'] as num?)?.toInt() ?? 0,
        imagePath: (j['image_path'] as String?) ?? '',
        tier1: Tier1Identification.fromJson(
            j['tier1_identification'] as Map<String, dynamic>),
        tier2: Tier2Analysis.fromJson(
            j['tier2_analysis'] as Map<String, dynamic>),
        tier3: Tier3DraftPattern.fromJson(
            j['tier3_draft_pattern'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'analysis_id': id,
        'created_at': createdAt.toIso8601String(),
        'provider': provider,
        'model': model,
        'latency_ms': latencyMs,
        'image_path': imagePath,
        'tier1_identification': tier1.toJson(),
        'tier2_analysis': tier2.toJson(),
        'tier3_draft_pattern': tier3.toJson(),
      };
}
