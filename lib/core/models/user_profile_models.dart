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
  static const boardMember = 'board_member';
  static const captain = 'captain';
  static const unitLead = 'unit_lead';
  static const admin = 'admin';
  static const member = 'member';
  static const honoraryMember = 'honorary_member';
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
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}