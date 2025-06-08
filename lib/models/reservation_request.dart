import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationRequest {
  final String id;
  final String userId;
  final String name;
  final int beds;
  final double expectedPrice;
  final String propertyType;
  final String location;
  final String tenantPhone;
  final String gender;
  final DateTime createdAt;
  final String status; // 'pending', 'approved', 'rejected'
  final String propertyId; // ID of the property this request is for

  ReservationRequest({
    required this.id,
    required this.userId,
    required this.name,
    required this.beds,
    required this.expectedPrice,
    required this.propertyType,
    required this.location,
    required this.tenantPhone,
    required this.gender,
    required this.createdAt,
    this.status = 'pending',
    this.propertyId = '',
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'beds': beds,
      'expectedPrice': expectedPrice,
      'propertyType': propertyType,
      'location': location,
      'tenantPhone': tenantPhone,
      'gender': gender,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'propertyId': propertyId,
    };
  }

  factory ReservationRequest.fromFirestore(Map<String, dynamic> data) {
    return ReservationRequest(
      id: data['id'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      beds: (data['beds'] as num?)?.toInt() ?? 0,
      expectedPrice: (data['expectedPrice'] as num?)?.toDouble() ?? 0.0,
      propertyType: data['propertyType'] as String? ?? '',
      location: data['location'] as String? ?? '',
      tenantPhone: data['tenantPhone'] as String? ?? '',
      gender: data['gender'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'pending',
      propertyId: data['propertyId'] as String? ?? '',
    );
  }
}