import 'package:flutter/material.dart';
import '../../../services/super_admin_service.dart';
import '../../../models/admin_application.dart';
import '../../../widgets/document_viewer_dialog.dart';
import 'package:intl/intl.dart';

class AdminApplicationsList extends StatefulWidget {
  const AdminApplicationsList({super.key});

  @override
  State<AdminApplicationsList> createState() => _AdminApplicationsListState();
}

class _AdminApplicationsListState extends State<AdminApplicationsList>
    with SingleTickerProviderStateMixin {
  final SuperAdminService _superAdminService = SuperAdminService();
  late AnimationController _animationController;
  final _dateFormat = DateFormat('MMM d, yyyy • h:mm a');

  // Filter options
  String _statusFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    color: Color(0xFF00C49A),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Admin Applications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const Spacer(),
                if (!_isSmallScreen) _buildStatusFilter(),
              ],
            ),
          ),
          if (_isSmallScreen) _buildMobileFilterChips(),
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<List<AdminApplication>>(
              stream: _superAdminService.getAdminApplications(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                if (!snapshot.hasData) {
                  return _buildLoadingState();
                }

                // Filter applications based on status and search query
                final allApplications = snapshot.data!;
                final filteredApplications = allApplications.where((app) {
                  // Apply status filter
                  if (_statusFilter != 'all' && app.status != _statusFilter) {
                    return false;
                  }

                  // Apply search filter if there's a query
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    return app.fullName.toLowerCase().contains(query) ||
                        app.email.toLowerCase().contains(query) ||
                        app.communityName.toLowerCase().contains(query);
                  }

                  return true;
                }).toList();

                if (filteredApplications.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: filteredApplications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final application = filteredApplications[index];

                    final itemAnimation =
                        Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          index / filteredApplications.length * 0.5,
                          (index + 1) / filteredApplications.length * 0.5 + 0.5,
                          curve: Curves.easeOut,
                        ),
                      ),
                    );

                    return FadeTransition(
                      opacity: itemAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.1, 0),
                          end: Offset.zero,
                        ).animate(itemAnimation),
                        child: _buildApplicationCard(application, context),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool get _isSmallScreen => MediaQuery.of(context).size.width < 600;

  Widget _buildMobileFilterChips() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Filter by status:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  _buildMobileFilterChip('All', 'all'),
                  _buildMobileFilterChip('Pending', 'pending'),
                  _buildMobileFilterChip('Approved', 'approved'),
                  _buildMobileFilterChip('Rejected', 'rejected'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;

    Color bgColor;
    Color textColor;
    Color borderColor;
    IconData? chipIcon;

    if (isSelected) {
      switch (value) {
        case 'pending':
          bgColor = const Color(0xFFFEF3C7);
          textColor = const Color(0xFFF59E0B);
          borderColor = const Color(0xFFF59E0B);
          chipIcon = Icons.pending_rounded;
          break;
        case 'approved':
          bgColor = const Color(0xFFDCFCE7);
          textColor = const Color(0xFF10B981);
          borderColor = const Color(0xFF10B981);
          chipIcon = Icons.check_circle_rounded;
          break;
        case 'rejected':
          bgColor = const Color(0xFFFEE2E2);
          textColor = const Color(0xFFEF4444);
          borderColor = const Color(0xFFEF4444);
          chipIcon = Icons.cancel_rounded;
          break;
        case 'all':
        default:
          bgColor = const Color(0xFFE6F7F2);
          textColor = const Color(0xFF00C49A);
          borderColor = const Color(0xFF00C49A);
          chipIcon = Icons.filter_alt_rounded;
          break;
      }
    } else {
      bgColor = Colors.white;
      textColor = const Color(0xFF64748B);
      borderColor = const Color(0xFFE2E8F0);

      // Only show icons when selected to reduce visual noise
      chipIcon = null;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _statusFilter = value;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: chipIcon != null ? 12 : 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: borderColor.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chipIcon != null) ...[
                  Icon(
                    chipIcon,
                    size: 16,
                    color: textColor,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    if (_isSmallScreen) {
      // Mobile layout - stacked search
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search applications...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          style: const TextStyle(fontSize: 15),
        ),
      );
    } else {
      // Desktop layout - search bar next to filter
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search applications...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon:
                              const Icon(Icons.clear, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildStatusFilter() {
    return _buildFilterDropdown();
  }

  Widget _buildFilterDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          icon: const Icon(Icons.filter_list_rounded, size: 18),
          borderRadius: BorderRadius.circular(12),
          items: const [
            DropdownMenuItem(
              value: 'all',
              child: Row(
                children: [
                  Icon(Icons.filter_alt_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('All Status'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'pending',
              child: Row(
                children: [
                  Icon(Icons.pending_rounded,
                      size: 18, color: Color(0xFFF59E0B)),
                  SizedBox(width: 8),
                  Text('Pending'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'approved',
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('Approved'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'rejected',
              child: Row(
                children: [
                  Icon(Icons.cancel_rounded,
                      size: 18, color: Color(0xFFEF4444)),
                  SizedBox(width: 8),
                  Text('Rejected'),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _statusFilter = value;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 16),
          Text(
            'Error loading applications',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: () {
              setState(() {});
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00C49A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading applications...',
            style: TextStyle(
                color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _searchQuery.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.inbox_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No applications match your search'
                : _statusFilter != 'all'
                    ? 'No $_statusFilter applications found'
                    : 'No admin applications available',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          if (_searchQuery.isNotEmpty || _statusFilter != 'all')
            TextButton.icon(
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear filters'),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _statusFilter = 'all';
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00C49A),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(
      AdminApplication application, BuildContext context) {
    // Determine status color and icon
    Color statusColor;
    IconData statusIcon;
    Color statusBgColor;

    switch (application.status) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        statusBgColor = const Color(0xFFDCFCE7);
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_rounded;
        statusBgColor = const Color(0xFFFEE2E2);
        break;
      case 'pending':
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending_rounded;
        statusBgColor = const Color(0xFFFEF3C7);
        break;
    }

    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSmallScreen)
              // Mobile layout - more stacked for smaller screens
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with avatar and status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar/Initial
                      Container(
                        width: 40, // Slightly smaller for mobile
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F7F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          application.fullName.isNotEmpty
                              ? application.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 18, // Smaller font for mobile
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00C49A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name and status side by side
                      Expanded(
                        child: Text(
                          application.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Color(0xFF2D3748),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusIcon,
                              size: 12,
                              color: statusColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              application.status.substring(0, 1).toUpperCase() +
                                  application.status.substring(1),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Email - full width for readability
                  Text(
                    application.email,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Community with icon
                  Row(
                    children: [
                      const Icon(
                        Icons.location_city_rounded,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          application.communityName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              // Desktop layout - horizontal arrangement with more space
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar/Initial
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      application.fullName.isNotEmpty
                          ? application.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00C49A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Main info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFF2D3748),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          application.email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_city_rounded,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                application.communityName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          application.status.substring(0, 1).toUpperCase() +
                              application.status.substring(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Date and documents section
            if (isSmallScreen)
              // Mobile layout - stack date and documents for small screens
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date first
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Applied: ${_dateFormat.format(application.appliedDate)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Documents button if available
                  if (application.documents.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon:
                              const Icon(Icons.description_outlined, size: 16),
                          label: const Text('Documents'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => DocumentViewerDialog(
                                documents: application.documents,
                                title: 'Documents - ${application.fullName}',
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ),
                  // Action buttons for pending applications
                  if (application.status == 'pending')
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Approve'),
                              onPressed: () =>
                                  _approveApplication(application, context),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Reject'),
                              onPressed: () =>
                                  _rejectApplication(application, context),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              )
            else
              // Desktop layout - date and documents side by side
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Applied: ${_dateFormat.format(application.appliedDate)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  if (application.documents.isNotEmpty)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: const Text('Documents'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => DocumentViewerDialog(
                            documents: application.documents,
                            title: 'Documents - ${application.fullName}',
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Action buttons for pending applications
                  if (application.status == 'pending')
                    Row(
                      children: [
                        FilledButton.icon(
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve'),
                          onPressed: () =>
                              _approveApplication(application, context),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject'),
                          onPressed: () =>
                              _rejectApplication(application, context),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveApplication(
      AdminApplication application, BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Application'),
        content: Text(
            'Are you sure you want to approve ${application.fullName}\'s application for ${application.communityName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _superAdminService.updateApplicationStatus(
          application.id,
          'approved',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application approved successfully'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error approving application: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectApplication(
      AdminApplication application, BuildContext context) async {
    final reasonController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject ${application.fullName}\'s application for ${application.communityName}?',
            ),
            const SizedBox(height: 16),
            const Text(
              'Please provide a reason for rejection:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // Don't allow empty reason
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for rejection'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(context).pop({
                'confirm': true,
                'reason': reasonController.text.trim(),
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result != null && result['confirm'] == true) {
      try {
        await _superAdminService.rejectAdminApplication(
          application.id,
          application.email,
          result['reason'],
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application rejected'),
              backgroundColor: Color(0xFF64748B),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting application: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
