let db;

try {
  const { initializeApp, getApps, cert } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');

  if (!getApps().length) {
    initializeApp({
      credential: cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      }),
    });
  }
  db = getFirestore();
} catch (initErr) {
  console.error('[Firebase init error]', initErr.message);
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  if (!db) {
    return res.status(500).json({ error: 'Firebase not initialized', hint: 'Check env vars: FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY' });
  }

  // Xác minh API Key từ SePay
  const authHeader = req.headers['authorization'] || '';
  const expectedKey = `Apikey ${process.env.SEPAY_API_KEY}`;
  if (process.env.SEPAY_API_KEY && authHeader !== expectedKey) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const { FieldValue, Timestamp } = require('firebase-admin/firestore');
    const { transferType, transferAmount, content = '' } = req.body;

    if (transferType !== 'in') {
      return res.json({ success: false, skipped: true });
    }

    const match = content.toUpperCase().match(/AP[A-Z0-9]{6}/);
    if (!match) {
      return res.json({ success: false, error: 'ref not found in content' });
    }

    const ref = match[0];
    const paymentRef = db.collection('payment_requests').doc(ref);
    const paymentSnap = await paymentRef.get();

    if (!paymentSnap.exists) {
      return res.json({ success: false, error: 'payment_request not found' });
    }

    const { uid, amount: expectedAmount, status, durationDays = 30 } = paymentSnap.data();

    if (status === 'completed') {
      return res.json({ success: true, already: true });
    }

    if (transferAmount < expectedAmount) {
      return res.json({ success: false, error: 'amount too low', received: transferAmount, expected: expectedAmount });
    }

    const expireAt = new Date();
    expireAt.setDate(expireAt.getDate() + durationDays);

    const batch = db.batch();
    batch.update(paymentRef, {
      status: 'completed',
      paidAt: FieldValue.serverTimestamp(),
      paidAmount: transferAmount,
    });
    batch.set(
      db.collection('users').doc(uid).collection('data').doc('profile'),
      {
        subscription_tier: 'pro',
        subscription_expire_at: Timestamp.fromDate(expireAt),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    await batch.commit();

    console.log(`[SePay] Upgraded ${uid} to pro (${durationDays}d) via ${ref}, paid ${transferAmount}`);
    return res.json({ success: true, ref, uid, expireAt: expireAt.toISOString() });

  } catch (err) {
    console.error('[webhook error]', err.message);
    return res.status(500).json({ error: err.message });
  }
};
