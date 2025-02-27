import 'package:flutter/material.dart';
import 'pages/market_page.dart';
import 'pages/login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'pages/volunteer_page.dart';
import 'pages/report_page.dart';
import 'pages/super_admin/dashboard_page.dart';
import 'pages/super_admin/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  } else {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }

  FirebaseDatabase.instance.databaseURL =
      'https://pulse-app-ea5be-default-rtdb.asia-southeast1.firebasedatabase.app';

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
      ),
      home: kIsWeb ? const SuperAdminLoginPage() : const LoginPage(),
      routes: {
        '/super-admin': (context) => const SuperAdminDashboardPage(),
        '/super-admin-login': (context) => const SuperAdminLoginPage(),
        '/mobile-login': (context) => const LoginPage(),
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

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    MarketPage(),
    VolunteerPage(),
    ReportPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            DateTime.now().difference(_lastPressedAt!) > const Duration(seconds: 2)) {
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Stream<String> getInitialStream() {
    final auth = FirebaseAuth.instance;
    final database = FirebaseDatabase.instance.ref();

    if (auth.currentUser != null) {
      return database
          .child('users')
          .child(auth.currentUser!.uid)
          .onValue
          .map((event) {
        if (event.snapshot.value != null) {
          final userData = event.snapshot.value as Map<dynamic, dynamic>;
          final fullName = userData['fullName'] as String;
          return fullName[0].toUpperCase();
        }
        return '?';
      });
    }
    return Stream.value('?');
  }

  Future<void> _refreshHome() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() {
      getInitialStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'PULSE',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF00C49A),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              // Navigate to notifications page
            },
          ),
          const SizedBox(width: 8),
          PopupMenuButton(
            icon: StreamBuilder<String>(
              stream: getInitialStream(),
              builder: (context, snapshot) {
                return CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    snapshot.data ?? '?',
                    style: const TextStyle(
                      color: Color(0xFF00C49A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Color(0xFF00C49A)),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                // Navigate to login page
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHome,
        color: const Color(0xFF00C49A),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              color: const Color(0xFFE8F5F0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Community Notices',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildNoticeCard(
                      'Community Clean-up Drive',
                      'Posted 2 hours ago',
                      'Join us this Saturday for our monthly community clean-up initiative. Together, we can make our neighborhood cleaner and greener!',
                    ),
                    const SizedBox(height: 16),
                    _buildNoticeCard(
                      'Local Business Meet',
                      'Posted 5 hours ago',
                      'Connect with local entrepreneurs and small business owners at our upcoming networking event. Share ideas and grow together!',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeCard(String title, String timestamp, String description) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timestamp,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Read More'),
            ),
          ],
        ),
      ),
    );
  }
}
