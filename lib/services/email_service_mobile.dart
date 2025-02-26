class EmailPlatform {
  final String publicKey;

  EmailPlatform({required this.publicKey});

  Future<void> sendEmail(
      String serviceId, String templateId, Map<String, dynamic> params) async {
    throw UnsupportedError('EmailJS is not supported on mobile platforms');
  }
}
