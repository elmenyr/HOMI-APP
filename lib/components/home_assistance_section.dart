import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeAssistanceSection extends StatefulWidget {
  const HomeAssistanceSection({super.key});

  @override
  State<HomeAssistanceSection> createState() => _HomeAssistanceSectionState();
}

class _HomeAssistanceSectionState extends State<HomeAssistanceSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int? _hoveredIndex;

  final List<Map<String, dynamic>> services = [
    {
      'name': 'Cleaning Service',
      'icon': Icons.cleaning_services,
      'emoji': '🧹',
      'description': 'Book professional apartment cleaning services',
      'color': Colors.green,
      'phone': '+201234567890', // Replace with actual phone number
    },
    {
      'name': 'Carpenter',
      'icon': Icons.handyman,
      'emoji': '🔨',
      'description': 'Fix furniture and wooden items',
      'color': Colors.brown,
      'phone': '+201234567891', // Replace with actual phone number
    },
    {
      'name': 'Plumber',
      'icon': Icons.plumbing,
      'emoji': '🔧',
      'description': 'Handle water-related maintenance and leaks',
      'color': Colors.blue,
      'phone': '+201234567892', // Replace with actual phone number
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not launch phone call. Please try again.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.home_repair_service,
                      color: Colors.purple.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Get professional help for your home maintenance needs',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.purple.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Service Cards Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 700
                    ? 3
                    : constraints.maxWidth > 500
                        ? 2
                        : 1;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    final color = service['color'] as MaterialColor;

                    return MouseRegion(
                      onEnter: (_) => setState(() => _hoveredIndex = index),
                      onExit: (_) => setState(() => _hoveredIndex = null),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: color.shade300.withOpacity(0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.shade100.withOpacity(
                                  _hoveredIndex == index ? 0.5 : 0.3),
                              blurRadius: _hoveredIndex == index ? 16 : 8,
                              offset: Offset(0, _hoveredIndex == index ? 8 : 4),
                            ),
                          ],
                        ),
                        transform: Matrix4.identity()
                          ..scale(_hoveredIndex == index ? 1.05 : 1.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                _makePhoneCall(service['phone'] as String),
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Emoji and Icon
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: color.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          service['emoji'] as String,
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                      ),
                                      if (_hoveredIndex == index)
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color:
                                                color.shade100.withOpacity(0.9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.phone,
                                            color: color.shade700,
                                            size: 24,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Service Name
                                  Text(
                                    service['name'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  // Description
                                  Text(
                                    service['description'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
