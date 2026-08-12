import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
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
final inventoryStatusesProvider =
    StreamProvider<List<InventoryStatus>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('inventory_statuses')
      .orderBy('order')
      .snapshots()
      .map(
          (snap) => snap.docs.map((d) => InventoryStatus.fromDoc(d)).toList());
});

/// Stream of all teams (for dropdown selection).
final teamListProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
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
  final FirebaseStorage _storage;

  DepoRepository(this._firestore) : _storage = FirebaseStorage.instance;

  Future<void> addItem(Map<String, dynamic> data,
      {File? imageFile,
      Uint8List? imageBytes,
      File? locationFile,
      Uint8List? locationBytes}) async {
    final docRef = _firestore.collection('depo_urunler').doc();

    // Parallel image uploads
    final uploads = <Future<String?>>[];
    if (imageFile != null || imageBytes != null) {
      uploads.add(_uploadImage(
          'depo_urunler/${docRef.id}_main.jpg',
          file: imageFile,
          bytes: imageBytes));
    } else {
      uploads.add(Future.value(null));
    }
    if (locationFile != null || locationBytes != null) {
      uploads.add(_uploadImage(
          'depo_urunler/${docRef.id}_location.jpg',
          file: locationFile,
          bytes: locationBytes));
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
    final ref = _storage.ref().child(path);
    if (kIsWeb && bytes != null) {
      await ref.putData(bytes);
    } else if (file != null) {
      await ref.putFile(file);
    }
    return ref.getDownloadURL();
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
      final ref = _storage.ref().child('depo_lokasyonlar/${location.id}.jpg');
      if (kIsWeb && bytes != null) {
        await ref.putData(bytes);
      } else if (file != null) {
        await ref.putFile(file);
      }
      imageUrl = await ref.getDownloadURL();
    }
    await _firestore.collection('depo_lokasyonlar').add({
      'name': location.name,
      'description': location.description,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteLocation(String id) async {
    await _firestore.collection('depo_lokasyonlar').doc(id).delete();
  }
}

final depoRepositoryProvider = Provider<DepoRepository>((ref) {
  return DepoRepository(ref.watch(firestoreProvider));
});