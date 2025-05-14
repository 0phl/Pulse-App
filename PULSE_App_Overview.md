# PULSE App Overview

PULSE (Public Update Local Services and Enagement Application) is a community engagement mobile application designed to connect and empower local communities. The application serves as a centralized platform for community members, local administrators, and super administrators to interact, share information, and manage community resources.

## System Architecture

The PULSE App is built with the following technologies:

- **Frontend**: Flutter (Mobile app for users and admins)
- **Web Interface**: Flutter Web (Super Admin dashboard)
- **Backend**: Firebase (Authentication, Realtime Database, Firestore, Storage)
- **Notifications**: Custom Node.js server using Firebase Cloud Messaging (FCM)

## User Roles and Permissions

### Regular Users
Regular users are community members who can access community information, participate in discussions, and utilize various features of the app.

**Permissions**:
- View community notices
- Like and comment on notices
- Browse and post items in the marketplace
- Join volunteer activities
- Submit community reports
- Receive notifications
- Chat with other users (especially for marketplace transactions)

### Community Admins
Community admins are responsible for managing their specific community, including content moderation and user verification.

**Permissions**:
- All regular user permissions
- Create and manage community notices
- Verify new community members
- Manage marketplace listings
- Create volunteer opportunities
- Process community reports
- View community statistics and analytics
- Manage users within their community

### Super Admins
Super admins have system-wide access and are responsible for managing communities and community admins.

**Permissions**:
- Create and manage communities
- Process admin applications
- Activate/deactivate communities
- Monitor system-wide statistics
- Manage all users across communities

## Core Modules

### 1. Authentication System

**Features**:
- User registration and login
- Admin authentication
- Super admin authentication
- Password reset functionality
- Persistent login sessions
- Account verification

**Implementation Details**:
- Firebase Authentication for user credentials
- Custom verification process for community members
- Role-based access control
- Session management for different user types

### 2. Community Notices

**Features**:
- Create, edit, and delete community announcements
- Support for text, images, videos, and file attachments
- Like and comment functionality with threaded replies
- Poll creation for community feedback

**Implementation Details**:
- Stored in both Firestore and Realtime Database
- Real-time updates for new notices and interactions
- Media storage in Cloudinary
- Notification triggers for new notices and interactions

### 3. Marketplace

**Features**:
- Post items for sale within the community
- Browse items by category
- Chat with sellers
- Mark items as sold
- Seller profiles and ratings
- Admin approval for listings

**Implementation Details**:
- Items stored in Firestore
- Chat functionality using Realtime Database
- Image storage in Cloudinary
- Approval workflow for new listings
- Sales analytics for admins

### 4. Volunteer Opportunities

**Features**:
- Create volunteer events
- Join volunteer activities
- Track participation
- Event details and location information
- Maximum volunteer capacity management

**Implementation Details**:
- Events stored in Firestore
- Real-time tracking of volunteer sign-ups
- Notification system for new opportunities
- Analytics for admin dashboard

### 5. Community Reporting

**Features**:
- Submit community issues with location data
- Attach photos and videos to reports
- Track report status
- Admin response and resolution
- Historical report viewing

**Implementation Details**:
- Reports stored in Firestore
- Location data using device GPS
- Media attachments stored in Cloudinary
- Status tracking workflow
- Resolution documentation

### 6. Notification System

**Features**:
- Push notifications for various events
- In-app notification center
- Notification preferences
- Read/unread status tracking
- Different notification types (community, chat, marketplace, etc.)

**Implementation Details**:
- Firebase Cloud Messaging (FCM) for push notifications
- Custom Node.js server for notification delivery
- Firestore for notification storage
- Two-collection approach: community_notifications and notification_status
- Animated notification badges

### 7. Chat System

**Features**:
- Direct messaging between users
- Marketplace transaction discussions
- Media sharing in chats
- Read status indicators
- Unread message counts

**Implementation Details**:
- Realtime Database for message storage and delivery
- Format: 'itemId_communityId_buyerId_sellerId'
- Media storage in Cloudinary 'chat_uploads' folder
- File size limits and format restrictions

### 8. Admin Dashboard

**Features**:
- Community statistics and analytics
- User management
- Content moderation
- Report processing
- Marketplace oversight
- Volunteer activity management

**Implementation Details**:
- Dedicated admin interface
- Real-time data visualization
- User verification workflow
- Content approval processes
- Analytics for community engagement

### 9. Super Admin Dashboard

**Features**:
- Community creation and management
- Admin application processing
- System-wide statistics
- Community activation/deactivation
- Location-based community organization

**Implementation Details**:
- Web-based interface using Flutter Web
- Community creation with location hierarchy
- Admin application workflow
- Community status management
- Location validation using codes (region, province, municipality, barangay)

## Data Storage

### Firebase Realtime Database
- User profiles
- Community notices
- Chat messages
- Community structure

### Firestore
- Admin users
- Reports
- Marketplace items
- Volunteer posts
- Notifications
- Analytics data

### Cloudinary
- Community notice media
- Marketplace item images
- Report photos and videos
- Chat media
- User profile pictures

## Security and Access Control

- Firebase Authentication for user identity
- Custom security rules for Firestore and Realtime Database
- Role-based access control
- Community-based data isolation
- Verification processes for new users

## Mobile App Features

- Responsive design for various device sizes
- Offline capability for critical features
- Push notifications
- Media handling (images, videos, documents)
- Location services
- QR code scanning for user verification

## User Interface Design

### Regular User Interface
- Bottom navigation with Home, Marketplace, Volunteer, and Report tabs
- Notification icon with animated badge for unread notifications
- Community notice feed with media display and interaction options
- Marketplace with toggle between list and grid views
- Profile section with user information and settings
- Chat interface with media sharing capabilities

### Admin Interface
- Side drawer navigation for different admin functions
- Dashboard with key performance indicators and analytics
- User management interface with verification capabilities
- Content management for notices, marketplace, and volunteer posts
- Report processing workflow
- Settings and configuration options

### Super Admin Interface
- Web-based dashboard with responsive design
- Admin application processing interface
- Community management with status controls
- System-wide statistics and monitoring
- User and admin account management

## Community Management

### Community Creation
1. Super admin creates communities based on geographic locations
2. Communities are organized by region, province, municipality, and barangay
3. Each community has a unique locationId and locationStatusId
4. Communities can be in pending, active, or inactive states

### Admin Application Process
1. Users apply to become community admins
2. Applications include personal information and supporting documents
3. Super admin reviews applications
4. Upon approval, admin accounts are created with initial login credentials
5. New admins must change password on first login

### User Verification
1. Users register with personal information
2. Admin verifies users through QR code scanning or manual verification
3. Verified users gain full access to community features
4. Unverified users have limited access

## Additional Features

### File Attachments
- Support for various file types (PDF, DOCX, images, videos)
- File size limits (5MB for images, 20-50MB for videos)
- Video duration limits (30-60 seconds)
- Downloadable attachments for community notices

### Polls and Surveys
- Community admins can create polls in notices
- Users can vote and see real-time results
- Analytics available for admins

### Deactivation Handling
- When communities are deactivated, users are redirected to a deactivation page
- Admins can see deactivation reasons, regular users cannot
- Super admins can reactivate communities

### Notification Preferences
- Users can customize notification settings
- Options for different notification types
- In-app vs. push notification controls

## Technical Challenges and Solutions

### Notification Delivery
- **Challenge**: Firebase Cloud Functions limitations on free tier
- **Solution**: Custom Node.js notification server deployed on Render

### Media Storage
- **Challenge**: Firebase Storage costs and limitations
- **Solution**: Cloudinary integration with folder organization

### User Verification
- **Challenge**: Ensuring authentic community membership
- **Solution**: Admin verification process with QR code scanning

### Data Synchronization
- **Challenge**: Maintaining consistency between Firestore and RTDB
- **Solution**: Service layer that handles dual-database operations

## Future Development Roadmap

1. **Enhanced Analytics**: More detailed community engagement metrics
2. **Advanced Marketplace**: Categories, search filters, and recommendation system
3. **Event Management**: Calendar integration for community events
4. **Emergency Alerts**: Priority notification system for urgent community issues
5. **Integration with Local Government Services**: API connections to municipal services

## Conclusion

The PULSE App serves as a comprehensive platform for community engagement, providing tools for communication, commerce, volunteering, and issue reporting. With its multi-tiered user system, the application enables effective community management while giving members access to valuable local resources and information.

The application's architecture balances real-time capabilities with scalable data storage, while the custom notification system ensures users stay informed about relevant community activities. Through continuous development and feature enhancement, PULSE aims to strengthen community bonds and improve local engagement.
