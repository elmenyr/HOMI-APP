// ignore_for_file: directives_ordering, sort_constructors_first, avoid_void_async, lines_longer_than_80_chars, unawaited_futures, sort_unnamed_constructors_first

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class Property {
  final String id;
  final String title;
  final double price;
  final String location;
  final String imageUrl;
  final int bedrooms;
  final int bathrooms;
  final bool airCond;
  final String description;
  final String type;
  final String gender;
  final DateTime createdAt;
  final String agentPhone;
  final double latitude;
  final double longitude;
  final bool isAvailable;
  final bool hasWifi;
  final String? vrTourUrl;
  final String? videoUrl;
  final int hasInsurance; // Changed from bool to int
  final double rating;
  final int ratingCount;
  final List<String> photos;
  final List<Map<String, dynamic>> images;
  final String plan;
  final List<Map<String, dynamic>> tenants; // List of tenants in this property
  double? distance;

  List<Map<String, String>> get labeledPhotos {
    return images
        .map((photo) => {
              'url': photo['url'] as String,
              'label': photo['label'] as String,
            })
        .toList();
  }

  Property({
    required this.id,
    required this.title,
    required this.price,
    required this.location,
    required this.imageUrl,
    required this.bedrooms,
    required this.bathrooms,
    required this.airCond,
    required this.description,
    required this.type,
    required this.gender,
    required this.createdAt,
    required this.agentPhone,
    required this.latitude,
    required this.longitude,
    required this.isAvailable,
    required this.hasWifi,
    required this.hasInsurance,
    this.vrTourUrl,
    this.videoUrl,
    this.plan = 'Free',
    this.rating = 0.0,
    this.ratingCount = 0,
    this.photos = const [],
    this.tenants = const [],
    List<Map<String, String>>? labeledPhotos,
  }) : images = labeledPhotos
                ?.map((photo) =>
                    {'url': photo['url'] ?? '', 'label': photo['name'] ?? ''})
                .toList() ??
            const [];

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'location': location,
      'imageUrl': imageUrl,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'airCond': airCond,
      'description': description,
      'type': type,
      'gender': gender,
      'plan': plan,
      'createdAt': createdAt,
      'agentPhone': agentPhone,
      'coordinates': GeoPoint(latitude, longitude),
      'isAvailable': isAvailable,
      'hasWifi': hasWifi,
      'vrTourUrl': vrTourUrl,
      'videoUrl': videoUrl,
      'hasInsurance': hasInsurance,
      'rating': rating,
      'ratingCount': ratingCount,
      'photos': photos,
      'images': images,
      'tenants': tenants,
    };
  }

  factory Property.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final geoPoint = data['coordinates'] as GeoPoint?;

    return Property(
      hasInsurance: (data['hasInsurance'] as num?)?.toInt() ?? 0,
      id: data['id'] as String? ?? doc.id,
      title: _parseString(data['title']),
      price: _parseDouble(data['price']),
      location: _parseString(data['location']),
      imageUrl: _parseString(data['imageUrl']),
      bedrooms: _parseInt(data['bedrooms']),
      bathrooms: _parseInt(data['bathrooms']),
      airCond: data['airCond'] as bool? ?? false,
      description: _parseString(data['description']),
      photos: (data['photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      type: _parseString(data['type'], defaultValue: 'All'),
      gender: _parseString(data['gender'], defaultValue: 'Any'),
      plan: _parseString(data['plan'], defaultValue: 'Free'),
      createdAt: _parseTimestamp(data['createdAt']),
      agentPhone: _parseString(data['agentPhone']),
      latitude: geoPoint?.latitude ?? 30.0444,
      longitude: geoPoint?.longitude ?? 31.2357,
      isAvailable: data['isAvailable'] as bool? ?? true,
      hasWifi: data['hasWifi'] as bool? ?? false,
      vrTourUrl: _parseString(data['vrTourUrl']),
      videoUrl: _parseString(data['videoUrl']),
      rating: _parseDouble(data['rating']),
      ratingCount: _parseInt(data['ratingCount']),
      tenants: _parseTenants(data['tenants']),
      labeledPhotos: _parseImages(data['images'])
          .map((image) => {
                'url': image['url'] as String,
                'name': image['label'] as String,
              })
          .toList(),
    );
  }

  static String _parseString(dynamic value, {String defaultValue = ''}) {
    return value is String ? value : defaultValue;
  }

  static double _parseDouble(dynamic value) {
    return value is num ? value.toDouble() : 0.0;
  }

  static int _parseInt(dynamic value) {
    return value is int ? value : 0;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static List<Map<String, dynamic>> _parseImages(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];

    return (value).map((item) {
      if (item is! Map) return {'url': '', 'label': ''};
      final map = item;
      return {
        'url': (map['url'] ?? '').toString(),
        'label': (map['label'] ?? map['name'] ?? '').toString()
      };
    }).toList();
  }
  
  static List<Map<String, dynamic>> _parseTenants(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    
    return (value).map((item) {
      if (item is! Map) return {
        'userId': '',
        'type': 'bed',
        'startDate': DateTime.now(),
      };
      
      final map = item;
      final startDate = map['startDate'];
      DateTime parsedStartDate;
      
      if (startDate is Timestamp) {
        parsedStartDate = startDate.toDate();
      } else if (startDate is DateTime) {
        parsedStartDate = startDate;
      } else {
        parsedStartDate = DateTime.now();
      }
      
      return {
        'userId': (map['userId'] ?? '').toString(),
        'type': (map['type'] ?? 'bed').toString(),
        'startDate': parsedStartDate,
      };
    }).toList();
  }

  String get mapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  void openInMaps() async {
    final url = mapsUrl;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error launching maps: $e');
    }
  }

  // Generate a unique cache key for image loading
  String getImageCacheKey() {
    // Use only the property ID for consistent caching
    // This ensures the image is loaded from cache most of the time
    return id;
  }

  // Generate a cache-busting key when image needs to be refreshed
  String getRefreshImageCacheKey() {
    // Add timestamp to force a cache miss and reload the image
    return '${id}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<WebViewController?> initializeWebView() async {
    if (vrTourUrl == null || vrTourUrl!.isEmpty) {
      print('VR Tour URL is empty, skipping WebView initialization.');
      return null;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {
            print('Page started loading: $url');
          },
          onPageFinished: (String url) {
            print('Page finished loading: $url');
          },
          onWebResourceError: (WebResourceError error) {
            print('Web resource error: ${error.description}');
          },
        ),
      );

    try {
      await controller.loadRequest(Uri.parse(vrTourUrl!));
    } catch (e) {
      print('Failed to load VR Tour URL: $e');
    }

    return controller;
  }

  // Update fromMap method
  factory Property.fromMap(Map<String, dynamic> map, String id) {
    return Property(
      hasInsurance: _parseInt(map['hasInsurance']), // Changed to use _parseInt
      id: id,
      title: _parseString(map['title']),
      price: _parseDouble(map['price']),
      location: _parseString(map['location']),
      imageUrl: _parseString(map['imageUrl']),
      bedrooms: _parseInt(map['bedrooms']),
      bathrooms: _parseInt(map['bathrooms']),
      airCond: map['airCond'] as bool? ?? false,
      description: _parseString(map['description']),
      type: _parseString(map['type'], defaultValue: 'All'),
      gender: _parseString(map['gender'], defaultValue: 'Any'),
      plan: _parseString(map['plan'], defaultValue: 'Free'),
      createdAt: _parseTimestamp(map['createdAt']),
      agentPhone: _parseString(map['agentPhone']),
      latitude:
          (map['coordinates'] as GeoPoint?)?.latitude ?? 30.87948347670811,
      longitude:
          (map['coordinates'] as GeoPoint?)?.longitude ?? 32.37215539693462,
      isAvailable: map['isAvailable'] as bool? ?? true,
      hasWifi: map['hasWifi'] as bool? ?? false,
      vrTourUrl: _parseString(map['vrTourUrl']),
      labeledPhotos: _parseImages(map['images'])
          .map((image) =>
              {'url': image['url'] as String, 'name': image['label'] as String})
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hasInsurance': hasInsurance,
      'title': title,
      'price': price,
      'location': location,
      'imageUrl': imageUrl,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'airCond': airCond,
      'description': description,
      'type': type,
      'gender': gender,
      'plan': plan,
      'createdAt': Timestamp.fromDate(createdAt),
      'agentPhone': agentPhone,
      'coordinates': GeoPoint(latitude, longitude),
      'isAvailable': isAvailable,
      'hasWifi': hasWifi,
      'vrTourUrl': vrTourUrl,
    };
  }
}
