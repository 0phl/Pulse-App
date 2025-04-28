import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../models/market_item.dart';

class DashboardUtils {
  // Helper method to get the appropriate refresh controller based on the stream
  static RefreshController getRefreshControllerForTab(
    Stream<List<MarketItem>>? itemsStream,
    Stream<List<MarketItem>> pendingItemsStream,
    Stream<List<MarketItem>> rejectedItemsStream,
    Stream<List<MarketItem>> soldItemsStream,
    RefreshController overviewRefreshController,
    RefreshController pendingRefreshController,
    RefreshController rejectedRefreshController,
    RefreshController soldRefreshController,
  ) {
    if (itemsStream == pendingItemsStream) {
      return pendingRefreshController;
    } else if (itemsStream == rejectedItemsStream) {
      return rejectedRefreshController;
    } else if (itemsStream == soldItemsStream) {
      return soldRefreshController;
    } else {
      // Default to overview controller if stream doesn't match any known stream
      return overviewRefreshController;
    }
  }

  // Helper method to convert various date formats to DateTime
  static DateTime getDateTime(dynamic dateValue, {MarketItem? item}) {
    // Debug info
    debugPrint('DashboardUtils.getDateTime called with:');
    debugPrint('  - dateValue type: ${dateValue?.runtimeType}');
    debugPrint('  - dateValue: $dateValue');
    if (item != null) {
      debugPrint('  - item.title: ${item.title}');
      debugPrint('  - item.isSold: ${item.isSold}');
      debugPrint('  - item.soldAt: ${item.soldAt}');
      debugPrint('  - item.createdAt: ${item.createdAt}');
    }

    // If this is a sold item and it has a soldAt timestamp, use that
    if (item != null && item.isSold && item.soldAt != null) {
      debugPrint('  - Using item.soldAt: ${item.soldAt}');
      return item.soldAt!;
    }

    DateTime result;
    if (dateValue == null) {
      debugPrint('  - dateValue is null, using DateTime.now()');
      result = DateTime.now();
    } else if (dateValue is Timestamp) {
      debugPrint('  - Converting Timestamp to DateTime: ${dateValue.toDate()}');
      result = dateValue.toDate();
    } else if (dateValue is DateTime) {
      debugPrint('  - Using DateTime directly: $dateValue');
      result = dateValue;
    } else {
      debugPrint('  - Unknown type, using DateTime.now()');
      result = DateTime.now();
    }

    debugPrint('  - Final result: $result');
    return result;
  }

  // Helper to safely unlock a tab with delay
  static Future<void> safelyUnlockTab(TabController tabController, bool mounted,
      int lockedTabIndex, Function(bool) setIsTabLocked) async {
    // Add a small delay before unlocking to ensure any pending tab changes are processed
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      final currentTab = tabController.index;
      if (currentTab != lockedTabIndex) {
        tabController.index = lockedTabIndex;

        // Add another small delay to ensure the tab is restored
        await Future.delayed(const Duration(milliseconds: 100));
      }

      setIsTabLocked(false);
    }
  }
}

// Utility for managing tab transitions
mixin TabLockMixin<T extends StatefulWidget> on State<T> {
  late bool _isTabLocked = false;
  late int _lockedTabIndex = 0;

  // Track tab changes
  void handleTabChange(TabController tabController) {
    // Only handle tab changes when the controller is actually changing tabs
    if (tabController.indexIsChanging) {
      final newIndex = tabController.index;

      // If tab is locked, prevent the change
      if (_isTabLocked && newIndex != _lockedTabIndex) {
        // Immediately jump back to the locked tab without animation
        tabController.index = _lockedTabIndex;

        // Also use post-frame callback as a backup to ensure we stay on the locked tab
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isTabLocked) {
            if (tabController.index != _lockedTabIndex) {
              tabController.index = _lockedTabIndex;
            }
          }
        });
      }
    }
  }

  bool get isTabLocked => _isTabLocked;
  int get lockedTabIndex => _lockedTabIndex;

  // Setter to update the tab lock status
  void setIsTabLocked(bool locked) {
    setState(() {
      _isTabLocked = locked;
    });
  }

  // Set the locked tab index
  void setLockedTabIndex(int index) {
    _lockedTabIndex = index;
  }

  // Lock the current tab
  void lockCurrentTab(TabController tabController) {
    final currentTab = tabController.index;
    setIsTabLocked(true);
    setLockedTabIndex(currentTab);
  }
}
