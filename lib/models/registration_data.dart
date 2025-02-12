class RegistrationData {
  final String fullName;
  final String username;
  final String email;
  final String password;
  final String mobile;
  final DateTime birthDate;
  final String address;
  final Map<String, String> location;

  RegistrationData({
    required this.fullName,
    required this.username,
    required this.email,
    required this.password,
    required this.mobile,
    required this.birthDate,
    required this.address,
    required this.location,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'username': username,
      'email': email,
      'mobile': mobile,
      'birthDate': birthDate.toIso8601String(),
      'address': address,
      'location': location,
    };
  }
}
