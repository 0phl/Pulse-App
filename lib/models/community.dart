class Community {
  final String id;
  final String name;
  final String description;
  final String? adminId;
  final String status;
  final DateTime createdAt;

  Community({
    required this.id,
    required this.name,
    required this.description,
    this.adminId,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Community.fromMap(String id, Map<dynamic, dynamic> map) {
    return Community(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      adminId: map['adminId'],
      status: map['status'] ?? 'pending',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }
}
