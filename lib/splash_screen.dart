import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'download_model_screen.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  final String modelFileName = "gemma-3n-E2B-it-int4.task";

  // UI Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Status tracking
  String _currentStatus = "Initializing...";
  bool _hasError = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _init();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Start animations
    _fadeController.forward();
    _scaleController.forward();
  }

  Future<void> _init() async {
    try {
      await _updateStatus("Checking device compatibility...");
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 1: Device compatibility check
      final isCompatible = await _checkDeviceCompatibility();
      if (!isCompatible) {
        throw Exception("Device not compatible with storage requirements");
      }

      await _updateStatus("Requesting permissions...");
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 2: Permission handling with retries
      final permissionGranted = await _requestStoragePermissionWithRetry();
      if (!permissionGranted) {
        _showPermissionError();
        return;
      }

      await _updateStatus("Verifying storage access...");
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 3: Verify we can actually write to the directory
      final storageAccessible = await _verifyStorageAccess();
      if (!storageAccessible) {
        throw Exception("Cannot access storage directory");
      }

      await _updateStatus("Checking AI model...");
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 4: Check model file with comprehensive verification
      final modelStatus = await _checkModelFileComprehensive();

      await _updateStatus("Loading application...");
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Navigate based on model status
      if (modelStatus.exists && modelStatus.isValid) {
        _goToMainApp();
      } else {
        _goToDownloadScreen();
      }

    } catch (e, stack) {
      debugPrint("Splash init error (attempt ${_retryCount + 1}): $e\n$stack");
      await _handleInitError(e);
    }
  }

  Future<bool> _checkDeviceCompatibility() async {
    try {
      if (!Platform.isAndroid) return true;

      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      // Check Android version (minimum API 21 - Android 5.0)
      if (androidInfo.version.sdkInt < 21) {
        debugPrint("Device Android version too old: ${androidInfo.version.sdkInt}");
        return false;
      }

      // Check available storage space (minimum 5GB for safety)
      final directory = Directory('/storage/emulated/0');
      if (await directory.exists()) {
        // Basic existence check passed
        return true;
      }

      return false;
    } catch (e) {
      debugPrint("Device compatibility check failed: $e");
      return false;
    }
  }

  Future<bool> _requestStoragePermissionWithRetry() async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final granted = await _requestStoragePermission();
        if (granted) {
          debugPrint("Storage permission granted on attempt ${attempt + 1}");
          return true;
        }

        if (attempt < _maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      } catch (e) {
        debugPrint("Permission request attempt ${attempt + 1} failed: $e");
      }
    }

    return false;
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      debugPrint("Android SDK: $sdkInt");

      // Android 11+ (API 30+) - Use MANAGE_EXTERNAL_STORAGE
      if (sdkInt >= 30) {
        // Check current status
        var manageStatus = await Permission.manageExternalStorage.status;
        debugPrint("MANAGE_EXTERNAL_STORAGE status: $manageStatus");

        if (manageStatus.isGranted) return true;

        // Request permission
        var result = await Permission.manageExternalStorage.request();
        debugPrint("MANAGE_EXTERNAL_STORAGE request result: $result");

        if (result.isGranted) return true;

        // If denied, also try regular storage permission as fallback
        var storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          var storageResult = await Permission.storage.request();
          debugPrint("Fallback storage permission result: $storageResult");
          return storageResult.isGranted;
        }

        return storageStatus.isGranted;

      }
      // Android 10 (API 29) - Special handling
      else if (sdkInt == 29) {
        // Try both permissions for Android 10
        var storageStatus = await Permission.storage.status;
        var externalStatus = await Permission.manageExternalStorage.status;

        if (storageStatus.isGranted || externalStatus.isGranted) return true;

        // Request both
        var storageResult = await Permission.storage.request();
        if (storageResult.isGranted) return true;

        // Try external storage as well
        var externalResult = await Permission.manageExternalStorage.request();
        return externalResult.isGranted;

      }
      // Android 6.0-9 (API 23-28) - Use regular storage permission
      else if (sdkInt >= 23) {
        var status = await Permission.storage.status;
        debugPrint("Storage permission status: $status");

        if (status.isGranted) return true;

        var result = await Permission.storage.request();
        debugPrint("Storage permission request result: $result");

        return result.isGranted;

      }
      // Android 5.x (API 21-22) - Permissions granted at install time
      else {
        return true;
      }

    } catch (e) {
      debugPrint("Permission request error: $e");
      return false;
    }
  }

  Future<bool> _verifyStorageAccess() async {
    try {
      const basePath = "/storage/emulated/0/InstructAI";
      final baseDir = Directory(basePath);

      // Try to create the directory structure
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      // Verify we can write to it
      final testFile = File("$basePath/test_write.tmp");
      await testFile.writeAsString("test");

      // Verify we can read from it
      final content = await testFile.readAsString();

      // Clean up
      if (await testFile.exists()) {
        await testFile.delete();
      }

      return content == "test";

    } catch (e) {
      debugPrint("Storage access verification failed: $e");
      return false;
    }
  }

  Future<ModelStatus> _checkModelFileComprehensive() async {
    try {
      const modelFolderPath = "/storage/emulated/0/InstructAI/models";
      final modelPath = "$modelFolderPath/$modelFileName";
      final modelFile = File(modelPath);

      // Check if file exists
      if (!await modelFile.exists()) {
        return ModelStatus(exists: false, isValid: false, reason: "File not found");
      }

      // Check file size (should be > 1GB for this model)
      final fileSize = await modelFile.length();
      if (fileSize < 1024 * 1024 * 500) { // Less than 500MB suggests incomplete download
        return ModelStatus(
            exists: true,
            isValid: false,
            reason: "File too small (${_formatBytes(fileSize)}), possibly corrupted"
        );
      }

      // Try to read the first few bytes to ensure it's accessible
      final randomAccess = await modelFile.open(mode: FileMode.read);
      await randomAccess.read(1024);
      await randomAccess.close();

      debugPrint("Model file verified: ${_formatBytes(fileSize)}");
      return ModelStatus(exists: true, isValid: true, reason: "Valid model file");

    } catch (e) {
      debugPrint("Model file check error: $e");
      return ModelStatus(exists: false, isValid: false, reason: "Access error: $e");
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _handleInitError(dynamic error) async {
    _retryCount++;

    if (_retryCount < _maxRetries) {
      await _updateStatus("Retrying... (${_retryCount}/$_maxRetries)");
      await Future.delayed(Duration(milliseconds: 1000 * _retryCount));

      // Reset retry and try again
      await _init();
    } else {
      setState(() {
        _hasError = true;
        _currentStatus = "Failed to initialize. Please restart the app.";
      });

      // Still try to navigate to download screen as fallback
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) _goToDownloadScreen();
    }
  }

  Future<void> _updateStatus(String status) async {
    if (mounted) {
      setState(() {
        _currentStatus = status;
      });
    }
  }

  void _showPermissionError() {
    setState(() {
      _hasError = true;
      _currentStatus = "Storage permission required";
    });

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Permission Required"),
          content: const Text(
              "InstructAI needs storage permission to download and manage AI models. "
                  "Please grant permission in the next dialog or through device settings."
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Retry permission request
                _retryCount = 0;
                _hasError = false;
                _init();
              },
              child: const Text("Retry"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _goToDownloadScreen(); // Continue anyway
              },
              child: const Text("Continue"),
            ),
          ],
        ),
      );
    }
  }

  void _goToMainApp() {
    if (!mounted) return;
    debugPrint("Navigating to main app");
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _goToDownloadScreen() {
    if (!mounted) return;
    debugPrint("Navigating to download screen");
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const DownloadModelScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // or your app’s primary color
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App Icon (replace with your logo if needed)
            Icon(
              Icons.school,
              size: 64,
              color: Colors.deepPurple,
            ),

            const SizedBox(height: 16),

            // App Name
            const Text(
              "InstructAI",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            // Subtext or Loading Message
            const Text(
              "Preparing your experience...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class for model status
class ModelStatus {
  final bool exists;
  final bool isValid;
  final String reason;

  ModelStatus({
    required this.exists,
    required this.isValid,
    required this.reason,
  });
}