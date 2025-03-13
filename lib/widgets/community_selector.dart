import 'package:flutter/material.dart';
import '../models/community.dart';
import '../services/community_service.dart';

class CommunitySelector extends StatelessWidget {
  final String? selectedCommunityId;
  final Function(Community) onCommunitySelected;
  final bool showCreateOption;

  CommunitySelector({
    Key? key,
    this.selectedCommunityId,
    required this.onCommunitySelected,
    this.showCreateOption = false,
  }) : super(key: key);

  final CommunityService _communityService = CommunityService();

  void _showCreateCommunityDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Community'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Community Name',
                hintText: 'Enter community name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter community description',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              
              try {
                // TODO: You need to collect location information (region, province, municipality, barangay)
                // before creating a community. Consider adding location selection fields
                // to this dialog or creating a separate registration flow.
                final communityId = await _communityService.createCommunity(
                  name: nameController.text,
                  description: descriptionController.text,
                  regionCode: '',       // Required
                  provinceCode: '',     // Required
                  municipalityCode: '', // Required
                  barangayCode: '',     // Required
                );
                
                final community = await _communityService.getCommunity(communityId);
                if (community != null) {
                  onCommunitySelected(community);
                }
                
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating community: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Community>>(
      stream: _communityService.getCommunities(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final communities = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedCommunityId,
              decoration: const InputDecoration(
                labelText: 'Select Community',
                border: OutlineInputBorder(),
              ),
              items: communities.map((community) {
                return DropdownMenuItem(
                  value: community.id,
                  child: Text(community.name),
                );
              }).toList(),
              onChanged: (String? communityId) {
                if (communityId == null) return;
                final community = communities.firstWhere(
                  (c) => c.id == communityId,
                );
                onCommunitySelected(community);
              },
            ),
            if (showCreateOption) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _showCreateCommunityDialog(context),
                child: const Text('Create New Community'),
              ),
            ],
          ],
        );
      },
    );
  }
}
