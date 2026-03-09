import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/constants.dart';
import '../services/storage_service.dart';

class BreakReminderWidget extends StatefulWidget {
  final String taskId;
  final String taskName;
  final int workDuration; // in minutes
  final int breakDuration; // in minutes
  final VoidCallback? onTaskComplete;
  
  const BreakReminderWidget({
    Key? key,
    required this.taskId,
    required this.taskName,
    this.workDuration = 50,
    this.breakDuration = 10,
    this.onTaskComplete,
  }) : super(key: key);

  @override
  State<BreakReminderWidget> createState() => _BreakReminderWidgetState();
}

class _BreakReminderWidgetState extends State<BreakReminderWidget> {
  final StorageService _storage = StorageService();
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isOnBreak = false;
  bool _isRunning = false;
  DateTime? _startTime;
  int _sessionCount = 0;
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  void _startTimer() {
    setState(() {
      _isRunning = true;
      _startTime = DateTime.now();
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
        
        if (!_isOnBreak) {
          // Check if work session is complete
          if (_elapsedSeconds >= widget.workDuration * 60) {
            _startBreak();
          }
        } else {
          // Check if break is complete
          if (_elapsedSeconds >= widget.breakDuration * 60) {
            _endBreak();
          }
        }
      });
    });
  }
  
  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }
  
  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _elapsedSeconds = 0;
      _isRunning = false;
      _isOnBreak = false;
      _sessionCount = 0;
      _startTime = null;
    });
  }
  
  void _startBreak() {
    _pauseTimer();
    setState(() {
      _isOnBreak = true;
      _elapsedSeconds = 0;
      _sessionCount++;
    });
    
    // Show break notification
    _showBreakDialog();
  }
  
  void _endBreak() {
    setState(() {
      _isOnBreak = false;
      _elapsedSeconds = 0;
    });
    
    // Automatically start next work session
    _startTimer();
  }
  
  void _completeTask() async {
    _timer?.cancel();
    
    // Calculate actual time in minutes
    final actualMinutes = (_elapsedSeconds / 60).ceil();
    
    // Record performance
    await _storage.recordTaskCompletion(widget.taskId, actualMinutes);
    
    if (widget.onTaskComplete != null) {
      widget.onTaskComplete!();
    }
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
  
  void _showBreakDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: const [
            Icon(Icons.free_breakfast, color: AppColors.primary, size: 28),
            SizedBox(width: 12),
            Text('Break Time! ☕'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve completed ${widget.workDuration} minutes of focused work!',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Text(
              'Take a ${widget.breakDuration}-minute break to:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildBreakTip('🚶 Stretch or walk around'),
            _buildBreakTip('💧 Drink water'),
            _buildBreakTip('👀 Rest your eyes'),
            _buildBreakTip('🧘 Take deep breaths'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _endBreak();
            },
            child: const Text('Skip Break'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startTimer();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Start Break'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBreakTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Text(
        tip,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
  
  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    final remainingSeconds = _isOnBreak
        ? (widget.breakDuration * 60) - _elapsedSeconds
        : (widget.workDuration * 60) - _elapsedSeconds;
    
    final progress = _isOnBreak
        ? _elapsedSeconds / (widget.breakDuration * 60)
        : _elapsedSeconds / (widget.workDuration * 60);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isOnBreak
              ? [AppColors.success.withOpacity(0.1), Colors.blue.withOpacity(0.05)]
              : [AppColors.primary.withOpacity(0.1), Colors.purple.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_isOnBreak ? AppColors.success : AppColors.primary).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_isOnBreak ? AppColors.success : AppColors.primary).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isOnBreak ? Icons.free_breakfast : Icons.timer,
                  color: _isOnBreak ? AppColors.success : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOnBreak ? '☕ Break Time' : '⚡ Focus Mode',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isOnBreak ? AppColors.success : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.taskName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                'Session ${_sessionCount + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Timer Display
          Text(
            _formatTime(_isRunning ? remainingSeconds : 0),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: _isOnBreak ? AppColors.success : AppColors.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            _isOnBreak ? 'Break remaining' : 'Until break',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.black.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation(
                _isOnBreak ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Control Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetTimer,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.textSecondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isRunning ? _pauseTimer : _startTimer,
                  icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow, size: 20),
                  label: Text(_isRunning ? 'Pause' : 'Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isOnBreak ? AppColors.success : AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _completeTask,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Done'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
