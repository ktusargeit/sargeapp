import 'package:firebase_messaging/firebase_messaging.dart';

/// Maps a notification `type` to the GoRouter location that owns its content.
///
/// For notification types whose owning document id is known up front
/// (`team_application` → team detail, `store_order` → order detail), the id is
/// embedded directly into the returned path so the user lands on the specific
/// content instead of a generic list page.
///
/// For list-backed screens (tasks, announcements, reports) the id is still
/// passed separately as `extra` because there is no dedicated detail route —
/// the list screen auto-opens the thread when it receives that `extra`.
String locationForNotificationType(String? type, {String? relatedId}) {
  final id = (relatedId != null && relatedId.isNotEmpty) ? relatedId : null;
  switch (type) {
    case 'task_comment':
    case 'task_assigned':
    case 'task_submitted':
      return '/tasks';
    case 'announcement_comment':
    case 'announcement':
      return '/dashboard';
    case 'report_reply':
    case 'report':
      return '/report-bug';
    case 'team_application':
      return id != null ? '/team/$id' : '/team';
    case 'cleaning':
      // Cleaning notifications carry the weekKey (Monday YYYY-MM-DD) as relatedId.
      return id != null ? '/cleaning/week/$id' : '/cleaning';
    case 'store_order':
      return id != null ? '/store/order-detail/$id' : '/store/orders';
    default:
      return '/dashboard';
  }
}

/// The owning document id from a notification's data payload (FCM sends it as
/// both `targetId` and `relatedId`).
String? targetIdOf(RemoteMessage message) {
  final data = message.data;
  return data['targetId'] as String? ?? data['relatedId'] as String?;
}

/// The owning document id from a notification's data payload as a plain
/// `Map<String, dynamic>` (used by the in-app notification center).
String? targetIdOfMap(Map<String, dynamic> data) {
  return data['targetId'] as String? ?? data['relatedId'] as String?;
}

/// Pending deep-link from a push notification that arrived before the router
/// was ready (terminated-state launch). The splash screen consumes this after
/// its own auth redirect so the deep link is not overwritten.
String? pendingNotificationLocation;
String? pendingNotificationTargetId;