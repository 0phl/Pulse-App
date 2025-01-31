import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../main.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../services/community_service.dart';
import '../models/community.dart';
import 'package:firebase_database/firebase_database.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
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
  final AuthService _authService = AuthService();
  final CommunityService _communityService = CommunityService();

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    _birthDateController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<String> _getOrCreateCommunity() async {
    if (_selectedBarangay == null) {
      throw Exception('No barangay selected');
    }

    final communityName = 'Barangay ${_selectedBarangay!.name}';

    try {
      final communitiesRef =
          FirebaseDatabase.instance.ref().child('communities');

      // Query existing communities
      final snapshot = await communitiesRef
          .orderByChild('name')
          .equalTo(communityName)
          .get();

      if (snapshot.exists) {
        // Return existing community ID
        final Map<dynamic, dynamic> communities =
            snapshot.value as Map<dynamic, dynamic>;
        return communities.keys.first;
      }

      // Create new community
      final newCommunityRef = communitiesRef.push();
      await newCommunityRef.set({
        'name': communityName,
        'description':
            'Community for ${_selectedBarangay!.name}, ${_selectedMunicipality!.name}',
        'createdAt': ServerValue.timestamp,
      });

      return newCommunityRef.key!;
    } catch (e) {
      throw Exception('Error getting/creating community: $e');
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

  Widget _buildNewFields() {
    return Column(
      children: [
        const SizedBox(height: 16),
        TextFormField(
          controller: _mobileController,
          decoration: const InputDecoration(
            labelText: 'Mobile Number',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your mobile number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your address';
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
              decoration: const InputDecoration(
                labelText: 'Birth Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              validator: (_) => _selectedDate == null
                  ? 'Please select your birth date'
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
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
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: 'Region',
              border: OutlineInputBorder(),
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
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: 'Province',
              border: OutlineInputBorder(),
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
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: 'City/Municipality',
              border: OutlineInputBorder(),
            ),
          ),
          validator: (value) {
            if (value == null) {
              return 'Please select a city/municipality';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownSearch<Barangay>(
          key: _barangayDropdownKey,
          items: _barangays,
          itemAsString: (Barangay? barangay) => barangay?.name ?? '',
          onChanged: (Barangay? barangay) {
            setState(() {
              _selectedBarangay = barangay;
            });
          },
          selectedItem: _selectedBarangay,
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: 'Barangay',
              border: OutlineInputBorder(),
            ),
          ),
          validator: (value) {
            if (value == null) {
              return 'Please select a barangay';
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
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
                  onPressed: _isLoading
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

                            try {
                              Map<String, String> location = {
                                'region': _selectedRegion!.name,
                                'province': _selectedProvince!.name,
                                'municipality': _selectedMunicipality!.name,
                                'barangay': _selectedBarangay!.name,
                              };

                              // Get or create community based on barangay
                              final communityId = await _getOrCreateCommunity();

                              // Register user with the community
                              await _authService.registerWithEmailAndPassword(
                                email: _emailController.text.trim(),
                                password: _passwordController.text,
                                fullName: _nameController.text.trim(),
                                username: _usernameController.text.trim(),
                                mobile: _mobileController.text.trim(),
                                birthDate: _selectedDate!,
                                address: _addressController.text.trim(),
                                location: location,
                                communityId: communityId,
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
                                    backgroundColor:
                                        const Color.fromARGB(255, 90, 90, 90),
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
    );
  }
}
