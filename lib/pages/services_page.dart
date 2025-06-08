// ignore_for_file: lines_longer_than_80_chars, directives_ordering
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'add_service_page.dart';
import 'service_details_page.dart';
import '../components/transportation_section.dart';
import '../components/section_divider.dart';
import '../components/home_assistance_section.dart';
import '../components/medical_services_section.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedUniversity;
  String? _selectedCategory;
  bool _isAdmin = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _fabController;
  late Animation<double> _fabScale;
  final ScrollController _scrollController = ScrollController();

  // Add section keys for navigation
  final GlobalKey _transportationKey = GlobalKey();
  final GlobalKey _homeAssistanceKey = GlobalKey();
  final GlobalKey _servicesKey = GlobalKey();
  final GlobalKey _medicalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _fabScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _fabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isAdmin = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() => _isAdmin = userDoc.exists);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAdmin = false);
      }
    }
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Glassmorphic App Bar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.8),
                      Colors.grey.shade100.withOpacity(0.9),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(24)),
                          border: Border(
                              bottom: BorderSide(
                                  color:
                                      Colors.orange.shade100.withOpacity(0.3))),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/supply.png',
                                width: 24,
                                height: 24,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Iconsax.shop,
                                    size: 24,
                                    color: Colors.black,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Services',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Morphing Search Bar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.teal.shade100.withOpacity(0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade300.withOpacity(0.5),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search services...',
                                hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey.shade600),
                                prefixIcon: Icon(Iconsax.search_normal,
                                    color: Colors.teal.shade300),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
                              style: GoogleFonts.poppins(color: Colors.black),
                              onChanged: (value) {
                                setState(() => _searchQuery = value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Transportation Section
          SliverToBoxAdapter(
            child: Container(
              key: _transportationKey,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SectionDivider(
                    title: 'Transportation',
                    icon: Icons.directions_bus,
                    color: Colors.blue.shade400,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TransportationSection(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Home Assistance Section
          SliverToBoxAdapter(
            child: Container(
              key: _homeAssistanceKey,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SectionDivider(
                    title: 'Home Assistance',
                    icon: Icons.home_repair_service,
                    color: Colors.purple.shade400,
                  ),
                  const HomeAssistanceSection(),
                ],
              ),
            ),
          ),
          // Medical Services Section
          SliverToBoxAdapter(
            child: Container(
              key: _medicalKey,
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: MedicalServicesSection(isAdmin: _isAdmin),
            ),
          ),
          // Services Filter Section
          SliverToBoxAdapter(
            child: Container(
              key: _servicesKey,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionDivider(
                    title: 'Available Services',
                    icon: Iconsax.shop,
                    color: Colors.teal.shade400,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 600) {
                          // Mobile layout - vertical stacking
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('universities')
                                    .orderBy('name')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(
                                        child: CircularProgressIndicator(
                                            color: Colors.black));
                                  }

                                  final universities = snapshot.data!.docs
                                      .map((doc) => doc['name'] as String)
                                      .toList();
                                  final universityOptions = [
                                    'All',
                                    ...universities
                                  ];

                                  return AnimatedDropdown(
                                    value: _selectedUniversity,
                                    items: universityOptions,
                                    hint: 'Select University',
                                    accentColor: Colors.orange.shade200,
                                    onChanged: (value) {
                                      setState(() => _selectedUniversity =
                                          value == 'All' ? null : value);
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('categories')
                                    .orderBy('name')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(
                                        child: CircularProgressIndicator(
                                            color: Colors.black));
                                  }

                                  final categories = snapshot.data!.docs
                                      .map((doc) => doc['name'] as String)
                                      .toList();
                                  final categoryOptions = [
                                    'All',
                                    ...categories
                                  ];

                                  return AnimatedDropdown(
                                    value: _selectedCategory,
                                    items: categoryOptions,
                                    hint: 'Select Category',
                                    accentColor: Colors.purple.shade200,
                                    onChanged: (value) {
                                      setState(() => _selectedCategory =
                                          value == 'All' ? null : value);
                                    },
                                  );
                                },
                              ),
                            ],
                          );
                        } else {
                          // Desktop layout - horizontal arrangement
                          return Row(
                            children: [
                              Expanded(
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('universities')
                                      .orderBy('name')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Center(
                                          child: CircularProgressIndicator(
                                              color: Colors.black));
                                    }

                                    final universities = snapshot.data!.docs
                                        .map((doc) => doc['name'] as String)
                                        .toList();
                                    final universityOptions = [
                                      'All',
                                      ...universities
                                    ];

                                    return AnimatedDropdown(
                                      value: _selectedUniversity,
                                      items: universityOptions,
                                      hint: 'Select University',
                                      accentColor: Colors.orange.shade200,
                                      onChanged: (value) {
                                        setState(() => _selectedUniversity =
                                            value == 'All' ? null : value);
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('categories')
                                      .orderBy('name')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Center(
                                          child: CircularProgressIndicator(
                                              color: Colors.black));
                                    }

                                    final categories = snapshot.data!.docs
                                        .map((doc) => doc['name'] as String)
                                        .toList();
                                    final categoryOptions = [
                                      'All',
                                      ...categories
                                    ];

                                    return AnimatedDropdown(
                                      value: _selectedCategory,
                                      items: categoryOptions,
                                      hint: 'Select Category',
                                      accentColor: Colors.purple.shade200,
                                      onChanged: (value) {
                                        setState(() => _selectedCategory =
                                            value == 'All' ? null : value);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Services List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            sliver: StreamBuilder<QuerySnapshot>(
              stream: _buildServicesQuery(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: GoogleFonts.poppins(color: Colors.red.shade600),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const SliverToBoxAdapter(
                    child: Center(
                        child: CircularProgressIndicator(color: Colors.black)),
                  );
                }

                final services = snapshot.data!.docs;

                if (services.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Iconsax.search_normal,
                            size: 48,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No services found',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final service =
                          services[index].data() as Map<String, dynamic>;
                      return ServiceCard(
                        service: service,
                        serviceId: services[index].id,
                        index: index,
                        onTap: () {
                          _navigateToServiceDetails(
                              context, services[index].id, service);
                        },
                        isAdmin: _isAdmin,
                      );
                    },
                    childCount: services.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'transportation_fab',
            onPressed: () => _scrollToSection(_transportationKey),
            backgroundColor: Colors.blue.shade400,
            child: const Icon(Icons.directions_bus, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'home_assistance_fab',
            onPressed: () => _scrollToSection(_homeAssistanceKey),
            backgroundColor: Colors.purple.shade400,
            child: const Icon(Icons.home_repair_service, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'medical_fab',
            onPressed: () => _scrollToSection(_medicalKey),
            backgroundColor: Colors.red.shade400,
            child: const Icon(Iconsax.health, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'services_fab',
            onPressed: () => _scrollToSection(_servicesKey),
            backgroundColor: Colors.teal.shade400,
            child: const Icon(Iconsax.shop, color: Colors.white),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 16),
            ScaleTransition(
              scale: _fabScale,
              child: FloatingActionButton(
                heroTag: 'add_service_fab',
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddServicePage(),
                    ),
                  ).then((_) => setState(() {}));
                },
                backgroundColor: Colors.black,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildServicesQuery() {
    Query query = FirebaseFirestore.instance.collection('services');

    if (_selectedUniversity != null) {
      query = query.where('university', isEqualTo: _selectedUniversity);
    }

    if (_selectedCategory != null) {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    if (_searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: _searchQuery)
          .where('name', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
    }

    return query.snapshots();
  }

  // Helper method to navigate to service details with proper back navigation
  void _navigateToServiceDetails(BuildContext context, String serviceId,
      Map<String, dynamic> serviceData) async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ServiceDetailsPage(
          serviceId: serviceId,
          serviceData: serviceData,
        ),
      ),
    );

    // Refresh the state when returning from service details
    if (mounted) {
      setState(() {
        // This forces a rebuild of the UI
      });
    }
  }

  // Delete a service from Firestore
  Future<void> deleteService(String serviceId) async {
    try {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Delete Service',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to delete this service? This action cannot be undone.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey.shade700),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(
                    color: Colors.red.shade600, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          elevation: 5,
        ),
      );

      if (confirm != true) return;

      // Delete the service
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Service deleted successfully',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting service: $e',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // Navigate to edit service page
  Future<void> editService(
      String serviceId, Map<String, dynamic> serviceData) async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddServicePage(
            serviceId: serviceId,
            serviceData: serviceData,
          ),
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error editing service: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

class AnimatedDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String hint;
  final Color accentColor;
  final ValueChanged<String?> onChanged;

  const AnimatedDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.hint,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ButtonTheme(
        alignedDropdown: true,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text(
              hint,
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight:
                        item == value ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            icon: Icon(
              Iconsax.arrow_down_1,
              color: accentColor,
              size: 20,
            ),
            isExpanded: true,
            dropdownColor: Colors.white,
            elevation: 3,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            borderRadius: BorderRadius.circular(12),
            menuMaxHeight: 300,
            style: GoogleFonts.poppins(color: Colors.black),
          ),
        ),
      ),
    );
  }
}

class ServiceCard extends StatefulWidget {
  final Map<String, dynamic> service;
  final String serviceId;
  final int index;
  final VoidCallback onTap;
  final bool isAdmin;

  const ServiceCard({
    super.key,
    required this.service,
    required this.serviceId,
    required this.index,
    required this.onTap,
    required this.isAdmin,
  });

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  vector.Vector3 _tilt = vector.Vector3(0, 0, 0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600 + widget.index * 100),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateTilt(Offset position, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final dx = (position.dx - centerX) / centerX;
    final dy = (position.dy - centerY) / centerY;
    setState(() {
      _tilt = vector.Vector3(dy * 10, -dx * 10, 0);
    });
  }

  void _resetTilt() {
    setState(() {
      _tilt = vector.Vector3(0, 0, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.service['category'] as String? ?? 'Other';
    Widget cardContent;

    switch (category) {
      case 'Restaurant':
        cardContent =
            RestaurantCard(service: widget.service, onTap: widget.onTap);
        break;
      case 'Supermarket':
        cardContent =
            SupermarketCard(service: widget.service, onTap: widget.onTap);
        break;
      case 'Copy Center':
        cardContent =
            CopyCenterCard(service: widget.service, onTap: widget.onTap);
        break;
      default:
        cardContent = DefaultCard(service: widget.service, onTap: widget.onTap);
        break;
    }

    return GestureDetector(
      onPanUpdate: (details) {
        final size = context.size!;
        _updateTilt(details.localPosition, size);
      },
      onPanEnd: (_) => _resetTilt(),
      child: Stack(
        children: [
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(_tilt.x * vector.degrees2Radians)
              ..rotateY(_tilt.y * vector.degrees2Radians),
            alignment: Alignment.center,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: cardContent,
            ),
          ),

          // Admin Controls Overlay
          if (widget.isAdmin)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  // Edit Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      color: Colors.blue.shade700,
                      onPressed: () {
                        // Get the ServicesPage instance to call editService
                        final servicesPage = context
                            .findAncestorStateOfType<_ServicesPageState>();
                        servicesPage?.editService(
                            widget.serviceId, widget.service);
                      },
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: const EdgeInsets.all(6),
                      splashRadius: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      color: Colors.red.shade600,
                      onPressed: () {
                        // Get the ServicesPage instance to call deleteService
                        final servicesPage = context
                            .findAncestorStateOfType<_ServicesPageState>();
                        servicesPage?.deleteService(widget.serviceId);
                      },
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: const EdgeInsets.all(6),
                      splashRadius: 20,
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

class RestaurantCard extends StatefulWidget {
  final Map<String, dynamic> service;
  final VoidCallback onTap;

  const RestaurantCard({super.key, required this.service, required this.onTap});

  @override
  State<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<RestaurantCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _iconOpacity;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _iconOpacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.orange.shade300.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade700.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Image Placeholder
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade100, Colors.grey.shade100],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _iconController,
                    builder: (context, _) {
                      return Opacity(
                        opacity: _iconOpacity.value,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.shade300.withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(Icons.restaurant,
                              size: 40, color: Colors.orange.shade300),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Content
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.service['name'] as String,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Category: ${widget.service['category']}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Glowing Border
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.orange.shade300.withOpacity(0.7),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SupermarketCard extends StatefulWidget {
  final Map<String, dynamic> service;
  final VoidCallback onTap;

  const SupermarketCard(
      {super.key, required this.service, required this.onTap});

  @override
  State<SupermarketCard> createState() => _SupermarketCardState();
}

class _SupermarketCardState extends State<SupermarketCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _iconOpacity;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _iconOpacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.teal.shade300.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade700.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade100, Colors.grey.shade100],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _iconController,
                    builder: (context, _) {
                      return Opacity(
                        opacity: _iconOpacity.value,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.shade300.withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(Iconsax.shopping_cart,
                              size: 40, color: Colors.teal.shade300),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.service['name'] as String,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Category: ${widget.service['category']}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Glowing Border
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.teal.shade300.withOpacity(0.7),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CopyCenterCard extends StatefulWidget {
  final Map<String, dynamic> service;
  final VoidCallback onTap;

  const CopyCenterCard({super.key, required this.service, required this.onTap});

  @override
  State<CopyCenterCard> createState() => _CopyCenterCardState();
}

class _CopyCenterCardState extends State<CopyCenterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _iconScale;
  late Animation<double> _iconRotation;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _iconScale = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );
    _iconRotation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.blue.shade300.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade700.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade100, Colors.grey.shade100],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _iconController,
                    builder: (context, _) {
                      return Transform.scale(
                        scale: _iconScale.value,
                        child: Transform.rotate(
                          angle: _iconRotation.value,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade300.withOpacity(0.5),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(Iconsax.book_14,
                                size: 40, color: Colors.blue.shade300),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.service['name'] as String,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Category: ${widget.service['category']}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Glowing Border
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.blue.shade300.withOpacity(0.7),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DefaultCard extends StatefulWidget {
  final Map<String, dynamic> service;
  final VoidCallback onTap;

  const DefaultCard({super.key, required this.service, required this.onTap});

  @override
  State<DefaultCard> createState() => _DefaultCardState();
}

class _DefaultCardState extends State<DefaultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _iconOpacity;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _iconOpacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Special case for print centers
    final isPrintCenter = (widget.service['category'] as String? ?? '')
        .toLowerCase()
        .contains('print');
    final iconColor =
        isPrintCenter ? Colors.blue.shade300 : Colors.purple.shade200;
    final borderColor =
        isPrintCenter ? Colors.blue.shade300 : Colors.purple.shade200;
    final gradientStartColor =
        isPrintCenter ? Colors.blue.shade100 : Colors.purple.shade100;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade700.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gradientStartColor, Colors.grey.shade100],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _iconController,
                    builder: (context, _) {
                      return Opacity(
                        opacity: _iconOpacity.value,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: borderColor.withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                              isPrintCenter ? Iconsax.book_1 : Iconsax.star,
                              size: 40,
                              color: iconColor),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.service['name'] as String,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Category: ${widget.service['category']}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: widget.onTap,
                  splashColor: Colors.purple.shade200.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
