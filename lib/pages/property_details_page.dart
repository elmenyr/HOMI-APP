// ignore_for_file: deprecated_member_use, unnecessary_lambdas, lines_longer_than_80_chars, directives_ordering, unused_field, unnecessary_raw_strings, avoid_void_async, unnecessary_brace_in_string_interps

import 'dart:async';
import 'dart:io';
import 'dart:math' show min, max, pi, sin, cos, sqrt, atan2;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:animate_do/animate_do.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:homi/models/admin_user.dart';
import 'package:homi/models/property.dart';
import 'package:homi/models/working_hours.dart';
import 'package:homi/pages/add_property_page.dart';
import 'package:homi/pages/property_photos_page.dart';
import 'package:homi/pages/video_player_page.dart';
import 'package:homi/pages/agents_page.dart';
import 'package:homi/utils/property_details_tour.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Stream controller for favorite updates
final StreamController<String> favoriteUpdateController =
    StreamController<String>.broadcast();

class FavoriteButton extends StatefulWidget {
  final Property property;
  final VoidCallback onFavoriteChanged;

  const FavoriteButton({
    required this.property,
    required this.onFavoriteChanged,
    super.key,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _isFavorite = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await _getFavoriteDocument(user.uid).get();
      if (!mounted) return;
      setState(() => _isFavorite = doc.exists);
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
    }
  }

  DocumentReference _getFavoriteDocument(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(widget.property.id);
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginRequiredMessage();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final favoriteRef = _getFavoriteDocument(user.uid);
      final newFavoriteState = !_isFavorite;

      await _updateFavoriteInFirestore(favoriteRef, newFavoriteState);

      if (!mounted) return;
      setState(() {
        _isFavorite = newFavoriteState;
        _isLoading = false;
      });

      _notifyFavoriteStatusChanged();
      _showFavoriteUpdateSuccessMessage();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showFavoriteUpdateFailedMessage();
    }
  }

  Future<void> _updateFavoriteInFirestore(
      DocumentReference favoriteRef, bool shouldAdd) async {
    if (shouldAdd) {
      await favoriteRef.set(widget.property.toFirestore());
    } else {
      await favoriteRef.delete();
    }
  }

  void _notifyFavoriteStatusChanged() {
    favoriteUpdateController.add(widget.property.id);
    widget.onFavoriteChanged();
  }

  void _showLoginRequiredMessage() {
    _showSnackBar(AppLocalizations.of(context)!.loginToSaveFavorites,
        isError: true);
  }

  void _showFavoriteUpdateSuccessMessage() {
    _showSnackBar(AppLocalizations.of(context)!.addedToFavorites);
  }

  void _showFavoriteUpdateFailedMessage() {
    _showSnackBar(AppLocalizations.of(context)!.favoriteUpdateFailed,
        isError: true);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleFavorite,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isFavorite ? Colors.red : Colors.grey.shade400,
                  ),
                ),
              )
            : Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : Colors.grey.shade400,
                size: 20,
              ),
      ),
    );
  }
}

class PropertyDetailsPage extends StatefulWidget {
  const PropertyDetailsPage({required this.property, super.key});
  final Property property;

  @override
  State<PropertyDetailsPage> createState() => _PropertyDetailsPageState();
}

class _PropertyDetailsPageState extends State<PropertyDetailsPage> {
  // Constants
  static const double _universityLat = 30.879281936554452;
  static const double _universityLng = 32.37214142149693;
  static const double _mapInitialZoom = 14.0;
  static const double _mapDetailedZoom = 16.0;
  static const Duration _animationDuration = Duration(milliseconds: 300);
  static const Duration _tourInitDelayDuration = Duration(milliseconds: 500);

  // Property data that will be refreshed
  late Property _property;

  // State variables
  bool _isLoading = false;
  bool _isAdmin = false;
  bool _isMapFullscreen = false;
  bool _isMapReady = false;

  // Controllers
  final PageController _imagePageController = PageController();
  final ValueNotifier<bool> _isInitialLoad = ValueNotifier<bool>(true);
  final ValueNotifier<int> _currentPageIndex = ValueNotifier<int>(0);
  GoogleMapController? _mapController;

  // Map related
  MapType _currentMapType = MapType.normal;
  Set<Polyline> _polylines = {};

  // Property marker icon
  BitmapDescriptor _propertyMarkerIcon = BitmapDescriptor.defaultMarker;

  @override
  void initState() {
    super.initState();
    // Initialize with the property passed from constructor
    _property = widget.property;
    // Fetch the latest property data from Firestore
    _refreshPropertyData();
    _checkAdminAccess();
    _setupPropertyToUniversityRoute();
    _initializeOnboardingTour();
    _loadPropertyMarkerIcon();
  }

  // Fetch the latest property data from Firestore
  Future<void> _refreshPropertyData() async {
    try {
      final propertyDoc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.property.id)
          .get();

      if (propertyDoc.exists && mounted) {
        setState(() {
          _property = Property.fromFirestore(propertyDoc);
        });
      }
    } catch (e) {
      debugPrint('Error refreshing property data: $e');
    }
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    _isInitialLoad.dispose();
    _currentPageIndex.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _initializeOnboardingTour() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Delay to allow UI to fully render
      Future.delayed(_tourInitDelayDuration, () {
        _showPropertyDetailsTour();
      });
    });
  }

  Future<void> _checkAdminAccess() async {
    final isAdmin = await AdminUser.isCurrentUserAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  void _setupPropertyToUniversityRoute() {
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('university_route'),
          color: Colors.blue,
          width: 5,
          points: [
            LatLng(widget.property.latitude, widget.property.longitude),
            LatLng(_universityLat - 0.001, _universityLng),
            const LatLng(_universityLat, _universityLng),
          ],
        ),
      };
    });
  }

  // Map utility functions
  LatLngBounds _getPropertyToUniversityBounds() {
    return LatLngBounds(
      southwest: LatLng(
        min(widget.property.latitude, _universityLat) - 0.001,
        min(widget.property.longitude, _universityLng) - 0.001,
      ),
      northeast: LatLng(
        max(widget.property.latitude, _universityLat) + 0.001,
        max(widget.property.longitude, _universityLng) + 0.001,
      ),
    );
  }

  void _fitMapToBounds() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        _getPropertyToUniversityBounds(),
        50,
      ),
    );
  }

  void _toggleMapFullscreen() {
    setState(() {
      _isMapFullscreen = !_isMapFullscreen;
      // Ensure map is properly sized after animation
      if (_mapController != null) {
        Future.delayed(_animationDuration, () {
          _mapController?.setMapStyle(_currentMapType == MapType.normal
              ? null
              : '[{"featureType":"all","elementType":"labels","stylers":[{"visibility":"off"}]}]');
        });
      }
    });
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  void _zoomToProperty() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(widget.property.latitude, widget.property.longitude),
        _mapDetailedZoom,
      ),
    );
  }

  // Distance calculation
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  double _getDistanceToUniversity() {
    return _calculateDistance(widget.property.latitude,
        widget.property.longitude, _universityLat, _universityLng);
  }

  // Property status functions
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade600;
      case 'rejected':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // Rating related functions
  Future<double> _getUserRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0.0;

    try {
      final ratingDoc = await _getUserRatingDocument(user.uid).get();

      if (ratingDoc.exists) {
        return (ratingDoc.data() as Map<String, dynamic>)['rating']
                as double? ??
            0.0;
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error getting user rating: $e');
      return 0.0;
    }
  }

  DocumentReference _getUserRatingDocument(String userId) {
    return FirebaseFirestore.instance
        .collection('properties')
        .doc(widget.property.id)
        .collection('ratings')
        .doc(userId);
  }

  Future<void> _submitRating(double rating) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginRequiredMessage(
          AppLocalizations.of(context)!.loginToRateProperties);
      return;
    }

    try {
      await _updatePropertyRatingInTransaction(user.uid, rating);
      _showSuccessMessage(
          AppLocalizations.of(context)!.ratingSubmittedSuccessfully);
    } catch (e) {
      _showErrorMessage(AppLocalizations.of(context)!.failedToSubmitRating);
    }
  }

  Future<void> _updatePropertyRatingInTransaction(
      String userId, double newUserRating) async {
    final propertyRef = FirebaseFirestore.instance
        .collection('properties')
        .doc(widget.property.id);
    final userRatingRef = _getUserRatingDocument(userId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final propertySnapshot = await transaction.get(propertyRef);

      if (!propertySnapshot.exists) {
        throw Exception('Property does not exist!');
      }

      final ratingsSnapshot = await propertyRef.collection('ratings').get();

      final updatedRating =
          _calculateUpdatedRating(ratingsSnapshot.docs, userId, newUserRating);

      transaction.update(propertyRef, {
        'rating': updatedRating.newAverageRating,
        'ratingCount': updatedRating.newTotalCount,
      });

      transaction.set(userRatingRef, {
        'rating': newUserRating,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
      });
    });
  }

  ({double newAverageRating, int newTotalCount}) _calculateUpdatedRating(
      List<QueryDocumentSnapshot> ratingDocs,
      String currentUserId,
      double newRating) {
    double totalRating = 0;
    int totalCount = 0;

    for (var doc in ratingDocs) {
      if (doc.id != currentUserId) {
        final data = doc.data() as Map<String, dynamic>;
        totalRating += data['rating'] as double;
        totalCount++;
      }
    }

    totalRating += newRating;
    totalCount++;

    final newAverageRating = totalCount > 0 ? totalRating / totalCount : 0.0;

    return (newAverageRating: newAverageRating, newTotalCount: totalCount);
  }

  // Sound related functions
  Future<void> _playSuccessSound() async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/done.mp3'),
          mode: PlayerMode.lowLatency);

      // Dispose after playing to clean up resources
      player.onPlayerComplete.listen((event) {
        player.dispose();
      });
    } catch (e) {
      // Silently handle any errors to avoid app crashes
      debugPrint('Error playing success sound: $e');
    }
  }

  // Messages and notifications
  void _showLoginRequiredMessage(String message) {
    _showSnackBar(message, isError: true);
  }

  void _showSuccessMessage(String message) {
    _showSnackBar(message);
  }

  void _showErrorMessage(String message) {
    _showSnackBar(message, isError: true);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
          textDirection: Directionality.of(context),
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // UI Building methods
  Widget _buildRatingBarSection() {
    final l10n = AppLocalizations.of(context)!;
    return RepaintBoundary(
      key: const ValueKey('rating_bar_section'),
      child: DescribedFeatureOverlay(
        featureId: PropertyDetailsTour.ratingFeature,
        tapTarget: const Icon(Icons.star),
        title: Text(l10n.rateProperty, style: GoogleFonts.poppins()),
        description: Text(
          l10n.tapToRate,
          style: GoogleFonts.poppins(),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.black,
        targetColor: Colors.amber,
        textColor: Colors.white,
        overflowMode: OverflowMode.wrapBackground,
        child: _buildRatingContainer(),
      ),
    );
  }

  Widget _buildRatingContainer() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRatingHeader(l10n),
          const SizedBox(height: 12),
          _buildRatingStars(),
        ],
      ),
    );
  }

  Widget _buildRatingHeader(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.rateProperty,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
              const SizedBox(width: 4),
              Text(
                '${widget.property.rating.toStringAsFixed(1)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingStars() {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<double>(
      future: _getUserRating(),
      builder: (context, snapshot) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(
            begin: 0,
            end: snapshot.data ?? 0.0,
          ),
          builder: (context, value, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RatingBar.builder(
                  initialRating: value,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemSize: 28,
                  glow: false,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                  itemBuilder: (context, _) => const Icon(
                    Icons.star_rounded,
                    color: Colors.amber,
                  ),
                  onRatingUpdate: (rating) {
                    _submitRating(rating);
                  },
                  unratedColor: Colors.grey.shade200,
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    value > 0
                        ? l10n.yourRating(value.toStringAsFixed(1))
                        : l10n.tapToRate,
                    key: ValueKey(value > 0),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMapSection() {
    return AnimatedContainer(
      duration: _animationDuration,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _isMapFullscreen ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(_isMapFullscreen ? 0 : 16),
        boxShadow: _isMapFullscreen
            ? []
            : [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                  spreadRadius: 2,
                ),
              ],
      ),
      child: Stack(
        children: [
          _buildMapView(),
          if (_isMapFullscreen) _buildMapBackButton(),
          _buildMapControls(),
          if (!_isMapFullscreen) _buildLocationDetailsSection(),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_isMapFullscreen ? 0 : 16),
      child: SizedBox(
        height: _isMapFullscreen ? MediaQuery.of(context).size.height : 350,
        width: double.infinity,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              (widget.property.latitude + _universityLat) / 2,
              (widget.property.longitude + _universityLng) / 2,
            ),
            zoom: _mapInitialZoom,
          ),
          polylines: _polylines,
          markers: {
            Marker(
              markerId: MarkerId(widget.property.id),
              position:
                  LatLng(widget.property.latitude, widget.property.longitude),
              infoWindow: InfoWindow(title: widget.property.title),
              icon: _propertyMarkerIcon,
            ),
            Marker(
              markerId: const MarkerId('university'),
              position: const LatLng(_universityLat, _universityLng),
              infoWindow: const InfoWindow(title: 'Sina University'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
            ),
          },
          onMapCreated: _onMapCreated,
          mapType: _currentMapType,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
          },
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() {
      _isMapReady = true;
    });
    _fitMapToBounds();
  }

  Widget _buildMapBackButton() {
    return AnimatedPositioned(
      duration: _animationDuration,
      curve: Curves.easeInOut,
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: _buildMapActionButton(
          icon: Icons.arrow_back,
          onTap: _toggleMapFullscreen,
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    return AnimatedPositioned(
      duration: _animationDuration,
      curve: Curves.easeInOut,
      top: _isMapFullscreen ? MediaQuery.of(context).padding.top + 16 : 12,
      right: _isMapFullscreen ? 16 : 12,
      child: Column(
        children: [
          _buildMapActionButton(
            icon: _isMapFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            onTap: _toggleMapFullscreen,
          ),
          const SizedBox(height: 8),
          _buildMapActionButton(
            icon: Icons.layers_outlined,
            onTap: _toggleMapType,
          ),
          const SizedBox(height: 8),
          _buildMapActionButton(
            icon: Icons.my_location,
            onTap: _zoomToProperty,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDetailsSection() {
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Iconsax.location, size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.property.location,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => widget.property.openInMaps(),
              icon: const Icon(Icons.directions, size: 18),
              label: Text(
                l10n.getDirections,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: Colors.black),
          ),
        ),
      ),
    );
  }

  void _launchWhatsApp() async {
    final phoneNumber = _formatPhoneNumber(widget.property.agentPhone);

    if (phoneNumber.isEmpty) {
      _showErrorMessage(AppLocalizations.of(context)!.agentPhoneNotAvailable);
      return;
    }

    final url = 'https://wa.me/$phoneNumber';
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      _showErrorMessage(AppLocalizations.of(context)!.couldNotOpenWhatsApp);
    }
  }

  String _formatPhoneNumber(String phone) {
    // Remove non-numeric characters, leading zeros, and add country code
    final cleanNumber =
        phone.replaceAll(RegExp(r'[^0-9]'), '').replaceAll(RegExp(r'^0+'), '');

    return cleanNumber.isEmpty ? '' : '20$cleanNumber';
  }

  Future<void> _showPropertyDetailsTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isTourCompleted =
          prefs.getBool('property_details_tour_completed') ?? false;

      if (!isTourCompleted && mounted) {
        // Ensure the UI is fully rendered before showing the tour
        await Future.delayed(const Duration(milliseconds: 300));

        FeatureDiscovery.discoverFeatures(
          context,
          const <String>[
            PropertyDetailsTour.favoriteFeature,
            PropertyDetailsTour.photoGalleryFeature,
            PropertyDetailsTour.locationFeature,
            PropertyDetailsTour.ratingFeature,
            PropertyDetailsTour.pdfFeature,
            PropertyDetailsTour.distanceFeature,
          ],
        );

        await prefs.setBool('property_details_tour_completed', true);
      }
    } catch (e) {
      debugPrint('Error showing property details tour: $e');
      // Fail gracefully, don't crash the app
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return WillPopScope(
      onWillPop: () async {
        if (_isMapFullscreen) {
          _toggleMapFullscreen();
          return false;
        }
        return true;
      },
      child: Directionality(
        // Force LTR layout regardless of language
        textDirection: TextDirection.ltr,
        child: Scaffold(
          backgroundColor:
              _isMapFullscreen ? Colors.black : Colors.grey.shade100,
          extendBodyBehindAppBar: true,
          appBar: _isMapFullscreen ? null : _buildAppBar(l10n),
          body: _buildBody(l10n),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: _buildBackButton(),
      actions: [
        _buildPdfButton(l10n),
        _buildFavoriteButton(),
        if (_isAdmin) ...[
          _buildEditButton(),
          _buildDeleteButton(),
        ],
        const SizedBox(width: 8), // Add some padding at the end
      ],
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_back, color: Colors.black),
      ),
    );
  }

  Widget _buildPdfButton(AppLocalizations l10n) {
    return DescribedFeatureOverlay(
      featureId: PropertyDetailsTour.pdfFeature,
      tapTarget: const Icon(Icons.picture_as_pdf),
      title: Text(l10n.downloadPdf, style: GoogleFonts.poppins()),
      description: Text(
        l10n.downloadPdfDesc,
        style: GoogleFonts.poppins(),
        textAlign: TextAlign.center,
      ),
      backgroundColor: Colors.black,
      targetColor: Colors.white,
      textColor: Colors.white,
      overflowMode: OverflowMode.wrapBackground,
      child: GestureDetector(
        onTap: _generateAndDownloadPDF,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.grey.shade800),
                  ),
                )
              : Icon(Icons.picture_as_pdf,
                  color: Colors.grey.shade800, size: 20),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton() {
    return DescribedFeatureOverlay(
      featureId: PropertyDetailsTour.favoriteFeature,
      tapTarget: const Icon(Icons.favorite),
      title: Text('Save to Favorites', style: GoogleFonts.poppins()),
      description: Text(
        'Add this property to your favorites list for quick access later.',
        style: GoogleFonts.poppins(),
        textAlign: TextAlign.center,
      ),
      backgroundColor: Colors.black,
      targetColor: Colors.white,
      textColor: Colors.white,
      overflowMode: OverflowMode.wrapBackground,
      child: FavoriteButton(
        property: widget.property,
        onFavoriteChanged: () {
          // Handle favorite change if needed
        },
      ),
    );
  }

  Widget _buildEditButton() {
    return GestureDetector(
      onTap: _editProperty,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Iconsax.edit, color: Colors.grey.shade800, size: 20),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: _deleteProperty,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Iconsax.trash, color: Colors.red.shade600, size: 20),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: _animationDuration,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: _isMapFullscreen
              ? _buildMapSection()
              : _buildPropertyDetailsContent(l10n),
        ),
        // Floating Action Button with animated position
        if (!_isMapFullscreen)
          AnimatedPositioned(
            duration: _animationDuration,
            curve: Curves.easeInOut,
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildFloatingActionButton(),
          ),
      ],
    );
  }

  Widget _buildPropertyDetailsContent(AppLocalizations l10n) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isInitialLoad,
      builder: (context, isInitial, child) {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 320,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildImageGallery()),
                    if (widget.property.images.isNotEmpty)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: _buildImagePageIndicators(),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildHeaderGradientOverlay(),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: _buildHeaderContent(),
                    ),
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: _buildMediaButtons(),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildPropertyDetails(l10n),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPropertyDetails(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildPropertyFeatures(),
          const SizedBox(height: 20),
          if (widget.property.hasInsurance > 0) _buildInsuranceNotice(l10n),
          const SizedBox(height: 20),
          _buildPropertyDescription(l10n),
          const SizedBox(height: 32),
          _buildLocationSection(l10n),
          const SizedBox(height: 32),
          _buildTenantsSection(l10n),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPropertyFeatures() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildPropertyFeature(
                Icons.bed, widget.property.bedrooms.toString()),
            const SizedBox(width: 8),
            _buildPropertyFeature(
                Icons.bathroom, widget.property.bathrooms.toString()),
            const SizedBox(width: 8),
            _buildDistanceFeature(),
            const SizedBox(width: 8),
            _buildPropertyFeature(
              Iconsax.wifi,
              'WiFi',
              highlighted: widget.property.hasWifi,
            ),
            const SizedBox(width: 8),
            _buildPropertyFeature(
              Iconsax.wind,
              'AC',
              highlighted: widget.property.airCond,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsuranceNotice(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.money, color: Colors.red.shade600, size: 18),
            const SizedBox(width: 6),
            Text(
              l10n.insurance(widget.property.hasInsurance.toString()),
              style: GoogleFonts.poppins(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyDescription(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.aboutThisProperty,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.property.description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          _buildRatingBarSection(),
        ],
      ),
    );
  }

  Widget _buildLocationSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.location,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          DescribedFeatureOverlay(
            featureId: PropertyDetailsTour.locationFeature,
            tapTarget: const Icon(Iconsax.location),
            title: Text(l10n.location, style: GoogleFonts.poppins()),
            description: Text(
              l10n.location, // Just use location text as it doesn't have locationDesc
              style: GoogleFonts.poppins(),
              textAlign: TextAlign.center,
            ),
            backgroundColor: Colors.black,
            targetColor: Colors.white,
            textColor: Colors.white,
            overflowMode: OverflowMode.wrapBackground,
            child: _buildMapSection(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTenantsSection(AppLocalizations l10n) {
    // Only show this section for admin users
    return FutureBuilder<bool>(
      future: AdminUser.isCurrentUserAdmin(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data != true) {
          return const SizedBox
              .shrink(); // Not an admin, don't show this section
        }

        // Admin user, show tenants list
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current Tenants',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  // Refresh button to reload property data
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.blue.shade600),
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                      });
                      _refreshPropertyData().then((_) {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Tenant information refreshed',
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                              backgroundColor: Colors.green.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          );
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(),
                )
              else if (_property.tenants == null || _property.tenants.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'No tenants currently in this property',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _property.tenants.length,
                  itemBuilder: (context, index) {
                    final tenant = _property.tenants[index];
                    return _buildTenantCard(tenant);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTenantCard(Map<String, dynamic> tenant) {
    final userId = tenant['userId'] as String;
    final type = tenant['type'] as String;
    final startDate = tenant['startDate'] as DateTime;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final name = userData?['fullName'] as String? ?? 'Unknown';
        final email = userData?['email'] as String? ?? 'No email';
        final phone = userData?['phone'] as String? ?? 'No phone';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    child: Icon(Icons.person, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Since ${_formatDate(startDate)}',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: type == 'bed'
                          ? Colors.blue.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type.toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: type == 'bed'
                            ? Colors.blue.shade700
                            : Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTenantDetailRow(Icons.email, email),
              const SizedBox(height: 8),
              _buildTenantDetailRow(Icons.phone, phone),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTenantDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildFloatingActionButton() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildAgentContactButton(),
        ),
        Expanded(
          flex: 3,
          child: _buildBookingButton(),
        ),
      ],
    );
  }

  Widget _buildAgentContactButton() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ElevatedButton(
        onPressed: _navigateToAgentsPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          side: BorderSide(color: Colors.grey.shade300),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          minimumSize: const Size(100, 48),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.people, size: 16, color: Colors.grey.shade800),
            const SizedBox(width: 6),
            Text(
              l10n.agents,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingButton() {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<DocumentSnapshot>(
      stream: _getBookingStatusStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.exists) {
          return _buildExistingBookingStatusButton(snapshot.data!, l10n);
        }
        return _buildNewBookingButton(l10n);
      },
    );
  }

  Stream<DocumentSnapshot> _getBookingStatusStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('propertyBookings')
        .doc('${user.uid}_${widget.property.id}')
        .snapshots();
  }

  Widget _buildExistingBookingStatusButton(
      DocumentSnapshot snapshot, AppLocalizations l10n) {
    final status = snapshot.get('status') as String? ?? 'pending';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        height: 48,
        decoration: BoxDecoration(
          color: _getStatusColor(status),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'approved' ? Iconsax.tick_circle : Iconsax.info_circle,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              '${l10n.status}: ${status.toUpperCase()}',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewBookingButton(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: ElevatedButton(
        onPressed: _bookProperty,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          minimumSize: const Size(100, 48),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.building, size: 16),
            const SizedBox(width: 6),
            Text(
              l10n.requestProperty,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyFeature(IconData icon, String value,
      {bool highlighted = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: highlighted ? Colors.grey.shade700 : Colors.red.shade400,
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: highlighted ? Colors.grey.shade800 : Colors.red.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceFeature() {
    return DescribedFeatureOverlay(
      featureId: PropertyDetailsTour.distanceFeature,
      tapTarget: const Icon(Iconsax.building),
      title: Text(AppLocalizations.of(context)!.distanceToUni,
          style: GoogleFonts.poppins()),
      description: Text(
        AppLocalizations.of(context)!
            .distanceToUni, // Just use this text since distanceInfo doesn't exist
        style: GoogleFonts.poppins(),
        textAlign: TextAlign.center,
      ),
      backgroundColor: Colors.black,
      targetColor: Colors.grey.shade700,
      textColor: Colors.white,
      overflowMode: OverflowMode.wrapBackground,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Iconsax.building, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              '${_getDistanceToUniversity().toStringAsFixed(1)}km',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'to uni',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery() {
    return DescribedFeatureOverlay(
      featureId: PropertyDetailsTour.photoGalleryFeature,
      tapTarget: const Icon(Iconsax.gallery),
      title: Text(AppLocalizations.of(context)!.propertyPhotos,
          style: GoogleFonts.poppins()),
      description: Text(
        AppLocalizations.of(context)!.propertyPhotosDesc,
        style: GoogleFonts.poppins(),
        textAlign: TextAlign.center,
      ),
      backgroundColor: Colors.black,
      targetColor: Colors.white,
      textColor: Colors.white,
      overflowMode: OverflowMode.wrapBackground,
      child: PageView.builder(
        controller: _imagePageController,
        onPageChanged: (index) {
          _currentPageIndex.value = index;
        },
        itemCount: widget.property.images.isNotEmpty
            ? widget.property.images.length
            : 1,
        itemBuilder: (context, index) {
          final imageUrl = widget.property.images.isNotEmpty
              ? widget.property.images[index]['url'] as String
              : widget.property.imageUrl;

          // Create a unique cache key for this image
          final cacheKey = 'property_${widget.property.id}_image_$index';

          return GestureDetector(
            onTap: () {
              if (widget.property.images.isNotEmpty) {
                _openPropertyPhotosPage();
              }
            },
            child: Hero(
              tag: 'property_${widget.property.id}_$index',
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                cacheKey: cacheKey,
                memCacheWidth: 1200,
                maxWidthDiskCache: 1200,
                useOldImageOnUrlChange: true,
                fadeInDuration: const Duration(milliseconds: 300),
                fadeOutDuration: const Duration(milliseconds: 300),
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildImagePlaceholder(),
                errorWidget: (context, url, error) {
                  debugPrint('Error loading property image: $error');
                  // Try to fetch the image again
                  _retryLoadingImage(imageUrl, cacheKey);
                  return _buildImageErrorWidget();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // Retry loading an image if it fails
  void _retryLoadingImage(String imageUrl, String cacheKey) {
    // Clear the cached failed image
    CachedNetworkImage.evictFromCache(imageUrl);

    // Wait a bit and try to pre-cache it again
    Future.delayed(const Duration(milliseconds: 500), () {
      precacheImage(
        CachedNetworkImageProvider(
          imageUrl,
          cacheKey: cacheKey,
        ),
        context,
      );
    });
  }

  void _openPropertyPhotosPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyPhotosPage(property: widget.property),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      ),
    );
  }

  Widget _buildImageErrorWidget() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(Icons.image_not_supported,
          size: 80, color: Colors.grey.shade600),
    );
  }

  Widget _buildImagePageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.property.images.length,
        (index) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPageIndex.value == index
                ? Colors.white
                : Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderGradientOverlay() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.6),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'EGP ${widget.property.price}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.property.title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black54,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Iconsax.location, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.property.location,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaButtons() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.property.images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _openPropertyPhotosPage,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Iconsax.gallery,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.photos,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (widget.property.videoUrl != null &&
            widget.property.videoUrl!.isNotEmpty)
          GestureDetector(
            onTap: _openVideoPlayer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Iconsax.video_play,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.video,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _openVideoPlayer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          videoUrl: widget.property.videoUrl!,
          property: widget.property,
        ),
      ),
    );
  }

  // Property management functions
  Future<void> _deleteProperty() async {
    final confirmed = await _showDeleteConfirmationDialog();
    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.property.id)
          .delete();

      if (!mounted) return;
      Navigator.of(context).pop();
      _showSuccessMessage(
          AppLocalizations.of(context)!.propertyDeletedSuccessfully);
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(AppLocalizations.of(context)!.errorDeletingProperty);
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.delete,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Text(AppLocalizations.of(context)!.deleteConfirm,
                style: GoogleFonts.poppins()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context)!.cancel,
                    style: GoogleFonts.poppins(color: Colors.grey.shade600)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(AppLocalizations.of(context)!.delete,
                    style: GoogleFonts.poppins(color: Colors.red.shade600)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _editProperty() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddPropertyPage(property: widget.property),
      ),
    );
  }

  // Property booking functionality
  Future<void> _bookProperty() async {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showLoginRequiredMessage(l10n.loginToFavorite);
      return;
    }

    if (await _hasExistingBookingRequest(user.uid)) {
      _showErrorMessage(l10n.alreadyRequested);
      return;
    }

    if (!await _isWithinWorkingHours()) {
      _showErrorMessage(
          'Sorry, requests cannot be submitted outside working hours');
      return;
    }

    final bookingDetails = await _showBookingDetailsDialog();
    if (bookingDetails == null) return;

    await _createBookingRequest(
        user.uid, bookingDetails.name, bookingDetails.phone);
  }

  Future<bool> _hasExistingBookingRequest(String userId) async {
    final existingRequest = await FirebaseFirestore.instance
        .collection('propertyBookings')
        .where('userId', isEqualTo: userId)
        .where('propertyId', isEqualTo: widget.property.id)
        .get();

    return existingRequest.docs.isNotEmpty;
  }

  Future<bool> _isWithinWorkingHours() async {
    return await WorkingHours.isServiceAvailable();
  }

  Future<({String name, String phone})?> _showBookingDetailsDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    bool? dialogResult = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          l10n.requestProperty,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBookingTextField(
                controller: nameController,
                labelText: l10n.fullName,
                hintText: l10n.enterFullName,
                icon: Iconsax.user,
              ),
              const SizedBox(height: 16),
              _buildBookingTextField(
                controller: phoneController,
                labelText: l10n.phoneNumber,
                hintText: l10n.enterPhoneNumber,
                icon: Iconsax.call,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              l10n.cancel,
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_validateBookingForm(
                  nameController.text, phoneController.text)) {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.fillAllFields,
                        style: GoogleFonts.poppins(color: Colors.white)),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              l10n.submit,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (dialogResult != true) return null;

    return (name: nameController.text, phone: phoneController.text);
  }

  Widget _buildBookingTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.white,
        border: InputBorder.none,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
        labelStyle: GoogleFonts.poppins(color: Colors.black),
      ),
      style: GoogleFonts.poppins(color: Colors.black),
    );
  }

  bool _validateBookingForm(String name, String phone) {
    return name.isNotEmpty && phone.isNotEmpty;
  }

  Future<void> _createBookingRequest(
      String userId, String userName, String userPhone) async {
    setState(() => _isLoading = true);

    try {
      final bookingRef =
          FirebaseFirestore.instance.collection('propertyBookings').doc();

      await bookingRef.set({
        'id': bookingRef.id,
        'propertyId': widget.property.id,
        'propertyTitle': widget.property.title,
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'price': widget.property.price,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isLoading = false);
        await _playSuccessSound();
        _showSuccessMessage('Booking request submitted successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorMessage('Failed to submit booking request');
      }
    }
  }

  // PDF generation and sharing
  Future<void> _generateAndDownloadPDF() async {
    setState(() => _isLoading = true);

    try {
      final pdf = pw.Document();
      final processedImages = await _downloadPropertyImagesForPdf();

      _addPropertyDetailsToPdf(pdf, processedImages);
      await _sharePdfDocument(pdf);
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Error generating PDF: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _downloadPropertyImagesForPdf() async {
    final List<Map<String, dynamic>> processedImages = [];

    if (widget.property.images.isEmpty) {
      return processedImages;
    }

    for (var image in widget.property.images) {
      try {
        final imageUrl = image['url'] as String;
        final response = await http.get(Uri.parse(imageUrl));

        if (response.statusCode == 200) {
          final imageBytes = response.bodyBytes;
          final pdfImage = pw.MemoryImage(imageBytes);

          processedImages.add({
            'image': pdfImage,
            'label': 'Property Image',
          });
        }
      } catch (e) {
        debugPrint('Error downloading image for PDF: $e');
        // Continue with other images even if one fails
      }
    }

    return processedImages;
  }

  void _addPropertyDetailsToPdf(
      pw.Document pdf, List<Map<String, dynamic>> processedImages) {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          _buildPdfHeaderSection(),
          _buildPdfFeaturesSection(),
          _buildPdfDescriptionSection(),
          _buildPdfContactSection(),
          if (processedImages.isNotEmpty)
            _buildPdfImagesSection(processedImages),
        ],
      ),
    );
  }

  pw.Widget _buildPdfHeaderSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          widget.property.title,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Price: EGP ${widget.property.price}',
          style: const pw.TextStyle(fontSize: 18),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Location: ${widget.property.location}',
          style: const pw.TextStyle(fontSize: 16),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfFeaturesSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Property Features:',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text('Bedrooms: ${widget.property.bedrooms}'),
        pw.Text('Bathrooms: ${widget.property.bathrooms}'),
        pw.Text('Property Type: ${widget.property.type}'),
        pw.Text('Gender: ${widget.property.gender}'),
        pw.Text('WiFi: ${widget.property.hasWifi ? "Yes" : "No"}'),
        pw.Text('Air Conditioning: ${widget.property.airCond ? "Yes" : "No"}'),
        if (widget.property.hasInsurance > 0)
          pw.Text('Insurance: EGP ${widget.property.hasInsurance}'),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfDescriptionSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Description:',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          widget.property.description,
          style: const pw.TextStyle(fontSize: 14),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfContactSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Contact Information:',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text('Phone: ${widget.property.agentPhone}'),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfImagesSection(List<Map<String, dynamic>> processedImages) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Property Images:',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var processedImage in processedImages)
              pw.Container(
                width: 200,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.ClipRRect(
                      horizontalRadius: 8,
                      verticalRadius: 8,
                      child: pw.Container(
                        width: 180,
                        height: 180,
                        child: pw.Image(
                          processedImage['image'] as pw.MemoryImage,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Container(
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        processedImage['label'] as String,
                        style: const pw.TextStyle(fontSize: 12),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _sharePdfDocument(pw.Document pdf) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = _generatePdfFileName();
    final filePath = '${dir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    if (!mounted) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Property Details: ${widget.property.title}',
    );
  }

  String _generatePdfFileName() {
    return '${widget.property.title.replaceAll(' ', '_')}_details.pdf';
  }

  // Load the custom property marker icon
  Future<void> _loadPropertyMarkerIcon() async {
    final homeIcon = await _createResizedMarkerIcon();
    setState(() {
      _propertyMarkerIcon = homeIcon;
    });
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

    // Create a very small icon (90x90 pixels)
    final int targetWidth = 90;
    final int targetHeight = 90;

    // Create a canvas to draw the resized image
    final pictureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(pictureRecorder);

    // Add a glowing effect (radial gradient around the image)
    final Rect glowRect =
        Rect.fromLTRB(-10, -10, targetWidth + 10, targetHeight + 10);

    // Draw the glow effect
    final Paint glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0)
      ..style = PaintingStyle.fill;

    // Create a radial gradient shader
    final Offset center = Offset(targetWidth / 2, targetHeight / 2);
    final double radius = targetWidth / 1.5;
    final List<Color> colors = [
      Colors.white.withOpacity(0.7),
      Colors.white.withOpacity(0.5),
      Colors.white.withOpacity(0.2),
      Colors.white.withOpacity(0.0),
    ];
    final List<double> stops = [0.0, 0.3, 0.6, 1.0];

    // Apply the shader to the paint
    glowPaint.shader = ui.Gradient.radial(
      center,
      radius,
      colors,
      stops,
    );

    canvas.drawCircle(
      center,
      targetWidth / 2,
      glowPaint,
    );

    // Draw the image with a specific size (slightly smaller than the glow)
    const double imagePadding = 15.0;
    canvas.drawImageRect(
      image,
      Rect.fromLTRB(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTRB(imagePadding, imagePadding, targetWidth - imagePadding,
          targetHeight - imagePadding),
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

  void _navigateToAgentsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AgentsPage(),
      ),
    );
  }
}

extension PropertyExtensions on Property {
  void openInMaps() async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}';
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      debugPrint('Could not open maps: $e');
    }
  }
}
