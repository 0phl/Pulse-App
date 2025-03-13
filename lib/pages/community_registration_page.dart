import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../models/admin_application.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/location_service.dart';
import '../services/community_service.dart';
import 'package:file_picker/file_picker.dart';
import '../services/cloudinary_service.dart';
import 'dart:io';

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
  final CommunityService _communityService = CommunityService();
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
  List<File> _selectedFiles = [];
  bool _isLoading = false;
  bool _isUploadingFiles = false;
  bool _isCheckingCommunity = false;

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

  Future<void> _checkCommunityExists() async {
    if (_selectedRegion == null ||
        _selectedProvince == null ||
        _selectedMunicipality == null ||
        _selectedBarangay == null) {
      return;
    }

    setState(() {
      _isCheckingCommunity = true;
    });

    try {
      final exists = await _communityService.checkCommunityExists(
        regionCode: _selectedRegion!.code,
        provinceCode: _selectedProvince!.code,
        municipalityCode: _selectedMunicipality!.code,
        barangayCode: _selectedBarangay!.code,
      );

      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This community is already registered. Please contact the administrator.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking community status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingCommunity = false;
        });
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: true,
        withData: true,
        onFileLoading: (FilePickerStatus status) => print(status),
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(
            result.paths.map((path) => File(path!)).toList(),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<String>> _uploadFiles() async {
    setState(() {
      _isUploadingFiles = true;
    });

    try {
      final cloudinaryService = CloudinaryService();
      final uploadedUrls = await cloudinaryService.uploadFiles(_selectedFiles);
      return uploadedUrls;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFiles = false;
        });
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
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        Icons.groups_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Community Registration',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00C49A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Register your community to get started',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _fullNameController,
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
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Full name is required' : null,
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Email is required';
                      if (!value!.contains('@')) return 'Invalid email';
                      return null;
                    },
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
                          borderSide:
                              const BorderSide(color: Color(0xFF00C49A)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
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
                              prefixIcon:
                                  const Icon(Icons.location_on_outlined),
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
                          itemAsString: (Province? province) =>
                              province?.name ?? '',
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
                              prefixIcon:
                                  const Icon(Icons.location_on_outlined),
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
                              prefixIcon:
                                  const Icon(Icons.location_city_outlined),
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
                          itemAsString: (Barangay? barangay) =>
                              barangay?.name ?? '',
                          onChanged: (Barangay? barangay) {
                            setState(() {
                              _selectedBarangay = barangay;
                              if (barangay != null) {
                                _checkCommunityExists();
                              }
                            });
                          },
                          selectedItem: _selectedBarangay,
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              labelText: 'Barangay',
                              prefixIcon:
                                  const Icon(Icons.location_on_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Required Documents',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please upload supporting documents (e.g., barangay certification, valid IDs, organization documents)',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _selectedFiles.length,
                          itemBuilder: (context, index) {
                            final file = _selectedFiles[index];
                            return ListTile(
                              leading: Icon(
                                file.path.toLowerCase().endsWith('.pdf')
                                    ? Icons.picture_as_pdf
                                    : Icons.image,
                                color: const Color(0xFF00C49A),
                              ),
                              title: Text(
                                file.path.split('/').last,
                                style: const TextStyle(fontSize: 14),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _selectedFiles.removeAt(index);
                                  });
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _pickFiles,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload Documents'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF00C49A),
                              side: const BorderSide(color: Color(0xFF00C49A)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _selectedFiles.isEmpty || _isCheckingCommunity)
                          ? null
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                setState(() {
                                  _isLoading = true;
                                });

                                try {
                                  // Check if community exists
                                  final exists = await _communityService.checkCommunityExists(
                                    regionCode: _selectedRegion!.code,
                                    provinceCode: _selectedProvince!.code,
                                    municipalityCode: _selectedMunicipality!.code,
                                    barangayCode: _selectedBarangay!.code,
                                  );

                                  if (exists) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'This community is already registered. Please contact the administrator.',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  // Upload files first
                                  final uploadedUrls = await _uploadFiles();

                                  // Create the community first
                                  final communityId = await _communityService.createCommunity(
                                    name: '${_selectedBarangay?.name} Community',
                                    description: 'Community for ${_selectedBarangay?.name}',
                                    regionCode: _selectedRegion!.code,
                                    provinceCode: _selectedProvince!.code,
                                    municipalityCode: _selectedMunicipality!.code,
                                    barangayCode: _selectedBarangay!.code,
                                  );

                                  // Then create the admin application
                                  final application = AdminApplication(
                                    id: '',
                                    fullName: _fullNameController.text,
                                    email: _emailController.text,
                                    communityId: communityId,
                                    communityName: '${_selectedBarangay?.name} Community',
                                    documents: uploadedUrls,
                                    status: 'pending',
                                    createdAt: DateTime.now(),
                                  );

                                  await FirebaseDatabase.instance
                                    .ref()
                                    .child('admin_applications')
                                    .push()
                                    .set(application.toJson());

                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Application submitted successfully! We will review and contact you via email.',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Error submitting application: $e'),
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
                        backgroundColor: const Color(0xFF00C49A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor:
                            const Color(0xFF00C49A).withOpacity(0.5),
                      ),
                      child: _isLoading || _isUploadingFiles || _isCheckingCommunity
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isUploadingFiles
                                      ? 'Uploading Files...'
                                      : _isCheckingCommunity
                                          ? 'Checking Community...'
                                          : 'Submitting...',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Submit Application',
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
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
