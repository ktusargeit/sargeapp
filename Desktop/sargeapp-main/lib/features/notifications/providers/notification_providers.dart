import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';

/// Stable "thread" identifier for a conversation. The same formula is used by
/// the Cloud Function (`functions/index.js`) so push suppression matches the
/// in-app suppression. `type` is one of `task_comment`, `announcement_comment`
/// or `report_reply` and `relatedId` is the owning document id.
String threadKeyFor(String type, String relatedId) => '$type:$relatedId';

/// Deterministic notification document id for a (recipient, thread) pair.
///
/// This is what turns "one notification per message" into "one notification
/// per thread, with a counter". Because the id is stable, the first message
/// CREATES the doc (triggering the push) while later messages UPDATE it (only
/// incrementing the counter, never creating a new push).
String notificationDocIdFor(
  String recipientId,
  String type,
  String relatedId,
) {
  final safe = '${type}_$relatedId'.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return '${recipientId}_$safe';
}

/// Unread notification count for the current user.
/// Only one `where` clause so no composite index is required.
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final authState = ref.watch(authStateProvider);
  // `.valueOrNull` — `.value` RETHROWS on error state, and this provider is
  // read by `_NotificationBell` inside the AppShell's AppBar, so a throw would
  // take down the whole Scaffold (bottom navigation bar included).
  final uid = authState.valueOrNull?.uid;
  if (uid == null) return Stream.value(0);
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('notifications')
      .where('recipientId', isEqualTo: uid)
      .snapshots()
      .map(
          (snap) => snap.docs.where((d) => d.data()['isRead'] == false).length);
});

/// All notifications for the current user, newest first.
/// Sorted client‑side to avoid requiring a composite index.
final userNotificationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final authState = ref.watch(authStateProvider);
  // `.valueOrNull` — see `unreadNotificationCountProvider` above.
  final uid = authState.valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('notifications')
      .where('recipientId', isEqualTo: uid)
      .snapshots()
      .map((snap) {
    final list = snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();
    // Sort client-side: newest first (descending updatedAt/createdAt).
    list.sort((a, b) {
      final aTime = (a['updatedAt'] as Timestamp?)?.toDate() ??
          (a['createdAt'] as Timestamp?)?.toDate() ??
          DateTime(2000);
      final bTime = (b['updatedAt'] as Timestamp?)?.toDate() ??
          (b['createdAt'] as Timestamp?)?.toDate() ??
          DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return list;
  });
});

/// Tracks which thread the current device is actively viewing, so the sender
/// (and the Cloud Function before pushing) can skip notifications for a thread
/// the recipient already has open.
class PresenceService {
  final FirebaseFirestore _firestore;

  PresenceService(this._firestore);

  /// Thread currently open on THIS device (used by `NotificationWatcher` to
  /// suppress local notifications for the conversation being viewed).
  static String? localActiveThread;

  Future<void> setActiveThread(String threadKey) async {
    localActiveThread = threadKey;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('presence').doc(uid).set({
        'activeThreadId': threadKey,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Presence is best-effort; failing here must not break navigation.
    }
  }

  Future<void> clearActiveThread(String threadKey) async {
    if (localActiveThread == threadKey) localActiveThread = null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final ref = _firestore.collection('presence').doc(uid);
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(ref);
        // Only clear if we still own this thread, so closing an older sheet
        // never clobbers a newer open thread.
        if (!snap.exists || snap.data()?['activeThreadId'] != threadKey) return;
        txn.update(ref, {
          'activeThreadId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {
      // Best-effort.
    }
  }
}

final presenceServiceProvider = Provider<PresenceService>((ref) {
  return PresenceService(ref.watch(firestoreProvider));
});

/// Service for creating notifications.
class NotificationService {
  final FirebaseFirestore _firestore;

  NotificationService(this._firestore);

  /// Send a one-off notification to a specific user (e.g. task assigned,
  /// task submitted, a new announcement). One document per recipient.
  ///
  /// [senderUid] defaults to the currently signed-in user. This value is
  /// required by the Firestore security rules (`senderUid == request.auth.uid`)
  /// so that any signed-in user can create a notification about their own
  /// activity (comments, task submissions, reports, etc.).
  Future<void> send({
    required String recipientId,
    required String title,
    required String body,
    String? type,
    String? relatedId,
    String? senderUid,
    String? senderName,
  }) async {
    final uid = senderUid ?? FirebaseAuth.instance.currentUser?.uid;
    await _firestore.collection('notifications').add({
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'type': type,
      'relatedId': relatedId,
      'senderUid': uid,
      'senderName':
          senderName ?? FirebaseAuth.instance.currentUser?.displayName,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Send (or increment) a GROUPED notification for a conversation thread.
  ///
  /// The first message creates a single deterministic notification document
  /// (which also triggers exactly one push via the Cloud Function); every
  /// following message in the same thread updates that same document and only
  /// increments its `count`, without creating a new document or a new push.
  ///
  /// If [recipientId] is currently viewing this same thread (via presence),
  /// nothing is written at all.
  Future<void> sendThreaded({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    required String relatedId,
    String? senderUid,
    String? senderName,
  }) async {
    final uid = senderUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final threadKey = threadKeyFor(type, relatedId);

    // Presence: skip in-app notification when the recipient actively has this
    // thread open (the sender's device reads the recipient's presence doc).
    try {
      final presenceSnap =
          await _firestore.collection('presence').doc(recipientId).get();
      if (presenceSnap.exists &&
          presenceSnap.data()?['activeThreadId'] == threadKey) {
        return;
      }
    } catch (_) {
      // If presence can't be read, fall through and notify.
    }

    final docId = notificationDocIdFor(recipientId, type, relatedId);
    final docRef = _firestore.collection('notifications').doc(docId);
    final name = senderName ?? FirebaseAuth.instance.currentUser?.displayName;

    // Blind merge-write: the sender is not allowed to READ the recipient's
    // notification, so no transaction. `increment` on a missing field starts
    // at 0, so a new doc gets count=1 and an existing one gets count+1.
    final now = FieldValue.serverTimestamp();
    await docRef.set({
      'recipientId': recipientId,
      'senderUid': uid,
      'senderName': name,
      'title': title,
      'body': body,
      'type': type,
      'relatedId': relatedId,
      'count': FieldValue.increment(1),
      'isRead': false,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  /// Marks a notification as read and resets its thread counter.
  Future<void> markRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'count': 0,
      });
    } catch (_) {
      // Document may not exist; ignore.
    }
  }

  /// Deletes a notification document.
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (_) {
      // Ignore errors
    }
  }

  /// Resets the grouped notification for a specific thread (when the user
  /// opens that thread directly).
  Future<void> resetThread(
    String recipientId,
    String type,
    String relatedId,
  ) async {
    final docId = notificationDocIdFor(recipientId, type, relatedId);
    await markRead(docId);
  }

  /// Notify admins and unit leads (used after a user submits a report,
  /// suggestion, or team application).
  Future<void> notifyAdmins({
    required String title,
    required String body,
    String? type,
    String? relatedId,
    String? senderUid,
    String? senderName,
  }) async {
    final uid = senderUid ?? FirebaseAuth.instance.currentUser?.uid;
    final snap = await _firestore
        .collection('users')
        .where('role', whereIn: ['admin', 'unit_lead']).get();
    for (final doc in snap.docs) {
      await send(
        recipientId: doc.id,
        title: title,
        body: body,
        type: type,
        relatedId: relatedId,
        senderUid: uid,
        senderName: senderName,
      );
    }
  }

  /// Grouped variant of [notifyAdmins]: each admin/unit-lead receives a single
  /// per-thread notification whose counter increments with each reply.
  Future<void> notifyAdminsThreaded({
    required String title,
    required String body,
    required String type,
    required String relatedId,
    String? senderUid,
    String? senderName,
  }) async {
    final uid = senderUid ?? FirebaseAuth.instance.currentUser?.uid;
    final snap = await _firestore
        .collection('users')
        .where('role', whereIn: ['admin', 'unit_lead']).get();
    for (final doc in snap.docs) {
      await sendThreaded(
        recipientId: doc.id,
        title: title,
        body: body,
        type: type,
        relatedId: relatedId,
        senderUid: uid,
        senderName: senderName,
      );
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(firestoreProvider));
});
