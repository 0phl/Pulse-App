import 'package:flutter/material.dart';
import '../widgets/report_stepper.dart';
import '../widgets/report_form_field.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/user_report_card.dart';
import '../widgets/report_filter_chip.dart';
import '../widgets/report_success_dialog.dart';
import '../widgets/report_review_item.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage>
    with SingleTickerProviderStateMixin {
  final List<String> _issueTypes = const [
    'Fires',
    'Street Light Damage',
    'Road Damage/Potholes',
    'Flooding/Drainage Issues',
    'Illegal Parking',
    'Garbage Collection Problems',
    'Noise Disturbances',
    'Stray Animals',
    'Illegal Dumping of Waste',
    'Suspicious Activities/Security Concerns',
    'Others'
  ];

  String? _selectedIssueType;
  final TextEditingController _issueTypeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSearching = false;
  List<String> _filteredIssueTypes = [];
  bool _isUploading = false;
  int _currentStep = 0;
  late TabController _tabController;
  final List<String> _tabs = ['New Report', 'My Reports'];
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _filteredIssueTypes = List.from(_issueTypes);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _issueTypeController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _filterIssueTypes(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredIssueTypes = List.from(_issueTypes);
      } else {
        _filteredIssueTypes = _issueTypes
            .where((type) => type.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _submitReport() {
    // Validate form
    if (_selectedIssueType == null || _selectedIssueType!.isEmpty) {
      _showSnackBar('Please select an issue type');
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      _showSnackBar('Please enter an address');
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar('Please provide a description');
      return;
    }

    // Simulate upload
    setState(() {
      _isUploading = true;
    });

    // Simulate network delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isUploading = false;
      });

      // Show success dialog
      ReportSuccessDialog.show(context, () {
        _tabController.animateTo(1);
      });

      // Reset form
      setState(() {
        _selectedIssueType = null;
        _issueTypeController.clear();
        _addressController.clear();
        _descriptionController.clear();
        _currentStep = 0;
      });
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF00C49A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Community Reports',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF00C49A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard and dropdown when tapping outside
          FocusScope.of(context).unfocus();
          setState(() {
            _isSearching = false;
          });
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            // New Report Tab
            _buildNewReportTab(),

            // My Reports Tab
            _buildMyReportsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewReportTab() {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              // Progress Stepper
              ReportStepper(
                currentStep: _currentStep,
                maxAllowedStep: _getMaxAllowedStep(),
                onStepTapped: (step) {
                  setState(() {
                    _currentStep = step;
                  });
                },
              ),

              // Form Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildStepContent(),
              ),
            ],
          ),
        ),

        // Loading Overlay
        if (_isUploading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
              ),
            ),
          ),
      ],
    );
  }

  int _getMaxAllowedStep() {
    if (_selectedIssueType == null || _selectedIssueType!.isEmpty) {
      return 0;
    }

    if (_addressController.text.trim().isEmpty) {
      return 1;
    }

    return 2;
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildDetailsStep();
      case 1:
        return _buildLocationStep();
      case 2:
        return _buildReviewStep();
      default:
        return _buildDetailsStep();
    }
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step Title
        const Text(
          'Report Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Provide information about the issue you want to report',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),

        // Issue Type Field
        ReportFormField(
          label: 'Issue Type',
          isRequired: true,
          child: SearchableDropdown(
            controller: _issueTypeController,
            items: _filteredIssueTypes,
            selectedItem: _selectedIssueType,
            hintText: 'Select or type issue type',
            onSearch: _filterIssueTypes,
            onItemSelected: (value) {
              setState(() {
                _selectedIssueType = value;
                _issueTypeController.text = value;
              });
            },
          ),
        ),

        // Description Field
        ReportFormField(
          label: 'Description',
          isRequired: true,
          child: TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Describe the issue in detail...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.all(12),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ),

        // Add Photo Button
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  // Photo picker would be implemented here
                },
                icon: const Icon(Icons.add_a_photo, size: 16),
                label: const Text('Add Photos'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00C49A),
                  side: BorderSide(color: Colors.grey.shade300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(Optional)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),

        // Next Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedIssueType != null &&
                    _descriptionController.text.isNotEmpty
                ? () {
                    setState(() {
                      _currentStep = 1;
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C49A),
              disabledBackgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Next: Location'),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step Title
        const Text(
          'Location Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Provide the exact location of the issue',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),

        // Address Field
        ReportFormField(
          label: 'Address',
          isRequired: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  hintText: 'Enter the full address',
                  prefixIcon:
                      const Icon(Icons.location_on, color: Color(0xFF00C49A)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _addressController.text = "Current Location";
                },
                icon: const Icon(Icons.my_location, size: 14),
                label: const Text('Use current location'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00C49A),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),

        // Map Placeholder
        Container(
          height: 180,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'Map View',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Navigation Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00C49A),
                  side: const BorderSide(color: Color(0xFF00C49A)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _addressController.text.isNotEmpty
                    ? () {
                        setState(() {
                          _currentStep = 2;
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C49A),
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Next: Review'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step Title
        const Text(
          'Review Your Report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Please review your report details before submitting',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),

        // Review Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              // Issue Type
              ReportReviewItem(
                icon: Icons.report_problem_outlined,
                label: 'Issue Type',
                value: _selectedIssueType ?? '',
                onEdit: () => setState(() => _currentStep = 0),
              ),
              const Divider(height: 24),

              // Description
              ReportReviewItem(
                icon: Icons.description_outlined,
                label: 'Description',
                value: _descriptionController.text,
                onEdit: () => setState(() => _currentStep = 0),
              ),
              const Divider(height: 24),

              // Location
              ReportReviewItem(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: _addressController.text,
                onEdit: () => setState(() => _currentStep = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Terms Checkbox
        Row(
          children: [
            Checkbox(
              value: true,
              onChanged: (value) {},
              activeColor: const Color(0xFF00C49A),
            ),
            Expanded(
              child: Text(
                'I confirm that the information provided is accurate to the best of my knowledge',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Navigation Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 1;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00C49A),
                  side: const BorderSide(color: Color(0xFF00C49A)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C49A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMyReportsTab() {
    // Mock data for reports
    final List<Map<String, dynamic>> reports = [
      {
        'title': 'Street Light Out',
        'location': 'Niog, Pavillion',
        'date': 'Today, 2:30 PM',
        'status': 'Pending',
        'statusColor': Colors.orange,
      },
      {
        'title': 'Pothole on Main Street',
        'location': '123 Main St, Downtown',
        'date': 'Yesterday, 10:15 AM',
        'status': 'In Progress',
        'statusColor': Colors.blue,
      },
      {
        'title': 'Garbage Collection Issue',
        'location': '45 Park Avenue',
        'date': 'Mar 15, 2023',
        'status': 'Resolved',
        'statusColor': Colors.green,
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ReportFilterChip(
                label: 'All',
                isSelected: _selectedFilter == 'All',
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = 'All';
                  });
                },
              ),
              ReportFilterChip(
                label: 'Pending',
                isSelected: _selectedFilter == 'Pending',
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = 'Pending';
                  });
                },
              ),
              ReportFilterChip(
                label: 'In Progress',
                isSelected: _selectedFilter == 'In Progress',
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = 'In Progress';
                  });
                },
              ),
              ReportFilterChip(
                label: 'Resolved',
                isSelected: _selectedFilter == 'Resolved',
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = 'Resolved';
                  });
                },
              ),
              ReportFilterChip(
                label: 'Rejected',
                isSelected: _selectedFilter == 'Rejected',
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = 'Rejected';
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Reports List
        ...reports.map((report) => UserReportCard(
              title: report['title'],
              location: report['location'],
              date: report['date'],
              status: report['status'],
              statusColor: report['statusColor'],
              onViewDetails: () {
                // Implement view details functionality
              },
            )),
      ],
    );
  }
}
