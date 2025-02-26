import 'package:flutter/material.dart';
import '../../../services/super_admin_service.dart';
import '../../../models/community.dart';

class CommunitiesList extends StatelessWidget {
  const CommunitiesList({super.key});

  @override
  Widget build(BuildContext context) {
    final SuperAdminService superAdminService = SuperAdminService();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: superAdminService.getCommunities(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final communities = snapshot.data!;
        if (communities.isEmpty) {
          return const Center(child: Text('No communities found'));
        }

        return ListView.builder(
          itemCount: communities.length,
          itemBuilder: (context, index) {
            final community = communities[index];
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                title: Text(community['name'] ?? ''),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Description: ${community['description'] ?? ''}'),
                    Text('Status: ${community['status'] ?? 'pending'}'),
                    if (community['adminId'] != null)
                      Text('Admin ID: ${community['adminId']}'),
                  ],
                ),
                trailing: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: community['status'] == 'active'
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
} 