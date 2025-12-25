import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'custom_course_detail_screen.dart';

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen>
    with TickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  late AnimationController _heroAnimationController;
  late AnimationController _floatingAnimationController;
  late Animation<double> _heroAnimation;
  late Animation<double> _floatingAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isTitleFocused = false;
  bool _isDescriptionFocused = false;
  int _selectedTopicIndex = -1;

  final List<String> _suggestedTopics = [
    "Flutter Development",
    "Machine Learning",
    "Web Development",
    "Data Science",
    "Mobile App Design",
    "AI & Deep Learning",
    "Cloud Computing",
    "Cybersecurity",
  ];

  @override
  void initState() {
    super.initState();

    _heroAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _floatingAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _heroAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _heroAnimationController,
      curve: Curves.elasticOut,
    ));

    _floatingAnimation = Tween<double>(
      begin: -10.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _floatingAnimationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _titleFocusNode.addListener(() {
      setState(() {
        _isTitleFocused = _titleFocusNode.hasFocus;
      });
    });

    _descriptionFocusNode.addListener(() {
      setState(() {
        _isDescriptionFocused = _descriptionFocusNode.hasFocus;
      });
    });

    _heroAnimationController.forward();
  }

  @override
  void dispose() {
    _heroAnimationController.dispose();
    _floatingAnimationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  void _onSuggestedTopicTap(String topic) {
    setState(() {
      _selectedTopicIndex = _suggestedTopics.indexOf(topic);
    });
    _titleController.text = topic;
    HapticFeedback.lightImpact();

    // Add a small animation feedback
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _selectedTopicIndex = -1;
        });
      }
    });
  }

  void _clearTitle() {
    _titleController.clear();
    HapticFeedback.lightImpact();
  }

  void _clearDescription() {
    _descriptionController.clear();
    HapticFeedback.lightImpact();
  }

  void _onGeneratePressed() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? "Creating a custom course roadmap to help you learn $title from basics to advanced concepts."
        : _descriptionController.text.trim();

    if (title.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade300),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Please enter a course topic to get started!",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      _titleFocusNode.requestFocus();
      return;
    }

    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CustomCourseDetailScreen(
              title: title,
              description: description,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildHeroSection()),
          SliverToBoxAdapter(child: _buildSuggestedTopics()),
          SliverToBoxAdapter(child: _buildInputSection()),
          SliverToBoxAdapter(child: _buildFeatures()),
          //SliverToBoxAdapter(child: _buildFooter()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
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
            child: const Icon(Icons.create, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          const Text(
            "Create Course",
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
    );
  }

  Widget _buildHeroSection() {
    return AnimatedBuilder(
      animation: _heroAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _heroAnimation,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.shade600,
                    Colors.blue.shade500,
                    Colors.purple.shade400,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _floatingAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatingAnimation.value),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Ready to learn your way?",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Give us a topic and we'll build a personalized roadmap & course tailored just for you using AI.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestedTopics() {
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
                    colors: [Colors.orange.shade400, Colors.pink.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "Popular Topics",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestedTopics.length,
              itemBuilder: (context, index) {
                final topic = _suggestedTopics[index];
                final isSelected = _selectedTopicIndex == index;

                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onSuggestedTopicTap(topic),
                      borderRadius: BorderRadius.circular(25),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                            colors: [Colors.deepPurple.shade400, Colors.blue.shade400],
                          )
                              : null,
                          color: isSelected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.grey.shade300,
                          ),
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                              : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          topic,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
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

  Widget _buildInputSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.teal.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_note, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "Course Details",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildTitleField(),
                const SizedBox(height: 20),
                _buildDescriptionField(),
                const SizedBox(height: 32),
                _buildGenerateButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isTitleFocused
              ? Colors.deepPurple.shade400
              : Colors.grey.shade300,
          width: _isTitleFocused ? 2 : 1,
        ),
        boxShadow: _isTitleFocused
            ? [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        decoration: InputDecoration(
          labelText: "Course Topic",
          hintText: "e.g., AI with Flutter, Machine Learning Basics",
          prefixIcon: Icon(
            Icons.lightbulb_outline,
            color: _isTitleFocused
                ? Colors.deepPurple.shade400
                : Colors.grey.shade500,
          ),
          suffixIcon: _titleController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: _clearTitle,
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(
            color: _isTitleFocused
                ? Colors.deepPurple.shade400
                : Colors.grey.shade600,
          ),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDescriptionFocused
              ? Colors.deepPurple.shade400
              : Colors.grey.shade300,
          width: _isDescriptionFocused ? 2 : 1,
        ),
        boxShadow: _isDescriptionFocused
            ? [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: TextField(
        controller: _descriptionController,
        focusNode: _descriptionFocusNode,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: "Course Description (Optional)",
          hintText: "What specific aspects do you want to focus on?",
          prefixIcon: Icon(
            Icons.notes,
            color: _isDescriptionFocused
                ? Colors.deepPurple.shade400
                : Colors.grey.shade500,
          ),
          suffixIcon: _descriptionController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: _clearDescription,
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(
            color: _isDescriptionFocused
                ? Colors.deepPurple.shade400
                : Colors.grey.shade600,
          ),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildGenerateButton() {
    final hasContent = _titleController.text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasContent
              ? [Colors.deepPurple.shade400, Colors.blue.shade400]
              : [Colors.grey.shade300, Colors.grey.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: hasContent
            ? [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasContent ? _onGeneratePressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_fix_high,
                  color: hasContent ? Colors.white : Colors.grey.shade500,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  "Generate Course Roadmap",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: hasContent ? Colors.white : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatures() {
    final features = [
      {
        'icon': Icons.auto_awesome,
        'title': 'AI-Powered',
        'description': 'Smart roadmap generation using advanced AI',
        'colors': [Colors.purple.shade400, Colors.pink.shade400],
      },
      {
        'icon': Icons.speed,
        'title': 'Instant Results',
        'description': 'Get your personalized roadmap in seconds',
        'colors': [Colors.blue.shade400, Colors.cyan.shade400],
      },
      {
        'icon': Icons.school,
        'title': 'Structured Learning',
        'description': 'Progressive modules from beginner to advanced',
        'colors': [Colors.green.shade400, Colors.teal.shade400],
      },
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade400, Colors.purple.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "Why Choose AI Course Creator?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: feature['colors'] as List<Color>,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    feature['icon'] as IconData,
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
                        feature['title'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feature['description'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }


}