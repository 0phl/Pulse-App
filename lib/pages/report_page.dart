import 'package:flutter/material.dart';

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
      _showSuccessDialog();

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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00C49A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF00C49A),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Report Submitted',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your report has been submitted successfully. We will review it shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Switch to My Reports tab
                  _tabController.animateTo(1);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C49A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('View My Reports'),
              ),
            ),
          ],
        ),
      ),
    );
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
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: Colors.grey.shade50,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStepIndicator(
                        step: 0,
                        title: 'Details',
                        isActive: _currentStep >= 0,
                        isCompleted: _currentStep > 0,
                      ),
                    ),
                    Expanded(
                      child: _buildStepIndicator(
                        step: 1,
                        title: 'Location',
                        isActive: _currentStep >= 1,
                        isCompleted: _currentStep > 1,
                      ),
                    ),
                    Expanded(
                      child: _buildStepIndicator(
                        step: 2,
                        title: 'Review',
                        isActive: _currentStep >= 2,
                        isCompleted: _currentStep > 2,
                      ),
                    ),
                  ],
                ),
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

  Widget _buildStepIndicator({
    required int step,
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Line before (except for first step)
            if (step > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color:
                      isActive ? const Color(0xFF00C49A) : Colors.grey.shade300,
                ),
              ),

            // Circle indicator
            GestureDetector(
              onTap: () {
                if (step <= _getMaxAllowedStep()) {
                  setState(() {
                    _currentStep = step;
                  });
                }
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? const Color(0xFF00C49A)
                      : isActive
                          ? Colors.white
                          : Colors.grey.shade300,
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF00C49A)
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? const Color(0xFF00C49A)
                                : Colors.grey,
                          ),
                        ),
                ),
              ),
            ),

            // Line after (except for last step)
            if (step < 2)
              Expanded(
                child: Container(
                  height: 2,
                  color: isCompleted
                      ? const Color(0xFF00C49A)
                      : Colors.grey.shade300,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF00C49A) : Colors.grey,
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
        _buildFormField(
          label: 'Issue Type',
          isRequired: true,
          child: _buildSearchableDropdown(),
        ),

        // Description Field
        _buildFormField(
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
        _buildFormField(
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
              _buildReviewItem(
                icon: Icons.report_problem_outlined,
                label: 'Issue Type',
                value: _selectedIssueType ?? '',
              ),
              const Divider(height: 24),

              // Description
              _buildReviewItem(
                icon: Icons.description_outlined,
                label: 'Description',
                value: _descriptionController.text,
              ),
              const Divider(height: 24),

              // Location
              _buildReviewItem(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: _addressController.text,
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

  Widget _buildReviewItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00C49A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF00C49A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _currentStep = label == 'Location' ? 1 : 0;
            });
          },
          icon: const Icon(
            Icons.edit,
            size: 16,
            color: Color(0xFF00C49A),
          ),
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildMyReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(label: 'All', isSelected: true),
              _buildFilterChip(label: 'Pending'),
              _buildFilterChip(label: 'In Progress'),
              _buildFilterChip(label: 'Resolved'),
              _buildFilterChip(label: 'Rejected'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Reports List
        _buildReportItem(
          title: 'Street Light Out',
          location: 'Niog, Pavillion',
          date: 'Today, 2:30 PM',
          status: 'Pending',
          statusColor: Colors.orange,
        ),
        _buildReportItem(
          title: 'Pothole on Main Street',
          location: '123 Main St, Downtown',
          date: 'Yesterday, 10:15 AM',
          status: 'In Progress',
          statusColor: Colors.blue,
        ),
        _buildReportItem(
          title: 'Garbage Collection Issue',
          location: '45 Park Avenue',
          date: 'Mar 15, 2023',
          status: 'Resolved',
          statusColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildFilterChip({required String label, bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {},
        backgroundColor: Colors.grey.shade100,
        selectedColor: const Color(0xFF00C49A).withOpacity(0.1),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF00C49A) : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? const Color(0xFF00C49A) : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildReportItem({
    required String title,
    required String location,
    required String date,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Report #${1000 + (title.hashCode % 1000)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF00C49A),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('View Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required Widget child,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildSearchableDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input field
        TextFormField(
          controller: _issueTypeController,
          onTap: () {
            setState(() {
              _isSearching = true;
            });
          },
          onChanged: (value) {
            _filterIssueTypes(value);
          },
          decoration: InputDecoration(
            hintText: 'Select or type issue type',
            suffixIcon: Icon(
              _isSearching ? Icons.close : Icons.arrow_drop_down,
              color: Colors.grey,
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          readOnly: false,
        ),

        // Dropdown options
        if (_isSearching)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(
              maxHeight: 180,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _filteredIssueTypes.length,
              itemBuilder: (context, index) {
                final type = _filteredIssueTypes[index];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    type,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedIssueType = type;
                      _issueTypeController.text = type;
                      _isSearching = false;
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
