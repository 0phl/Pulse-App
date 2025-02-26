import 'package:flutter/material.dart';
import '../../../services/super_admin_service.dart';
import '../../../models/admin_application.dart';

class AdminApplicationsList extends StatelessWidget {
  const AdminApplicationsList({super.key});

  @override
  Widget build(BuildContext context) {
    final SuperAdminService superAdminService = SuperAdminService();

    return StreamBuilder<List<AdminApplication>>(
      stream: superAdminService.getAdminApplications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final applications = snapshot.data!;
        if (applications.isEmpty) {
          return const Center(child: Text('No pending admin applications'));
        }

        return ListView.builder(
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final application = applications[index];
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                title: Text(application.fullName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email: ${application.email}'),
                    Text('Community: ${application.communityName}'),
                    Text('Status: ${application.status}'),
                    Text('Applied: ${application.createdAt.toString()}'),
                  ],
                ),
                trailing: application.status == 'pending'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _showApprovalDialog(
                              context,
                              application,
                              superAdminService,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _showRejectionDialog(
                              context,
                              application,
                              superAdminService,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showApprovalDialog(
    BuildContext context,
    AdminApplication application,
    SuperAdminService superAdminService,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Application'),
        content: Text(
          'Are you sure you want to approve ${application.fullName} as admin of ${application.communityName}?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Approve'),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                // Show loading indicator
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(width: 16),
                          Text('Processing approval...'),
                        ],
                      ),
                      duration: Duration(seconds: 30), // Longer duration
                      backgroundColor: Colors.blue,
                      dismissDirection: DismissDirection.none,
                    ),
                  );
                }

                await superAdminService.approveAdminApplication(application);

                if (context.mounted) {
                  // Clear the loading snackbar
                  ScaffoldMessenger.of(context).clearSnackBars();
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Application approved successfully! Admin credentials have been sent via email.'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  // Clear the loading snackbar
                  ScaffoldMessenger.of(context).clearSnackBars();
                  // Show error message with more details
                  String errorMessage = 'Error approving application: ';
                  if (e.toString().contains('email-already-in-use')) {
                    errorMessage += 'This email is already registered.';
                  } else if (e.toString().contains('invalid-email')) {
                    errorMessage += 'The email address is invalid.';
                  } else if (e.toString().contains('permission-denied')) {
                    errorMessage +=
                        'You do not have permission to perform this action.';
                  } else {
                    errorMessage += e.toString();
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'Dismiss',
                        textColor: Colors.white,
                        onPressed: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        },
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showRejectionDialog(
    BuildContext context,
    AdminApplication application,
    SuperAdminService superAdminService,
  ) async {
    final reasonController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Reject'),
            onPressed: () async {
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              Navigator.of(context).pop();
              try {
                await superAdminService.rejectAdminApplication(
                  application.id,
                  application.email,
                  reasonController.text,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Application rejected')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error rejecting application: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
