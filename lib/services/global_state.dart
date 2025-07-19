import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A simple global state class to maintain app-wide state
class GlobalState {
  // Singleton pattern
  static final GlobalState _instance = GlobalState._internal();
  factory GlobalState() => _instance;
  GlobalState._internal() {
    _initialize();
  }

  // Unread chat count
  int _unreadChatCount = 0;
  final _unreadChatCountController = StreamController<int>.broadcast();

  // Logout state
  bool _isLoggingOut = false;
  final _logoutController = StreamController<bool>.broadcast();

  // Stream subscriptions
  StreamSubscription? _chatSubscription;
  StreamSubscription? _visitSubscription;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Getters
  int get unreadChatCount => _unreadChatCount;
  Stream<int> get unreadChatCountStream => _unreadChatCountController.stream;

  bool get isLoggingOut => _isLoggingOut;
  Stream<bool> get logoutStream => _logoutController.stream;

  void _initialize() async {
    _unreadChatCount = await _getStoredUnreadCount();

    // Start listening for changes
    _startListening();

    // Log initialization
    debugPrint('GlobalState initialized with unread count: $_unreadChatCount');
  }

  Future<int> _getStoredUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user != null) {
        return prefs.getInt('unread_chat_count_${user.uid}') ?? 0;
      }
    } catch (e) {
      debugPrint('Error getting stored unread count: $e');
    }
    return 0;
  }

  Future<void> _saveUnreadCount(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user != null) {
        await prefs.setInt('unread_chat_count_${user.uid}', count);
      }
    } catch (e) {
      debugPrint('Error saving unread count: $e');
    }
  }

  // Start listening for changes
  void _startListening() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Listen for changes to chats
    _chatSubscription = _database.ref('chats').onValue.listen((event) {
      _updateUnreadCount(event.snapshot);
    });

    // Listen for changes to the lastChatListVisit timestamp
    _visitSubscription = _database.ref('users/${user.uid}/lastChatListVisit').onValue.listen((_) {
      // When this changes, refresh the unread count
      _fetchUnreadCount();
    });
  }

  void _updateUnreadCount(DataSnapshot snapshot) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      int unreadCount = 0;
      final chatData = snapshot.value as Map<dynamic, dynamic>?;

      if (chatData != null) {
        for (var entry in chatData.entries) {
          final chatInfo = entry.value as Map<dynamic, dynamic>?;

          if (chatInfo == null) continue;

          final buyerId = chatInfo['buyerId'] as String?;
          final sellerId = chatInfo['sellerId'] as String?;
          final communityId = chatInfo['communityId'] as String?;

          // Skip if user is not part of this chat
          if (user.uid != sellerId && user.uid != buyerId) continue;

          if (chatInfo.containsKey('unreadCount')) {
            final unreadCountMap = chatInfo['unreadCount'] as Map<dynamic, dynamic>?;
            if (unreadCountMap != null && unreadCountMap.containsKey(user.uid)) {
              final count = unreadCountMap[user.uid] as int? ?? 0;
              unreadCount += count;
            }
          }
        }
      }

      // Only update if the count has changed
      if (_unreadChatCount != unreadCount) {
        _unreadChatCount = unreadCount;
        await _saveUnreadCount(unreadCount);
        _notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating unread count: $e');
    }
  }

  Future<void> _fetchUnreadCount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _database.ref('chats').get();
      _updateUnreadCount(snapshot);
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
    }
  }

  // Notify listeners of changes
  void _notifyListeners() {
    if (!_unreadChatCountController.isClosed) {
      _unreadChatCountController.add(_unreadChatCount);
    }
  }

  // Force refresh the unread count
  Future<void> refreshUnreadCount() async {
    await _fetchUnreadCount();

    // Also notify listeners with the current count to ensure UI updates
    _notifyListeners();

    // Log the refresh
    debugPrint('Refreshed unread count: $_unreadChatCount');
  }

  void setLogoutState(bool isLoggingOut) {
    _isLoggingOut = isLoggingOut;
    if (!_logoutController.isClosed) {
      _logoutController.add(_isLoggingOut);
    }
    debugPrint('Logout state changed: $_isLoggingOut');
  }

  // Dispose of resources
  void dispose() {
    _chatSubscription?.cancel();
    _visitSubscription?.cancel();
    if (!_unreadChatCountController.isClosed) {
      _unreadChatCountController.close();
    }
    if (!_logoutController.isClosed) {
      _logoutController.close();
    }
  }
}
