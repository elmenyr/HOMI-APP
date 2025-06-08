// ignore_for_file: avoid_print

import 'package:feature_discovery/feature_discovery.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homi/app_data.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:homi/firebase_options.dart';
import 'package:homi/app.dart';
import 'package:homi/app_loader.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homi/services/messaging_service.dart';
import 'package:provider/provider.dart';
import 'package:homi/providers/language_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:homi/models/property.dart';
import 'package:homi/pages/property_details_page.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
  print("Message data: ${message.data}");
  print("Message notification: ${message.notification?.title}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set background message handler before any other Firebase Messaging usage
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions immediately
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );
  print('User granted permission: ${settings.authorizationStatus}');

  // Get the token and save it
  String? token = await messaging.getToken();
  print('FCM Token: $token');
  if (token != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  // Initialize messaging service
  try {
    await MessagingService().initialize();
    print('Messaging service initialized successfully');
  } catch (e) {
    print('Error initializing messaging service: $e');
  }

  // Configure Firebase Storage
  FirebaseStorage.instance.setMaxUploadRetryTime(const Duration(seconds: 3));
  FirebaseStorage.instance.setMaxOperationRetryTime(const Duration(seconds: 3));

  // Initialize App Check
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // Configure image caching to prevent images from disappearing
  await DefaultCacheManager()
      .emptyCache(); // Clear any corrupt cache entries on startup
  CachedNetworkImage.logLevel =
      CacheManagerLogLevel.warning; // Set log level to debug image issues

  // Run the app with shared MessagingService navigatorKey
  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: languageProvider.currentLocale,
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            navigatorKey: MessagingService().navigatorKey,
            routes: {
              '/propertyDetails': (context) {
                final args = ModalRoute.of(context)!.settings.arguments
                    as Map<String, dynamic>;
                final propertyId = args['propertyId'] as String;
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('properties')
                      .doc(propertyId)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Scaffold(
                        body: Center(child: Text('Error loading property')),
                      );
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Scaffold(
                        body: Center(child: Text('Property not found')),
                      );
                    }
                    final propertyData = snapshot.data!;
                    final property = Property.fromFirestore(propertyData);
                    return FeatureDiscovery(
                      child: PropertyDetailsPage(property: property),
                    );
                  },
                );
              },
            },
            builder: (context, child) {
              return Directionality(
                textDirection: languageProvider.isArabic
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: child!,
              );
            },
            theme: ThemeData(
              useMaterial3: true,
              primaryColor: Colors.green,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.green,
                primary: Colors.green,
                secondary: Colors.green.shade700,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
            home: FeatureDiscovery(
              child: const AppLoader(),
            ),
          );
        },
      ),
    ),
  );
}

// Lifecycle event handler for Firebase cleanup
class LifecycleEventHandler extends WidgetsBindingObserver {
  final Future<void> Function() detachedCallBack;

  LifecycleEventHandler({required this.detachedCallBack});

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.detached) {
      await detachedCallBack();
    }
  }
}
