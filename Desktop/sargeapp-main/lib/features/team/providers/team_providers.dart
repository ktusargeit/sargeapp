import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sarge_depo_app/core/services/imgbb_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/utils/image_utils.dart';
import '../../admin/services/user_title_service.dart';
import '../models/team_models.dart';

/// Stream of all users for the weekly leaderboard.
///
/// Ordered by `weeklyPoints` descending. The order is enforced server-side via
/// `orderBy` and then re-asserted client-side so the rendered ranking can never
/// drift from the actual point value.
final leaderboardProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .orderBy('weeklyPoints', descending: true)
      .snapshots()
      .map((snap) {
    final entries = snap.docs.map((d) => LeaderboardEntry.fromDoc(d)).toList();
    entries.sort((a, b) => b.weeklyPoints.compareTo(a.weeklyPoints));
    return entries;
  });
});

/// Monday-anchored `YYYY-MM-DD` week key, mirroring the cleaning module's
/// `weekKey` concept (Monday = 0). Used as the id for `weekly_leaderboard_archive`.
String leaderboardWeekKey(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final monday = day.subtract(Duration(days: day.weekday - 1));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${monday.year.toString().padLeft(4, '0')}-${two(monday.month)}-${two(monday.day)}';
}

/// Stream of existing archived week keys, newest first.
final weeklyArchiveWeeksProvider = StreamProvider<List<String>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('weekly_leaderboard_archive')
      .orderBy('weekStart', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.id).toList());
});

/// Stream of a single archived week's leaderboard, sorted by the archived
/// weekly points descending.
final weeklyArchiveLeaderboardProvider =
    StreamProvider.family<List<LeaderboardEntry>, String>((ref, weekKey) {
  if (weekKey.isEmpty) return Stream.value(const <LeaderboardEntry>[]);
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('weekly_leaderboard_archive')
      .doc(weekKey)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return const <LeaderboardEntry>[];
    final entries = (doc.data()?['entries'] as List?)
            ?.map((e) => LeaderboardEntry.fromArchiveMap(
                Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const <LeaderboardEntry>[];
    final list = List<LeaderboardEntry>.from(entries);
    list.sort((a, b) => b.weeklyPoints.compareTo(a.weeklyPoints));
    return list;
  });
});

/// Weekly reset metadata (`lastResetAt`, `lastResetWeekKey`) written by the
/// `resetWeeklyPoints` scheduled Cloud Function.
final weeklyMetaProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('weekly_meta')
      .doc('config')
      .snapshots()
      .map((doc) => doc.exists ? doc.data()! : const <String, dynamic>{});
});

/// Stream of users currently checked-in to the workshop.
final workshopPresenceProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .where('inWorkshop', isEqualTo: true)
      .snapshots()
      .map(
          (snap) => snap.docs.map((d) => LeaderboardEntry.fromDoc(d)).toList());
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

/// Stream of Yönetim Kurulu (board) members — users whose `role` is
/// `board_president`, `board_vice_president` or `board_member`. Used
/// exclusively by the gold-themed "Yönetim Kurulu" card on the Takımım screen.
final boardMembersProvider = StreamProvider<List<AppUser>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .where('role', whereIn: [
        'board_president',
        'board_vice_president',
        'board_member',
      ])
      .snapshots()
      .map((snap) {
        final members = snap.docs.map((d) => AppUser.fromDoc(d)).toList();
        // Başkan > Başkan Yardımcısı > Üye, sonra isme göre.
        int rank(AppUser u) {
          if (u.role == 'board_president') return 0;
          if (u.role == 'board_vice_president') return 1;
          return 2;
        }

        members.sort((a, b) {
          final r = rank(a).compareTo(rank(b));
          if (r != 0) return r;
          return a.displayName.compareTo(b.displayName);
        });
        return members;
      });
});

class TeamRepository {
  final FirebaseFirestore _firestore;

  TeamRepository(this._firestore);

  Future<void> addPoints(String uid, int amount, {String? teamId}) async {
    await _firestore.collection('users').doc(uid).update({
      'points': FieldValue.increment(amount),
      'weeklyPoints': FieldValue.increment(amount),
      if (teamId != null && teamId.isNotEmpty)
        'teamPoints.$teamId': FieldValue.increment(amount),
    });
  }

  Future<void> setWorkshopPresence(String uid, bool present) async {
    await _firestore.collection('users').doc(uid).update({
      'inWorkshop': present,
    });
  }

  Future<String> uploadReportImage(String reportId,
      {File? file, Uint8List? bytes}) async {
    final PickedImage img =
        file != null ? PickedImage(dartFile: file) : PickedImage(bytes: bytes);
    final compressed = await img.compressedUploadBytes();
    var uploadBytes = compressed.isNotEmpty ? compressed : bytes;
    if (uploadBytes == null && file != null) {
      uploadBytes = await file.readAsBytes();
    }
    if (uploadBytes == null) {
      throw Exception('No image data provided');
    }
    final url = await ImgbbService.uploadImage(uploadBytes);
    if (url == null) throw Exception('Image upload failed');
    return url;
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
              'unitLeadUid': data['unitLeadUid'] as String? ?? '',
            };
          }).toList());
});

/// Units filtered by a specific teamId.
///
/// Equality-only query (no server-side `orderBy`) so it never requires a
/// composite index. Sorting happens client-side below, which is safe for these
/// small per-team unit lists.
final teamUnitsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, teamId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('units')
      .where('teamId', isEqualTo: teamId)
      .snapshots()
      .map((snap) {
    final units = snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'name': data['name'] as String? ?? '',
        'teamId': data['teamId'] as String? ?? '',
        'unitLeadUid': data['unitLeadUid'] as String? ?? '',
      };
    }).toList();
    units.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return units;
  });
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
    final memberIds =
        (data?['memberIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (memberIds.isEmpty)
      memberIds.add(
          'dummy_id'); // Just to allow execution, we also need board members

    // Fetch board members
    final boardSnap = await firestore.collection('users').where('role',
        whereIn: [
          'board_president',
          'board_vice_president',
          'board_member'
        ]).get();

    final users = <AppUser>[];
    for (final doc in boardSnap.docs) {
      users.add(AppUser.fromDoc(doc));
    }

    // Add users by titles (if any)
    final titlesSnap = await firestore.collection('users').get();
    for (final doc in titlesSnap.docs) {
      if (!users.any((u) => u.uid == doc.id)) {
        final appUser = AppUser.fromDoc(doc);
        if (appUser.isBoardMember) {
          users.add(appUser);
        }
      }
    }

    // Remove duplicates and keep track of added users
    final addedUids = users.map((u) => u.uid).toSet();

    // Fetch team members
    if (memberIds.isNotEmpty && memberIds.first != 'dummy_id') {
      final chunks = <List<String>>[];
      for (var i = 0; i < memberIds.length; i += 10) {
        chunks.add(memberIds.sublist(
            i, i + 10 > memberIds.length ? memberIds.length : i + 10));
      }
      for (final chunk in chunks) {
        final snap = await firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          if (!addedUids.contains(doc.id)) {
            users.add(AppUser.fromDoc(doc));
            addedUids.add(doc.id);
          }
        }
      }
    }
    users.sort((a, b) => a.displayName.compareTo(b.displayName));
    return users;
  });
});

/// Typed, team-scoped units ("birimler").
///
/// Equality-only query (no server-side `orderBy`) so it never requires a
/// composite index; sorting happens client-side below.
final teamUnitsListProvider =
    StreamProvider.family<List<TeamUnit>, String>((ref, teamId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('units')
      .where('teamId', isEqualTo: teamId)
      .snapshots()
      .map((snap) {
    final units = snap.docs.map((d) => TeamUnit.fromDoc(d)).toList();
    units.sort((a, b) => a.name.compareTo(b.name));
    return units;
  });
});

/// Live stream of a single unit document.
final unitDocProvider = StreamProvider.family<TeamUnit?, String>((ref, unitId) {
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
    final memberUids =
        (data?['memberUids'] as List?)?.map((e) => e.toString()).toList() ??
            const [];
    if (memberUids.isEmpty) return <AppUser>[];
    final users = <AppUser>[];
    for (var i = 0; i < memberUids.length; i += 10) {
      final chunk = memberUids.sublist(
          i, i + 10 > memberUids.length ? memberUids.length : i + 10);
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
      'description': (description == null || description.trim().isEmpty)
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
final teamApplicationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
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
