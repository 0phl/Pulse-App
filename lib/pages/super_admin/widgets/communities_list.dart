import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/super_admin_service.dart';
import '../../../models/community.dart';
import '../../../models/admin_application.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

class CommunitiesList extends StatefulWidget {
  const CommunitiesList({super.key});

  @override
  State<CommunitiesList> createState() => _CommunitiesListState();
}

class _CommunitiesListState extends State<CommunitiesList>
    with SingleTickerProviderStateMixin {
  final SuperAdminService _superAdminService = SuperAdminService();
  late AnimationController _animationController;
  final _dateFormat = DateFormat('MMM d, yyyy');

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
                    Icons.location_city_rounded,
                    color: Color(0xFF00C49A),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Communities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const Spacer(),
                _buildFilterChip(),
              ],
            ),
          ),
          _buildSearchBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD1FAE5)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF059669),
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Only active and inactive communities are shown here. Pending and rejected applications can be found in the Admin Applications section.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _superAdminService.getCommunities(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                if (!snapshot.hasData) {
                  return _buildLoadingState();
                }

                // Filter communities based on status and search query
                final allCommunities = snapshot.data!;
                final filteredCommunities = allCommunities.where((community) {
                  // Apply status filter
                  if (_statusFilter != 'all' &&
                      community['status'] != _statusFilter) {
                    return false;
                  }

                  // Apply search filter if there's a query
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    final name =
                        (community['name'] ?? '').toString().toLowerCase();
                    final description = (community['description'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(query) || description.contains(query);
                  }

                  return true;
                }).toList();

                if (filteredCommunities.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: filteredCommunities.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final community = filteredCommunities[index];

                    final itemAnimation =
                        Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          index / filteredCommunities.length * 0.5,
                          (index + 1) / filteredCommunities.length * 0.5 + 0.5,
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
                        child: _buildCommunityCard(community, context),
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

  Widget _buildFilterChip() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _statusFilter,
        icon: const Icon(Icons.filter_list_rounded, size: 18),
        borderRadius: BorderRadius.circular(12),
        items: const [
          DropdownMenuItem(
            value: 'all',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.all_inclusive_rounded,
                    size: 18, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Text('All Status'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'active',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 18, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('Active'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'inactive',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel_rounded,
                    size: 18, color: Color(0xFFEF4444)),
                SizedBox(width: 8),
                Text('Inactive'),
              ],
            ),
          ),
        ],
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _statusFilter = newValue;
            });
          }
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search communities...',
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
            'Error loading communities',
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
            'Loading communities...',
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
                : Icons.location_city_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No communities match your search'
                : _statusFilter != 'all'
                    ? 'No $_statusFilter communities found'
                    : 'No active or inactive communities available',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Communities appear here after they have been approved and assigned an admin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
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

  Widget _buildCommunityCard(
      Map<String, dynamic> community, BuildContext context) {
    final String name = community['name'] ?? 'Unknown';
    final String adminId = community['adminId'] ?? '';
    final String adminName = community['adminName'] ?? '';
    final String status = community['status'] ?? 'inactive';
    final bool isActive = status == 'active';
    final DateTime createdAt = community['createdAt'] is Timestamp
        ? (community['createdAt'] as Timestamp).toDate()
        : (community['createdAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(community['createdAt'])
            : DateTime.now());

    // Determine color based on status
    final Color statusColor =
        isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final Color statusBgColor =
        isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final IconData statusIcon =
        isActive ? Icons.check_circle_rounded : Icons.cancel_rounded;

    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Community initial icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00C49A),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Community info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF2D3748),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  'Admin: ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  adminName.isNotEmpty
                                      ? adminName
                                      : 'Not assigned',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: adminName.isNotEmpty
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade500,
                                    fontStyle: adminName.isNotEmpty
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Created: ${_dateFormat.format(createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
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
                        isActive ? 'Active' : 'Inactive',
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
            // Actions area
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isActive)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.block, size: 16),
                    label: const Text('Deactivate'),
                    onPressed: () => _showDeactivateDialog(community, context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                  )
                else
                  FilledButton.icon(
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Activate'),
                    onPressed: () => _activateCommunity(community, context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
      ),
    );
  }

  Future<void> _showDeactivateDialog(
      Map<String, dynamic> community, BuildContext context) async {
    final reasonController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Community'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8 > 400
              ? 400
              : MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to deactivate ${community['name']}?\n\nThis will prevent users from accessing this community.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please provide a reason for deactivation:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Enter deactivation reason',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 500,
                  buildCounter: (context,
                      {required currentLength, required isFocused, maxLength}) {
                    return Text(
                      '$currentLength/$maxLength',
                      style: TextStyle(
                        fontSize: 12,
                        color: currentLength > 400
                            ? Colors.amber[700]
                            : Colors.grey[600],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
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
                    content: Text('Please provide a reason for deactivation'),
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
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (result != null && result['confirm'] == true) {
      try {
        // Pass the reason to the service method
        await _superAdminService.updateCommunityStatus(
          community['id'],
          'inactive',
          deactivationReason: result['reason'],
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Community deactivated successfully'),
              backgroundColor: Color(0xFF64748B),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deactivating community: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _activateCommunity(
      Map<String, dynamic> community, BuildContext context) async {
    try {
      await _superAdminService.updateCommunityStatus(community['id'], 'active');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Community activated successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error activating community: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
