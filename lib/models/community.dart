class Community {
  final String id;
  final String name;
  final String description;
  final String? adminId;
  final String status;
  final DateTime createdAt;
  final String regionCode;
  final String provinceCode;
  final String municipalityCode;
  final String barangayCode;
  final String locationId; // Unique identifier based on location codes

  Community({
    required this.id,
    required this.name,
    required this.description,
    this.adminId,
    required this.status,
    required this.createdAt,
    required this.regionCode,
    required this.provinceCode,
    required this.municipalityCode,
    required this.barangayCode,
    required this.locationId,
  });

  // Create a unique location identifier
  static String createLocationId({
    required String regionCode,
    required String provinceCode,
    required String municipalityCode,
    required String barangayCode,
  }) {
    return '$regionCode-$provinceCode-$municipalityCode-$barangayCode';
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'adminId': adminId,
      'status': status,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'regionCode': regionCode,
      'provinceCode': provinceCode,
      'municipalityCode': municipalityCode,
      'barangayCode': barangayCode,
      'locationId': locationId,
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
      regionCode: map['regionCode'] ?? '',
      provinceCode: map['provinceCode'] ?? '',
      municipalityCode: map['municipalityCode'] ?? '',
      barangayCode: map['barangayCode'] ?? '',
      locationId: map['locationId'] ?? '',
    );
  }
}
