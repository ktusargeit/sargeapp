import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/permission_system.dart';
import '../../../core/providers/auth_providers.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../models/task_models.dart';

/// Single source of truth for a user's active (non-completed) tasks.
///
/// Riverpod caches the AsyncValue, so the dashboard's "Görevlerim" widget
/// does not flicker or vanish when the parent ListView rebuilds/disposes it.
final myActiveTasksProvider =
    StreamProvider.family<List<TaskModel>, String>((ref, uid) {
  final firestore = ref.watch(firestoreProvider);
  // NOTE: only equality/IN filters here — no orderBy/limit on the server so
  // this query does NOT require a composite index (avoids
  // "The query requires an index" errors). Sorting + limit happen client-side
  // below, which is safe because this per-user active list is small.
  return firestore
      .collection('tasks')
      .where('assignedTo', isEqualTo: uid)
      .where('status',
          whereIn: [
            'assigned',
            'inProgress',
            'pendingApproval',
          ])
      .snapshots()
      .map((snap) {
        final now = DateTime.now();
        final tasks = snap.docs
            .map((d) => TaskModel.fromDoc(d))
            .where((t) {
              // Submitted tasks ("Onay Bekliyor") only stay visible for 24h
              // after they were completed/submitted.
              if (t.status == TaskStatus.pendingApproval) {
                final completedAt = t.completedAt;
                if (completedAt == null) return true;
                return now.difference(completedAt) <
                    const Duration(hours: 24);
              }
              return true;
            })
            .toList();
        tasks.sort((a, b) {
          final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at); // newest first
        });
        return tasks.take(3).toList();
      });
});

/// Live stream of a single task document, used by the detail sheet so that
/// status changes (Atandı → Devam Ediyor → Tamamlandı) reflect immediately.
final taskDocProvider =
    StreamProvider.family<TaskModel, String>((ref, taskId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('tasks')
      .doc(taskId)
      .snapshots()
      .map((doc) => TaskModel.fromDoc(doc));
});

/// Stream of a user's completed (onaylanmış) task count, for profile stats.
/// Uses equality filters only, so no composite index is required.
final completedTaskCountProvider =
    StreamProvider.family<int, String>((ref, uid) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('tasks')
      .where('assignedTo', isEqualTo: uid)
      .where('status', isEqualTo: 'completed')
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// View context for the Tasks screen: who is viewing and whether they are admin.
typedef TasksViewKey = ({String? uid, bool isAdmin});

/// Tasks visible in the Tasks screen.
///
/// Keyed by (uid, isAdmin) so the underlying Firestore query stream is stable
/// across widget rebuilds. This prevents the "tasks flash then vanish" bug
/// where a brand-new query (with a momentarily-null uid) got built on every
/// setState/rebuild and briefly returned the wrong result set.
///
/// Scope rules (takım bazlı görev izolasyonu):
///  - Admin and Yönetim Kurulu Başkanı (`board_president`) see every task.
///  - Everyone else only sees tasks assigned to them, and — when a task carries
///    a `teamId` — only tasks of teams they are CURRENTLY a member of. This is
///    enforced client-side against `teams/{id}.memberIds` (the real membership
///    source of truth), so a user cannot see another team's tasks.
///  - Board tasks (`assignmentMode == 'board'`) carry no `teamId` and remain
///    visible to the board members they are assigned to.
final tasksScreenProvider =
    StreamProvider.family<List<TaskModel>, TasksViewKey>((ref, key) {
  final firestore = ref.watch(firestoreProvider);

  // Resolve the current user's board president flag and current team
  // membership reactively. Membership comes from `teams/{id}.memberIds`
  // (NOT `users.teamIds`, which is not kept in sync on all join/leave paths).
  final appUser = ref.watch(currentAppUserProvider).value;
  final isBoardPresident = userIsBoardPresident(appUser);
  final teams = ref.watch(clubTeamsProvider).valueOrNull ?? const <ClubTeam>[];
  final myTeamIds = teams
      .where((t) => t.memberIds.contains(key.uid))
      .map((t) => t.id)
      .toSet();

  final seesAll = key.isAdmin || isBoardPresident;

  Query<Map<String, dynamic>> q;
  if (seesAll) {
    // Admins and the Yönetim Kurulu Başkanı see every task, newest first.
    // Single-field orderBy → no index.
    q = firestore.collection('tasks').orderBy('createdAt', descending: true);
  } else if (key.uid != null) {
    // Regular users only see tasks assigned to them. No server-side orderBy is
    // applied here, so this query does NOT require a composite index (avoids
    // the "The query requires an index" / failed-precondition error for
    // members). Sorting happens client-side below.
    q = firestore
        .collection('tasks')
        .where('assignedTo', isEqualTo: key.uid);
  } else {
    // Auth still loading — caller shows a loader instead.
    return Stream.value(const <TaskModel>[]);
  }

  return q.snapshots().map((snap) {
    final tasks = snap.docs.map((d) => TaskModel.fromDoc(d)).where((t) {
      if (seesAll) return true;
      final teamId = t.teamId;
      if (teamId == null || teamId.isEmpty) return true;
      return myTeamIds.contains(teamId);
    }).toList();
    tasks.sort((a, b) {
      final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at); // newest first
    });
    return tasks;
  });
});
