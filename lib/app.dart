// ignore_for_file: avoid_print, lines_longer_than_80_chars, inference_failure_on_instance_creation, prefer_int_literals, deprecated_member_use, directives_ordering, dead_code, omit_local_variable_types, prefer_const_constructors

import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:homi/app_data.dart';
import 'package:homi/login_page.dart';
import 'package:homi/models/admin_user.dart';
import 'package:homi/pages/add_service_page.dart';
import 'package:homi/pages/admin_requests_page.dart';
import 'package:homi/pages/favorites_page.dart';
import 'package:homi/pages/home_page.dart';
import 'package:homi/pages/settings_page.dart';
import 'package:homi/pages/agents_page.dart';
import 'package:homi/pages/reservation_form_page.dart';
import 'package:homi/pages/admin_booked_page.dart';
import 'package:homi/pages/services_page.dart';
import 'package:homi/pages/chatbot_page.dart';
import 'package:homi/pages/map_page.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animations/animations.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:homi/utils/navigation_tour.dart';
import 'package:homi/widgets/admin_drawer.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class App extends StatefulWidget {
  const App({
    required this.data,
    this.initialRouteIndex = 0,
    this.isFirstLogin = false,
    super.key,
  });

  final AppData data;
  final int initialRouteIndex;
  final bool isFirstLogin;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _selectedIndex = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialRouteIndex;
    _checkAdminStatus();
    
    // Initialize the navigation tour after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Only show tour for first-time users
      await NavigationTour.initTour(context, _isAdmin);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    bool isAdmin = await AdminUser.isCurrentUserAdmin();
    if (mounted && isAdmin != _isAdmin) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  List<Widget> get _pages => [
        const MainHomePage(),
        const FavoritesPage(),
        ChatbotPage(apiKey: 'AIzaSyDwZoqRaIx-zRTHi04r4e5fxtAopw9nu_w'),
        const ReservationFormPage(),
        const AgentsPage(),
        const ServicesPage(),
        const SettingsPage(),
        const MapPage(),
      ];

  int _getAdjustedIndex(int index) {
    if (!_isAdmin) {
      if (index == 4) return 3;
      if (index >= 6) return index - 1;
      if (index >= 5) return index - 1;
    }
    return index;
  }

  String _getFeatureId(int index) {
    switch (index) {
      case 0:
        return NavigationTour.homeFeature;
      case 1:
        return NavigationTour.favoritesFeature;
      case 2:
        return NavigationTour.chatbotFeature;
      case 3:
        return NavigationTour.servicesFeature;
      case 4:
        return NavigationTour.settingsFeature;
      case 5:
        return 'map_feature';
      default:
        return 'unknown_feature';
    }
  }

  String _getFeatureTitle(int index) {
    final l10n = AppLocalizations.of(context)!;
    switch (index) {
      case 0:
        return l10n.navHome;
      case 1:
        return l10n.navFavorites;
      case 2:
        return "HOMI AI";
      case 3:
        return l10n.navServices;
      case 4:
        return l10n.navSettings;
      case 5:
        return "Map";
      default:
        return 'Feature';
    }
  }

  String _getFeatureDescription(int index) {
    final l10n = AppLocalizations.of(context)!;
    switch (index) {
      case 0:
        return l10n.navTourHome;
      case 1:
        return l10n.navTourFavorites;
      case 2:
        return 'تحدث مع مساعد هومي العقاري';
      case 3:
        return l10n.navTourServices;
      case 4:
        return l10n.navTourSettings;
      case 5:
        return 'View property locations on map';
      default:
        return 'Discover this feature.';
    }
  }

  List<SalomonBottomBarItem> get _navBarItems {
    final l10n = AppLocalizations.of(context)!;
    return [
        SalomonBottomBarItem(
          icon: Image.asset('assets/images/homepage.png', width: 20, height: 20),
          activeIcon: Image.asset('assets/images/homepage.png', width: 20, height: 20, color: const Color(0xFF9FE870)),
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF9FE870),
                Color(0xFF80D1FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              l10n.navHome,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          selectedColor: const Color(0xFF9FE870),
          unselectedColor: Colors.grey.shade400,
        ),
        SalomonBottomBarItem(
          icon: Image.asset('assets/images/favourite.png', width: 20, height: 20),
          activeIcon: Image.asset('assets/images/favourite.png', width: 20, height: 20, color: const Color(0xFF9FE870)),
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF9FE870),
                Color(0xFF80D1FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              l10n.navFavorites,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          selectedColor: const Color(0xFF9FE870),
          unselectedColor: Colors.grey.shade400,
        ),
        SalomonBottomBarItem(
          icon: Image.asset('assets/images/bot.png', width: 20, height: 20),
          activeIcon: Image.asset('assets/images/bot.png', width: 20, height: 20, color: const Color(0xFF9FE870)),
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF9FE870),
                Color(0xFF80D1FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              "HOMI AI",
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          selectedColor: const Color(0xFF9FE870),
          unselectedColor: Colors.grey.shade400,
        ),
        SalomonBottomBarItem(
          icon: Image.asset('assets/images/service.png', width: 20, height: 20),
          activeIcon: Image.asset('assets/images/service.png', width: 20, height: 20, color: const Color(0xFF9FE870)),
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF9FE870),
                Color(0xFF80D1FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              l10n.navServices,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          selectedColor: const Color(0xFF9FE870),
          unselectedColor: Colors.grey.shade400,
        ),
        SalomonBottomBarItem(
          icon: Image.asset('assets/images/settings.png', width: 20, height: 20),
          activeIcon: Image.asset('assets/images/settings.png', width: 20, height: 20, color: const Color(0xFF9FE870)),
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF9FE870),
                Color(0xFF80D1FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              l10n.navSettings,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          selectedColor: const Color(0xFF9FE870),
          unselectedColor: Colors.grey.shade400,
        ),
      ];
  }

  // Method to map navigation bar indices to page indices
  int _getPageIndexFromNavIndex(int navIndex) {
    switch (navIndex) {
      case 0: // Home
        return 0; // MainHomePage
      case 1: // Favorites
        return 1; // FavoritesPage
      case 2: // Chatbot 
        return 2; // ChatbotPage
      case 3: // Services
        return 5; // ServicesPage
      case 4: // Settings
        return 6; // SettingsPage
      default:
        return 0; // Default to home
    }
  }

  int _getNavIndexFromPageIndex(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 2;
      case 5:
        return 3;
      case 6:
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    int visibleIndex = _selectedIndex;
    if (_selectedIndex >= _pages.length) {
      visibleIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedIndex = 0;
        });
      });
    }

    return Directionality(
      // Force LTR layout for consistent navigation positioning
      textDirection: TextDirection.ltr,
      child: Scaffold(
        drawer: _isAdmin ? const AdminDrawer() : null,
        body: IndexedStack(
          index: visibleIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: SalomonBottomBar(
              currentIndex: _getNavIndexFromPageIndex(_selectedIndex),
              onTap: (index) {
                setState(() {
                  _selectedIndex = _getPageIndexFromNavIndex(index);
                });
              },
              items: List.generate(_navBarItems.length, (index) {
                final item = _navBarItems[index];
                return SalomonBottomBarItem(
                  icon: DescribedFeatureOverlay(
                    featureId: _getFeatureId(index),
                    tapTarget: item.icon,
                    title: Text(_getFeatureTitle(index)),
                    description: Text(_getFeatureDescription(index)),
                    backgroundColor: Colors.black,
                    targetColor: Colors.white,
                    textColor: Colors.white,
                    enablePulsingAnimation: true,
                    barrierDismissible: false,
                    overflowMode: OverflowMode.extendBackground,
                    child: item.icon,
                  ),
                  activeIcon: item.activeIcon,
                  title: item.title,
                  selectedColor: item.selectedColor,
                  unselectedColor: item.unselectedColor,
                );
              }),
              backgroundColor: Colors.white,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({
    super.key,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const MainHomePage(),
      const FavoritesPage(),
      const ServicesPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      // Use IndexedStack to preserve page states when switching tabs
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        elevation: 8,
        selectedItemColor: Colors.grey.shade800,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontSize: 16,
          fontFamily: 'Montserrat',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontFamily: 'Montserrat',
        ),
        items: [
          BottomNavigationBarItem(
            icon: Image.asset('assets/images/homepage.png', width: 28, height: 28),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/images/favourite.png', width: 28, height: 28),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/images/service.png', width: 28, height: 28),
            label: 'Services',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/images/settings.png', width: 28, height: 28),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 51),
              Text(
                'Welcome to Homi!',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Montserrat',
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Center(
                child: Image.asset(
                  'assets/images/logoo.png',
                  height: 400,
                ),
              ),
              const Spacer(),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  },
                  child: Container(
                    width: double.infinity, // Full width button
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24), // Increased padding
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Iconsax.arrow_right_3,
                          color: const Color(0xFF424242),
                          size: 24, // Increased icon size
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Let's get started",
                          style: TextStyle(
                            fontSize: 18, // Increased font size
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                            fontFamily: 'Montserrat',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}