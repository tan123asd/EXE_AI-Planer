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

  /// Fully disconnects the cached Google account so the next sign-in shows the
  /// account picker (and re-consent). Used during account deletion — a bare
  /// FirebaseAuth.signOut() leaves the Google session cached, which would let
  /// the just-deleted email sign back in silently.
  Future<void> disconnectGoogle() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      // disconnect() throws if not currently connected; fall back to signOut.
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
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

  /// Re-authenticate current user using Google Sign-In.
  ///
  /// Used to satisfy Firebase's `requires-recent-login` requirement for sensitive
  /// operations like account deletion.
  Future<void> reauthenticateWithGoogle() async {
    // Trigger the authentication flow again.
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'user-cancelled-reauth',
        message: 'User cancelled Google re-authentication.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-missing',
        message: 'No signed-in user to re-authenticate.',
      );
    }

    // Re-authenticate the user.
    await user.reauthenticateWithCredential(credential);
  }
}

