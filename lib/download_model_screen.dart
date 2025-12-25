import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart';

class DownloadModelScreen extends StatefulWidget {
  const DownloadModelScreen({super.key});

  @override
  State<DownloadModelScreen> createState() => _DownloadModelScreenState();
}

class _DownloadModelScreenState extends State<DownloadModelScreen> {
  final String modelFileName = "gemma-3n-E2B-it-int4.task";
  final String downloadUrl = "https://huggingface.co/gummybear2555/Gemma-3n-E2B-it-int4/resolve/main/gemma-3n-E2B-it-int4.task";

  String modelFolderPath = "";
  bool isDownloading = false;
  double downloadProgress = 0.0;
  String downloadStatus = "";
  bool isModelAvailable = false;

  // Parallel download settings
  int numberOfChunks = 8; // Number of parallel connections
  List<double> chunkProgresses = [];
  List<bool> chunkCompleted = [];
  int totalBytes = 0;
  int downloadedBytes = 0;
  DateTime? downloadStartTime;
  double currentSpeed = 0.0;

  late List<Dio> dioInstances;
  List<CancelToken> cancelTokens = [];

  @override
  void initState() {
    super.initState();
    _prepareModelFolder();
  }

  void _initializeDioInstances() {
    dioInstances = [];
    cancelTokens = [];
    chunkProgresses = List.filled(numberOfChunks, 0.0);
    chunkCompleted = List.filled(numberOfChunks, false);

    for (int i = 0; i < numberOfChunks; i++) {
      final dio = Dio();

      // Optimized configuration for parallel downloads
      dio.options = BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'User-Agent': 'InstructAI/1.0 (High-Speed-Downloader)',
          'Accept': '*/*',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'keep-alive',
          'Cache-Control': 'no-cache',
        },
      );

      // Configure for maximum performance
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Accept-Ranges'] = 'bytes';
          options.headers['Pragma'] = 'no-cache';
          handler.next(options);
        },
      ));

      dioInstances.add(dio);
      cancelTokens.add(CancelToken());
    }
  }

  Future<void> _prepareModelFolder() async {
    await _requestStoragePermission();

    final Directory baseDir = Directory('/storage/emulated/0/InstructAI/models');

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    setState(() {
      modelFolderPath = baseDir.path;
    });

    await _checkModelAvailability();
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }

      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    }
  }

  Future<void> _checkModelAvailability() async {
    final modelFile = File("$modelFolderPath/$modelFileName");
    setState(() {
      isModelAvailable = modelFile.existsSync();
    });
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: downloadUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Link copied to clipboard")),
      );
    }
  }

  Future<bool> _checkServerSupportsRangeRequests() async {
    try {
      final dio = Dio();
      final response = await dio.head(downloadUrl);

      // Check if server supports range requests
      final acceptRanges = response.headers.value('accept-ranges');
      final contentLength = response.headers.value('content-length');

      if (acceptRanges?.toLowerCase() == 'bytes' && contentLength != null) {
        totalBytes = int.parse(contentLength);
        return true;
      }

      // Fallback: try a small range request
      final testResponse = await dio.get(
        downloadUrl,
        options: Options(headers: {'Range': 'bytes=0-1023'}),
      );

      if (testResponse.statusCode == 206) {
        // Server supports partial content
        final contentRange = testResponse.headers.value('content-range');
        if (contentRange != null) {
          final match = RegExp(r'bytes \d+-\d+/(\d+)').firstMatch(contentRange);
          if (match != null) {
            totalBytes = int.parse(match.group(1)!);
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      print('Error checking range support: $e');
      return false;
    }
  }

  Future<void> _downloadModel() async {
    if (isDownloading) return;

    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
      downloadStatus = "Initializing high-speed download...";
      downloadStartTime = DateTime.now();
      downloadedBytes = 0;
      currentSpeed = 0.0;
    });

    try {
      // Check if server supports range requests
      bool supportsRanges = await _checkServerSupportsRangeRequests();

      if (!supportsRanges || totalBytes == 0) {
        // Fallback to single connection download
        await _fallbackSingleDownload();
        return;
      }

      // Adjust chunk count based on file size
      _optimizeChunkCount();

      setState(() {
        downloadStatus = "Starting $numberOfChunks parallel connections...";
      });

      _initializeDioInstances();

      final modelFile = File("$modelFolderPath/$modelFileName");

      // Create chunk files
      List<File> chunkFiles = [];
      List<Future<void>> downloadTasks = [];

      int chunkSize = (totalBytes / numberOfChunks).ceil();

      for (int i = 0; i < numberOfChunks; i++) {
        final chunkFile = File("$modelFolderPath/${modelFileName}.chunk$i");
        chunkFiles.add(chunkFile);

        int startByte = i * chunkSize;
        int endByte = min((i + 1) * chunkSize - 1, totalBytes - 1);

        // Resume support for chunks
        if (await chunkFile.exists()) {
          int existingSize = await chunkFile.length();
          if (existingSize > 0 && existingSize <= (endByte - startByte + 1)) {
            startByte += existingSize;
            chunkProgresses[i] = existingSize / (endByte - startByte + existingSize).toDouble();
          }
        }

        if (startByte <= endByte) {
          downloadTasks.add(_downloadChunk(i, startByte, endByte, chunkFile));
        } else {
          chunkCompleted[i] = true;
          chunkProgresses[i] = 1.0;
        }
      }

      // Start speed calculation timer
      _startSpeedCalculation();

      // Wait for all chunks to complete
      await Future.wait(downloadTasks);

      // Verify all chunks completed
      bool allChunksComplete = chunkCompleted.every((completed) => completed);

      if (!allChunksComplete) {
        throw Exception('Some chunks failed to download');
      }

      setState(() {
        downloadStatus = "Merging downloaded chunks...";
      });

      // Merge chunks into final file
      await _mergeChunks(chunkFiles, modelFile);

      // Clean up chunk files
      await _cleanupChunkFiles(chunkFiles);

      setState(() {
        downloadStatus = "Download completed successfully!";
        isModelAvailable = true;
        downloadProgress = 1.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Model downloaded successfully in ${_getElapsedTime()}!"),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      await _handleDownloadError(e);
    } finally {
      setState(() {
        isDownloading = false;
      });
    }
  }

  void _optimizeChunkCount() {
    // Optimize chunk count based on file size and device capabilities
    if (totalBytes < 100 * 1024 * 1024) { // < 100MB
      numberOfChunks = 4;
    } else if (totalBytes < 500 * 1024 * 1024) { // < 500MB
      numberOfChunks = 6;
    } else if (totalBytes < 1024 * 1024 * 1024) { // < 1GB
      numberOfChunks = 8;
    } else { // >= 1GB
      numberOfChunks = 12;
    }
  }

  Future<void> _downloadChunk(int chunkIndex, int startByte, int endByte, File chunkFile) async {
    try {
      await dioInstances[chunkIndex].download(
        downloadUrl,
        chunkFile.path,
        onReceiveProgress: (received, total) {
          chunkProgresses[chunkIndex] = received / (endByte - startByte + 1);
          _updateOverallProgress();
        },
        cancelToken: cancelTokens[chunkIndex],
        options: Options(
          headers: {
            'Range': 'bytes=$startByte-$endByte',
          },
          receiveDataWhenStatusError: true,
        ),
      );

      chunkCompleted[chunkIndex] = true;

    } catch (e) {
      if (!cancelTokens[chunkIndex].isCancelled) {
        print('Chunk $chunkIndex download error: $e');
        throw e;
      }
    }
  }

  void _updateOverallProgress() {
    double totalProgress = 0;
    for (int i = 0; i < numberOfChunks; i++) {
      totalProgress += chunkProgresses[i];
    }

    setState(() {
      downloadProgress = totalProgress / numberOfChunks;
      downloadedBytes = (downloadProgress * totalBytes).round();
    });
  }

  void _startSpeedCalculation() {
    int lastBytes = 0;
    DateTime lastTime = DateTime.now();

    Stream.periodic(const Duration(milliseconds: 500)).listen((event) {
      if (!isDownloading) return;

      final now = DateTime.now();
      final timeDiff = now.difference(lastTime).inMilliseconds / 1000.0;
      final bytesDiff = downloadedBytes - lastBytes;

      if (timeDiff > 0) {
        currentSpeed = bytesDiff / timeDiff;
        lastBytes = downloadedBytes;
        lastTime = now;

        final eta = currentSpeed > 0 ? (totalBytes - downloadedBytes) / currentSpeed : 0;

        setState(() {
          downloadStatus = "Downloading at ${_formatSpeed(currentSpeed)} - "
              "ETA: ${_formatDuration(eta.round())} - "
              "${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}";
        });
      }
    });
  }

  Future<void> _mergeChunks(List<File> chunkFiles, File finalFile) async {
    final output = finalFile.openWrite();

    try {
      for (int i = 0; i < chunkFiles.length; i++) {
        if (await chunkFiles[i].exists()) {
          await output.addStream(chunkFiles[i].openRead());
        }
      }
    } finally {
      await output.close();
    }
  }

  Future<void> _cleanupChunkFiles(List<File> chunkFiles) async {
    for (final chunkFile in chunkFiles) {
      if (await chunkFile.exists()) {
        try {
          await chunkFile.delete();
        } catch (e) {
          print('Error deleting chunk file: $e');
        }
      }
    }
  }

  Future<void> _fallbackSingleDownload() async {
    setState(() {
      downloadStatus = "Server doesn't support parallel download. Using single connection...";
    });

    final dio = Dio();
    final modelFile = File("$modelFolderPath/$modelFileName");

    await dio.download(
      downloadUrl,
      modelFile.path,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          setState(() {
            downloadProgress = received / total;
            downloadedBytes = received;
            totalBytes = total;

            final elapsed = DateTime.now().difference(downloadStartTime!).inSeconds;
            if (elapsed > 0) {
              currentSpeed = received / elapsed;
              downloadStatus = "Downloading at ${_formatSpeed(currentSpeed)} - "
                  "${_formatBytes(received)} / ${_formatBytes(total)}";
            }
          });
        }
      },
    );

    setState(() {
      downloadStatus = "Download completed successfully!";
      isModelAvailable = true;
    });
  }

  Future<void> _handleDownloadError(dynamic error) async {
    String errorMessage = "Download failed";

    if (error is DioException) {
      if (error.type == DioExceptionType.cancel) {
        errorMessage = "Download cancelled";
      } else if (error.type == DioExceptionType.connectionTimeout) {
        errorMessage = "Connection timeout - please check your internet";
      } else if (error.type == DioExceptionType.receiveTimeout) {
        errorMessage = "Download timeout - please try again";
      } else {
        errorMessage = "Network error: ${error.message}";
      }
    } else {
      errorMessage = "Unexpected error: $error";
    }

    setState(() {
      downloadStatus = errorMessage;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelDownload() {
    for (final token in cancelTokens) {
      if (!token.isCancelled) {
        token.cancel("Download cancelled by user");
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatSpeed(double bytesPerSecond) {
    return '${_formatBytes(bytesPerSecond.round())}/s';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
  }

  String _getElapsedTime() {
    if (downloadStartTime == null) return '';
    final elapsed = DateTime.now().difference(downloadStartTime!);
    return _formatDuration(elapsed.inSeconds);
  }

  Future<void> _onContinuePressed() async {
    final modelFile = File("$modelFolderPath/$modelFileName");

    if (await modelFile.exists()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Model file not found. Please download it first.")),
      );
    }
  }

  @override
  void dispose() {
    _cancelDownload();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Model Setup"),
        actions: [
          if (isDownloading)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelDownload,
              tooltip: "Cancel Download",
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: modelFolderPath.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Card(
                color: isModelAvailable ? Colors.green.shade50 : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        isModelAvailable ? Icons.check_circle : Icons.info,
                        color: isModelAvailable ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isModelAvailable
                              ? "AI Model is ready to use!"
                              : "AI Model needs to be downloaded for offline features.",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isModelAvailable ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              if (!isModelAvailable) ...[
                const Text(
                  "🚀 High-Speed AI Model Download",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Download using parallel connections for maximum speed (2.9 GB model).",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Download Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isDownloading ? null : _downloadModel,
                    icon: isDownloading
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.rocket_launch),
                    label: Text(isDownloading ? "Downloading..." : "Start High-Speed Download"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                // Download Progress
                if (isDownloading) ...[
                  const SizedBox(height: 20),

                  // Main Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: downloadProgress,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      minHeight: 12,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Progress Text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${(downloadProgress * 100).toStringAsFixed(1)}%",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (currentSpeed > 0)
                        Text(
                          _formatSpeed(currentSpeed),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    downloadStatus,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),

                  const SizedBox(height: 16),

                  // Individual chunk progress (for debugging/info)
                  if (chunkProgresses.isNotEmpty) ...[
                    const Text(
                      "Parallel Connections:",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: chunkProgresses.asMap().entries.map((entry) {
                        int index = entry.key;
                        double progress = entry.value;
                        return Container(
                          width: 40,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: chunkCompleted[index] ? Colors.green : Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],

                const SizedBox(height: 24),

                // Manual Download Section
                const Divider(),
                const SizedBox(height: 16),

                const Text(
                  "📱 Alternative: Manual Download",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  "If automatic download doesn't work:",
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),

                GestureDetector(
                  onTap: _copyToClipboard,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Expanded(
                          child: Text(
                            "https://huggingface.co/.../gemma-3n-E2B-it-int4.task",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        Icon(Icons.copy, size: 18)
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    "Save to: $modelFolderPath",
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blueGrey,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isModelAvailable ? _onContinuePressed : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                      isModelAvailable
                          ? "Continue to App"
                          : "Download model first"
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: isModelAvailable ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}