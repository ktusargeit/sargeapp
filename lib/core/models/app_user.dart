import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile_models.dart';

/// Represents the current authenticated user's Firestore profile.
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final int points;
  final int weeklyPoints;
  final int prevWeeklyPoints;

  /// Team-scoped total points: `{ teamId: totalPoints }`.
  ///
  /// A user can belong to more than one team and contribute a DIFFERENT amount
  /// in each team, so the single global `points` field is no longer the source
  /// of truth for team leaderboards. `points` is kept for backwards
  /// compatibility (profile header) but team screens read from this map.
  final Map<String, int> teamPoints;
  final String? photoUrl;
  final String? coverPhotoUrl;
  final String? bio;
  final String? department;
  final String? className;
  final List<String> teamIds;
  final List<String> pastTeamIds;
  final List<Map<String, dynamic>> pastTeams;
  final List<Map<String, dynamic>> links;
  final List<Map<String, dynamic>> clubRoles;
  final List<String> unitResponsibilities;
  final List<Map<String, dynamic>> awards;
  final List<UserTitle> titles;
  final bool inWorkshop;
  final bool isSuspended;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = 'member',
    this.points = 0,
    this.weeklyPoints = 0,
    this.prevWeeklyPoints = 0,
    this.teamPoints = const {},
    this.photoUrl,
    this.coverPhotoUrl,
    this.bio,
    this.department,
    this.className,
    this.teamIds = const [],
    this.pastTeamIds = const [],
    this.pastTeams = const [],
    this.links = const [],
    this.clubRoles = const [],
    this.unitResponsibilities = const [],
    this.awards = const [],
    this.titles = const [],
    this.inWorkshop = false,
    this.isSuspended = false,
  });

  /// Whether the user holds the Admin role, honoring BOTH the legacy single
  /// `role` field and the `titles` array (a user can hold Admin + other global
  /// roles simultaneously, and Admin may only exist as an active title).
  bool get isAdmin =>
      role == 'admin' ||
      activeTitles.any((t) => t.titleType == TitleType.admin);

  /// Whether the user holds the Yönetim Kurulu Üyesi role (including Başkan).
  bool get isBoardMember =>
      role == 'board_member' ||
      role == 'board_president' ||
      activeTitles.any((t) =>
          t.titleType == TitleType.boardMember ||
          t.titleType == TitleType.boardPresident);

  bool get isUnitLead => role == 'unit_lead';

  String get roleLabel {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'board_president':
        return 'Başkan';
      case 'board_member':
        return 'Yönetim Kurulu Üyesi';
      case 'captain':
        return 'Kaptan';
      case 'unit_lead':
        return 'Birim Sorumlusu';
      // Both 'member' and the legacy 'user' value fall through here, so the
      // display stays identical regardless of the stored string.
      default:
        return 'Üye';
    }
  }

  /// Currently active (non-retired) titles, newest first.
  List<UserTitle> get activeTitles {
    final active = titles.where((t) => t.isActive).toList();
    active.sort((a, b) => b.startDate.compareTo(a.startDate));
    return active;
  }

  /// Retired/former titles, newest first.
  List<UserTitle> get formerTitles {
    final former = titles.where((t) => !t.isActive).toList();
    former.sort((a, b) => b.startDate.compareTo(a.startDate));
    return former;
  }

  String? get activeTeamName {
    if (teamIds.isEmpty) return null;
    return teamIds.first;
  }

  /// Total points earned in [teamId], falling back to 0 for teams the user
  /// has no recorded contribution in.
  int teamPointsFor(String teamId) => teamPoints[teamId] ?? 0;

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
      teamPoints: (data['teamPoints'] as Map?)
              ?.map((key, value) => MapEntry(key.toString(), (value as num).toInt())) ??
          const {},
      photoUrl: data['photoUrl'] as String?,
      coverPhotoUrl: data['coverPhotoUrl'] as String?,
      bio: data['bio'] as String?,
      department: data['department'] as String?,
      className: data['className'] as String?,
      teamIds: (data['teamIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      pastTeamIds: (data['pastTeamIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
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
      titles: (data['titles'] as List?)
              ?.map((e) => UserTitle.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      inWorkshop: data['inWorkshop'] as bool? ?? false,
      isSuspended: data['isSuspended'] as bool? ?? false,
    );
  }
}
