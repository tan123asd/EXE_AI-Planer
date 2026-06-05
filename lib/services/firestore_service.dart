import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference? get _profileRef =>
      _uid == null ? null : _db.collection('users').doc(_uid).collection('data').doc('profile');

  CollectionReference? get _tasksRef =>
      _uid == null ? null : _db.collection('users').doc(_uid).collection('tasks');

  CollectionReference? get _performanceRef =>
      _uid == null ? null : _db.collection('users').doc(_uid).collection('performance');

  // ─── Profile ────────────────────────────────────────────────────────────────

  Future<void> pushProfile(Map<String, dynamic> profileData) async {
    final ref = _profileRef;
    if (ref == null) return;
    await ref.set({
      ...profileData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> fetchProfile() async {
    final ref = _profileRef;
    if (ref == null) return null;
    final snap = await ref.get();
    if (!snap.exists) return null;
    return snap.data() as Map<String, dynamic>?;
  }

  // ─── Subscription tier (server is source of truth) ─────────────────────────

  /// Reads subscription_tier directly from Firestore. Returns null if offline or no data.
  Future<String?> fetchSubscriptionTier() async {
    final profile = await fetchProfile();
    return profile?['subscription_tier'] as String?;
  }

  /// Writes subscription_tier to Firestore. Only call this from a verified payment callback.
  Future<void> setSubscriptionTier(String tier) async {
    final ref = _profileRef;
    if (ref == null) return;
    await ref.set(
      {'subscription_tier': tier, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ─── Tasks ──────────────────────────────────────────────────────────────────

  Future<void> pushTask(Map<String, dynamic> task) async {
    final ref = _tasksRef;
    if (ref == null) return;
    final id = task['id']?.toString();
    if (id == null || id.isEmpty) return;
    await ref.doc(id).set({
      ...task,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> pushAllTasks(List<Map<String, dynamic>> tasks) async {
    final ref = _tasksRef;
    if (ref == null) return;
    final batch = _db.batch();
    for (final task in tasks) {
      final id = task['id']?.toString();
      if (id == null || id.isEmpty) continue;
      batch.set(ref.doc(id), {
        ...task,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> updateTaskFields(String taskId, Map<String, dynamic> fields) async {
    final ref = _tasksRef;
    if (ref == null) return;
    await ref.doc(taskId).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Firestore arrays don't support index updates via field path.
  /// Read-modify-write the sessions array directly.
  Future<void> updateSessionCompleted(
      String taskId, int sessionIndex, bool isCompleted) async {
    final ref = _tasksRef;
    if (ref == null) return;
    final doc = await ref.doc(taskId).get();
    if (!doc.exists) return;
    final data = Map<String, dynamic>.from(doc.data() as Map);
    final sessions = (data['sessions'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    if (sessionIndex < 0 || sessionIndex >= sessions.length) return;
    sessions[sessionIndex] = {
      ...sessions[sessionIndex],
      'isCompleted': isCompleted,
    };
    final allDone = sessions.isNotEmpty && sessions.every((s) => s['isCompleted'] == true);
    await ref.doc(taskId).update({
      'sessions': sessions,
      'isCompleted': allDone,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> taskExists(String taskId) async {
    final ref = _tasksRef;
    if (ref == null) return false;
    final snap = await ref.doc(taskId).get();
    return snap.exists;
  }

  Future<void> deleteTask(String taskId) async {
    if (taskId.isEmpty) return;
    final ref = _tasksRef;
    if (ref == null) return;
    await ref.doc(taskId).delete();
  }

  /// Batch-deletes every task document in Firestore for the current user.
  Future<void> deleteAllTasks() async {
    final ref = _tasksRef;
    if (ref == null) return;
    final snap = await ref.get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> fetchAllTasks() async {
    final ref = _tasksRef;
    if (ref == null) return [];
    final snap = await ref.get();
    return snap.docs
        .map((d) {
          final data = Map<String, dynamic>.from(d.data() as Map);
          // Convert Firestore Timestamp → ISO8601 string for local sync comparison.
          // Kept so _syncTasks can pick the latest-writer winner.
          final ts = data['updatedAt'];
          if (ts is Timestamp) {
            data['updatedAt'] = ts.toDate().toUtc().toIso8601String();
          } else {
            data.remove('updatedAt');
          }
          return data;
        })
        .toList();
  }

  // ─── Performance ─────────────────────────────────────────────────────────────

  Future<void> pushPerformance(Map<String, dynamic> record) async {
    final ref = _performanceRef;
    if (ref == null) return;
    final id = record['taskId']?.toString() ?? _db.collection('_').doc().id;
    await ref.doc(id).set(record);
  }

  // ─── Initial sync: Firestore → local ────────────────────────────────────────

  /// Called once after login. Pulls Firestore data into SharedPreferences.
  /// If Firestore is empty (new account), pushes local data up instead.
  Future<void> initialSync(SharedPreferences prefs) async {
    await _syncProfile(prefs);
    await _syncTasks(prefs);
  }

  Future<void> _syncProfile(SharedPreferences prefs) async {
    final remote = await fetchProfile();
    if (remote == null) {
      // New account — push existing local profile to Firestore
      await _pushLocalProfile(prefs);
      return;
    }

    final remoteTs = (remote['updatedAt'] as Timestamp?)?.toDate();
    final localTsStr = prefs.getString('profile_updatedAt');
    final localTs = localTsStr != null ? DateTime.tryParse(localTsStr) : null;

    if (localTs != null && remoteTs != null && localTs.isAfter(remoteTs)) {
      // Local is newer — push local up
      await _pushLocalProfile(prefs);
    } else {
      // Remote is newer or no local ts — pull remote down
      _applyRemoteProfile(prefs, remote);
    }
  }

  Future<void> _pushLocalProfile(SharedPreferences prefs) async {
    final data = <String, dynamic>{
      'name': prefs.getString('user_name') ?? '',
      'email': prefs.getString('user_email') ?? '',
      'photoUrl': prefs.getString('user_photo_url') ?? '',
      'phone': prefs.getString('user_phone') ?? '',
      'bio': prefs.getString('user_bio') ?? '',
      'productivityHours': prefs.getString('productivity_hours') ?? '[]',
      'breakSettings': prefs.getString('break_settings') ?? '{}',
      'userProfile': prefs.getString('user_profile') ?? '{}',
      // subscription_tier is intentionally excluded — managed only by SubscriptionService.
    };
    await pushProfile(data);
    await prefs.setString(
        'profile_updatedAt', DateTime.now().toUtc().toIso8601String());
  }

  void _applyRemoteProfile(SharedPreferences prefs, Map<String, dynamic> remote) {
    if (remote['name'] != null) prefs.setString('user_name', remote['name']);
    if (remote['email'] != null) prefs.setString('user_email', remote['email']);
    if (remote['photoUrl'] != null) prefs.setString('user_photo_url', remote['photoUrl']);
    if (remote['phone'] != null) prefs.setString('user_phone', remote['phone']);
    if (remote['bio'] != null) prefs.setString('user_bio', remote['bio']);
    if (remote['productivityHours'] != null) {
      prefs.setString('productivity_hours', remote['productivityHours']);
    }
    if (remote['breakSettings'] != null) {
      prefs.setString('break_settings', remote['breakSettings']);
    }
    if (remote['userProfile'] != null) {
      prefs.setString('user_profile', remote['userProfile']);
    }
    // Restore subscription tier from Firestore so switching accounts applies correct tier.
    final tier = remote['subscription_tier'] as String?;
    if (tier != null && _uid != null) {
      prefs.setString('user_tier_$_uid', tier);
    }
    final remoteTs = (remote['updatedAt'] as Timestamp?)?.toDate();
    if (remoteTs != null) {
      prefs.setString('profile_updatedAt', remoteTs.toUtc().toIso8601String());
    }
  }

  Future<void> _syncTasks(SharedPreferences prefs) async {
    final remoteTasks = await fetchAllTasks();
    final remoteIds = remoteTasks.map((t) => t['id']?.toString()).toSet();

    final localJson = prefs.getString('custom_tasks');
    final localTasks = localJson != null && localJson.isNotEmpty
        ? (jsonDecode(localJson) as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    if (remoteTasks.isEmpty) {
      // Firestore empty (new account or all remote tasks deleted) — push local if any
      if (localTasks.isNotEmpty) await pushAllTasks(localTasks);
      return;
    }

    // Find the latest updatedAt among remote tasks for comparison
    DateTime? latestRemoteTs;
    for (final t in remoteTasks) {
      final tsStr = t['updatedAt'] as String?;
      if (tsStr != null) {
        final ts = DateTime.tryParse(tsStr);
        if (ts != null && (latestRemoteTs == null || ts.isAfter(latestRemoteTs))) {
          latestRemoteTs = ts;
        }
      }
    }

    final localTsStr = prefs.getString('custom_tasks_updatedAt');
    final localTs = localTsStr != null ? DateTime.tryParse(localTsStr) : null;

    if (localTs != null && latestRemoteTs != null && localTs.isAfter(latestRemoteTs)) {
      // Local was modified AFTER last remote update → local wins
      if (localTasks.isEmpty) {
        // User deleted all tasks locally — batch-delete remote as well
        await deleteAllTasks();
      } else {
        await pushAllTasks(localTasks);
      }
      return;
    }

    // Remote wins (or no local timestamp) — pull remote down.
    // Also push any local tasks not present in Firestore (failed to push earlier).
    final tasksToStore = remoteTasks.map((t) {
      final copy = Map<String, dynamic>.from(t);
      copy.remove('updatedAt');
      return copy;
    }).toList();

    final localOnlyTasks = localTasks
        .where((t) {
          final id = t['id']?.toString();
          return id != null && id.isNotEmpty && !remoteIds.contains(id);
        })
        .toList();
    if (localOnlyTasks.isNotEmpty) {
      await pushAllTasks(localOnlyTasks);
      tasksToStore.addAll(localOnlyTasks);
    }

    await prefs.setString('custom_tasks', jsonEncode(tasksToStore));
    // Align local timestamp with remote so the next login doesn't flip back to local
    final tsToStore = latestRemoteTs?.toUtc().toIso8601String() ??
        DateTime.now().toUtc().toIso8601String();
    await prefs.setString('custom_tasks_updatedAt', tsToStore);
  }

  // ─── Settings sync (called on reconnect) ────────────────────────────────────

  /// Compares profile_updatedAt local vs Firestore and syncs the winner.
  Future<void> syncSettingsIfNeeded(SharedPreferences prefs) async {
    final remote = await fetchProfile();
    final localTsStr = prefs.getString('profile_updatedAt');
    final localTs = localTsStr != null ? DateTime.tryParse(localTsStr) : null;
    final remoteTs = (remote?['updatedAt'] as Timestamp?)?.toDate();

    if (remote == null || (localTs != null && remoteTs != null && localTs.isAfter(remoteTs))) {
      await _pushLocalProfile(prefs);
    } else if (remoteTs != null && (localTs == null || remoteTs.isAfter(localTs))) {
      _applyRemoteProfile(prefs, remote);
    }
  }
}
