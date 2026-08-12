/// Models for user profile sub-entities: past teams, social links, awards.
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