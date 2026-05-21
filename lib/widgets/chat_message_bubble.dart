import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_models.dart';
import '../utils/constants.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({Key? key, required this.message}) : super(key: key);

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: _isUser ? 56 : 12,
        right: _isUser ? 12 : 56,
        top: 4,
        bottom: 4,
      ),
      child: Column(
        crossAxisAlignment:
            _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_isUser) ...[
                _buildAvatar(),
                const SizedBox(width: 8),
              ],
              Flexible(child: _buildBubble()),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              left: _isUser ? 0 : 40,
              right: _isUser ? 4 : 0,
              top: 2,
            ),
            child: Text(
              _formatTime(message.timestamp),
              style: AppTextStyles.caption.copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.auto_awesome,
        size: 14,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _isUser ? AppColors.primary : AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.lg),
          topRight: const Radius.circular(AppRadius.lg),
          bottomLeft: Radius.circular(_isUser ? AppRadius.lg : 4),
          bottomRight: Radius.circular(_isUser ? 4 : AppRadius.lg),
        ),
        boxShadow: AppShadows.card,
      ),
      child: Text(
        message.content,
        style: TextStyle(
          fontSize: 15,
          height: 1.45,
          color: _isUser ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return DateFormat('HH:mm').format(dt.toLocal());
  }
}
