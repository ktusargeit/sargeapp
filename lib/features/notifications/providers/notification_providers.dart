import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';

/// Unread notification count for the current user.
/// Only one `where` clause so no composite index is required.
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return Stream.value(0);
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('notifications')
      .where('recipientId', isEqualTo: uid)
      .snapshots()
      .map((snap) =>
          snap.docs.where((d) => d.data()['isRead'] == false).length);
});

/// All notifications for the current user, newest first.
/// Sorted client‑side to avoid requiring a composite index.
final userNotificationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
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
        // Sort client‑side: newest first (descending createdAt).
        list.sort((a, b) {
          final aTime =
              (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          final bTime =
              (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });
        return list;
      });
});

/// Service for creating notifications.
class NotificationService {
  final FirebaseFirestore _firestore;

  NotificationService(this._firestore);

  /// Send a notification to a specific user.
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
  }) async {
    final uid = senderUid ?? FirebaseAuth.instance.currentUser?.uid;
    await _firestore.collection('notifications').add({
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'type': type,
      'relatedId': relatedId,
      'senderUid': uid,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Notify admins and unit leads (used after a user submits a report,
  /// suggestion, or team application).
  Future<void> notifyAdmins({
    required String title,
    required String body,
    String? type,
    String? relatedId,
    String? senderUid,
  }) async {
    final uid = senderUid ?? FirebaseAuth.instance.currentUser?.uid;
    final snap = await _firestore
        .collection('users')
        .where('role', whereIn: ['admin', 'unit_lead'])
        .get();
    for (final doc in snap.docs) {
      await send(
        recipientId: doc.id,
        title: title,
        body: body,
        type: type,
        relatedId: relatedId,
        senderUid: uid,
      );
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(firestoreProvider));
});
