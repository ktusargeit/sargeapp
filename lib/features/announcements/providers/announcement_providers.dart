import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../models/announcement_models.dart';

/// Stream of all announcements, newest first.
final announcementsProvider = StreamProvider<List<Announcement>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('announcements')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Announcement.fromDoc(d)).toList());
});

class AnnouncementRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AnnouncementRepository(this._firestore) : _storage = FirebaseStorage.instance;

  Future<void> addAnnouncement({
    required String title,
    required String description,
    String? imageUrl,
    DateTime? eventDate,
    required String createdBy,
    String createdByName = '',
    bool notifyAll = false,
  }) async {
    await _firestore.collection('announcements').add({
      'title': title.trim(),
      'description': description.trim(),
      'imageUrl': imageUrl,
      'eventDate': eventDate != null ? Timestamp.fromDate(eventDate) : null,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'notifyAll': notifyAll,
    });
  }

  Future<void> updateAnnouncement(
    String id, {
    String? title,
    String? description,
    String? imageUrl,
    DateTime? eventDate,
    bool? notifyAll,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title.trim();
    if (description != null) updates['description'] = description.trim();
    if (imageUrl != null) updates['imageUrl'] = imageUrl;
    if (eventDate != null) updates['eventDate'] = Timestamp.fromDate(eventDate);
    if (notifyAll != null) updates['notifyAll'] = notifyAll;
    if (updates.isNotEmpty) {
      await _firestore.collection('announcements').doc(id).update(updates);
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    await _firestore.collection('announcements').doc(id).delete();
  }

  Future<String> uploadImage(String announcementId,
      {File? file, Uint8List? bytes}) async {
    // ── DEBUG: User identity ──
    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('═══ [DEBUG uploadImage] ═══');
    debugPrint('[DEBUG] currentUser.uid: $uid');

    // ── DEBUG: Fetch user role from Firestore ──
    if (uid != null) {
      try {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          debugPrint('[DEBUG] Firestore users/$uid data: ${userDoc.data()}');
          debugPrint('[DEBUG] Firestore users/$uid role: ${userDoc.data()?['role']}');
        } else {
          debugPrint('[DEBUG] Firestore users/$uid doc DOES NOT EXIST');
        }
      } catch (e) {
        debugPrint('[DEBUG] ERROR reading Firestore user doc: $e');
      }
    } else {
      debugPrint('[DEBUG] uid is NULL — user is NOT signed in!');
    }

    // ── DEBUG: Storage path ──
    final storagePath = 'announcements/$announcementId.jpg';
    debugPrint('[DEBUG] Storage path: $storagePath');
    final ref = _storage.ref().child(storagePath);

    // ── Upload with try/catch ──
    try {
      if (kIsWeb && bytes != null) {
        debugPrint('[DEBUG] Uploading via putData (web, ${bytes.length} bytes)');
        await ref.putData(bytes);
      } else if (file != null) {
        debugPrint('[DEBUG] Uploading via putFile: ${file.path}');
        await ref.putFile(file);
      } else {
        throw Exception('No image data provided');
      }
      debugPrint('[DEBUG] Upload SUCCESS, getting download URL...');
      final url = await ref.getDownloadURL();
      debugPrint('[DEBUG] Download URL: $url');
      debugPrint('═══ [DEBUG uploadImage] END ═══');
      return url;
    } catch (e, st) {
      debugPrint('[DEBUG] ⛔ UPLOAD FAILED: $e');
      debugPrint('[DEBUG] Stack trace: $st');
      debugPrint('═══ [DEBUG uploadImage] END (ERROR) ═══');
      rethrow;
    }
  }
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(ref.watch(firestoreProvider));
});