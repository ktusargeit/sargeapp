import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the current authenticated user's Firestore profile.
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final int points;
  final int weeklyPoints;
  final int prevWeeklyPoints;
  final String? photoUrl;
  final String? bio;
  final String? department;
  final String? className;
  final List<String> teamIds;
  final List<Map<String, dynamic>> pastTeams;
  final List<Map<String, dynamic>> links;
  final List<Map<String, dynamic>> clubRoles;
  final List<String> unitResponsibilities;
  final List<Map<String, dynamic>> awards;
  final bool inWorkshop;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = 'member',
    this.points = 0,
    this.weeklyPoints = 0,
    this.prevWeeklyPoints = 0,
    this.photoUrl,
    this.bio,
    this.department,
    this.className,
    this.teamIds = const [],
    this.pastTeams = const [],
    this.links = const [],
    this.clubRoles = const [],
    this.unitResponsibilities = const [],
    this.awards = const [],
    this.inWorkshop = false,
  });

  bool get isAdmin => role == 'admin';
  bool get isUnitLead => role == 'unit_lead';

  String get roleLabel {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'unit_lead':
        return 'Birim Sorumlusu';
      default:
        return 'Üye';
    }
  }

  String? get activeTeamName {
    if (teamIds.isEmpty) return null;
    return teamIds.first;
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'İsimsiz Üye',
      role: data['role'] as String? ?? 'member',
      points: (data['points'] as num?)?.toInt() ?? 0,
      weeklyPoints: (data['weeklyPoints'] as num?)?.toInt() ?? 0,
      prevWeeklyPoints: (data['prevWeeklyPoints'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String?,
      department: data['department'] as String?,
      className: data['className'] as String?,
      teamIds: (data['teamIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      pastTeams: (data['pastTeams'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      links: (data['links'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      clubRoles: (data['clubRoles'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      unitResponsibilities:
          (data['unitResponsibilities'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      awards: (data['awards'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      inWorkshop: data['inWorkshop'] as bool? ?? false,
    );
  }
}