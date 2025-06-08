import 'package:cloud_firestore/cloud_firestore.dart';

class PropertyRequest {
  final String id;
  final String userId;
  final String title;
  final double price;
  final String location;
  final String imageUrl;
  final int bedrooms;
  final int bathrooms;
  final bool airCond;
  final String description;
  final String type;
  final String gender;
  final DateTime createdAt;
  final String agentPhone;
  final double latitude;
  final double longitude;
  final bool isAvailable;
  final bool hasWifi;
  final int hasInsurance;
  final String? vrTourUrl;
  final String status; // 'pending', 'approved', 'rejected'

  PropertyRequest({
    required this.id,
    required this.userId,
    required this.title,
    required this.price,
    required this.location,
    required this.imageUrl,
    required this.bedrooms,
    required this.bathrooms,
    required this.airCond,
    required this.description,
    required this.type,
    required this.gender,
    required this.createdAt,
    required this.agentPhone,
    required this.latitude,
    required this.longitude,
    required this.isAvailable,
    required this.hasWifi,
    required this.hasInsurance,
    this.vrTourUrl,
    required this.status,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'price': price,
      'location': location,
      'imageUrl': imageUrl,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'airCond': airCond,
      'description': description,
      'type': type,
      'gender': gender,
      'createdAt': Timestamp.fromDate(createdAt),
      'agentPhone': agentPhone,
      'latitude': latitude,
      'longitude': longitude,
      'isAvailable': isAvailable,
      'hasWifi': hasWifi,
      'hasInsurance': hasInsurance,
      'vrTourUrl': vrTourUrl,
      'status': status,
    };
  }

  factory PropertyRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PropertyRequest(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      price: (data['price'] is num ? (data['price'] as num).toDouble() : 0.0),
      location: data['location']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      bedrooms: (data['bedrooms'] is num ? (data['bedrooms'] as num).toInt() : 0),
      bathrooms: (data['bathrooms'] is num ? (data['bathrooms'] as num).toInt() : 0),
      airCond: data['airCond'] as bool? ?? false,
      description: data['description']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      gender: data['gender']?.toString() ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      agentPhone: data['agentPhone']?.toString() ?? '',
      latitude: (data['latitude'] is num ? (data['latitude'] as num).toDouble() : 0.0),
      longitude: (data['longitude'] is num ? (data['longitude'] as num).toDouble() : 0.0),
      isAvailable: data['isAvailable'] as bool? ?? true,
      hasWifi: data['hasWifi'] as bool? ?? false,
      hasInsurance: (data['hasInsurance'] is num ? (data['hasInsurance'] as num).toInt() : 0),
      vrTourUrl: data['vrTourUrl']?.toString(),
      status: data['status']?.toString() ?? 'pending',
    );
  }
}