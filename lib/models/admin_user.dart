import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminUser {
  final String id;
  final String name;
  final String email;
  final bool isAdmin;
  final DateTime createdAt;

  static const List<String> adminEmails = [
    'elmounier@admin.com',
    'atef@admin.com',
    'mnyr@gmail.com',
    'elmaghraby@admin.com',
    'oelmenayr@gmail.com'
  ];

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isAdmin,
    required this.createdAt,
  });

  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminUser(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      isAdmin: data['isAdmin'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'isAdmin': isAdmin,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static Future<AdminUser?> getCurrentAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('admins')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;
    return AdminUser.fromFirestore(doc);
  }

  static Future<bool> isCurrentUserAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check if user's email is in the predefined admin emails list
      if (adminEmails.contains(user.email)) {
        return true;
      }

      // Check if user exists in admins collection
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();

      if (adminDoc.exists) {
        return true;
      }

      return false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }
}
