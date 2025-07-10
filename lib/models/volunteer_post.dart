import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerPost {
  final String id;
  final String title;
  final String description;
  final String adminId;
  final String adminName;
  final DateTime date; // Changed from datePosted to match Firestore index
  final DateTime eventDate;
  final String location;
  final int maxVolunteers;
  final List<String> joinedUsers;
  final bool isActive;
  final String communityId;

  VolunteerPost({
    required this.id,
    required this.title,
    required this.description,
    required this.adminId,
    required this.adminName,
    required this.date, // Changed parameter name
    required this.eventDate,
    required this.location,
    required this.maxVolunteers,
    required this.joinedUsers,
    required this.communityId,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'adminId': adminId,
      'adminName': adminName,
      'date': date, // Changed from datePosted to date
      'eventDate': eventDate,
      'location': location,
      'maxVolunteers': maxVolunteers,
      'joinedUsers': joinedUsers,
      'isActive': isActive,
      'communityId': communityId,
    };
  }

  factory VolunteerPost.fromMap(Map<String, dynamic> map, String documentId) {
    return VolunteerPost(
      id: documentId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      adminId: map['adminId'] ?? '',
      adminName: map['adminName'] ?? '',
      date: (map['date'] as Timestamp)
          .toDate(), // Changed from datePosted to date
      eventDate: (map['eventDate'] as Timestamp).toDate(),
      location: map['location'] ?? '',
      maxVolunteers: map['maxVolunteers'] ?? 0,
      joinedUsers: List<String>.from(map['joinedUsers'] ?? []),
      isActive: map['isActive'] ?? true,
      communityId: map['communityId'] ?? '',
    );
  }

  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(date); // Changed from datePosted to date

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

  String get formattedTime {
    final hour = eventDate.hour;
    final minute = eventDate.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hourDisplay = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final minuteDisplay = minute.toString().padLeft(2, '0');
    return '$hourDisplay:$minuteDisplay $period';
  }

  VolunteerPost copyWith({
    String? title,
    String? description,
    String? location,
    DateTime? date, // Changed from datePosted to date
    int? maxVolunteers,
    List<String>? joinedUsers,
    bool? isActive,
    String? communityId,
  }) {
    return VolunteerPost(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      adminId: adminId,
      adminName: adminName,
      date: date ?? this.date, // Changed from datePosted to date
      eventDate: eventDate,
      location: location ?? this.location,
      maxVolunteers: maxVolunteers ?? this.maxVolunteers,
      joinedUsers: joinedUsers ?? this.joinedUsers,
      isActive: isActive ?? this.isActive,
      communityId: communityId ?? this.communityId,
    );
  }

  bool hasParticipant(String userId) {
    return joinedUsers.contains(userId);
  }
}
