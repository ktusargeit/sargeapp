import 'package:cloud_firestore/cloud_firestore.dart';

/// Models for user profile sub-entities: past teams, social links, awards,
/// and club titles.
class PastTeamEntry {
  final String teamId;
  final String teamName;
  final String? role;
  final int startYear;
  final int? endYear;

  const PastTeamEntry({
    this.teamId = '',
    required this.teamName,
    this.role,
    required this.startYear,
    this.endYear,
  });

  factory PastTeamEntry.fromMap(Map<String, dynamic> map) {
    return PastTeamEntry(
      teamId: map['teamId'] as String? ?? '',
      teamName: map['teamName'] as String? ?? '',
      role: map['role'] as String?,
      startYear: (map['startYear'] as num?)?.toInt() ?? 0,
      endYear: (map['endYear'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'teamId': teamId,
        'teamName': teamName,
        'role': role,
        'startYear': startYear,
        'endYear': endYear,
      };
}

class SocialLink {
  final String type;
  final String label;
  final String url;

  const SocialLink({
    required this.type,
    this.label = '',
    required this.url,
  });

  factory SocialLink.fromMap(Map<String, dynamic> map) {
    return SocialLink(
      type: map['type'] as String? ?? '',
      label: map['label'] as String? ?? '',
      url: map['url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'label': label,
        'url': url,
      };
}

class ClubRole {
  final String roleName;
  final String? teamName;
  final int startYear;
  final int? endYear;

  const ClubRole({
    required this.roleName,
    this.teamName,
    required this.startYear,
    this.endYear,
  });

  factory ClubRole.fromMap(Map<String, dynamic> map) {
    return ClubRole(
      roleName: map['roleName'] as String? ?? '',
      teamName: map['teamName'] as String?,
      startYear: (map['startYear'] as num?)?.toInt() ?? 0,
      endYear: (map['endYear'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'roleName': roleName,
        'teamName': teamName,
        'startYear': startYear,
        'endYear': endYear,
      };
}

class Award {
  final String title;
  final String? description;

  const Award({required this.title, this.description});

  factory Award.fromMap(Map<String, dynamic> map) {
    return Award(
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
      };
}

/// Canonical identifiers for the club's active titles.
///
/// These values are persisted in Firestore under `users/{uid}/titles`.
class TitleType {
  static const boardPresident = 'board_president';
  static const boardVicePresident = 'board_vice_president';
  static const boardMember = 'board_member';
  static const captain = 'captain';
  static const unitLead = 'unit_lead';
  static const admin = 'admin';
  static const member = 'member';
  static const honoraryMember = 'honorary_member';

  /// Yönetim Kurulu (board) titles — Başkan, Başkan Yardımcısı and Üye.
  /// All three carry the same server-side privileges (see firestore.rules
  /// `isBoardMember()`), but they are displayed with distinct labels.
  static const List<String> boardTitleTypes = [
    boardPresident,
    boardVicePresident,
    boardMember,
  ];

  /// Whether [titleType] is a Yönetim Kurulu title.
  static bool isBoardTitle(String? titleType) =>
      titleType != null && boardTitleTypes.contains(titleType);
}

/// A structured, user-authored entry from the user's past (previous years).
///
/// Stored in Firestore under `users/{uid}.pastExperiences` as an array of maps.
///
/// Two flavours exist, discriminated by [kind]:
///  * [kindBoard]   — a Yönetim Kurulu experience; [roleType] holds
///                    `board_president` / `board_vice_president` /
///                    `board_member`.
///  * [kindTeam]    — a team experience; [teamId]/[teamName]/[unitName] and
///                    [roleType] (`unit_lead` = Birim Sorumlusu or
///                    `member` = Takım Üyesi) describe it.
///
/// The profile \"Deneyim\" timeline merges these entries with the automatically
/// retired (`isActive: false`) entries of the `titles` array.
class PastExperience {
  /// Board (Yönetim Kurulu) experience kind.
  static const kindBoard = 'board';

  /// Team experience kind.
  static const kindTeam = 'team';

  /// Roles selectable inside a board experience.
  static const List<String> boardRoleTypes = [
    TitleType.boardPresident,
    TitleType.boardVicePresident,
    TitleType.boardMember,
  ];

  /// Roles selectable inside a team experience (Kaptan / Birim Sorumlusu /
  /// Takım Üyesi). `captain` entries never carry a unit name.
  static const List<String> teamRoleTypes = [
    TitleType.captain,
    TitleType.unitLead,
    TitleType.member,
  ];

  final String id;

  /// Either [kindBoard] or [kindTeam].
  final String kind;

  /// `board_president` / `board_vice_president` / `board_member` for board
  /// entries; `unit_lead` / `member` for team entries.
  final String roleType;

  final String? teamId;
  final String? teamName;
  final String? unitName;

  final int startYear;
  final int? endYear;

  const PastExperience({
    required this.id,
    required this.kind,
    required this.roleType,
    this.teamId,
    this.teamName,
    this.unitName,
    required this.startYear,
    this.endYear,
  });

  bool get isBoard => kind == kindBoard;

  /// Turkish display label, e.g. \"Başkan Yardımcısı\" or \"Birim Sorumlusu\".
  String get roleLabel {
    switch (roleType) {
      case TitleType.boardPresident:
        return 'Başkan';
      case TitleType.boardVicePresident:
        return 'Başkan Yardımcısı';
      case TitleType.boardMember:
        return 'Üye';
      case TitleType.captain:
        return 'Takım Kaptanı';
      case TitleType.unitLead:
        return 'Birim Sorumlusu';
      case TitleType.member:
        return 'Takım Üyesi';
      default:
        return roleType;
    }
  }

  /// Short \"Başkan Yardımcısı — Roket\" style headline for the timeline.
  String get headline {
    if (isBoard) return 'Yönetim Kurulu — $roleLabel';
    final team = (teamName ?? '').trim();
    final unit = (unitName ?? '').trim();
    final parts = [
      if (team.isNotEmpty) team,
      if (unit.isNotEmpty && unit != team) unit,
    ];
    final where = parts.isEmpty ? 'Takım' : parts.join(' / ');
    return '$where — $roleLabel';
  }

  /// \"2023 - 2024\" or \"2023 - Devam ediyor\".
  String get periodLabel =>
      endYear != null ? '$startYear - $endYear' : '$startYear - Devam ediyor';

  factory PastExperience.fromMap(Map<String, dynamic> map) {
    return PastExperience(
      id: map['id'] as String? ?? '',
      kind: map['kind'] as String? ?? kindTeam,
      roleType: map['roleType'] as String? ?? TitleType.member,
      teamId: map['teamId'] as String?,
      teamName: map['teamName'] as String?,
      unitName: map['unitName'] as String?,
      startYear: (map['startYear'] as num?)?.toInt() ??
          DateTime.now().year,
      endYear: (map['endYear'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind,
        'roleType': roleType,
        'teamId': teamId,
        'teamName': teamName,
        'unitName': unitName,
        'startYear': startYear,
        'endYear': endYear,
      };

  PastExperience copyWith({
    String? id,
    String? kind,
    String? roleType,
    String? teamId,
    String? teamName,
    String? unitName,
    int? startYear,
    int? endYear,
  }) {
    return PastExperience(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      roleType: roleType ?? this.roleType,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      unitName: unitName ?? this.unitName,
      startYear: startYear ?? this.startYear,
      endYear: endYear ?? this.endYear,
    );
  }
}

/// A single title/role grant for a user.
///
/// A user can hold multiple titles at the same time and each title can be
/// "retired" (marked as a former title) instead of being deleted. Dates are
/// persisted as epoch milliseconds so this model stays independent of any
/// Firestore types.
class UserTitle {
  final String id;
  final String titleType; // see [TitleType]
  final String? unitName; // only relevant for TitleType.unitLead
  final bool isActive; // true = current, false = former/retired
  final DateTime startDate;
  final DateTime? endDate; // required when isActive is false

  const UserTitle({
    required this.id,
    required this.titleType,
    this.unitName,
    this.isActive = true,
    required this.startDate,
    this.endDate,
  });

  /// Turkish display label for the title type (without unit name).
  String get label {
    switch (titleType) {
      case TitleType.boardPresident:
        return 'Yönetim Kurulu Başkanı';
      case TitleType.boardVicePresident:
        return 'Yönetim Kurulu Başkan Yardımcısı';
      case TitleType.boardMember:
        return 'Yönetim Kurulu Üyesi';
      case TitleType.captain:
        return 'Kaptan';
      case TitleType.unitLead:
        return 'Birim Sorumlusu';
      case TitleType.admin:
        return 'Admin';
      case TitleType.honoraryMember:
        return 'Onursal Üye';
      case TitleType.member:
        return 'Normal Üye';
      default:
        return titleType;
    }
  }

  /// Full display label. For unit leads the unit name is appended, and retired
  /// titles are prefixed with "Eski" (e.g. "Eski Kaptan").
  String get displayLabel {
    final base = titleType == TitleType.unitLead && unitName != null
        ? '$label ($unitName)'
        : label;
    return isActive ? base : 'Eski $base';
  }

  factory UserTitle.fromMap(Map<String, dynamic> map) {
    return UserTitle(
      id: map['id'] as String? ?? '',
      titleType: map['titleType'] as String? ?? TitleType.member,
      unitName: map['unitName'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      startDate: _dateFrom(map['startDate']),
      endDate: map['endDate'] == null ? null : _dateFrom(map['endDate']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'titleType': titleType,
        'unitName': unitName,
        'isActive': isActive,
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate?.millisecondsSinceEpoch,
      };

  UserTitle copyWith({
    String? id,
    String? titleType,
    String? unitName,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return UserTitle(
      id: id ?? this.id,
      titleType: titleType ?? this.titleType,
      unitName: unitName ?? this.unitName,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  /// Handles both epoch millis (int) and already-decoded [DateTime] values.
  static DateTime _dateFrom(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}