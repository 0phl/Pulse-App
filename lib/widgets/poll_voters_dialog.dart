import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_notice.dart';

class PollVotersDialog extends StatefulWidget {
  final PollOption option;
  final String pollQuestion;

  const PollVotersDialog({
    super.key,
    required this.option,
    required this.pollQuestion,
  });

  @override
  State<PollVotersDialog> createState() => _PollVotersDialogState();
}

class _PollVotersDialogState extends State<PollVotersDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _voters = [];
  final _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadVoters();
  }

  Future<void> _loadVoters() async {
    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> voters = [];

      // Process each voter ID
      for (final voterId in widget.option.votedBy) {
        // Get user data from RTDB
        final userSnapshot = await _database.child('users/$voterId').get();

        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;

          // Get user's name (handle both formats)
          String fullName = '';
          if (userData['firstName'] != null && userData['lastName'] != null) {
            fullName = userData['middleName'] != null &&
                    userData['middleName'].toString().isNotEmpty
                ? '${userData['firstName']} ${userData['middleName']} ${userData['lastName']}'
                : '${userData['firstName']} ${userData['lastName']}';
          } else if (userData['fullName'] != null) {
            fullName = userData['fullName'];
          } else {
            fullName = 'User $voterId';
          }

          // Add to voters list
          voters.add({
            'id': voterId,
            'name': fullName,
            'email': userData['email'] ?? '',
            'mobile': userData['mobile'] ?? '',
            'isAdmin': userData['role'] == 'admin',
            'profileImageUrl': userData['profileImageUrl'],
          });
        } else {
          // If user not found in RTDB, check if it's an admin in Firestore
          // Try to get admin data from Firestore
          try {
            final adminSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .doc(voterId)
                .get();

            if (adminSnapshot.exists) {
              final adminData = adminSnapshot.data() as Map<String, dynamic>;
              voters.add({
                'id': voterId,
                'name': adminData['fullName'] ?? 'Admin User',
                'email': adminData['email'] ?? '',
                'mobile': adminData['mobile'] ?? '',
                'isAdmin': true,
                'profileImageUrl': adminData['profileImageUrl'],
              });
            } else {
              // Fallback if not found in Firestore either
              voters.add({
                'id': voterId,
                'name': 'Admin User',
                'email': '',
                'mobile': '',
                'isAdmin': true,
                'profileImageUrl': null,
              });
            }
          } catch (e) {
            // Fallback on error
            voters.add({
              'id': voterId,
              'name': 'Admin User',
              'email': '',
              'mobile': '',
              'isAdmin': true,
              'profileImageUrl': null,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _voters = voters;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading voters: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 500,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.how_to_vote_outlined,
                  color: Color(0xFF00C49A), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Voters for "${widget.option.text}"',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Poll: ${widget.pollQuestion}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '${widget.option.votedBy.length} ${widget.option.votedBy.length == 1 ? 'person' : 'people'} voted for this option',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _voters.isEmpty
                      ? Center(
                          child: Text(
                            'No voters found',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _voters.length,
                          itemBuilder: (context, index) {
                            final voter = _voters[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: voter['isAdmin']
                                    ? Colors.amber.withOpacity(0.2)
                                    : const Color(0xFF00C49A).withOpacity(0.2),
                                backgroundImage: voter['profileImageUrl'] != null
                                    ? NetworkImage(voter['profileImageUrl'])
                                    : null,
                                child: voter['profileImageUrl'] == null
                                    ? Text(
                                        voter['name'][0].toUpperCase(),
                                        style: TextStyle(
                                          color: voter['isAdmin']
                                              ? Colors.amber[800]
                                              : const Color(0xFF00C49A),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                voter['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: voter['isAdmin']
                                      ? Colors.amber[800]
                                      : Colors.black87,
                                ),
                              ),
                              subtitle: voter['email'].isNotEmpty || voter['mobile'].isNotEmpty
                                  ? Text(
                                      voter['email'].isNotEmpty
                                          ? voter['email']
                                          : voter['mobile'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    )
                                  : null,
                              trailing: voter['isAdmin']
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.amber,
                                          width: 1,
                                        ),
                                      ),
                                      child: const Text(
                                        'Admin',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C49A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
