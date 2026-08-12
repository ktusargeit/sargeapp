import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
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
