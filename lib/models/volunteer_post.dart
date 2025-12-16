import 'package:cloud_firestore/cloud_firestore.dart';

/// Status enum for volunteer posts
enum VolunteerPostStatus {
  upcoming, // Not yet started
  ongoing, // Currently active
  done, // Completed
}

class VolunteerPost {
  final String id;
  final String title;
  final String description;
  final String adminId;
  final String adminName;
  final DateTime date; // Date when the post was created
  final DateTime startDate; // When the volunteer activity starts
  final DateTime endDate; // When the volunteer activity ends
  final String location;
  final int maxVolunteers;
  final List<String> joinedUsers;
  final bool isActive;
  final String communityId;
  final bool participationRecorded; // Track if participation has been recorded
  final String? imageUrl; // Optional image for visual appeal

  VolunteerPost({
    required this.id,
    required this.title,
    required this.description,
    required this.adminId,
    required this.adminName,
    required this.date,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.maxVolunteers,
    required this.joinedUsers,
    required this.communityId,
    this.isActive = true,
    this.participationRecorded = false,
    this.imageUrl,
  });

  /// Automatically computed status based on current time and start/end dates
  VolunteerPostStatus get status {
    final now = DateTime.now();
    if (now.isBefore(startDate)) {
      return VolunteerPostStatus.upcoming;
    } else if (now.isAfter(endDate)) {
      return VolunteerPostStatus.done;
    } else {
      return VolunteerPostStatus.ongoing;
    }
  }

  /// Check if the post has transitioned to ongoing or done (for recording participation)
  bool get shouldRecordParticipation {
    return !participationRecorded && 
           (status == VolunteerPostStatus.ongoing || status == VolunteerPostStatus.done);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'adminId': adminId,
      'adminName': adminName,
      'date': date,
      'startDate': startDate,
      'endDate': endDate,
      // Keep eventDate for backward compatibility
      'eventDate': startDate,
      'location': location,
      'maxVolunteers': maxVolunteers,
      'joinedUsers': joinedUsers,
      'isActive': isActive,
      'communityId': communityId,
      'participationRecorded': participationRecorded,
      'imageUrl': imageUrl,
    };
  }

  factory VolunteerPost.fromMap(Map<String, dynamic> map, String documentId) {
    // Handle backward compatibility - if startDate/endDate don't exist, use eventDate
    DateTime parseDate(dynamic value, {DateTime? fallback}) {
      if (value == null) return fallback ?? DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return fallback ?? DateTime.now();
    }

    final eventDate = parseDate(map['eventDate']);
    final startDate = parseDate(map['startDate'], fallback: eventDate);
    // For backward compatibility, if endDate doesn't exist, set it to end of the eventDate day
    final endDate = parseDate(
      map['endDate'], 
      fallback: DateTime(eventDate.year, eventDate.month, eventDate.day, 23, 59, 59),
    );

    return VolunteerPost(
      id: documentId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      adminId: map['adminId'] ?? '',
      adminName: map['adminName'] ?? '',
      date: parseDate(map['date'], fallback: DateTime.now()),
      startDate: startDate,
      endDate: endDate,
      location: map['location'] ?? '',
      maxVolunteers: map['maxVolunteers'] ?? 0,
      joinedUsers: List<String>.from(map['joinedUsers'] ?? []),
      isActive: map['isActive'] ?? true,
      communityId: map['communityId'] ?? '',
      participationRecorded: map['participationRecorded'] ?? false,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(date);

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

  String get formattedStartTime {
    final hour = startDate.hour;
    final minute = startDate.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hourDisplay = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final minuteDisplay = minute.toString().padLeft(2, '0');
    return '$hourDisplay:$minuteDisplay $period';
  }

  String get formattedEndTime {
    final hour = endDate.hour;
    final minute = endDate.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hourDisplay = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final minuteDisplay = minute.toString().padLeft(2, '0');
    return '$hourDisplay:$minuteDisplay $period';
  }

  /// Legacy getter for backward compatibility
  DateTime get eventDate => startDate;

  /// Legacy getter for backward compatibility
  String get formattedTime => formattedStartTime;

  /// Get a human-readable status label
  String get statusLabel {
    switch (status) {
      case VolunteerPostStatus.upcoming:
        return 'Upcoming';
      case VolunteerPostStatus.ongoing:
        return 'Ongoing';
      case VolunteerPostStatus.done:
        return 'Done';
    }
  }

  /// Get time remaining or elapsed info
  String get timeInfo {
    final now = DateTime.now();
    switch (status) {
      case VolunteerPostStatus.upcoming:
        final diff = startDate.difference(now);
        if (diff.inDays > 0) {
          return 'Starts in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
        } else if (diff.inHours > 0) {
          return 'Starts in ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
        } else {
          return 'Starting soon';
        }
      case VolunteerPostStatus.ongoing:
        final diff = endDate.difference(now);
        if (diff.inDays > 0) {
          return 'Ends in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
        } else if (diff.inHours > 0) {
          return 'Ends in ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
        } else {
          return 'Ending soon';
        }
      case VolunteerPostStatus.done:
        final diff = now.difference(endDate);
        if (diff.inDays > 0) {
          return 'Ended ${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
        } else if (diff.inHours > 0) {
          return 'Ended ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
        } else {
          return 'Just ended';
        }
    }
  }

  VolunteerPost copyWith({
    String? title,
    String? description,
    String? location,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    int? maxVolunteers,
    List<String>? joinedUsers,
    bool? isActive,
    String? communityId,
    bool? participationRecorded,
    String? imageUrl,
  }) {
    return VolunteerPost(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      adminId: adminId,
      adminName: adminName,
      date: date ?? this.date,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      maxVolunteers: maxVolunteers ?? this.maxVolunteers,
      joinedUsers: joinedUsers ?? this.joinedUsers,
      isActive: isActive ?? this.isActive,
      communityId: communityId ?? this.communityId,
      participationRecorded: participationRecorded ?? this.participationRecorded,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  bool hasParticipant(String userId) {
    return joinedUsers.contains(userId);
  }
}
