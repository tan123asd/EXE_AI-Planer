import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_queue_service.dart';
import 'firestore_service.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _wasOffline = false;

  /// Call once from main() after all services are initialized.
  void init() {
    Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final online = results.any((r) => r != ConnectivityResult.none);

    if (online && _wasOffline) {
      // Just came back online — flush pending ops + sync settings
      _wasOffline = false;
      await _syncOnReconnect();
    } else if (!online) {
      _wasOffline = true;
    }
  }

  Future<void> _syncOnReconnect() async {
    final prefs = await SharedPreferences.getInstance();
    // 1. Flush queued task ops (delete / complete)
    await SyncQueueService().flushToFirestore();
    // 2. Sync profile/settings (last-write-wins)
    await FirestoreService().syncSettingsIfNeeded(prefs);
  }

  /// Manually trigger a sync — call this after login.
  Future<void> syncNow() async {
    final online = await isOnline();
    if (!online) return;
    await _syncOnReconnect();
  }
}
