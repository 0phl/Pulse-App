class RegistrationData {
  final String firstName;
  final String? middleName;
  final String lastName;
  final String username;
  final String email;
  final String password;
  final String mobile;
  final DateTime birthDate;
  final String address;
  final Map<String, String> location;
  final String? profileImageUrl;
  final String registrationId;

  RegistrationData({
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.password,
    required this.mobile,
    required this.birthDate,
    required this.address,
    required this.location,
    this.profileImageUrl,
    required this.registrationId,
  });

  // Get full name by combining first, middle, and last names
  String get fullName {
    if (middleName != null && middleName!.isNotEmpty) {
      return '$firstName $middleName $lastName';
    }
    return '$firstName $lastName';
  }

  // Convert to Map for Firebase
  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      if (middleName != null && middleName!.isNotEmpty) 'middleName': middleName,
      'lastName': lastName,
      'fullName': fullName, // Store the combined name for backward compatibility
      'username': username,
      'email': email,
      'mobile': mobile,
      'birthDate': birthDate.toIso8601String(),
      'address': address,
      'location': location,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      'registrationId': registrationId,
      'verificationStatus': 'pending',
    };
  }
}
