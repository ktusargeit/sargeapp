import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sarge_depo_app/core/services/imgbb_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/image_utils.dart';
import '../models/depo_models.dart';

/// Stream of all inventory items.
final inventoryItemsProvider = StreamProvider<List<DepoItem>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('depo_urunler')
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map((d) => DepoItem.fromDoc(d)).toList());
});

/// Stream of all depo locations.
final locationsProvider = StreamProvider<List<DepoLocation>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('depo_lokasyonlar')
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map((d) => DepoLocation.fromDoc(d)).toList());
});

/// Stream of warehouse location categories (Toplantı Salonu / Atölye / Depo).
final locationCategoriesProvider =
    StreamProvider<List<LocationCategory>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('location_categories')
      .orderBy('order')
      .snapshots()
      .map(
          (snap) => snap.docs.map((d) => LocationCategory.fromDoc(d)).toList());
});

/// Stream of inventory categories (hierarchical: team → unit → category).
final inventoryCategoriesProvider =
    StreamProvider<List<InventoryCategory>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('inventory_categories')
      .orderBy('name')
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => InventoryCategory.fromDoc(d)).toList());
});

/// Stream of user-defined inventory status options.
final inventoryStatusesProvider = StreamProvider<List<InventoryStatus>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('inventory_statuses')
      .orderBy('order')
      .snapshots()
      .map((snap) => snap.docs.map((d) => InventoryStatus.fromDoc(d)).toList());
});

/// Stream of all teams (for dropdown selection).
final teamListProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('teams')
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map((d) {
            final data = d.data();
            return {'id': d.id, 'name': data['name'] as String? ?? ''};
          }).toList());
});

/// Stream of units (filtered by teamId, for dropdown selection).
final unitsByTeamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String?>((ref, teamId) {
  final firestore = ref.watch(firestoreProvider);
  if (teamId == null || teamId.isEmpty) {
    return const Stream.empty();
  }
  return firestore
      .collection('units')
      .where('teamId', isEqualTo: teamId)
      .snapshots()
      .map((snap) => snap.docs.map((d) {
            final data = d.data();
            return {'id': d.id, 'name': data['name'] as String? ?? ''};
          }).toList());
});

class DepoRepository {
  final FirebaseFirestore _firestore;

  DepoRepository(this._firestore);

  Future<void> addItem(Map<String, dynamic> data,
      {File? imageFile,
      Uint8List? imageBytes,
      File? locationFile,
      Uint8List? locationBytes}) async {
    final docRef = _firestore.collection('depo_urunler').doc();

    // Parallel image uploads
    final uploads = <Future<String?>>[];
    if (imageFile != null || imageBytes != null) {
      uploads.add(_uploadImage('depo_urunler/${docRef.id}_main.jpg',
          file: imageFile, bytes: imageBytes));
    } else {
      uploads.add(Future.value(null));
    }
    if (locationFile != null || locationBytes != null) {
      uploads.add(_uploadImage('depo_urunler/${docRef.id}_location.jpg',
          file: locationFile, bytes: locationBytes));
    } else {
      uploads.add(Future.value(null));
    }

    final results = await Future.wait(uploads);
    if (results[0] != null) data['imageUrl'] = results[0];
    if (results[1] != null) data['locationImageUrl'] = results[1];

    data['createdAt'] = FieldValue.serverTimestamp();
    await docRef.set(data);
  }

  Future<void> updateItem(String id, Map<String, dynamic> data,
      {File? imageFile,
      Uint8List? imageBytes,
      File? locationFile,
      Uint8List? locationBytes}) async {
    // Parallel image uploads
    final uploads = <Future<String?>>[];
    if (imageFile != null || imageBytes != null) {
      uploads.add(_uploadImage('depo_urunler/${id}_main.jpg',
          file: imageFile, bytes: imageBytes));
    } else {
      uploads.add(Future.value(null));
    }
    if (locationFile != null || locationBytes != null) {
      uploads.add(_uploadImage('depo_urunler/${id}_location.jpg',
          file: locationFile, bytes: locationBytes));
    } else {
      uploads.add(Future.value(null));
    }

    final results = await Future.wait(uploads);
    if (results[0] != null) data['imageUrl'] = results[0];
    if (results[1] != null) data['locationImageUrl'] = results[1];

    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('depo_urunler').doc(id).update(data);
  }

  Future<void> deleteItem(String id) async {
    await _firestore.collection('depo_urunler').doc(id).delete();
  }

  Future<String> _uploadImage(String path,
      {File? file, Uint8List? bytes}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint(
        '[depo-upload] path=$path uid=$uid hasFile=${file != null} hasBytes=${bytes != null}');

    if (uid == null) {
      throw Exception(
          'Görsel yüklenemedi: oturum bilgisi bulunamadı. Lütfen çıkış yapıp tekrar giriş yapın.');
    }

    try {
      final compressed = await _compressedBytes(file: file, bytes: bytes);
      Uint8List? finalBytes;
      if (compressed.isNotEmpty) {
        finalBytes = compressed;
      } else if (bytes != null) {
        finalBytes = bytes;
      } else if (file != null) {
        finalBytes = await file.readAsBytes();
      }
      
      if (finalBytes == null) {
        throw Exception('No image data provided');
      }

      final fileName = path.split('/').last;
      final url = await ImgbbService.uploadImage(finalBytes, fileName: fileName);
      if (url == null) {
        throw Exception('ImgBB upload failed');
      }
      debugPrint('[depo-upload] OK path=$path');
      return url;
    } catch (e, st) {
      debugPrint(
          '[depo-upload] FAILED path=$path uid=$uid error=$e\n$st');
      rethrow;
    }
  }

  /// Reads [file]/[bytes] and returns JPEG bytes ≤1280px wide; empty if no data.
  Future<Uint8List> _compressedBytes({File? file, Uint8List? bytes}) async {
    try {
      final PickedImage img;
      if (file != null) {
        img = PickedImage(dartFile: file);
      } else if (bytes != null) {
        img = PickedImage(bytes: bytes);
      } else {
        return Uint8List(0);
      }
      return await img.compressedUploadBytes();
    } catch (_) {
      return Uint8List(0);
    }
  }

  // Category CRUD
  Future<void> addCategory(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('inventory_categories').add(data);
  }

  Future<void> updateCategory(String id, Map<String, dynamic> data) async {
    await _firestore.collection('inventory_categories').doc(id).update(data);
  }

  Future<void> deleteCategory(String id) async {
    await _firestore.collection('inventory_categories').doc(id).delete();
  }

  // Status CRUD
  Future<void> addStatus(Map<String, dynamic> data) async {
    await _firestore.collection('inventory_statuses').add(data);
  }

  Future<void> updateStatus(String id, Map<String, dynamic> data) async {
    await _firestore.collection('inventory_statuses').doc(id).update(data);
  }

  Future<void> deleteStatus(String id) async {
    await _firestore.collection('inventory_statuses').doc(id).delete();
  }

  // Location CRUD
  Future<void> addLocation(DepoLocation location,
      {File? file, Uint8List? bytes}) async {
    String? imageUrl = location.imageUrl;
    if ((file != null || bytes != null) && location.id.isNotEmpty) {
      Uint8List? imageBytes = bytes;
      if (imageBytes == null && file != null) {
        imageBytes = await file.readAsBytes();
      }
      if (imageBytes != null) {
        final url = await ImgbbService.uploadImage(imageBytes, fileName: '${location.id}.jpg');
        if (url != null) {
          imageUrl = url;
        }
      }
    }
    await _firestore.collection('depo_lokasyonlar').add({
      'name': location.name,
      'description': location.description,
      'imageUrl': imageUrl,
      'categoryId': location.categoryId,
      'categoryName': location.categoryName,
      'parentId': location.parentId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteLocation(String id) async {
    await _firestore.collection('depo_lokasyonlar').doc(id).delete();
  }

  /// Creates a new location with only a name (no image).
  Future<void> addLocationByName(String name) async {
    await _firestore.collection('depo_lokasyonlar').add({
      'name': name.trim(),
      'description': null,
      'imageUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Renames an existing location.
  Future<void> updateLocationName(String id, String name) async {
    await _firestore
        .collection('depo_lokasyonlar')
        .doc(id)
        .update({'name': name.trim()});
  }

  /// Moves a location into a category (also stores the denormalized name).
  Future<void> setLocationCategory(
      String id, String? categoryId, String? categoryName) async {
    await _firestore.collection('depo_lokasyonlar').doc(id).update({
      'categoryId': categoryId,
      'categoryName': categoryName,
    });
  }

  /// Sets a location's parent (sub-location relationship).
  Future<void> setLocationParent(String id, String? parentId) async {
    await _firestore.collection('depo_lokasyonlar').doc(id).update({
      'parentId': parentId,
    });
  }

  /// Number of products currently assigned to [locationId].
  Future<int> countItemsInLocation(String locationId) async {
    final snap = await _firestore
        .collection('depo_urunler')
        .where('locationId', isEqualTo: locationId)
        .count()
        .get();
    return snap.count ?? 0;
  }

  // Location category CRUD
  Future<void> addCategoryByName(String name, {int order = 0}) async {
    await _firestore.collection('location_categories').add({
      'name': name.trim(),
      'order': order,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCategoryName(String id, String name) async {
    await _firestore
        .collection('location_categories')
        .doc(id)
        .update({'name': name.trim()});
  }

  Future<void> deleteLocationCategory(String id) async {
    await _firestore.collection('location_categories').doc(id).delete();
  }

  /// Number of locations currently assigned to [categoryId].
  Future<int> countLocationsInCategory(String categoryId) async {
    final snap = await _firestore
        .collection('depo_lokasyonlar')
        .where('categoryId', isEqualTo: categoryId)
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// Number of locations whose `parentId` points at [locationId].
  Future<int> countSubLocations(String locationId) async {
    final snap = await _firestore
        .collection('depo_lokasyonlar')
        .where('parentId', isEqualTo: locationId)
        .count()
        .get();
    return snap.count ?? 0;
  }
}

final depoRepositoryProvider = Provider<DepoRepository>((ref) {
  return DepoRepository(ref.watch(firestoreProvider));
});
