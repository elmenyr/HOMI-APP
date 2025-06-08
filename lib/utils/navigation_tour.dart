import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Class to manage the onboarding tour for navigation buttons
class NavigationTour {
  static const String _tourCompletedKey = 'navigation_tour_completed';
  
  // Feature IDs for different elements in the tour
  static const String homeFeature = 'home_feature';
  static const String favoritesFeature = 'favorites_feature';
  static const String chatbotFeature = 'chatbot_feature';
  static const String requestFeature = 'request_feature';
  static const String agentsFeature = 'agents_feature';
  static const String servicesFeature = 'services_feature';
  static const String settingsFeature = 'settings_feature';
  static const String vrTourFeature = 'vr_tour_feature';
  
  // Admin-specific features
  static const String bookedRequestsFeature = 'booked_requests_feature';
  static const String serviceProvidersFeature = 'service_providers_feature';
  
  /// Initialize the tour
  static Future<void> initTour(BuildContext context, bool isAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    final tourCompleted = prefs.getBool(_tourCompletedKey) ?? false;
    
    // Only show for first-time users (when tourCompleted is false)
    if (!tourCompleted) {
      // Delay to ensure the UI has fully rendered
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Show Chatbot, Services, and VR tour features (removed request feature)
      final features = <String>[
        chatbotFeature,
        servicesFeature,
        vrTourFeature,
      ];

      // Clear any existing feature preferences to ensure fresh start
      await FeatureDiscovery.clearPreferences(context, features);
      
      // Start the tour
      FeatureDiscovery.discoverFeatures(
        context,
        features,
      );
      
      // Mark tour as completed so it never shows again
      await prefs.setBool(_tourCompletedKey, true);
    }
  }
  
  /// Reset the tour and immediately show it (for testing or manual trigger only)
  static Future<void> resetAndShowTour(BuildContext context, bool isAdmin) async {
    // First reset the tour
    await resetTour();
    
    // Only include Chatbot, Services, and VR tour features (removed request feature)
    final features = <String>[
      chatbotFeature,
      servicesFeature,
      vrTourFeature,
    ];
    
    // Clear any feature preferences to ensure features are shown again
    await FeatureDiscovery.clearPreferences(context, features);
    
    // Start the tour
    await initTour(context, isAdmin);
  }
  
  /// Reset the tour so it will show again next time (for testing purposes only)
  static Future<void> resetTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourCompletedKey, false);
  }
  
  /// Check if the tour is completed
  static Future<bool> isTourCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tourCompletedKey) ?? false;
  }
  
  /// Set flag to force show the tour on next initTour call (removed as no longer needed)
  static Future<void> forceShowOnNextInit() async {
    // This method is kept for compatibility but does nothing now
    // as we want the tour to show only on first use
  }
  
  // Example usage for nav bar tour overlay customization
  // To apply a black background to all nav bar tour steps, set default values in the DescribedFeatureOverlay widget

  // If you use DescribedFeatureOverlay for navigation bar items, set:
  // backgroundColor: Colors.black,
  // textColor: Colors.white,
  // targetColor: Colors.white,
  // barrierColor: Colors.black.withOpacity(0.8),

  // If you have a helper function that builds nav bar tour steps, add these parameters there as well.
} 