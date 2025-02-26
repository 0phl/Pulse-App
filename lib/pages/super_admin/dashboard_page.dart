import 'package:flutter/material.dart';
import '../../services/super_admin_service.dart';
import '../../models/admin_application.dart';
import '../../models/community.dart';
import 'widgets/admin_applications_list.dart';
import 'widgets/communities_list.dart';

class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  State<SuperAdminDashboardPage> createState() => _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  final SuperAdminService _superAdminService = SuperAdminService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      drawer: NavigationDrawer(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: const [
          NavigationDrawerDestination(
            icon: Icon(Icons.admin_panel_settings),
            label: Text('Admin Applications'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.location_city),
            label: Text('Communities'),
          ),
        ],
      ),
      body: Row(
        children: [
          // Main content
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                AdminApplicationsList(),
                CommunitiesList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 