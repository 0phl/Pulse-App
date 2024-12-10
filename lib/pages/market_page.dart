import 'package:flutter/material.dart';
import '../widgets/market_item_card.dart';
import '../models/market_item.dart';
import 'chat_page.dart';
import 'add_item_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MarketItem> _allItems = [];
  List<MarketItem> _userItems = [];
  String _userId = 'user1'; // Default user ID

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId') ?? 'user1';
    
    // Load user's items from SharedPreferences
    final userItemsJson = prefs.getStringList('userItems') ?? [];
    final loadedUserItems = userItemsJson
        .map((item) => MarketItem.fromJson(json.decode(item)))
        .toList();

    // Default items
    final defaultItems = [
      MarketItem(
        id: '1',
        title: 'Pre-loved iPhone 13',
        price: 35000.00,
        description:
            'iPhone 13 128GB, 98% battery health, complete with box and accessories',
        sellerId: 'user1',
        sellerName: 'John Doe',
        imageUrl:
            'https://images.unsplash.com/photo-1632661674596-df8be070a5c5?q=80&w=1000',
      ),
      MarketItem(
        id: '2',
        title: 'Gaming Chair',
        price: 4500.00,
        description:
            'Ergonomic gaming chair, 3 months used, very good condition',
        sellerId: 'user2',
        sellerName: 'Jane Smith',
        imageUrl:
            'https://images.unsplash.com/photo-1598550476439-6847785fcea6',
      ),
      MarketItem(
        id: '3',
        title: 'Sony WH-1000XM4',
        price: 12000.00,
        description:
            'Noise cancelling headphones, barely used, complete package',
        sellerId: 'user3',
        sellerName: 'Mike Wilson',
        imageUrl:
            'https://images.unsplash.com/photo-1618366712010-f4ae9c647dcb',
      ),
    ];

    setState(() {
      // Show newest items first by reversing the loadedUserItems list
      _allItems = [...loadedUserItems.reversed, ...defaultItems];
      _userItems = loadedUserItems.reversed.toList();
    });
  }

  void _handleNewItem(MarketItem item) {
    setState(() {
      // Add new item at the beginning of both lists
      _allItems.insert(0, item);
      _userItems.insert(0, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Market'),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All Items'),
            Tab(text: 'My Items'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All Items Tab
          _buildItemList(_allItems),
          // My Items Tab
          _buildItemList(_userItems),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddItemPage(
                onItemAdded: _handleNewItem,
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF00C49A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildItemList(List<MarketItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No items to display',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MarketItemCard(
            item: items[index],
            onInterested: () => _handleInterested(context, items[index]),
          ),
        );
      },
    );
  }

  void _handleInterested(BuildContext context, MarketItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          itemId: item.id,
          sellerId: item.sellerId,
          sellerName: item.sellerName,
          itemTitle: item.title,
        ),
      ),
    );
  }
}
