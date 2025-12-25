import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'course_model.dart';

class CustomCourseDetailScreen extends StatefulWidget {
  final String title;
  final String description;

  const CustomCourseDetailScreen({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  State<CustomCourseDetailScreen> createState() => _CustomCourseDetailScreenState();
}

class _CustomCourseDetailScreenState extends State<CustomCourseDetailScreen>
    with TickerProviderStateMixin {
  static const EventChannel _streamChannel = EventChannel('genai/stream');
  static const MethodChannel _methodChannel = MethodChannel('genai/method');

  String roadmapText = "";
  StreamSubscription? _streamSubscription;

  bool _isGenerating = false;
  bool _isModelBusy = false;

  late AnimationController _fadeAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimationController.forward();
    _generateRoadmap();
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _pulseAnimationController.dispose();
    _streamSubscription?.cancel();
    _resetModelSession();
    super.dispose();
  }

  Future<void> _generateRoadmap() async {
    if (_isModelBusy) {
      _showModelBusyWarning();
      return;
    }

    await _resetModelSession();

    setState(() {
      roadmapText = "";
      _isGenerating = true;
      _isModelBusy = true;
    });

    await _streamSubscription?.cancel();

    _streamSubscription = _streamChannel
        .receiveBroadcastStream({
      "prompt": _buildPrompt(widget.title, widget.description),
    })
        .listen(
          (chunk) {
        if (!mounted) return;
        setState(() {
          roadmapText += chunk;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
          _isModelBusy = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
          _isModelBusy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to generate roadmap")),
        );
      },
    );
  }

  Future<void> _resetModelSession() async {
    try {
      await _methodChannel.invokeMethod('cancelGeneration');
    } catch (e) {
      debugPrint("Model reset failed: $e");
    }
  }

  void _showModelBusyWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.hourglass_top, color: Colors.orange.shade300),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Please wait for the current roadmap to finish before starting a new one.",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _buildPrompt(String title, String desc) {
    return '''
You are an expert AI course creator. Based on the following course, generate a structured roadmap that progressively covers all important concepts from beginner to advanced level.

Course Title: "$title"  
Course Description: $desc

Instructions:
- Structure the roadmap into **up to 3 modules**:
  - **Module 1** should focus on **Beginner** level fundamentals.
  - **Module 2** should cover **Intermediate** topics that build upon the basics.
  - **Module 3** (if needed) should introduce **Advanced** concepts or applications.
- Each module must include:
  - A **descriptive title**
  - **3 to 4 concise and logically grouped topics** that represent the scope of that level.
- Ensure the course covers **all essential and practical concepts** needed to understand or apply the subject thoroughly.
- Be informative yet compact. Avoid repetition.
- Add an **Estimated Completion Time** at the end, based on the topic depth.

Output Format:

Module 1 (Beginner): [Module Title]
- Topic 1
- Topic 2
- Topic 3

Module 2 (Intermediate): [Module Title]
- Topic 1
- Topic 2
- Topic 3

Module 3 (Advanced): [Module Title]
- Topic 1
- Topic 2
- Topic 3

Estimated Completion Time: [X hours] or [X weeks]
''';
  }

  void _saveAndStartLearning() async {
    final parsedModules = _parseRoadmap(roadmapText);
    if (parsedModules.isEmpty) {
      _showErrorSnackBar("Invalid roadmap. Try regenerating.");
      return;
    }

    final box = await Hive.openBox<CourseModel>('courses');
    final course = CourseModel(
      id: const Uuid().v4(),
      title: widget.title,
      description: widget.description,
      modules: parsedModules,
      isRecommended: false, // important difference
      roadmap: roadmapText,
      isStarted: true,
      createdAt: DateTime.now(),
    );
    await box.put(course.id, course);

    if (!mounted) return;

    _showSuccessDialog();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade300),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade50,
                Colors.blue.shade50,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.blue.shade400],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "🎉 Course Created Successfully!",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Your personalized learning roadmap is ready. You can now start your journey from the Learn tab.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // dialog
                    Navigator.of(context).pop(); // screen
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text("Got it!"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<ModuleModel> _parseRoadmap(String roadmap) {
    final lines = roadmap.split('\n');
    final modules = <ModuleModel>[];

    String? currentTitle;
    List<String> currentTopics = [];

    final moduleRegex = RegExp(r'^\*\*(.+?)\*\*$');

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase().startsWith('estimated')) continue;

      final match = moduleRegex.firstMatch(trimmed);
      if (match != null) {
        if (currentTitle != null && currentTopics.isNotEmpty) {
          modules.add(ModuleModel(title: currentTitle, topics: List.from(currentTopics)));
        }
        currentTitle = match.group(1)?.trim();
        currentTopics.clear();
      } else if (trimmed.startsWith('-')) {
        currentTopics.add(trimmed.substring(1).trim());
      }
    }

    if (currentTitle != null && currentTopics.isNotEmpty) {
      modules.add(ModuleModel(title: currentTitle, topics: currentTopics));
    }

    return modules;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isModelBusy) {
          _showModelBusyWarning();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(child: _buildCourseHeader()),
            SliverToBoxAdapter(child: _buildRoadmapSection()),
            SliverToBoxAdapter(child: _buildActionButtons()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 60,
      leading: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
          onPressed: () {
            if (_isModelBusy) {
              _showModelBusyWarning();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade400, Colors.blue.shade400],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.create, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Text(
            "Custom Course",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.deepPurple.shade50,
                Colors.white,
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (_isGenerating)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Icon(
                        Icons.auto_awesome,
                        color: Colors.orange.shade700,
                        size: 14,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                Text(
                  "AI Working",
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  "Ready",
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCourseHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple.shade400, Colors.blue.shade400],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.create, size: 12, color: Colors.purple.shade700),
                            const SizedBox(width: 4),
                            Text(
                              "Custom Course",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.purple.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        "Course Description",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.pink.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.route, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "Learning Roadmap",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (_isGenerating)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Generating...",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.deepPurple.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: roadmapText.isEmpty
                ? _buildEmptyRoadmapState()
                : _buildRoadmapContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRoadmapState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isGenerating) ...[
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade100, Colors.purple.shade100],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 48,
                    color: Colors.deepPurple.shade600,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            "Creating Your Personalized Roadmap",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "AI is analyzing the course content and building\na structured learning path just for you...",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.map_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "No Roadmap Generated Yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Click 'Generate Roadmap' to create your\npersonalized learning journey.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildRoadmapContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.teal.shade400],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  "Roadmap Ready",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MarkdownBody(
            data: roadmapText,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
              listBullet: TextStyle(fontSize: 15, color: Colors.deepPurple.shade600),
              code: const TextStyle(
                fontSize: 13,
                backgroundColor: Color(0xFFF0F0F0),
                fontFamily: 'monospace',
              ),
              h2: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
              h3: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
              blockquote: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple.shade300),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _isGenerating ? null : _generateRoadmap,
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isGenerating
                              ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.deepPurple.shade400,
                              ),
                            ),
                          )
                              : Icon(
                            Icons.refresh,
                            color: Colors.deepPurple.shade600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isGenerating ? "Generating..." : "Regenerate",
                          style: TextStyle(
                            color: _isGenerating
                                ? Colors.grey.shade500
                                : Colors.deepPurple.shade600,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: roadmapText.isNotEmpty && !_isGenerating
                      ? [Colors.green.shade400, Colors.teal.shade400]
                      : [Colors.grey.shade300, Colors.grey.shade400],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: roadmapText.isNotEmpty && !_isGenerating
                    ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: roadmapText.isNotEmpty && !_isGenerating
                      ? _saveAndStartLearning
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Start Learning",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}