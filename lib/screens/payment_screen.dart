import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/payment_service.dart';
import '../services/subscription_service.dart';
import '../utils/constants.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({Key? key}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _svc = PaymentService();

  ProPlan _plan = ProPlan.monthly;
  bool _loading = true;
  bool _paid = false;
  bool _confirming = false;
  String _ref = '';
  String _qrUrl = '';
  StreamSubscription<bool>? _tierSub;

  @override
  void initState() {
    super.initState();
    _createRequest(_plan);
    _tierSub = _svc.watchTierUpgrade().listen((isPro) {
      if (isPro && mounted && !_paid) _onPaymentConfirmed();
    });
  }

  Future<void> _createRequest(ProPlan plan) async {
    setState(() => _loading = true);
    try {
      final result = await _svc.createPaymentRequest(plan);
      if (!mounted) return;
      setState(() {
        _ref = result.ref;
        _qrUrl = result.qrUrl;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tạo yêu cầu thanh toán. Thử lại sau.')),
      );
    }
  }

  void _selectPlan(ProPlan plan) {
    if (plan == _plan) return;
    setState(() => _plan = plan);
    _createRequest(plan);
  }

  void _onPaymentConfirmed() async {
    if (_confirming) return;
    _confirming = true;
    await SubscriptionService().upgradeToPro();
    if (!mounted) return;
    setState(() => _paid = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.pop(context, true);
  }

  void _copyRef() {
    Clipboard.setData(ClipboardData(text: _ref));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép mã chuyển khoản'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _tierSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nâng cấp Pro',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: _paid ? _buildSuccessView() : _buildPaymentView(),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            'Thanh toán thành công!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tài khoản của bạn đã được nâng cấp lên Pro.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPlanSelector(),
          const SizedBox(height: 20),
          _buildQrCard(),
          const SizedBox(height: 20),
          _buildBankInfoCard(),
          const SizedBox(height: 16),
          _buildNote(),
          const SizedBox(height: 12),
          _buildSupportContact(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn gói',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _planCard(ProPlan.monthly)),
            const SizedBox(width: 12),
            Expanded(child: _planCard(ProPlan.yearly)),
          ],
        ),
      ],
    );
  }

  Widget _planCard(ProPlan plan) {
    final isSelected = _plan == plan;
    final isYearly = plan == ProPlan.yearly;

    return GestureDetector(
      onTap: () => _selectPlan(plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isYearly)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Tiết kiệm 158k',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              plan.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatPrice(plan.price),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            Text(
              'đ${isYearly ? '/năm' : '/tháng'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (isYearly) ...[
              const SizedBox(height: 4),
              const Text(
                '≈ 65.833đ/tháng',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Quét mã QR để thanh toán',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const SizedBox(
              width: 240,
              height: 240,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _qrUrl,
                width: 240,
                height: 240,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : SizedBox(
                        width: 240,
                        height: 240,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 240,
                  height: 240,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2, size: 60, color: AppColors.textSecondary),
                        SizedBox(height: 8),
                        Text(
                          'Không tải được QR.\nDùng thông tin bên dưới.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Hỗ trợ tất cả ứng dụng ngân hàng Việt Nam',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBankInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin chuyển khoản',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _infoRow('Ngân hàng', PaymentService.bankBin),
          _infoRow('Số tài khoản', PaymentService.accountNo),
          _infoRow('Tên tài khoản', PaymentService.accountName),
          _infoRow('Số tiền', '${_formatPrice(_plan.price)} đ'),
          const Divider(height: 24),
          _buildRefRow(),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nội dung chuyển khoản',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              _loading
                  ? const SizedBox(
                      height: 28,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      _ref,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 2,
                      ),
                    ),
              const SizedBox(height: 4),
              const Text(
                'Bắt buộc nhập đúng để kích hoạt tự động',
                style: TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loading ? null : _copyRef,
          icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
          tooltip: 'Sao chép',
        ),
      ],
    );
  }

  Widget _buildNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sau khi chuyển khoản, tài khoản sẽ được nâng cấp tự động trong vài giây. '
              'Màn hình này sẽ tự đóng khi xác nhận xong.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportContact() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Cần hỗ trợ? Liên hệ: ',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        GestureDetector(
          onTap: () {
            Clipboard.setData(const ClipboardData(text: '0935457152'));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã sao chép số điện thoại'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          child: const Text(
            '0935457152',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  String _formatPrice(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}
