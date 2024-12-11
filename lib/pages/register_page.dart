import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _selectedDate;
  final _locationService = LocationService();
  Region? _selectedRegion;
  Province? _selectedProvince;
  Municipality? _selectedMunicipality;
  Barangay? _selectedBarangay;
  List<Region> _regions = [];
  List<Province> _provinces = [];
  List<Municipality> _municipalities = [];
  List<Barangay> _barangays = [];
  final _regionDropdownKey = GlobalKey<DropdownSearchState<Region>>();
  final _provinceDropdownKey = GlobalKey<DropdownSearchState<Province>>();
  final _municipalityDropdownKey =
      GlobalKey<DropdownSearchState<Municipality>>();
  final _barangayDropdownKey = GlobalKey<DropdownSearchState<Barangay>>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await _locationService.getRegions();
      setState(() {
        _regions = regions;
      });
    } catch (e) {
      // Handle error
      print('Error loading regions: $e');
    }
  }

  Future<void> _loadProvinces(String regionCode) async {
    try {
      final provinces = await _locationService.getProvinces(regionCode);
      setState(() {
        _provinces = provinces;
        _selectedProvince = null;
        _municipalities = [];
        _barangays = [];
      });
    } catch (e) {
      print('Error loading provinces: $e');
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
      });
    } catch (e) {
      print('Error loading municipalities: $e');
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
      print('Error loading barangays: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildNewFields() {
    return Column(
      children: [
        const SizedBox(height: 16),
        TextFormField(
          controller: _mobileController,
          decoration: const InputDecoration(
            labelText: 'Mobile Number',
            border: OutlineInputBorder(),
            prefixText: '+63 ',
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your mobile number';
            }
            if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
              return 'Please enter a valid 10-digit mobile number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectDate(context),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Birth Date',
              border: OutlineInputBorder(),
            ),
            child: Text(
              _selectedDate == null
                  ? 'Select Date'
                  : DateFormat('MMM dd, yyyy').format(_selectedDate!),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownSearch<Region>(
          key: _regionDropdownKey,
          popupProps: const PopupProps.menu(
            showSelectedItems: true,
            showSearchBox: true,
          ),
          items: _regions,
          itemAsString: (Region? region) => region?.name ?? '',
          compareFn: (Region? r1, Region? r2) => r1?.code == r2?.code,
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: "Region",
              border: OutlineInputBorder(),
            ),
          ),
          onChanged: (Region? value) {
            setState(() {
              _selectedRegion = value;
              if (value != null) {
                _loadProvinces(value.code);
              }
            });
          },
        ),
        const SizedBox(height: 16),
        DropdownSearch<Province>(
          key: _provinceDropdownKey,
          popupProps: const PopupProps.menu(
            showSelectedItems: true,
            showSearchBox: true,
          ),
          items: _provinces,
          itemAsString: (Province? province) => province?.name ?? '',
          compareFn: (Province? p1, Province? p2) => p1?.code == p2?.code,
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: "Province",
              border: OutlineInputBorder(),
            ),
          ),
          onChanged: (Province? value) {
            setState(() {
              _selectedProvince = value;
              if (value != null) {
                _loadMunicipalities(value.code);
              }
            });
          },
        ),
        const SizedBox(height: 16),
        DropdownSearch<Municipality>(
          key: _municipalityDropdownKey,
          popupProps: const PopupProps.menu(
            showSelectedItems: true,
            showSearchBox: true,
          ),
          items: _municipalities,
          itemAsString: (Municipality? municipality) =>
              municipality?.name ?? '',
          compareFn: (Municipality? m1, Municipality? m2) =>
              m1?.code == m2?.code,
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: "Municipality",
              border: OutlineInputBorder(),
            ),
          ),
          onChanged: (Municipality? value) {
            setState(() {
              _selectedMunicipality = value;
              if (value != null) {
                _loadBarangays(value.code);
              }
            });
          },
        ),
        const SizedBox(height: 16),
        DropdownSearch<Barangay>(
          key: _barangayDropdownKey,
          popupProps: const PopupProps.menu(
            showSelectedItems: true,
            showSearchBox: true,
          ),
          items: _barangays,
          itemAsString: (Barangay? barangay) => barangay?.name ?? '',
          compareFn: (Barangay? b1, Barangay? b2) => b1?.code == b2?.code,
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: "Barangay",
              border: OutlineInputBorder(),
            ),
          ),
          onChanged: (Barangay? value) {
            setState(() {
              _selectedBarangay = value;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Street Address / House Number',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your street address';
            }
            return null;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name (Include Middle Name if applicable)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    if (value.contains(' ')) {
                      return 'Username cannot contain spaces';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
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
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                _buildNewFields(),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 50,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate() &&
                          _selectedDate != null &&
                          _selectedRegion != null &&
                          _selectedProvince != null &&
                          _selectedMunicipality != null &&
                          _selectedBarangay != null) {
                        setState(() {
                          _isLoading = true;
                        });
                        try {
                          Map<String, String> location = {
                            'region': _selectedRegion!.name,
                            'province': _selectedProvince!.name,
                            'municipality': _selectedMunicipality!.name,
                            'barangay': _selectedBarangay!.name,
                          };

                          await _authService.registerWithEmailAndPassword(
                            email: _emailController.text.trim(),
                            password: _passwordController.text,
                            fullName: _nameController.text.trim(),
                            username: _usernameController.text.trim(),
                            mobile: _mobileController.text.trim(),
                            birthDate: _selectedDate!,
                            address: _addressController.text.trim(),
                            location: location,
                          );

                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MainScreen(isLoggedIn: true),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
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
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Register',
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
    );
  }
}
