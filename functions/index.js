const { onRequest } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();

/**
 * SePay webhook — POST /sePayWebhook
 *
 * Cấu hình trong SePay dashboard:
 *   Webhook URL: https://<region>-<project>.cloudfunctions.net/sePayWebhook
 *
 * Body (application/json) từ SePay:
 *   { transferType, amount, content, ... }
 */
exports.sePayWebhook = onRequest({ cors: false }, async (req, res) => {
  if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');

  const { transferType, amount, content = '' } = req.body;

  if (transferType !== 'in') return res.json({ success: false, skipped: true });

  // Tìm mã AP + 6 ký tự trong nội dung chuyển khoản
  const match = content.toUpperCase().match(/AP[A-Z0-9]{6}/);
  if (!match) return res.json({ success: false, error: 'ref not found in content' });

  const ref = match[0];
  const paymentRef = db.collection('payment_requests').doc(ref);
  const paymentSnap = await paymentRef.get();

  if (!paymentSnap.exists) {
    return res.json({ success: false, error: 'payment_request not found' });
  }

  const { uid, amount: expectedAmount, status, durationDays = 30 } = paymentSnap.data();

  if (status === 'completed') return res.json({ success: true, already: true });

  if (amount < expectedAmount) {
    return res.json({
      success: false,
      error: 'amount too low',
      received: amount,
      expected: expectedAmount,
    });
  }

  // Tính ngày hết hạn
  const expireAt = new Date();
  expireAt.setDate(expireAt.getDate() + durationDays);

  const batch = db.batch();

  batch.update(paymentRef, {
    status: 'completed',
    paidAt: FieldValue.serverTimestamp(),
    paidAmount: amount,
  });

  const profileRef = db
    .collection('users')
    .doc(uid)
    .collection('data')
    .doc('profile');

  batch.set(profileRef, {
    subscription_tier: 'pro',
    subscription_expire_at: Timestamp.fromDate(expireAt),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await batch.commit();

  console.log(`[SePay] Upgraded user ${uid} to pro (${durationDays}d) via ref ${ref}`);
  return res.json({ success: true, ref, uid, expireAt: expireAt.toISOString() });
});
