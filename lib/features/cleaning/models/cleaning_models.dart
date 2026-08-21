import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Assignment types for a cleaning-rotation slot.
class CleaningAssignmentType {
  static const team = 'team';
  static const unit = 'unit';
  static const individual = 'individual';
  static const customGroup = 'custom_group';

  static const all = [team, unit, individual, customGroup];

  static String label(String type) {
    switch (type) {
      case team:
        return 'Takım';
      case unit:
        return 'Birim';
      case individual:
        return 'Tek Kişi';
      case customGroup:
        return 'Özel Grup';
      default:
        return type;
    }
  }
}

/// Date helpers for the weekly cleaning schedule.
///
/// A "week" is anchored to the Monday of the ISO week. `weekKey` is the
/// `YYYY-MM-DD` of that Monday, and doubles as the Firestore document id.
class CleaningDates {
  CleaningDates._();

  static final DateTime _epoch = DateTime(1970);

  /// Monday at 00:00 (local) of the week containing [date].
  static DateTime mondayOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final weekday = day.weekday; // 1 = Monday ... 7 = Sunday
    return day.subtract(Duration(days: weekday - 1));
  }

  static String keyOf(DateTime date) {
    final m = mondayOf(date);
    return '${m.year.toString().padLeft(4, '0')}-'
        '${m.month.toString().padLeft(2, '0')}-'
        '${m.day.toString().padLeft(2, '0')}';
  }

  static String keyOfMonday(DateTime monday) {
    return '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  static DateTime parseKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return _epoch;
    final y = int.tryParse(parts[0]) ?? 1970;
    final m = int.tryParse(parts[1]) ?? 1;
    final d = int.tryParse(parts[2]) ?? 1;
    return DateTime(y, m, d);
  }

  /// Number of whole weeks between two Monday dates.
  static int weeksBetween(DateTime earlierMonday, DateTime laterMonday) {
    return (laterMonday.difference(earlierMonday).inDays / 7).floor();
  }

  static String humanRange(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    // Turkish month names: "17 Ağustos - 23 Ağustos". `Intl.defaultLocale`
    // is set to 'tr_TR' on app startup (see main.dart).
    String fmt(DateTime d) => DateFormat('d MMMM', 'tr_TR').format(d);
    return '${fmt(weekStart)} - ${fmt(end)}';
  }
}

/// A single slot in the cleaning rotation.
class CleaningRotationSlot {
  final String id;
  final int order;
  final String assignmentType;
  final List<String> targetIds;
  final String? label;
  final DateTime? createdAt;

  const CleaningRotationSlot({
    required this.id,
    required this.order,
    required this.assignmentType,
    this.targetIds = const [],
    this.label,
    this.createdAt,
  });

  factory CleaningRotationSlot.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CleaningRotationSlot(
      id: doc.id,
      order: (data['order'] as num?)?.toInt() ?? 0,
      assignmentType: data['assignmentType'] as String? ?? 'individual',
      targetIds:
          (data['targetIds'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      label: data['label'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// An item on a week's shopping (alışveriş) list.
class CleaningItem {
  final String id;
  final String name;
  final bool done;
  final String? doneBy;
  final String? doneByName;
  final DateTime? doneAt;

  const CleaningItem({
    required this.id,
    required this.name,
    this.done = false,
    this.doneBy,
    this.doneByName,
    this.doneAt,
  });

  factory CleaningItem.fromMap(Map<String, dynamic> map) {
    return CleaningItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      done: map['done'] as bool? ?? false,
      doneBy: map['doneBy'] as String?,
      doneByName: map['doneByName'] as String?,
      doneAt: (map['doneAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'done': done,
        'doneBy': doneBy,
        'doneByName': doneByName,
        'doneAt': doneAt,
      };
}

/// A realized weekly schedule record.
///
/// [assignmentType]/[targetIds]/[label] are snapshotted from the rotation slot
/// used for this week. [overrideAssignmentType]/[overrideTargetIds]/
/// [overrideLabel], when set, supersede the snapshot (a manual override).
class CleaningSchedule {
  final String weekKey;
  final DateTime weekStart;
  final int slotOrder;

  final String assignmentType;
  final List<String> targetIds;
  final String? label;

  final String? overrideAssignmentType;
  final List<String> overrideTargetIds;
  final String? overrideLabel;

  final List<CleaningItem> items;
  final bool completed;
  final String? completedBy;
  final String? completedByName;
  final DateTime? completedAt;

  final DateTime? createdAt;

  const CleaningSchedule({
    required this.weekKey,
    required this.weekStart,
    this.slotOrder = 0,
    this.assignmentType = 'individual',
    this.targetIds = const [],
    this.label,
    this.overrideAssignmentType,
    this.overrideTargetIds = const [],
    this.overrideLabel,
    this.items = const [],
    this.completed = false,
    this.completedBy,
    this.completedByName,
    this.completedAt,
    this.createdAt,
  });

  factory CleaningSchedule.fromDoc(
      String weekKey, DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CleaningSchedule(
      weekKey: weekKey,
      weekStart: (data['weekStart'] as Timestamp?)?.toDate() ??
          CleaningDates.parseKey(weekKey),
      slotOrder: (data['slotOrder'] as num?)?.toInt() ?? 0,
      assignmentType: data['assignmentType'] as String? ?? 'individual',
      targetIds:
          (data['targetIds'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      label: data['label'] as String?,
      overrideAssignmentType: data['overrideAssignmentType'] as String?,
      overrideTargetIds: (data['overrideTargetIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      overrideLabel: data['overrideLabel'] as String?,
      items: (data['items'] as List?)
              ?.map((e) => CleaningItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      completed: data['completed'] as bool? ?? false,
      completedBy: data['completedBy'] as String?,
      completedByName: data['completedByName'] as String?,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isOverridden =>
      overrideAssignmentType != null && overrideAssignmentType!.isNotEmpty;

  String get effectiveAssignmentType =>
      isOverridden ? overrideAssignmentType! : assignmentType;

  List<String> get effectiveTargetIds =>
      isOverridden && overrideTargetIds.isNotEmpty
          ? overrideTargetIds
          : targetIds;

  String? get effectiveLabel => isOverridden ? overrideLabel : label;

  bool get allItemsDone => items.isNotEmpty && items.every((i) => i.done);
}

/// Club-wide cleaning config (singleton doc `cleaning_meta/config`).
class CleaningConfig {
  final String? startWeekKey;
  final List<String> shoppingTemplate;
  final DateTime? updatedAt;

  const CleaningConfig({
    this.startWeekKey,
    this.shoppingTemplate = const [],
    this.updatedAt,
  });

  factory CleaningConfig.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CleaningConfig(
      startWeekKey: data['startWeekKey'] as String?,
      shoppingTemplate: (data['shoppingTemplate'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}