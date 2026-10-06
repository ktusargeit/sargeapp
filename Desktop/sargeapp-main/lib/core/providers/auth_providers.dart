import '../services/local_backend_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';

/// Raw Firebase Auth instance
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Raw Firestore instance
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Stream of the raw Firebase auth user (null when signed out)
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Stream of the current user's Firestore profile document (role, points, etc.)
///
/// IMPORTANT: `authState.value` (not `.valueOrNull`) would RETHROW when the
/// auth provider is in an error state, which tears down every widget that
/// watches this provider — including the shell's bottom navigation bar. Use
/// `.valueOrNull` so an auth hiccup degrades to a null user instead of a crash.
final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;
  if (user == null) {
    return Stream.value(null);
  }
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('users').doc(user.uid).snapshots().map((doc) {
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  });
});

// ─── Registration approval (onay) ──────────────────────────────────────────
//
// GUEST LOGIN HAS BEEN REMOVED (v4.4.0). The app is only reachable with an
// approved, registered account. Anything that needs to know whether the current
// session is a real, approved member reads [currentAppUserProvider] (or the
// helpers below).

/// Whether the signed-in user's registration has been approved by an admin.
///
/// `false` while the profile document is still loading, so callers can treat
/// "not known yet" exactly like "not approved" without crashing. Widgets that
/// want to distinguish the two should read [currentAppUserProvider] directly
/// and `.valueOrNull` first.
final isApprovedProvider = Provider<bool>((ref) {
  final appUser = ref.watch(currentAppUserProvider).valueOrNull;
  return appUser?.isApproved ?? false;
});

/// Whether the signed-in user exists but is still waiting for admin approval.
final isPendingApprovalProvider = Provider<bool>((ref) {
  final appUser = ref.watch(currentAppUserProvider).valueOrNull;
  return appUser?.isPendingApproval ?? false;
});

/// All users whose registration is still `pending`.
///
/// Backs BOTH the admin "Kayıt Onayları" tab and the waiting screen's
/// "who else is waiting" list. The Firestore rules allow this read for an
/// unapproved signed-in user (see `firestore.rules` → `isWaitingForApproval`).
final pendingApprovalsProvider = StreamProvider<List<AppUser>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .where('approvalStatus', isEqualTo: approvalPending)
      .snapshots()
      .map((snap) {
    final users = snap.docs.map((d) => AppUser.fromDoc(d)).toList();
    users.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return users;
  });
});

/// Convenience: is the current user an admin?
final isAdminProvider = Provider<bool>((ref) {
  final appUser = ref.watch(currentAppUserProvider).valueOrNull;
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
    await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
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
      try {
        await userDoc.set({
          'email': email.trim(),
          'displayName': displayName.trim(),
          'role': 'member',
          // NEW SIGN-UPS WAIT FOR ADMIN APPROVAL. The user lands on
          // [PendingApprovalScreen] until an admin flips this to 'approved'.
          // Legacy documents have no such field at all and are read as
          // 'approved' (see AppUser.fromDoc), so existing members keep access.
          'approvalStatus': approvalPending,
          'points': 0,
          'weeklyPoints': 0,
          'prevWeeklyPoints': 0,
          'teamPoints': <String, int>{},
          'photoUrl': null,
          'bio': null,
          'department': null,
          'className': null,
          'teamIds': <String>[],
          'pastTeamIds': <String>[],
          'pastTeams': <Map<String, dynamic>>[],
          'links': <Map<String, dynamic>>[],
          'pastExperiences': <Map<String, dynamic>>[],
          'awards': <Map<String, dynamic>>[],
          'inWorkshop': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Clean up orphaned auth account
        await cred.user?.delete();
        rethrow;
      }
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Marks a user's registration as [approvalApproved] (admin action).
  ///
  /// Written by admins from the "Kayıt Onayları" tab. `firestore.rules` grants
  /// `isAdmin()` a full update on the users collection, so no rule change is
  /// needed for this specific write.
  Future<void> approveUser(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'approvalStatus': approvalApproved,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marks a user's registration as [approvalRejected] (admin action).
  ///
  /// The Auth account and the Firestore document are intentionally LEFT IN
  /// PLACE: a client cannot delete another user's Auth account, and keeping the
  /// document lets the admin undo the decision later. The rejected user is
  /// blocked from the app exactly like a pending one.
  Future<void> rejectUser(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'approvalStatus': approvalRejected,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes the user's Firestore profile document (admin action).
  ///
  /// Used for "Reddet / Sil" on a pending registration. Note that the Firebase
  /// Auth account itself can only be removed with the Admin SDK (the
  /// `onUserDeleted` Cloud Function handles that after the user deletes their
  /// own account), so a deleted document simply means the sign-up screen will
  /// be shown again the next time that uid signs in.
  Future<void> deleteUserDocument(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
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

    // Formerly the `cleanupDeletedUser` Cloud Function: clean up Firestore /
    // Storage while still authenticated, then delete the Auth account.
    await LocalBackend.cleanupUserData(user.uid);
    await user.delete();
  }
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(
      ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider));
});
