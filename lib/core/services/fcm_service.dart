import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

/// Manages the FCM device token lifecycle.
///
/// The token is stored on the user's own Firestore document under `fcmToken`
/// (not in the public `users` profile that everyone can read). The device token
/// is refreshed on login, on token rotation, and removed on sign-out so a
/// stale/old token can never be used to deliver another user's notifications.
class FcmService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  FcmService(this._messaging, this._firestore);

  /// Writes the token to the dedicated `fcm_tokens/{uid}` document so it is
  /// never exposed via the publicly-readable `users` profile document.
  Future<String?> _refreshAndSave(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return null;
      await _firestore.collection('fcm_tokens').doc(uid).set({
        'uid': uid,
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return token;
    } catch (e, st) {
      debugPrint('FCM token save failed: $e\n$st');
      return null;
    }
  }

  Future<void> _clearToken(String uid) async {
    try {
      await _firestore.collection('fcm_tokens').doc(uid).delete();
    } catch (e, st) {
      debugPrint('FCM token clear failed: $e\n$st');
    }
  }

  /// Attaches listeners for auth-state changes and token refresh. Called once
  /// at startup. Returns an unsubscribe function for completeness.
  void Function() init() {
    String? lastUid;

    Future<void> handleUser(User? user) async {
      // Web has no push registration via FCM on all browsers; skip gracefully.
      if (kIsWeb) return;

      if (user == null) {
        // Sign-out: remove the previous user's token so a stale token can never
        // be used to deliver another user's notifications after re-login.
        if (lastUid != null) {
          await _clearToken(lastUid!);
          lastUid = null;
        }
        return;
      }

      lastUid = user.uid;
      await _refreshAndSave(user.uid);
    }

    final authSub = FirebaseAuth.instance.authStateChanges().listen(handleUser);

    final tokenSub = _messaging.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || token.isEmpty) return;
      try {
        await _firestore.collection('fcm_tokens').doc(uid).set({
          'uid': uid,
          'token': token,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e, st) {
        debugPrint('FCM token refresh save failed: $e\n$st');
      }
    });

    return () {
      authSub.cancel();
      tokenSub.cancel();
    };
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(
    FirebaseMessaging.instance,
    ref.watch(firestoreProvider),
  );
});