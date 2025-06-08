import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:homi/models/admin_user.dart';
import 'package:homi/models/property.dart';
import 'package:flutter/foundation.dart';

class PreloadService {
  static final PreloadService _instance = PreloadService._internal();
  factory PreloadService() => _instance;
  PreloadService._internal();

  bool _isPreloading = false;
  bool _isPreloaded = false;
  Map<String, dynamic> _preloadedData = {};

  bool get isPreloaded => _isPreloaded;
  Map<String, dynamic> get preloadedData => _preloadedData;

  Future<void> preloadHomePageData() async {
    if (_isPreloading || _isPreloaded) return;
    _isPreloading = true;

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;

      // Create a batch query for properties to reduce number of reads
      final propertiesQuery = FirebaseFirestore.instance
          .collection('properties')
          .orderBy('price')
          .limit(50); // Limit initial load to improve performance

      // Run multiple async operations in parallel with optimized queries
      final results = await Future.wait([
        // Check if user is admin (cached in AdminUser)
        AdminUser.isCurrentUserAdmin(),
        
        // Load favorite statuses if user is logged in
        if (user != null)
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('favorites')
              .get()
        else
          Future.value(null),
        
        // Load properties with optimized query
        propertiesQuery.get(),
      ]);

      // Process results
      final isAdmin = results[0] as bool;
      
      // Process favorites
      final Map<String, bool> favoriteStatus = {};
      if (user != null && results[1] != null) {
        final favorites = results[1] as QuerySnapshot;
        for (var doc in favorites.docs) {
          favoriteStatus[doc.id] = true;
        }
      }

      // Process properties for prices and locations
      final propertySnapshot = results[2] as QuerySnapshot;
      final prices = <double>[];
      final locations = <String>{};

      for (var doc in propertySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Extract price
        final price = (data['price'] as num?)?.toDouble();
        if (price != null) prices.add(price);
        
        // Extract location
        final location = data['location'] as String?;
        if (location != null && location.isNotEmpty) {
          locations.add(location);
        }
      }

      // Sort prices once
      prices.sort();
      final availablePrices = prices.isEmpty ? [0.0, 5000.0] : [prices.first, prices.last];

      // Store preloaded data
      _preloadedData = {
        'isAdmin': isAdmin,
        'favoriteStatus': favoriteStatus,
        'availablePrices': availablePrices,
        'locations': locations.toList(),
        'initialProperties': propertySnapshot.docs
            .map((doc) => Property.fromFirestore(doc))
            .toList(),
      };

      _isPreloaded = true;
    } catch (e) {
      debugPrint('Error preloading home page data: $e');
      _isPreloaded = true;
    } finally {
      _isPreloading = false;
    }
  }

  void reset() {
    _isPreloaded = false;
    _isPreloading = false;
    _preloadedData.clear();
  }
} 