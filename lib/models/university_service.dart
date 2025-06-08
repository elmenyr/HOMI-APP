import 'package:cloud_firestore/cloud_firestore.dart';

class UniversityService {
  final String id;
  final String name;
  final String category;
  final String location;
  final double rating;
  final String university;

  UniversityService({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.rating,
    required this.university,
  });

  factory UniversityService.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UniversityService(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      location: data['location']?.toString() ?? '',
      rating: (data['rating'] is num ? (data['rating'] as num).toDouble() : 0.0),
      university: data['university']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'location': location,
      'rating': rating,
      'university': university,
    };
  }

  static Stream<List<UniversityService>> getServices({
    String? university,
    String? category,
    String searchQuery = '',
  }) {
    Query query = FirebaseFirestore.instance.collection('services');

    if (university != null) {
      query = query.where('university', isEqualTo: university);
    }

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UniversityService.fromFirestore(doc))
          .where((service) => searchQuery.isEmpty ||
              service.name.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    });
  }
}