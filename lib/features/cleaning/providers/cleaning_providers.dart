import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../models/cleaning_models.dart';

/// Stream of the full (ordered) cleaning rotation.
final cleaningRotationProvider =
    StreamProvider<List<CleaningRotationSlot>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('cleaning_rotation')
      .snapshots()
      .map((snap) {
        final slots = snap.docs
            .map((d) => CleaningRotationSlot.fromDoc(d))
            .toList();
        slots.sort((a, b) => a.order.compareTo(b.order));
        return slots;
      });
});

/// Stream of club-wide cleaning config (`cleaning_meta/config`).
final cleaningConfigProvider = StreamProvider<CleaningConfig>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('cleaning_meta')
      .doc('config')
      .snapshots()
      .map((doc) => doc.exists
          ? CleaningConfig.fromDoc(doc)
          : const CleaningConfig());
});

/// Empty schedule used while none has been realized yet for a week.
final _emptySchedule = Stream.value(CleaningSchedule(
  weekKey: '',
  weekStart: DateTime(1970),
));

/// Stream of a single week's schedule.
///
/// There is intentionally NO on-demand realization here (realization is a
/// write operation performed by admins). This provider only reads what exists.
final cleaningScheduleProvider =
    StreamProvider.family<CleaningSchedule, String>((ref, weekKey) {
  final firestore = ref.watch(firestoreProvider);
  if (weekKey.isEmpty) return _emptySchedule;
  return firestore
      .collection('cleaning_schedule')
      .doc(weekKey)
      .snapshots()
      .map((doc) => doc.exists
          ? CleaningSchedule.fromDoc(weekKey, doc)
          : CleaningSchedule(
              weekKey: weekKey,
              weekStart: CleaningDates.parseKey(weekKey)));
});

/// Upcoming weeks (starting from the current ISO week) as schedule records,
/// for the calendar / "sırada kim var" view.
final upcomingCleaningProvider =
    StreamProvider.autoDispose<List<CleaningSchedule>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final now = DateTime.now();
  final startMonday = CleaningDates.mondayOf(now);
  // Next 12 weeks (including the current one).
  final keys = List.generate(
      12, (i) => CleaningDates.keyOfMonday(startMonday.add(Duration(days: 7 * i))));
  final stream = firestore
      .collection('cleaning_schedule')
      .where(FieldPath.documentId,
          whereIn: keys.length <= 10 ? keys : keys.sublist(0, 10))
      .snapshots()
      .map((snap) {
        final byKey = <String, CleaningSchedule>{};
        for (final d in snap.docs) {
          byKey[d.id] = CleaningSchedule.fromDoc(d.id, d);
        }
        return keys.map((k) {
          final s = byKey[k];
          if (s != null) return s;
          return CleaningSchedule(
              weekKey: k, weekStart: CleaningDates.parseKey(k));
        }).toList();
      });
  return stream;
});

class CleaningRepository {
  final FirebaseFirestore _firestore;

  CleaningRepository(this._firestore);

  // ── Rotation mutations ─────────────────────────────────────────────────────

  Future<void> setStartWeek(String weekKey) async {
    await _firestore.collection('cleaning_meta').doc('config').set({
      'startWeekKey': weekKey,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveShoppingTemplate(List<String> template) async {
    await _firestore.collection('cleaning_meta').doc('config').set({
      'shoppingTemplate': template,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addSlot({
    required int order,
    required String assignmentType,
    required List<String> targetIds,
    String? label,
  }) async {
    await _firestore.collection('cleaning_rotation').add({
      'order': order,
      'assignmentType': assignmentType,
      'targetIds': targetIds,
      'label': (label == null || label.trim().isEmpty) ? null : label.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSlot({
    required String slotId,
    required String assignmentType,
    required List<String> targetIds,
    String? label,
  }) async {
    await _firestore.collection('cleaning_rotation').doc(slotId).update({
      'assignmentType': assignmentType,
      'targetIds': targetIds,
      'label': (label == null || label.trim().isEmpty) ? null : label.trim(),
    });
  }

  Future<void> deleteSlot(String slotId) async {
    await _firestore.collection('cleaning_rotation').doc(slotId).delete();
  }

  /// Persists the given ordered list of slot ids (their index is the order).
  Future<void> reorderSlots(List<String> orderedIds) async {
    final batch = _firestore.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(
        _firestore.collection('cleaning_rotation').doc(orderedIds[i]),
        {'order': i},
      );
    }
    await batch.commit();
  }

  // ── Realization ────────────────────────────────────────────────────────────

  /// Realizes (writes) schedule records for [count] weeks beginning at
  /// [startMonday], applying the given (ordered) rotation cyclically.
  ///
  /// Existing schedule records are NOT overwritten (e.g. overrides/checklists
  /// are preserved). Items for each new week are seeded from [shoppingTemplate].
  Future<int> realizeWeeks({
    required List<CleaningRotationSlot> rotation,
    required DateTime startMonday,
    required int count,
    required List<String> shoppingTemplate,
  }) async {
    final batch = _firestore.batch();
    var created = 0;

    for (var i = 0; i < count; i++) {
      final monday = startMonday.add(Duration(days: 7 * i));
      final key = CleaningDates.keyOfMonday(monday);
      final ref = _firestore.collection('cleaning_schedule').doc(key);

      if (rotation.isEmpty) continue;

      final slot = rotation[i % rotation.length];
      final items = shoppingTemplate
          .where((s) => s.trim().isNotEmpty)
          .map((name) => CleaningItem(
                id: '${key}_${DateTime.now().microsecondsSinceEpoch}_$i',
                name: name.trim(),
              ).toMap())
          .toList();

      batch.set(
        ref,
        {
          'weekKey': key,
          'weekStart': Timestamp.fromDate(monday),
          'slotOrder': slot.order,
          'assignmentType': slot.assignmentType,
          'targetIds': slot.targetIds,
          'label': slot.label,
          'items': items,
          'completed': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      created++;
    }

    await batch.commit();
    // Materialize a `startWeekKey` so future scheduled jobs have an anchor.
    await _firestore.collection('cleaning_meta').doc('config').set({
      'startWeekKey': CleaningDates.keyOfMonday(startMonday),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return created;
  }

  // ── Week mutations ─────────────────────────────────────────────────────────

  Future<void> overrideWeek({
    required String weekKey,
    required String assignmentType,
    required List<String> targetIds,
    String? label,
  }) async {
    await _firestore.collection('cleaning_schedule').doc(weekKey).set({
      'weekKey': weekKey,
      'weekStart': Timestamp.fromDate(CleaningDates.parseKey(weekKey)),
      'overrideAssignmentType': assignmentType,
      'overrideTargetIds': targetIds,
      'overrideLabel': (label == null || label.trim().isEmpty)
          ? null
          : label.trim(),
    }, SetOptions(merge: true));
  }

  Future<void> clearOverride(String weekKey) async {
    await _firestore.collection('cleaning_schedule').doc(weekKey).update({
      'overrideAssignmentType': FieldValue.delete(),
      'overrideTargetIds': FieldValue.delete(),
      'overrideLabel': FieldValue.delete(),
    });
  }

  Future<void> addWeekItem(String weekKey, String name) async {
    final item = CleaningItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
    ).toMap();
    await _firestore.collection('cleaning_schedule').doc(weekKey).update({
      'items': FieldValue.arrayUnion([item]),
    });
  }

  Future<void> removeWeekItem(String weekKey, CleaningItem item) async {
    await _firestore.collection('cleaning_schedule').doc(weekKey).update({
      'items': FieldValue.arrayRemove([item.toMap()]),
    });
  }

  /// Toggles a single shopping-list item's `done` state for a week,
  /// recording who toggled it and when.
  Future<void> setItemDone({
    required String weekKey,
    required CleaningItem item,
    required bool done,
    required String uid,
    required String displayName,
  }) async {
    final updated = CleaningItem(
      id: item.id,
      name: item.name,
      done: done,
      doneBy: done ? uid : null,
      doneByName: done ? displayName : null,
      doneAt: done ? DateTime.now() : null,
    );
    await _firestore.collection('cleaning_schedule').doc(weekKey).update({
      'items': FieldValue.arrayRemove([item.toMap()]),
    });
    await _firestore.collection('cleaning_schedule').doc(weekKey).update({
      'items': FieldValue.arrayUnion([updated.toMap()]),
    });
  }

  Future<void> setWeekCompleted({
    required String weekKey,
    required bool completed,
    required String uid,
    required String displayName,
  }) async {
    final doc = _firestore.collection('cleaning_schedule').doc(weekKey);
    if (completed) {
      await doc.update({
        'completed': true,
        'completedBy': uid,
        'completedByName': displayName,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await doc.update({
        'completed': false,
        'completedBy': FieldValue.delete(),
        'completedByName': FieldValue.delete(),
        'completedAt': FieldValue.delete(),
      });
    }
  }
}

final cleaningRepositoryProvider = Provider<CleaningRepository>((ref) {
  return CleaningRepository(ref.watch(firestoreProvider));
});