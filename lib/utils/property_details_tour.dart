import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Class to manage the onboarding tour for property details
class PropertyDetailsTour {
  static const String _tourCompletedKey = 'property_details_tour_completed';
  
  // Feature IDs for different elements in the tour
  static const String photoGalleryFeature = 'photo_gallery_feature';
  static const String favoriteFeature = 'favorite_feature';
  static const String ratingFeature = 'rating_feature';
  static const String locationFeature = 'location_feature';
  static const String pdfFeature = 'pdf_feature';
  static const String distanceFeature = 'distance_feature';
  
  /// Initialize the tour
  static Future<void> initTour(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final tourCompleted = prefs.getBool(_tourCompletedKey) ?? false;
    
    if (!tourCompleted) {
      // Delay to ensure the UI has fully rendered
      await Future.delayed(const Duration(milliseconds: 500));
      
      try {
        FeatureDiscovery.discoverFeatures(
          context, 
          <String>[
            photoGalleryFeature,
            favoriteFeature,
            ratingFeature,
            locationFeature,
            pdfFeature,
            distanceFeature,
          ],
        );
        
        // Mark tour as completed
        await prefs.setBool(_tourCompletedKey, true);
      } catch (e) {
        print('FeatureDiscovery error: $e');
        // Fail gracefully, don't crash the app
      }
    }
  }
  
  /// Reset the tour so it will show again next time
  static Future<void> resetTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourCompletedKey, false);
  }
  
  /// Reset and show tour with error handling
  static Future<void> resetAndShowTour(BuildContext context) async {
    try {
      // First reset the tour
      await resetTour();
      
      // Then clear any feature preferences to ensure features are shown again
      await FeatureDiscovery.clearPreferences(
        context, 
        <String>[
          photoGalleryFeature,
          favoriteFeature,
          ratingFeature,
          locationFeature,
          pdfFeature,
          distanceFeature,
        ],
      );
      
      // Finally, show the tour
      await Future.delayed(const Duration(milliseconds: 300));
      FeatureDiscovery.discoverFeatures(
        context, 
        <String>[
          photoGalleryFeature,
          favoriteFeature,
          ratingFeature,
          locationFeature,
          pdfFeature,
          distanceFeature,
        ],
      );
    } catch (e) {
      print('Error showing property details tour: $e');
      // Fail gracefully, don't crash the app
    }
  }
  
  /// Check if the tour is completed
  static Future<bool> isTourCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tourCompletedKey) ?? false;
  }
} 