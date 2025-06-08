import 'package:flutter/material.dart';
import 'package:homi/services/preload_service.dart';
import 'package:homi/login_page.dart';
import 'package:animate_do/animate_do.dart';

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isDataLoaded = false;
  bool _isAnimationComplete = false;

  void _checkAndNavigate() {
    // Only navigate when both animation is complete and data is loaded
    if (_isDataLoaded && _isAnimationComplete && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Listen for animation completion
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimationComplete = true;
        });
        _checkAndNavigate();
      }
    });

    // Start preloading immediately
    _preloadData();
    _controller.forward();
  }

  Future<void> _preloadData() async {
    try {
      // Ensure minimum display time of 2 seconds for splash screen
      await Future.wait([
        PreloadService().preloadHomePageData(),
        Future.delayed(const Duration(seconds: 2)),
      ]);
      
      if (mounted) {
        setState(() {
          _isDataLoaded = true;
        });
        _checkAndNavigate();
      }
    } catch (e) {
      debugPrint('Error preloading data: $e');
      // Even if there's an error, we should proceed after splash screen
      if (mounted) {
        setState(() {
          _isDataLoaded = true;
        });
        _checkAndNavigate();
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeInDown(
              duration: const Duration(milliseconds: 1500),
              child: Image.asset(
                'assets/images/home.png',
                width: 150,
                height: 150,
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              duration: const Duration(milliseconds: 1500),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        colors: [
                          Color(0xFFF17575), // Darker salmon pink
                          Color(0xFFFFA0A0), // Lighter salmon pink
                        ],
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'HO',
                      style: TextStyle(
                        fontSize: 24,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        colors: [
                          Color(0xFFCEE26B), // Darker lime green
                          Color(0xFFDDEEA0), // Lighter lime green
                        ],
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'MI',
                      style: TextStyle(
                        fontSize: 24,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            if (!_isDataLoaded)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                  strokeWidth: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }
} 