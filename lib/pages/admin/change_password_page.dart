import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _adminService = AdminService();
  bool _isLoading = false;
  String? _error;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _passwordsMatch = true;

  @override
  void initState() {
    super.initState();
    // Add listeners to both password fields to check for matching
    _confirmPasswordController.addListener(_checkPasswordsMatch);
    _newPasswordController.addListener(_checkPasswordsMatch);
  }

  void _checkPasswordsMatch() {
    if (_confirmPasswordController.text.isNotEmpty) {
      setState(() {
        _passwordsMatch =
            _confirmPasswordController.text == _newPasswordController.text;
      });
    }
  }

  Map<String, bool> _checkPasswordStrength(String password) {
    return {
      'length': password.length >= 8,
      'uppercase': password.contains(RegExp(r'[A-Z]')),
      'lowercase': password.contains(RegExp(r'[a-z]')),
      'number': password.contains(RegExp(r'[0-9]')),
      'special': password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
    };
  }

  bool _isPasswordStrong(String password) {
    final checks = _checkPasswordStrength(password);
    return checks.values.every((isValid) => isValid);
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? const Color(0xFF00C49A) : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _confirmPasswordController.removeListener(_checkPasswordsMatch);
    _newPasswordController.removeListener(_checkPasswordsMatch);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    print('ChangePasswordPage: Starting password change process');

    try {
      print('ChangePasswordPage: Calling updateAdminFirstLogin');
      await _adminService.updateAdminFirstLogin(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      print('ChangePasswordPage: Password changed successfully');

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: Colors.green,
        ),
      );

      print('ChangePasswordPage: Navigating to admin dashboard');
      // Navigate to admin dashboard using pushNamedAndRemoveUntil to clear the stack
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/admin/dashboard',
        (route) => false,
      );
    } catch (e) {
      print('ChangePasswordPage: Error changing password: $e');
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: const Color(0xFFF5FBF9),
        appBar: AppBar(
          title: const Text(
            'Change Password',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false, // Disable back button
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              const Text(
                                'First Time Login',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'For security reasons, you must change your password before proceeding.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: !_showCurrentPassword,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00C49A)),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showCurrentPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _showCurrentPassword = !_showCurrentPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: !_showNewPassword,
                      onChanged: (value) {
                        // Force rebuild to update password requirements
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00C49A)),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showNewPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _showNewPassword = !_showNewPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (value == _currentPasswordController.text) {
                          return 'New password must be different from current password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters long';
                        }
                        if (!_isPasswordStrong(value)) {
                          return 'Password is not strong enough';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_newPasswordController.text.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Password Requirements',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildRequirement(
                              'At least 8 characters',
                              _checkPasswordStrength(
                                      _newPasswordController.text)['length'] ??
                                  false,
                            ),
                            _buildRequirement(
                              'Contains uppercase letter',
                              _checkPasswordStrength(
                                      _newPasswordController.text)['uppercase'] ??
                                  false,
                            ),
                            _buildRequirement(
                              'Contains lowercase letter',
                              _checkPasswordStrength(
                                      _newPasswordController.text)['lowercase'] ??
                                  false,
                            ),
                            _buildRequirement(
                              'Contains number',
                              _checkPasswordStrength(
                                      _newPasswordController.text)['number'] ??
                                  false,
                            ),
                            _buildRequirement(
                              'Contains special character',
                              _checkPasswordStrength(
                                      _newPasswordController.text)['special'] ??
                                  false,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_showConfirmPassword,
                      onChanged: (value) {
                        // This triggers validation as the user types
                        _formKey.currentState?.validate();
                      },
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00C49A)),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showConfirmPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _showConfirmPassword = !_showConfirmPassword;
                            });
                          },
                        ),
                        // Show error text as part of the decoration if passwords don't match
                        errorText: (_confirmPasswordController.text.isNotEmpty &&
                                !_passwordsMatch)
                            ? 'Passwords do not match'
                            : null,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C49A),
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Change Password',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}