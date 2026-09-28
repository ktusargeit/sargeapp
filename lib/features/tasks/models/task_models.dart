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
  final String assignedTo;       // user uid (kişiye atanan)
  final String assignedToName;   // display name of the assigned person
  final String assignedByName;   // display name of the task creator (atayan)
  final int points;
  final TaskStatus status;
  final DateTime? createdAt;
  final DateTime? deadline;
  final String? teamId;          // team doc id
  final String? teamName;
  final String? unitId;           // unit doc id
  final String? unitName;
  final String? assignedBy;       // uid of task creator (atayan)
  final String? approvedBy;       // uid of team captain who approved
  final bool pointsAwarded;       // guard: only award points once
  final String? imageUrl;         // task image (uploaded by creator)
  final DateTime? completedAt;    // when submitted/completed (for 24h "recent" window)
  final List<Map<String, dynamic>> comments; // [{senderUid, senderName, text, imageUrl, createdAt, isAdmin}]
  final String? bulkGroupId;      // groups tasks created in one bulk assignment (team/unit/board)
  final String? assignmentMode;   // 'single' | 'team' | 'unit' | 'board'

  const TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.assignedTo,
    this.assignedToName = '',
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
    this.imageUrl,
    this.completedAt,
    this.comments = const [],
    this.bulkGroupId,
    this.assignmentMode,
  });

  factory TaskModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TaskModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      assignedTo: data['assignedTo'] as String? ?? '',
      assignedToName: data['assignedToName'] as String? ?? '',
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
      imageUrl: data['imageUrl'] as String?,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      comments: (data['comments'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      bulkGroupId: data['bulkGroupId'] as String?,
      assignmentMode: data['assignmentMode'] as String?,
    );
  }

  int get commentCount => comments.length;

  /// Whether this task was created via the "Yönetim Kurulu" assignment mode
  /// (targets board members only, carries no `teamId`).
  bool get isBoardTask => assignmentMode == 'board';

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
        return 'Yeni Görev';
      case TaskStatus.inProgress:
        return 'Devam Ediyor';
      case TaskStatus.pendingApproval:
        return 'Onay Bekliyor';
      case TaskStatus.completed:
        return 'Onaylandı';
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
        'assignedToName': assignedToName,
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
        if (bulkGroupId != null) 'bulkGroupId': bulkGroupId,
        if (assignmentMode != null) 'assignmentMode': assignmentMode,
      };
}