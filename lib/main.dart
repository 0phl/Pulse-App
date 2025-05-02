import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'firebase_options.dart';
import 'widgets/delayed_auth_wrapper.dart';
import 'pages/admin/change_password_page.dart';
import 'pages/admin/community_notices_page.dart';
import 'pages/admin/dashboard_page.dart';
import 'pages/admin/marketplace_page.dart';
import 'pages/admin/reports_page.dart';
import 'pages/admin/users_page.dart';
import 'pages/admin/volunteer_posts_page.dart';
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
import 'services/user_session_service.dart';
import 'services/global_state.dart';
import 'services/media_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Set persistence to SESSION for web
      await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  } else {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Set persistence to LOCAL for mobile
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }

  FirebaseDatabase.instance.databaseURL =
      'https://pulse-app-ea5be-default-rtdb.asia-southeast1.firebasedatabase.app';

  // Check if there's a saved session
  final sessionService = UserSessionService();
  final isLoggedIn = await sessionService.isLoggedIn();

  // Only sign out if there's no saved session
  if (!isLoggedIn) {
    await FirebaseAuth.instance.signOut();
  }

  // Initialize media cache service for optimized Cloudinary usage
  try {
    final mediaCacheService = MediaCacheService();
    await mediaCacheService.initConnectivityMonitoring();
    debugPrint('MediaCacheService initialized successfully');
  } catch (e) {
    debugPrint('Error initializing MediaCacheService: $e');
  }

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
        // Use page transitions for smoother navigation
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
              // User verification functionality consolidated into Manage Users page

              // Main app routes
              '/home': (context) => const MainScreen(),
              '/market': (context) => const MarketPage(),
              '/volunteer': (context) => const VolunteerPage(),
              '/report': (context) => const ReportPage(),
              '/seller/dashboard': (context) => const SellerDashboardPage(),
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

  // Pages with the MarketPage having the callback
  late final List<Widget> _pages = <Widget>[
    const HomePage(),
    MarketPage(
        key: UniqueKey(), // Add a unique key to force rebuild
        onUnreadChatsChanged: _updateUnreadChats),
    const VolunteerPage(),
    const ReportPage(),
  ];

  void _onItemTapped(int index) {
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

      // Add a delayed refresh to ensure the badge appears
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
      child: Scaffold(
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
    );
  }
}
