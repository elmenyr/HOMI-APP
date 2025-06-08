import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Accept a booking request
  Future<void> acceptBooking(String bookingId) async {
    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final propertyRef = _firestore.collection('properties');

    try {
      // Get the booking details
      final bookingDoc = await bookingRef.get();
      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final booking = Booking.fromMap(
        bookingDoc.data() as Map<String, dynamic>,
        bookingDoc.id,
      );

      // Start a batch write
      final batch = _firestore.batch();

      // Update booking status
      batch.update(bookingRef, {
        'status': BookingStatus.accepted.toString().split('.').last,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Update property with tenant information
      final propertyDoc = await propertyRef.doc(booking.propertyId).get();
      if (!propertyDoc.exists) {
        throw Exception('Property not found');
      }

      // Add tenant to property
      batch.update(propertyRef.doc(booking.propertyId), {
        'tenants': FieldValue.arrayUnion([
          {
            'userId': booking.userId,
            'name': booking.userName,
            'phone': booking.userPhone,
            'bookingType': booking.type.toString().split('.').last,
            'startDate': booking.startDate,
            'bookingId': booking.id,
          }
        ]),
        'availableUnits': FieldValue.increment(-1), // Decrease available units
      });

      // Update user's profile with property information
      final userRef = _firestore.collection('users').doc(booking.userId);
      batch.update(userRef, {
        'currentResidence': {
          'propertyId': booking.propertyId,
          'bookingId': booking.id,
          'bookingType': booking.type.toString().split('.').last,
          'startDate': booking.startDate,
        },
      });

      // Create a notification
      final notificationRef = _firestore.collection('notifications').doc();
      batch.set(notificationRef, {
        'userId': booking.userId,
        'title': 'Booking Accepted!',
        'message': 'Your booking has been accepted. Welcome to your new place!',
        'type': 'booking_accepted',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'bookingId': booking.id,
          'propertyId': booking.propertyId,
        },
      });

      // Commit the batch
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to accept booking: $e');
    }
  }

  // Get user's current residence details
  Future<Map<String, dynamic>?> getCurrentResidence() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      final currentResidence =
          userData['currentResidence'] as Map<String, dynamic>?;

      if (currentResidence != null) {
        // Get property details
        final propertyDoc = await _firestore
            .collection('properties')
            .doc(currentResidence['propertyId'] as String)
            .get();

        if (propertyDoc.exists) {
          final propertyData = propertyDoc.data() as Map<String, dynamic>;
          return {
            ...currentResidence,
            'property': propertyData,
          };
        }
      }

      return null;
    } catch (e) {
      throw Exception('Failed to get current residence: $e');
    }
  }

  // Get all bookings for a property
  Stream<List<Booking>> getPropertyBookings(String propertyId) {
    return _firestore
        .collection('bookings')
        .where('propertyId', isEqualTo: propertyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Booking.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get user's bookings
  Stream<List<Booking>> getUserBookings() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Booking.fromMap(doc.data(), doc.id))
            .toList());
  }
}
