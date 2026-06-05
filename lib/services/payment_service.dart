import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ProPlan { monthly, yearly }

extension ProPlanExt on ProPlan {
  String get label => this == ProPlan.monthly ? '1 tháng' : '1 năm';
  int get price => this == ProPlan.monthly ? 79000 : 790000;
  int get durationDays => this == ProPlan.monthly ? 30 : 365;
  String get key => this == ProPlan.monthly ? 'monthly' : 'yearly';
}

class PaymentService {
  static final PaymentService _instance = PaymentService._();
  factory PaymentService() => _instance;
  PaymentService._();

  static const String bankBin = 'SACOMBANK';
  static const String accountNo = '050120365591';
  static const String accountName = 'NGUYEN THANH NGUYEN';

  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  String _generateRef() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return 'AP${List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join()}';
  }

  String vietQrUrl(String ref, ProPlan plan) =>
      'https://img.vietqr.io/image/$bankBin-$accountNo-compact2.png'
      '?amount=${plan.price}'
      '&addInfo=${Uri.encodeComponent(ref)}'
      '&accountName=${Uri.encodeComponent(accountName)}';

  Future<({String ref, String qrUrl})> createPaymentRequest(ProPlan plan) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');
    final ref = _generateRef();
    await _db.collection('payment_requests').doc(ref).set({
      'uid': uid,
      'amount': plan.price,
      'plan': plan.key,
      'durationDays': plan.durationDays,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return (ref: ref, qrUrl: vietQrUrl(ref, plan));
  }

  Stream<bool> watchTierUpgrade() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(uid)
        .collection('data')
        .doc('profile')
        .snapshots()
        .map((s) => s.data()?['subscription_tier'] == 'pro');
  }
}
