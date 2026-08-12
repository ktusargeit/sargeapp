import 'package:cloud_firestore/cloud_firestore.dart';

/// A hierarchical category within a team's unit.
class InventoryCategory {
  final String id;
  final String teamId;
  final String unitId;
  final String name;
  final DateTime? createdAt;

  const InventoryCategory({
    required this.id,
    required this.teamId,
    required this.unitId,
    required this.name,
    this.createdAt,
  });

  factory InventoryCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return InventoryCategory(
      id: doc.id,
      teamId: data['teamId'] as String? ?? '',
      unitId: data['unitId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// A user-defined inventory status option.
class InventoryStatus {
  final String id;
  final String label;
  final int order;

  const InventoryStatus({
    required this.id,
    required this.label,
    this.order = 0,
  });

  factory InventoryStatus.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return InventoryStatus(
      id: doc.id,
      label: data['label'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// An inventory item stored in the depo.
class DepoItem {
  final String id;
  final String name;
  final String? description;
  final String? teamId;
  final String? unitId;
  final String? categoryId;
  final String? categoryName;
  final String? serialNumber;
  final String? model;
  final String? brand;
  final int? quantity;
  final String? locationId;
  final String? locationName;
  final String? shelfName;
  final String? drawerName;
  final String? imageUrl;
  final String? locationImageUrl;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const DepoItem({
    required this.id,
    required this.name,
    this.description,
    this.teamId,
    this.unitId,
    this.categoryId,
    this.categoryName,
    this.serialNumber,
    this.model,
    this.brand,
    this.quantity,
    this.locationId,
    this.locationName,
    this.shelfName,
    this.drawerName,
    this.imageUrl,
    this.locationImageUrl,
    this.status = 'available',
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory DepoItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DepoItem(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      teamId: data['teamId'] as String?,
      unitId: data['unitId'] as String?,
      categoryId: data['categoryId'] as String?,
      categoryName: data['categoryName'] as String?,
      serialNumber: data['serialNumber'] as String?,
      model: data['model'] as String?,
      brand: data['brand'] as String?,
      quantity: (data['quantity'] as num?)?.toInt(),
      locationId: data['locationId'] as String?,
      locationName: data['locationName'] as String?,
      shelfName: data['shelfName'] as String?,
      drawerName: data['drawerName'] as String?,
      imageUrl: data['imageUrl'] as String?,
      locationImageUrl: data['locationImageUrl'] as String?,
      status: data['status'] as String? ?? 'available',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
    );
  }
}

/// A storage location within the depo.
class DepoLocation {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final DateTime? createdAt;

  const DepoLocation({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.createdAt,
  });

  factory DepoLocation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DepoLocation(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}