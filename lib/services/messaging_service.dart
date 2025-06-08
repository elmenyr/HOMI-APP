import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  factory MessagingService() {
    return _instance;
  }

  MessagingService._internal();

  Future<void> initialize() async {
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    print('User granted permission: ${settings.authorizationStatus}');

    // Get FCM token
    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');

    // Enable Firebase Messaging auto-init
    await _firebaseMessaging.setAutoInitEnabled(true);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message notification title: ${message.notification?.title}');
        print('Message notification body: ${message.notification?.body}');
      }
    });
    
    // Handle when app is opened from a notification when in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A notification was tapped: ${message.data}');
      _handleNotificationNavigation(message);
    });

    // Handle when app is opened from a notification when terminated
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('App opened from terminated state via notification');
      _handleNotificationNavigation(initialMessage);
    }

    // Subscribe to 'all' topic to receive broadcast messages
    await _firebaseMessaging.subscribeToTopic('all');
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    // Extract route and propertyId from data payload
    if (message.data.containsKey('route')) {
      String route = message.data['route'] as String;
      String? propertyId = message.data['propertyId'] as String?;
      
      if (route == 'propertyDetails' && propertyId != null && propertyId.isNotEmpty) {
        // Navigate to property details page
        navigatorKey.currentState?.pushNamed(
          '/propertyDetails',
          arguments: {'propertyId': propertyId},
        );
      } else {
        print('Invalid navigation data: route=$route, propertyId=$propertyId');
      }
    }
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }
} 