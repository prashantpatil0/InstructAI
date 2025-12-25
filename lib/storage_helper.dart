import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

class CourseFileManager {
  static Future<Directory> _getCoursesFolder() async {
    const path = "/storage/emulated/0/InstructAI/courses";
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<bool> writeCourseRoadmap({
    required String title,
    required Map<String, dynamic> roadmap,
  }) async {
    try {
      final dir = await _getCoursesFolder();
      final safeTitle = title.toLowerCase().replaceAll(' ', '_');
      final file = File("${dir.path}/$safeTitle.json");

      final jsonContent = const JsonEncoder.withIndent('  ').convert(roadmap);
      await file.writeAsString(jsonContent);

      return true;
    } catch (e) {
      print("Failed to write course file: $e");
      return false;
    }
  }

  static Future<List<FileSystemEntity>> listSavedCourses() async {
    final dir = await _getCoursesFolder();
    return dir.list().toList();
  }
}
