import 'package:flutter/material.dart';
import '../widgets/market_item_card.dart';
import '../models/market_item.dart';
import 'chat_page.dart';
import 'add_item_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/image_viewer_page.dart';
import 'edit_item_page.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage>
    with SingleTickerProviderStateMixin {
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
        .map((snapshot) =>
            snapshot.docs.map((doc) => MarketItem.fromFirestore(doc)).toList());

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

      // Upload image to Imgur and get the download URL
      String downloadUrl =
          await _uploadImage(item.imageUrl); // Assuming item.imageUrl is a File

      // Create new item document in Firestore
      await _firestore.collection('market_items').add({
        'title': item.title,
        'price': item.price,
        'description': item.description,
        'sellerId': currentUser.uid,
        'sellerName':
            userData['fullName'] ?? userData['username'] ?? 'Unknown User',
        'imageUrl': downloadUrl, // Use the download URL
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

  Future<String> _uploadImage(String imagePath) async {
    File imageFile = File(imagePath); // Convert the path to a File
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('https://api.imgur.com/3/image'),
      headers: {
        'Authorization': 'Client-ID d22045c222ba371', // Use your Client ID
        'Content-Type': 'application/json',
      },
      body: json.encode({'image': base64Image}),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return jsonResponse['data']['link']; // Return the image URL
    } else {
      throw Exception('Failed to upload image: ${response.body}');
    }
  }

  void _handleImageTap(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerPage(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Market', style: TextStyle(fontWeight: FontWeight.bold)),
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
              return _buildItemList(snapshot.data ?? []);
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
              return _buildItemList(snapshot.data ?? []);
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
        final bool isMyItemsTab = _tabController.index == 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MarketItemCard(
            item: items[index],
            onInterested: () => _handleInterested(context, items[index]),
            onImageTap: () => _handleImageTap(context, items[index].imageUrl),
            isOwner: _auth.currentUser?.uid == items[index].sellerId,
            showEditButton: isMyItemsTab,
            onEdit: isMyItemsTab ? () => _handleEditItem(items[index]) : null,
          ),
        );
      },
    );
  }

  void _handleEditItem(MarketItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditItemPage(
          item: item,
          onItemUpdated: _handleItemUpdate,
        ),
      ),
    );
  }

  Future<void> _handleItemUpdate(MarketItem updatedItem, String? newImagePath) async {
    setState(() {
      _isAddingItem = true;
    });

    try {
      String imageUrl = updatedItem.imageUrl;
      
      // Only upload new image if provided
      if (newImagePath != null) {
        imageUrl = await _uploadImage(newImagePath);
      }

      // Update the item in Firestore
      await _firestore.collection('market_items').doc(updatedItem.id).update({
        'title': updatedItem.title,
        'price': updatedItem.price,
        'description': updatedItem.description,
        'imageUrl': imageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item updated successfully!')),
      );
    } catch (e) {
      print('Error updating item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating item: $e')),
      );
    } finally {
      setState(() {
        _isAddingItem = false;
      });
    }
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