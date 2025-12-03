import 'package:flutter/material.dart';
import '../../services/barangay_profiling_service.dart';
import '../../models/barangay_profile.dart';
import 'barangay_profile_detail_page.dart';
import 'package:intl/intl.dart';

class BarangayProfilingPage extends StatefulWidget {
  const BarangayProfilingPage({super.key});

  @override
  State<BarangayProfilingPage> createState() => _BarangayProfilingPageState();
}

class _BarangayProfilingPageState extends State<BarangayProfilingPage> {
  final BarangayProfilingService _profilingService = BarangayProfilingService();
  final TextEditingController _searchController = TextEditingController();

  List<BarangayProfile> _allProfiles = [];
  List<BarangayProfile> _filteredProfiles = [];
  String _selectedSortBy = 'name';
  bool _isLoading = true;

  final List<String> _sortOptions = [
    'name',
    'registeredAt',
    'totalUsers',
    'activeUsers',
  ];

  @override
  void initState() {
    super.initState();
    _loadBarangayProfiles();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadBarangayProfiles() {
    _profilingService.getBarangayProfilesStream().listen((profiles) {
      setState(() {
        _allProfiles = profiles;
        _applyFilters();
        _isLoading = false;
      });
    });
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    List<BarangayProfile> filtered = _allProfiles;

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      filtered =
          _profilingService.filterBarangays(filtered, _searchController.text);
    }

    // Only show active barangays
    filtered = filtered.where((profile) => profile.status == 'active').toList();

    // Apply sorting
    filtered = _profilingService.sortBarangays(filtered, _selectedSortBy);

    setState(() {
      _filteredProfiles = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEEEEE)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F7F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.location_city_rounded,
                        color: Color(0xFF00C49A),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Barangay User Profiling',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const Spacer(),
                    if (!isSmallScreen)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF16A34A).withOpacity(0.2)),
                        ),
                        child: Text(
                          '${_filteredProfiles.length} Active Barangays',
                          style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search and filters
                if (isSmallScreen) ...[
                  _buildSearchField(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSortDropdown()),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(flex: 3, child: _buildSearchField()),
                      const SizedBox(width: 16),
                      Expanded(flex: 1, child: _buildSortDropdown()),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProfiles.isEmpty
                    ? _buildEmptyState()
                    : isSmallScreen
                        ? _buildMobileList()
                        : _buildDesktopGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search barangays, admins, or locations...',
        prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF00C49A)),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedSortBy,
      decoration: InputDecoration(
        labelText: 'Sort by',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF00C49A)),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: _sortOptions.map((option) {
        return DropdownMenuItem(
          value: option,
          child: Text(_getSortDisplayName(option)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedSortBy = value!;
          _applyFilters();
        });
      },
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProfiles.length,
      itemBuilder: (context, index) {
        final profile = _filteredProfiles[index];
        return _buildMobileCard(profile);
      },
    );
  }

  Widget _buildDesktopGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: _filteredProfiles.length,
      itemBuilder: (context, index) {
        final profile = _filteredProfiles[index];
        return _buildDesktopCard(profile);
      },
    );
  }

  Widget _buildMobileCard(BarangayProfile profile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToProfile(profile),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE6F7F2),
                    backgroundImage: profile.adminAvatar != null
                        ? NetworkImage(profile.adminAvatar!)
                        : null,
                    child: profile.adminAvatar == null
                        ? const Icon(Icons.location_city,
                            color: Color(0xFF00C49A))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFF1F2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          profile.adminName,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(profile.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                profile.fullAddress,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatItem('Users',
                      profile.analytics.totalRegisteredUsers.toString()),
                  const SizedBox(width: 16),
                  _buildStatItem(
                      'Active', profile.analytics.totalActiveUsers.toString()),
                  const SizedBox(width: 16),
                  _buildStatItem(
                      'Reports', profile.analytics.reportsSubmitted.toString()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopCard(BarangayProfile profile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToProfile(profile),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFE6F7F2),
                    backgroundImage: profile.adminAvatar != null
                        ? NetworkImage(profile.adminAvatar!)
                        : null,
                    child: profile.adminAvatar == null
                        ? const Icon(Icons.location_city,
                            color: Color(0xFF00C49A), size: 28)
                        : null,
                  ),
                  const Spacer(),
                  _buildStatusBadge(profile.status),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                profile.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Color(0xFF1F2937),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Admin: ${profile.adminName}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                profile.fullAddress,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('Users',
                      profile.analytics.totalRegisteredUsers.toString()),
                  _buildStatItem(
                      'Active', profile.analytics.totalActiveUsers.toString()),
                  _buildStatItem(
                      'Reports', profile.analytics.reportsSubmitted.toString()),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Registered: ${DateFormat('MMM dd, yyyy').format(profile.registeredAt)}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF1F2937),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'active':
        backgroundColor = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF16A34A);
        displayText = 'Active';
        break;
      case 'pending':
        backgroundColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        displayText = 'Pending';
        break;
      case 'inactive':
        backgroundColor = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFDC2626);
        displayText = 'Inactive';
        break;
      default:
        backgroundColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF64748B);
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.location_city_outlined,
              size: 48,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No barangays found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getSortDisplayName(String sortBy) {
    switch (sortBy) {
      case 'name':
        return 'Name';
      case 'registeredAt':
        return 'Date Registered';
      case 'totalUsers':
        return 'Total Users';
      case 'activeUsers':
        return 'Active Users';
      case 'status':
        return 'Status';
      default:
        return sortBy;
    }
  }

  void _navigateToProfile(BarangayProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarangayProfileDetailPage(profile: profile),
      ),
    );
  }
}
