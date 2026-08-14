import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';

/// Raw Firebase Auth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Raw Firestore instance
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Stream of the raw Firebase auth user (null when signed out)
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Stream of the current user's Firestore profile document (role, points, etc.)
final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) {
    return Stream.value(null);
  }
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('users').doc(user.uid).snapshots().map((doc) {
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  });
});

/// Guest mode: uses a [StateProvider] so that go_router's [refreshListenable]
/// can detect changes and re-evaluate the [redirect] guard immediately.
final guestSessionProvider = StateProvider<bool>((ref) => false);

/// Whether the current session is a guest session.
final isGuestProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  final loggedIn = authState.value != null;
  return !loggedIn && ref.watch(guestSessionProvider);
});

/// Convenience: is the current user an admin?
final isAdminProvider = Provider<bool>((ref) {
  final appUser = ref.watch(currentAppUserProvider).value;
  return appUser?.isAdmin ?? false;
});

/// Stream of any user's profile document by uid.
final userProfileProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('users').doc(uid).snapshots().map((doc) {
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  });
});

/// Stream of all registered users, ordered by displayName.
final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('users').orderBy('displayName').snapshots().map(
        (snap) => snap.docs.map((d) => AppUser.fromDoc(d)).toList(),
      );
});

/// Auth controller for sign in / sign up / sign out / guest actions.
class AuthController {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthController(this._auth, this._firestore);

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    await cred.user!.updateDisplayName(displayName.trim());

    final userDoc = _firestore.collection('users').doc(uid);
    final existing = await userDoc.get();
    if (!existing.exists) {
      await userDoc.set({
        'email': email.trim(),
        'displayName': displayName.trim(),
        'role': 'member',
        'points': 0,
        'weeklyPoints': 0,
        'prevWeeklyPoints': 0,
        'photoUrl': null,
        'bio': null,
        'department': null,
        'className': null,
        'teamIds': <String>[],
        'pastTeamIds': <String>[],
        'pastTeams': <Map<String, dynamic>>[],
        'links': <Map<String, dynamic>>[],
        'clubRoles': <Map<String, dynamic>>[],
        'unitResponsibilities': <String>[],
        'awards': <Map<String, dynamic>>[],
        'inWorkshop': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> continueAsGuest() async {
    // No-op — the caller must toggle guestSessionProvider.
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Deletes the current user's account.
  ///
  ///  1. Re-authenticates with the supplied password (required for `deleteUser`,
  ///     otherwise `requires-recent-login` is thrown).
  ///  2. Deletes the Firebase Auth account (signs the user out on success).
  ///
  /// All Firestore/Storage cleanup (user document, team/unit memberships,
  /// profile photos, FCM token) is handled by the `onUserDeleted` Cloud
  /// Function, which runs with the Admin SDK and bypasses client rules.
  ///
  /// Content the user created (tasks, comments, announcements, reports) is
  /// intentionally left intact so other members can still reference it.
  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Oturum bulunamadı.');
    }

    // Re-authenticate with the password.
    final credential = EmailAuthProvider.credential(
      email: user.email ?? '',
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    // Delete the Auth account. Firestore/Storage cleanup happens in the
    // `onUserDeleted` Cloud Function.
    await user.delete();
  }
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider));
});