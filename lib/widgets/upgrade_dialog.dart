import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../screens/payment_screen.dart';

class UpgradeDialog extends StatelessWidget {
  const UpgradeDialog({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const UpgradeDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 22),
          ),
          const SizedBox(width: 10),
          const Text('Tính năng Pro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nâng cấp Pro để mở khoá:',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          _buildBenefit(Icons.chat_bubble_rounded, 'Chat với AI Agent không giới hạn'),
          _buildBenefit(Icons.add_task, '100 lượt AI/ngày (Free: 15 lượt)'),
          _buildBenefit(Icons.bolt, 'Phản hồi ưu tiên, tính năng mới sớm nhất'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Để sau', style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentScreen()),
            );
          },
          child: const Text('Nâng cấp'),
        ),
      ],
    );
  }

  Widget _buildBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
