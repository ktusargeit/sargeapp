import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sarge_depo_app/core/services/imgbb_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_system.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/image_utils.dart';
import '../models/store_models.dart';

/// Stream of all store products, newest first.
final storeProductsProvider = StreamProvider<List<StoreProduct>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('store_products')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => StoreProduct.fromDoc(d)).toList());
});

/// Stream of store settings (IBAN list).
final storeSettingsProvider = StreamProvider<StoreSettings>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('store_meta')
      .doc('settings')
      .snapshots()
      .map((doc) => StoreSettings.fromDoc(doc));
});

/// Stream of ALL orders (manager view only).
///
/// The `orders` collection is restricted by firestore.rules to the owner or a
/// `manageStore` holder, so a non-manager must NOT query it without a `userId`
/// filter (that would fail the whole query with `permission-denied`). For
/// non-managers we return an empty stream so the orders screen never errors.
final allOrdersProvider = StreamProvider<List<StoreOrder>>((ref) {
  final canManage = ref.watch(currentUserCanProvider(Permissions.manageStore));
  if (!canManage) return Stream.value(const <StoreOrder>[]);
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => StoreOrder.fromDoc(d)).toList());
});

/// Stream of the current user's orders only.
final myOrdersProvider = StreamProvider<List<StoreOrder>>((ref) {
  final authState = ref.watch(authStateProvider);
  // `.valueOrNull` — `.value` RETHROWS on error state and would abort the
  // build of whatever widget reads this provider.
  final uid = authState.valueOrNull?.uid;
  if (uid == null) return Stream.value(const <StoreOrder>[]);
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('orders')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snap) {
    final list = snap.docs.map((d) => StoreOrder.fromDoc(d)).toList();
    // Sort client-side (newest first) to avoid a composite index on
    // (userId + createdAt).
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

/// A picked PDF file (receipt/dekont).
///
/// Only `bytes` is stored (always populated via `withData: true`), because on
/// the web the `path` property is unavailable and throws when accessed.
class PickedPdf {
  final Uint8List bytes;
  final String name;

  const PickedPdf({required this.bytes, required this.name});
}

/// Store repository: product CRUD + orders + settings (IBAN management).
class StoreRepository {
  final FirebaseFirestore _firestore;

  StoreRepository(this._firestore);

  // ── Products ───────────────────────────────────────────────────────────────

  /// Creates a product. [images] are compressed and uploaded to Storage.
  ///
  /// [price] is the numeric value extracted from the free-text [priceDisplay]
  /// (used for any sorting/comparison), while [priceDisplay] keeps the exact
  /// text the user typed (e.g. "50 TL", "50₺").
  Future<void> addProduct({
    required String name,
    required double price,
    required String priceDisplay,
    required String description,
    required bool inStock,
    required List<PickedImage> images,
    String? createdBy,
  }) async {
    final docRef = _firestore.collection('store_products').doc();

    // Upload all images in parallel (first = cover).
    final urls = await _uploadImages('store_products/${docRef.id}', images);

    await docRef.set({
      'name': name.trim(),
      'price': price,
      'priceDisplay': priceDisplay,
      'description': description.trim(),
      'imageUrls': urls,
      'inStock': inStock,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates an existing product. New images are uploaded and appended.
  Future<void> updateProduct({
    required String productId,
    required String name,
    required double price,
    required String priceDisplay,
    required String description,
    required bool inStock,
    required List<String> existingImageUrls,
    required List<PickedImage> newImages,
  }) async {
    // Upload any new images (parallel).
    final newUrls = await _uploadImages('store_products/$productId', newImages);
    final allUrls = [...existingImageUrls, ...newUrls];

    await _firestore.collection('store_products').doc(productId).update({
      'name': name.trim(),
      'price': price,
      'priceDisplay': priceDisplay,
      'description': description.trim(),
      'imageUrls': allUrls,
      'inStock': inStock,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String productId) async {
    await _firestore.collection('store_products').doc(productId).delete();
  }

  // ── Orders ─────────────────────────────────────────────────────────────────

  /// Creates a new order with a receipt PDF uploaded to Storage.
  Future<String> createOrder({
    required String productId,
    required String productName,
    required double price,
    required String note,
    required PickedPdf receiptPdf,
    required String userId,
    required String userName,
  }) async {
    final docRef = _firestore.collection('orders').doc();

    final receiptUrl = await _uploadPdf(
      'store_receipts/${docRef.id}.pdf',
      receiptPdf,
    );

    await docRef.set({
      'userId': userId,
      'userName': userName,
      'productId': productId,
      'productName': productName,
      'price': price,
      'receiptUrl': receiptUrl,
      'note': note,
      'status': StoreOrderStatus.waitingPayment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Admin: update an order's status. Returns the new status.
  Future<String> updateOrderStatus(String orderId, String newStatus) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return newStatus;
  }

  // ── Settings (IBAN management) ─────────────────────────────────────────────

  /// Loads the current IBAN list.
  Future<List<IbanEntry>> loadIbans() async {
    final snap =
        await _firestore.collection('store_meta').doc('settings').get();
    final settings = StoreSettings.fromDoc(snap);
    return settings.ibans;
  }

  /// Saves the IBAN list (full replace).
  Future<void> saveIbans(List<IbanEntry> ibans) async {
    // Keep only non-empty trimmed values.
    final cleaned = ibans
        .where((e) => e.iban.trim().isNotEmpty)
        .map((e) => e.toMap())
        .toList();
    await _firestore.collection('store_meta').doc('settings').set({
      'ibans': cleaned,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Uploads ────────────────────────────────────────────────────────────────

  Future<List<String>> _uploadImages(
      String basePath, List<PickedImage> images) async {
    if (images.isEmpty) return const <String>[];
    final futures = <Future<String>>[];
    for (var i = 0; i < images.length; i++) {
      final img = images[i];
      futures.add(_uploadImage('${basePath}_$i.jpg', img));
    }
    return Future.wait(futures);
  }

  Future<String> _uploadImage(String path, PickedImage image) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint(
        '[store-upload] path=$path uid=$uid hasBytes=${image.bytes != null} hasFile=${image.dartFile != null}');

    if (uid == null) {
      throw Exception(
          'Görsel yüklenemedi: oturum bilgisi bulunamadı. Lütfen çıkış yapıp tekrar giriş yapın.');
    }

    try {
      final compressed = await image.compressedUploadBytes();
      Uint8List? finalBytes;
      if (compressed.isNotEmpty) {
        finalBytes = compressed;
      } else if (image.bytes != null) {
        finalBytes = image.bytes;
      } else if (image.dartFile != null) {
        finalBytes = await image.dartFile!.readAsBytes();
      }

      if (finalBytes == null) {
        throw Exception('No image data provided');
      }

      final fileName = path.split('/').last;
      final url = await ImgbbService.uploadImage(finalBytes, fileName: fileName);
      if (url == null) throw Exception('ImgBB upload failed');
      debugPrint('[store-upload] OK path=$path url=$url');
      return url;
    } catch (e, st) {
      debugPrint(
          '[store-upload] FAILED path=$path uid=$uid error=$e\n$st');
      rethrow;
    }
  }

  Future<String> _uploadPdf(String path, PickedPdf pdf) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint(
        '[receipt-upload] path=$path uid=$uid hasBytes=${pdf.bytes.isNotEmpty}');

    if (uid == null) {
      throw Exception(
          'Dekont yüklenemedi: oturum bilgisi bulunamadı. Lütfen çıkış yapıp tekrar giriş yapın.');
    }

    try {
      final fileName = path.split('/').last;
      final url = await ImgbbService.uploadImage(pdf.bytes, fileName: fileName);
      if (url == null) throw Exception('ImgBB upload failed');
      debugPrint('[receipt-upload] OK path=$path url=$url');
      return url;
    } catch (e, st) {
      debugPrint(
          '[receipt-upload] FAILED path=$path uid=$uid error=$e\n$st');
      rethrow;
    }
  }
}

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(ref.watch(firestoreProvider));
});

/// Picks a PDF file for a receipt/dekont.
/// Returns null if the user cancels, or throws if the file is not a PDF
/// or exceeds [maxBytes] (default 10 MB).
Future<PickedPdf?> pickReceiptPdf({int maxBytes = 10 * 1024 * 1024}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  final name = file.name.toLowerCase();
  if (!name.endsWith('.pdf')) {
    throw const FormatException('Lütfen sadece PDF dosyası yükleyin.');
  }
  if (file.size > maxBytes) {
    throw const FormatException(
        'Dosya boyutu 10MB sınırını aşıyor. Lütfen daha küçük bir PDF seçin.');
  }

  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    throw const FormatException(
        'PDF dosyası okunamadı. Lütfen tekrar deneyin.');
  }

  return PickedPdf(bytes: bytes, name: file.name);
}

/// Sends a notification to all users with `manageStore` permission
/// (or default: admin / board_president / board_member / captain / unit_lead).
class StoreNotifier {
  final FirebaseFirestore _firestore;

  StoreNotifier(this._firestore);

  Future<List<String>> _storeManagerUids() async {
    final snap = await _firestore.collection('users').get();
    final uids = <String>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final role = data['role'] as String? ?? 'member';
      // Default manageStore roles: admin, board_president,
      // board_vice_president, board_member, captain, unit_lead.
      // (Member lacks it by default.)
      if (const {
        'admin',
        'board_president',
        'board_vice_president',
        'board_member',
        'captain',
        'unit_lead',
      }.contains(role)) {
        uids.add(doc.id);
      }
    }
    return uids;
  }

  /// Notifies store managers that a new order was created.
  Future<void> notifyNewOrder({
    required String productName,
    required String userName,
    required String orderId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final managerUids = await _storeManagerUids();
    for (final managerUid in managerUids) {
      if (managerUid == uid) continue;
      await _firestore.collection('notifications').add({
        'recipientId': managerUid,
        'senderUid': uid,
        'senderName': userName,
        'title': 'Yeni sipariş var',
        'body': 'Yeni bir sipariş var: $productName - $userName',
        'type': 'store_order',
        'relatedId': orderId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Notifies the order owner that their order status changed.
  Future<void> notifyOrderStatusChanged({
    required String recipientId,
    required String productName,
    required String newStatus,
    required String orderId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _firestore.collection('notifications').add({
      'recipientId': recipientId,
      'senderUid': uid,
      'senderName': 'Mağaza',
      'title': 'Siparişiniz güncellendi',
      'body': 'Siparişiniz $productName artık: $newStatus',
      'type': 'store_order',
      'relatedId': orderId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

final storeNotifierProvider = Provider<StoreNotifier>((ref) {
  return StoreNotifier(ref.watch(firestoreProvider));
});
