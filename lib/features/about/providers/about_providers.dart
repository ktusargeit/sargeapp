import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../models/about_models.dart';

final aboutSectionsProvider = StreamProvider<List<AboutSection>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('aboutSections')
      .orderBy('order')
      .snapshots()
      .map((snap) => snap.docs.map((d) => AboutSection.fromMap(d.id, d.data())).toList());
});

final aboutMembersProvider = StreamProvider<List<AboutMember>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('aboutMembers')
      .snapshots()
      .map((snap) => snap.docs.map((d) => AboutMember.fromMap(d.id, d.data())).toList());
});

class AboutRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AboutRepository(this._firestore) : _storage = FirebaseStorage.instance;

  Future<void> upsertSection(AboutSection section) async {
    if (section.id.isEmpty) {
      await _firestore.collection('aboutSections').add(section.toMap());
    } else {
      await _firestore.collection('aboutSections').doc(section.id).update(section.toMap());
    }
  }

  Future<void> deleteSection(String id) async {
    await _firestore.collection('aboutSections').doc(id).delete();
  }

  Future<void> addMember(AboutMember member) async {
    await _firestore.collection('aboutMembers').doc(member.id).set(member.toMap());
  }

  Future<void> updateMember(String id, Map<String, dynamic> data) async {
    await _firestore.collection('aboutMembers').doc(id).update(data);
  }

  Future<void> deleteMember(String id, {String? photoUrl}) async {
    await _firestore.collection('aboutMembers').doc(id).delete();
    if (photoUrl != null) {
      try {
        await _storage.refFromURL(photoUrl).delete();
      } catch (_) {}
    }
  }

  Future<String> uploadMemberPhoto(String memberId,
      {File? file, Uint8List? bytes}) async {
    final ref = _storage.ref().child('about_members/$memberId.jpg');
    if (kIsWeb && bytes != null) {
      await ref.putData(bytes);
    } else if (file != null) {
      await ref.putFile(file);
    }
    return ref.getDownloadURL();
  }
}

final aboutRepositoryProvider = Provider<AboutRepository>((ref) {
  return AboutRepository(ref.watch(firestoreProvider));
});