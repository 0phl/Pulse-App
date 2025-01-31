import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerPost {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final int spotLimit;
  final int spotsLeft;
  final String userId;
  final String userName;
  final String communityId;
  final DateTime createdAt;

  VolunteerPost({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    required this.spotLimit,
    required this.spotsLeft,
    required this.userId,
    required this.userName,
    required this.communityId,
    required this.createdAt,
  });

  factory VolunteerPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<dynamic, dynamic>;
    return VolunteerPost(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      spotLimit: data['spotLimit'] ?? 0,
      spotsLeft: data['spotsLeft'] ?? 0,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      communityId: data['communityId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'date': Timestamp.fromDate(date),
      'spotLimit': spotLimit,
      'spotsLeft': spotsLeft,
      'userId': userId,
      'userName': userName,
      'communityId': communityId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  VolunteerPost copyWith({
    String? title,
    String? description,
    String? location,
    DateTime? date,
    int? spotLimit,
    int? spotsLeft,
  }) {
    return VolunteerPost(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      date: date ?? this.date,
      spotLimit: spotLimit ?? this.spotLimit,
      spotsLeft: spotsLeft ?? this.spotsLeft,
      userId: userId,
      userName: userName,
      communityId: communityId,
      createdAt: createdAt,
    );
  }
}
