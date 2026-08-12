import 'package:cloud_firestore/cloud_firestore.dart';

/// A notification sent to a user.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? type;
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;
  final String? recipientId;

  const AppNotification({
    required this.id,
    required this.title,
    this.body = '',
    this.type,
    this.relatedId,
    this.isRead = false,
    required this.createdAt,
    this.recipientId,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String?,
      relatedId: data['relatedId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recipientId: data['recipientId'] as String?,
    );
  }
}