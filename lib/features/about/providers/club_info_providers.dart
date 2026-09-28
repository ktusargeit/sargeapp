import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../models/club_info_models.dart';

/// The single `club_info` document (story + gallery + contact info).
final clubInfoProvider = StreamProvider<ClubInfo>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('club_info')
      .doc('info')
      .snapshots()
      .map((doc) => ClubInfo.fromMap(doc.exists ? doc.data() : null));
});

/// Honorary members collection (selected from registered users).
final honoraryMembersProvider = StreamProvider<List<HonoraryMember>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('honorary_members')
      .orderBy('addedDate', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => HonoraryMember.fromDoc(d)).toList());
});

/// Club info + honorary member repository.
class ClubInfoRepository {
  final FirebaseFirestore _firestore;

  ClubInfoRepository(this._firestore);

  Future<void> saveClubInfo(ClubInfo info) async {
    await _firestore
        .collection('club_info')
        .doc('info')
        .set(info.toMap(), SetOptions(merge: true));
  }

  Future<void> addHonoraryMember({
    required String userId,
    required String note,
    required String addedBy,
  }) async {
    await _firestore.collection('honorary_members').add({
      'userId': userId,
      'note': note.trim(),
      'story': '',
      'photos': <String>[],
      'addedDate': FieldValue.serverTimestamp(),
      'addedBy': addedBy,
    });
  }

  Future<void> updateHonoraryMember(String id, String note) async {
    await _firestore.collection('honorary_members').doc(id).update({
      'note': note.trim(),
    });
  }

  /// Updates the extended story + gallery photos of an honorary member.
  Future<void> updateHonoraryMemberStory({
    required String id,
    required String story,
    required List<String> photos,
  }) async {
    await _firestore.collection('honorary_members').doc(id).update({
      'story': story.trim(),
      'photos': photos,
    });
  }

  Future<void> removeHonoraryMember(String id) async {
    await _firestore.collection('honorary_members').doc(id).delete();
  }

  /// Creates a brand-new archived ("past") team directly, without it ever
  /// appearing in the active team list.
  Future<String> createArchivedTeam({
    required String name,
    required String period,
    required List<String> memberIds,
    required List<String> freeTextMembers,
    required String createdBy,
  }) async {
    final docRef = await _firestore.collection('teams').add({
      'name': name.trim(),
      'description': '',
      'photoUrl': null,
      'status': 'archived',
      'isActive': false,
      'period': period.trim().isEmpty ? null : period.trim(),
      'story': null,
      'photos': <String>[],
      'memberIds': memberIds,
      'pastMemberIds': <String>[],
      'pastMemberNames': freeTextMembers,
      'leadUid': null,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    });
    return docRef.id;
  }
}

final clubInfoRepositoryProvider = Provider<ClubInfoRepository>((ref) {
  return ClubInfoRepository(ref.watch(firestoreProvider));
});

/// Service maintaining the two-way link between `users/{uid}.pastTeamIds` and
/// `teams/{id}.pastMemberIds`.
///
/// Any mutation must update BOTH sides so removing from one place also removes
/// from the other.
class PastTeamLinkService {
  final FirebaseFirestore _firestore;

  PastTeamLinkService(this._firestore);

  /// Links [uid] to an archived team [teamId] on both sides.
  Future<void> addPastTeam({
    required String uid,
    required String teamId,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'pastTeamIds': FieldValue.arrayUnion([teamId]),
    });
    await _firestore.collection('teams').doc(teamId).update({
      'pastMemberIds': FieldValue.arrayUnion([uid]),
    });
  }

  /// Unlinks [uid] from [teamId] on both sides.
  Future<void> removePastTeam({
    required String uid,
    required String teamId,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'pastTeamIds': FieldValue.arrayRemove([teamId]),
    });
    await _firestore.collection('teams').doc(teamId).update({
      'pastMemberIds': FieldValue.arrayRemove([uid]),
    });
  }
}

final pastTeamLinkServiceProvider = Provider<PastTeamLinkService>((ref) {
  return PastTeamLinkService(ref.watch(firestoreProvider));
});

/// Stream of archived (former) teams, used by the "Hakkımızda → Geçmiş
/// Takımlar" archive view (the profile-side picker was removed).
///
/// Equality-only query; ordering/filtering happens client-side.
final archivedTeamsProvider = StreamProvider<List<dynamic>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('teams')
      .where('isActive', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => {
                'id': d.id,
                'name': d.data()['name'] as String? ?? '',
                'period': d.data()['period'] as String?,
              })
          .toList());
});