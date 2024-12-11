import 'package:flutter/material.dart';
import 'pages/market_page.dart';
import 'pages/login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    Firebase.app(); // Try to get existing app
  } catch (e) {
    await Firebase.initializeApp(
      name: 'Pulse-App',
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
      title: 'PulseApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF00C49A),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00C49A)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
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

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    MarketPage(),
    Center(child: Text('Volunteer')),
    Center(child: Text('Report')),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'PulseApp',
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
<<<<<<< HEAD
          PopupMenuButton(
            icon: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                'G',
                style: TextStyle(
                  color: Color(0xFF00C49A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Color(0xFF00C49A)),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
=======
          const SizedBox(width: 8),
          PopupMenuButton(
            icon: StreamBuilder<String>(
              stream: getInitialStream(),
              builder: (context, snapshot) {
                return CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    snapshot.data ?? '?',
                    style: TextStyle(
                      color: Color(0xFF00C49A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout, color: Color(0xFF00C49A)),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
>>>>>>> ab1b17e79c11d8e96f4ff052c769614edc0598d7
            ],
            onSelected: (value) {
              if (value == 'logout') {
                // Navigate to login page
                Navigator.pushAndRemoveUntil(
                  context,
<<<<<<< HEAD
                  MaterialPageRoute(builder: (context) => LoginPage()),
=======
                  MaterialPageRoute(builder: (context) => const LoginPage()),
>>>>>>> ab1b17e79c11d8e96f4ff052c769614edc0598d7
                  (route) => false,
                );
              }
            },
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Container(
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
