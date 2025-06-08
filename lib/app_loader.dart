// ignore_for_file: lines_longer_than_80_chars, directives_ordering

import 'package:flutter/material.dart';
import 'package:homi/app.dart';
import 'package:homi/app_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:homi/login_page.dart';
import 'package:homi/onboarding_page.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:homi/utils/navigation_tour.dart';

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Add new fields to track loading state
  late Future<AppData> _appDataFuture;
  late Future<SharedPreferences> _prefsFuture;
  bool _animationComplete = false;

  @override
  void initState() {
    super.initState();
    // Start loading data immediately
    _appDataFuture = AppData.load().timeout(
      const Duration(seconds: 5),
      onTimeout: () => const AppData(),
    );
    _prefsFuture = SharedPreferences.getInstance();
    
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
    ));

    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 0.9, curve: Curves.easeIn),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 0.9, curve: Curves.easeOut),
    ));

    // Start animation and handle its completion
    _controller.forward().then((_) {
      _animationComplete = true;
      _tryNavigate();
    });
  }

  Future<void> _tryNavigate() async {
    if (!mounted) return;
    
    try {
      // Wait for both the app data and preferences to be loaded
      final results = await Future.wait([
        _appDataFuture,
        _prefsFuture,
      ]);
      
      if (!_animationComplete || !mounted) return;

      final appData = results[0] as AppData;
      final prefs = results[1] as SharedPreferences;
      
      final onboardingComplete = prefs.getBool('onboardingComplete') ?? false;

      if (!onboardingComplete) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (context) => const OnboardingPage(),
          ),
        );
        return;
      }

      // Check if user is logged in
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        await NavigationTour.forceShowOnNextInit();

        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (context) => FeatureDiscovery(
              child: App(
                data: appData,
                isFirstLogin: true,
              ),
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (context) => const LoginPage(),
          ),
        );
      }
    } catch (e) {
      // Handle any errors during loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading app: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack( 
        children: [
          FadeTransition(
            opacity: _fadeInAnimation,
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.6, // 60% of screen width
                height: MediaQuery.of(context).size.width * 0.6, // Keep it square
                child: Lottie.asset(
                  'assets/Animation - 1745981769604.json',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _textOpacityAnimation,
                child: const Text(
                  '',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
