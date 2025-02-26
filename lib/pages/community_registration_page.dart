import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../models/admin_application.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/location_service.dart';

class CommunityRegistrationPage extends StatefulWidget {
  const CommunityRegistrationPage({super.key});

  @override
  State<CommunityRegistrationPage> createState() =>
      _CommunityRegistrationPageState();
}

class _CommunityRegistrationPageState extends State<CommunityRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
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
  List<String> _documents = [];
  bool _isLoading = false;

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
        _barangays = [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Community'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Community Registration',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Full name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Email is required';
                  if (!value!.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownSearch<Region>(
                key: _regionDropdownKey,
                items: _regions,
                itemAsString: (Region? r) => r?.name ?? '',
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: "Region",
                    border: OutlineInputBorder(),
                  ),
                ),
                onChanged: (Region? value) {
                  setState(() {
                    _selectedRegion = value;
                    _selectedProvince = null;
                    _selectedMunicipality = null;
                    _selectedBarangay = null;
                    _provinces = [];
                    _municipalities = [];
                    _barangays = [];
                  });
                  if (value != null) {
                    _loadProvinces(value.code);
                  }
                },
                selectedItem: _selectedRegion,
                validator: (value) =>
                    value == null ? 'Please select a region' : null,
              ),
              const SizedBox(height: 16),
              DropdownSearch<Province>(
                key: _provinceDropdownKey,
                items: _provinces,
                itemAsString: (Province? p) => p?.name ?? '',
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: "Province",
                    border: OutlineInputBorder(),
                  ),
                ),
                onChanged: (Province? value) {
                  setState(() {
                    _selectedProvince = value;
                    _selectedMunicipality = null;
                    _selectedBarangay = null;
                    _municipalities = [];
                    _barangays = [];
                  });
                  if (value != null) {
                    _loadMunicipalities(value.code);
                  }
                },
                selectedItem: _selectedProvince,
                validator: (value) =>
                    value == null ? 'Please select a province' : null,
              ),
              const SizedBox(height: 16),
              DropdownSearch<Municipality>(
                key: _municipalityDropdownKey,
                items: _municipalities,
                itemAsString: (Municipality? m) => m?.name ?? '',
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: "City/Municipality",
                    border: OutlineInputBorder(),
                  ),
                ),
                onChanged: (Municipality? value) {
                  setState(() {
                    _selectedMunicipality = value;
                    _selectedBarangay = null;
                    _barangays = [];
                  });
                  if (value != null) {
                    _loadBarangays(value.code);
                  }
                },
                selectedItem: _selectedMunicipality,
                validator: (value) =>
                    value == null ? 'Please select a city/municipality' : null,
              ),
              const SizedBox(height: 16),
              DropdownSearch<Barangay>(
                key: _barangayDropdownKey,
                items: _barangays,
                itemAsString: (Barangay? b) => b?.name ?? '',
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: "Barangay",
                    border: OutlineInputBorder(),
                  ),
                ),
                onChanged: (Barangay? value) {
                  setState(() {
                    _selectedBarangay = value;
                    if (value != null) {
                      // Show the auto-generated community name in a snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Community will be registered as: ${value.name}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  });
                },
                selectedItem: _selectedBarangay,
                validator: (value) =>
                    value == null ? 'Please select a barangay' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  // TODO: Implement document upload
                  _documents.add('document_url');
                  setState(() {});
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Registration Documents'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              if (_documents.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_documents.length} document(s) uploaded',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.green),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitApplication,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Submit Application'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload registration documents'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get a new key for the application
      final newRef = FirebaseDatabase.instance
          .ref()
          .child('admin_applications')
          .push();

      // Generate community name from selected barangay
      if (_selectedBarangay == null) {
        throw Exception('Please select a barangay');
      }

      final communityName = _selectedBarangay!.name;

      // Create application with the generated key
      final application = AdminApplication(
        id: newRef.key ?? '',
        fullName: _fullNameController.text,
        email: _emailController.text,
        communityId: '',
        communityName: communityName,
        documents: _documents,
        status: 'pending',
        createdAt: DateTime.now(),
      );
      
      // Save the application
      await newRef.set(application.toJson());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Application submitted successfully! We will review and contact you via email.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting application: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
