class Community {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;

  Community({
    required this.id,
    required this.name,
    required this.description,
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
      name: map['name'] as String,
      description: map['description'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}
