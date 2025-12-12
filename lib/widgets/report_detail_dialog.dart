import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../widgets/image_viewer_page.dart';
import '../widgets/video_player_page.dart';
import '../widgets/video_thumbnail.dart';

class ReportDetailDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  final Function(String, String) onHandleReport;
  final Function(String) onShowResolveDialog;
  final Function(String)? onShowRejectDialog;

  const ReportDetailDialog({
    super.key,
    required this.report,
    required this.onHandleReport,
    required this.onShowResolveDialog,
    this.onShowRejectDialog,
  });

  @override
  State<ReportDetailDialog> createState() => _ReportDetailDialogState();
}

class _ReportDetailDialogState extends State<ReportDetailDialog> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      if (widget.report.containsKey('reporterInfo') && widget.report['reporterInfo'] != null) {
        print('Using reporter info from report data');
        setState(() {
          _userData = Map<String, dynamic>.from(widget.report['reporterInfo'] as Map);
          _isLoading = false;
        });
        return;
      }

      final userId = widget.report['userId'];
      print('Fetching user data for userId: $userId');

      if (userId != null) {
        // First try to get user from RTDB (regular users)
        final userSnapshot = await _database.ref().child('users/$userId').get();
        if (userSnapshot.exists) {
          final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
          print('Found user in RTDB: ${userData['fullName']}');

          setState(() {
            _userData = userData;
            _isLoading = false;
          });
          return;
        } else {
          print('User not found in RTDB');
        }

        // If not found in RTDB, try Firestore (admin users)
        try {
          final adminSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (adminSnapshot.exists) {
            final adminData = adminSnapshot.data() as Map<String, dynamic>;
            print('Found user in Firestore: ${adminData['fullName']}');

            setState(() {
              _userData = adminData;
              _isLoading = false;
            });
            return;
          } else {
            print('User not found in Firestore');
          }
        } catch (firestoreError) {
          print('Error fetching admin data from Firestore: $firestoreError');
        }
      }

      // If we reach here, try to use the reporter information directly from the report
      if (widget.report.containsKey('reporterName') && widget.report['reporterName'] != null) {
        print('Using reporter name and email from report data');
        final Map<String, dynamic> reporterData = {
          'fullName': widget.report['reporterName'],
          'email': widget.report['reporterEmail'] ?? 'N/A',
          'mobile': widget.report['reporterPhone'] ?? 'N/A',
          'profilePicture': widget.report['reporterProfilePicture'],
        };

        setState(() {
          _userData = reporterData;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }

    print('No user data found, setting _isLoading to false');
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String status = widget.report['status'] ?? 'pending';
    final Timestamp createdAt = widget.report['createdAt'] as Timestamp;
    final String formattedDate =
        DateFormat('MMMM d, y • h:mm a').format(createdAt.toDate());

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.report['issueType'] ?? 'Unknown Type',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Report #${widget.report['id']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reporter info
                    _buildSectionTitle('Reporter Information'),
                    _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name with profile picture
                            _buildInfoRowWithAvatar(
                              'Name',
                              _userData?['fullName'] ??
                              _userData?['name'] ??
                              _userData?['displayName'] ?? 'Anonymous',
                            ),
                            const SizedBox(height: 8),

                            // Email
                            _buildInfoRow(
                              'Email',
                              _userData?['email'] ??
                              _userData?['userEmail'] ??
                              _userData?['mail'] ?? 'N/A',
                              Icons.email,
                            ),

                            const SizedBox(height: 8),

                            // Phone
                            _buildInfoRow(
                              'Phone',
                              _userData?['mobile'] ??
                              _userData?['phone'] ??
                              _userData?['phoneNumber'] ??
                              _userData?['contactNumber'] ?? 'N/A',
                              Icons.phone,
                            ),
                          ],
                        ),

                    const SizedBox(height: 16),

                    // Report details
                    _buildSectionTitle('Report Details'),
                    _buildInfoRow(
                      'Reported On',
                      formattedDate,
                      Icons.calendar_today,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Location',
                      widget.report['address'] ?? 'No location provided',
                      Icons.location_on,
                    ),

                    const SizedBox(height: 16),

                    // Description
                    _buildSectionTitle('Description'),
                    Text(
                      widget.report['description'] ?? 'No description provided.',
                      style: const TextStyle(fontSize: 14),
                    ),

                    // Images section
                    if (widget.report['photoUrls'] != null &&
                        (widget.report['photoUrls'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Images'),
                      const SizedBox(height: 8),
                      Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: (widget.report['photoUrls'] as List).map((url) {
                              final imageUrl = url.toString();
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 200,
                                height: 200,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ImageViewerPage(
                                          imageUrl: imageUrl,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Hero(
                                    tag: imageUrl,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[300],
                                            alignment: Alignment.center,
                                            child: const Text('Image not available'),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],

                    // Videos section
                    if (widget.report['videoUrls'] != null &&
                        (widget.report['videoUrls'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Videos'),
                      const SizedBox(height: 8),
                      Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: (widget.report['videoUrls'] as List).map((url) {
                              final videoUrl = url.toString();
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 200,
                                height: 200,
                                child: VideoThumbnail(
                                  videoUrl: videoUrl,
                                  width: 200,
                                  height: 200,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VideoPlayerPage(
                                          videoUrl: videoUrl,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],

                    if (widget.report['resolution'] != null &&
                        widget.report['resolution'].isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Resolution'),
                      Text(
                        widget.report['resolution'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8, // horizontal spacing
                runSpacing: 8, // vertical spacing
                children: [
                  // Assign button completely removed
                  if (status == 'pending') ...[
                    _buildActionButton(
                      label: 'Start',
                      icon: Icons.play_arrow,
                      color: Colors.blue,
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onHandleReport(widget.report['id'], 'in_progress');
                      },
                    ),
                    if (widget.onShowRejectDialog != null)
                      _buildActionButton(
                        label: 'Reject',
                        icon: Icons.cancel,
                        color: Colors.red,
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onShowRejectDialog!(widget.report['id']);
                        },
                      ),
                  ],
                  if (status == 'in_progress') ...[
                    _buildActionButton(
                      label: 'Resolve',
                      icon: Icons.task_alt,
                      color: Colors.green,
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onShowResolveDialog(widget.report['id']);
                      },
                    ),
                    if (widget.onShowRejectDialog != null)
                      _buildActionButton(
                        label: 'Reject',
                        icon: Icons.cancel,
                        color: Colors.red,
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onShowRejectDialog!(widget.report['id']);
                        },
                      ),
                  ],
                  _buildActionButton(
                    label: 'Close',
                    icon: Icons.close,
                    color: Colors.grey,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34, // Fixed width for consistency
            height: 34, // Fixed height for consistency
            padding: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: Colors.transparent, // Match the profile picture container
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: Theme.of(context).primaryColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithAvatar(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34, // Match the size of the icon containers
            height: 34,
            padding: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: Colors.transparent, // Remove the light blue background
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Builder(
                builder: (context) {
                  final profileImage = _getProfileImage();
                  final String fullName = value;
                  final String firstLetter = fullName.isNotEmpty ?
                                           fullName.substring(0, 1).toUpperCase() : 'A';

                  return CircleAvatar(
                    radius: 15, // Slightly larger radius since we removed the container background
                    backgroundColor: profileImage == null ?
                                    Theme.of(context).primaryColor.withOpacity(0.1) :
                                    Colors.transparent,
                    backgroundImage: profileImage,
                    child: profileImage == null
                        ? Text(
                            firstLetter,
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12, // Smaller font size
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'PENDING';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'resolved':
        return 'RESOLVED';
      case 'rejected':
        return 'REJECTED';
      default:
        return 'UNKNOWN';
    }
  }

  ImageProvider? _getProfileImage() {
    if (_userData == null) return null;

    // List of possible profile image field names
    final List<String> possibleFields = [
      'profilePicture',
      'photoURL',
      'profileImageUrl',
      'photoUrl',
      'profile_image',
      'avatar',
      'avatarUrl',
      'image',
      'imageUrl',
      'picture',
      'pictureUrl',
      'profileImage',
      'userImage',
      'userPhoto',
      'photo',
    ];

    for (final field in possibleFields) {
      if (_userData!.containsKey(field) &&
          _userData![field] != null &&
          _userData![field] is String &&
          (_userData![field] as String).isNotEmpty) {
        final String imageUrl = _userData![field];
        return NetworkImage(imageUrl);
      }
    }

    // If we reach here, no profile image was found
    return null;
  }
}
