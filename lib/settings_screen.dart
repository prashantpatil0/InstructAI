import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  int _selectedFeatureIndex = 0;
  bool _showEasterEgg = false;
  int _logoTapCount = 0;

  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.route,
      'title': 'AI-Generated Roadmaps',
      'description': 'Personalized learning paths tailored to your goals',
      'color': Colors.deepPurple,
    },
    {
      'icon': Icons.psychology,
      'title': 'Real-time AI Streaming',
      'description': 'Interactive lessons with live AI responses',
      'color': Colors.indigo,
    },
    {
      'icon': Icons.offline_bolt,
      'title': 'Offline Learning',
      'description': 'Learn anywhere with Gemma-powered offline AI',
      'color': Colors.blue,
    },
    {
      'icon': Icons.bookmark,
      'title': 'Progress Tracking',
      'description': 'Save and resume your learning journey',
      'color': Colors.teal,
    },
  ];

  final List<Map<String, String>> _techStack = [
    {'name': 'Flutter', 'description': 'Cross-platform UI framework'},
    {'name': 'Dart', 'description': 'Programming language'},
    {'name': 'Gemma 3n', 'description': 'On-device AI model'},
    {'name': 'MediaPipe Tasks', 'description': 'AI inference engine'},
    {'name': 'Hive DB', 'description': 'Local data storage'},
  ];

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_rotationController);
    _rotationController.repeat();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _slideController.forward();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      launchUrl(uri);
    }
  }

  void _onLogoTap() {
    setState(() {
      _logoTapCount++;
      if (_logoTapCount >= 7) {
        _showEasterEgg = true;
        _logoTapCount = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 400;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey.shade50,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Clean App Bar
              SliverAppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                floating: true,
                title: Text(
                  'About InstructAI',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
                iconTheme: IconThemeData(color: Colors.grey[800]),
              ),

              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      SizedBox(height: screenHeight * 0.02),

                      // Animated Logo Section
                      _buildAnimatedLogo(isSmallScreen),

                      SizedBox(height: screenHeight * 0.04),

                      // App Title
                      _buildAppTitle(),

                      SizedBox(height: screenHeight * 0.04),

                      // Features Section
                      _buildFeaturesSection(screenWidth, isSmallScreen, isMediumScreen),

                      SizedBox(height: screenHeight * 0.04),

                      // Mission Statement
                      _buildMissionSection(screenWidth),

                      SizedBox(height: screenHeight * 0.04),

                      // Tech Stack
                      _buildTechStackSection(screenWidth),

                      SizedBox(height: screenHeight * 0.04),

                      // Developer Info
                      _buildDeveloperSection(screenWidth),

                      SizedBox(height: screenHeight * 0.04),

                      // Version and Stats
                      _buildStatsSection(screenWidth),

                      SizedBox(height: screenHeight * 0.03),
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

  Widget _buildAnimatedLogo(bool isSmallScreen) {
    final logoSize = isSmallScreen ? 100.0 : 140.0;
    final iconSize = isSmallScreen ? 35.0 : 50.0;

    return GestureDetector(
      onTap: _onLogoTap,
      child: Container(
        width: logoSize,
        height: logoSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Rotating gradient border
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Container(
                    width: logoSize - 20,
                    height: logoSize - 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.deepPurple.withOpacity(0.3),
                          Colors.indigo.withOpacity(0.3),
                          Colors.blue.withOpacity(0.3),
                          Colors.deepPurple.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // Pulsing logo
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: logoSize - 40,
                    height: logoSize - 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.psychology,
                      size: iconSize,
                      color: Colors.deepPurple.shade600,
                    ),
                  ),
                );
              },
            ),
            // Easter egg sparkles
            if (_showEasterEgg)
              ...List.generate(8, (index) {
                final radius = (logoSize - 40) / 2 + 20;
                return Positioned(
                  left: logoSize/2 + radius * math.cos(index * math.pi / 4) - 8,
                  top: logoSize/2 + radius * math.sin(index * math.pi / 4) - 8,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Icon(
                          Icons.auto_awesome,
                          color: Colors.amber.shade400,
                          size: 16,
                        ),
                      );
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return Column(
      children: [
        Text(
          'InstructAI',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your offline AI tutor — powered by Gemma',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeaturesSection(double screenWidth, bool isSmallScreen, bool isMediumScreen) {
    double cardHeight = isSmallScreen ? 180 : isMediumScreen ? 200 : 220;
    double horizontalPadding = isSmallScreen ? 12 : 16;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: horizontalPadding, bottom: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.deepPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Features',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 22 : 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: cardHeight,
            child: PageView.builder(
              onPageChanged: (index) {
                setState(() {
                  _selectedFeatureIndex = index;
                });
              },
              itemCount: _features.length,
              itemBuilder: (context, index) {
                final feature = _features[index];
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 4 : 8),
                  child: Material(
                    elevation: 8,
                    shadowColor: feature['color'].withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: feature['color'].withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            decoration: BoxDecoration(
                              color: feature['color'].withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              feature['icon'],
                              size: isSmallScreen ? 28 : 32,
                              color: feature['color'],
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          Text(
                            feature['title'],
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Flexible(
                            child: Text(
                              feature['description'],
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : 14,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _features.length,
                  (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _selectedFeatureIndex == index ? 12 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _selectedFeatureIndex == index
                      ? Colors.deepPurple
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionSection(double screenWidth) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                        Icons.rocket_launch,
                        color: Colors.blue,
                        size: 24
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Our Mission',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'To make high-quality, personalized learning accessible — even offline — using on-device AI technology that empowers learners everywhere.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTechStackSection(double screenWidth) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.construction,
                    color: Colors.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Tech Stack',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(_techStack.length, (index) {
            final tech = _techStack[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${tech['name']}: ${tech['description']}'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.grey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.teal, Colors.teal.shade300],
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tech['name']!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tech['description']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.touch_app,
                          color: Colors.grey[400],
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDeveloperSection(double screenWidth) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade400, Colors.indigo.shade500],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 35,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Developed by',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Prashant Patil',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 20),
              Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(25),
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Email-ID: patilprashant9307@gmail.com'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.grey[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.email_outlined,
                          color: Colors.deepPurple,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Get in Touch',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  Widget _buildStatsSection(double screenWidth) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Version', 'v1.0.0', Icons.verified, Colors.green),
              Container(
                width: 1,
                height: 50,
                color: Colors.grey.withOpacity(0.3),
              ),
              _buildStatItem('Model', 'Gemma 3n', Icons.smart_toy, Colors.orange),
              Container(
                width: 1,
                height: 50,
                color: Colors.grey.withOpacity(0.3),
              ),
              _buildStatItem('Platform', 'Flutter', Icons.flutter_dash, Colors.blue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Flexible(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}