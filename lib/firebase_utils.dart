import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseUtils {
  static bool isDemoMode = false;

  static bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  static String get currentUid {
    if (isFirebaseInitialized) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) return user.uid;
      } catch (_) {}
    }
    return 'guest';
  }

  static User? get currentUser {
    if (isFirebaseInitialized) {
      try {
        return FirebaseAuth.instance.currentUser;
      } catch (_) {}
    }
    return null;
  }
}
