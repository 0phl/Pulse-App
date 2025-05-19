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

class _NotificationBadge extends StatefulWidget {
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _NotificationBadge({
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  State<_NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<_NotificationBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Create a curved animation
    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    // Start the animation
    _controller.forward();
  }

  @override
  void didUpdateWidget(_NotificationBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count) {
      // Reset and restart animation when count changes
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return GestureDetector(
          onTap: widget.onTap,
          child: Transform.scale(
            scale: _animation.value,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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

  @override
  void dispose() {
    // Notify the MarketPage that we're leaving the chat list
    // This will trigger a refresh of the unread count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This will run after the widget is disposed
      _refreshUnreadCountInMarketPage();
    });
    super.dispose();
  }

  // Method to refresh the unread count in the MarketPage
  void _refreshUnreadCountInMarketPage() {
    // This is a workaround to force the MarketPage to refresh its unread count
    // We're using the Firebase database to trigger a refresh
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _database
          .ref('users/${currentUser.uid}/lastChatListVisit')
          .set(ServerValue.timestamp);
    }
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

  Future<bool> _deleteChat(ChatInfo chat) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Chat'),
          content:
              const Text('Are you sure you want to delete this conversation?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return false;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Store deletion timestamp for this user
      await _database
          .ref('chats/${chat.chatId}/deletedTimestamps')
          .child(currentUser.uid)
          .set(ServerValue.timestamp);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted successfully')),
        );
      }
      return true; // Return true to confirm the dismissal
    } catch (e) {
      print('Error deleting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error deleting chat. Please try again.')),
        );
      }
      return false; // Return false if deletion failed
    }
  }

  void _loadChats() {
    if (_currentUserCommunityId == null) {
      print('No community ID found');
      return;
    }

    setState(() {
      _isLoading = true;
    });

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

              // Ensure messages map exists with data
              if (messagesMap == null || messagesMap.isEmpty) {
                print(
                    'Chat $chatId has no messages or invalid messages format');
                // Create empty messages map if it's missing
                await _database.ref('chats/$chatId/messages').set({});
                continue;
              }

              // Check each required field individually for better error logging
              if (communityId == null) {
                print('Missing communityId for chat: $chatId');
                continue;
              }
              if (itemId == null) {
                print('Missing itemId for chat: $chatId');
                continue;
              }
              if (sellerId == null) {
                print('Missing sellerId for chat: $chatId');
                continue;
              }
              if (messagesMap == null || messagesMap.isEmpty) {
                print('Missing or empty messages for chat: $chatId');
                continue;
              }

              // Skip if not in user's community
              if (communityId != _currentUserCommunityId) {
                continue;
              }

              // Determine buyerId from chat info or first message
              String? buyerId = chatInfo['buyerId'] as String?;
              if (buyerId == null) {
                // If buyerId is not stored at chat level, try to determine from first message
                final firstMessage = messagesMap.values.first;
                final firstSenderId = firstMessage['senderId'] as String;
                // If first message is from seller, this must be stored at chat level
                if (firstSenderId == sellerId) {
                  print('Unable to determine buyerId for chat: $chatId');
                  continue;
                }
                buyerId = firstSenderId;
                // Store buyerId at chat level for future reference
                await _database
                    .ref('chats/$chatId')
                    .update({'buyerId': buyerId});
              }

              // Skip if user is not part of this chat
              if (currentUser.uid != sellerId && currentUser.uid != buyerId) {
                continue;
              }

              // Get item details (with fallback)
              final itemDetails =
                  await _getItemDetails(itemId) ?? {'title': 'Unknown Item'};

              // Get deletion timestamps
              final deletedTimestamps =
                  (chatInfo['deletedTimestamps'] as Map<dynamic, dynamic>?)
                      ?.cast<String, int>();
              final currentUserDeletedAt = deletedTimestamps?[currentUser.uid];

              // Get messages after filtering out deleted ones
              final validMessages = messagesMap.entries.where((msg) {
                final timestamp = msg.value['timestamp'] as int;
                // Include message if no deletion timestamp or message is newer
                return currentUserDeletedAt == null ||
                    timestamp > currentUserDeletedAt;
              }).toList();

              // Skip this chat if no valid messages
              if (validMessages.isEmpty) continue;

              // Sort messages by timestamp
              validMessages.sort((a, b) => (b.value['timestamp'] as int)
                  .compareTo(a.value['timestamp'] as int));
              final lastMessage = validMessages[0].value;

              final isSeller = sellerId == currentUser.uid;
              final otherUserId = isSeller ? buyerId : sellerId;
              final otherUserName =
                  await _getUserName(otherUserId) ?? 'Unknown User';

              // Get profile image URL for the other user
              String? profileImageUrl;
              try {
                final userSnapshot =
                    await _database.ref('users/$otherUserId').get();
                if (userSnapshot.exists) {
                  final userData = userSnapshot.value as Map<dynamic, dynamic>;
                  profileImageUrl = userData['profileImageUrl'] as String?;
                }
              } catch (e) {
                print('Error getting profile image for chat list: $e');
                // Continue without profile image
              }

              // Get unread count from chat level
              final unreadSnapshot = await _database
                  .ref('chats/$chatId/unreadCount')
                  .child(currentUser.uid)
                  .get();
              final unreadCount = (unreadSnapshot.value as int?) ?? 0;

              // Check if the last message contains media
              bool hasMedia = false;
              String? mediaType;

              if (lastMessage.containsKey('imageUrl') &&
                  lastMessage['imageUrl'] != null) {
                hasMedia = true;
                mediaType = 'image';
              } else if (lastMessage.containsKey('videoUrl') &&
                  lastMessage['videoUrl'] != null) {
                hasMedia = true;
                mediaType = 'video';
              }

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
                unreadCount: unreadCount,
                deletedTimestamps: deletedTimestamps,
                profileImageUrl: profileImageUrl,
                hasMedia: hasMedia,
                mediaType: mediaType,
              ));
            }
          }

          // Sort chats by last message time before updating state
          chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

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
        title: const Text('My Chats',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
        // Add padding to the actions
        actionsIconTheme: const IconThemeData(size: 26),
        // Add some right padding to the title
        titleSpacing: 16,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _chats.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: Color(0xFF00C49A).withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: const Text(
                              'No chats yet',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'When you message sellers or receive messages about your items, they will appear here',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
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

    final hasUnread = chat.unreadCount > 0;

    return Dismissible(
      key: Key(chat.chatId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _deleteChat(chat),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: hasUnread ? const Color(0xFFF0F9F6) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: () {
            _navigateToChat(chat);
          },
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[300],
                backgroundImage: chat.profileImageUrl != null
                    ? NetworkImage(chat.profileImageUrl!)
                    : null,
                child: chat.profileImageUrl == null
                    ? Text(
                        chat.otherUserName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF00C49A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (hasUnread)
                Positioned(
                  right: 2, // Adjust position to be more inward
                  top: 2,
                  child: _NotificationBadge(
                    count: chat.unreadCount,
                    color: Colors.red,
                    onTap: () {
                      _navigateToChat(chat);
                    },
                  ),
                ),
            ],
          ),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.otherUserName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            hasUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C49A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            chat.isSeller ? 'Buyer' : 'Seller',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF00C49A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            chat.itemTitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                _formatTimestamp(chat.lastMessageTime),
                style: TextStyle(
                  fontSize: 12,
                  color: hasUnread ? const Color(0xFF00C49A) : Colors.grey[500],
                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: chat.hasMedia
                ? Row(
                    children: [
                      Icon(
                        chat.mediaType == 'image'
                            ? Icons.image
                            : Icons.videocam,
                        size: 16,
                        color: hasUnread ? Colors.black87 : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        chat.mediaType == 'image' ? '[Image]' : '[Video]',
                        style: TextStyle(
                          fontSize: 14,
                          color: hasUnread ? Colors.black87 : Colors.grey[600],
                          fontWeight:
                              hasUnread ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      if (chat.lastMessage.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            chat.lastMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  hasUnread ? Colors.black87 : Colors.grey[600],
                              fontWeight: hasUnread
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  )
                : Text(
                    chat.lastMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: hasUnread ? Colors.black87 : Colors.grey[600],
                      fontWeight:
                          hasUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    // Convert to Philippines timezone (UTC+8)
    final philippinesTime = timestamp.toUtc().add(const Duration(hours: 8));
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final difference = now.difference(philippinesTime);

    if (difference.inDays == 0) {
      final hour = philippinesTime.hour > 12
          ? philippinesTime.hour - 12
          : philippinesTime.hour;
      final period = philippinesTime.hour >= 12 ? 'PM' : 'AM';
      // Handle 12 AM/PM case
      final displayHour = hour == 0 ? 12 : hour;
      return '$displayHour:${philippinesTime.minute.toString().padLeft(2, '0')} $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // Format date with month/day/year
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final month = months[philippinesTime.month - 1];
      return '$month ${philippinesTime.day}, ${philippinesTime.year}';
    }
  }

  void _navigateToChat(ChatInfo chat) async {
    // Same navigation logic as in the ListTile onTap
    await Navigator.push(
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

    // Refresh the chat list after returning from chat page
    if (mounted) {
      _loadChats();
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
  final int unreadCount;
  final Map<String, int>? deletedTimestamps;
  final String? profileImageUrl;
  final bool hasMedia; // Whether the last message contains media
  final String? mediaType; // Type of media: 'image' or 'video'

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
    required this.unreadCount,
    this.deletedTimestamps,
    this.profileImageUrl,
    this.hasMedia = false,
    this.mediaType,
  });
}
