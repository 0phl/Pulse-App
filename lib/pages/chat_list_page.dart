import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<ChatInfo> _chats = [];
  String? _error;
  Map<String, String> _userNames = {};
  Map<String, dynamic> _itemDetails = {};

  @override
  void initState() {
    super.initState();
    _loadChats();
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
      final itemDoc = await _firestore.collection('market_items').doc(itemId).get();
      if (itemDoc.exists) {
        final data = itemDoc.data();
        if (data != null) {
          _itemDetails[itemId] = data;
          return data;
        }
      }
    } catch (e) {
      print('Error getting item details: $e');
    }
    return null;
  }

  void _loadChats() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'Please sign in to view chats';
          _isLoading = false;
        });
        return;
      }

      // Listen to all chats
      _database.ref('chats').onValue.listen((event) async {
        if (!mounted) return;

        try {
          final chats = <ChatInfo>[];
          final chatData = event.snapshot.value as Map<dynamic, dynamic>?;
          
          if (chatData != null) {
            for (var entry in chatData.entries) {
              final chatId = entry.key.toString();
              final chatValue = entry.value;
              
              // Parse chat ID parts (itemId_buyerId_sellerId)
              final parts = chatId.split('_');
              if (parts.length == 3) {
                final itemId = parts[0];
                final buyerId = parts[1];
                final sellerId = parts[2];

                // Include chats where user is either buyer or seller
                if (buyerId == currentUser.uid || sellerId == currentUser.uid) {
                  final messages = (chatValue['messages'] as Map<dynamic, dynamic>?)?.values.toList() ?? [];
                  if (messages.isNotEmpty) {
                    // Get the last message
                    final lastMessage = messages.reduce((a, b) {
                      final aTime = a['timestamp'] as int;
                      final bTime = b['timestamp'] as int;
                      return aTime > bTime ? a : b;
                    });

                    // Get item details and names
                    final itemDetails = await _getItemDetails(itemId);
                    if (itemDetails != null) {
                      final isSeller = sellerId == currentUser.uid;
                      final otherUserId = isSeller ? buyerId : sellerId;
                      final otherUserName = await _getUserName(otherUserId);
                      
                      chats.add(ChatInfo(
                        chatId: chatId,
                        itemId: itemId,
                        buyerId: buyerId,
                        sellerId: sellerId,
                        sellerName: itemDetails['sellerName'] ?? 'Unknown Seller',
                        otherUserName: otherUserName,
                        lastMessage: lastMessage['message'].toString(),
                        lastMessageTime: DateTime.fromMillisecondsSinceEpoch(lastMessage['timestamp'] as int),
                        itemTitle: itemDetails['title'] ?? 'Unknown Item',
                        isSeller: isSeller,
                      ));
                    }
                  }
                }
              }
            }
          }

          // Sort chats by most recent message
          chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

          setState(() {
            _chats = chats;
            _isLoading = false;
          });
        } catch (e) {
          print('Error processing chats: $e');
          setState(() {
            _error = 'Error loading chats';
            _isLoading = false;
          });
        }
      }, onError: (error) {
        print('Database error: $error');
        setState(() {
          _error = 'Error loading chats';
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error setting up chat listener: $e');
      setState(() {
        _error = 'Error loading chats';
        _isLoading = false;
      });
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
          Text(chat.itemTitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
  });
}
