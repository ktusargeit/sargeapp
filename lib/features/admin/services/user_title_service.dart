import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/providers/auth_providers.dart';

const _uuid = Uuid();

/// Role code priority, highest first. Used to keep the legacy `users/{uid}.role`
/// field in sync with the user's highest active title so that Firestore/Storage
/// rules (which read only the single `role` field) match what the app UI grants.
const List<String> _rolePriority = [
  TitleType.admin,
  TitleType.boardPresident,
  TitleType.boardVicePresident,
  TitleType.boardMember,
  TitleType.captain,
  TitleType.unitLead,
  TitleType.member,
];

/// Service for managing the `users/{uid}/titles` array.
///
/// Titles can be added, "retired" (marked as former) or completely removed.
/// The legacy `role` field is intentionally kept in sync with the user's
/// highest active title so that Firestore/Storage rules (which read only the
/// single `role` field) keep working exactly as before.
///
/// Because the Firestore and Storage security rules resolve permissions from
/// the single `role` field (they cannot iterate over the `titles` array), every
/// title mutation also reconciles `role` to the user's highest active title.
/// Without this, granting e.g. a `unit_lead` or `captain` title would show the
/// store/depo UI but the server-side rules would reject the writes with
/// `permission-denied` / `firebase_storage/unauthorized`.
class UserTitleService {
  final FirebaseFirestore _firestore;

  UserTitleService(this._firestore);

  CollectionReference<Map<String, dynamic>> _users() =>
      _firestore.collection('users');

  /// A stable, ordered list of selectable titles for the admin UI.
  static const List<Map<String, String>> titleOptions = [
    {'type': TitleType.boardPresident, 'label': 'Yönetim Kurulu Başkanı'},
    {'type': TitleType.boardVicePresident, 'label': 'Yönetim Kurulu Başkan Yardımcısı'},
    {'type': TitleType.boardMember, 'label': 'Yönetim Kurulu Üyesi'},
    {'type': TitleType.captain, 'label': 'Kaptan'},
    {'type': TitleType.unitLead, 'label': 'Birim Sorumlusu'},
    {'type': TitleType.admin, 'label': 'Admin'},
    {'type': TitleType.member, 'label': 'Normal Üye'},
    {'type': TitleType.honoraryMember, 'label': 'Onursal Üye'},
  ];

  static String labelForType(String titleType) {
    for (final o in titleOptions) {
      if (o['type'] == titleType) return o['label']!;
    }
    return titleType;
  }

  /// Adds a new active title to [uid]. Returns the created title.
  Future<UserTitle> addTitle({
    required String uid,
    required String titleType,
    String? unitName,
    DateTime? startDate,
  }) async {
    final title = UserTitle(
      id: _uuid.v4(),
      titleType: titleType,
      unitName: unitName,
      isActive: true,
      startDate: startDate ?? DateTime.now(),
    );

    await _users().doc(uid).update({
      'titles': FieldValue.arrayUnion([title.toMap()]),
    });

    await reconcileRole(uid);

    return title;
  }

  /// Marks a title as former ("retired") instead of deleting it.
  ///
  /// Sets [UserTitle.isActive] to false and fills [UserTitle.endDate].
  Future<void> retireTitle({
    required String uid,
    required String titleId,
    DateTime? endDate,
  }) async {
    final userRef = _users().doc(uid);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      final titles = _titlesFromData(data);
      var changed = false;
      final updated = titles.map((t) {
        if (t.id == titleId && t.isActive) {
          changed = true;
          return t.copyWith(
            isActive: false,
            endDate: endDate ?? DateTime.now(),
          );
        }
        return t;
      }).map((t) => t.toMap()).toList();
      if (changed) {
        txn.update(userRef, {'titles': updated});
      }
    });
    await reconcileRole(uid);
  }

  /// Retires the active `unit_lead` title for a specific [unitName].
  ///
  /// Used by the team/unit system: when a user is removed as the lead of a
  /// birim, the matching active title is retired (kept as "Eski Birim
  /// Sorumlusu") instead of deleted. Returns true if a title was retired.
  Future<bool> retireUnitLeadTitle({
    required String uid,
    required String unitName,
  }) async {
    final userRef = _users().doc(uid);
    var retired = false;
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      final titles = _titlesFromData(data);
      var changed = false;
      final updated = titles.map((t) {
        if (t.isActive &&
            t.titleType == TitleType.unitLead &&
            t.unitName == unitName) {
          changed = true;
          return t.copyWith(
            isActive: false,
            endDate: DateTime.now(),
          );
        }
        return t;
      }).map((t) => t.toMap()).toList();
      if (changed) {
        retired = true;
        txn.update(userRef, {'titles': updated});
      }
    });
    await reconcileRole(uid);
    return retired;
  }

  /// Retires the active `captain` title for a specific [teamName].
  ///
  /// Mirror of [retireUnitLeadTitle] for the team-captain role: when a user is
  /// removed as the lead of a team, only the matching active title is retired
  /// (kept as "Eski Kaptan") instead of deleting it — so a user who captains
  /// several teams keeps the other teams' active captain titles. Returns true
  /// if a title was retired.
  Future<bool> retireCaptainTitle({
    required String uid,
    required String teamName,
  }) async {
    final userRef = _users().doc(uid);
    var retired = false;
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      final titles = _titlesFromData(data);
      var changed = false;
      final updated = titles.map((t) {
        if (t.isActive &&
            t.titleType == TitleType.captain &&
            t.unitName == teamName) {
          changed = true;
          return t.copyWith(
            isActive: false,
            endDate: DateTime.now(),
          );
        }
        return t;
      }).map((t) => t.toMap()).toList();
      if (changed) {
        retired = true;
        txn.update(userRef, {'titles': updated});
      }
    });
    await reconcileRole(uid);
    return retired;
  }

  /// Assigns the SINGLE active `board_president` (Yönetim Kurulu Başkanı) title
  /// to [uid] and retires any other user's active presidency.
  ///
  /// Business rule: the club can only have ONE active Yönetim Kurulu Başkanı at
  /// a time. Exactly like team captaincy (`teams/{id}.leadUid` is unique), the
  /// previously active president is retired (`isActive: false` + `endDate`) so
  /// their title remains visible in their history as \"Eski Yönetim Kurulu
  /// Başkanı\".
  ///
  /// Steps:
  ///  1. Query every user holding an ACTIVE `board_president` title.
  ///  2. Retire those titles (skipping [uid] itself, to avoid churning the new
  ///     president's own record).
  ///  3. Add a fresh active `board_president` title for [uid].
  ///  4. Reconcile the legacy `role` field for every affected user.
  ///
  /// Returns the newly created title.
  Future<UserTitle> grantPresidentTitle({
    required String uid,
    DateTime? startDate,
  }) async {
    // 1. Find the currently active president(s). `titles` is an array of maps,
    //    so the equality query narrows the candidates and the final filter is
    //    done client-side.
    final snapshot = await _users()
        .where('titles', arrayContains: {
          'titleType': TitleType.boardPresident,
          'isActive': true,
        })
        .get()
        .catchError((_) async => _users().get());

    final affected = <String>{};
    for (final doc in snapshot.docs) {
      if (doc.id == uid) continue;
      final titles = _titlesFromData(doc.data());
      final hasActivePresidency = titles.any(
        (t) => t.isActive && t.titleType == TitleType.boardPresident,
      );
      if (!hasActivePresidency) continue;

      final updated = titles.map((t) {
        if (t.isActive && t.titleType == TitleType.boardPresident) {
          return t.copyWith(isActive: false, endDate: DateTime.now()).toMap();
        }
        return t.toMap();
      }).toList();
      await _users().doc(doc.id).update({'titles': updated});
      affected.add(doc.id);
    }

    // 3. Grant the new presidency.
    final title = await addTitle(
      uid: uid,
      titleType: TitleType.boardPresident,
      startDate: startDate,
    );

    // 4. Re-sync the retired presidents' legacy `role`.
    for (final otherUid in affected) {
      await reconcileRole(otherUid);
    }

    return title;
  }

  /// Retires all active titles of [titleType] for [uid].
  ///
  /// Used when a global role (e.g. admin, board president, board member) is
  /// removed from a user via the multi-role sheet. Matching titles are kept as
  /// former titles instead of being deleted. Reconciles `role` afterwards so a
  /// user who is still holding e.g. a `board_member` title is promoted back to
  /// `board_member` after their `admin` title is retired.
  Future<void> retireActiveTitleByType({
    required String uid,
    required String titleType,
  }) async {
    final userRef = _users().doc(uid);
    var changed = false;
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      final titles = _titlesFromData(data);
      final updated = titles.map((t) {
        if (t.isActive && t.titleType == titleType) {
          changed = true;
          return t.copyWith(isActive: false, endDate: DateTime.now());
        }
        return t;
      }).map((t) => t.toMap()).toList();
      if (changed) {
        txn.update(userRef, {'titles': updated});
      }
    });
    await reconcileRole(uid);
  }

  /// Completely removes a title (only for accidental additions).
  Future<void> removeTitle({
    required String uid,
    required String titleId,
  }) async {
    final userRef = _users().doc(uid);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      final titles = _titlesFromData(data);
      final updated = titles
          .where((t) => t.id != titleId)
          .map((t) => t.toMap())
          .toList();
      if (updated.length != titles.length) {
        txn.update(userRef, {'titles': updated});
      }
    });
    await reconcileRole(uid);
  }

  /// Re-syncs the legacy `users/{uid}.role` field to the user's highest-priority
  /// active title. Firestore and Storage rules resolve authorization from this
  /// single `role` field, so without this sync a title change would show in the
  /// UI but be denied server-side with `permission-denied` /
  /// `firebase_storage/unauthorized`.
  ///
  /// The computation is authoritative in BOTH directions (Çakışma #4 fix):
  ///  * It looks at `activeTitles` (isActive == true) and picks the role with
  ///    the highest priority in [_rolePriority] — admin > board_president >
  ///    board_member > captain > unit_lead > member.
  ///  * It then writes that role unconditionally (`role` is set EXACTLY to the
  ///    computed value). Retiring/removing a title therefore DOWNGRADES `role`
  ///    just as reliably as adding one upgrades it, so the backend rules always
  ///    see the true highest active role.
  ///  * If the user has no privileged active title left, `role` becomes
  ///    `member`.
  ///
  /// Public so the multi-role editor can call it AFTER writing `role: 'member'`
  /// when a global title is removed: the remaining privileged titles (e.g. a
  /// `board_member` title staying while `admin` is removed) then re-promote
  /// `role` to the correct value.
  ///
  /// Note: `honorary_member` has no entry in [_rolePriority] (it grants no
  /// privileges), so it never raises `role`.
  Future<void> reconcileRole(String uid) async {
    try {
      final snap = await _users().doc(uid).get();
      if (!snap.exists) return;
      final data = snap.data()!;
      final currentRole = data['role'] as String? ?? TitleType.member;

      final activeTitles = _titlesFromData(data).where((t) => t.isActive);
      var newRole = TitleType.member;
      for (final candidate in _rolePriority) {
        if (activeTitles.any((t) => t.titleType == candidate)) {
          newRole = candidate;
          break;
        }
      }

      // Enforce the computed role in both directions (upgrade AND downgrade).
      if (newRole != currentRole) {
        await _users().doc(uid).update({'role': newRole});
      }
    } catch (_) {
      // Best-effort: never let a failed role sync break the title operation.
    }
  }

  /// Decodes the persisted `titles` list into [UserTitle] objects.
  List<UserTitle> _titlesFromData(Map<String, dynamic> data) {
    final raw = data['titles'] as List? ?? const [];
    return raw
        .map((e) => UserTitle.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

/// Riverpod provider for the title service.
final userTitleServiceProvider = Provider<UserTitleService>((ref) {
  return UserTitleService(ref.watch(firestoreProvider));
});