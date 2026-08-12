import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/models/app_user.dart';
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

  Future<void> submitReport({
    required String title,
    required String message,
    required String submittedBy,
    required String submittedByName,
    String? imageUrl,
    String type = 'bug',
  }) async {
    await _firestore.collection('reports').add({
      'title': title.trim(),
      'message': message.trim(),
      'submittedBy': submittedBy,
      'submittedByName': submittedByName,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
      'type': type,
      'imageUrl': imageUrl,
    });
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