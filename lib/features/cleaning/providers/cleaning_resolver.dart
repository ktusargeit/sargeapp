import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/auth_providers.dart';
import '../models/cleaning_models.dart';

/// Fully resolved view of a cleaning assignment: a human label plus the list
/// of users actually responsible this week.
class ResolvedAssignment {
  final String label;
  final List<AppUser> users;
  final bool resolved;

  const ResolvedAssignment({
    required this.label,
    required this.users,
    this.resolved = false,
  });
}

/// Arguments for [resolvedAssignmentProvider].
typedef CleaningAssignmentArg = (String, List<String>, String?);

/// Resolves a (assignmentType, targetIds, label) triple into a display label
/// and the responsible users.
///
/// - `team` / `unit`: reads the team's/unit's CURRENT members at runtime, so
///   the schedule stays "live" even when membership changes.
/// - `individual` / `custom_group`: targetIds are fixed user ids.
final resolvedAssignmentProvider =
    FutureProvider.family<ResolvedAssignment, CleaningAssignmentArg>(
        (ref, arg) async {
  final (assignmentType, targetIds, label) = arg;
  final firestore = ref.watch(firestoreProvider);

  if (targetIds.isEmpty) {
    return ResolvedAssignment(label: label ?? 'Tanımsız', users: const []);
  }

  switch (assignmentType) {
    case CleaningAssignmentType.team:
      final teamDoc =
          await firestore.collection('teams').doc(targetIds.first).get();
      final teamName = (teamDoc.data()?['name'] as String?) ?? 'Takım';
      final ids = (teamDoc.data()?['memberIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];
      final users = await _resolveUsers(firestore, ids);
      return ResolvedAssignment(
        label: label ?? teamName,
        users: users,
        resolved: true,
      );

    case CleaningAssignmentType.unit:
      final unitDoc =
          await firestore.collection('units').doc(targetIds.first).get();
      final unitName = (unitDoc.data()?['name'] as String?) ?? 'Birim';
      final ids = (unitDoc.data()?['memberUids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];
      final users = await _resolveUsers(firestore, ids);
      return ResolvedAssignment(
        label: label ?? unitName,
        users: users,
        resolved: true,
      );

    case CleaningAssignmentType.customGroup:
      final users = await _resolveUsers(firestore, targetIds);
      return ResolvedAssignment(
        label: label ?? users.map((u) => u.displayName).join(', '),
        users: users,
        resolved: true,
      );

    case CleaningAssignmentType.individual:
    default:
      final users = await _resolveUsers(firestore, targetIds);
      return ResolvedAssignment(
        label: label ?? users.map((u) => u.displayName).join(', '),
        users: users,
        resolved: true,
      );
  }
});

/// Resolves a list of user ids into [AppUser] profiles (chunked `whereIn`).
Future<List<AppUser>> _resolveUsers(
    FirebaseFirestore firestore, List<String> ids) async {
  final unique = ids.where((e) => e.isNotEmpty).toSet().toList();
  if (unique.isEmpty) return const [];
  final users = <AppUser>[];
  for (var i = 0; i < unique.length; i += 10) {
    final chunk = unique.sublist(
        i, i + 10 > unique.length ? unique.length : i + 10);
    final snap = await firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: chunk)
        .get();
    for (final doc in snap.docs) {
      users.add(AppUser.fromDoc(doc));
    }
  }
  users.sort((a, b) => a.displayName.compareTo(b.displayName));
  return users;
}

