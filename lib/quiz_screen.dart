import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuizScreen extends StatefulWidget {
  final String selectedModule;
  final String roadmap;

  const QuizScreen({
    super.key,
    required this.selectedModule,
    required this.roadmap,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static const MethodChannel _methodChannel = MethodChannel('genai/method');
  static const EventChannel _streamChannel = EventChannel('genai/stream');

  late StreamSubscription _streamSubscription;
  late AnimationController _cardAnimationController;
  late AnimationController _progressAnimationController;
  late AnimationController _loadingAnimationController;

  List<dynamic> _questions = [];
  String _buffer = "";
  bool _isLoading = false;
  bool _hasError = false;
  int _currentQuestionIndex = 0;
  bool _showResults = false;

  // Track selected answers and whether user answered
  final Map<int, String> _selectedAnswers = {};
  final Map<int, bool> _answered = {};
  final Map<int, bool> _isCorrect = {};

  // Quiz statistics
  int get _correctAnswers =>
      _isCorrect.values
          .where((correct) => correct)
          .length;

  int get _totalAnswered =>
      _answered.values
          .where((answered) => answered)
          .length;

  double get _scorePercentage =>
      _totalAnswered > 0 ? (_correctAnswers / _totalAnswered) * 100 : 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )
      ..repeat();

    _generateQuiz();
  }

  @override
  void dispose() {
    _streamSubscription.cancel();
    _cardAnimationController.dispose();
    _progressAnimationController.dispose();
    _loadingAnimationController.dispose();
    _resetModelSession();
    super.dispose();
  }

  Future<void> _resetModelSession() async {
    try {
      await _methodChannel.invokeMethod("resetSession");
    } catch (e) {
      debugPrint("Reset session failed: $e");
    }
  }

  Future<void> _generateQuiz() async {
    await _resetModelSession();

    setState(() {
      _buffer = "";
      _isLoading = true;
      _hasError = false;
      _showResults = false;
    });

    // Optimized prompt for faster generation
    final prompt = """
Generate exactly 5 quiz questions for: ${widget.selectedModule}

Return ONLY valid JSON array:
[
  {"type":"mcq","question":"Question text?","options":["A","B","C","D"],"answer":"A"},
  {"type":"true_false","question":"Statement text.","answer":"True"}
]

Rules:
- Mix mcq and true_false types
- Keep questions concise and clear
- Focus on ${widget.selectedModule} concepts
- No explanations, just JSON array
""";

    try {
      _streamSubscription = _streamChannel
          .receiveBroadcastStream({"prompt": prompt})
          .listen((data) {
        setState(() {
          _buffer += data;
        });
      }, onDone: () {
        _parseQuestionsFromBuffer();
      }, onError: (e) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _parseQuestionsFromBuffer() {
    try {
      // Find JSON array in buffer more efficiently
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(_buffer);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final List<dynamic> result = json.decode(jsonStr);

        setState(() {
          _questions.clear();
          _questions.addAll(result);
          _isLoading = false;
          _currentQuestionIndex = 0;
        });

        // Start animations
        _cardAnimationController.forward();
        _progressAnimationController.forward();
      } else {
        throw Exception("No valid JSON found");
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _submitAnswer(int index, String selected) {
    if (_answered[index] == true) return;

    final question = _questions[index];
    final correctAnswer = question['answer'];
    final isCorrect = selected == correctAnswer;

    setState(() {
      _selectedAnswers[index] = selected;
      _answered[index] = true;
      _isCorrect[index] = isCorrect;
    });

    // Haptic feedback
    if (isCorrect) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }

    // Auto-advance after a delay
    if (index == _currentQuestionIndex) {
      Timer(const Duration(milliseconds: 1500), () {
        _nextQuestion();
      });
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _cardAnimationController.reset();
      _cardAnimationController.forward();
    } else if (_totalAnswered == _questions.length) {
      _showQuizResults();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
      _cardAnimationController.reset();
      _cardAnimationController.forward();
    }
  }

  void _showQuizResults() {
    setState(() {
      _showResults = true;
    });
  }

  void _resetQuiz() {
    setState(() {
      _selectedAnswers.clear();
      _answered.clear();
      _isCorrect.clear();
      _currentQuestionIndex = 0;
      _showResults = false;
    });
    _cardAnimationController.reset();
    _cardAnimationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildModernAppBar(),
      body: _buildQuizBody(),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.black87),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Quiz Challenge",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            widget.selectedModule,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        if (_questions.isNotEmpty && !_showResults) ...[
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade400],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.quiz, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  "${_currentQuestionIndex + 1}/${_questions.length}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuizBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_questions.isEmpty) {
      return _buildEmptyState();
    }

    if (_showResults) {
      return _buildResultsState();
    }

    return Column(
      children: [
        _buildProgressSection(),
        Expanded(child: _buildQuestionSection()),
        _buildNavigationSection(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _loadingAnimationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _loadingAnimationController.value * 2.0 * 3.14159,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                      Icons.psychology, color: Colors.white, size: 30),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "Generating Quiz Questions...",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "AI is crafting personalized questions for ${widget
                .selectedModule}",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            width: 200,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: AnimatedBuilder(
              animation: _loadingAnimationController,
              builder: (context, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (_loadingAnimationController.value * 0.7) + 0.3,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.purple.shade400],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Oops! Something went wrong",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We couldn't generate the quiz questions. Please try again.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _generateQuiz,
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.quiz,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "No Questions Available",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Let's generate some quiz questions to test your knowledge!",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _generateQuiz,
            icon: const Icon(Icons.auto_awesome),
            label: const Text("Generate Quiz"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Progress",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                "${_currentQuestionIndex + 1} of ${_questions.length}",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _progressAnimationController,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: ((_currentQuestionIndex + 1) / _questions.length) *
                    _progressAnimationController.value,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.purple.shade400,
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, size: 16,
                      color: Colors.green.shade600),
                  const SizedBox(width: 4),
                  Text(
                    "$_correctAnswers Correct",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (_totalAnswered > 0)
                Text(
                  "${_scorePercentage.round()}% Score",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSection() {
    return AnimatedBuilder(
      animation: _cardAnimationController,
      builder: (context, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _cardAnimationController,
          curve: Curves.easeOutCubic,
        ));

        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _cardAnimationController,
          curve: Curves.easeIn,
        ));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: _buildQuestionCard(
                _questions[_currentQuestionIndex], _currentQuestionIndex),
          ),
        );
      },
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int index) {
    final type = question['type'];
    final questionText = question['question'];
    final correctAnswer = question['answer'];
    final options = (question['options'] as List?) ??
        (type == 'true_false' ? ['True', 'False'] : []);

    final hasAnswered = _answered[index] == true;
    final selectedAnswer = _selectedAnswers[index];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Question header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.purple.shade400],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            type == 'mcq' ? 'Multiple Choice' : 'True / False',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (hasAnswered)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _isCorrect[index]!
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _isCorrect[index]! ? Icons.check : Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      questionText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Options section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: options.length,
                          itemBuilder: (context, optionIndex) {
                            final option = options[optionIndex];
                            final isSelected = selectedAnswer == option;
                            final isCorrect = option == correctAnswer;

                            Color? backgroundColor;
                            Color? borderColor;
                            Color? textColor = Colors.black87;

                            if (hasAnswered) {
                              if (isSelected && isCorrect) {
                                backgroundColor = Colors.green.shade50;
                                borderColor = Colors.green.shade400;
                                textColor = Colors.green.shade700;
                              } else if (isSelected && !isCorrect) {
                                backgroundColor = Colors.red.shade50;
                                borderColor = Colors.red.shade400;
                                textColor = Colors.red.shade700;
                              } else if (isCorrect) {
                                backgroundColor = Colors.green.shade50;
                                borderColor = Colors.green.shade200;
                                textColor = Colors.green.shade600;
                              } else {
                                backgroundColor = Colors.grey.shade50;
                                borderColor = Colors.grey.shade200;
                                textColor = Colors.grey.shade600;
                              }
                            } else {
                              backgroundColor =
                              isSelected ? Colors.blue.shade50 : Colors.white;
                              borderColor =
                              isSelected ? Colors.blue.shade400 : Colors.grey
                                  .shade300;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: hasAnswered ? null : () =>
                                      _submitAnswer(index, option),
                                  borderRadius: BorderRadius.circular(16),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: backgroundColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: borderColor!, width: 2),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: borderColor,
                                              width: 2,
                                            ),
                                            color: isSelected
                                                ? borderColor
                                                : Colors.transparent,
                                          ),
                                          child: isSelected
                                              ? Icon(
                                            Icons.check,
                                            size: 16,
                                            color: hasAnswered
                                                ? Colors.white
                                                : Colors.white,
                                          )
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            option,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                        if (hasAnswered && isCorrect &&
                                            !isSelected)
                                          Icon(
                                            Icons.lightbulb_outline,
                                            color: Colors.green.shade600,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Feedback section
                      if (hasAnswered) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isCorrect[index]!
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isCorrect[index]!
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isCorrect[index]! ? Icons.celebration : Icons
                                    .info_outline,
                                color: _isCorrect[index]!
                                    ? Colors.green.shade600
                                    : Colors.red.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _isCorrect[index]!
                                      ? "Excellent! You got it right!"
                                      : "Not quite. The correct answer is: $correctAnswer",
                                  style: TextStyle(
                                    color: _isCorrect[index]!
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          if (_currentQuestionIndex > 0) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousQuestion,
                icon: const Icon(Icons.arrow_back),
                label: const Text("Previous"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Next/Finish button
          Expanded(
            flex: _currentQuestionIndex == 0 ? 3 : 2,
            child: ElevatedButton.icon(
              onPressed: _answered[_currentQuestionIndex] == true
                  ? (_currentQuestionIndex < _questions.length - 1
                  ? _nextQuestion
                  : _showQuizResults)
                  : null,
              icon: Icon(_currentQuestionIndex < _questions.length - 1
                  ? Icons.arrow_forward
                  : Icons.flag),
              label: Text(_currentQuestionIndex < _questions.length - 1
                  ? "Next Question"
                  : "View Results"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
            ),
          ),

          // Generate more questions button
          if (_currentQuestionIndex == 0) ...[
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _resetQuiz();
                  _generateQuiz();
                },
                icon: const Icon(Icons.add),
                label: const Text("More"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsState() {
    final scoreColor = _scorePercentage >= 80
        ? Colors.green
        : _scorePercentage >= 60
        ? Colors.orange
        : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Results header
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [scoreColor.shade400, scoreColor.shade600]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scoreColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _scorePercentage >= 80
                      ? Icons.emoji_events
                      : _scorePercentage >= 60
                      ? Icons.thumb_up
                      : Icons.refresh,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  "${_scorePercentage.round()}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Results title
          Text(
            _getResultsTitle(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            _getResultsSubtitle(),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Results stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      "Correct",
                      "$_correctAnswers",
                      Colors.green.shade600,
                      Icons.check_circle,
                    ),
                    _buildStatItem(
                      "Total",
                      "${_questions.length}",
                      Colors.blue.shade600,
                      Icons.quiz,
                    ),
                    _buildStatItem(
                      "Score",
                      "${_scorePercentage.round()}%",
                      scoreColor.shade600,
                      Icons.percent,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Performance Breakdown",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _scorePercentage / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                scoreColor.shade400,
                                scoreColor.shade600
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetQuiz,
                  icon: const Icon(Icons.replay),
                  label: const Text("Retry Quiz"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _resetQuiz();
                    _generateQuiz();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("New Quiz"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
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

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home),
              label: const Text("Back to Courses"),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color,
      IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _getResultsTitle() {
    if (_scorePercentage >= 90) return "Outstanding!";
    if (_scorePercentage >= 80) return "Excellent Work!";
    if (_scorePercentage >= 70) return "Well Done!";
    if (_scorePercentage >= 60) return "Good Effort!";
    return "Keep Learning!";
  }

  String _getResultsSubtitle() {
    if (_scorePercentage >= 90) return "You've mastered this topic!";
    if (_scorePercentage >= 80) return "You have a strong understanding.";
    if (_scorePercentage >= 70) return "You're on the right track.";
    if (_scorePercentage >= 60) return "Room for improvement, but good start.";
    return "Consider reviewing the material again.";
  }
}