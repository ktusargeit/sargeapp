import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/providers/auth_providers.dart';

const _uuid = Uuid();

/// Service for managing the `users/{uid}/titles` array.
///
/// Titles can be added, "retired" (marked as former) or completely removed.
/// The legacy `role` field is intentionally left untouched so that existing
/// permission checks (`isAdmin`, `isUnitLead`) keep working exactly as before;
/// `titles` provides the richer, historical view.
class UserTitleService {
  final FirebaseFirestore _firestore;

  UserTitleService(this._firestore);

  CollectionReference<Map<String, dynamic>> _users() =>
      _firestore.collection('users');

  /// A stable, ordered list of selectable titles for the admin UI.
  static const List<Map<String, String>> titleOptions = [
    {'type': TitleType.boardPresident, 'label': 'Yönetim Kurulu Başkanı'},
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
    return retired;
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