// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CourseModelAdapter extends TypeAdapter<CourseModel> {
  @override
  final int typeId = 0;

  @override
  CourseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CourseModel(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      modules: (fields[3] as List).cast<ModuleModel>(),
      isRecommended: fields[4] as bool,
      isStarted: fields[5] as bool,
      createdAt: fields[6] as DateTime,
      roadmap: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CourseModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.modules)
      ..writeByte(4)
      ..write(obj.isRecommended)
      ..writeByte(5)
      ..write(obj.isStarted)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.roadmap);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ModuleModelAdapter extends TypeAdapter<ModuleModel> {
  @override
  final int typeId = 1;

  @override
  ModuleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ModuleModel(
      title: fields[0] as String,
      topics: (fields[1] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ModuleModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.topics);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModuleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
