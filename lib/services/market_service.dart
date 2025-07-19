import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/market_item.dart';
import '../models/seller_rating.dart';
import 'package:intl/intl.dart';

class MarketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  final CollectionReference _marketItemsCollection =
      FirebaseFirestore.instance.collection('market_items');
  final CollectionReference _sellerRatingsCollection =
      FirebaseFirestore.instance.collection('seller_ratings');
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  Stream<List<MarketItem>> getMarketItemsStream(String communityId) {
    return _marketItemsCollection
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'approved') // Only show approved items
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MarketItem.fromFirestore(doc)).toList());
  }

  Stream<List<MarketItem>> getSellerItemsStream(String sellerId,
      {bool isCurrentUser = false}) {
    // If viewing own profile, show all items including pending
    // If viewing another seller's profile, only show approved items that are not sold
    Query query = _marketItemsCollection.where('sellerId', isEqualTo: sellerId);

    // Only filter by status if not viewing own profile
    if (!isCurrentUser) {
      query = query.where('status', isEqualTo: 'approved');
      query = query.where('isSold',
          isEqualTo:
              false); // Only show active items when viewing other sellers
    }

    return query.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => MarketItem.fromFirestore(doc)).toList());
  }

  Future<MarketItem?> getMarketItem(String itemId) async {
    final doc = await _marketItemsCollection.doc(itemId).get();
    if (doc.exists) {
      return MarketItem.fromFirestore(doc);
    }
    return null;
  }

  Stream<MarketItem?> getMarketItemStream(String itemId) {
    return _marketItemsCollection
        .doc(itemId)
        .snapshots()
        .map((doc) => doc.exists ? MarketItem.fromFirestore(doc) : null);
  }

  Future<String> addMarketItem(MarketItem item) async {
    final docRef = await _marketItemsCollection.add(item.toFirestore());
    return docRef.id;
  }

  Future<void> updateMarketItem(MarketItem item) async {
    await _marketItemsCollection.doc(item.id).update(item.toFirestore());
  }

  Future<void> deleteMarketItem(String itemId) async {
    await _marketItemsCollection.doc(itemId).delete();
  }

  // Mark an item as sold
  Future<void> markItemAsSold(String itemId) async {
    // First update with server timestamp
    await _marketItemsCollection.doc(itemId).update({
      'isSold': true,
      'soldAt': FieldValue.serverTimestamp(),
    });

    // Then fetch the updated document to get the actual server timestamp
    final updatedDoc = await _marketItemsCollection.doc(itemId).get();
    if (updatedDoc.exists) {
      final data = updatedDoc.data() as Map<String, dynamic>;
      final soldAt = data['soldAt'] as Timestamp?;

      // If soldAt is still null (server timestamp not yet processed), set it manually
      if (soldAt == null) {
        await _marketItemsCollection.doc(itemId).update({
          'soldAt': Timestamp.now(),
        });
      }
    }
  }

  Stream<List<SellerRating>> getSellerRatingsStream(String sellerId) {
    return _sellerRatingsCollection
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SellerRating.fromFirestore(doc))
            .toList());
  }

  Future<String> addSellerRating(SellerRating rating) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to rate a seller');
    }

    final existingRatings = await _sellerRatingsCollection
        .where('sellerId', isEqualTo: rating.sellerId)
        .where('buyerId', isEqualTo: currentUser.uid)
        .where('marketItemId', isEqualTo: rating.marketItemId)
        .get();

    if (existingRatings.docs.isNotEmpty) {
      final existingRatingId = existingRatings.docs.first.id;
      await _sellerRatingsCollection
          .doc(existingRatingId)
          .update(rating.toFirestore());
      return existingRatingId;
    } else {
      final docRef = await _sellerRatingsCollection.add(rating.toFirestore());
      return docRef.id;
    }
  }

  Future<bool> hasUserRatedTransaction(
      String sellerId, String buyerId, String marketItemId) async {
    if (buyerId.isEmpty) return false;

    final existingRatings = await _sellerRatingsCollection
        .where('sellerId', isEqualTo: sellerId)
        .where('buyerId', isEqualTo: buyerId)
        .where('marketItemId', isEqualTo: marketItemId)
        .get();

    return existingRatings.docs.isNotEmpty;
  }

  Future<double> getSellerAverageRating(String sellerId) async {
    final ratingsSnapshot = await _sellerRatingsCollection
        .where('sellerId', isEqualTo: sellerId)
        .get();

    if (ratingsSnapshot.docs.isEmpty) {
      return 0.0;
    }

    double totalRating = 0.0;
    for (var doc in ratingsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalRating += (data['rating'] as num).toDouble();
    }

    return totalRating / ratingsSnapshot.docs.length;
  }

  Future<Map<String, dynamic>> getSellerProfile(String sellerId) async {
    final userDoc = await _usersCollection.doc(sellerId).get();
    if (!userDoc.exists) {
      throw Exception('Seller not found');
    }

    final userData = userDoc.data() as Map<String, dynamic>;
    final averageRating = await getSellerAverageRating(sellerId);
    final ratingsCount = await _sellerRatingsCollection
        .where('sellerId', isEqualTo: sellerId)
        .count()
        .get();

    return {
      'id': sellerId,
      'name': userData['fullName'] ?? userData['username'] ?? 'Unknown User',
      'email': userData['email'] ?? 'N/A',
      'phone': userData['phone'] ?? 'N/A',
      'profileImage': userData['profileImageUrl'] ?? '',
      'averageRating': averageRating,
      'ratingsCount': ratingsCount.count,
      'joinedDate': (userData['createdAt'] as Timestamp?)?.toDate(),
    };
  }

  Stream<Map<String, dynamic>> getSellerProfileStream(String sellerId) {
    return _usersCollection.doc(sellerId).snapshots().asyncMap((userDoc) async {
      if (!userDoc.exists) {
        throw Exception('Seller not found');
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      final averageRating = await getSellerAverageRating(sellerId);

      final ratingsCount = await _sellerRatingsCollection
          .where('sellerId', isEqualTo: sellerId)
          .count()
          .get();

      return {
        'id': sellerId,
        'name': userData['fullName'] ?? userData['username'] ?? 'Unknown User',
        'email': userData['email'] ?? 'N/A',
        'phone': userData['phone'] ?? 'N/A',
        'profileImage': userData['profileImageUrl'] ?? '',
        'averageRating': averageRating,
        'ratingsCount': ratingsCount.count,
        'joinedDate': (userData['createdAt'] as Timestamp?)?.toDate(),
      };
    });
  }

  Future<bool> canRateSeller(String sellerId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    if (currentUser.uid == sellerId) return false; // Can't rate yourself

    // In a real app, you would check if the current user has purchased from this seller
    // For simplicity, we'll allow any user to rate any seller
    return true;
  }

  Future<Map<String, dynamic>> getSellerDashboardStats() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to view seller dashboard');
    }

    final itemsSnapshot = await _marketItemsCollection
        .where('sellerId', isEqualTo: currentUser.uid)
        .get();

    int totalItems = 0;
    int itemsSold = 0;
    double totalRevenue = 0.0;
    double averagePrice = 0.0;

    for (var doc in itemsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalItems++;

      if (data['isSold'] == true) {
        itemsSold++;
        totalRevenue += (data['price'] as num).toDouble();
      }
    }

    if (itemsSold > 0) {
      averagePrice = totalRevenue / itemsSold;
    }

    final dailySales = await getDailySalesData();

    List<Map<String, dynamic>> recentActivity = [];

    final recentItemsSnapshot = await _marketItemsCollection
        .where('sellerId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    for (var doc in recentItemsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final title = data['title'] as String? ?? 'Unknown item';

      if (data['approvedAt'] != null) {
        recentActivity.add({
          'type': 'item_approved',
          'message': 'Your item "$title" was approved',
          'timestamp': data['approvedAt'],
          'itemId': doc.id,
        });
      }

      if (data['rejectedAt'] != null) {
        recentActivity.add({
          'type': 'item_rejected',
          'message': 'Your item "$title" was rejected',
          'timestamp': data['rejectedAt'],
          'itemId': doc.id,
          'reason': data['rejectionReason'],
        });
      }

      if (data['isSold'] == true) {
        recentActivity.add({
          'type': 'item_sold',
          'message': 'Your item "$title" was sold',
          'timestamp': data['soldAt'] ?? data['createdAt'],
          'itemId': doc.id,
          'price': data['price'],
        });
      }
    }

    final recentRatingsSnapshot = await _sellerRatingsCollection
        .where('sellerId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    for (var doc in recentRatingsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final rating = (data['rating'] as num).toDouble();
      final buyerName = data['buyerName'] as String? ?? 'A buyer';

      recentActivity.add({
        'type': 'new_rating',
        'message': '$buyerName gave you a $rating-star rating',
        'timestamp': data['createdAt'],
        'ratingId': doc.id,
        'rating': rating,
      });
    }

    // Sort all activities by timestamp (most recent first)
    recentActivity.sort((a, b) {
      final aTime = a['timestamp'] as Timestamp;
      final bTime = b['timestamp'] as Timestamp;
      return bTime.compareTo(aTime);
    });

    // Limit to 10 most recent activities
    if (recentActivity.length > 10) {
      recentActivity = recentActivity.sublist(0, 10);
    }

    return {
      'totalItems': totalItems,
      'itemsSold': itemsSold,
      'totalRevenue': totalRevenue,
      'averagePrice': averagePrice,
      'dailySales': dailySales,
      'recentActivity': recentActivity,
    };
  }

  Future<Map<String, dynamic>> getDailySalesData({
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    debugPrint('MarketService.getDailySalesData called');

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to view sales data');
    }

    final now = DateTime.now();
    final endDate = customEndDate ?? now;
    final startDate = customStartDate ??
        DateTime(now.year, now.month, now.day - 6); // 7 days including today by default

    debugPrint('Date range: ${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}');

    final daysDifference = endDate.difference(startDate).inDays + 1;
    final Map<String, dynamic> dailySales = {};

    for (int i = 0; i < daysDifference; i++) {
      final date = startDate.add(Duration(days: i));
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      dailySales[dateString] = 0.0;
    }

    debugPrint('Initialized ${dailySales.length} days with zero values');

    final soldItemsSnapshot = await _marketItemsCollection
        .where('sellerId', isEqualTo: currentUser.uid)
        .where('isSold', isEqualTo: true)
        .get();

    debugPrint('Found ${soldItemsSnapshot.docs.length} sold items for seller ${currentUser.uid}');

    for (var doc in soldItemsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;

      debugPrint('Processing sold item: ${data['title']} (ID: ${doc.id})');
      debugPrint('  - soldAt: ${data['soldAt']}');
      debugPrint('  - createdAt: ${data['createdAt']}');

      final timestamp = data['soldAt'] ?? data['createdAt'];
      if (timestamp == null) {
        debugPrint('  - No timestamp found, skipping item');
        continue;
      }

      final soldDate = (timestamp as Timestamp).toDate();
      debugPrint('  - Using date: $soldDate');

      if (soldDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          soldDate.isBefore(endDate.add(const Duration(days: 1)))) {
        final dateString = DateFormat('yyyy-MM-dd').format(soldDate);
        final price = (data['price'] as num).toDouble();

        debugPrint('  - Sale falls within date range, adding ₱$price to $dateString');

        if (dailySales.containsKey(dateString)) {
          dailySales[dateString] = (dailySales[dateString] as double) + price;
          debugPrint('  - Updated total for $dateString: ₱${dailySales[dateString]}');
        } else {
          debugPrint('  - Date $dateString not in range, skipping');
        }
      } else {
        debugPrint('  - Sale date outside of range window, skipping');
      }
    }

    debugPrint('Final daily sales data: $dailySales');
    return dailySales;
  }

  Stream<Map<String, dynamic>> getDailySalesDataStream({
    DateTime? customStartDate,
    DateTime? customEndDate,
    int defaultDays = 7,
  }) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to view sales data');
    }

    return _marketItemsCollection
        .where('sellerId', isEqualTo: currentUser.uid)
        .where('isSold', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final endDate = customEndDate ?? now;
      final startDate = customStartDate ??
          DateTime(now.year, now.month, now.day - (defaultDays - 1));

      final daysDifference = endDate.difference(startDate).inDays + 1;
      final Map<String, dynamic> dailySales = {};

      for (int i = 0; i < daysDifference; i++) {
        final date = startDate.add(Duration(days: i));
        final dateString = DateFormat('yyyy-MM-dd').format(date);
        dailySales[dateString] = 0.0;
      }

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final timestamp = data['soldAt'] ?? data['createdAt'];
        if (timestamp == null) continue;

        final soldDate = (timestamp as Timestamp).toDate();

        if (soldDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
            soldDate.isBefore(endDate.add(const Duration(days: 1)))) {
          final dateString = DateFormat('yyyy-MM-dd').format(soldDate);
          final price = (data['price'] as num).toDouble();

          if (dailySales.containsKey(dateString)) {
            dailySales[dateString] = (dailySales[dateString] as double) + price;
          }
        }
      }

      return dailySales;
    });
  }

  Future<List<MarketItem>> getSellerItemsByStatus(String status) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to view items');
    }

    final snapshot = await _marketItemsCollection
        .where('sellerId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: status)
        .where('isSold', isEqualTo: false) // Not sold items
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => MarketItem.fromFirestore(doc)).toList();
  }

  Stream<List<MarketItem>> getSellerItemsByStatusStream(String status) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to view items');
    }

    return _marketItemsCollection
        .where('sellerId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: status)
        .where('isSold', isEqualTo: false) // Not sold items
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MarketItem.fromFirestore(doc)).toList());
  }

  Future<List<MarketItem>> getSellerSoldItems() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to view sold items');
    }

    final snapshot = await _marketItemsCollection
        .where('sellerId', isEqualTo: currentUser.uid)
        .where('isSold', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => MarketItem.fromFirestore(doc)).toList();
  }

  Stream<List<MarketItem>> getSellerSoldItemsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to view sold items');
    }

    return _marketItemsCollection
        .where('sellerId', isEqualTo: currentUser.uid)
        .where('isSold', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MarketItem.fromFirestore(doc)).toList());
  }

  Future<Map<String, dynamic>> getSellerRatingInfo() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to view rating information');
    }

    final averageRating = await getSellerAverageRating(currentUser.uid);
    final ratingsCount = await _sellerRatingsCollection
        .where('sellerId', isEqualTo: currentUser.uid)
        .count()
        .get();

    return {
      'averageRating': averageRating,
      'totalRatings': ratingsCount.count,
    };
  }

  // Fix sold items with missing soldAt timestamps
  Future<int> fixSoldItemsWithMissingSoldAt(String communityId) async {
    int fixedCount = 0;

    final snapshot = await _marketItemsCollection
        .where('communityId', isEqualTo: communityId)
        .where('isSold', isEqualTo: true)
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['soldAt'] == null) {
        await _marketItemsCollection.doc(doc.id).update({
          'soldAt': Timestamp.now(),
        });
        fixedCount++;
      }
    }

    return fixedCount;
  }
}
