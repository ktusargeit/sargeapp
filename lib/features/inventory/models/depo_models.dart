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

  factory InventoryCategory.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
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

/// A fixed warehouse location category (Toplantı Salonu / Atölye / Depo).
///
/// Categories are NOT hard-coded — they live in the `location_categories`
/// collection so an admin/kaptan can add, rename, or remove them. This was
/// intentionally chosen (per product decision) instead of baking the 3 names
/// into the client.
class LocationCategory {
  final String id;
  final String name;
  final int order;
  final DateTime? createdAt;

  const LocationCategory({
    required this.id,
    required this.name,
    this.order = 0,
    this.createdAt,
  });

  factory LocationCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return LocationCategory(
      id: doc.id,
      name: data['name'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
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
  final String? locationCategoryId;
  final String? locationCategoryName;
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
    this.locationCategoryId,
    this.locationCategoryName,
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
      locationCategoryId: data['locationCategoryId'] as String?,
      locationCategoryName: data['locationCategoryName'] as String?,
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
///
/// Locations belong to a [categoryId] (a `LocationCategory`). A location may
/// also have a [parentId] pointing at another location, which models
/// sub-locations/shelves such as "Depo > Raf A".
class DepoLocation {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? categoryId;
  final String? categoryName;
  final String? parentId;
  final DateTime? createdAt;

  const DepoLocation({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.categoryId,
    this.categoryName,
    this.parentId,
    this.createdAt,
  });

  factory DepoLocation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DepoLocation(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
      categoryId: data['categoryId'] as String?,
      categoryName: data['categoryName'] as String?,
      parentId: data['parentId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
