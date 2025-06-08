import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:homi/models/property.dart';
import 'package:homi/pages/property_details_page.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:feature_discovery/feature_discovery.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // Controller for the Google Map
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  
  // Default camera position (will be updated with user's location)
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(30.0444, 31.2357), // Cairo, Egypt as default
    zoom: 14.0,
  );
  
  // User's current position
  Position? _currentPosition;
  
  // Map to store all markers
  final Map<String, Marker> _markers = {};
  
  // Properties loaded from Firestore
  List<Property> _properties = [];
  
  // Filter variables
  RangeValues _priceRange = const RangeValues(0, 5000);
  double _minPrice = 0;
  double _maxPrice = 5000;
  int? _selectedBedrooms;
  bool _filtersVisible = false;
  
  // Loading states
  bool _isLoadingLocation = true;
  bool _isLoadingProperties = true;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  // Request location permission and get current position
  Future<void> _requestLocationPermission() async {
    setState(() => _isLoadingLocation = true);
    
    final status = await Permission.location.request();
    
    if (status.isGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
        
        _animateToCurrentLocation();
        _loadNearbyProperties();
      } catch (e) {
        _showErrorSnackbar('Failed to get current location: $e');
        setState(() => _isLoadingLocation = false);
      }
    } else {
      _showErrorSnackbar('Location permission denied');
      setState(() => _isLoadingLocation = false);
      _loadAllProperties(); // Load all properties if location permission denied
    }
  }
  
  // Animate camera to current location
  Future<void> _animateToCurrentLocation() async {
    if (_currentPosition == null || !_mapController.isCompleted) return;
    
    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 14.0,
        ),
      ),
    );
  }
  
  // Load properties from Firestore
  Future<void> _loadNearbyProperties() async {
    setState(() => _isLoadingProperties = true);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('properties')
          .get();
      
      if (snapshot.docs.isEmpty) {
        setState(() => _isLoadingProperties = false);
        return;
      }
      
      final properties = snapshot.docs
          .map((doc) => Property.fromFirestore(doc))
          .toList();
      
      // Calculate distances if current position is available
      if (_currentPosition != null) {
        for (final property in properties) {
          // Parse location coordinates from the property
          // Note: This assumes properties have latitude and longitude fields
          // You may need to adjust based on your actual data structure
          if (property.latitude != null && property.longitude != null) {
            final distance = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              property.latitude!,
              property.longitude!,
            );
            property.distance = distance;
          }
        }
        
        // Sort by distance
        properties.sort((a, b) => (a.distance ?? double.infinity)
            .compareTo(b.distance ?? double.infinity));
      }
      
      setState(() {
        _properties = properties;
        _isLoadingProperties = false;
        _updatePriceRange();
      });
      
      _createMarkers();
    } catch (e) {
      _showErrorSnackbar('Failed to load properties: $e');
      setState(() => _isLoadingProperties = false);
    }
  }
  
  // Load all properties (used when location permission is denied)
  Future<void> _loadAllProperties() async {
    setState(() => _isLoadingProperties = true);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('properties')
          .get();
      
      final properties = snapshot.docs
          .map((doc) => Property.fromFirestore(doc))
          .toList();
      
      setState(() {
        _properties = properties;
        _isLoadingProperties = false;
        _updatePriceRange();
      });
      
      _createMarkers();
    } catch (e) {
      _showErrorSnackbar('Failed to load properties: $e');
      setState(() => _isLoadingProperties = false);
    }
  }
  
  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371; // Earth radius in kilometers
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = 
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * 
        sin(dLon / 2) * sin(dLon / 2);
        
    final c = 2 * asin(sqrt(a));
    return r * c;
  }
  
  double _toRadians(double degree) {
    return degree * (pi / 180);
  }
  
  // Update price range based on loaded properties
  void _updatePriceRange() {
    if (_properties.isEmpty) return;
    
    final prices = _properties.map((p) => p.price.toDouble()).toList();
    _minPrice = prices.reduce(min);
    _maxPrice = prices.reduce(max);
    
    setState(() {
      _priceRange = RangeValues(_minPrice, _maxPrice);
    });
  }
  
  // Create markers for all properties
  Future<void> _createMarkers() async {
    if (_properties.isEmpty) return;

    // Filter properties based on current filters
    final filteredProperties = _applyFilters();
    
    // Clear existing markers
    setState(() => _markers.clear());
    
    // Load and resize home icon
    final BitmapDescriptor homeIcon = await _createResizedMarkerIcon();
    
    for (final property in filteredProperties) {
      // Skip if coordinates are missing
      if (property.latitude == null || property.longitude == null) continue;
      
      final markerId = MarkerId(property.id);
      
      final marker = Marker(
        markerId: markerId,
        position: LatLng(property.latitude!, property.longitude!),
        icon: homeIcon,
        infoWindow: InfoWindow(
          title: property.title,
          snippet: 'EGP ${NumberFormat('#,###').format(property.price)}',
          onTap: () {
            try {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => FeatureDiscovery(
                    child: PropertyDetailsPage(property: property),
                  ),
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error loading property details: $e")),
              );
            }
          },
        ),
        onTap: () => _showPropertyInfoBottomSheet(property),
      );
      
      setState(() => _markers[property.id] = marker);
    }
  }
  
  // Helper method to create a resized marker icon
  Future<BitmapDescriptor> _createResizedMarkerIcon() async {
    // Load the image
    final ByteData data = await rootBundle.load('assets/images/home.png');
    final Uint8List bytes = data.buffer.asUint8List();
    
    // Decode the image
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ui.Image image = fi.image;
    
    // Create a very small icon (24x24 pixels)
    final int targetWidth = 90;
    final int targetHeight = 90;
    
    // Create a canvas to draw the resized image
    final pictureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(pictureRecorder);
    
    // Draw the image with a specific size
    canvas.drawImageRect(
      image,
      Rect.fromLTRB(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTRB(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      Paint(),
    );
    
    // Convert the canvas to an image
    final picture = pictureRecorder.endRecording();
    final resizedImage = await picture.toImage(targetWidth, targetHeight);
    final ByteData? resizedByteData = await resizedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    
    if (resizedByteData == null) {
      // Fallback to default marker if resizing fails
      return BitmapDescriptor.defaultMarker;
    }
    
    final Uint8List resizedBytes = resizedByteData.buffer.asUint8List();
    
    // Create the bitmap descriptor from the resized image
    return BitmapDescriptor.fromBytes(resizedBytes);
  }
  
  // Apply filters to properties
  List<Property> _applyFilters() {
    return _properties.where((property) {
      // Price filter
      if (property.price < _priceRange.start || property.price > _priceRange.end) {
        return false;
      }
      
      // Bedrooms filter
      if (_selectedBedrooms != null && property.bedrooms < _selectedBedrooms!) {
        return false;
      }
      
      return true;
    }).toList();
  }
  
  // Navigate to property details page with error handling
  void _navigateToPropertyDetails(Property property) {
    try {
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => FeatureDiscovery(
            child: PropertyDetailsPage(property: property),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading property details: $e")),
      );
    }
  }
  
  // Show property info in bottom sheet
  void _showPropertyInfoBottomSheet(Property property) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Property image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: property.imageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      height: 100,
                      width: 100,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      height: 100,
                      width: 100,
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'EGP ${NumberFormat('#,###').format(property.price)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        property.location,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontFamily: 'Montserrat',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.bed, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${property.bedrooms} ${AppLocalizations.of(context)!.beds}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontFamily: 'Montserrat',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.bathtub, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${property.bathrooms} ${AppLocalizations.of(context)!.baths}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ],
                      ),
                      if (property.distance != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.directions, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${property.distance!.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  try {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => FeatureDiscovery(
                          child: PropertyDetailsPage(property: property),
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error loading property details: $e")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  "View Details",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Find closest property to current location
  void _findClosestProperty() {
    if (_currentPosition == null || _properties.isEmpty) {
      _showErrorSnackbar('Unable to find closest property');
      return;
    }
    
    Property? closestProperty;
    double minDistance = double.infinity;
    
    for (final property in _properties) {
      if (property.latitude == null || property.longitude == null) continue;
      
      final distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        property.latitude!,
        property.longitude!,
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        closestProperty = property;
      }
    }
    
    if (closestProperty != null) {
      _animateToProperty(closestProperty);
      _showPropertyInfoBottomSheet(closestProperty);
    } else {
      _showErrorSnackbar('No nearby properties found');
    }
  }
  
  // Animate to property on map
  Future<void> _animateToProperty(Property property) async {
    if (property.latitude == null || property.longitude == null || !_mapController.isCompleted) return;
    
    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(property.latitude!, property.longitude!),
          zoom: 16.0,
        ),
      ),
    );
  }
  
  // Show error message
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            "Map View",
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'Montserrat',
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _filtersVisible ? Icons.filter_list_off : Icons.filter_list,
                  color: Colors.black87,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _filtersVisible = !_filtersVisible;
                  });
                },
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: _defaultPosition,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            markers: Set<Marker>.of(_markers.values),
            onMapCreated: (GoogleMapController controller) {
              _mapController.complete(controller);
              if (_currentPosition != null) {
                _animateToCurrentLocation();
              }
            },
            onCameraMove: (_) {
              // Map is being moved
            },
            onCameraIdle: () {
              // Map movement has stopped
            },
          ),
          
          // Loading indicator
          if (_isLoadingLocation || _isLoadingProperties)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade800),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Loading...",
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          // Filters panel with modern design
          if (_filtersVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 80, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Filters",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey.shade600, size: 20),
                          onPressed: () => setState(() => _filtersVisible = false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Price range filter
                    Text(
                      "Price Range: EGP ${_priceRange.start.toInt()} - EGP ${_priceRange.end.toInt()}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: Colors.grey.shade800,
                        inactiveTrackColor: Colors.grey.shade300,
                        thumbColor: Colors.white,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayColor: Colors.grey.shade800.withOpacity(0.2),
                        valueIndicatorColor: Colors.grey.shade800,
                        valueIndicatorTextStyle: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      child: RangeSlider(
                        values: _priceRange,
                        min: _minPrice,
                        max: _maxPrice,
                        divisions: 20,
                        onChanged: (RangeValues values) {
                          setState(() {
                            _priceRange = values;
                          });
                        },
                        onChangeEnd: (RangeValues values) {
                          _createMarkers();
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Bedrooms filter
                    Row(
                      children: [
                        Text(
                          "Bedrooms",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: _selectedBedrooms,
                              hint: Text("Any"),
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontFamily: 'Montserrat',
                                fontSize: 14,
                              ),
                              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade800, size: 20),
                              borderRadius: BorderRadius.circular(20),
                              onChanged: (int? value) {
                                setState(() {
                                  _selectedBedrooms = value;
                                });
                                _createMarkers();
                              },
                              items: [null, 1, 2, 3, 4, 5]
                                  .map<DropdownMenuItem<int?>>((int? value) {
                                return DropdownMenuItem<int?>(
                                  value: value,
                                  child: Text(value == null ? "Any" : "$value+"),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Reset filters button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _priceRange = RangeValues(_minPrice, _maxPrice);
                            _selectedBedrooms = null;
                          });
                          _createMarkers();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade800,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "Reset Filters",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          // Floating action buttons with modern design
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Find Closest Property
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                    child: InkWell(
                      onTap: _findClosestProperty,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.near_me,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Find Nearby",
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Current Location Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Material(
                      color: Colors.white,
                      child: InkWell(
                        onTap: _animateToCurrentLocation,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.my_location,
                            color: Colors.grey.shade800,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 