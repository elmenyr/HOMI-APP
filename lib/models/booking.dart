import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  accepted,
  rejected,
  cancelled,
}

enum BookingType {
  entireApartment,
  privateRoom,
  sharedBed,
}

class Booking {
  final String id;
  final String userId;
  final String propertyId;
  final String userName;
  final String userPhone;
  final String? message;
  final BookingType type;
  final BookingStatus status;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime? acceptedAt;

  Booking({
    required this.id,
    required this.userId,
    required this.propertyId,
    required this.userName,
    required this.userPhone,
    this.message,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.startDate,
    this.acceptedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'propertyId': propertyId,
      'userName': userName,
      'userPhone': userPhone,
      'message': message,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'startDate': Timestamp.fromDate(startDate),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
    };
  }

  factory Booking.fromMap(Map<String, dynamic> map, String id) {
    return Booking(
      id: id,
      userId: map['userId'] as String,
      propertyId: map['propertyId'] as String,
      userName: map['userName'] as String,
      userPhone: map['userPhone'] as String,
      message: map['message'] as String?,
      type: BookingType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
      ),
      status: BookingStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      startDate: (map['startDate'] as Timestamp).toDate(),
      acceptedAt: map['acceptedAt'] != null
          ? (map['acceptedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
