import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notifications/providers/notification_providers.dart';

/// In-app replacement for the former Cloud Functions (`functions/index.js`).
///
/// Everything that used to run on Firebase's paid Blaze plan now runs inside
/// the app itself:
///
/// | Cloud Function                 | Replacement                                   |
/// |--------------------------------|-----------------------------------------------|
/// | notifyTaskComment              | [notifyTaskComment] (called after comment add) |
/// | notifyAnnouncementComment      | [notifyAnnouncementComment]                   |
/// | notifyReportReply              | [notifyReportReply]                           |
/// | sendPushOnNotification(+Update)| [NotificationWatcher] → local notifications   |
/// | notifyCleaningWeek             | [runCleaningWeekNotify] (on app start)        |
/// | resetWeeklyPoints              | [runWeeklyReset] (on app start, admins only)  |
/// | cleanupDeletedUser             | [cleanupUserData] (before `user.delete()`)    |
class LocalBackend {
  LocalBackend._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ───────────────────────── Comment / reply fan-out ─────────────────────────

  /// Task comment → grouped notifications to assignee + creator + replied-to
  /// user + every assignee in the same bulk group (never the commenter).
  static Future<void> notifyTaskComment({
    required String taskId,
    required String senderUid,
    required String senderName,
    required String text,
    String? replyToUid,
  }) async {
    try {
      final taskSnap = await _db.collection('tasks').doc(taskId).get();
      final task = taskSnap.data() ?? {};
      final title = (task['title'] as String?) ?? 'Görev';

      final snippet = text.length > 80 ? '${text.substring(0, 80)}...' : text;
      final body = snippet.isNotEmpty
          ? '$senderName, "$title" görevine yorum yaptı: "$snippet"'
          : '$senderName, "$title" görevine yorum yaptı.';

      final targets = <String>{};
      void add(Object? v) {
        if (v is String && v.isNotEmpty) targets.add(v);
      }

      add(task['assignedTo']);
      add(task['assignedBy']);
      add(replyToUid);

      final bulkGroupId = task['bulkGroupId'];
      if (bulkGroupId is String && bulkGroupId.isNotEmpty) {
        try {
          final bulk = await _db
              .collection('tasks')
              .where('bulkGroupId', isEqualTo: bulkGroupId)
              .get();
          for (final d in bulk.docs) {
            add(d.data()['assignedTo']);
          }
        } catch (e) {
          debugPrint('bulk group read skipped: $e');
        }
      }

      targets.remove(senderUid);
      final service = NotificationService(_db);
      for (final uid in targets) {
        try {
          await service.sendThreaded(
            recipientId: uid,
            title: 'Görev yorumu: $title',
            body: body,
            type: 'task_comment',
            relatedId: taskId,
            senderUid: senderUid,
            senderName: senderName,
          );
        } catch (e) {
          debugPrint('task comment notify failed for $uid: $e');
        }
      }
    } catch (e) {
      debugPrint('notifyTaskComment failed: $e');
    }
  }

  /// Announcement comment → grouped notification to the announcement author.
  static Future<void> notifyAnnouncementComment({
    required String announcementId,
    required String senderUid,
    required String senderName,
    required String text,
  }) async {
    try {
      final snap =
          await _db.collection('announcements').doc(announcementId).get();
      final ann = snap.data() ?? {};
      final creatorId = ann['createdBy'] as String?;
      if (creatorId == null || creatorId.isEmpty || creatorId == senderUid) {
        return;
      }
      await NotificationService(_db).sendThreaded(
        recipientId: creatorId,
        title: 'Duyuruya yorum: ${ann['title'] ?? 'Duyuru'}',
        body: text.isNotEmpty ? text : 'Duyuruna bir yorum eklendi.',
        type: 'announcement_comment',
        relatedId: announcementId,
        senderUid: senderUid,
        senderName: senderName,
      );
    } catch (e) {
      debugPrint('notifyAnnouncementComment failed: $e');
    }
  }

  /// Report reply → grouped notification to the submitter, or to
  /// admins/unit-leads when the submitter is the one replying.
  static Future<void> notifyReportReply({
    required String reportId,
    required String senderUid,
    required String senderName,
    required String text,
  }) async {
    try {
      final snap = await _db.collection('reports').doc(reportId).get();
      final report = snap.data() ?? {};
      final title =
          (report['title'] ?? report['message'] ?? 'Bildirim').toString();
      final body = text.isNotEmpty ? text : 'Bildirime bir yanıt eklendi.';
      final submittedBy = report['submittedBy'] as String?;
      final service = NotificationService(_db);

      if (senderUid != submittedBy) {
        if (submittedBy != null && submittedBy.isNotEmpty) {
          await service.sendThreaded(
            recipientId: submittedBy,
            title: 'Bildiriminize yanıt: $title',
            body: body,
            type: 'report_reply',
            relatedId: reportId,
            senderUid: senderUid,
            senderName: senderName,
          );
        }
      } else {
        await service.notifyAdminsThreaded(
          title: 'Yeni bildirim yanıtı: $title',
          body: body,
          type: 'report_reply',
          relatedId: reportId,
          senderUid: senderUid,
          senderName: senderName,
        );
      }
    } catch (e) {
      debugPrint('notifyReportReply failed: $e');
    }
  }

  // ───────────────────────────── Weekly jobs ─────────────────────────────

  /// Monday (YYYY-MM-DD) of the week containing [date] (device local time).
  static String weekKeyOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final monday = d.subtract(Duration(days: d.weekday - DateTime.monday));
    return _fmt(monday);
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Runs every idempotent "scheduled" job. Safe to call on every app start:
  /// each job records that it ran, so it executes at most once per week no
  /// matter how many devices open the app.
  static Future<void> runScheduledJobs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await runCleaningWeekNotify();
    await runWeeklyReset(user.uid);
  }

  /// Replacement for `notifyCleaningWeek` (was: Monday 09:00). The first
  /// signed-in device that opens the app on/after Monday 09:00 sends the
  /// week's cleaning notifications.
  static Future<void> runCleaningWeekNotify() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    if (now.weekday == DateTime.monday && now.hour < 9) return;

    final weekKey = weekKeyOf(now);
    final ref = _db.collection('cleaning_schedule').doc(weekKey);
    try {
      final snap = await ref.get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      if (data['notifiedAt'] != null || data['completed'] == true) return;

      final uids = (await _resolveResponsibleUids(data)).toSet()
        ..removeWhere((e) => e.isEmpty);

      await _db.runTransaction((txn) async {
        final fresh = await txn.get(ref);
        if (!fresh.exists) return;
        final f = fresh.data() ?? {};
        if (f['notifiedAt'] != null || f['completed'] == true) return;

        final ts = FieldValue.serverTimestamp();
        for (final r in uids) {
          txn.set(_db.collection('notifications').doc(), {
            'recipientId': r,
            'senderUid': uid,
            'senderName': 'SARGE',
            'title': 'Temizlik sırası sizde',
            'body': 'Bu hafta temizlik/malzeme alma sırası sizde.',
            'type': 'cleaning',
            'relatedId': weekKey,
            'isRead': false,
            'createdAt': ts,
          });
        }
        txn.update(ref, {'notifiedAt': ts});
      });
    } catch (e) {
      debugPrint('runCleaningWeekNotify failed: $e');
    }
  }

  static Future<List<String>> _resolveResponsibleUids(
      Map<String, dynamic> d) async {
    final overrideType = d['overrideAssignmentType'];
    final isOverridden = overrideType is String && overrideType.isNotEmpty;
    final type = isOverridden ? overrideType : d['assignmentType'];
    final overrideIds = d['overrideTargetIds'];
    final List targetIds =
        isOverridden && overrideIds is List && overrideIds.isNotEmpty
            ? overrideIds
            : (d['targetIds'] as List? ?? const []);
    if (targetIds.isEmpty) return [];

    if (type == 'team') {
      final doc = await _db.collection('teams').doc('${targetIds.first}').get();
      return ((doc.data()?['memberIds'] as List?) ?? const [])
          .whereType<String>()
          .toList();
    }
    if (type == 'unit') {
      final doc = await _db.collection('units').doc('${targetIds.first}').get();
      return ((doc.data()?['memberUids'] as List?) ?? const [])
          .whereType<String>()
          .toList();
    }
    return targetIds.whereType<String>().toList();
  }

  /// Replacement for `resetWeeklyPoints` (was: Monday 00:00). Firestore rules
  /// only let admins rewrite other users' points, so this runs the first time
  /// an ADMIN opens the app in a new week.
  static Future<void> runWeeklyReset(String uid) async {
    try {
      final me = await _db.collection('users').doc(uid).get();
      if (me.data()?['role'] != 'admin') return;

      final currentMonday = DateTime.parse(weekKeyOf(DateTime.now()));
      final prevMonday = currentMonday.subtract(const Duration(days: 7));
      final endingWeekKey = _fmt(prevMonday);

      final metaRef = _db.collection('weekly_meta').doc('config');
      final meta = await metaRef.get();
      final last = meta.data()?['lastResetWeekKey'] as String?;
      // Already reset for this (or a later) week.
      if (last != null && last.compareTo(endingWeekKey) >= 0) return;

      // Claim the job first so a second admin device doesn't run it again.
      await metaRef.set({
        'lastResetWeekKey': endingWeekKey,
        'lastResetAt': FieldValue.serverTimestamp(),
      });

      final usersSnap = await _db
          .collection('users')
          .where('weeklyPoints', isGreaterThan: 0)
          .get();

      final entries = usersSnap.docs.map((doc) {
        final d = doc.data();
        return {
          'uid': doc.id,
          'displayName': d['displayName'] ?? 'İsimsiz Üye',
          'points': (d['weeklyPoints'] as num?)?.toInt() ?? 0,
          'photoUrl': d['photoUrl'],
        };
      }).toList()
        ..sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

      if (entries.isNotEmpty) {
        await _db
            .collection('weekly_leaderboard_archive')
            .doc(endingWeekKey)
            .set({
          'weekKey': endingWeekKey,
          'weekStart': Timestamp.fromDate(prevMonday),
          'entries': entries,
          'archivedAt': FieldValue.serverTimestamp(),
        });
      }

      // Firestore batches are limited to 500 writes.
      final docs = usersSnap.docs;
      for (var i = 0; i < docs.length; i += 450) {
        final batch = _db.batch();
        for (final doc in docs.skip(i).take(450)) {
          batch.update(doc.reference, {'weeklyPoints': 0});
        }
        await batch.commit();
      }
      debugPrint('Weekly points archived/reset for $endingWeekKey');
    } catch (e) {
      debugPrint('runWeeklyReset failed: $e');
    }
  }

  // ─────────────────────────── Account cleanup ───────────────────────────

  /// Replacement for `cleanupDeletedUser`. Must run BEFORE `user.delete()`
  /// while the user is still authenticated (rules check `request.auth.uid`).
  static Future<void> cleanupUserData(String uid) async {
    Future<void> safe(String label, Future<void> Function() fn) async {
      try {
        await fn();
      } catch (e) {
        debugPrint('cleanup [$label] skipped: $e');
      }
    }

    await safe('teams', () async {
      final snap = await _db
          .collection('teams')
          .where('memberIds', arrayContains: uid)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({
          'memberIds': FieldValue.arrayRemove([uid]),
          if (doc.data()['leadUid'] == uid) 'leadUid': null,
        });
      }
      final lead =
          await _db.collection('teams').where('leadUid', isEqualTo: uid).get();
      for (final doc in lead.docs) {
        await doc.reference.update({
          'leadUid': null,
          'memberIds': FieldValue.arrayRemove([uid]),
        });
      }
    });

    await safe('units', () async {
      final snap = await _db
          .collection('units')
          .where('memberUids', arrayContains: uid)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({
          'memberUids': FieldValue.arrayRemove([uid]),
          if (doc.data()['unitLeadUid'] == uid) 'unitLeadUid': null,
        });
      }
      final lead = await _db
          .collection('units')
          .where('unitLeadUid', isEqualTo: uid)
          .get();
      for (final doc in lead.docs) {
        await doc.reference.update({
          'unitLeadUid': null,
          'memberUids': FieldValue.arrayRemove([uid]),
        });
      }
    });

    await safe('fcm_token',
        () => _db.collection('fcm_tokens').doc(uid).delete());
    await safe('presence', () => _db.collection('presence').doc(uid).delete());

    // User document last (other steps may depend on it in rules).
    await safe('user_doc', () => _db.collection('users').doc(uid).delete());
  }
}

/// Replacement for `sendPushOnNotification` / `sendPushOnNotificationUpdate`.
///
/// Listens to the signed-in user's notification documents and shows a local
/// OS notification for each new (or incremented) unread one. Works while the
/// app is running (foreground or in the background until the OS kills it).
class NotificationWatcher {
  NotificationWatcher(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  StreamSubscription? _authSub;
  StreamSubscription? _notifSub;

  void start() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      _notifSub?.cancel();
      _notifSub = null;
      if (user == null) return;
      _listen(user.uid);
      // Also run the weekly "scheduled" jobs once per sign-in / app start.
      LocalBackend.runScheduledJobs();
    });
  }

  void _listen(String uid) {
    var first = true;
    _notifSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      // The first snapshot is the existing backlog — don't spam on startup.
      if (first) {
        first = false;
        return;
      }
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.removed) continue;
        if (change.doc.metadata.hasPendingWrites) continue;
        final data = change.doc.data();
        if (data == null || data['isRead'] == true) continue;

        final type = data['type'] as String?;
        final relatedId = data['relatedId'] as String?;
        if (type != null &&
            relatedId != null &&
            PresenceService.localActiveThread == threadKeyFor(type, relatedId)) {
          continue; // user is looking at this conversation right now
        }
        _show(change.doc.id, data);
      }
    }, onError: (e) => debugPrint('NotificationWatcher error: $e'));
  }

  void _show(String docId, Map<String, dynamic> data) {
    final title = (data['title'] as String?) ?? 'SARGE';
    final body = (data['body'] as String?) ?? '';
    final count = (data['count'] as num?)?.toInt() ?? 0;
    final displayBody = count > 1 ? '$body ($count yeni mesaj)' : body;
    final type = (data['type'] as String?) ?? '';
    final relatedId = (data['relatedId'] as String?) ?? '';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'announcements',
        'Duyurular',
        channelDescription: 'Yeni duyuru ve görev bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    // Same doc id → same notification id, so grouped threads REPLACE the
    // previous OS notification instead of stacking (like the old collapseKey).
    _plugin.show(
      docId.hashCode & 0x7fffffff,
      title,
      displayBody,
      details,
      payload: '$type|$relatedId',
    );
  }
}
