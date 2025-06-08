import 'dart:math';
import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homi/models/admin_user.dart';
import 'package:homi/models/property.dart';
import 'package:homi/pages/add_property_page.dart';
import 'package:homi/pages/property_details_page.dart';
import 'package:homi/pages/vr_tour_page.dart';
import 'package:homi/pages/map_page.dart';
import 'package:homi/pages/reservation_form_page.dart';
import 'package:homi/providers/language_provider.dart';
import 'package:homi/utils/navigation_tour.dart';
import 'package:homi/widgets/admin_drawer.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:homi/services/preload_service.dart';

// Constants for styling and configuration
class HomePageStyles {
  // Spacing
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double extraLargePadding = 40.0;

  // Sizes
  static const double iconSize = 20.0;
  static const double smallIconSize = 16.0;
  static const double microIconSize = 10.0;
  static const double logoSize = 30.0;
  static const double propertyImageHeight = 200.0;

  // Border radius
  static const double borderRadius = 12.0;
  static const double largeBorderRadius = 16.0;
  static const double smallBorderRadius = 10.0;

  // Typography
  static const String fontFamily = 'Montserrat';
  static const double titleFontSize = 18.0;
  static const double bodyFontSize = 16.0;
  static const double smallFontSize = 14.0;
  static const double microFontSize = 10.0;
  static const double priceFontSize = 16.0;

  // Colors
  static final Color primaryColor = Colors.grey.shade800;
  static final Color backgroundColor = Colors.white;
  static final Color surfaceColor = Colors.grey.shade200;
  static final Color borderColor = Colors.grey.shade300;
  static final Color textPrimaryColor = Colors.black87;
  static final Color textSecondaryColor = Colors.grey.shade600;
  static const Color availableColor = Colors.green;
  static final Color unavailableColor = Colors.red.shade600;
  static const Color accentColor = Colors.amber;
  static const Color favoriteColor = Colors.red;

  // Animation
  static const Duration animationDuration = Duration(milliseconds: 1500);
  static const Duration refreshDelay = Duration(milliseconds: 800);

  // Brand Colors
  static const Color logoRoofBaseColor = Color(0xFFF17575);
  static const Color logoRoofHighlightColor = Color(0xFFFFA0A0);
  static const Color logoBushBaseColor = Color(0xFFCEE26B);
  static const Color logoBushHighlightColor = Color(0xFFDDEEA0);
}

// Stream controller for favorite updates
final StreamController<String> favoriteUpdateController =
    StreamController<String>.broadcast();

/// Service class to handle property-related data operations
class PropertyService {
  static final PropertyService _instance = PropertyService._internal();
  factory PropertyService() => _instance;
  PropertyService._internal();

  // Flag to track whether we're currently refreshing data
  bool _isRefreshing = false;

  /// Get a filtered stream of properties based on filter criteria
  Stream<QuerySnapshot> getFilteredPropertiesStream({
    String? location,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    bool sortAscending = true,
  }) {
    // Start with the base query
    Query query = FirebaseFirestore.instance.collection('properties');

    // Apply location filter if specified
    if (location != null) {
      query = query.where('location', isEqualTo: location);
    }

    // Apply price range filter if selected
    if (minPrice != null) {
      query = query.where('price', isGreaterThanOrEqualTo: minPrice);
    }
    if (maxPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: maxPrice);
    }

    // Apply sorting
    switch (sortBy?.toLowerCase() ?? 'price') {
      case 'price':
        query = query.orderBy('price', descending: !sortAscending);
        break;
      case 'date':
        query = query.orderBy('createdAt', descending: !sortAscending);
        break;
      default:
        // Default sorting by price
        query = query.orderBy('price');
    }

    return query.snapshots();
  }

  /// Filter properties client-side with additional criteria
  List<Property> applyClientSideFilters(
    List<Property> properties, {
    String? searchQuery,
    String? idSearchQuery,
  }) {
    // Debug print active filters
    debugPrint(
        'Applied filters: searchQuery=$searchQuery, idSearchQuery=$idSearchQuery');

    return properties.where((property) {
      // Apply text search
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final searchLower = searchQuery.toLowerCase();
        if (!property.title.toLowerCase().contains(searchLower) &&
            !property.location.toLowerCase().contains(searchLower)) {
          return false;
        }
      }

      // Apply ID search for admin
      if (idSearchQuery != null &&
          idSearchQuery.isNotEmpty &&
          !property.id.contains(idSearchQuery)) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Apply client-side sorting by rating
  List<Property> applyClientSideSorting(
    List<Property> properties, {
    String? sortBy,
    bool sortAscending = true,
  }) {
    if (sortBy?.toLowerCase() == 'rating') {
      properties.sort((a, b) => sortAscending
          ? a.rating.compareTo(b.rating)
          : b.rating.compareTo(a.rating));
    }
    return properties;
  }

  /// Load user's favorite properties
  Future<Map<String, bool>> loadFavoriteStatuses(String? userId) async {
    if (userId == null) return {};

    try {
      final favorites = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();

      final Map<String, bool> favoriteStatus = {};
      for (var doc in favorites.docs) {
        favoriteStatus[doc.id] = true;
      }
      return favoriteStatus;
    } catch (e) {
      debugPrint('Error loading favorite statuses: $e');
      return {};
    }
  }

  /// Toggle favorite status for a property
  Future<bool> toggleFavorite(
      String propertyId, Property property, String? userId) async {
    if (userId == null) return false;

    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      final favoriteRef = userRef.collection('favorites').doc(propertyId);
      final isFavorite = await isFavorited(propertyId, userId);

      if (isFavorite) {
        await favoriteRef.delete();
      } else {
        // Store all property data including images
        final propertyData = property.toFirestore();
        // Ensure main image is included
        if (!propertyData.containsKey('imageUrl') ||
            propertyData['imageUrl'] == null) {
          propertyData['imageUrl'] = property.imageUrl;
        }
        // Ensure all images are included
        if (!propertyData.containsKey('photos') ||
            propertyData['photos'] == null) {
          propertyData['photos'] = property.photos;
        }
        if (!propertyData.containsKey('images') ||
            propertyData['images'] == null) {
          propertyData['images'] = property.images;
        }
        await favoriteRef.set(propertyData);
      }

      // Notify other parts of the app about the change
      favoriteUpdateController.add(propertyId);
      return !isFavorite;
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      return false;
    }
  }

  /// Check if a property is favorited
  Future<bool> isFavorited(String propertyId, String? userId) async {
    if (userId == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(propertyId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
      return false;
    }
  }

  /// Load available locations from Firestore
  Future<List<String>> loadLocations() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('properties').get();

      if (snapshot.docs.isEmpty) return [];

      final locations = snapshot.docs
          .map((doc) => doc.data()['location'] as String)
          .where((location) => location.isNotEmpty)
          .toSet() // Remove duplicates
          .toList();

      return locations;
    } catch (e) {
      debugPrint('Error loading locations: $e');
      return [];
    }
  }

  /// Load the available price range from Firestore
  Future<List<double>> loadAvailablePrices() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('properties')
          .orderBy('price')
          .get();

      if (snapshot.docs.isEmpty) return [0, 5000];

      final prices = snapshot.docs
          .map((doc) => (doc.data()['price'] as num).toDouble())
          .toList();

      return [prices.first, prices.last];
    } catch (e) {
      debugPrint('Error loading available prices: $e');
      return [0, 5000];
    }
  }

  /// Clear image cache for proper refresh
  Future<void> refreshImageCache() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    try {
      // Clear only the default cache, not persistent storage
      await DefaultCacheManager().emptyCache();
    } catch (e) {
      debugPrint('Error refreshing image cache: $e');
    } finally {
      _isRefreshing = false;
    }
  }
}

/// Manages filter state for the property listings
class PropertyFilterManager {
  // Filter values
  String? location;
  double? minPrice;
  double? maxPrice;
  String sortBy = 'price';
  bool sortAscending = true;
  String searchQuery = '';
  String idSearchQuery = '';

  // Available values
  List<String> availableLocations = [];
  List<double> availablePrices = [0, 5000];
  double minPriceLimit = 0;
  double maxPriceLimit = 5000;

  // Reset all filters to default values
  void reset() {
    location = null;
    minPrice = null;
    maxPrice = null;
    sortBy = 'price';
    sortAscending = true;
    searchQuery = '';
    idSearchQuery = '';
  }

  // Update available price range
  void updatePriceRange(List<double> prices) {
    if (prices.length >= 2) {
      availablePrices = prices;
      minPriceLimit = prices[0];
      maxPriceLimit = prices[1];
    }
  }
}

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage>
    with AutomaticKeepAliveClientMixin {
  // Services
  final _propertyService = PropertyService();

  // User and authentication
  bool _isAdmin = false;
  final _user = FirebaseAuth.instance.currentUser;
  Map<String, bool> _favoriteStatus = {};

  // UI and navigation
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Property filter values
  List<double> _availablePrices = [0, 5000]; // Default price range
  double _minPrice = 0;
  double _maxPrice = 5000;

  // Property type and gender options
  final List<String> _propertyTypeKeys = ['apartment', 'studio'];

  String? _selectedPropertyTypeKey;

  // Loading states
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _dataInitialized = false; // Track if data has been initialized
  static bool _hasInitializedOnce =
      false; // Static flag to ensure one-time initialization

  // Add this after the service declaration
  final _filterManager = PropertyFilterManager();

  // Flag to control when images should be refreshed from network
  bool _shouldRefreshImages = false;

  // Stream optimization to prevent rebuilding the stream unnecessarily
  Stream<QuerySnapshot>? _currentFilteredStream;
  Map<String, dynamic>? _lastFilterParams;

  @override
  void initState() {
    super.initState();

    // Check if data is already preloaded
    final preloadService = PreloadService();
    if (preloadService.isPreloaded) {
      // Use preloaded data
      final data = preloadService.preloadedData;
      setState(() {
        _isAdmin = data['isAdmin'] as bool;
        _favoriteStatus = Map<String, bool>.from(
            data['favoriteStatus'] as Map<String, dynamic>);
        _availablePrices = List<double>.from(data['availablePrices'] as List);
        _minPrice = _availablePrices.isNotEmpty ? _availablePrices[0] : 0;
        _maxPrice = _availablePrices.length > 1 ? _availablePrices[1] : 5000;
        _locations = List<String>.from(data['locations'] as List);
        _filterManager.availableLocations = _locations;
        _filterManager.updatePriceRange(_availablePrices);
        _isLoading = false;
        _dataInitialized = true;
      });
    } else if (!_hasInitializedOnce) {
      _initializeData();
      _hasInitializedOnce = true;
    } else if (_isLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Initialize all data needed for the home page
  Future<void> _initializeData() async {
    if (_dataInitialized) return; // Skip if data is already initialized

    setState(() => _isLoading = true);

    try {
      // Load data in parallel
      final results = await Future.wait([
        AdminUser.isCurrentUserAdmin(),
        _propertyService.loadFavoriteStatuses(_user?.uid),
        _propertyService.loadAvailablePrices(),
        _propertyService.loadLocations(),
      ]);

      if (mounted) {
        setState(() {
          _isAdmin = results[0] as bool;
          _favoriteStatus = results[1] as Map<String, bool>;

          // Update filter manager
          _filterManager.updatePriceRange(results[2] as List<double>);
          _filterManager.availableLocations = results[3] as List<String>;

          // Also update old variables for compatibility
          _availablePrices = results[2] as List<double>;
          _minPrice = _availablePrices.isNotEmpty ? _availablePrices[0] : 0;
          _maxPrice = _availablePrices.length > 1 ? _availablePrices[1] : 5000;
          _locations = results[3] as List<String>;

          _isLoading = false;
          _dataInitialized = true; // Mark data as initialized
        });
      }
    } catch (e) {
      debugPrint('Error initializing data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Toggle favorite status for a property
  Future<void> _toggleFavorite(String propertyId, Property property) async {
    if (_user == null) {
      _showLoginRequiredMessage();
      return;
    }

    // Optimistically update UI for better responsiveness
    setState(() {
      _favoriteStatus[propertyId] = !(_favoriteStatus[propertyId] ?? false);
    });

    try {
      final isFavorite = await _propertyService.toggleFavorite(
          propertyId, property, _user?.uid);

      // Update UI if the result is different from our optimistic update
      if (mounted && isFavorite != _favoriteStatus[propertyId]) {
        setState(() {
          _favoriteStatus[propertyId] = isFavorite;
        });
      }
    } catch (e) {
      // Revert UI state if operation failed
      if (mounted) {
        setState(() {
          _favoriteStatus[propertyId] = !(_favoriteStatus[propertyId] ?? false);
        });
        _showFavoriteUpdateError(e);
      }
    }
  }

  // Show message when user is not logged in
  void _showLoginRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)!.loginToSaveFavorites)),
    );
  }

  // Show error message when favorite update fails
  void _showFavoriteUpdateError(dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${AppLocalizations.of(context)!.favoriteUpdateFailed}: $error')),
    );
  }

  // Filter variables
  String? _selectedLocation;
  int? _selectedBedrooms;
  int? _selectedBathrooms;
  String? _selectedType;
  bool? _selectedAirCond;
  bool? _selectedWifi;
  int? _selectedInsurance;
  double? _selectedMinPrice;
  double? _selectedMaxPrice;
  double? _selectedMinRating;
  String _sortBy = 'price';
  bool _sortAscending = true;
  String _searchQuery = '';
  String _idSearchQuery = '';
  List<String> _locations = [];

  @override
  bool get wantKeepAlive => true;

  Widget _buildPriceRangeChip(String label, double? min, double? max) {
    final isSelected =
        _filterManager.minPrice == min && _filterManager.maxPrice == max;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[800],
            fontFamily: 'Montserrat',
          ),
        ),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            if (selected) {
              _filterManager.minPrice = min;
              _filterManager.maxPrice = max;
            } else {
              _filterManager.minPrice = null;
              _filterManager.maxPrice = null;
            }
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.grey[800],
        checkmarkColor: Colors.white,
      ),
    );
  }

  Widget _buildPriceRangeSection(StateSetter setDialogState) {
    return _buildFilterSection(
      'Price Range',
      Icons.attach_money,
      child: Column(
        children: [
          RangeSlider(
            values: RangeValues(
              _filterManager.minPrice ?? _filterManager.minPriceLimit,
              _filterManager.maxPrice ?? _filterManager.maxPriceLimit,
            ),
            min: _filterManager.minPriceLimit,
            max: _filterManager.maxPriceLimit,
            divisions: 100,
            labels: RangeLabels(
              'EGP ${(_filterManager.minPrice ?? _filterManager.minPriceLimit).round()}',
              'EGP ${(_filterManager.maxPrice ?? _filterManager.maxPriceLimit).round()}',
            ),
            onChanged: (values) {
              setDialogState(() {
                _filterManager.minPrice = values.start;
                _filterManager.maxPrice = values.end;
              });
            },
            activeColor: Colors.grey[800],
            inactiveColor: Colors.grey[300],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPriceRangeChip('Any', null, null),
                _buildPriceRangeChip('< 500', null, 500),
                _buildPriceRangeChip('500-1000', 500, 1000),
                _buildPriceRangeChip('1000-2000', 1000, 2000),
                _buildPriceRangeChip('> 2000', 2000, null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> getFilteredStream() {
    // Create a key based on current filter params
    final filterParams = {
      'location': _filterManager.location,
      'minPrice': _filterManager.minPrice,
      'maxPrice': _filterManager.maxPrice,
      'sortBy': _filterManager.sortBy,
      'sortAscending': _filterManager.sortAscending,
    };

    // Only create a new stream if filter params have changed
    if (_currentFilteredStream == null ||
        _lastFilterParams.toString() != filterParams.toString()) {
      _lastFilterParams = filterParams;
      _currentFilteredStream = _propertyService.getFilteredPropertiesStream(
        location: _filterManager.location,
        minPrice: _filterManager.minPrice,
        maxPrice: _filterManager.maxPrice,
        sortBy: _filterManager.sortBy,
        sortAscending: _filterManager.sortAscending,
      );
    }

    return _currentFilteredStream!;
  }

  List<Property> applyClientSideFilters(List<Property> properties) {
    // Apply only our simplified filters
    return _propertyService.applyClientSideFilters(
      properties,
      searchQuery: _filterManager.searchQuery,
      idSearchQuery: _isAdmin ? _filterManager.idSearchQuery : null,
    );
  }

  List<Property> applyClientSideSorting(List<Property> properties) {
    return _propertyService.applyClientSideSorting(
      properties,
      sortBy: _filterManager.sortBy,
      sortAscending: _filterManager.sortAscending,
    );
  }

  void _showSelectionDialog({
    required BuildContext dialogContext,
    required String title,
    required List<String> options,
    required Function(String) onSelected,
    required String? currentValue,
  }) {
    showModalBottomSheet(
      context: dialogContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = option == currentValue;
                return FadeInUp(
                  delay: Duration(milliseconds: 100 * index),
                  child: ListTile(
                    onTap: () {
                      onSelected(option);
                      Navigator.pop(context);
                    },
                    title: Text(
                      option,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.grey.shade800
                            : Colors.grey.shade600,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Color(0xFF616161),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showNumberSelectionDialog({
    required BuildContext dialogContext,
    required String title,
    required int maxValue,
    required Function(int) onSelected,
    required int? currentValue,
  }) {
    showModalBottomSheet(
      context: dialogContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: maxValue,
              itemBuilder: (context, index) {
                final value = index + 1;
                final isSelected = value == currentValue;
                return FadeInUp(
                  delay: Duration(milliseconds: 100 * index),
                  child: ListTile(
                    onTap: () {
                      onSelected(value);
                      Navigator.pop(context);
                    },
                    title: Text(
                      '$value+',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.grey.shade800
                            : Colors.grey.shade600,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Color(0xFF616161),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _getLocalizedPropertyType(AppLocalizations l10n, String? key) {
    if (key == null) return l10n.propertyType.toString();
    switch (key) {
      case 'apartment':
        return l10n.apartment.toString();
      case 'studio':
        return l10n.studio.toString();
      default:
        return key;
    }
  }

  void _showAdvancedFilterDialog() {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Text(
                l10n.advancedFilters.toString(),
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.sort),
                onPressed: () {
                  showModalBottomSheet(
                    context: dialogContext,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            l10n.sortBy.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ),
                        ...[l10n.price.toString(), l10n.rating.toString()]
                            .map((String option) {
                          final isSelected =
                              _filterManager.sortBy.toLowerCase() ==
                                  option.toLowerCase();
                          return ListTile(
                            title: Text(option),
                            trailing: isSelected
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          _filterManager.sortAscending
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward,
                                          color: Colors.grey[800],
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            _filterManager.sortAscending =
                                                !_filterManager.sortAscending;
                                          });
                                          Navigator.pop(context);
                                        },
                                      ),
                                      const Icon(Icons.check,
                                          color: Colors.grey),
                                    ],
                                  )
                                : null,
                            onTap: () {
                              setDialogState(() {
                                _filterManager.sortBy = option;
                              });
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location Section
                if (_filterManager.availableLocations.isNotEmpty)
                  _buildFilterSection(
                    l10n.location,
                    Icons.location_on,
                    child: InkWell(
                      onTap: () => _showSelectionDialog(
                        dialogContext: dialogContext,
                        title: l10n.selectLocation,
                        options: _filterManager.availableLocations,
                        onSelected: (value) => setDialogState(
                            () => _filterManager.location = value),
                        currentValue: _filterManager.location,
                      ),
                      child: _buildFilterOption(
                        _filterManager.location ?? l10n.selectLocation,
                        _filterManager.location != null,
                      ),
                    ),
                  ),

                // Price Range Section
                _buildPriceRangeSection(setDialogState),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  _filterManager.reset();
                });
              },
              child: Text(
                l10n.reset,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {});
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                l10n.apply,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, IconData icon,
      {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[800]),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
        ),
        child,
        const Divider(height: 24),
      ],
    );
  }

  Widget _buildFilterOption(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? Colors.grey.shade100 : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.black87 : Colors.grey.shade600,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          Icon(Icons.arrow_drop_down, color: Colors.grey[800]),
        ],
      ),
    );
  }

  // Update the refresh method to avoid unnecessary refreshes
  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      // Refresh cached data
      await _propertyService.refreshImageCache();

      // Only reload data if needed
      if (!_dataInitialized) {
        await _initializeData();
      } else {
        // Just update favorite statuses which might have changed
        final favoriteStatuses =
            await _propertyService.loadFavoriteStatuses(_user?.uid);
        if (mounted) {
          setState(() {
            _favoriteStatus = favoriteStatuses;
          });
        }
      }

      setState(() {
        _shouldRefreshImages = true;
      });

      // Reset refresh flags after a short delay
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _shouldRefreshImages = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing data: $e');
      if (mounted) {
        setState(() {
          _shouldRefreshImages = false;
          _isRefreshing = false;
        });
      }
    }
  }

  // Create a PageStorageBucket for the home page
  static final PageStorageBucket _homePageBucket = PageStorageBucket();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);

    return PageStorage(
      bucket: _homePageBucket,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        drawer: _isAdmin ? const AdminDrawer() : null,
        floatingActionButton: _isAdmin
            ? FloatingActionButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AddPropertyPage()),
                  );

                  // If property was added or edited, refresh data
                  if (result == true && mounted) {
                    _refreshData();
                  }
                },
                backgroundColor: Colors.grey.shade800,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refreshData,
              color: Colors.grey.shade800,
              backgroundColor: Colors.white,
              strokeWidth: 3.0,
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.grey.shade800),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Header with logo and search bar
                        Container(
                          padding: const EdgeInsets.only(
                              top: 40, left: 16, right: 16, bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (_isAdmin)
                                    IconButton(
                                      icon: const Icon(Icons.menu,
                                          color: Colors.black),
                                      onPressed: () => _scaffoldKey.currentState
                                          ?.openDrawer(),
                                    ),
                                  Image.asset(
                                    'assets/images/home.png',
                                    width: 30,
                                    height: 30,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 4),
                                  Row(
                                    children: [
                                      Row(
                                        children: [
                                          // HO with coral/salmon pink gradient to match logo roof
                                          Shimmer.fromColors(
                                            baseColor: const Color(
                                                0xFFF17575), // Darker salmon pink
                                            highlightColor: const Color(
                                                0xFFFFA0A0), // Lighter salmon pink
                                            period: const Duration(
                                                milliseconds: 1500),
                                            child: ShaderMask(
                                              shaderCallback: (Rect bounds) {
                                                return const LinearGradient(
                                                  colors: [
                                                    Color(
                                                        0xFFF17575), // Darker salmon pink
                                                    Color(
                                                        0xFFFFA0A0), // Lighter salmon pink
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ).createShader(bounds);
                                              },
                                              child: GestureDetector(
                                                // Remove debug ad timer reset functionality
                                                child: const Text(
                                                  'HO',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontFamily: 'Montserrat',
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // MI with light green gradient to match logo bushes
                                          Shimmer.fromColors(
                                            baseColor: const Color(
                                                0xFFCEE26B), // Darker lime green
                                            highlightColor: const Color(
                                                0xFFDDEEA0), // Lighter lime green
                                            period: const Duration(
                                                milliseconds: 1500),
                                            child: ShaderMask(
                                              shaderCallback: (Rect bounds) {
                                                return const LinearGradient(
                                                  colors: [
                                                    Color(
                                                        0xFFCEE26B), // Darker lime green
                                                    Color(
                                                        0xFFDDEEA0), // Lighter lime green
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ).createShader(bounds);
                                              },
                                              child: const Text(
                                                'MI',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontFamily: 'Montserrat',
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  // Replace filter icon with logo that navigates to reservation form
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ReservationFormPage(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color.fromARGB(
                                            255, 255, 255, 255),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color.fromARGB(
                                                    255, 255, 255, 255)
                                                .withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Image.asset(
                                        'assets/images/req.png',
                                        width: 28,
                                        height: 28,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Icon(
                                            Iconsax.pen_add,
                                            size: 24,
                                            color: Colors.grey.shade800,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                onChanged: (value) => setState(
                                    () => _filterManager.searchQuery = value),
                                decoration: InputDecoration(
                                  hintText: l10n.search,
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                    fontFamily: 'Montserrat',
                                  ),
                                  prefixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.filter_list,
                                            color: Colors.grey),
                                        onPressed: _showAdvancedFilterDialog,
                                        tooltip: l10n.advancedFilters,
                                      ),
                                      const Icon(Iconsax.search_normal,
                                          color: Colors.grey),
                                    ],
                                  ),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_filterManager
                                              .searchQuery.isNotEmpty ||
                                          _filterManager.location != null ||
                                          _filterManager.minPrice != null ||
                                          _filterManager.maxPrice != null)
                                        IconButton(
                                          icon: const Icon(Icons.clear,
                                              color: Colors.grey),
                                          onPressed: () {
                                            setState(() {
                                              _filterManager.reset();
                                            });
                                          },
                                          tooltip: l10n.reset,
                                        ),
                                      if (_isAdmin)
                                        SizedBox(
                                          width: 100,
                                          child: TextField(
                                            onChanged: (value) => setState(() =>
                                                _filterManager.idSearchQuery =
                                                    value),
                                            decoration: InputDecoration(
                                              hintText: l10n.propId,
                                              hintStyle: const TextStyle(
                                                color: Colors.grey,
                                                fontFamily: 'Montserrat',
                                              ),
                                              border: InputBorder.none,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontFamily: 'Montserrat',
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade200,
                                ),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Property List
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: getFilteredStream(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(
                                  child:
                                      Text('${l10n.error}: ${snapshot.error}'),
                                );
                              }

                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !snapshot.hasData &&
                                  !_dataInitialized) {
                                return const SizedBox
                                    .shrink(); // Hide the second loading indicator
                              }

                              var properties = snapshot.data?.docs
                                      .map((doc) => Property.fromFirestore(doc))
                                      .toList() ??
                                  [];

                              // Debug logging
                              debugPrint(
                                  'Properties before filtering: ${properties.length}');

                              properties = applyClientSideFilters(properties);

                              // Debug logging
                              debugPrint(
                                  'Properties after client-side filtering: ${properties.length}');

                              properties = applyClientSideSorting(properties);

                              // Don't show empty state during initial load or when refreshing
                              if (properties.isEmpty &&
                                  snapshot.connectionState !=
                                      ConnectionState.waiting &&
                                  _dataInitialized) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 80,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        l10n.noPropertiesFound,
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.adjustFilters,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade500,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // Show loading indicator while waiting for data
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !_dataInitialized) {
                                return const SizedBox.shrink();
                              }

                              return ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: properties.length +
                                    1, // Add 1 for Nearby Properties
                                itemBuilder: (context, index) {
                                  // First item is Nearby Properties
                                  if (index == 0) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.shade200,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                        image: const DecorationImage(
                                          image: AssetImage(
                                              'assets/images/map.avif'),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const MapPage(),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.black.withOpacity(0.6),
                                                Colors.black.withOpacity(0.4),
                                              ],
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    "Nearby Properties",
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                      fontFamily: 'Montserrat',
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.arrow_forward_ios,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(Iconsax.map_15,
                                                      size: 20,
                                                      color: Colors.white
                                                          .withOpacity(0.9)),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    "View all properties on an interactive map",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.white
                                                          .withOpacity(0.9),
                                                      fontFamily: 'Montserrat',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  // Remove Advanced Filter Section
                                  // Adjust index for property items
                                  final propertyIndex =
                                      index - 1; // Changed from index - 2
                                  final property = properties[propertyIndex];
                                  return PropertyCard(
                                    property: property,
                                    isFavorite:
                                        _favoriteStatus[property.id] ?? false,
                                    onFavoriteToggle: () =>
                                        _toggleFavorite(property.id, property),
                                    refreshImage: _shouldRefreshImages,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PropertyCard extends StatefulWidget {
  const PropertyCard({
    super.key,
    required this.property,
    required this.isFavorite,
    required this.onFavoriteToggle,
    this.refreshImage = false,
  });

  final Property property;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final bool refreshImage;

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard>
    with AutomaticKeepAliveClientMixin {
  // This controls whether we need to refresh the image
  bool _needsRefresh = false;
  bool _isImageLoading = true;

  @override
  void initState() {
    super.initState();
    _needsRefresh = widget.refreshImage;
    // Preload image to reduce flickering on scroll
    _preloadImage();
  }

  @override
  void didUpdateWidget(PropertyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If refresh flag changed or property changed, we might need to refresh
    if (widget.refreshImage != oldWidget.refreshImage ||
        widget.property.id != oldWidget.property.id ||
        widget.property.imageUrl != oldWidget.property.imageUrl) {
      setState(() {
        _needsRefresh = widget.refreshImage;
        // Only set loading state to true if URL changed
        if (widget.property.imageUrl != oldWidget.property.imageUrl) {
          _isImageLoading = true;
          _preloadImage();
        }
      });
    }
  }

  // Helps with performance by preventing unnecessary rebuilds
  @override
  bool get wantKeepAlive => true;

  // Preload the image to reduce flickering
  Future<void> _preloadImage() async {
    try {
      final cacheKey = widget.property.id + '_cover_image';

      final imageProvider = CachedNetworkImageProvider(
        widget.property.imageUrl,
        cacheKey: cacheKey,
      );

      await precacheImage(imageProvider, context);

      if (mounted) {
        setState(() => _isImageLoading = false);
      }
    } catch (e) {
      // Image preload failed, but we'll still try to load it in the widget
      debugPrint('Error preloading image: $e');
      if (mounted) {
        setState(() => _isImageLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;

    String getTranslatedPropertyType(String type) {
      switch (type.toLowerCase()) {
        case 'apartment':
          return l10n.apartment;
        case 'studio':
          return l10n.studio;
        case 'house':
          return l10n.house;
        default:
          return type;
      }
    }

    // Use a stable cache key based on property ID
    final imageKey = widget.property.id + '_cover_image';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FeatureDiscovery(
                child: PropertyDetailsPage(property: widget.property),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: widget.property.imageUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      memCacheWidth: 800,
                      memCacheHeight: 800,
                      cacheKey: widget.property.id,
                      maxWidthDiskCache: 800,
                      maxHeightDiskCache: 800,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                            child: Icon(Icons.error, color: Colors.grey)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: widget.onFavoriteToggle,
                      icon: Icon(
                        widget.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Colors.red,
                        size: 20,
                      ),
                      padding: const EdgeInsets.all(4),
                    ),
                  ),
                ),
                if (widget.property.vrTourUrl != null &&
                    widget.property.vrTourUrl!.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: DescribedFeatureOverlay(
                      featureId: NavigationTour.vrTourFeature,
                      tapTarget: const Icon(FontAwesomeIcons.video, size: 10),
                      title: Text(l10n.virtualTourFeature,
                          style: const TextStyle(fontSize: 16)),
                      description: Text(
                        l10n.virtualTourDesc,
                        textAlign: TextAlign.center,
                      ),
                      backgroundColor: Colors.grey.shade800,
                      targetColor: Colors.white,
                      textColor: Colors.white,
                      overflowMode: OverflowMode.wrapBackground,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VRTourPage(
                                vrTourUrl: widget.property.vrTourUrl!,
                                property: widget.property,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(FontAwesomeIcons.video,
                                  size: 10, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                l10n.virtualTour,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.property.isAvailable
                          ? Colors.green
                          : Colors.red.shade600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.property.isAvailable
                          ? l10n.available
                          : l10n.notAvailable,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EGP ${NumberFormat('#,###').format(widget.property.price)}${l10n.perMonth}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      Text(
                        getTranslatedPropertyType(widget.property.type),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.property.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      RatingBar.builder(
                        initialRating: widget.property.rating,
                        minRating: 0,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemSize: 16,
                        ignoreGestures: true,
                        itemBuilder: (context, _) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        onRatingUpdate: (_) {},
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${widget.property.ratingCount})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.property.location,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
