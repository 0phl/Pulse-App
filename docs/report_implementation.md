# Report Feature Implementation Plan

## Data Model

### Report
```dart
class Report {
  final String id;
  final String userId;
  final String communityId;
  final String issueType;
  final String description;
  final String address;
  final Map<String, dynamic> location;
  final List<String> photoUrls;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

## Firebase Structure

### Firestore Collections
- `reports`: Main collection for all reports
  - `{reportId}`: Individual report documents
    - Basic report information
    - Location data
    - Status information
    - `statusUpdates`: Subcollection for tracking status changes

## Implementation Steps

1. Create Models & Services
   - `Report` model with Firestore serialization
   - `ReportService` for CRUD operations
   - Photo upload functionality using Cloudinary

2. Update Report Page UI
   - Integrate with ReportService for submission
   - Add photo upload widget
   - Implement real-time status updates
   - Implement filtering and pagination for My Reports

3. Security Rules
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /reports/{reportId} {
      allow create: if request.auth != null && 
                      request.resource.data.communityId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.communityId;
      allow read: if request.auth != null && 
                    resource.data.communityId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.communityId;
      allow update: if request.auth != null && 
                     (request.auth.token.role == 'admin' || request.auth.uid == resource.data.userId);
    }
  }
}
```

## Status Flow
1. `pending` - Initial state when report is created
2. `under_review` - Admin has seen the report
3. `in_progress` - Being addressed
4. `resolved` - Issue has been fixed
5. `rejected` - Report was invalid/duplicate

## Features to Implement
1. Report Creation
   - Multi-step form validation
   - Photo upload with compression
   - Location selection with map integration
   - Auto-assignment to user's community

2. Report Viewing
   - Real-time status updates
   - Photo gallery view
   - Location map view

3. Report Management (Admin)
   - Status update workflow
   - Bulk actions for similar reports
   - Analytics dashboard
   - Export functionality

4. User Features
   - Report history
   - Status notifications
   - Similar report suggestions
   - Follow-up functionality