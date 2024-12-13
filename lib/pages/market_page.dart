import 'package:flutter/material.dart';
import '../widgets/market_item_card.dart';
import '../models/market_item.dart';
import 'chat_page.dart';
import 'add_item_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'edit_item_page.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Stream<List<MarketItem>>? _allItemsStream;
  Stream<List<MarketItem>>? _userItemsStream;
  bool _isAddingItem = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeStreams();
  }

  void _initializeStreams() {
    // Stream for all items
    _allItemsStream = _firestore
        .collection('market_items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MarketItem.fromFirestore(doc))
            .toList());

    // Stream for user's items
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _userItemsStream = _firestore
          .collection('market_items')
          .where('sellerId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => MarketItem.fromFirestore(doc))
              .toList());
    }
  }

  Future<void> _handleNewItem(MarketItem item) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isAddingItem = true;
    });

    try {
      // Get user data from Realtime Database
      final userSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(currentUser.uid)
          .get();

      if (!userSnapshot.exists) {
        throw 'User data not found';
      }
      
      final userData = userSnapshot.value as Map<dynamic, dynamic>;

      // Create new item document in Firestore
      await _firestore.collection('market_items').add({
        'title': item.title,
        'price': item.price,
        'description': item.description,
        'sellerId': currentUser.uid,
        'sellerName': userData['fullName'] ?? userData['username'] ?? 'Unknown User',
        'imageUrl': item.imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added successfully!')),
      );
    } catch (e) {
      print('Error adding item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding item: $e')),
      );
    } finally {
      setState(() {
        _isAddingItem = false;
      });
    }
  }

  void _handleEdit(BuildContext context, MarketItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditItemPage(
          item: item,
          onItemUpdated: (MarketItem updatedItem) {
            // The Firestore stream will automatically update the UI
          },
        ),
      ),
    );
  }

  Future<void> _refreshAllItems() async {
    setState(() {
      _allItemsStream = _firestore
          .collection('market_items')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => MarketItem.fromFirestore(doc))
              .toList());
    });
  }

  Future<void> _refreshUserItems() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        _userItemsStream = _firestore
            .collection('market_items')
            .where('sellerId', isEqualTo: currentUser.uid)
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snapshot) => snapshot.docs
                .map((doc) => MarketItem.fromFirestore(doc))
                .toList());
      });
    }
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
          StreamBuilder<List<MarketItem>>(
            stream: _allItemsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return RefreshIndicator(
                onRefresh: _refreshAllItems,
                color: const Color(0xFF00C49A),
                child: _buildItemList(snapshot.data ?? [], showEditButton: false),
              );
            },
          ),
          // My Items Tab
          StreamBuilder<List<MarketItem>>(
            stream: _userItemsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return RefreshIndicator(
                onRefresh: _refreshUserItems,
                color: const Color(0xFF00C49A),
                child: _buildItemList(snapshot.data ?? [], showEditButton: true),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isAddingItem 
          ? null 
          : () {
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
        child: _isAddingItem 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildItemList(List<MarketItem> items, {required bool showEditButton}) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(
            child: Text(
              'No items to display',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ],
      );
    }

    final currentUser = _auth.currentUser;
    
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final isOwner = currentUser?.uid == items[index].sellerId;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MarketItemCard(
            item: items[index],
            onInterested: isOwner ? null : () => _handleInterested(context, items[index]),
            isOwner: isOwner,
            onEdit: isOwner ? () => _handleEdit(context, items[index]) : null,
            showEditButton: showEditButton,
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
