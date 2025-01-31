import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/community_service.dart';

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

  @override
  void initState() {
    super.initState();
    _displayName = widget.isSeller ? widget.sellerName : widget.sellerName;
    _initializeChat();
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

  void _initializeChat() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'Please sign in to use chat';
          _isLoading = false;
        });
        return;
      }

      _currentUserId = currentUser.uid;
      _userRef = FirebaseDatabase.instance.ref('users');

      // Verify user's community
      final userCommunity = await _communityService.getUserCommunity(_currentUserId);
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
        _chatId = '${widget.itemId}_${widget.communityId}_${widget.buyerId}_${widget.sellerId}';
      } else {
        _chatId = '${widget.itemId}_${widget.communityId}_${_currentUserId}_${widget.sellerId}';
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

      _setupChatListener();
      if (!widget.isSeller) {
        _sendInitialMessage();
      } else {
        setState(() {
          _isLoading = false;
        });
      }

      // Mark messages as read
      _markAsRead();
    } catch (e) {
      print('Chat initialization error: $e');
      setState(() {
        _error = 'Error initializing chat. Please try again later.';
        _isLoading = false;
      });
    }
  }

  void _markAsRead() async {
    try {
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      await _chatRef.child('readStatus').update({
        _currentUserId: currentTimestamp,
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

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
                try {
                  final message = ChatMessage.fromJson(Map<String, dynamic>.from(value));
                  // Get the sender's name from cache
                  message.senderName = _userNames[message.senderId] ?? message.senderName;
                  messages.add(message);
                } catch (e) {
                  print('Error parsing message: $e');
                }
              }
            });

            // Sort messages by timestamp (oldest first)
            messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

            setState(() {
              _messages = messages;
              _isLoading = false;
            });

            // Mark messages as read whenever new messages come in
            _markAsRead();
          } else {
            setState(() {
              _messages = [];
              _isLoading = false;
            });
          }
        } catch (e) {
          print('Error processing messages: $e');
          setState(() {
            _error = 'Error loading messages';
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        print('Chat listener error: $error');
        setState(() {
          _error = 'Error loading messages. Please try again later.';
          _isLoading = false;
        });
      },
    );
  }

  void _sendInitialMessage() async {
    try {
      final messagesSnapshot = await _chatRef.child('messages').get();
      if (!messagesSnapshot.exists) {
        // Send the first message
        _sendMessage(
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
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage({String? message, bool isInitial = false}) async {
    try {
      final messageText = message ?? _messageController.text.trim();
      if (messageText.isEmpty) return;

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to send messages')),
        );
        return;
      }

      final newMessage = ChatMessage(
        message: messageText,
        senderId: currentUser.uid,
        senderName: _userNames[currentUser.uid] ?? 'User',
        timestamp: DateTime.now(),
        isInitialMessage: isInitial,
      );

      await _chatRef.child('messages').push().set(newMessage.toJson());

      if (!isInitial) {
        _messageController.clear();
      }
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error sending message. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isLoading && _displayName.isEmpty ? 'Loading...' : _displayName),
            Text(
              widget.itemTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!))
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _buildMessage(message);
                        },
                      ),
          ),
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

  Widget _buildMessage(ChatMessage message) {
    final isMe = message.senderId == _currentUserId;
    
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

  ChatMessage({
    required this.message,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.isInitialMessage = false,
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
    return json;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      message: json['message'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      isInitialMessage: json['isInitialMessage'] ?? false,
    );
  }
}
