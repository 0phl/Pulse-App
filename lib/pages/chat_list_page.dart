import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_page.dart';
import '../services/community_service.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance;
  final _firestore = FirebaseFirestore.instance;
  final _communityService = CommunityService();
  bool _isLoading = true;
  List<ChatInfo> _chats = [];
  String? _error;
  Map<String, String> _userNames = {};
  Map<String, dynamic> _itemDetails = {};
  String? _currentUserCommunityId;

  @override
  void initState() {
    super.initState();
    _loadUserCommunityAndChats();
  }

  void _loadUserCommunityAndChats() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'Please sign in to view chats';
          _isLoading = false;
        });
        return;
      }

      final userCommunity =
          await _communityService.getUserCommunity(currentUser.uid);
      if (userCommunity == null) {
        setState(() {
          _error = 'User is not associated with any community';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _currentUserCommunityId = userCommunity.id;
      });

      _loadChats();
    } catch (e) {
      print('Error loading user community: $e');
      setState(() {
        _error = 'Error loading community information';
        _isLoading = false;
      });
    }
  }

  Future<String> _getUserName(String userId) async {
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }

    try {
      final userSnapshot = await _database.ref('users/$userId').get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        final name = userData['fullName'] ?? userData['username'] ?? 'User';
        _userNames[userId] = name;
        return name;
      }
    } catch (e) {
      print('Error getting user name: $e');
    }
    return 'User';
  }

  Future<Map<String, dynamic>?> _getItemDetails(String itemId) async {
    if (_itemDetails.containsKey(itemId)) {
      return _itemDetails[itemId];
    }

    try {
      // First try getting from Realtime Database
      var snapshot = await _database.ref('marketItems').child(itemId).get();

      if (!snapshot.exists) {
        // If not found in Realtime Database, try Firestore
        final firestoreDoc =
            await _firestore.collection('market_items').doc(itemId).get();
        if (firestoreDoc.exists) {
          final data = firestoreDoc.data()!;
          _itemDetails[itemId] = data;
          return data;
        }
      } else {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final convertedData = Map<String, dynamic>.from(data);
        _itemDetails[itemId] = convertedData;
        return convertedData;
      }

      print('No item details found for ID: $itemId');
      return {'title': 'Unknown Item'}; // Return default data instead of null
    } catch (e) {
      print('Error getting item details: $e');
      return {'title': 'Unknown Item'}; // Return default data on error
    }
  }

  void _loadChats() {
    if (_currentUserCommunityId == null) {
      print('No community ID found');
      return;
    }

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No current user found');
        return;
      }

      print(
          'Loading chats for user ${currentUser.uid} in community $_currentUserCommunityId');

      _database.ref('chats').onValue.listen((event) async {
        if (!mounted) return;

        try {
          final chats = <ChatInfo>[];
          final chatData = event.snapshot.value as Map<dynamic, dynamic>?;

          if (chatData != null) {
            for (var entry in chatData.entries) {
              final chatId = entry.key as String;
              final chatInfo = entry.value as Map<dynamic, dynamic>;

              // Get chat details
              final communityId = chatInfo['communityId'] as String?;
              final itemId = chatInfo['itemId'] as String?;
              final sellerId = chatInfo['sellerId'] as String?;
              final messagesMap =
                  chatInfo['messages'] as Map<dynamic, dynamic>?;

              if (communityId == null ||
                  itemId == null ||
                  sellerId == null ||
                  messagesMap == null) {
                print('Missing required chat info fields');
                continue;
              }

              // Skip if not in user's community
              if (communityId != _currentUserCommunityId) {
                continue;
              }

              // Skip if user is not part of this chat
              final buyerId = messagesMap.values.first['senderId'] as String;
              if (currentUser.uid != sellerId && currentUser.uid != buyerId) {
                continue;
              }

              // Get item details (with fallback)
              final itemDetails =
                  await _getItemDetails(itemId) ?? {'title': 'Unknown Item'};

              final messages = messagesMap.values.toList();
              messages.sort((a, b) =>
                  (b['timestamp'] as int).compareTo(a['timestamp'] as int));
              final lastMessage = messages[0] as Map<dynamic, dynamic>;

              final isSeller = sellerId == currentUser.uid;
              final otherUserId = isSeller ? buyerId : sellerId;
              final otherUserName =
                  await _getUserName(otherUserId) ?? 'Unknown User';

              chats.add(ChatInfo(
                chatId: chatId,
                itemId: itemId,
                buyerId: buyerId,
                sellerId: sellerId,
                sellerName: itemDetails['sellerName'] ??
                    await _getUserName(sellerId) ??
                    'Unknown Seller',
                otherUserName: otherUserName,
                lastMessage: lastMessage['message'] as String,
                lastMessageTime: DateTime.fromMillisecondsSinceEpoch(
                    lastMessage['timestamp'] as int),
                itemTitle: itemDetails['title'] ?? 'Unknown Item',
                isSeller: isSeller,
                communityId: communityId,
              ));
            }
          }

          if (mounted) {
            setState(() {
              _chats = chats;
              _isLoading = false;
            });
          }

          print('Total chats loaded: ${chats.length}');
        } catch (e, stack) {
          print('Error processing chats: $e');
          print('Stack trace: $stack');
          if (mounted) {
            setState(() {
              _error = 'Error loading chats';
              _isLoading = false;
            });
          }
        }
      });
    } catch (e) {
      print('Error setting up chat listener: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading chats';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Chats'),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _chats.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No chats yet. When you message sellers or receive messages about your items, they will appear here.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _chats.length,
                      itemBuilder: (context, index) {
                        final chat = _chats[index];
                        return _buildChatItem(chat);
                      },
                    ),
    );
  }

  Widget _buildChatItem(ChatInfo chat) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[300],
        child: Text(
          chat.otherUserName[0].toUpperCase(),
          style: const TextStyle(color: Colors.black87),
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(chat.otherUserName)),
          Text(
            chat.isSeller ? 'Buyer' : 'Seller',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chat.itemTitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
      trailing: Text(
        _formatTimestamp(chat.lastMessageTime),
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              itemId: chat.itemId,
              sellerId: chat.sellerId,
              sellerName: chat.isSeller ? chat.otherUserName : chat.sellerName,
              itemTitle: chat.itemTitle,
              communityId: chat.communityId,
              isSeller: chat.isSeller,
              buyerId: chat.buyerId,
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

class ChatInfo {
  final String chatId;
  final String itemId;
  final String buyerId;
  final String sellerId;
  final String sellerName;
  final String otherUserName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String itemTitle;
  final bool isSeller;
  final String communityId;

  ChatInfo({
    required this.chatId,
    required this.itemId,
    required this.buyerId,
    required this.sellerId,
    required this.sellerName,
    required this.otherUserName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.itemTitle,
    required this.isSeller,
    required this.communityId,
  });
}
