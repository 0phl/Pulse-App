import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/audit_log_service.dart';
import '../../models/market_item.dart';

class AdminMarketplacePage extends StatefulWidget {
  const AdminMarketplacePage({super.key});

  @override
  State<AdminMarketplacePage> createState() => _AdminMarketplacePageState();
}

class _AdminMarketplacePageState extends State<AdminMarketplacePage> {
  final _adminService = AdminService();
  final _authService = AuthService();
  final _auditLogService = AuditLogService();
  String _communityName = '';
  bool _isLoading = false;
  List<MarketItem> _items = [];
  
  @override
  void initState() {
    super.initState();
    _loadCommunity();
    _loadMarketItems();
  }

  Future<void> _loadCommunity() async {
    try {
      final community = await _adminService.getCurrentAdminCommunity();
      if (community != null && mounted) {
        setState(() => _communityName = community.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading community: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 35,
                      color: Color(0xFF00C49A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _communityName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/admin/dashboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Users'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/admin/users');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Audit Trail'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/admin/audit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.announcement),
              title: const Text('Community Notices'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/admin/notices');
              },
            ),
            ListTile(
              selected: true,
              leading: const Icon(Icons.store),
              title: const Text('Marketplace'),
              textColor: const Color(0xFF00C49A),
              iconColor: const Color(0xFF00C49A),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.volunteer_activism),
              title: const Text('Volunteer Posts'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/admin/volunteer-posts');
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Reports'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/admin/reports');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _signOut,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Total Items: ${_items.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('No marketplace items'))
                      : ListView.builder(
                          itemCount: _items.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(item.imageUrl),
                                ),
                                title: Text(item.title),
                                subtitle: Text(
                                  'Price: ₱${item.price.toStringAsFixed(2)}'
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () => _showItemOptions(item),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _loadMarketItems() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Log that admin is viewing marketplace items
      await _auditLogService.logAction(
        actionType: AuditActionType.marketplaceViewed.value,
        targetResource: 'marketplace',
        details: {
          'action': 'Viewed marketplace items',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // TODO: Implement loading marketplace items from Firestore
      setState(() {
        _items = [
          MarketItem(
            id: '1',
            title: 'Sample Item',
            description: 'This is a sample item',
            price: 100.0,
            imageUrl: 'https://via.placeholder.com/150',
            sellerId: 'seller1',
            sellerName: 'Sample Seller',
            communityId: 'community1',
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading marketplace items: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showItemOptions(MarketItem item) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _viewItemDetails(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning),
              title: const Text('Remove Item'),
              onTap: () {
                Navigator.pop(context);
                _removeItem(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_off),
              title: const Text('Warn Seller'),
              onTap: () {
                Navigator.pop(context);
                _warnSeller(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewItemDetails(MarketItem item) async {
    try {
      // Log item details view
      await _auditLogService.logAction(
        actionType: AuditActionType.marketplaceItemViewed.value,
        targetResource: 'marketplace/${item.id}',
        details: {
          'action': 'Viewed item details',
          'itemTitle': item.title,
          'sellerId': item.sellerId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Show item details dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(item.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(item.imageUrl),
                const SizedBox(height: 16),
                Text('Price: ₱${item.price.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                Text('Description: ${item.description}'),
                const SizedBox(height: 8),
                Text('Seller ID: ${item.sellerId}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error viewing item details: $e')),
      );
    }
  }

  Future<void> _removeItem(MarketItem item) async {
    try {
      // Show confirmation dialog
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Why are you removing this item?'),
              const SizedBox(height: 16),
              TextFormField(
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter reason',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'Violates community guidelines'),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (reason == null) return;

      // TODO: Implement actual item removal logic

      // Log item removal
      await _auditLogService.logAction(
        actionType: AuditActionType.marketplaceItemRemoved.value,
        targetResource: 'marketplace/${item.id}',
        details: {
          'action': 'Removed marketplace item',
          'itemTitle': item.title,
          'sellerId': item.sellerId,
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item removed successfully')),
      );

      _loadMarketItems(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing item: $e')),
      );
    }
  }

  Future<void> _warnSeller(MarketItem item) async {
    try {
      // Show warning message dialog
      final warning = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Warn Seller'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter warning message:'),
              const SizedBox(height: 16),
              TextFormField(
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Warning message',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'Please follow community guidelines'),
              child: const Text('Send Warning'),
            ),
          ],
        ),
      );

      if (warning == null) return;

      // TODO: Implement actual warning system logic

      // Log seller warning
      await _auditLogService.logAction(
        actionType: AuditActionType.sellerWarned.value,
        targetResource: 'users/${item.sellerId}',
        details: {
          'action': 'Warned seller',
          'itemTitle': item.title,
          'sellerId': item.sellerId,
          'warning': warning,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Warning sent to seller')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending warning: $e')),
      );
    }
  }
}
