import 'package:cloud_firestore/cloud_firestore.dart';

/// A leaderboard entry - basically a snapshot of a user's points.
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final int points;
  final int weeklyPoints;
  final String? photoUrl;
  final bool inWorkshop;
  final List<String> teamIds;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.points,
    this.weeklyPoints = 0,
    this.photoUrl,
    this.inWorkshop = false,
    this.teamIds = const [],
  });

  factory LeaderboardEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return LeaderboardEntry(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'Isimsiz Uye',
      points: (data['points'] as num?)?.toInt() ?? 0,
      weeklyPoints: (data['weeklyPoints'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String?,
      inWorkshop: data['inWorkshop'] as bool? ?? false,
      teamIds: (data['teamIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  /// Builds an entry from an archived weekly-leaderboard snapshot, where the
  /// stored `points` is the user's `weeklyPoints` at archive time.
  factory LeaderboardEntry.fromArchiveMap(Map<String, dynamic> data) {
    final pts = (data['points'] as num?)?.toInt() ?? 0;
    return LeaderboardEntry(
      uid: data['uid'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Isimsiz Uye',
      points: pts,
      weeklyPoints: pts,
      photoUrl: data['photoUrl'] as String?,
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
  final String type; // 'bug' | 'suggestion'
  final String? imageUrl;
  final List<Map<String, dynamic>> reviewedBy; // [{uid, name, startedAt}]
  final String? resolvedBy;       // uid of admin who resolved
  final String? resolvedByName;   // display name of resolver
  final DateTime? resolvedAt;     // when resolved
  final List<Map<String, dynamic>> messages; // [{senderUid, senderName, text, imageUrl, createdAt, isAdmin}]

  const BugReport({
    required this.id,
    this.title = '',
    required this.message,
    required this.submittedBy,
    required this.submittedByName,
    this.createdAt,
    this.status = 'open',
    this.type = 'bug',
    this.imageUrl,
    this.reviewedBy = const [],
    this.resolvedBy,
    this.resolvedByName,
    this.resolvedAt,
    this.messages = const [],
  });

  bool get isResolved => status == 'done';
  bool get isSuggestion => type == 'suggestion';

  String get statusLabel {
    switch (status) {
      case 'investigating':
        return 'İnceleniyor';
      case 'done':
        return 'Çözüldü';
      default:
        return 'Yeni';
    }
  }

  /// Human-readable status with reviewer names.
  String statusLabelWithReviewers() {
    if (status == 'investigating' && reviewedBy.isNotEmpty) {
      final names = reviewedBy.map((r) => r['name'] as String? ?? '').where((n) => n.isNotEmpty).toList();
      if (names.isNotEmpty) {
        return '${names.join(', ')} tarafından inceleniyor';
      }
    }
    if (status == 'done' && resolvedByName != null && resolvedByName!.isNotEmpty) {
      return '$resolvedByName tarafından çözüldü';
    }
    return statusLabel;
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
      type: data['type'] as String? ?? 'bug',
      imageUrl: data['imageUrl'] as String?,
      reviewedBy: (data['reviewedBy'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      resolvedBy: data['resolvedBy'] as String?,
      resolvedByName: data['resolvedByName'] as String?,
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      messages: (data['messages'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }

  int get messageCount => messages.length;
}

/// A club team (Elektronik Harp, Roket, Mekanik, etc.).
class ClubTeam {
  final String id;
  final String name;
  final String description;
  final String? photoUrl;

  /// Canonical team status: 'active' | 'archived'. Archived teams are former
  /// seasons whose data is kept but no longer shown as a current team.
  final String status;

  /// Season/period label, e.g. "2024-2025".
  final String? period;

  /// Free-form team story (shown on the About / club history page).
  final String? story;

  /// Gallery photos for the team's story.
  final List<String> photos;

  final List<String> memberIds;

  /// Former members (archived season rosters); linked two-way with
  /// `users/{uid}.pastTeamIds`.
  final List<String> pastMemberIds;

  /// Free-text names of past members who are no longer registered in the
  /// system (e.g. for legacy/archived teams). These are displayed alongside
  /// [pastMemberIds]-resolved profiles but are not linked to a user account.
  final List<String> pastMemberNames;

  final DateTime? createdAt;
  final String? createdBy;
  final String? leadUid;         // team captain uid

  const ClubTeam({
    required this.id,
    required this.name,
    required this.description,
    this.photoUrl,
    this.status = 'active',
    this.period,
    this.story,
    this.photos = const [],
    this.memberIds = const [],
    this.pastMemberIds = const [],
    this.pastMemberNames = const [],
    this.createdAt,
    this.createdBy,
    this.leadUid,
  });

  bool get hasLead => leadUid != null && leadUid!.isNotEmpty;

  /// Backwards-compatible "active" getter (active == not archived).
  bool get isActive => status != 'archived';

  bool get isArchived => status == 'archived';

  factory ClubTeam.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final legacyActive = data['isActive'] as bool?;
    final status = data['status'] as String? ??
        (legacyActive == false ? 'archived' : 'active');
    return ClubTeam(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      status: status,
      period: data['period'] as String?,
      story: data['story'] as String?,
      photos: (data['photos'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      memberIds: (data['memberIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      pastMemberIds: (data['pastMemberIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      pastMemberNames: (data['pastMemberNames'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      leadUid: data['leadUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'photoUrl': photoUrl,
        'status': status,
        'isActive': status != 'archived',
        'period': period,
        'story': story,
        'photos': photos,
        'memberIds': memberIds,
        'pastMemberIds': pastMemberIds,
        'pastMemberNames': pastMemberNames,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'leadUid': leadUid,
      };
}

/// A team-scoped sub-group (birim), e.g. "Güç Elektroniği Birimi" inside
/// an "Elektrik" team.
///
/// Unlike the legacy `unitResponsibilities` string array on the user profile
/// (which is just a free-form list of names), this is a structured document in
/// the existing `units` collection with its own member list and an optional
/// unit lead.
class TeamUnit {
  final String id;
  final String teamId;
  final String name;
  final String? description;
  final List<String> memberUids;
  final String? unitLeadUid;
  final DateTime? createdAt;

  const TeamUnit({
    required this.id,
    required this.teamId,
    required this.name,
    this.description,
    this.memberUids = const [],
    this.unitLeadUid,
    this.createdAt,
  });

  bool get hasLead => unitLeadUid != null && unitLeadUid!.isNotEmpty;

  factory TeamUnit.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TeamUnit(
      id: doc.id,
      teamId: data['teamId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      memberUids:
          (data['memberUids'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      unitLeadUid: data['unitLeadUid'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}