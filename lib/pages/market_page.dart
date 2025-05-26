import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/market_item_card.dart';
import '../models/market_item.dart';
import 'chat_page.dart';
import 'add_item_page.dart';
import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/image_viewer_page.dart';
import '../widgets/multi_image_viewer_page.dart';
import 'edit_item_page.dart';
import 'chat_list_page.dart';
import '../services/community_service.dart';
import '../services/cloudinary_service.dart';
import '../services/global_state.dart';
import 'seller_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/marketplace_shimmer_loading.dart';

class MarketPage extends StatefulWidget {
  final Function(int)? onUnreadChatsChanged;

  const MarketPage({super.key, this.onUnreadChatsChanged});

  @override
  State<MarketPage> createState() => _MarketPageState();
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
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                widget.count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MarketPageState extends State<MarketPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final GlobalState _globalState = GlobalState();
  Stream<List<MarketItem>>? _allItemsStream;
  Stream<List<MarketItem>>? _userItemsStream;
  bool _isAddingItem = false;
  int _unreadChats = 0;
  final CommunityService _communityService = CommunityService();
  String? _currentUserCommunityId;
  late StreamSubscription<int> _unreadCountSubscription;

  // Loading state
  bool _isInitialLoading = true;

  // View mode state
  bool _isGridView = false; // Default to list view

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        setState(() {});
      });

    // Initialize unread count from the global state
    _unreadChats = _globalState.unreadChatCount;

    // Set up subscription to unread count changes
    _unreadCountSubscription =
        _globalState.unreadChatCountStream.listen((chatCount) {
      if (mounted && _unreadChats != chatCount) {
        setState(() {
          _unreadChats = chatCount;
        });
        widget.onUnreadChatsChanged?.call(chatCount);
      }
    });

    _loadUserCommunity();
    _setupChatListener();
    _loadViewPreference();

    // Force refresh the unread count
    _globalState.refreshUnreadCount();
  }

  // Load the user's view preference from SharedPreferences
  Future<void> _loadViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user != null && mounted) {
        setState(() {
          _isGridView = prefs.getBool('market_grid_view_${user.uid}') ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading view preference: $e');
    }
  }

  // Save the user's view preference to SharedPreferences
  Future<void> _saveViewPreference(bool isGridView) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user != null) {
        await prefs.setBool('market_grid_view_${user.uid}', isGridView);
      }
    } catch (e) {
      debugPrint('Error saving view preference: $e');
    }
  }

  // Toggle between grid and list view
  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });
    _saveViewPreference(_isGridView);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh unread count when dependencies change (e.g., when returning to this screen)
    _globalState.refreshUnreadCount();

    // Also update the local state with the current count
    setState(() {
      _unreadChats = _globalState.unreadChatCount;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh unread count when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _globalState.refreshUnreadCount();
    }
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
          _isInitialLoading = false; // Set loading to false after streams are initialized
        });
      } else {
        // If no community found, still set loading to false
        setState(() {
          _isInitialLoading = false;
        });
      }
    } else {
      // If no user, set loading to false
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  void _setupChatListener() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Listen for changes to the user's lastChatListVisit timestamp
    _database
        .ref('users/${currentUser.uid}/lastChatListVisit')
        .onValue
        .listen((event) {
      // When this changes, refresh the unread count
      _updateUnreadCount();
    });

    // Listen for changes to chats
    _database.ref('chats').onValue.listen((event) {
      if (!mounted) return;
      _updateUnreadCount(event.snapshot);
    });
  }

  void _updateUnreadCount([DataSnapshot? chatSnapshot]) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || !mounted) return;

    try {
      int unreadCount = 0;
      int totalChats = 0;

      // If no snapshot was provided, get one
      DataSnapshot snapshot =
          chatSnapshot ?? await _database.ref('chats').get();
      final chatData = snapshot.value as Map<dynamic, dynamic>?;

      if (chatData != null) {
        totalChats = chatData.length;
        print('DEBUG: Found $totalChats total chats in database');

        // Get all chats from the database
        for (var entry in chatData.entries) {
          final chatId = entry.key as String;
          final chatInfo = entry.value as Map<dynamic, dynamic>?;

          if (chatInfo == null) {
            print('DEBUG: Chat $chatId has null info');
            continue;
          }

          // Extract chat details
          final buyerId = chatInfo['buyerId'] as String?;
          final sellerId = chatInfo['sellerId'] as String?;
          final communityId = chatInfo['communityId'] as String?;

          print(
              'DEBUG: Checking chat $chatId - buyerId: $buyerId, sellerId: $sellerId, communityId: $communityId');

          // Skip if not in user's community
          if (communityId != _currentUserCommunityId) {
            print('DEBUG: Skipping chat $chatId - not in user community');
            continue;
          }

          // Skip if user is not part of this chat
          if (currentUser.uid != sellerId && currentUser.uid != buyerId) {
            print('DEBUG: Skipping chat $chatId - user not part of chat');
            continue;
          }

          print('DEBUG: User is part of chat $chatId');

          // Get unread count directly from the unreadCount field
          if (chatInfo.containsKey('unreadCount')) {
            final unreadCountMap =
                chatInfo['unreadCount'] as Map<dynamic, dynamic>?;
            if (unreadCountMap != null &&
                unreadCountMap.containsKey(currentUser.uid)) {
              final count = unreadCountMap[currentUser.uid] as int? ?? 0;
              print(
                  'DEBUG: Chat $chatId has $count unread messages for user ${currentUser.uid}');
              unreadCount += count;
            } else {
              print(
                  'DEBUG: Chat $chatId has no unread count for user ${currentUser.uid}');
            }
          } else {
            print('DEBUG: Chat $chatId has no unreadCount field');
          }
        }
      }

      print('DEBUG: Total unread count: $unreadCount');

      if (mounted) {
        // Only update state if the count has changed
        if (_unreadChats != unreadCount) {
          setState(() {
            _unreadChats = unreadCount;
          });

          // Notify parent widget about unread count change
          widget.onUnreadChatsChanged?.call(unreadCount);

          print('DEBUG: Updated _unreadChats to $unreadCount');
        }
      }
    } catch (e) {
      print('Error processing chat notifications: $e');
    }
  }

  void _initializeStreams() {
    if (_currentUserCommunityId == null) return;

    // Stream for all items in user's community - only show approved items
    _allItemsStream = _firestore
        .collection('market_items')
        .where('communityId', isEqualTo: _currentUserCommunityId)
        .where('status', isEqualTo: 'approved') // Only show approved items
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

      // Upload images to Cloudinary and get the download URLs
      List<String> downloadUrls = await _uploadImages(item.imageUrls);

      // Create new item document in Firestore using the item's ID
      await _firestore.collection('market_items').doc(item.id).set({
        'title': item.title,
        'price': item.price,
        'description': item.description,
        'sellerId': currentUser.uid,
        'sellerName':
            userData['fullName'] ?? userData['username'] ?? 'Unknown User',
        'imageUrls': downloadUrls,
        'communityId': _currentUserCommunityId,
        'createdAt': FieldValue.serverTimestamp(),
        'isSold': false,
        'status': 'pending', // Set initial status as pending
      }).catchError((error) {
        print('Firestore error details: $error');
        throw error;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Item added successfully! It will be visible after admin approval.')),
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

  Future<List<String>> _uploadImages(List<String> imagePaths) async {
    List<File> imageFiles = imagePaths.map((path) => File(path)).toList();
    final cloudinaryService = CloudinaryService();
    return await cloudinaryService.uploadMarketImages(imageFiles);
  }

  void _handleImageTap(BuildContext context, MarketItem item) {
    if (item.imageUrls.isEmpty) return;

    if (item.imageUrls.length == 1) {
      // Single image - use the simple image viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerPage(imageUrl: item.imageUrls[0]),
        ),
      );
    } else {
      // Multiple images - use the multi-image viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MultiImageViewerPage(
            imageUrls: item.imageUrls,
            initialIndex: 0,
          ),
        ),
      );
    }
  }

  // Fix method removed as it's no longer needed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Market',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        // Add padding to the actions
        actionsIconTheme: const IconThemeData(size: 26),
        actions: [
          // View Toggle Button
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: _toggleViewMode,
            tooltip:
                _isGridView ? 'Switch to List View' : 'Switch to Grid View',
          ),
          // Seller Dashboard Button with distinct icon
          IconButton(
            icon: const Icon(Icons.store_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/seller/dashboard',
                  arguments: {'initialTabIndex': 0});
            },
            tooltip: 'Seller Dashboard',
          ),
          // Chat Button with Notification Badge
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Make the icon button open the chat page
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
                // Make the badge also open the chat page
                Positioned(
                  right: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatListPage(),
                        ),
                      );
                    },
                    child: Visibility(
                      visible: _unreadChats > 0,
                      maintainState: true,
                      maintainAnimation: true,
                      maintainSize: true,
                      child: _NotificationBadge(
                        count: _unreadChats,
                        color: Colors.red,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChatListPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
      body: _isInitialLoading
          ? MarketplaceShimmerLoading(isGridView: _isGridView)
          : TabBarView(
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
                      return MarketplaceShimmerLoading(isGridView: _isGridView);
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
                      return MarketplaceShimmerLoading(isGridView: _isGridView);
                    }

                    final items = snapshot.data ?? [];
                    final hasPendingItems =
                        items.any((item) => item.status == 'pending');

                    return Column(
                      children: [
                        // Show pending items notification if there are any
                        if (hasPendingItems)
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/seller/dashboard',
                                  arguments: {'initialTabIndex': 1});
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 16),
                              color: Colors.orange.withOpacity(0.1),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.pending_actions,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'You have items pending approval',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Colors.orange,
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Main content
                        Expanded(
                          child: _buildItemList(items),
                        ),
                      ],
                    );
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
    final bool isMyItemsTab = _tabController.index == 1;

    // Debug print for all items to check their status
    for (var item in items) {
      if (item.isSold) {
        if (item.soldAt != null) {
          final now = DateTime.now();
          final soldAt = item.soldAt!;
          final timeDifference = now.difference(soldAt);
          final secondsAgo = timeDifference.inSeconds;
          final minutesAgo = timeDifference.inMinutes;
          debugPrint(
              'Item ${item.title} (status: ${item.status}) sold $minutesAgo minutes ($secondsAgo seconds) ago (soldAt: $soldAt)');
        } else {
          debugPrint(
              'Item ${item.title} (status: ${item.status}) is marked as sold but has no soldAt timestamp');
        }
      } else {
        debugPrint('Item ${item.title} (status: ${item.status}) is not sold');
      }
    }

    // For My Items tab, hide sold items and pending items immediately
    // For All Items tab, filter out items that are not approved and hide sold items after 10 minutes
    final List<MarketItem> displayItems = isMyItemsTab
        ? items
            .where((item) => !item.isSold && item.status != 'pending')
            .toList() // Hide sold and pending items in My Items tab
        : items.where((item) {
            // Always show approved items that are not sold
            if (item.status == 'approved' && !item.isSold) {
              return true;
            }

            // For sold items, check if they were sold within the last 10 minutes
            if (item.status == 'approved' && item.isSold) {
              // If soldAt is null, set a default timestamp 10 minutes ago
              // This ensures items with missing soldAt will disappear after a refresh
              if (item.soldAt == null) {
                debugPrint(
                    'Item ${item.title} has null soldAt timestamp, using default logic');
                // For items with null soldAt, show them for this session but they'll disappear on refresh
                return true;
              }

              // Calculate time difference between now and when the item was marked as sold
              final now = DateTime.now();
              final soldAt = item.soldAt!;
              final timeDifference = now.difference(soldAt);
              final secondsAgo = timeDifference.inSeconds;

              // Show the item if it was sold less than 10 minutes ago
              // Use total seconds for more precise comparison (avoid rounding issues)
              final shouldShow = secondsAgo < 600; // 10 minutes = 600 seconds
              if (shouldShow) {
                debugPrint(
                    'Item ${item.title} is showing because it was sold $secondsAgo seconds ago (< 600 seconds)');
              } else {
                debugPrint(
                    'Item ${item.title} is NOT showing because it was sold $secondsAgo seconds ago (>= 600 seconds)');
              }
              return shouldShow;
            }

            return false;
          }).toList();

    // For All Items tab, sort items so active items appear at the top, followed by sold items
    if (!isMyItemsTab) {
      displayItems.sort((a, b) {
        // First sort by sold status (active items first)
        if (a.isSold != b.isSold) {
          return a.isSold ? 1 : -1; // Active items (not sold) come first
        }
        // Then sort by creation date (newest first)
        if (a.createdAt != null && b.createdAt != null) {
          return b.createdAt!.compareTo(a.createdAt!);
        }
        return 0;
      });
    }

    if (displayItems.isEmpty) {
      // Check if there are pending items when in My Items tab
      bool hasPendingItems =
          isMyItemsTab && items.any((item) => item.status == 'pending');

      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Container with icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F0),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Icon(
                  isMyItemsTab
                      ? Icons.shopping_bag_outlined
                      : Icons.store_outlined,
                  size: 64,
                  color: const Color(0xFF00C49A),
                ),
              ),
              const SizedBox(height: 24),
              // Main message
              Text(
                isMyItemsTab
                    ? hasPendingItems
                        ? 'No active items to display'
                        : 'You haven\'t added any items yet'
                    : 'No marketplace items yet',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Subtitle message
              Text(
                isMyItemsTab
                    ? hasPendingItems
                        ? 'Your items are awaiting approval'
                        : 'Tap the + button to add your first item'
                    : 'Be the first to add something to the community marketplace',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              // Action button for My Items tab with pending items
              if (hasPendingItems) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/seller/dashboard',
                        arguments: {'initialTabIndex': 1});
                  },
                  icon: const Icon(Icons.dashboard),
                  label: const Text('View in Seller Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C49A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              // Action button for All Items tab
              if (!isMyItemsTab) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
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
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C49A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Precache next few images
    for (var i = 0; i < items.length && i < 5; i++) {
      if (items[i].imageUrls.isNotEmpty &&
          items[i].imageUrls[0].startsWith('http')) {
        precacheImage(NetworkImage(items[i].imageUrls[0]), context);
      }
    }

    // Return either ListView or GridView based on the current view mode
    return _isGridView
        ? GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // Reduced to 2 items per row for more space
              childAspectRatio:
                  0.6, // Further reduced to give more height for buttons
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: displayItems.length,
            itemBuilder: (context, index) {
              final bool isMyItemsTab = _tabController.index == 1;
              return MarketItemCard(
                item: displayItems[index],
                onInterested: () =>
                    _handleInterested(context, displayItems[index]),
                onImageTap: () => _handleImageTap(context, displayItems[index]),
                isOwner: _auth.currentUser?.uid == displayItems[index].sellerId,
                showEditButton: isMyItemsTab,
                onEdit: isMyItemsTab
                    ? () => _handleEditItem(displayItems[index])
                    : null,
                onDelete: isMyItemsTab
                    ? () => _handleDelete(displayItems[index])
                    : null,
                onSellerTap: !isMyItemsTab
                    ? () => _navigateToSellerProfile(displayItems[index])
                    : null,
                isGridView: true, // Pass grid view flag to card
              );
            },
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: displayItems.length,
            itemBuilder: (context, index) {
              final bool isMyItemsTab = _tabController.index == 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: MarketItemCard(
                  item: displayItems[index],
                  onInterested: () =>
                      _handleInterested(context, displayItems[index]),
                  onImageTap: () =>
                      _handleImageTap(context, displayItems[index]),
                  isOwner:
                      _auth.currentUser?.uid == displayItems[index].sellerId,
                  showEditButton: isMyItemsTab,
                  onEdit: isMyItemsTab
                      ? () => _handleEditItem(displayItems[index])
                      : null,
                  onDelete: isMyItemsTab
                      ? () => _handleDelete(displayItems[index])
                      : null,
                  onSellerTap: !isMyItemsTab
                      ? () => _navigateToSellerProfile(displayItems[index])
                      : null,
                  isGridView: false, // Pass list view flag to card
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

  Future<void> _handleDelete(MarketItem item) async {
    final confirmDelete = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Item',
      message:
          'Are you sure you want to delete this item? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: Colors.red,
      icon: Icons.delete_forever_rounded,
      iconBackgroundColor: Colors.red,
    );

    if (confirmDelete != true) return;

    try {
      // Delete the item from Firestore
      await _firestore.collection('market_items').doc(item.id).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting item: $e')),
        );
      }
    }
  }

  void _navigateToSellerProfile(MarketItem item) {
    // Navigate to seller profile page, passing the seller ID and name
    // The seller profile page will filter out pending items since this is not the current user
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellerProfilePage(
          sellerId: item.sellerId,
          sellerName: item.sellerName,
        ),
      ),
    );
  }

  Future<void> _handleItemUpdate(
      MarketItem updatedItem, List<String>? newImagePaths) async {
    setState(() {
      _isAddingItem = true;
    });

    try {
      List<String> finalImageUrls = List.from(updatedItem.imageUrls);

      // Only upload new images if provided
      if (newImagePaths != null && newImagePaths.isNotEmpty) {
        // Upload the new images
        List<String> newUploadedUrls = await _uploadImages(newImagePaths);

        // Merge existing images with new ones, respecting the 5 image limit
        if (finalImageUrls.isEmpty) {
          // If there are no existing images, just use the new ones
          finalImageUrls = newUploadedUrls;
        } else {
          // If there are existing images, add the new ones up to a maximum of 5 total
          final int remainingSlots = 5 - finalImageUrls.length;
          if (remainingSlots > 0) {
            // Add only up to the remaining slots
            finalImageUrls.addAll(newUploadedUrls.take(remainingSlots));
          }
        }
      }

      // Update the item in Firestore
      await _firestore.collection('market_items').doc(updatedItem.id).update({
        'title': updatedItem.title,
        'price': updatedItem.price,
        'description': updatedItem.description,
        'imageUrls': finalImageUrls,
        'communityId': updatedItem.communityId,
        'isSold': updatedItem.isSold,
        'status': 'pending', // Reset to pending after edit for re-approval
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Item updated successfully! It will need to be approved again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating item: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingItem = false;
        });
      }
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
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _unreadCountSubscription.cancel();
    super.dispose();
  }
}
