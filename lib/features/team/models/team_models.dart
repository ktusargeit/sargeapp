import 'package:cloud_firestore/cloud_firestore.dart';

/// A leaderboard entry - basically a snapshot of a user's points.
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final int points;
  final String? photoUrl;
  final bool inWorkshop;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.points,
    this.photoUrl,
    this.inWorkshop = false,
  });

  factory LeaderboardEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return LeaderboardEntry(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'Isimsiz Uye',
      points: (data['points'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String?,
      inWorkshop: data['inWorkshop'] as bool? ?? false,
    );
  }
}

/// A bug/issue report submitted by a user.
class BugReport {
  final String id;
  final String title;
  final String message;
  final String submittedBy;
  final String submittedByName;
  final DateTime? createdAt;
  final String status; // 'open', 'investigating', 'done'
  final String? imageUrl;

  const BugReport({
    required this.id,
    this.title = '',
    required this.message,
    required this.submittedBy,
    required this.submittedByName,
    this.createdAt,
    this.status = 'open',
    this.imageUrl,
  });

  bool get isResolved => status == 'done';

  String get statusLabel {
    switch (status) {
      case 'investigating':
        return 'İnceleniyor';
      case 'done':
        return 'Yapıldı';
      default:
        return 'Beklemede';
    }
  }

  factory BugReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BugReport(
      id: doc.id,
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      submittedBy: data['submittedBy'] as String? ?? '',
      submittedByName: data['submittedByName'] as String? ?? 'Bilinmiyor',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'open',
      imageUrl: data['imageUrl'] as String?,
    );
  }
}

/// A club team (Elektronik Harp, Roket, Mekanik, etc.).
class ClubTeam {
  final String id;
  final String name;
  final String description;
  final String? photoUrl;
  final bool isActive;
  final List<String> memberIds;
  final DateTime? createdAt;
  final String? createdBy;
  final String? leadUid;         // team captain uid

  const ClubTeam({
    required this.id,
    required this.name,
    required this.description,
    this.photoUrl,
    this.isActive = true,
    this.memberIds = const [],
    this.createdAt,
    this.createdBy,
    this.leadUid,
  });

  bool get hasLead => leadUid != null && leadUid!.isNotEmpty;

  factory ClubTeam.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ClubTeam(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      memberIds: (data['memberIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      leadUid: data['leadUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'photoUrl': photoUrl,
        'isActive': isActive,
        'memberIds': memberIds,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'leadUid': leadUid,
      };
}
