import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:instructai/course_model.dart';
import 'splash_screen.dart';
import 'home_screen.dart';
import 'create_course_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'learn_screen.dart';
import 'settings_screen.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // // Define your desired Hive storage directory
  // const hiveFolderPath = '/storage/emulated/0/InstructAI/data';
  //
  // final hiveDir = Directory(hiveFolderPath);
  // if (!await hiveDir.exists()) {
  //   await hiveDir.create(recursive: true); //  Create folder if it doesn't exist
  // }
  //
  // Hive.init(hiveFolderPath); // Tell Hive to use that path
  //
  // Hive.registerAdapter(CourseModelAdapter());
  // Hive.registerAdapter(ModuleModelAdapter());
  await _initializeHiveIfPermitted();


  runApp(const InstructAIApp());
}

Future<void> _initializeHiveIfPermitted() async {
  //  Check Android version for permission type
  bool hasPermission = false;

  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 30) {
      hasPermission = await Permission.manageExternalStorage.isGranted;
    } else {
      hasPermission = await Permission.storage.isGranted;
    }
  }

  if (!hasPermission) {
    debugPrint("Storage permission not granted. Skipping Hive init.");
    return;
  }

  //  Safe folder creation and Hive initialization
  const hiveFolderPath = '/storage/emulated/0/InstructAI/data';

  try {
    final hiveDir = Directory(hiveFolderPath);
    if (!await hiveDir.exists()) {
      await hiveDir.create(recursive: true);
      debugPrint("Hive folder created at: $hiveFolderPath");
    }

    Hive.init(hiveFolderPath);
    Hive.registerAdapter(CourseModelAdapter());
    Hive.registerAdapter(ModuleModelAdapter());

    debugPrint("Hive initialized at: $hiveFolderPath");
  } catch (e) {
    debugPrint("Error initializing Hive: $e");
  }
}

class InstructAIApp extends StatelessWidget {
  const InstructAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _modelLoading = true;

  final List<Widget> _screens = [
    const HomeScreen(),
    const CreateCourseScreen(),
    const LearnScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadModelOnce();
  }

  Future<void> _loadModelOnce() async {
    const modelPath = "/storage/emulated/0/InstructAI/models/gemma-3n-E2B-it-int4.task";
    const MethodChannel _channel = MethodChannel('genai/method');

    try {
      final result = await _channel.invokeMethod('loadModel', {
        'modelPath': modelPath,
      });
      debugPrint("Model loaded in MainNavigation: $result");
    } catch (e) {
      debugPrint("Failed to load model: $e");
      // optionally show a dialog/toast here
    }

    setState(() => _modelLoading = false); // hide loading spinner
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Step 1: Show loading state while model is being loaded
    if (_modelLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading AI model... Please wait."),
            ],
          ),
        ),
      );
    }

    // Step 2: Show full UI only after model is ready
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: 'Create'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Learn'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'Info'),
        ],
      ),
    );
  }
}
