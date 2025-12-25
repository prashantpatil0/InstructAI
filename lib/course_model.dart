import 'package:hive/hive.dart';

part 'course_model.g.dart';

@HiveType(typeId: 0)
class CourseModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final List<ModuleModel> modules;

  @HiveField(4)
  final bool isRecommended;

  @HiveField(5)
  final bool isStarted;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  String? roadmap;

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.modules,
    this.isRecommended = false,
    required this.isStarted,
    required this.createdAt,
    this.roadmap,
  });
}


@HiveType(typeId: 1)
class ModuleModel extends HiveObject {
  @HiveField(0)
  final String title;

  @HiveField(1)
  final List<String> topics;

  ModuleModel({
    required this.title,
    required this.topics,
  });
}
