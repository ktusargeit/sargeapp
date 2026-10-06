import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/services/imgbb_service.dart';
import '../models/about_models.dart';

final aboutSectionsProvider = StreamProvider<List<AboutSection>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('aboutSections').orderBy('order').snapshots().map(
      (snap) =>
          snap.docs.map((d) => AboutSection.fromMap(d.id, d.data())).toList());
});

final aboutMembersProvider = StreamProvider<List<AboutMember>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('aboutMembers').snapshots().map((snap) =>
      snap.docs.map((d) => AboutMember.fromMap(d.id, d.data())).toList());
});

class AboutRepository {
  final FirebaseFirestore _firestore;

  AboutRepository(this._firestore);

  Future<void> upsertSection(AboutSection section) async {
    if (section.id.isEmpty) {
      await _firestore.collection('aboutSections').add(section.toMap());
    } else {
      await _firestore
          .collection('aboutSections')
          .doc(section.id)
          .update(section.toMap());
    }
  }

  Future<void> deleteSection(String id) async {
    await _firestore.collection('aboutSections').doc(id).delete();
  }

  Future<void> addMember(AboutMember member) async {
    await _firestore
        .collection('aboutMembers')
        .doc(member.id)
        .set(member.toMap());
  }

  Future<void> updateMember(String id, Map<String, dynamic> data) async {
    await _firestore.collection('aboutMembers').doc(id).update(data);
  }

  Future<void> deleteMember(String id, {String? photoUrl}) async {
    await _firestore.collection('aboutMembers').doc(id).delete();
    // ImgBB doesn't support easy deletions by URL
  }

  Future<String> uploadMemberPhoto(String memberId,
      {File? file, Uint8List? bytes}) async {
    Uint8List? imageBytes = bytes;
    if (imageBytes == null && file != null) {
      imageBytes = await file.readAsBytes();
    }
    if (imageBytes == null) throw Exception('No image data provided');
    final imageUrl = await ImgbbService.uploadImage(imageBytes, fileName: '$memberId.jpg');
    if (imageUrl == null) throw Exception('Image upload failed');
    return imageUrl;
  }
}

final aboutRepositoryProvider = Provider<AboutRepository>((ref) {
  return AboutRepository(ref.watch(firestoreProvider));
});
