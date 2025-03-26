import 'package:cloud_firestore/cloud_firestore.dart';

class MarketItem {
  final String id;
  final String title;
  final double price;
  final String description;
  final String sellerId;
  final String sellerName;
  final String imageUrl;
  final String communityId;
  final DateTime? createdAt;
  final bool isSold;

  MarketItem({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.sellerId,
    required this.sellerName,
    required this.imageUrl,
    required this.communityId,
    this.createdAt,
    this.isSold = false,
  });

  factory MarketItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketItem(
      id: doc.id,
      title: data['title'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      communityId: data['communityId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isSold: data['isSold'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'price': price,
      'description': description,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'imageUrl': imageUrl,
      'communityId': communityId,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'isSold': isSold,
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
      'imageUrl': imageUrl,
      'communityId': communityId,
      'isSold': isSold,
    };
  }

  factory MarketItem.fromJson(Map<String, dynamic> json) {
    return MarketItem(
      id: json['id'] as String,
      title: json['title'] as String,
      price: json['price'] as double,
      description: json['description'] as String,
      sellerId: json['sellerId'] as String,
      sellerName: json['sellerName'] as String,
      imageUrl: json['imageUrl'] as String,
      communityId: json['communityId'] as String,
    );
  }
}
