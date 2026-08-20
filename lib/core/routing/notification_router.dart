import 'package:firebase_messaging/firebase_messaging.dart';

/// Maps a notification `type` to the GoRouter location that owns its content.
///
/// Deep-link targets are passed separately as `extra` so each screen can
/// auto-open the right thread (task detail sheet, announcement detail sheet,
/// or report detail view).
String locationForNotificationType(String? type) {
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
      return '/team';
    case 'cleaning':
      return '/cleaning';
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