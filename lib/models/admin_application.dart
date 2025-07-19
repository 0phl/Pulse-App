class AdminApplication {
  final String id;
  final String fullName;
  final String email;
  final String communityId;
  final String communityName;
  final List<String> documents;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;

  AdminApplication({
    required this.id,
    required this.fullName,
    required this.email,
    required this.communityId,
    required this.communityName,
    required this.documents,
    required this.status,
    required this.createdAt,
  });


  DateTime get appliedDate => createdAt;

  factory AdminApplication.fromJson(Map<String, dynamic> json, String id) {
    return AdminApplication(
      id: id,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      communityId: json['communityId'] ?? '',
      communityName: json['communityName'] ?? '',
      documents: List<String>.from(json['documents'] ?? []),
      status: json['status'] ?? 'pending',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'communityId': communityId,
      'communityName': communityName,
      'documents': documents,
      'status': status,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
