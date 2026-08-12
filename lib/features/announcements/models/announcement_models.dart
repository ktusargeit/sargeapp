import 'package:cloud_firestore/cloud_firestore.dart';

/// An announcement / event posted by admin.
class Announcement {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime? eventDate;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
  final bool notifyAll;
  final String targetType;       // 'club' | 'team'
  final List<String> targetTeamIds; // team doc ids if targetType == 'team'
  final List<Map<String, dynamic>> comments; // [{senderUid, senderName, text, createdAt, isAdmin}]

  const Announcement({
    required this.id,
    required this.title,
    this.description = '',
    this.imageUrl,
    this.eventDate,
    required this.createdAt,
    required this.createdBy,
    this.createdByName = '',
    this.notifyAll = false,
    this.targetType = 'club',
    this.targetTeamIds = const [],
    this.comments = const [],
  });

  bool get isClubWide => targetType == 'club';

  int get commentCount => comments.length;

  /// Returns a human-readable event status label based on [eventDate].
  String get eventStatus {
    if (eventDate == null) return '';
    final now = DateTime.now();
    final diff = eventDate!.difference(now);
    if (diff.isNegative) return 'Geçti';
    if (diff.inDays <= 1) return 'Çok Yakında';
    if (diff.inDays <= 7) return 'Yakında';
    return '';
  }

  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Announcement(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      eventDate: (data['eventDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? 'Kullanıcı',
      notifyAll: data['notifyAll'] as bool? ?? false,
      targetType: data['targetType'] as String? ?? 'club',
      targetTeamIds: (data['targetTeamIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      comments: (data['comments'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'eventDate': eventDate != null ? Timestamp.fromDate(eventDate!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdBy': createdBy,
        'createdByName': createdByName,
        'notifyAll': notifyAll,
        'targetType': targetType,
        'targetTeamIds': targetTeamIds,
        'comments': comments,
      };
}