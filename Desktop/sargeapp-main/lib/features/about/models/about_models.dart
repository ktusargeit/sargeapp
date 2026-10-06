enum MemberType { team, honorary }

/// A text section on the About page (e.g., "Tarihçemiz").
class AboutSection {
  final String id;
  final String title;
  final String content;
  final int order;

  const AboutSection({
    required this.id,
    required this.title,
    this.content = '',
    this.order = 0,
  });

  factory AboutSection.fromMap(String id, Map<String, dynamic> map) {
    return AboutSection(
      id: id,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'content': content,
        'order': order,
      };
}

/// A member displayed on the About page (team member or honorary).
class AboutMember {
  final String id;
  final String name;
  final String? role;
  final String? photoUrl;
  final MemberType type;

  const AboutMember({
    required this.id,
    required this.name,
    this.role,
    this.photoUrl,
    this.type = MemberType.team,
  });

  factory AboutMember.fromMap(String id, Map<String, dynamic> map) {
    return AboutMember(
      id: id,
      name: map['name'] as String? ?? '',
      role: map['role'] as String?,
      photoUrl: map['photoUrl'] as String?,
      type: map['type'] == 'honorary' ? MemberType.honorary : MemberType.team,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'role': role,
        'photoUrl': photoUrl,
        'type': type == MemberType.honorary ? 'honorary' : 'team',
      };
}
