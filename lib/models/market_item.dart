import 'package:cloud_firestore/cloud_firestore.dart';

class MarketItem {
  final String id;
  final String title;
  final double price;
  final String description;
  final String sellerId;
  final String sellerName;
  final List<String> imageUrls;
  final String communityId;
  final DateTime? createdAt;
  final bool isSold;
  final DateTime? soldAt; // When the item was marked as sold
  final String status; // pending, approved, rejected
  final String? rejectionReason;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;

  MarketItem({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.sellerId,
    required this.sellerName,
    required this.imageUrls,
    required this.communityId,
    this.createdAt,
    this.isSold = false,
    this.soldAt,
    this.status = 'pending',
    this.rejectionReason,
    this.approvedBy,
    this.approvedAt,
    this.rejectedAt,
  });

  factory MarketItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    
    List<String> imageUrls = [];
    if (data['imageUrls'] != null) {
      
      imageUrls = List<String>.from(data['imageUrls']);
    } else if (data['imageUrl'] != null) {
      
      imageUrls = [data['imageUrl']];
    }

    return MarketItem(
      id: doc.id,
      title: data['title'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? '',
      imageUrls: imageUrls,
      communityId: data['communityId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isSold: data['isSold'] ?? false,
      soldAt: (data['soldAt'] as Timestamp?)?.toDate(),
      status: data['status'] ?? 'pending',
      rejectionReason: data['rejectionReason'],
      approvedBy: data['approvedBy'],
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'price': price,
      'description': description,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'imageUrls': imageUrls,
      'communityId': communityId,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'isSold': isSold,
      'soldAt': soldAt,
      'status': status,
      'rejectionReason': rejectionReason,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt,
      'rejectedAt': rejectedAt,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'description': description,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'imageUrls': imageUrls,
      'communityId': communityId,
      'isSold': isSold,
      'soldAt': soldAt,
      'status': status,
      'rejectionReason': rejectionReason,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt,
      'rejectedAt': rejectedAt,
    };
  }

  factory MarketItem.fromJson(Map<String, dynamic> json) {
    
    List<String> imageUrls = [];
    if (json['imageUrls'] != null) {

      imageUrls = List<String>.from(json['imageUrls']);
    } else if (json['imageUrl'] != null) {

      imageUrls = [json['imageUrl']];
    }

    return MarketItem(
      id: json['id'] as String,
      title: json['title'] as String,
      price: json['price'] as double,
      description: json['description'] as String,
      sellerId: json['sellerId'] as String,
      sellerName: json['sellerName'] as String,
      imageUrls: imageUrls,
      communityId: json['communityId'] as String,
      status: json['status'] as String? ?? 'pending',
      isSold: json['isSold'] as bool? ?? false,
      soldAt: json['soldAt'] != null ? DateTime.parse(json['soldAt']) : null,
      rejectionReason: json['rejectionReason'] as String?,
      approvedBy: json['approvedBy'] as String?,
      approvedAt: json['approvedAt'] != null ? DateTime.parse(json['approvedAt']) : null,
      rejectedAt: json['rejectedAt'] != null ? DateTime.parse(json['rejectedAt']) : null,
    );
  }
}
