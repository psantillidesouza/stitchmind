import 'package:hive/hive.dart';

import '../../domain/entities/entities.dart';

class StitchTechniqueAdapter extends TypeAdapter<StitchTechnique> {
  @override
  final int typeId = 0;

  @override
  StitchTechnique read(BinaryReader reader) {
    return StitchTechnique.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, StitchTechnique obj) {
    writer.writeByte(obj.index);
  }
}

class ProjectStatusAdapter extends TypeAdapter<ProjectStatus> {
  @override
  final int typeId = 1;

  @override
  ProjectStatus read(BinaryReader reader) {
    return ProjectStatus.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, ProjectStatus obj) {
    writer.writeByte(obj.index);
  }
}

class MarkerAdapter extends TypeAdapter<Marker> {
  @override
  final int typeId = 3;

  @override
  Marker read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    return Marker(
      row: fields[0] as int,
      note: (fields[1] as String?) ?? '',
      done: (fields[2] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Marker obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.row)
      ..writeByte(1)
      ..write(obj.note)
      ..writeByte(2)
      ..write(obj.done);
  }
}

class ProjectAdapter extends TypeAdapter<Project> {
  @override
  final int typeId = 2;

  @override
  Project read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    final markersRaw = fields[10] as List?;
    return Project(
      id: fields[0] as String,
      name: fields[1] as String,
      technique: fields[2] as StitchTechnique,
      yarn: fields[3] as String,
      needle: fields[4] as String,
      status: fields[5] as ProjectStatus,
      currentRow: fields[6] as int,
      targetRow: fields[7] as int?,
      startedAt: DateTime.fromMillisecondsSinceEpoch(fields[8] as int),
      notes: (fields[9] as String?) ?? '',
      markers: markersRaw == null
          ? const <Marker>[]
          : markersRaw.cast<Marker>(),
      patternId: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Project obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.technique)
      ..writeByte(3)
      ..write(obj.yarn)
      ..writeByte(4)
      ..write(obj.needle)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.currentRow)
      ..writeByte(7)
      ..write(obj.targetRow)
      ..writeByte(8)
      ..write(obj.startedAt.millisecondsSinceEpoch)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.markers)
      ..writeByte(11)
      ..write(obj.patternId);
  }
}
