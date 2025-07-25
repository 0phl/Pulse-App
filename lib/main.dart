import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'widgets/delayed_auth_wrapper.dart';
import 'services/user_service.dart';
import 'pages/deactivated_community_page.dart';
import 'pages/admin/change_password_page.dart';
import 'pages/admin/community_notices_page.dart';
import 'pages/admin/dashboard_page.dart';
import 'pages/admin/marketplace_page.dart';
import 'pages/admin/reports_page.dart';
import 'pages/admin/users_page.dart';
import 'pages/admin/volunteer_posts_page.dart';
import 'services/notification_service.dart';
import 'pages/notifications/notifications_page.dart';
import 'pages/notifications/notification_settings_page.dart';
// User verification page import removed - functionality consolidated into Manage Users
import 'pages/home_page.dart';
import 'pages/market_page.dart';
import 'pages/login_page.dart';
import 'pages/report_page.dart';
import 'pages/super_admin/dashboard_page.dart';
import 'pages/super_admin/login_page.dart';
import 'pages/volunteer_page.dart';
import 'pages/add_item_page.dart';
import 'pages/seller_dashboard_page.dart';
import 'pages/admin/add_volunteer_post_page.dart';
import 'pages/admin/show_create_notice_sheet.dart';
import 'pages/admin/profile_page.dart';
import 'pages/admin/notifications_page.dart';
import 'pages/admin/notification_settings_page.dart';
import 'services/user_session_service.dart';
import 'services/global_state.dart';
import 'services/media_cache_service.dart';
import 'services/user_activity_service.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Log the message for debugging
  debugPrint("Handling a background message: ${message.messageId}");
  debugPrint("Message data: ${message.data}");
  if (message.notification != null) {
    debugPrint(
        "Message notification: ${message.notification!.title} - ${message.notification!.body}");
  }

  final String notificationType = message.data['type'] ?? 'general';

  final String requestId = message.data['requestId'] ?? '';

  debugPrint("Notification type: $notificationType, Request ID: $requestId");

  // Call the handler from notification service with the new implementation
  await handleNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable debug painting to prevent yellow debug lines
  debugPaintSizeEnabled = false;

  if (kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
    }
  } else {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
    }
  }

  FirebaseDatabase.instance.databaseURL =
      'https://pulse-app-ea5be-default-rtdb.asia-southeast1.firebasedatabase.app';

  final sessionService = UserSessionService();
  final isLoggedIn = await sessionService.isLoggedIn();

  // Only sign out if there's no saved session
  if (!isLoggedIn) {
    await FirebaseAuth.instance.signOut();
  }

  try {
    final mediaCacheService = MediaCacheService();
    await mediaCacheService.initConnectivityMonitoring();
    debugPrint('MediaCacheService initialized successfully');
  } catch (e) {
    debugPrint('Error initializing MediaCacheService: $e');
  }

  // We'll initialize it after login in DelayedAuthWrapper instead
  // to avoid the duplicate Firebase initialization error

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PULSE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF00C49A),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00C49A)),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: kIsWeb ? const SuperAdminLoginPage() : const DelayedAuthWrapper(),
      routes: kIsWeb
          ? {
              '/super-admin': (context) => const SuperAdminDashboardPage(),
              '/super-admin-login': (context) => const SuperAdminLoginPage(),
            }
          : {
              '/login': (context) => const LoginPage(),

              // Admin routes
              '/admin/dashboard': (context) => const AdminDashboardPage(),
              '/admin/change-password': (context) => const ChangePasswordPage(),
              '/admin/users': (context) => const UsersPage(),
              '/admin/notices': (context) => const AdminCommunityNoticesPage(),
              '/admin/notices/add': (context) => const ShowCreateNoticeSheet(),
              '/admin/marketplace': (context) => const AdminMarketplacePage(),
              '/admin/marketplace/add': (context) => AddItemPage(
                    onItemAdded: (item) {
                      Navigator.pushReplacementNamed(
                          context, '/admin/marketplace');
                    },
                  ),
              '/admin/volunteer-posts': (context) =>
                  const AdminVolunteerPostsPage(),
              '/admin/volunteer-posts/add': (context) =>
                  const AddVolunteerPostPage(),
              '/admin/reports': (context) => const AdminReportsPage(),
              '/admin/profile': (context) => const AdminProfilePage(),
              '/admin/notifications': (context) =>
                  const AdminNotificationsPage(),
              '/admin/notification-settings': (context) =>
                  const AdminNotificationSettingsPage(),
              // User verification functionality consolidated into Manage Users page

              // Main app routes
              '/home': (context) => const MainScreen(),
              '/market': (context) => const MarketPage(),
              '/volunteer': (context) => const VolunteerPage(),
              '/report': (context) => const ReportPage(),
              '/seller/dashboard': (context) {
                final args = ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
                final initialTabIndex =
                    args != null && args.containsKey('initialTabIndex')
                        ? args['initialTabIndex'] as int
                        : 0;
                return SellerDashboardPage(initialTabIndex: initialTabIndex);
              },
              '/add_item': (context) => AddItemPage(
                    onItemAdded: (item) {
                      Navigator.pop(context);
                    },
                  ),

              // Notification routes
              '/notifications': (context) => const NotificationsPage(),
              '/notification-settings': (context) =>
                  const NotificationSettingsPage(),
            },
    );
  }
}

class MainScreen extends StatefulWidget {
  final bool isLoggedIn;
  const MainScreen({super.key, this.isLoggedIn = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  DateTime? _lastPressedAt;
  final GlobalState _globalState = GlobalState();
  final UserService _userService = UserService();
  final UserActivityService _activityService = UserActivityService();
  StreamSubscription? _communityStatusSubscription;

  @override
  void initState() {
    super.initState();
    // Start monitoring community status
    _startCommunityStatusMonitoring();

    _activityService.initialize();

    // Track that user opened the main screen
    _activityService.trackPageNavigation('MainScreen');
  }

  @override
  void dispose() {
    // Cancel the subscription when the widget is disposed
    _communityStatusSubscription?.cancel();

    // Clean up activity service
    _activityService.dispose();

    super.dispose();
  }

  // Start monitoring community status
  void _startCommunityStatusMonitoring() {
    _communityStatusSubscription = _userService.streamCommunityStatus().listen(
      (status) {
        if (status.isDeactivated && mounted) {
          debugPrint('Community has been deactivated, redirecting user...');
          // Navigate to the deactivated community page
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const DeactivatedCommunityPage(),
            ),
            (route) => false, // Remove all previous routes
          );
        }
      },
      onError: (error) {
        debugPrint('Error monitoring community status: $error');
      },
    );
  }

  // Pages with the MarketPage having the callback
  late final List<Widget> _pages = <Widget>[
    HomePage(),
    MarketPage(
        key: UniqueKey(), // Add a unique key to force rebuild
        onUnreadChatsChanged: _updateUnreadChats),
    const VolunteerPage(),
    const ReportPage(),
  ];

  void _onItemTapped(int index) {
    // Track navigation activity
    final pageNames = ['Home', 'Market', 'Volunteer', 'Report'];
    _activityService.trackPageNavigation(pageNames[index]);

    // If already on the home tab and pressing home again, scroll to top
    if (index == 0 && _selectedIndex == 0) {
      // Call the static method to scroll to top
      HomePage.scrollToTop();
      return;
    }

    // If selecting the Market tab
    if (index == 1) {
      // Force refresh of the unread count
      _globalState.refreshUnreadCount();

      // Always force a complete rebuild of the MarketPage when selecting it
      // This ensures the notification badge is always visible
      setState(() {
        // Replace the MarketPage with a new instance to force a rebuild
        _pages[1] = MarketPage(
            key: UniqueKey(), onUnreadChatsChanged: _updateUnreadChats);
        _selectedIndex = index;
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _globalState.refreshUnreadCount();
        }
      });
    } else {
      // For other tabs, just update the selected index
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // Method to update unread chats count - callback for the MarketPage
  void _updateUnreadChats(int count) {
    // No need to do anything here as the GlobalState handles persistence
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          // If not on home page, go to home page
          setState(() {
            _selectedIndex = 0;
          });
          return false;
        }

        // Double-press back to exit
        if (_lastPressedAt == null ||
            DateTime.now().difference(_lastPressedAt!) >
                const Duration(seconds: 2)) {
          _lastPressedAt = DateTime.now();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          Scaffold(
            body: _pages[_selectedIndex],
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              selectedItemColor: const Color(0xFF00C49A),
              onTap: _onItemTapped,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_cart),
                  label: 'Market',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.volunteer_activism),
                  label: 'Volunteer',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.report),
                  label: 'Report',
                ),
              ],
            ),
          ),
          // Global logout overlay that covers entire screen including bottom navigation
          StreamBuilder<bool>(
            stream: _globalState.logoutStream,
            initialData: _globalState.isLoggingOut,
            builder: (context, snapshot) {
              final isLoggingOut = snapshot.data ?? false;
              if (!isLoggingOut) return const SizedBox.shrink();

              return Positioned.fill(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Signing out...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
