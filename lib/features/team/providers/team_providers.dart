import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/models/app_user.dart';
import '../../admin/services/user_title_service.dart';
import '../models/team_models.dart';

/// Stream of all users ordered by points descending (weekly leaderboard).
/// Stream of users that belong to at least one team, ordered by points descending.
final leaderboardProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .orderBy('weeklyPoints', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => LeaderboardEntry.fromDoc(d))
          .toList());
});

/// Stream of users currently checked-in to the workshop.
final workshopPresenceProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .where('inWorkshop', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => LeaderboardEntry.fromDoc(d)).toList());
});

/// Stream of all bug reports, newest first.
final bugReportsProvider = StreamProvider<List<BugReport>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('reports')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => BugReport.fromDoc(d)).toList());
});

/// Stream of all club teams (Elektronik Harp, Roket, Mekanik, etc.).
final clubTeamsProvider = StreamProvider<List<ClubTeam>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('teams').orderBy('name').snapshots().map(
        (snap) => snap.docs.map((d) => ClubTeam.fromDoc(d)).toList(),
      );
});

class TeamRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  TeamRepository(this._firestore) : _storage = FirebaseStorage.instance;

  Future<void> addPoints(String uid, int amount) async {
    await _firestore.collection('users').doc(uid).update({
      'points': FieldValue.increment(amount),
      'weeklyPoints': FieldValue.increment(amount),
    });
  }

  Future<void> setWorkshopPresence(String uid, bool present) async {
    await _firestore.collection('users').doc(uid).update({
      'inWorkshop': present,
    });
  }

  Future<String> uploadReportImage(String reportId,
      {File? file, Uint8List? bytes}) async {
    final ref = _storage.ref().child('reports/$reportId.jpg');
    if (kIsWeb && bytes != null) {
      await ref.putData(bytes);
    } else if (file != null) {
      await ref.putFile(file);
    } else {
      throw Exception('No image data provided');
    }
    return ref.getDownloadURL();
  }

  Future<String> submitReport({
    required String title,
    required String message,
    required String submittedBy,
    required String submittedByName,
    String? imageUrl,
    String type = 'bug',
  }) async {
    final docRef = await _firestore.collection('reports').add({
      'title': title.trim(),
      'message': message.trim(),
      'submittedBy': submittedBy,
      'submittedByName': submittedByName,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
      'type': type,
      'imageUrl': imageUrl,
    });
    return docRef.id;
  }

  Future<void> resolveReport(String id, bool resolved) async {
    await _firestore
        .collection('reports')
        .doc(id)
        .update(resolved ? {'status': 'done'} : {'status': 'open'});
  }

  Future<void> updateReportStatus(String id, String status) async {
    await _firestore.collection('reports').doc(id).update({'status': status});
  }
}

/// Stream of all units with teamId.
final teamUnitListProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('units')
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map((d) {
            final data = d.data();
            return {
              'id': d.id,
              'name': data['name'] as String? ?? '',
              'teamId': data['teamId'] as String? ?? '',
            };
          }).toList());
});

/// Units filtered by a specific teamId.
final teamUnitsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>(
    (ref, teamId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('units')
      .where('teamId', isEqualTo: teamId)
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map((d) {
            final data = d.data();
            return {
              'id': d.id,
              'name': data['name'] as String? ?? '',
              'teamId': data['teamId'] as String? ?? '',
            };
          }).toList());
});

/// Stream of team members (users whose uid is in team.memberIds).
final teamMembersProvider =
    StreamProvider.family<List<AppUser>, String>((ref, teamId) {
  final firestore = ref.watch(firestoreProvider);
    return firestore
        .collection('teams')
        .doc(teamId)
        .snapshots()
        .asyncMap((teamDoc) async {
        final data = teamDoc.data();
        final memberIds = (data?['memberIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        if (memberIds.isEmpty) return <AppUser>[];
        // Firestore 'whereIn' supports up to 10 items; chunk for larger teams.
        final users = <AppUser>[];
        final chunks = <List<String>>[];
        for (var i = 0; i < memberIds.length; i += 10) {
          chunks.add(memberIds.sublist(
              i,
              i + 10 > memberIds.length
                  ? memberIds.length
                  : i + 10));
        }
        for (final chunk in chunks) {
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
      });
});

/// Typed, team-scoped units ("birimler"), ordered by name.
final teamUnitsListProvider =
    StreamProvider.family<List<TeamUnit>, String>((ref, teamId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('units')
      .where('teamId', isEqualTo: teamId)
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map((d) => TeamUnit.fromDoc(d)).toList());
});

/// Live stream of a single unit document.
final unitDocProvider =
    StreamProvider.family<TeamUnit?, String>((ref, unitId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('units')
      .doc(unitId)
      .snapshots()
      .map((doc) => doc.exists ? TeamUnit.fromDoc(doc) : null);
});

/// Resolves a unit's members into full [AppUser] profiles.
final unitMembersProvider =
    StreamProvider.family<List<AppUser>, String>((ref, unitId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('units')
      .doc(unitId)
      .snapshots()
      .asyncMap((doc) async {
    final data = doc.data();
    final memberUids = (data?['memberUids'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];
    if (memberUids.isEmpty) return <AppUser>[];
    final users = <AppUser>[];
    for (var i = 0; i < memberUids.length; i += 10) {
      final chunk = memberUids.sublist(
          i,
          i + 10 > memberUids.length ? memberUids.length : i + 10);
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
  });
});

/// Service for managing team-scoped units ("birimler") and their leads.
///
/// Integrates with [UserTitleService] so that assigning a user as a unit lead
/// automatically grants an active `unit_lead` title (with the unit name), and
/// removing them retires that title.
class UnitService {
  final FirebaseFirestore _firestore;
  UnitService(this._firestore);

  Future<void> createUnit({
    required String teamId,
    required String name,
    String? description,
  }) async {
    await _firestore.collection('units').add({
      'teamId': teamId,
      'name': name.trim(),
      'description': description == null || description.trim().isEmpty
          ? null
          : description.trim(),
      'memberUids': <String>[],
      'unitLeadUid': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUnit({
    required String unitId,
    required String name,
    String? description,
  }) async {
    await _firestore.collection('units').doc(unitId).update({
      'name': name.trim(),
      'description':
          (description == null || description.trim().isEmpty)
              ? null
              : description.trim(),
    });
  }

  Future<void> deleteUnit(String unitId) async {
    await _firestore.collection('units').doc(unitId).delete();
  }

  Future<void> addMember(String unitId, String uid) async {
    await _firestore.collection('units').doc(unitId).update({
      'memberUids': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> removeMember(String unitId, String uid) async {
    await _firestore.collection('units').doc(unitId).update({
      'memberUids': FieldValue.arrayRemove([uid]),
    });
  }

  /// Assigns [uid] as the unit lead, optionally granting a `unit_lead` title.
  ///
  /// If the unit already has a lead, their active matching title is retired
  /// first. Then the new lead (if any) gets an auto-granted `unit_lead` title
  /// via [UserTitleService.addTitle].
  Future<void> setUnitLead({
    required TeamUnit unit,
    String? newLeadUid,
  }) async {
    final titleService = UserTitleService(_firestore);

    // Retire the previous lead's active title for this unit.
    final previousLeadUid = unit.unitLeadUid;
    if (previousLeadUid != null && previousLeadUid.isNotEmpty) {
      try {
        await titleService.retireUnitLeadTitle(
          uid: previousLeadUid,
          unitName: unit.name,
        );
      } catch (_) {
        // Title integration is best-effort; the unit doc update still proceeds.
      }
    }

    await _firestore.collection('units').doc(unit.id).update({
      'unitLeadUid': newLeadUid,
    });

    // Grant the new lead an active `unit_lead` title.
    if (newLeadUid != null && newLeadUid.isNotEmpty) {
      try {
        await titleService.addTitle(
          uid: newLeadUid,
          titleType: 'unit_lead',
          unitName: unit.name,
        );
      } catch (_) {
        // Best-effort; the unit doc already reflects the lead assignment.
      }
    }
  }
}

final unitServiceProvider = Provider<UnitService>((ref) {
  return UnitService(ref.watch(firestoreProvider));
});

/// Team applications stream (for admin to review).
final teamApplicationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('teamApplications')
      .orderBy('appliedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList());
});

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(firestoreProvider));
});