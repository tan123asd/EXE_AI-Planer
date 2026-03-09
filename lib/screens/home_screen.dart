import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/constants.dart';
import '../widgets/ai_coach_card.dart';
import '../widgets/stats_card.dart';
import '../widgets/timeline_item.dart';
import '../widgets/priority_task_card.dart';
import '../widgets/status_task_card.dart';
import '../widgets/progress_stats_card.dart';
import '../widgets/performance_tracking_card.dart';
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
      final allTasks = _storage.getCustomTasks();
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      
      // 🆕 Filter tasks for today
      _todayTasks = allTasks.where((task) {
        // Schedules: check if today's weekday is in the weekdays list
        if (task['taskType'] == 'Schedules') {
          final weekdays = task['weekdays'];
          if (weekdays != null && weekdays is List) {
            return weekdays.contains(today.weekday);
          }
          return false;
        }
        
        // Task: check if has session today OR deadline is today
        if (task['taskType'] == 'Task') {
          // Check sessions first
          final sessions = task['sessions'];
          if (sessions != null && sessions is List) {
            // Has sessions - check if any session is today
            return sessions.any((session) {
              try {
                final sessionStart = DateTime.parse(session['startTime']);
                final sessionDate = DateTime(sessionStart.year, sessionStart.month, sessionStart.day);
                return sessionDate.isAtSameMomentAs(todayDate);
              } catch (e) {
                return false;
              }
            });
          }
          
          // No sessions - check deadline
          final deadline = task['deadline'];
          if (deadline != null) {
            try {
              final deadlineDate = DateTime.parse(deadline);
              final deadlineDateOnly = DateTime(deadlineDate.year, deadlineDate.month, deadlineDate.day);
              return deadlineDateOnly.isAtSameMomentAs(todayDate);
            } catch (e) {
              return false;
            }
          }
        }
        
        return false;
      }).toList();
      
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

  // 🔧 FIXED: Format time range from actual deadline or schedule times
  String _formatTimeRange(Map<String, dynamic> task) {
    // 🔧 For Schedules type - use fixed start/end time
    if (task['taskType'] == 'Schedules') {
      final startTime = task['startTime'];
      final endTime = task['endTime'];
      
      if (startTime != null && endTime != null) {
        // 🆕 Parse "HH:MM" strings and format to AM/PM
        return '${_formatTimeStringToAMPM(startTime)} - ${_formatTimeStringToAMPM(endTime)}';
      }
    }
    
    // 🔧 For Task type - check sessions first, then deadline
    if (task['taskType'] == 'Task') {
      final sessions = task['sessions'];
      
      // 🆕 If task has sessions, find today's session
      if (sessions != null && sessions is List && sessions.isNotEmpty) {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        
        // Find session for today
        for (var session in sessions) {
          try {
            final sessionStart = DateTime.parse(session['startTime']);
            final sessionEnd = DateTime.parse(session['endTime']);
            final sessionDate = DateTime(sessionStart.year, sessionStart.month, sessionStart.day);
            
            if (sessionDate.isAtSameMomentAs(todayDate)) {
              return '${_formatTimeWithAMPM(sessionStart)} - ${_formatTimeWithAMPM(sessionEnd)}';
            }
          } catch (e) {
            // Continue to next session
          }
        }
      }
      
      // 🔧 Fallback: use deadline if no sessions
      final estimatedHours = task['estimatedTime'] as int? ?? 1;
      final durationMinutes = estimatedHours * 60;
      
      // Try to get actual deadline with time
      DateTime? taskStartTime;
      if (task['deadline'] != null) {
        try {
          taskStartTime = DateTime.parse(task['deadline']);
        } catch (e) {
          taskStartTime = null;
        }
      }
      
      // If task has specific time (not midnight), use it
      if (taskStartTime != null && (taskStartTime.hour != 0 || taskStartTime.minute != 0)) {
        final endTime = taskStartTime.add(Duration(minutes: durationMinutes));
        return '${_formatTimeWithAMPM(taskStartTime)} - ${_formatTimeWithAMPM(endTime)}';
      }
      
      // Otherwise, use default scheduling (9 AM start + index offset)
      final taskIndex = _todayTasks.indexOf(task);
      final startHour = 9 + (taskIndex * 2);
      final endHour = startHour + estimatedHours;
      
      final startTime = DateTime(2026, 1, 1, startHour, 0);
      final endTime = DateTime(2026, 1, 1, endHour, 0);
      
      return '${_formatTimeWithAMPM(startTime)} - ${_formatTimeWithAMPM(endTime)}';
    }
    
    // Default fallback
    return '9:00 AM - 10:00 AM';
  }
  
  // 🆕 Helper to format time with AM/PM
  String _formatTimeWithAMPM(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    
    if (hour == 0) {
      return '12:${minute.toString().padLeft(2, '0')} AM';
    } else if (hour < 12) {
      return '$hour:${minute.toString().padLeft(2, '0')} AM';
    } else if (hour == 12) {
      return '12:${minute.toString().padLeft(2, '0')} PM';
    } else {
      return '${hour - 12}:${minute.toString().padLeft(2, '0')} PM';
    }
  }
  
  // 🆕 Helper to parse "HH:MM" string and format to AM/PM
  String _formatTimeStringToAMPM(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length != 2) return timeString;
      
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      // Create dummy DateTime to use existing formatter
      final dummyDate = DateTime(2026, 1, 1, hour, minute);
      return _formatTimeWithAMPM(dummyDate);
    } catch (e) {
      return timeString; // Return original if parsing fails
    }
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

  // 🆕 Format weekdays for display
  String _formatWeekdays(dynamic weekdays) {
    if (weekdays == null) return 'Not set';
    
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    List<int> daysList = [];
    
    if (weekdays is List) {
      daysList = weekdays.cast<int>();
    }
    
    if (daysList.isEmpty) return 'Not set';
    
    daysList.sort();
    return daysList.map((d) => days[d - 1]).join(', ');
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
            
            // Performance Tracking Card - Temporarily hidden
            // const SizedBox(height: AppSpacing.lg),
            // const PerformanceTrackingCard(),
            
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
                  timeSlot: _formatTimeRange(_todayTasks[i]), // 🔧 Pass full task object
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
            
            // Recurring Schedules Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.15),
                        AppColors.primary.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.event_repeat_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recurring Schedules',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your weekly routines',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary.withOpacity(0.7),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Recurring Schedule Cards - Filter by taskType == 'Schedules'
            if (_todayTasks.where((task) => task['taskType'] == 'Schedules').isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.03),
                      AppColors.primary.withOpacity(0.01),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No recurring schedules',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add schedules that repeat weekly',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Show recurring schedules
              for (var task in _todayTasks.where((t) => t['taskType'] == 'Schedules')) ...[
                PriorityTaskCard(
                  title: task['name'] ?? 'Untitled Schedule',
                  subtitle: _formatWeekdays(task['weekdays']),
                  bestSlot: _formatTimeRange(task),
                  priority: 'Schedule', // Changed from difficulty
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Starting ${task['name']}...')),
                    );
                  },
                ),
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
