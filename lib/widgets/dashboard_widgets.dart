import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardWidgets {
  static Widget buildDashboardCard(
      {required Widget child,
      required Color cardBackgroundColor,
      required List<BoxShadow> cardShadow}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow,
      ),
      child: child,
    );
  }

  static Widget buildStatRow(String label, String value, IconData icon,
      Color color, Color textSecondaryColor, Color textPrimaryColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: textSecondaryColor,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
        ),
      ],
    );
  }

  static Widget buildItemStatusRow(String label, String value, IconData icon,
      Color color, Color textSecondaryColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: textSecondaryColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  static List<Widget> buildRecentActivityList(
      Map<String, dynamic> dashboardStats,
      Color textPrimaryColor,
      Color textSecondaryColor) {
    final activities = dashboardStats['recentActivity'] as List;
    return activities.map((activity) {
      final DateTime timestamp = (activity['timestamp'] as Timestamp).toDate();
      final String formattedDate = DateFormat('MMM d, y').format(timestamp);

      IconData activityIcon;
      Color activityColor;

      switch (activity['type']) {
        case 'item_approved':
          activityIcon = Icons.check_circle_outline;
          activityColor = const Color(0xFF10B981);
          break;
        case 'item_rejected':
          activityIcon = Icons.cancel_outlined;
          activityColor = const Color(0xFFEF4444);
          break;
        case 'item_sold':
          activityIcon = Icons.shopping_bag_outlined;
          activityColor = const Color(0xFF3B82F6);
          break;
        case 'new_rating':
          activityIcon = Icons.star_outline;
          activityColor = const Color(0xFFF59E0B);
          break;
        default:
          activityIcon = Icons.notifications_none_rounded;
          activityColor = const Color(0xFF718096);
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: activityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                activityIcon,
                color: activityColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity['message'] ?? 'Activity',
                    style: TextStyle(
                      fontSize: 14,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  static Widget buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color textPrimaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00C49A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF00C49A),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildQuickActions(
      Color textPrimaryColor,
      List<BoxShadow> cardShadow,
      VoidCallback navigateToAddItem,
      TabController tabController) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildActionButton(
                icon: Icons.add_circle_outline,
                label: 'Add Item',
                onTap: navigateToAddItem,
                textPrimaryColor: textPrimaryColor,
              ),
              buildActionButton(
                icon: Icons.inventory_2_outlined,
                label: 'Inventory',
                onTap: () => tabController.animateTo(0),
                textPrimaryColor: textPrimaryColor,
              ),
              buildActionButton(
                icon: Icons.analytics_outlined,
                label: 'Analytics',
                onTap: () {
                  // This is just a stub for future implementation
                },
                textPrimaryColor: textPrimaryColor,
              ),
              buildActionButton(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  // This is just a stub for future implementation
                },
                textPrimaryColor: textPrimaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget buildFilterBar(TextEditingController searchController,
      String currentFilter, Function(String) onFilterSelected) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search items...',
              hintStyle: TextStyle(
                color: Colors.grey[400],
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey[400],
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey[200]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00C49A)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', currentFilter, onFilterSelected),
                _buildFilterChip(
                    'Recent', 'recent', currentFilter, onFilterSelected),
                _buildFilterChip('Price: High to Low', 'price_desc',
                    currentFilter, onFilterSelected),
                _buildFilterChip('Price: Low to High', 'price_asc',
                    currentFilter, onFilterSelected),
                _buildFilterChip(
                    'Oldest', 'oldest', currentFilter, onFilterSelected),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildFilterChip(String label, String value,
      String currentFilter, Function(String) onFilterSelected) {
    final isSelected = currentFilter == value;

    return GestureDetector(
      onTap: () {
        onFilterSelected(value);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C49A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00C49A) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
