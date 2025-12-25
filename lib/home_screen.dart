import 'package:flutter/material.dart';
import 'package:instructai/recommended_course_detail_screen.dart';
import 'course_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late List<String> categories;
  String selectedCategory = "All";
  late AnimationController _animationController;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  bool isGridView = false;
  bool showSearch = false;

  @override
  void initState() {
    super.initState();
    categories = [
      "All",
      ...{...recommendedCourses.map((c) => c['category'] as String)}
    ];
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get filteredCourses {
    var courses = selectedCategory == "All"
        ? recommendedCourses
        : recommendedCourses
        .where((course) => course['category'] == selectedCategory)
        .toList();

    if (searchQuery.isNotEmpty) {
      courses = courses.where((course) {
        return course['title'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
            course['description'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
            (course['skills'] as List).any((skill) =>
                skill.toString().toLowerCase().contains(searchQuery.toLowerCase()));
      }).toList();
    }

    return courses;
  }

  @override
  Widget build(BuildContext context) {
    final courses = filteredCourses;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildCleanAppBar(),
      body: Column(
        children: [
          _buildSearchSection(),
          _buildCategorySection(),
          _buildHeaderSection(courses.length),
          Expanded(child: _buildCoursesSection(courses)),
        ],
      ),
      floatingActionButton: _buildViewToggleFAB(),
    );
  }

  PreferredSizeWidget _buildCleanAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade400, Colors.blue.shade400],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "InstructAI Courses",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                "AI-Powered Learning Platform",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: showSearch ? Colors.deepPurple.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                showSearch ? Icons.close : Icons.search,
                key: ValueKey(showSearch),
                color: showSearch ? Colors.deepPurple : Colors.grey.shade700,
              ),
            ),
            onPressed: () {
              setState(() {
                showSearch = !showSearch;
                if (!showSearch) {
                  searchController.clear();
                  searchQuery = "";
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: showSearch ? 80 : 0,
      child: showSearch
          ? Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: TextField(
          controller: searchController,
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: "Search courses, skills, or topics...",
            hintStyle: TextStyle(color: Colors.grey.shade500),
            prefixIcon: Icon(Icons.search, color: Colors.deepPurple.shade400),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                searchController.clear();
                setState(() {
                  searchQuery = "";
                });
              },
            )
                : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.deepPurple.shade400, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildCategorySection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Browse Categories",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = selectedCategory == cat;

                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          selectedCategory = cat;
                        });
                      },
                      borderRadius: BorderRadius.circular(25),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.deepPurple.shade500 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: isSelected ? Colors.deepPurple.shade500 : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ] : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check_circle, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                            ] else ...[
                              Icon(
                                _getCategoryIcon(cat),
                                color: Colors.grey.shade600,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              cat,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
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
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all': return Icons.apps;
      case 'programming': return Icons.code;
      case 'design': return Icons.palette;
      case 'business': return Icons.business;
      case 'marketing': return Icons.campaign;
      case 'data science': return Icons.analytics;
      default: return Icons.category;
    }
  }

  Widget _buildHeaderSection(int courseCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$courseCount ${courseCount == 1 ? 'Course' : 'Courses'} Available",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  selectedCategory == "All"
                      ? "Explore all learning paths"
                      : "in $selectedCategory category",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
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
                const Icon(Icons.trending_up, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  "${recommendedCourses.length} Total",
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
      ),
    );
  }

  Widget _buildCoursesSection(List<Map<String, dynamic>> courses) {
    if (courses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "No courses found",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try adjusting your search terms or category filters",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          if (isGridView) {
            return GridView.builder(
              itemCount: courses.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 350,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (context, index) {
                final course = courses[index];
                final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(
                      (index * 0.1).clamp(0.0, 1.0),
                      1.0,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                );

                return Transform.scale(
                  scale: animation.value,
                  child: _buildGridCourseCard(
                    context,
                    course["title"],
                    course["description"],
                    List<String>.from(course["skills"]),
                    course["outcomes"],
                    index,
                  ),
                );
              },
            );
          } else {
            return ListView.builder(
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(
                      (index * 0.1).clamp(0.0, 1.0),
                      1.0,
                      curve: Curves.easeOut,
                    ),
                  ),
                );

                return Transform.scale(
                  scale: animation.value,
                  child: _buildListCourseCard(
                    context,
                    course["title"],
                    course["description"],
                    List<String>.from(course["skills"]),
                    course["outcomes"],
                    index,
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildGridCourseCard(
      BuildContext context,
      String title,
      String description,
      List<String> skills,
      String outcomes,
      int index,
      ) {
    final colors = [
      [Colors.blue.shade400, Colors.blue.shade600],
      [Colors.purple.shade400, Colors.purple.shade600],
      [Colors.orange.shade400, Colors.orange.shade600],
      [Colors.teal.shade400, Colors.teal.shade600],
      [Colors.pink.shade400, Colors.pink.shade600],
      [Colors.indigo.shade400, Colors.indigo.shade600],
    ];

    final colorPair = colors[index % colors.length];

    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecommendedCourseDetailScreen(
                title: title,
                description: description,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: colorPair[0].withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colorPair,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "AI Course",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        "${skills.length} Skills • Interactive",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // Description
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 12),

                      // Skills section
                      Row(
                        children: [
                          Icon(Icons.verified, size: 12, color: colorPair[1]),
                          const SizedBox(width: 4),
                          Text(
                            "Skills:",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorPair[1],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Skills chips
                      Wrap(
                        spacing: 4,
                        runSpacing: 3,
                        children: skills.take(3).map((skill) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorPair[0].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorPair[0].withOpacity(0.3)),
                          ),
                          child: Text(
                            skill,
                            style: TextStyle(
                              fontSize: 9,
                              color: colorPair[1],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )).toList(),
                      ),

                      if (skills.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "+${skills.length - 3} more",
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),

                      const Spacer(),

                      // Course outcome preview
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.emoji_events, size: 14, color: Colors.amber.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                outcomes,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action button
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecommendedCourseDetailScreen(
                                  title: title,
                                  description: description,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.map, size: 14),
                          label: const Text("View Roadmap", style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorPair[1],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
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

  Widget _buildListCourseCard(
      BuildContext context,
      String title,
      String description,
      List<String> skills,
      String outcomes,
      int index,
      ) {
    final colors = [
      [Colors.blue.shade400, Colors.blue.shade600],
      [Colors.purple.shade400, Colors.purple.shade600],
      [Colors.orange.shade400, Colors.orange.shade600],
      [Colors.teal.shade400, Colors.teal.shade600],
      [Colors.pink.shade400, Colors.pink.shade600],
      [Colors.indigo.shade400, Colors.indigo.shade600],
    ];

    final colorPair = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecommendedCourseDetailScreen(
                  title: title,
                  description: description,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Course icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colorPair),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                ),

                const SizedBox(width: 16),

                // Course info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorPair[0].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${skills.length} Skills",
                              style: TextStyle(
                                fontSize: 10,
                                color: colorPair[1],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.verified, size: 12, color: Colors.green.shade600),
                          const SizedBox(width: 2),
                          Text(
                            "AI Generated",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorPair[0].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: colorPair[1],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggleFAB() {
    return FloatingActionButton(
      onPressed: () {
        setState(() {
          isGridView = !isGridView;
        });
      },
      backgroundColor: Colors.deepPurple,
      elevation: 4,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(
          isGridView ? Icons.view_list : Icons.grid_view,
          key: ValueKey(isGridView),
          color: Colors.white,
        ),
      ),
    );
  }
}