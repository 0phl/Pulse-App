import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/community_service.dart';
import '../services/market_service.dart';
import '../models/seller_rating.dart';
import '../models/market_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'package:cloudinary_public/cloudinary_public.dart';
import '../widgets/video_player_page.dart';
import '../widgets/image_viewer_page.dart';
import '../widgets/video_thumbnail.dart';

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
  final Map<String, String> _userNames = {};
  String _displayName = '';
  String? _currentUserCommunityId;
  final _marketService = MarketService();
  bool _isItemSold = false;
  bool _hasRatedSeller = false;
  MarketItem? _marketItem;
  StreamSubscription<MarketItem?>? _marketItemSubscription;
  String? _otherUserProfileUrl;
  String? _selectedMessageId; // Track which message is showing timestamp

  // Media handling
  final _imagePicker = ImagePicker();
  File? _selectedImage;
  File? _selectedVideo;
  bool _isUploadingMedia = false;

  @override
  void initState() {
    super.initState();
    _displayName = widget.isSeller ? widget.sellerName : widget.sellerName;
    _initializeChat();
    _loadMarketItem();
    _setupMarketItemListener();

    // Mark messages as read immediately when the page is opened
    // This will be called again after chat initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
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

        // Get buyer's profile image
        try {
          final userSnapshot = await _userRef.child(widget.buyerId!).get();
          if (userSnapshot.exists) {
            final userData = userSnapshot.value as Map<dynamic, dynamic>;
            _otherUserProfileUrl = userData['profileImageUrl'] as String?;
          }
        } catch (e) {
          print('Error getting buyer profile image: $e');
        }

        setState(() {
          _displayName = buyerName;
        });
      } else {
        // We are buyer chatting with seller
        final sellerName = await _getUserName(widget.sellerId);
        _userNames[widget.sellerId] = sellerName;

        // Get seller's profile image
        try {
          final userSnapshot = await _userRef.child(widget.sellerId).get();
          if (userSnapshot.exists) {
            final userData = userSnapshot.value as Map<dynamic, dynamic>;
            _otherUserProfileUrl = userData['profileImageUrl'] as String?;
          }
        } catch (e) {
          print('Error getting seller profile image: $e');
        }

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

  void _setupMarketItemListener() {
    // Set up a real-time listener for the market item
    _marketItemSubscription = _marketService.getMarketItemStream(widget.itemId).listen((item) async {
      if (item != null && mounted) {
        final currentUser = _auth.currentUser;
        if (currentUser == null) return;

        // Check if the item status has changed to sold
        if (item.isSold && !_isItemSold) {
          // Check if user has already rated this seller for this item
          bool hasRated = false;
          if (!widget.isSeller) {
            hasRated = await _marketService.hasUserRatedTransaction(
                widget.sellerId, currentUser.uid, widget.itemId);
          }

          // Update the UI to reflect the new status
          setState(() {
            _marketItem = item;
            _isItemSold = true;
            _hasRatedSeller = hasRated;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _marketItemSubscription?.cancel();

    // Notify the MarketPage that we're leaving the chat page
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
      FirebaseDatabase.instance.ref('users/${currentUser.uid}/lastChatListVisit').set(ServerValue.timestamp);
    }
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

  // Show media picker options
  Future<void> _showMediaPickerOptions() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Send Image'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Send Video'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickVideo();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Pick image from gallery
  Future<void> _pickImage() async {
    try {
      setState(() {
        _isUploadingMedia = true;
      });

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Higher quality but still compressed
        maxWidth: 1920,   // Limit max width to 1920px
        maxHeight: 1920,  // Limit max height to 1920px
      );

      if (image != null) {
        final file = File(image.path);

        // Check file size (5MB limit)
        final fileSize = await file.length();
        final fileSizeInMB = fileSize / (1024 * 1024);

        if (fileSizeInMB > 5) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image size exceeds 5MB limit. Please select a smaller image.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedImage = file;
          _selectedVideo = null; // Clear any selected video
        });

        // Upload and send the image
        await _uploadAndSendMedia(isImage: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    } finally {
      setState(() {
        _isUploadingMedia = false;
      });
    }
  }

  // Pick video from gallery
  Future<void> _pickVideo() async {
    try {
      setState(() {
        _isUploadingMedia = true;
      });

      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60), // Limit to 60 seconds
      );

      if (video != null) {
        final file = File(video.path);

        // Check file size (20MB limit)
        final fileSize = await file.length();
        final fileSizeInMB = fileSize / (1024 * 1024);

        if (fileSizeInMB > 20) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video size exceeds 20MB limit. Please select a smaller video.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedVideo = file;
          _selectedImage = null; // Clear any selected image
        });

        // Upload and send the video
        await _uploadAndSendMedia(isImage: false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: $e')),
        );
      }
    } finally {
      setState(() {
        _isUploadingMedia = false;
      });
    }
  }

  // Upload and send media
  Future<void> _uploadAndSendMedia({required bool isImage}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      String? mediaUrl;
      String mediaType = isImage ? 'image' : 'video';

      // Upload the media to Cloudinary using a single upload preset for chat
      if (isImage && _selectedImage != null) {
        try {
          // Create a CloudinaryPublic instance for chat uploads
          final chatCloudinary = CloudinaryPublic('dy1jizr52', 'chat_uploads', cache: false);

          // Check file size before uploading (5MB limit for images)
          final fileSize = await _selectedImage!.length();
          const maxSize = 5 * 1024 * 1024; // 5MB in bytes

          if (fileSize > maxSize) {
            throw Exception('Image size exceeds 5MB limit. Please select a smaller image.');
          }

          // We'll use the upload preset configured in Cloudinary
          // The preset should handle transformations automatically
          final cloudinaryFile = CloudinaryFile.fromFile(
            _selectedImage!.path,
            folder: 'chat_media',
            resourceType: CloudinaryResourceType.Image,
          );

          final response = await chatCloudinary.uploadFile(cloudinaryFile);
          mediaUrl = response.secureUrl;
        } catch (e) {
          print('Error uploading image: $e');
          rethrow; // Rethrow to be caught by the outer try-catch
        }
      } else if (!isImage && _selectedVideo != null) {
        try {
          // Use the same CloudinaryPublic instance for videos
          final chatCloudinary = CloudinaryPublic('dy1jizr52', 'chat_uploads', cache: false);

          // Check file size before uploading (20MB limit for videos)
          final fileSize = await _selectedVideo!.length();
          const maxSize = 20 * 1024 * 1024; // 20MB in bytes

          if (fileSize > maxSize) {
            throw Exception('Video size exceeds 20MB limit. Please select a smaller video.');
          }

          // We'll use the upload preset configured in Cloudinary
          // The preset should handle transformations automatically
          final cloudinaryFile = CloudinaryFile.fromFile(
            _selectedVideo!.path,
            folder: 'chat_media',
            resourceType: CloudinaryResourceType.Video,
          );

          final response = await chatCloudinary.uploadFile(cloudinaryFile);
          mediaUrl = response.secureUrl;
        } catch (e) {
          print('Error uploading video: $e');
          rethrow; // Rethrow to be caught by the outer try-catch
        }
      }

      if (mediaUrl != null) {
        // Get user profile image
        String? profileImageUrl;
        try {
          final userSnapshot = await _userRef.child(currentUser.uid).get();
          if (userSnapshot.exists) {
            final userData = userSnapshot.value as Map<dynamic, dynamic>;
            profileImageUrl = userData['profileImageUrl'] as String?;
          }
        } catch (e) {
          // Continue without profile image
        }

        // Create message with media - without text labels
        final newMessage = ChatMessage(
          message: '', // Empty message for cleaner look
          senderId: currentUser.uid,
          senderName: _userNames[currentUser.uid] ?? 'User',
          timestamp: DateTime.now(),
          profileImageUrl: profileImageUrl,
          imageUrl: isImage ? mediaUrl : null,
          videoUrl: !isImage ? mediaUrl : null,
          mediaType: mediaType,
        );

        // Send the message
        await _chatRef.child('messages').push().set(newMessage.toJson());

        // Update unread count for the recipient
        final recipientId = widget.isSeller ? widget.buyerId! : widget.sellerId;
        final unreadSnapshot = await _chatRef.child('unreadCount').child(recipientId).get();
        final currentUnreadCount = (unreadSnapshot.value as int?) ?? 0;
        await _chatRef.child('unreadCount').update({recipientId: currentUnreadCount + 1});

        // Always include buyerId when sending a message
        if (!widget.isSeller) {
          await _chatRef.update({'buyerId': currentUser.uid});
        }

        // Clear selected media
        setState(() {
          _selectedImage = null;
          _selectedVideo = null;
        });
      }
    } catch (e) {
      if (mounted) {
        // Extract the meaningful part of the error message
        String errorMessage = 'Error sending media';

        if (e.toString().contains('DioException')) {
          if (e.toString().contains('400')) {
            errorMessage = 'Upload failed: The upload preset "chat_uploads" may not exist or is not properly configured in Cloudinary.';
          } else {
            errorMessage = 'Upload failed: Please check your internet connection and try again.';
          }
        } else if (e.toString().contains('size exceeds')) {
          errorMessage = e.toString();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
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

      String? profileImageUrl;

      // Only get profile image for non-system messages
      if (!isSystemMessage) {
        try {
          final userSnapshot = await _userRef.child(currentUser.uid).get();

          if (userSnapshot.exists) {
            final userData = userSnapshot.value as Map<dynamic, dynamic>;
            profileImageUrl = userData['profileImageUrl'] as String?;
          }
        } catch (e) {
          print('Error getting profile image for message: $e');
          // Continue without profile image
        }
      }

      final newMessage = ChatMessage(
        message: messageText,
        senderId: isSystemMessage ? 'system' : currentUser.uid,
        senderName: isSystemMessage
            ? 'System'
            : (_userNames[currentUser.uid] ?? 'User'),
        timestamp: DateTime.now(),
        isInitialMessage: isInitial,
        isSystemMessage: isSystemMessage,
        profileImageUrl: profileImageUrl,
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
        title: Row(
          children: [
            // Profile picture
            _otherUserProfileUrl != null
                ? CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: NetworkImage(_otherUserProfileUrl!),
                  )
                : CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    child: Text(
                      _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Color(0xFF00C49A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            const SizedBox(width: 12),
            // User name and item title
            Expanded(
              child: Column(
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
                  // Gallery/Media button
                  IconButton(
                    onPressed: _isUploadingMedia ? null : _showMediaPickerOptions,
                    icon: _isUploadingMedia
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00C49A),
                            ),
                          )
                        : const Icon(Icons.photo_library_rounded),
                    color: const Color(0xFF00C49A),
                    tooltip: 'Send media',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 24,
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (context, value, child) {
                      final hasText = value.text.isNotEmpty;
                      return IconButton(
                        onPressed: hasText ? () => _sendMessage() : null,
                        icon: const Icon(Icons.send_rounded),
                        color: hasText
                            ? const Color(0xFF00C49A)
                            : Colors.grey[400],
                      );
                    },
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

      // Get the seller's name
      String sellerName = _userNames[_currentUserId] ?? 'The seller';

      // Send a system message to the chat
      await _sendMessage(
        message: ' $sellerName has marked this item as sold!',
        isSystemMessage: true,
      );

      // The real-time listener will automatically update the UI
      // but we'll also update the local state immediately for better UX
      if (mounted) {
        setState(() {
          _isItemSold = true;
          if (_marketItem != null) {
            // Update the existing market item
            _marketItem = MarketItem(
              id: _marketItem!.id,
              title: _marketItem!.title,
              price: _marketItem!.price,
              description: _marketItem!.description,
              sellerId: _marketItem!.sellerId,
              sellerName: _marketItem!.sellerName,
              imageUrls: _marketItem!.imageUrls,
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
                      child: Builder(
                        builder: (context) {
                          final currentUser = _auth.currentUser;
                          String userName = _userNames[currentUser?.uid ?? ''] ?? 'User';
                          String discreetName = _createDiscreetName(userName);

                          return Text(
                            'Show my full name in the review (if unchecked, your name will appear as "$discreetName")',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          );
                        },
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
      String? profileImageUrl;

      // Get the user's profile image URL
      try {
        final userSnapshot = await _userRef.child(currentUser.uid).get();

        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          profileImageUrl = userData['profileImageUrl'] as String?;
        }
      } catch (e) {
        print('Error getting profile image: $e');
      }

      // If user chose not to show full name, create a discreet version
      if (!showFullName) {
        buyerName = _createDiscreetName(buyerName);
      }

      final newRating = SellerRating(
        id: '',
        sellerId: widget.sellerId,
        buyerId: currentUser.uid,
        buyerName: buyerName,
        buyerAvatar: profileImageUrl,
        rating: rating,
        comment: comment.isNotEmpty ? comment : null,
        createdAt: DateTime.now(),
        marketItemId: widget.itemId,
      );

      await _marketService.addSellerRating(newRating);

      // Send a system message to the chat
      await _sendMessage(
        message:
            ' the buyer has left a $rating-star rating for this transaction!',
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

  // Format timestamp for display
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

  Widget _buildMessage(ChatMessage message) {
    final isMe = message.senderId == _currentUserId;
    final isSystemMessage = message.isSystemMessage;
    final isSelected = _selectedMessageId == '${message.senderId}_${message.timestamp.millisecondsSinceEpoch}';

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

    // Create a unique ID for this message
    final messageId = '${message.senderId}_${message.timestamp.millisecondsSinceEpoch}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Timestamp with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: isSelected ? 20 : 0,
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: 4,
                  left: isMe ? 0 : 40,
                  right: isMe ? 8 : 0,
                ),
                child: Text(
                  _formatTimestamp(message.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: message.profileImageUrl != null
                      ? NetworkImage(message.profileImageUrl!)
                      : null,
                  child: message.profileImageUrl == null
                      ? Text(
                          message.senderName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.black87),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () {
                  setState(() {
                    // Toggle timestamp visibility
                    _selectedMessageId = isSelected ? null : messageId;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  transform: isSelected
                      ? Matrix4.translationValues(isMe ? -3.0 : 3.0, 0, 0)
                      : Matrix4.translationValues(0, 0, 0),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: message.hasMedia
                      ? const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        )
                      : const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF00C49A) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: message.hasMedia
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.imageUrl != null)
                              GestureDetector(
                                onTap: () {
                                  // Navigate to dedicated image viewer page with zoom functionality
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ImageViewerPage(
                                        imageUrl: message.imageUrl!,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white, width: 0.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      message.imageUrl!,
                                      width: 200,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return SizedBox(
                                          width: 200,
                                          height: 150,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                              color: const Color(0xFF00C49A),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            if (message.videoUrl != null)
                              GestureDetector(
                                child: Container(
                                  width: 200,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white, width: 0.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: VideoThumbnail(
                                      videoUrl: message.videoUrl!,
                                      width: 200,
                                      height: 150,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => VideoPlayerPage(
                                              videoUrl: message.videoUrl!,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            if (message.message.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 8, right: 8, bottom: 4),
                                child: Text(
                                  message.message,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Text(
                          message.message,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                ),
              ),
              if (isMe) const SizedBox(width: 8),
            ],
          ),
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
  final String? profileImageUrl;
  final String? imageUrl; // URL for image attachment
  final String? videoUrl; // URL for video attachment
  final String? mediaType; // Type of media: 'image' or 'video'

  ChatMessage({
    required this.message,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.isInitialMessage = false,
    this.isSystemMessage = false,
    this.profileImageUrl,
    this.imageUrl,
    this.videoUrl,
    this.mediaType,
  });

  // Check if this message has media attached
  bool get hasMedia => imageUrl != null || videoUrl != null;

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
    if (profileImageUrl != null) {
      json['profileImageUrl'] = profileImageUrl as Object;
    }
    if (imageUrl != null) {
      json['imageUrl'] = imageUrl as Object;
    }
    if (videoUrl != null) {
      json['videoUrl'] = videoUrl as Object;
    }
    if (mediaType != null) {
      json['mediaType'] = mediaType as Object;
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
      profileImageUrl: json['profileImageUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      mediaType: json['mediaType'] as String?,
    );
  }
}
