import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_notice.dart';

class PollAllVotersDialog extends StatefulWidget {
  final Poll poll;

  const PollAllVotersDialog({
    super.key,
    required this.poll,
  });

  @override
  State<PollAllVotersDialog> createState() => _PollAllVotersDialogState();
}

class _PollAllVotersDialogState extends State<PollAllVotersDialog> {
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _votersByOption = {};
  final _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadAllVoters();
  }

  Future<void> _loadAllVoters() async {
    setState(() => _isLoading = true);

    try {
      final Map<String, List<Map<String, dynamic>>> votersByOption = {};

      for (final option in widget.poll.options) {
        final List<Map<String, dynamic>> optionVoters = [];

        for (final voterId in option.votedBy) {
          final userSnapshot = await _database.child('users/$voterId').get();

          if (userSnapshot.exists) {
            final userData = userSnapshot.value as Map<dynamic, dynamic>;

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

            optionVoters.add({
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
                optionVoters.add({
                  'id': voterId,
                  'name': adminData['fullName'] ?? 'Admin User',
                  'email': adminData['email'] ?? '',
                  'mobile': adminData['mobile'] ?? '',
                  'isAdmin': true,
                  'profileImageUrl': adminData['profileImageUrl'],
                });
              } else {
                // Fallback if not found in Firestore either
                optionVoters.add({
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
              optionVoters.add({
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

        if (optionVoters.isNotEmpty) {
          votersByOption[option.text] = optionVoters;
        }
      }

      if (mounted) {
        setState(() {
          _votersByOption = votersByOption;
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
    int totalVotes = 0;
    _votersByOption.forEach((_, voters) {
      totalVotes += voters.length;
    });

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 600,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.poll_outlined,
                  color: Color(0xFF00C49A), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: const Text(
                    'Poll Voters',
                    style: TextStyle(
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
              widget.poll.question,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'} total',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _votersByOption.isEmpty
                      ? Center(
                          child: Text(
                            'No votes yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _votersByOption.length,
                          itemBuilder: (context, index) {
                            final optionText = _votersByOption.keys.elementAt(index);
                            final voters = _votersByOption[optionText]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 16, bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C49A).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF00C49A),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          optionText,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF00C49A),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${voters.length} ${voters.length == 1 ? 'vote' : 'votes'}',
                                          style: const TextStyle(
                                            color: Color(0xFF00C49A),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...voters.map((voter) => ListTile(
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
                                )),
                                if (index < _votersByOption.length - 1)
                                  const Divider(height: 32),
                              ],
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
