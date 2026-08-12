import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus {
  assigned,
  inProgress,
  pendingApproval,
  completed,
  rejected,
  cancelled,
}

/// A task assigned to a user within a team → unit hierarchy.
class TaskModel {
  final String id;
  final String title;
  final String description;
  final String assignedTo;       // user uid
  final String assignedByName;
  final int points;
  final TaskStatus status;
  final DateTime? createdAt;
  final DateTime? deadline;
  final String? teamId;          // team doc id
  final String? teamName;
  final String? unitId;           // unit doc id
  final String? unitName;
  final String? assignedBy;       // uid of task creator
  final String? approvedBy;       // uid of team captain who approved
  final bool pointsAwarded;       // guard: only award points once

  const TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.assignedTo,
    this.assignedByName = '',
    this.points = 0,
    this.status = TaskStatus.assigned,
    this.createdAt,
    this.deadline,
    this.teamId,
    this.teamName,
    this.unitId,
    this.unitName,
    this.assignedBy,
    this.approvedBy,
    this.pointsAwarded = false,
  });

  factory TaskModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TaskModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      assignedTo: data['assignedTo'] as String? ?? '',
      assignedByName: data['assignedByName'] as String? ?? '',
      points: (data['points'] as num?)?.toInt() ?? 0,
      status: _parseStatus(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      deadline: (data['deadline'] as Timestamp?)?.toDate(),
      teamId: data['teamId'] as String?,
      teamName: data['teamName'] as String?,
      unitId: data['unitId'] as String?,
      unitName: data['unitName'] as String?,
      assignedBy: data['assignedBy'] as String?,
      approvedBy: data['approvedBy'] as String?,
      pointsAwarded: data['pointsAwarded'] as bool? ?? false,
    );
  }

  String get statusText {
    switch (status) {
      case TaskStatus.assigned:
        return 'assigned';
      case TaskStatus.inProgress:
        return 'inProgress';
      case TaskStatus.pendingApproval:
        return 'pendingApproval';
      case TaskStatus.completed:
        return 'completed';
      case TaskStatus.rejected:
        return 'rejected';
      case TaskStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Human-readable Turkish label for the status.
  String get statusLabel {
    switch (status) {
      case TaskStatus.assigned:
        return 'Atandı';
      case TaskStatus.inProgress:
        return 'Devam Ediyor';
      case TaskStatus.pendingApproval:
        return 'Onay Bekliyor';
      case TaskStatus.completed:
        return 'Tamamlandı';
      case TaskStatus.rejected:
        return 'Reddedildi';
      case TaskStatus.cancelled:
        return 'İptal Edildi';
    }
  }

  static TaskStatus _parseStatus(String? s) {
    switch (s) {
      case 'inProgress':
        return TaskStatus.inProgress;
      case 'pendingApproval':
        return TaskStatus.pendingApproval;
      case 'completed':
        return TaskStatus.completed;
      case 'rejected':
        return TaskStatus.rejected;
      case 'cancelled':
        return TaskStatus.cancelled;
      default:
        return TaskStatus.assigned;
    }
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'assignedTo': assignedTo,
        'assignedByName': assignedByName,
        'points': points,
        'status': statusText,
        'createdAt': FieldValue.serverTimestamp(),
        'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
        if (teamId != null) 'teamId': teamId,
        if (teamName != null) 'teamName': teamName,
        if (unitId != null) 'unitId': unitId,
        if (unitName != null) 'unitName': unitName,
        if (assignedBy != null) 'assignedBy': assignedBy,
        'approvedBy': approvedBy,
        'pointsAwarded': pointsAwarded,
      };
}
