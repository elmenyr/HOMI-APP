import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:homi/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:homi/providers/language_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:ui';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({Key? key}) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _backgroundAnimationController;
  late Animation<double> _backgroundAnimation;

  final List<OnboardingItem> _items = [
    const OnboardingItem(
      image: 'assets/images/on1.png',
      title: 'Find Your Perfect Home',
      description:
          'Discover a wide range of properties that match your preferences and lifestyle.',
      gradientColors: [Color(0xFF6448FE), Color(0xFF5FC6FF)],
    ),
    const OnboardingItem(
      image: 'assets/images/on2.png',
      title: 'Easy Booking Process',
      description:
          'Book your desired property with just a few taps and secure your stay instantly.',
      gradientColors: [Color(0xFFFF9A9E), Color(0xFFFAD0C4)],
    ),
    const OnboardingItem(
      image: 'assets/images/on3.png',
      title: 'Safe & Secure',
      description:
          'We ensure all properties are verified and transactions are secure.',
      gradientColors: [Color(0xFF08AEEA), Color(0xFF2AF598)],
    ),
    const OnboardingItem(
      image: 'assets/images/on4.png',
      title: 'Ready to Begin?',
      description:
          'Start your journey to find your perfect student accommodation today.',
      gradientColors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _backgroundAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _backgroundAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _backgroundAnimationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _backgroundAnimationController.dispose();
    super.dispose();
  }

  void _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
  }

  Widget _buildGlassmorphicContainer(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  void _showLanguageSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final languageProvider = Provider.of<LanguageProvider>(context);
            final hasSelectedLanguage = languageProvider.currentLocale.languageCode != 'en' || 
                                     context.widget.runtimeType != OnboardingPage;
            
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: FadeInUp(
                duration: const Duration(milliseconds: 300),
                child: _buildGlassmorphicContainer(
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Select Language',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 24,
                            fontFamily: 'Montserrat',
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'اختر اللغة',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                            fontSize: 20,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildLanguageButton(
                          context,
                          'English',
                          'en',
                          languageProvider,
                          onSelected: () => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        _buildLanguageButton(
                          context,
                          'العربية',
                          'ar',
                          languageProvider,
                          onSelected: () => setState(() {}),
                        ),
                        if (hasSelectedLanguage) ...[
                          const SizedBox(height: 24),
                          FadeInUp(
                            duration: const Duration(milliseconds: 200),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushReplacement(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    },
                                    transitionDuration: const Duration(milliseconds: 500),
                                  ),
                                );
                              },
                              child: _buildGlassmorphicContainer(
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        languageProvider.currentLocale.languageCode == 'ar' 
                                            ? 'ابدأ' 
                                            : 'Start',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Montserrat',
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 20,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildLanguageButton(
    BuildContext context,
    String label,
    String languageCode,
    LanguageProvider languageProvider, {
    required VoidCallback onSelected,
  }) {
    final isSelected = languageProvider.currentLocale.languageCode == languageCode;
    
    return GestureDetector(
      onTap: () async {
        await languageProvider.changeLanguage(languageCode);
        onSelected();
      },
      child: _buildGlassmorphicContainer(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontFamily: 'Montserrat',
                  letterSpacing: 0.2,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: Colors.white.withOpacity(0.9),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _items[_currentPage].gradientColors[0],
                      _items[_currentPage].gradientColors[1],
                    ],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _items.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
                _backgroundAnimationController.forward(from: 0);
              },
              itemBuilder: (context, index) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    FadeInDown(
                      duration: const Duration(milliseconds: 800),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.35,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          _items[index].image,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                    FadeInUp(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: _buildGlassmorphicContainer(
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Text(
                                  _items[index].title,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Montserrat',
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _items[index].description,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white.withOpacity(0.9),
                                    fontFamily: 'Montserrat',
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (index == _items.length - 1)
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: GestureDetector(
                            onTap: () {
                              _markOnboardingComplete();
                              _showLanguageSelectionDialog(context);
                            },
                            child: _buildGlassmorphicContainer(
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      "Let's Start",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Montserrat',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                _markOnboardingComplete();
                                _showLanguageSelectionDialog(context);
                              },
                              child: _buildGlassmorphicContainer(
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    'Skip',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: List.generate(
                                _items.length,
                                (i) => Container(
                                  width: i == _currentPage ? 32 : 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(
                                      i == _currentPage ? 0.9 : 0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: _buildGlassmorphicContainer(
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      const Text(
                                        'Next',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 16,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingItem {
  final String image;
  final String title;
  final String description;
  final List<Color> gradientColors;

  const OnboardingItem({
    required this.image,
    required this.title,
    required this.description,
    required this.gradientColors,
  });
}
