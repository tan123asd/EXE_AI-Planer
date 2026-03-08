import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/constants.dart';
import '../widgets/ai_coach_card.dart';
import '../widgets/stats_card.dart';
import '../widgets/timeline_item.dart';
import '../widgets/priority_task_card.dart';
import '../widgets/status_task_card.dart';
import '../widgets/progress_stats_card.dart';
import '../services/storage_service.dart';
import 'new_task_input_screen.dart';
import 'tasks_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final StorageService _storage = StorageService();
  late String _userName;
  DateTime _selectedDate = DateTime.now();
  
  // Current tasks to display
  List<Map<String, dynamic>> _todayTasks = [];
  int _totalFocusHours = 0;
  int _dayStreak = 7;
  int _completedTasksCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // Load user name
    _userName = _storage.getUserName();
    
    setState(() {
      // Load custom tasks from storage
      _todayTasks = _storage.getCustomTasks();
      
      // Calculate total focus hours
      _totalFocusHours = _todayTasks.fold(0, (sum, task) => sum + (task['estimatedTime'] as int? ?? 1));
      
      // Count completed tasks
      _completedTasksCount = _todayTasks.where((task) => 
        _storage.isTaskCompleted(task['id'] ?? '')
      ).length;
    });
  }

  void _handleTaskStatusChange(String taskId, TaskStatus newStatus) async {
    String statusString = 'pending';
    if (newStatus == TaskStatus.completed) {
      statusString = 'completed';
    } else if (newStatus == TaskStatus.inProgress) {
      statusString = 'inProgress';
    }
    
    await _storage.updateTaskStatus(taskId, statusString);
    _loadData();
  }

  TaskStatus _getTaskStatus(String taskId) {
    if (_storage.isTaskCompleted(taskId)) {
      return TaskStatus.completed;
    } else if (_storage.isTaskInProgress(taskId)) {
      return TaskStatus.inProgress;
    }
    return TaskStatus.pending;
  }

  void _refreshData() {
    _loadData();
  }

  String _formatTime(int estimatedHours) {
    // Simple time formatting
    final hour = 9 + (estimatedHours * 2);
    final formattedHour = hour > 12 ? hour - 12 : hour;
    return '$formattedHour:00 ${hour < 12 ? 'AM' : 'PM'}';
  }

  String _formatTimeRange(int estimatedHours) {
    final startHour = 9 + (_todayTasks.indexOf(_todayTasks.firstWhere((t) => t['estimatedTime'] == estimatedHours, orElse: () => {})) * 2);
    final endHour = startHour + estimatedHours;
    
    final startFormatted = startHour > 12 ? startHour - 12 : startHour;
    final endFormatted = endHour > 12 ? endHour - 12 : endHour;
    
    return '${startFormatted.toString().padLeft(2, '0')}:00 - ${endFormatted.toString().padLeft(2, '0')}:00';
  }

  Color _getTimelineColor(int index) {
    final colors = [
      AppColors.timelineBlue,
      AppColors.timelinePeach,
      AppColors.timelineGreen,
      AppColors.timelinePurple,
      AppColors.timelinePink,
    ];
    return colors[index % colors.length];
  }

  int _getGreetingTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 0;
    if (hour < 17) return 1;
    return 2;
  }

  String _getGreeting() {
    final greetings = ['Good Morning', 'Good Afternoon', 'Good Evening'];
    return greetings[_getGreetingTime()];
  }

  String _mapDifficultyToPriority(String difficulty) {
    switch (difficulty) {
      case 'Hard':
        return 'High';
      case 'Medium':
        return 'Medium';
      case 'Easy':
        return 'Low';
      default:
        return 'Medium';
    }
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Greeting
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // AI Coach Card - Dynamic message
            AICoachCard(
              message: _todayTasks.isEmpty
                  ? "Welcome! Add your first task to get started with AI-powered scheduling."
                  : _todayTasks.any((t) => t['difficulty'] == 'Hard')
                      ? "You're doing great! Let's focus on your ${_todayTasks.firstWhere((t) => t['difficulty'] == 'Hard')['name']} next. It's your hardest task today."
                      : "Great job! Focus on completing your tasks one by one. You've got this!",
            ),
            
            // Combined Progress & Stats Card
            if (_todayTasks.isNotEmpty)
              const SizedBox(height: AppSpacing.lg),
            if (_todayTasks.isNotEmpty)
              ProgressStatsCard(
                completedTasks: _completedTasksCount,
                totalTasks: _todayTasks.length,
                dayStreak: _dayStreak,
                focusHours: _totalFocusHours,
              ),
            const SizedBox(height: AppSpacing.xl),
            
            // Today's Schedule Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Schedule",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 2; // Navigate to calendar
                    });
                  },
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Task Cards - Dynamic from storage with status
            if (_todayTasks.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_task,
                      size: 48,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No tasks yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tap the + button to add your first task',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              for (int i = 0; i < _todayTasks.length && i < 5; i++) ...[
                StatusTaskCard(
                  taskId: _todayTasks[i]['id'] ?? '',
                  title: _todayTasks[i]['name'] ?? 'Untitled Task',
                  timeSlot: _formatTimeRange(_todayTasks[i]['estimatedTime'] as int? ?? 1),
                  duration: '${_todayTasks[i]['estimatedTime'] ?? 1}h',
                  difficulty: _todayTasks[i]['difficulty'] ?? 'Medium',
                  category: _todayTasks[i]['category'] ?? 'General',
                  status: _getTaskStatus(_todayTasks[i]['id'] ?? ''),
                  onStatusChanged: _handleTaskStatusChange,
                  onDelete: () async {
                    await _storage.deleteCustomTask(_todayTasks[i]['id'] ?? '');
                    _loadData();
                  },
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.xl),
            
            // Priority Tasks Header
            const Text(
              'Priority Tasks',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Priority Task Cards - Dynamic from storage
            if (_todayTasks.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Add tasks to see your priority list',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ] else ...[
              // Sort tasks by priority: Hard > Medium > Easy
              for (var task in [..._todayTasks]..sort((a, b) {
                final priorityOrder = {'Hard': 0, 'Medium': 1, 'Easy': 2};
                return (priorityOrder[a['difficulty']] ?? 3)
                    .compareTo(priorityOrder[b['difficulty']] ?? 3);
              })) ...[
                PriorityTaskCard(
                  title: task['name'] ?? 'Untitled Task',
                  subtitle: task['category'] ?? 'General',
                  bestSlot: _formatTimeRange(task['estimatedTime'] as int? ?? 1),
                  priority: _mapDifficultyToPriority(task['difficulty'] ?? 'Medium'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Starting ${task['name']}...')),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _currentIndex = index;
            });
          },
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 6), // Reduced space for dot
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 2), // Reduced spacing
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getDotPosition(double screenWidth) {
    // Manual calculation for accurate positioning with spaceAround
    // Layout: [Home] [Tasks] [FAB:48px] [Calendar] [Profile]
    final fabWidth = 48.0;
    final totalItemsWidth = screenWidth - fabWidth;
    final itemWidth = totalItemsWidth / 4;
    
    // Calculate center position for each item
    if (_currentIndex == 0) {
      // Home - first quarter
      return itemWidth * 0.5;
    } else if (_currentIndex == 1) {
      // Tasks - second quarter
      return itemWidth * 1.5;
    } else if (_currentIndex == 2) {
      // Calendar - third quarter (skip FAB space)
      return (itemWidth * 2) + fabWidth + (itemWidth * 0.5);
    } else {
      // Profile - fourth quarter
      return (itemWidth * 3) + fabWidth + (itemWidth * 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeContent(),
      const TasksScreen(),
      const CalendarScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: screens[_currentIndex],
      ),
      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primaryDark,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              // Navigate with slide up animation
              await Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const NewTaskInputScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0); // Start from bottom
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;
                    
                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              );
              // Refresh data when coming back
              _loadData();
            },
            customBorder: const CircleBorder(),
            child: const Center(
              child: Icon(
                Icons.add,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomAppBar(
          color: AppColors.cardBackground,
          elevation: 0,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          child: SizedBox(
            height: 60,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Navigation items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(Icons.home_rounded, 'Home', 0),
                        _buildNavItem(Icons.task_alt, 'Tasks', 1),
                        const SizedBox(width: 48), // Space for FAB
                        _buildNavItem(Icons.calendar_month, 'Calendar', 2),
                        _buildNavItem(Icons.person, 'Profile', 3),
                      ],
                    ),
                    // Animated dot indicator
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      left: _getDotPosition(constraints.maxWidth) - 2.5,
                      top: 0,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
