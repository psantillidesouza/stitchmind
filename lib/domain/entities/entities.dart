import 'package:flutter/material.dart';

enum StitchTechnique { crochet, knit }

extension StitchTechniqueX on StitchTechnique {
  String get labelPt =>
      this == StitchTechnique.crochet ? 'Crochet' : 'Knitting';
  String get key =>
      this == StitchTechnique.crochet ? 'crochet' : 'knit';

  static StitchTechnique fromKey(String key) =>
      key == 'knit' ? StitchTechnique.knit : StitchTechnique.crochet;
}

enum Difficulty { beginner, intermediate, advanced }

extension DifficultyX on Difficulty {
  String get labelPt {
    switch (this) {
      case Difficulty.beginner:
        return 'Beginner';
      case Difficulty.intermediate:
        return 'Intermediate';
      case Difficulty.advanced:
        return 'Advanced';
    }
  }

  String get key => name;

  static Difficulty fromKey(String key) {
    return Difficulty.values.firstWhere(
      (d) => d.name == key,
      orElse: () => Difficulty.beginner,
    );
  }
}

enum ProjectStatus { inProgress, paused, finished }

extension ProjectStatusX on ProjectStatus {
  String get labelPt {
    switch (this) {
      case ProjectStatus.inProgress:
        return 'In progress';
      case ProjectStatus.paused:
        return 'Paused';
      case ProjectStatus.finished:
        return 'Completed';
    }
  }
}

@immutable
class Stitch {
  final String id;
  final String namePt;
  final String nameEn;
  final String abbrev;
  final StitchTechnique technique;
  final Difficulty difficulty;
  final List<String> categories;
  final String description;
  final List<String> steps;
  final String? videoUrl;
  final String? videoPoster;

  const Stitch({
    required this.id,
    required this.namePt,
    required this.nameEn,
    required this.abbrev,
    required this.technique,
    required this.difficulty,
    required this.categories,
    required this.description,
    this.steps = const [],
    this.videoUrl,
    this.videoPoster,
  });

  factory Stitch.fromJson(Map<String, dynamic> json) {
    return Stitch(
      id: json['id'] as String,
      namePt: json['name_pt'] as String,
      nameEn: json['name_en'] as String,
      abbrev: json['abbrev'] as String,
      technique:
          StitchTechniqueX.fromKey(json['technique'] as String),
      difficulty: DifficultyX.fromKey(json['difficulty'] as String),
      categories: (json['categories'] as List).cast<String>(),
      description: json['description'] as String,
      steps: ((json['steps'] as List?) ?? const []).cast<String>(),
      videoUrl: json['video_url'] as String?,
      videoPoster: json['video_poster_url'] as String?,
    );
  }
}

@immutable
class Marker {
  final int row;
  final String note;
  final bool done;

  const Marker({required this.row, required this.note, this.done = false});

  Marker copyWith({int? row, String? note, bool? done}) => Marker(
        row: row ?? this.row,
        note: note ?? this.note,
        done: done ?? this.done,
      );
}

@immutable
class Project {
  final String id;
  final String name;
  final StitchTechnique technique;
  final String yarn;
  final String needle;
  final ProjectStatus status;
  final int currentRow;
  final int? targetRow;
  final DateTime startedAt;
  final String notes;
  final List<Marker> markers;
  final String? patternId;

  const Project({
    required this.id,
    required this.name,
    required this.technique,
    required this.yarn,
    required this.needle,
    required this.status,
    required this.currentRow,
    required this.startedAt,
    this.targetRow,
    this.notes = '',
    this.markers = const [],
    this.patternId,
  });

  double get progress {
    if (targetRow == null || targetRow == 0) return 0;
    return (currentRow / targetRow!).clamp(0.0, 1.0);
  }

  Marker? get nextMarker {
    final pending = markers.where((m) => !m.done && m.row > currentRow).toList()
      ..sort((a, b) => a.row.compareTo(b.row));
    return pending.isEmpty ? null : pending.first;
  }

  Project copyWith({
    String? name,
    StitchTechnique? technique,
    String? yarn,
    String? needle,
    ProjectStatus? status,
    int? currentRow,
    int? targetRow,
    bool clearTargetRow = false,
    DateTime? startedAt,
    String? notes,
    List<Marker>? markers,
    String? patternId,
    bool clearPatternId = false,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      technique: technique ?? this.technique,
      yarn: yarn ?? this.yarn,
      needle: needle ?? this.needle,
      status: status ?? this.status,
      currentRow: currentRow ?? this.currentRow,
      targetRow: clearTargetRow ? null : (targetRow ?? this.targetRow),
      startedAt: startedAt ?? this.startedAt,
      notes: notes ?? this.notes,
      markers: markers ?? this.markers,
      patternId: clearPatternId ? null : (patternId ?? this.patternId),
    );
  }
}

@immutable
class PatternRow {
  final int row;
  final String instruction;
  final int? stitchCount;

  const PatternRow({
    required this.row,
    required this.instruction,
    this.stitchCount,
  });

  factory PatternRow.fromJson(Map<String, dynamic> j) => PatternRow(
        row: j['row'] as int,
        instruction: j['instruction'] as String,
        stitchCount: j['stitch_count'] as int?,
      );
}

@immutable
class PatternSection {
  final String title;
  final String? subtitle;
  final List<PatternRow> rows;

  const PatternSection({
    required this.title,
    this.subtitle,
    required this.rows,
  });

  factory PatternSection.fromJson(Map<String, dynamic> j) => PatternSection(
        title: j['title'] as String,
        subtitle: j['subtitle'] as String?,
        rows: (j['rows'] as List)
            .cast<Map<String, dynamic>>()
            .map(PatternRow.fromJson)
            .toList(),
      );
}

@immutable
class Pattern {
  final String id;
  final String name;
  final String author;
  final StitchTechnique technique;
  final Difficulty difficulty;
  final String yarnRequirement;
  final Duration estimatedTime;
  final String description;
  final String? suggestedNeedle;
  final List<PatternSection> sections;

  /// Glossário de abreviações usadas (ex.: "sc" → "single crochet"). Opcional;
  /// vem preenchido em receitas importadas.
  final Map<String, String>? abbrevGlossary;

  const Pattern({
    required this.id,
    required this.name,
    required this.author,
    required this.technique,
    required this.difficulty,
    required this.yarnRequirement,
    required this.estimatedTime,
    required this.description,
    required this.sections,
    this.suggestedNeedle,
    this.abbrevGlossary,
  });

  int get totalRows => sections.fold(0, (sum, s) => sum + s.rows.length);

  factory Pattern.fromJson(Map<String, dynamic> j) => Pattern(
        id: j['id'] as String,
        name: j['name'] as String,
        author: j['author'] as String,
        technique:
            StitchTechniqueX.fromKey(j['technique'] as String),
        difficulty: DifficultyX.fromKey(j['difficulty'] as String),
        yarnRequirement: j['yarn_requirement'] as String,
        estimatedTime: Duration(hours: j['estimated_hours'] as int),
        description: j['description'] as String,
        suggestedNeedle: j['suggested_needle'] as String?,
        sections: (j['sections'] as List)
            .cast<Map<String, dynamic>>()
            .map(PatternSection.fromJson)
            .toList(),
        abbrevGlossary: (j['abbrev_glossary'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v.toString())),
      );
}
