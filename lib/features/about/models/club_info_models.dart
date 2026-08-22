import 'package:cloud_firestore/cloud_firestore.dart';

/// The single `club_info` document: club story + gallery + contact info.
class ClubInfo {
  final String story;
  final List<String> galleryPhotos;
  final String? title;
  final String? description;
  final String? email;
  final String? phone;
  final String? address;
  final String? instagram;
  final String? website;
  final String? socialLinks;

  const ClubInfo({
    this.story = '',
    this.galleryPhotos = const [],
    this.title,
    this.description,
    this.email,
    this.phone,
    this.address,
    this.instagram,
    this.website,
    this.socialLinks,
  });

  factory ClubInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ClubInfo();
    return ClubInfo(
      story: map['story'] as String? ?? '',
      galleryPhotos:
          (map['galleryPhotos'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      title: map['title'] as String?,
      description: map['description'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      instagram: map['instagram'] as String?,
      website: map['website'] as String?,
      socialLinks: map['socialLinks'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'story': story,
        'galleryPhotos': galleryPhotos,
        'title': title,
        'description': description,
        'email': email,
        'phone': phone,
        'address': address,
        'instagram': instagram,
        'website': website,
        'socialLinks': socialLinks,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

/// An honorary member, selected from registered users.
class HonoraryMember {
  final String id;
  final String userId;
  final String note;

  /// Extended free-form story/note about the member.
  final String story;

  /// Gallery photos for the member's detail screen.
  final List<String> photos;

  final DateTime? addedDate;
  final String? addedBy;

  const HonoraryMember({
    required this.id,
    required this.userId,
    this.note = '',
    this.story = '',
    this.photos = const [],
    this.addedDate,
    this.addedBy,
  });

  factory HonoraryMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return HonoraryMember(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      note: data['note'] as String? ?? '',
      story: data['story'] as String? ?? '',
      photos:
          (data['photos'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      addedDate: (data['addedDate'] as Timestamp?)?.toDate(),
      addedBy: data['addedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'note': note,
        'story': story,
        'photos': photos,
        'addedDate': FieldValue.serverTimestamp(),
        'addedBy': addedBy,
      };
}
