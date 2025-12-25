import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:instructai/course_model.dart';
import 'package:instructai/course_detail_screen.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen>
    with TickerProviderStateMixin {
  Box<CourseModel>? courseBox;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  late AnimationController _fadeAnimationController;
  late AnimationController _staggerAnimationController;
  late Animation<double> _fadeAnimation;

  final List<String> _filterOptions = ['All', 'Recommended', 'Custom', 'Recent'];

  @override
  void initState() {
    super.initState();
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _staggerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    _loadCourses();
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _staggerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    courseBox = await Hive.openBox<CourseModel>('courses');
    setState(() {});
    _fadeAnimationController.forward();
    _staggerAnimationController.forward();
  }

  List<CourseModel> _getFilteredCourses() {
    if (courseBox == null) return [];

    var courses = courseBox!.values.where((c) => c.isStarted == true).toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      courses = courses.where((course) =>
      course.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          course.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // Apply category filter
    switch (_selectedFilter) {
      case 'Recommended':
        courses = courses.where((c) => c.isRecommended).toList();
        break;
      case 'Custom':
        courses = courses.where((c) => !c.isRecommended).toList();
        break;
      case 'Recent':
        courses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        courses = courses.take(5).toList();
        break;
    }

    return courses;
  }

  void _onCourseCardTap(CourseModel course, int index) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CourseDetailScreen(course: course),
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

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    if (courseBox == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade100, Colors.blue.shade100],
                  ),
                  shape: BoxShape.circle,
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple.shade600),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Loading your courses...",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filteredCourses = _getFilteredCourses();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildSearchAndFilters()),
          SliverToBoxAdapter(child: _buildStatsCard(filteredCourses.length)),
          filteredCourses.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState())
              : _buildSliverList(filteredCourses),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade400, Colors.blue.shade400],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            "Your Courses",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
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
                Colors.blue.shade50,
                Colors.white,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: "Search courses...",
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Filter Chips
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final filter = _filterOptions[index];
                final isSelected = _selectedFilter == filter;

                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onFilterChanged(filter),
                      borderRadius: BorderRadius.circular(19),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                            colors: [Colors.deepPurple.shade400, Colors.blue.shade400],
                          )
                              : null,
                          color: isSelected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.grey.shade300,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? Colors.deepPurple.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.05),
                              blurRadius: isSelected ? 8 : 6,
                              offset: Offset(0, isSelected ? 4 : 2),
                            ),
                          ],
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
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

  Widget _buildStatsCard(int courseCount) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade500,
              Colors.blue.shade500,
              Colors.purple.shade500,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.trending_up,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$courseCount Active Course${courseCount != 1 ? 's' : ''}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    courseCount > 0
                        ? "Keep it up!"
                        : "Start learning",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _selectedFilter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey.shade300, Colors.grey.shade200],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school_outlined,
                  size: 56,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _searchQuery.isNotEmpty
                    ? "No courses match your search"
                    : "No courses started yet",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _searchQuery.isNotEmpty
                    ? "Try adjusting your search or filters"
                    : "Start exploring courses from the Explore tab\nor create your own custom course!",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _searchQuery = ''),
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text("Clear Search"),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.deepPurple.shade500,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverList(List<CourseModel> courses) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          return _buildCourseListItem(courses[index], index);
        },
        childCount: courses.length,
      ),
    );
  }

  Widget _buildCourseListItem(CourseModel course, int index) {
    return AnimatedBuilder(
      animation: _staggerAnimationController,
      builder: (context, child) {
        final animationDelay = index * 0.1;
        final adjustedAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _staggerAnimationController,
          curve: Interval(
            animationDelay,
            1.0,
            curve: Curves.easeOutCubic,
          ),
        ));

        return FadeTransition(
          opacity: adjustedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(adjustedAnimation),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onCourseCardTap(course, index),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: course.isRecommended
                                  ? [Colors.green.shade500, Colors.teal.shade500]
                                  : [Colors.purple.shade500, Colors.pink.shade500],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: course.isRecommended
                                    ? Colors.green.withOpacity(0.25)
                                    : Colors.purple.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            course.isRecommended
                                ? Icons.auto_awesome
                                : Icons.create,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: course.isRecommended
                                            ? Colors.green.shade100
                                            : Colors.purple.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        course.isRecommended ? "AI" : "Custom",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: course.isRecommended
                                              ? Colors.green.shade700
                                              : Colors.purple.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.library_books,
                                      size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${course.modules.length}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey.shade600,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}