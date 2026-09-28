import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile_models.dart';

// ─── Registration approval status ──────────────────────────────────────────
//
// Stored on `users/{uid}.approvalStatus`.
//
// IMPORTANT (legacy fallback): documents created before this feature shipped
// have NO `approvalStatus` field at all. They belong to users who are already
// active members, so a missing/null value must be read as [approvalApproved].
// Only an EXPLICIT `'pending'` / `'rejected'` from Firestore puts a user behind
// the [PendingApprovalScreen]. This is why the fallback lives in
// [AppUser.fromDoc] and NOT in the model's constructor default alone.

/// New sign-ups start here — they cannot enter the app until an admin approves.
const String approvalPending = 'pending';

/// Approved members — full access to the shell/dashboard.
const String approvalApproved = 'approved';

/// Rejected registrations — blocked just like pending, but never listed to
/// other waiting users (an admin may still delete the account).
const String approvalRejected = 'rejected';

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

  /// Structured "Deneyim" entries authored by the user (previous
  /// years). Replaces the legacy free-text `clubRoles` /
  /// `unitResponsibilities` arrays. Automatic (previous) titles live in
  /// [titles] with `isActive: false` — both sources are merged into the
  /// profile timeline.
  final List<PastExperience> pastExperiences;
  final List<Map<String, dynamic>> awards;
  final List<UserTitle> titles;
  final bool inWorkshop;
  final bool isSuspended;

  /// Registration approval state: `'pending'`, `'approved'` or `'rejected'`.
  ///
  /// Defaults to [approvalApproved] for legacy documents that were created
  /// before this field existed (see [approvalStatusFor] docs and
  /// [AppUser.fromDoc]) so that existing, active users are never locked out.
  final String approvalStatus;

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
    this.pastExperiences = const [],
    this.awards = const [],
    this.titles = const [],
    this.inWorkshop = false,
    this.isSuspended = false,
    this.approvalStatus = approvalApproved,
  });

  /// Whether the user holds the Admin role, honoring BOTH the legacy single
  /// `role` field and the `titles` array (a user can hold Admin + other global
  /// roles simultaneously, and Admin may only exist as an active title).
  bool get isAdmin =>
      role == 'admin' ||
      activeTitles.any((t) => t.titleType == TitleType.admin);

  /// Whether the user holds the Yönetim Kurulu Üyesi role (including Başkan
  /// and Başkan Yardımcısı).
  bool get isBoardMember =>
      TitleType.isBoardTitle(role) ||
      activeTitles.any((t) => TitleType.isBoardTitle(t.titleType));

  bool get isUnitLead => role == 'unit_lead';

  /// True only when an admin has explicitly approved this registration.
  ///
  /// A missing `approvalStatus` (legacy document) resolves to
  /// [approvalApproved] — see the constants block at the top of this file.
  bool get isApproved => approvalStatus != approvalPending &&
      approvalStatus != approvalRejected;

  /// True while the registration is waiting for an admin decision.
  bool get isPendingApproval => approvalStatus == approvalPending;

  /// True when an admin explicitly rejected the registration.
  bool get isRejected => approvalStatus == approvalRejected;

  /// True when the user must be parked on the pending-approval screen instead
  /// of the shell (pending OR rejected).
  bool get needsApproval => !isApproved;

  String get roleLabel {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'board_president':
        return 'Başkan';
      case 'board_vice_president':
        return 'Başkan Yardımcısı';
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

  /// Resolves a raw `users/{uid}.approvalStatus` value into one of the three
  /// known states.
  ///
  /// LEGACY FALLBACK — this is the single place that decides it: a `null`
  /// (field absent, or explicitly null) means the document predates the
  /// approval system, i.e. an already-active member, so it resolves to
  /// [approvalApproved]. Treating it as 'pending' would lock out every current
  /// member the moment v4.4.0 ships.
  ///
  /// Kept public + pure so it can be unit-tested without a live Firestore
  /// (`DocumentSnapshot` is sealed and cannot be hand-built in a test).
  static String applyApprovalFallback(Object? raw) {
    final value = raw as String?;
    if (value == approvalPending) return approvalPending;
    if (value == approvalRejected) return approvalRejected;
    return approvalApproved;
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
      pastExperiences: (data['pastExperiences'] as List?)
              ?.map((e) => PastExperience.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
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
      // LEGACY FALLBACK: a missing/null field means the document predates the
      // approval system, i.e. the user is an existing, already-active member.
      // Reading those as 'pending' would lock every current member out.
      approvalStatus: applyApprovalFallback(data['approvalStatus']),
    );
  }
}
