import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Get auth state stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Check if user is logged in
  bool get isLoggedIn => _firebaseAuth.currentUser != null;

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // The user canceled the sign-in flow
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Silently restores the Firebase session using the cached Google account.
  /// Returns null if no cached Google account is available (user must log in manually).
  Future<UserCredential?> signInSilently() async {
    try {
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _firebaseAuth.signInWithCredential(credential);
    } catch (_) {
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  /// Get user display name
  String? getUserDisplayName() {
    return _firebaseAuth.currentUser?.displayName;
  }

  /// Get user email
  String? getUserEmail() {
    return _firebaseAuth.currentUser?.email;
  }

  /// Get user photo URL
  String? getUserPhotoUrl() {
    return _firebaseAuth.currentUser?.photoURL;
  }

  /// Get user UID
  String? getUserUID() {
    return _firebaseAuth.currentUser?.uid;
  }
}
