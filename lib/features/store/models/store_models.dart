import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// A product in the store.
class StoreProduct {
  final String id;
  final String name;
  final double price;
  final String description;
  final List<String> imageUrls;
  final bool inStock;
  final DateTime createdAt;
  final String? createdBy;

  /// Original, free-form price text as entered by the user (e.g. "50 TL",
  /// "50₺", "50"). Shown on the product card so the price keeps whatever unit
  /// or wording the manager typed.
  final String? priceDisplay;

  const StoreProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrls,
    required this.inStock,
    required this.createdAt,
    this.createdBy,
    this.priceDisplay,
  });

  String get coverImageUrl =>
      imageUrls.isNotEmpty ? imageUrls.first : '';

  /// The text to show for the price. Prefers the manager-provided
  /// [priceDisplay]; falls back to a numeric "₺50" so old rows still render.
  String get formattedPrice =>
      (priceDisplay != null && priceDisplay!.isNotEmpty)
          ? priceDisplay!
          : '₺${price.toStringAsFixed(0)}';

  factory StoreProduct.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawImages = data['imageUrls'];
    final images = rawImages is List
        ? rawImages.whereType<String>().toList()
        : <String>[];
    return StoreProduct(
      id: doc.id,
      name: data['name'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      description: data['description'] as String? ?? '',
      imageUrls: images,
      inStock: data['inStock'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdBy: data['createdBy'] as String?,
      priceDisplay: data['priceDisplay'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'priceDisplay': priceDisplay,
        'description': description,
        'imageUrls': imageUrls,
        'inStock': inStock,
        'createdBy': createdBy,
        'createdAt': createdAt,
      };
}

/// A customer order (decont/EFT based, no real payment integration).
class StoreOrder {
  final String id;
  final String userId;
  final String userName;
  final String productId;
  final String productName;
  final double price;
  final String receiptUrl;
  final String note;
  final String status;
  final DateTime createdAt;

  const StoreOrder({
    required this.id,
    required this.userId,
    required this.userName,
    required this.productId,
    required this.productName,
    required this.price,
    required this.receiptUrl,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  factory StoreOrder.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StoreOrder(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      receiptUrl: data['receiptUrl'] as String? ?? '',
      note: data['note'] as String? ?? '',
      status: data['status'] as String? ?? StoreOrderStatus.waitingPayment,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Store order statuses (flexible — driven by this list).
class StoreOrderStatus {
  static const String waitingPayment = 'Ödeme Bekleniyor';
  static const String approved = 'Onaylandı';
  static const String inProduction = 'Üretimde/Basımda';
  static const String shipped = 'Kargoya Verildi';
  static const String completed = 'Tamamlandı';
  static const String cancelled = 'İptal Edildi';

  static const List<String> all = [
    waitingPayment,
    approved,
    inProduction,
    shipped,
    completed,
    cancelled,
  ];

  /// Statuses that move forward (used for admin status transition buttons).
  static const List<String> forwardFlow = [
    waitingPayment,
    approved,
    inProduction,
    shipped,
    completed,
  ];

  static String label(String status) => status;

  /// Chip color for a status in the orders list.
  static (String label, Color color) statusVisual(String status) {
    switch (status) {
      case waitingPayment:
        return (status, const Color(0xFFF59E0B)); // warning amber
      case approved:
        return (status, const Color(0xFF35D07F)); // green
      case inProduction:
        return (status, const Color(0xFF3B82F6)); // blue
      case shipped:
        return (status, const Color(0xFF8B5CF6)); // purple
      case completed:
        return (status, const Color(0xFF10B981)); // teal/green
      case cancelled:
        return (status, const Color(0xFFEF4444)); // red
      default:
        return (status, const Color(0xFF94A3B8)); // gray
    }
  }
}

/// Store settings (IBAN list).
class StoreSettings {
  final List<String> ibans;

  const StoreSettings({this.ibans = const []});

  factory StoreSettings.fromDoc(DocumentSnapshot? doc) {
    if (doc == null || !doc.exists) return const StoreSettings();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final raw = data['ibans'];
    return StoreSettings(
      ibans: raw is List ? raw.whereType<String>().toList() : const [],
    );
  }

  Map<String, dynamic> toMap() => {'ibans': ibans};
}