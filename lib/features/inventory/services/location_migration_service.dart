import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../models/depo_models.dart';

/// Summary of what a migration would do, shown to the user before running it.
class LocationMigrationPlan {
  final List<LocationCategory> categories;
  final Map<String, List<DepoLocation>> categorized;
  final List<DepoLocation> unmatched;

  const LocationMigrationPlan({
    required this.categories,
    required this.categorized,
    required this.unmatched,
  });

  int get total => categorized.values.fold(0, (n, l) => n + l.length);
}

/// Determines and runs the one-time migration of existing `depo_lokasyonlar`
/// into `location_categories`.
///
/// Strategy (keyword matching):
///   * "top"/"toplantı" → Toplantı Salonu
///   * "atöl"/"atolye"  → Atölye
///   * "depo"           → Depo
///   * anything else    → Depo (as a generic sub-location)
///
/// Before touching anything, ALL existing locations are backed up to
/// `locations_backup_pre_migration`. Three categories are seeded if missing.
class LocationMigrationService {
  final FirebaseFirestore _firestore;

  LocationMigrationService(this._firestore);

  /// Returns a migration plan without writing anything.
  Future<LocationMigrationPlan> plan() async {
    final catSnap = await _firestore
        .collection('location_categories')
        .orderBy('order')
        .get();
    var categories =
        catSnap.docs.map((d) => LocationCategory.fromDoc(d)).toList();
    if (categories.isEmpty) {
      categories = _defaultCategories;
    }

    final locSnap = await _firestore.collection('depo_lokasyonlar').get();
    final locations =
        locSnap.docs.map((d) => DepoLocation.fromDoc(d)).toList();

    final categorized = <String, List<DepoLocation>>{};
    for (final c in categories) {
      categorized[c.id] = [];
    }
    final unmatched = <DepoLocation>[];

    for (final loc in locations) {
      final matched = _matchCategory(loc.name, categories);
      if (matched != null) {
        categorized[matched.id]!.add(loc);
      } else {
        unmatched.add(loc);
      }
    }

    return LocationMigrationPlan(
      categories: categories,
      categorized: categorized,
      unmatched: unmatched,
    );
  }

  /// Backs up, seeds categories, reassigns locations, and re-links the three
  /// top-level locations as parents for sub-locations. Returns the number of
  /// locations migrated.
  Future<int> run() async {
    final migrationPlan = await plan();

    // 1. Backup all existing locations.
    final locSnap = await _firestore.collection('depo_lokasyonlar').get();
    final batch = _firestore.batch();
    for (final doc in locSnap.docs) {
      batch.set(
        _firestore
            .collection('locations_backup_pre_migration')
            .doc(doc.id),
        doc.data(),
      );
    }
    await batch.commit();

    // 2. Seed categories if missing (by name).
    final cats = _firestore.collection('location_categories');
    final existingSnap = await cats.get();
    final existing = existingSnap.docs.map((d) => LocationCategory.fromDoc(d)).toList();

    final catById = <String, LocationCategory>{};
    for (final c in existing) {
      catById[c.name] = c;
    }
    var order = existing.length;
    for (final def in _defaultCategories) {
      if (!catById.containsKey(def.name)) {
        final ref = await cats.add({
          'name': def.name,
          'order': order++,
          'createdAt': FieldValue.serverTimestamp(),
        });
        catById[def.name] = LocationCategory(id: ref.id, name: def.name, order: order);
      }
    }

    // 3. Assign each location to a category. Unmatched → Depo.
    final depoCat = catById['Depo'];
    final b2 = _firestore.batch();
    var migrated = 0;
    for (final loc in _allLocations(migrationPlan)) {
      final cat = _matchCategory(loc.name, catById.values.toList()) ?? depoCat;
      final depoRef = _firestore.collection('depo_lokasyonlar').doc(loc.id);
      if (loc.categoryId != cat?.id) {
        b2.update(depoRef, {
          'categoryId': cat?.id,
          'categoryName': cat?.name,
        });
        migrated++;
      }
    }
    await b2.commit();

    // 4. For each category, link the first location as the "parent" of the rest
    //    so sub-locations nest under it (e.g. "Depo > Raf A").
    final b3 = _firestore.batch();
    for (final entry in migrationPlan.categorized.entries) {
      final list = entry.value;
      if (list.isEmpty) continue;
      final parent = list.first;
      // Ensure the parent is not nested under anything.
      b3.update(_firestore.collection('depo_lokasyonlar').doc(parent.id), {
        'parentId': FieldValue.delete(),
      });
      for (final loc in list.skip(1)) {
        b3.update(_firestore.collection('depo_lokasyonlar').doc(loc.id), {
          'parentId': parent.id,
        });
      }
    }
    if (migrationPlan.unmatched.isNotEmpty) {
      final depo = migrationPlan.categorized[depoCat?.id];
      final depoParent = depo != null && depo.isNotEmpty ? depo.first : null;
      for (final loc in migrationPlan.unmatched) {
        if (depoParent != null && depoParent.id != loc.id) {
          b3.update(_firestore.collection('depo_lokasyonlar').doc(loc.id), {
            'parentId': depoParent.id,
          });
        }
      }
    }
    await b3.commit();

    return migrated;
  }

  static final List<LocationCategory> _defaultCategories = [
    const LocationCategory(id: 'toplanti', name: 'Toplantı Salonu', order: 0),
    const LocationCategory(id: 'atolye', name: 'Atölye', order: 1),
    const LocationCategory(id: 'depo', name: 'Depo', order: 2),
  ];

  LocationCategory? _matchCategory(
      String name, List<LocationCategory> categories) {
    final n = name.toLowerCase().replaceAll('ş', 's').replaceAll('ö', 'o');
    for (final c in categories) {
      final cn = c.name.toLowerCase().replaceAll('ş', 's').replaceAll('ö', 'o');
      if (cn.contains('depo') && n.contains('depo')) return c;
      if (cn.contains('atolye') &&
          (n.contains('atolye') || n.contains('atöl') || n.contains('atol'))) {
        return c;
      }
      if (cn.contains('toplanti') &&
          (n.contains('toplanti') || n.contains('toplant') || n.contains('top'))) {
        return c;
      }
    }
    return null;
  }

  List<DepoLocation> _allLocations(LocationMigrationPlan plan) {
    final list = <DepoLocation>[];
    for (final l in plan.categorized.values) {
      list.addAll(l);
    }
    list.addAll(plan.unmatched);
    return list;
  }
}

final locationMigrationServiceProvider = Provider<LocationMigrationService>(
    (ref) => LocationMigrationService(ref.watch(firestoreProvider)));