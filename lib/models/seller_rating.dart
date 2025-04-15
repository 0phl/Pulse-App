import 'package:cloud_firestore/cloud_firestore.dart';

class SellerRating {
  final String id;
  final String sellerId;
  final String buyerId;
  final String buyerName;
  final double rating;
  final String? comment;
  final DateTime createdAt;
  final String? marketItemId;

  SellerRating({
    required this.id,
    required this.sellerId,
    required this.buyerId,
    required this.buyerName,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.marketItemId,
  });

  factory SellerRating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SellerRating(
      id: doc.id,
      sellerId: data['sellerId'] ?? '',
      buyerId: data['buyerId'] ?? '',
      buyerName: data['buyerName'] ?? 'Anonymous',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      marketItemId: data['marketItemId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sellerId': sellerId,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
      'marketItemId': marketItemId,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'marketItemId': marketItemId,
    };
  }

  factory SellerRating.fromJson(Map<String, dynamic> json) {
    return SellerRating(
      id: json['id'] as String,
      sellerId: json['sellerId'] as String,
      buyerId: json['buyerId'] as String,
      buyerName: json['buyerName'] as String,
      rating: json['rating'] as double,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      marketItemId: json['marketItemId'] as String?,
    );
  }
}
