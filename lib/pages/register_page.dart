import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/location_service.dart';
import '../models/community.dart';
import '../models/registration_data.dart';
import 'otp_verification_page.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:async';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  DateTime? _selectedDate;
  final LocationService _locationService = LocationService();
  Region? _selectedRegion;
  Province? _selectedProvince;
  Municipality? _selectedMunicipality;
  Barangay? _selectedBarangay;
  List<Region> _regions = [];
  List<Province> _provinces = [];
  List<Municipality> _municipalities = [];
  List<Barangay> _barangays = [];
  final GlobalKey<DropdownSearchState<Region>> _regionDropdownKey = GlobalKey();
  final GlobalKey<DropdownSearchState<Province>> _provinceDropdownKey =
      GlobalKey();
  final GlobalKey<DropdownSearchState<Municipality>> _municipalityDropdownKey =
      GlobalKey();
  final GlobalKey<DropdownSearchState<Barangay>> _barangayDropdownKey =
      GlobalKey();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _shakeController;
  final ScrollController _scrollController = ScrollController();
  bool _isEmailAvailable = true;
  bool _isCheckingEmail = false;
  Timer? _emailCheckDebouncer;



  @override
  void initState() {
    super.initState();
    _loadRegions();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _emailCheckDebouncer?.cancel();
    _shakeController.dispose();
    _scrollController.dispose();
    _birthDateController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await _locationService.getRegions();
      setState(() {
        _regions = regions;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading regions: $e')),
        );
      }
    }
  }

  Future<void> _loadProvinces(String regionCode) async {
    try {
      final provinces = await _locationService.getProvinces(regionCode);
      setState(() {
        _provinces = provinces;
        _selectedProvince = null;
        _municipalities = [];
        _selectedMunicipality = null;
        _barangays = [];
        _selectedBarangay = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading provinces: $e')),
        );
      }
    }
  }

  Future<void> _loadMunicipalities(String provinceCode) async {
    try {
      final municipalities =
          await _locationService.getMunicipalities(provinceCode);
      setState(() {
        _municipalities = municipalities;
        _selectedMunicipality = null;
        _barangays = [];
        _selectedBarangay = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading municipalities: $e')),
        );
      }
    }
  }

  Future<void> _loadBarangays(String municipalityCode) async {
    try {
      final barangays = await _locationService.getBarangays(municipalityCode);
      setState(() {
        _barangays = barangays;
        _selectedBarangay = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading barangays: $e')),
        );
      }
    }
  }



  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text = DateFormat('MMMM dd, yyyy').format(picked);
      });
    }
  }

  void _scrollToField(GlobalKey fieldKey) {
    final context = fieldKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
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

  Future<void> _checkEmailAvailability(String email) async {
    if (email.isEmpty) {
      setState(() {
        _isEmailAvailable = true;
        _isCheckingEmail = false;
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (mounted) {
        setState(() {
          _isEmailAvailable = querySnapshot.docs.isEmpty;
          _isCheckingEmail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isEmailAvailable = true;
          _isCheckingEmail = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking email: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFF5FBF9),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C49A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00C49A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fill in your details to get started',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00C49A)),
                      ),
                      prefixIcon: const Icon(Icons.person_outline),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00C49A)),
                      ),
                      prefixIcon: const Icon(Icons.alternate_email),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00C49A)),
                      ),
                      prefixIcon: const Icon(Icons.mail_outline),
                      suffixIcon: _isCheckingEmail
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : _emailController.text.isNotEmpty &&
                                  !_isEmailAvailable
                              ? const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                )
                              : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (value) {
                      // Cancel previous debounced call
                      _emailCheckDebouncer?.cancel();
                      // Create new debounced call
                      _emailCheckDebouncer = Timer(
                        const Duration(milliseconds: 500),
                        () => _checkEmailAvailability(value),
                      );
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email address';
                      }
                      if (!_isEmailAvailable) {
                        return 'This email is already registered';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00C49A)),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    obscureText: _obscurePassword,
                    onChanged: (value) {
                      // Force rebuild to update password requirements
                      setState(() {});
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (!_isPasswordStrong(value)) {
                        return 'Password does not meet requirements';
                      }
                      return null;
                    },
                  ),
                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 16),
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
                                    _passwordController.text)['length'] ??
                                false,
                          ),
                          _buildRequirement(
                            'Contains uppercase letter',
                            _checkPasswordStrength(
                                    _passwordController.text)['uppercase'] ??
                                false,
                          ),
                          _buildRequirement(
                            'Contains lowercase letter',
                            _checkPasswordStrength(
                                    _passwordController.text)['lowercase'] ??
                                false,
                          ),
                          _buildRequirement(
                            'Contains number',
                            _checkPasswordStrength(
                                    _passwordController.text)['number'] ??
                                false,
                          ),
                          _buildRequirement(
                            'Contains special character',
                            _checkPasswordStrength(
                                    _passwordController.text)['special'] ??
                                false,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00C49A)),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  _buildNewFields(),
                  const SizedBox(height: 16),
                  // Show community status message
                  if (_selectedBarangay != null && _communityStatusMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _communityStatusMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    height: 50,
                    margin: const EdgeInsets.only(top: 8),
                    child: AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            sin(_shakeController.value * 2 * pi) * 10,
                            0,
                          ),
                          child: child,
                        );
                      },
                      child: ElevatedButton(
                        onPressed: _isLoading || !_isFormValid()
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate() &&
                                    _selectedDate != null &&
                                    _selectedRegion != null &&
                                    _selectedProvince != null &&
                                    _selectedMunicipality != null &&
                                    _selectedBarangay != null) {
                                  setState(() {
                                    _isLoading = true;
                                  });

                                  final locationId = Community.createLocationId(
                                    _selectedRegion!.code,
                                    _selectedProvince!.code,
                                    _selectedMunicipality!.code,
                                    _selectedBarangay!.code,
                                  );

                                  Map<String, String> location = {
                                    'region': _selectedRegion!.name,
                                    'regionCode': _selectedRegion!.code,
                                    'province': _selectedProvince!.name,
                                    'provinceCode': _selectedProvince!.code,
                                    'municipality': _selectedMunicipality!.name,
                                    'municipalityCode':
                                        _selectedMunicipality!.code,
                                    'barangay': _selectedBarangay!.name,
                                    'barangayCode': _selectedBarangay!.code,
                                    'locationId': locationId,
                                  };

                                  // Create registration data
                                  final registrationData = RegistrationData(
                                    email: _emailController.text.trim(),
                                    password: _passwordController.text,
                                    fullName: _nameController.text.trim(),
                                    username: _usernameController.text.trim(),
                                    mobile:
                                        '+63${_mobileController.text.trim()}',
                                    birthDate: _selectedDate!,
                                    address: _addressController.text.trim(),
                                    location: location,
                                  );

                                  // Navigate to OTP verification page
                                  try {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            OTPVerificationPage(
                                          registrationData: registrationData,
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString()),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
                                  }
                                } else {
                                  // Shake the button
                                  _shakeController.forward(from: 0);

                                  // Find and scroll to the first invalid field
                                  if (_nameController.text.isEmpty) {
                                    _scrollToField(_formKey);
                                  } else if (_usernameController.text.isEmpty) {
                                    _scrollToField(_formKey);
                                  } else if (_emailController.text.isEmpty) {
                                    _scrollToField(_formKey);
                                  } else if (_passwordController.text.isEmpty ||
                                      !_isPasswordStrong(
                                          _passwordController.text)) {
                                    _scrollToField(_formKey);
                                  } else if (_confirmPasswordController
                                          .text.isEmpty ||
                                      _confirmPasswordController.text !=
                                          _passwordController.text) {
                                    _scrollToField(_formKey);
                                  } else if (_mobileController.text.isEmpty ||
                                      !RegExp(r'^\d{10}$')
                                          .hasMatch(_mobileController.text)) {
                                    _scrollToField(_formKey);
                                  } else if (_selectedDate == null) {
                                    _scrollToField(_formKey);
                                  } else if (_selectedRegion == null) {
                                    _scrollToField(_regionDropdownKey);
                                  } else if (_selectedProvince == null) {
                                    _scrollToField(_provinceDropdownKey);
                                  } else if (_selectedMunicipality == null) {
                                    _scrollToField(_municipalityDropdownKey);
                                  } else if (_selectedBarangay == null) {
                                    _scrollToField(_barangayDropdownKey);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C49A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          disabledBackgroundColor:
                              const Color(0xFF00C49A).withOpacity(0.5),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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
    );
  }

  Widget _buildNewFields() {
    return Column(
      children: [
        const SizedBox(height: 16),
        TextFormField(
          controller: _mobileController,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Mobile Number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00C49A)),
            ),
            prefixIcon: const Icon(Icons.phone_outlined),
            prefixText: '+63 ',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your mobile number';
            }
            if (!RegExp(r'^\d{10}$').hasMatch(value)) {
              return 'Please enter 10 digits for mobile number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _birthDateController,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                labelText: 'Birth Date',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00C49A)),
                ),
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (_) {
                if (_selectedDate == null) {
                  return 'Please select your birth date';
                }
                

                final today = DateTime.now();
                final age = today.year - _selectedDate!.year -
                    (today.month < _selectedDate!.month ||
                            (today.month == _selectedDate!.month &&
                                today.day < _selectedDate!.day)
                        ? 1
                        : 0);
                        
                if (age < 18) {
                  return 'Registration is only allowed for users 18 years old and above.';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00C49A)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          child: Column(
            children: [
              DropdownSearch<Region>(
                key: _regionDropdownKey,
                items: _regions,
                itemAsString: (Region? region) => region?.name ?? '',
                onChanged: (Region? region) {
                  setState(() {
                    _selectedRegion = region;
                    if (region != null) {
                      _loadProvinces(region.code);
                    }
                  });
                },
                selectedItem: _selectedRegion,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Region',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null) {
                    return 'Please select a region';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownSearch<Province>(
                key: _provinceDropdownKey,
                enabled: _selectedRegion != null,
                items: _provinces,
                itemAsString: (Province? province) => province?.name ?? '',
                onChanged: (Province? province) {
                  setState(() {
                    _selectedProvince = province;
                    if (province != null) {
                      _loadMunicipalities(province.code);
                    }
                  });
                },
                selectedItem: _selectedProvince,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Province',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null) {
                    return 'Please select a province';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownSearch<Municipality>(
                key: _municipalityDropdownKey,
                enabled: _selectedProvince != null,
                items: _municipalities,
                itemAsString: (Municipality? municipality) =>
                    municipality?.name ?? '',
                onChanged: (Municipality? municipality) {
                  setState(() {
                    _selectedMunicipality = municipality;
                    if (municipality != null) {
                      _loadBarangays(municipality.code);
                    }
                  });
                },
                selectedItem: _selectedMunicipality,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'City / Municipality',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null) {
                    return 'Please select a city / municipality';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownSearch<Barangay>(
                key: _barangayDropdownKey,
                enabled: _selectedMunicipality != null,
                items: _barangays,
                itemAsString: (Barangay? barangay) => barangay?.name ?? '',
                onChanged: (Barangay? barangay) async {
                  setState(() {
                    _selectedBarangay = barangay;
                  });

                  // Check if community is active when barangay is selected
                  if (barangay != null && _selectedRegion != null &&
                      _selectedProvince != null && _selectedMunicipality != null) {
                    await _checkCommunityStatus();
                  }
                },
                selectedItem: _selectedBarangay,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Barangay',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null) {
                    return 'Please select a barangay';
                  }
                  // We're showing the community status message in a separate container
                  // so we don't need to show it here as well
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address / Street No. (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00C49A)),
                  ),
                  prefixIcon: const Icon(Icons.home_outlined),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isCommunityActive = false;
  String? _communityStatusMessage;

  Future<void> _checkCommunityStatus() async {
    if (_selectedRegion == null || _selectedProvince == null ||
        _selectedMunicipality == null || _selectedBarangay == null) {
      return;
    }

    setState(() {
      _isCommunityActive = false;
      _communityStatusMessage = null;
    });

    try {
      // We'll manually check each community for a match

      // Get all communities to check
      final communitiesRef = FirebaseDatabase.instance.ref().child('communities');
      final allCommunitiesSnapshot = await communitiesRef.get();

      if (allCommunitiesSnapshot.exists) {
        final allCommunities = allCommunitiesSnapshot.value as Map<dynamic, dynamic>;
        bool foundActiveMatch = false;

        // Manually check each community since we can't query by locationStatusId without an index
        for (var entry in allCommunities.entries) {
          final community = entry.value as Map<dynamic, dynamic>;

          // Check if this community matches our barangay code and is active
          if (community['barangayCode'] == _selectedBarangay!.code &&
              community['status'] == 'active' &&
              community['adminId'] != null) {

            // Found an active community for this barangay
            setState(() {
              _isCommunityActive = true;
              _communityStatusMessage = null; // Clear any previous error message
            });

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Community is active and ready for registration'),
                  backgroundColor: Colors.green,
                ),
              );
            }

            foundActiveMatch = true;
            break;
          }
        }

        // If no active community was found
        if (!foundActiveMatch) {
          setState(() {
            _isCommunityActive = false;
            _communityStatusMessage = 'This community is not yet active or has no admin. Registration is not available.';
          });
        }
      }

      else {
        // No communities found at all
        setState(() {
          _isCommunityActive = false;
          _communityStatusMessage = 'No communities found in the database.';
        });
      }
    } catch (e) {
      // Use ScaffoldMessenger instead of print for errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking community status: $e')),
        );
      }
      setState(() {
        _isCommunityActive = false;
        _communityStatusMessage = 'Error checking community status';
      });
    }
  }

  bool _isFormValid() {
    return _nameController.text.isNotEmpty &&
        _usernameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _isPasswordStrong(_passwordController.text) &&
        _confirmPasswordController.text == _passwordController.text &&
        _mobileController.text.isNotEmpty &&
        RegExp(r'^\d{10}$').hasMatch(_mobileController.text) &&
        _selectedDate != null &&
        _selectedRegion != null &&
        _selectedProvince != null &&
        _selectedMunicipality != null &&
        _selectedBarangay != null &&
        _isCommunityActive; // Add check for active community
  }
}
