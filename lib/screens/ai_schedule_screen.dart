import 'package:flutter/material.dart';
import '../models/schedule_item.dart';
import '../utils/constants.dart';
import '../widgets/schedule_card.dart';
import '../services/storage_service.dart';

class AIScheduleScreen extends StatefulWidget {
  final Map<String, dynamic>? taskData;
  
  const AIScheduleScreen({Key? key, this.taskData}) : super(key: key);

  @override
  State<AIScheduleScreen> createState() => _AIScheduleScreenState();
}

class _AIScheduleScreenState extends State<AIScheduleScreen> {
  final StorageService _storage = StorageService();
  List<ScheduleItem> _scheduleItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Load saved schedule from storage
    final savedSchedule = await _storage.getGeneratedSchedule();
    
    if (savedSchedule.isNotEmpty) {
      // Convert saved data to ScheduleItem objects
      _scheduleItems = savedSchedule.map((item) {
        return ScheduleItem(
          id: item['id'] ?? DateTime.now().toString(),
          day: item['day'] ?? 'Unknown',
          time: item['time'] ?? '00:00',
          title: item['title'] ?? 'Untitled',
          subject: item['subject'] ?? 'General',
          difficulty: item['difficulty'] ?? 'Medium',
        );
      }).toList();
    } else {
      // Default schedule if nothing saved
      _scheduleItems = [
        ScheduleItem(
          id: '1',
          day: 'Monday',
          time: '08:00 - 09:30',
          title: 'Study Math',
          subject: 'Calculus',
          difficulty: 'Hard',
        ),
        ScheduleItem(
          id: '2',
          day: 'Monday',
          time: '14:00 - 15:00',
          title: 'Gym',
          subject: 'Personal Development',
          difficulty: 'Easy',
        ),
        ScheduleItem(
          id: '3',
          day: 'Monday',
          time: '20:00 - 21:00',
          title: 'Data Structures',
          subject: 'Computer Science',
          difficulty: 'Medium',
        ),
        ScheduleItem(
          id: '4',
          day: 'Tuesday',
          time: '09:00 - 10:30',
          title: 'Physics Lab',
          subject: 'Physics',
          difficulty: 'Medium',
        ),
        ScheduleItem(
          id: '5',
          day: 'Tuesday',
          time: '16:00 - 17:00',
          title: 'Reading Time',
          subject: 'Personal Development',
          difficulty: 'Easy',
        ),
        ScheduleItem(
          id: '6',
          day: 'Wednesday',
          time: '08:00 - 09:30',
          title: 'Chemistry Assignment',
          subject: 'Chemistry',
          difficulty: 'Hard',
        ),
        ScheduleItem(
          id: '7',
          day: 'Wednesday',
          time: '15:00 - 16:00',
          title: 'Meditation',
          subject: 'Personal Development',
          difficulty: 'Easy',
        ),
      ];
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheduleItems = _scheduleItems;

    // Group schedule items by day
    final Map<String, List<ScheduleItem>> groupedSchedule = {};
    for (var item in scheduleItems) {
      if (!groupedSchedule.containsKey(item.day)) {
        groupedSchedule[item.day] = [];
      }
      groupedSchedule[item.day]!.add(item);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'AI Generated Schedule',
          style: AppTextStyles.heading2,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Your personalized schedule has been generated based on your tasks and preferences.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                
                // Schedule by Day
                ...groupedSchedule.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              entry.key,
                              style: AppTextStyles.heading2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...entry.value.map((item) => ScheduleCard(scheduleItem: item)),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  );
                }).toList(),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Schedule refreshed!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(
                            color: AppColors.textSecondary,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        ),
                        child: const Text('Regenerate'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Convert schedule items to Map for storage
                          final scheduleData = scheduleItems.map((item) => {
                            'id': item.id,
                            'day': item.day,
                            'time': item.time,
                            'title': item.title,
                            'subject': item.subject,
                            'difficulty': item.difficulty,
                          }).toList();
                          
                          // Save schedule
                          await _storage.saveGeneratedSchedule(scheduleData);
                          
                          // Save task data if provided
                          if (widget.taskData != null) {
                            await _storage.addCustomTask(widget.taskData!);
                          }
                          
                          // Show success message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Schedule and task saved successfully!'),
                              backgroundColor: AppColors.success,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          
                          // Navigate back to home
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          elevation: 0,
                        ),
                        child: const Text('Save Schedule'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
