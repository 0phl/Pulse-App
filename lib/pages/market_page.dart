import 'package:flutter/material.dart';
import '../widgets/market_item_card.dart';
import '../models/market_item.dart';
import 'chat_page.dart';
import 'add_item_page.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/image_viewer_page.dart';
import 'edit_item_page.dart';
import 'chat_list_page.dart';
import '../services/community_service.dart';
import '../services/cloudinary_service.dart';

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
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  Stream<List<MarketItem>>? _allItemsStream;
  Stream<List<MarketItem>>? _userItemsStream;
  bool _isAddingItem = false;
  int _unreadChats = 0;
  final CommunityService _communityService = CommunityService();
  String? _currentUserCommunityId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        setState(() {});
      });
    _loadUserCommunity();
    _setupChatListener();
  }

  Future<void> _loadUserCommunity() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final community =
          await _communityService.getUserCommunity(currentUser.uid);
      if (community != null) {
        setState(() {
          _currentUserCommunityId = community.id;
          _initializeStreams();
        });
      }
    }
  }

  void _setupChatListener() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _database.ref('chats').onValue.listen((event) {
      if (!mounted) return;

      try {
        int unreadCount = 0;
        final chatData = event.snapshot.value as Map<dynamic, dynamic>?;

        if (chatData != null) {
          chatData.forEach((chatId, chatValue) {
            if (chatValue is Map && chatValue.containsKey('messages')) {
              // Parse chat ID parts (communityId_itemId_buyerId_sellerId)
              final parts = chatId.toString().split('_');
              if (parts.length == 4) {
                final communityId = parts[0];
                final buyerId = parts[2];
                final sellerId = parts[3];

                // Only count messages from the same community
                if (communityId == _currentUserCommunityId &&
                    (buyerId == currentUser.uid ||
                        sellerId == currentUser.uid)) {
                  final messages =
                      (chatValue['messages'] as Map<dynamic, dynamic>)
                          .values
                          .toList();
                  final readStatus = (chatValue['readStatus']
                          as Map<dynamic, dynamic>?)?[currentUser.uid] ??
                      0;

                  // Count messages newer than last read timestamp
                  final unreadMessages = messages.where((msg) {
                    return msg['timestamp'] > readStatus &&
                        msg['senderId'] != currentUser.uid;
                  }).length;
                  unreadCount += unreadMessages;
                }
              }
            }
          });
        }

        setState(() {
          _unreadChats = unreadCount;
        });
      } catch (e) {
        print('Error processing chat notifications: $e');
      }
    });
  }

  void _initializeStreams() {
    if (_currentUserCommunityId == null) return;

    // Stream for all items in user's community
    _allItemsStream = _firestore
        .collection('market_items')
        .where('communityId', isEqualTo: _currentUserCommunityId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MarketItem.fromFirestore(doc)).toList());

    // Stream for user's items
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _userItemsStream = _firestore
          .collection('market_items')
          .where('communityId', isEqualTo: _currentUserCommunityId)
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

      // Upload image to Cloudinary and get the download URL
      String downloadUrl = await _uploadImage(item.imageUrl);

      // Create new item document in Firestore using the item's ID
      await _firestore.collection('market_items').doc(item.id).set({
        'title': item.title,
        'price': item.price,
        'description': item.description,
        'sellerId': currentUser.uid,
        'sellerName':
            userData['fullName'] ?? userData['username'] ?? 'Unknown User',
        'imageUrl': downloadUrl,
        'communityId': _currentUserCommunityId,
        'createdAt': FieldValue.serverTimestamp(),
      }).catchError((error) {
        print('Firestore error details: $error');
        throw error;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added successfully!')),
      );
    } catch (e) {
      print('Detailed error adding item: $e');
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
    File imageFile = File(imagePath);
    final cloudinaryService = CloudinaryService();
    return await cloudinaryService.uploadMarketImage(imageFile);
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
        title: const Text('Community Market',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          if (_tabController.index == 1) // Only show on My Items tab
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.chat),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatListPage(),
                      ),
                    );
                  },
                  tooltip: 'My Chats',
                ),
                if (_unreadChats > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadChats.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
        ],
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
        onPressed: _isAddingItem || _currentUserCommunityId == null
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

    // Precache next few images
    for (var i = 0; i < items.length && i < 5; i++) {
      if (items[i].imageUrl.startsWith('http')) {
        precacheImage(NetworkImage(items[i].imageUrl), context);
      }
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

  Future<void> _handleItemUpdate(
      MarketItem updatedItem, String? newImagePath) async {
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
        'communityId': updatedItem.communityId,
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
    if (_currentUserCommunityId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          itemId: item.id,
          sellerId: item.sellerId,
          sellerName: item.sellerName,
          itemTitle: item.title,
          communityId: _currentUserCommunityId!,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
