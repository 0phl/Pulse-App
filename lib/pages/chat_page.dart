import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/community_service.dart';
import '../services/market_service.dart';
import '../models/seller_rating.dart';
import '../models/market_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatPage extends StatefulWidget {
  final String itemId;
  final String sellerId;
  final String sellerName;
  final String itemTitle;
  final bool isSeller;
  final String? buyerId;
  final String communityId;

  const ChatPage({
    super.key,
    required this.itemId,
    required this.sellerId,
    required this.sellerName,
    required this.itemTitle,
    required this.communityId,
    this.isSeller = false,
    this.buyerId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  late DatabaseReference _chatRef;
  late DatabaseReference _userRef;
  final _auth = FirebaseAuth.instance;
  final _communityService = CommunityService();
  late String _currentUserId;
  late String _chatId;
  bool _isLoading = true;
  String? _error;
  Map<String, String> _userNames = {};
  String _displayName = '';
  String? _currentUserCommunityId;
  final _firestore = FirebaseFirestore.instance;
  final _marketService = MarketService();
  bool _isItemSold = false;
  bool _hasRatedSeller = false;
  MarketItem? _marketItem;

  @override
  void initState() {
    super.initState();
    _displayName = widget.isSeller ? widget.sellerName : widget.sellerName;
    _initializeChat();
    _loadMarketItem();
  }

  Future<void> _loadMarketItem() async {
    try {
      final item = await _marketService.getMarketItem(widget.itemId);
      if (item != null && mounted) {
        // Check if user has already rated this seller for this item
        bool hasRated = false;
        if (!widget.isSeller && item.isSold) {
          hasRated = await _marketService.hasUserRatedTransaction(
              widget.sellerId, _auth.currentUser?.uid ?? '', widget.itemId);
        }

        setState(() {
          _marketItem = item;
          _isItemSold = item.isSold;
          _hasRatedSeller = hasRated;
        });
      }
    } catch (e) {
      print('Error loading market item: $e');
    }
  }

  Future<String> _getUserName(String userId) async {
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }

    try {
      final userSnapshot = await _userRef.child(userId).get();
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

  Future<void> _initializeChat() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'Please sign in to continue';
          _isLoading = false;
        });
        return;
      }

      _currentUserId = currentUser.uid;
      _userRef = FirebaseDatabase.instance.ref('users');

      // Verify user's community
      final userCommunity =
          await _communityService.getUserCommunity(_currentUserId);
      if (userCommunity == null || userCommunity.id != widget.communityId) {
        setState(() {
          _error = 'You can only chat with users in your community';
          _isLoading = false;
        });
        return;
      }
      _currentUserCommunityId = userCommunity.id;

      // Get the names for both users
      final currentUserName = await _getUserName(_currentUserId);
      _userNames[_currentUserId] = currentUserName;

      if (widget.isSeller) {
        // We are seller viewing a buyer's chat
        if (widget.buyerId == null) {
          setState(() {
            _error = 'Invalid chat configuration';
            _isLoading = false;
          });
          return;
        }
        final buyerName = await _getUserName(widget.buyerId!);
        _userNames[widget.buyerId!] = buyerName;
        setState(() {
          _displayName = buyerName;
        });
      } else {
        // We are buyer chatting with seller
        final sellerName = await _getUserName(widget.sellerId);
        _userNames[widget.sellerId] = sellerName;
        setState(() {
          _displayName = sellerName;
        });
      }

      // Format: itemId_communityId_buyerId_sellerId
      if (widget.isSeller) {
        _chatId =
            '${widget.itemId}_${widget.communityId}_${widget.buyerId}_${widget.sellerId}';
      } else {
        _chatId =
            '${widget.itemId}_${widget.communityId}_${_currentUserId}_${widget.sellerId}';
      }

      _chatRef = FirebaseDatabase.instance.ref('chats/$_chatId');

      // Initialize chat with required communityId
      try {
        final chatSnapshot = await _chatRef.get();
        if (!chatSnapshot.exists) {
          // Set the communityId at chat root level to satisfy security rules
          await _chatRef.set({
            'communityId': widget.communityId,
            'itemId': widget.itemId,
            'sellerId': widget.sellerId,
            'messages': {} // Initialize with empty messages map
          });
        }
      } catch (e) {
        print('Database access error: $e');
        setState(() {
          _error = 'Error accessing chat. Please try again later.';
          _isLoading = false;
        });
        return;
      }

      // Mark messages as read BEFORE setting up the chat listener
      await _markMessagesAsRead();

      // Set up chat listener after marking as read
      _setupChatListener();

      if (!widget.isSeller) {
        await _sendInitialMessage();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Chat initialization error: $e');
      setState(() {
        _error = 'Error initializing chat. Please try again later.';
        _isLoading = false;
      });
    }
  }

  // Removed unused _markAsRead method

  void _setupChatListener() {
    _chatRef.child('messages').onValue.listen(
      (event) {
        if (!mounted) return;

        try {
          final messages = <ChatMessage>[];
          final chatData = event.snapshot.value as Map<dynamic, dynamic>?;

          if (chatData != null) {
            chatData.forEach((key, value) {
              if (value is Map) {
                messages.add(
                    ChatMessage.fromJson(Map<String, dynamic>.from(value)));
              }
            });

            // Sort messages by timestamp
            messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

            setState(() {
              _messages = messages;
            });

            // Jump to bottom immediately without animation
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController
                    .jumpTo(_scrollController.position.maxScrollExtent);
              }
            });
          }
        } catch (e) {
          print('Error processing messages: $e');
        }
      },
    );
  }

  Future<void> _sendInitialMessage() async {
    try {
      final messagesSnapshot = await _chatRef.child('messages').get();
      if (!messagesSnapshot.exists) {
        // Send the first message
        await _sendMessage(
          message: 'Hi, I\'m interested in your ${widget.itemTitle}',
          isInitial: true,
        );
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking/sending initial message: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Update the readStatus for the current user
      await _chatRef.child('readStatus').update({
        currentUser.uid: ServerValue.timestamp,
      });

      // Update unread count at chat level
      await _chatRef.child('unreadCount').update({
        currentUser.uid: 0,
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage(
      {String? message,
      bool isInitial = false,
      bool isSystemMessage = false}) async {
    try {
      final messageText = message ?? _messageController.text.trim();
      if (messageText.isEmpty) return;

      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final newMessage = ChatMessage(
        message: messageText,
        senderId: isSystemMessage ? 'system' : currentUser.uid,
        senderName: isSystemMessage
            ? 'System'
            : (_userNames[currentUser.uid] ?? 'User'),
        timestamp: DateTime.now(),
        isInitialMessage: isInitial,
        isSystemMessage: isSystemMessage,
      );

      await _chatRef.child('messages').push().set(newMessage.toJson());

      if (!isInitial) {
        _messageController.clear();
        // Jump to bottom immediately without animation
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }

      // Update unread count for the recipient at chat level (skip for system messages)
      if (!isSystemMessage) {
        final recipientId = widget.isSeller ? widget.buyerId! : widget.sellerId;
        final unreadSnapshot =
            await _chatRef.child('unreadCount').child(recipientId).get();
        final currentUnreadCount = (unreadSnapshot.value as int?) ?? 0;

        await _chatRef
            .child('unreadCount')
            .update({recipientId: currentUnreadCount + 1});
      }

      // Always include buyerId when sending a message
      if (!widget.isSeller) {
        await _chatRef.update({'buyerId': currentUser.uid});
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error sending message. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isLoading && _displayName.isEmpty ? 'Loading...' : _displayName,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            Row(
              children: [
                Flexible(
                  child: Text(
                    widget.itemTitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (_isItemSold) ...[
                  // Show sold indicator if item is sold
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SOLD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
        leadingWidth: 40,
        titleSpacing: 0,
        actions: [
          if (_marketItem != null) _buildActionButton(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!))
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _buildMessage(message);
                        },
                      ),
          ),
          // We've removed the large action button at the bottom

          // Message input area
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _sendMessage(),
                    icon: const Icon(Icons.send),
                    color: const Color(0xFF00C49A),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    // If user is the seller and item is not sold, show Mark as Sold button
    if (widget.isSeller && !_isItemSold) {
      return Container(
        margin: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _showMarkAsSoldDialog,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sell, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'MARK AS SOLD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // If user is the buyer and item is sold, show Review button (only if not already rated)
    if (!widget.isSeller && _isItemSold && !_hasRatedSeller) {
      return Container(
        margin: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(20),
          elevation: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _showRateSellerDialog,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Rate Seller',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showMarkAsSoldDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        title: Text(
          'Mark as Sold',
          style: TextStyle(
            color: const Color(0xFF00C49A),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sell,
              color: const Color(0xFF00C49A),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to mark this item as sold?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _markItemAsSold();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C49A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Mark as Sold'),
          ),
        ],
      ),
    );
  }

  // We've removed the large action buttons at the bottom

  Future<void> _markItemAsSold() async {
    try {
      await _marketService.markItemAsSold(widget.itemId);

      // Send a system message to the chat
      await _sendMessage(
        message: '🎉 This item has been marked as sold!',
        isSystemMessage: true,
      );

      // Fetch the updated item to get the server timestamp
      final updatedItem = await _marketService.getMarketItem(widget.itemId);

      // Update local state
      if (mounted) {
        setState(() {
          _isItemSold = true;
          if (updatedItem != null) {
            _marketItem = updatedItem;
          } else if (_marketItem != null) {
            // Fallback if we couldn't fetch the updated item
            _marketItem = MarketItem(
              id: _marketItem!.id,
              title: _marketItem!.title,
              price: _marketItem!.price,
              description: _marketItem!.description,
              sellerId: _marketItem!.sellerId,
              sellerName: _marketItem!.sellerName,
              imageUrl: _marketItem!.imageUrl,
              communityId: _marketItem!.communityId,
              createdAt: _marketItem!.createdAt,
              isSold: true,
              soldAt: DateTime.now(), // Use current time as fallback
              status: _marketItem!.status,
              rejectionReason: _marketItem!.rejectionReason,
              approvedBy: _marketItem!.approvedBy,
              approvedAt: _marketItem!.approvedAt,
              rejectedAt: _marketItem!.rejectedAt,
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item marked as sold successfully')),
        );
      }
    } catch (e) {
      // Use mounted check before accessing context
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking item as sold: $e')),
        );
      }
    }
  }

  void _showRateSellerDialog() {
    double rating = 5.0;
    final commentController = TextEditingController();
    bool showFullName = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
          title: Text(
            'Rate Seller',
            style: TextStyle(
              color: const Color(0xFF00C49A),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How would you rate ${widget.sellerName}?',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        rating = index + 1.0;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.grey.shade50,
                ),
                child: TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment (optional)',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none,
                  ),
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      activeColor: const Color(0xFF00C49A),
                      value: showFullName,
                      onChanged: (value) {
                        setState(() {
                          showFullName = value ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          showFullName = !showFullName;
                        });
                      },
                      child: const Text(
                        'Show my full name in the review (if unchecked, your name will appear as "Jem*** Na***")',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                _submitRating(rating, commentController.text, showFullName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C49A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(
      double rating, String comment, bool showFullName) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      String buyerName = _userNames[currentUser.uid] ?? 'User';

      // If user chose not to show full name, create a discreet version
      if (!showFullName) {
        buyerName = _createDiscreetName(buyerName);
      }

      final newRating = SellerRating(
        id: '',
        sellerId: widget.sellerId,
        buyerId: currentUser.uid,
        buyerName: buyerName,
        rating: rating,
        comment: comment.isNotEmpty ? comment : null,
        createdAt: DateTime.now(),
        marketItemId: widget.itemId,
      );

      await _marketService.addSellerRating(newRating);

      // Send a system message to the chat
      await _sendMessage(
        message:
            '⭐ The buyer has left a $rating-star rating for this transaction!',
        isSystemMessage: true,
      );

      // Update local state to hide the rate button
      setState(() {
        _hasRatedSeller = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting rating: $e')),
        );
      }
    }
  }

  String _createDiscreetName(String fullName) {
    if (fullName.isEmpty) return 'User';

    List<String> nameParts = fullName.split(' ');
    List<String> discreetParts = [];

    for (String part in nameParts) {
      if (part.length <= 3) {
        discreetParts.add(part);
      } else {
        discreetParts.add('${part.substring(0, 3)}***');
      }
    }

    return discreetParts.join(' ');
  }

  Widget _buildMessage(ChatMessage message) {
    final isMe = message.senderId == _currentUserId;
    final isSystemMessage = message.isSystemMessage;

    // For system messages, display them centered with a different style
    if (isSystemMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message.message,
              style: TextStyle(
                  color: Colors.grey[800], fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: Text(
                message.senderName[0].toUpperCase(),
                style: const TextStyle(color: Colors.black87),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF00C49A) : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.message,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String message;
  final String senderId;
  String senderName;
  final DateTime timestamp;
  final bool isInitialMessage;
  final bool isSystemMessage;

  ChatMessage({
    required this.message,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.isInitialMessage = false,
    this.isSystemMessage = false,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
    if (isInitialMessage) {
      json['isInitialMessage'] = true;
    }
    if (isSystemMessage) {
      json['isSystemMessage'] = true;
    }
    return json;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      message: json['message'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      isInitialMessage: json['isInitialMessage'] ?? false,
      isSystemMessage: json['isSystemMessage'] ?? false,
    );
  }
}
