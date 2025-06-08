import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class TransportationSection extends StatefulWidget {
  const TransportationSection({super.key});

  @override
  State<TransportationSection> createState() => _TransportationSectionState();
}

class _TransportationSectionState extends State<TransportationSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _busAnimation;
  late Animation<double> _fadeAnimation;
  int? _hoveredIndex;

  final List<Map<String, dynamic>> governorates = [
    {
      'name': 'Cairo',
      'whatsappLink': 'https://chat.whatsapp.com/HflgA2quweRF5cTt0PauXh',
      'icon': Iconsax.building,
      'color': Colors.blue,
    },
    {
      'name': 'Giza',
      'whatsappLink': 'https://chat.whatsapp.com/JKp7Gi6Tr6G56kClx5eAGy',
      'icon': Iconsax.building,
      'color': Colors.teal,
    },
    {
      'name': 'Alexandria',
      'whatsappLink': 'https://chat.whatsapp.com/KLmzXuKf8Xt4Qd6Yl7kCVm',
      'icon': Iconsax.building,
      'color': Colors.cyan,
    },
    {
      'name': 'Dakahlia',
      'whatsappLink': 'https://chat.whatsapp.com/LNjB7Tr8Xt9Qd6Yl7kCVm',
      'icon': Iconsax.building,
      'color': Colors.indigo,
    },
    {
      'name': 'Sharqia',
      'whatsappLink': 'https://chat.whatsapp.com/MNpB8Gi6Tr6G56kClx5eAGy',
      'icon': Iconsax.house,
      'color': Colors.purple,
    },
    {
      'name': 'Faiyum',
      'whatsappLink': 'https://chat.whatsapp.com/NOpC8Gi6Tr6G56kClx5eAGy',
      'icon': Iconsax.house,
      'color': Colors.deepPurple,
    },
    {
      'name': 'Monufia',
      'whatsappLink': 'https://chat.whatsapp.com/PQrB7Gi6Tr6G56kClx5eAGy',
      'icon': Iconsax.building,
      'color': Colors.orange,
    },
    {
      'name': 'Luxor',
      'whatsappLink': 'https://chat.whatsapp.com/QRsB7Gi6Tr6G56kClx5eAGy',
      'icon': Iconsax.building,
      'color': Colors.amber,
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _busAnimation = Tween<double>(
      begin: -10.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsAppGroup(String url) async {
    try {
      // Format URL based on platform
      final whatsappUrl = kIsWeb
          ? url // Use direct URL for web
          : Platform.isAndroid
              ? 'whatsapp://chat?code=${url.split('/').last}' // Android deep link
              : Platform.isIOS
                  ? 'whatsapp://send?text=Join%20group:%20$url' // iOS deep link
                  : url;

      final uri = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // If can't launch, try opening in browser first
        final browserUri = Uri.parse(url);
        if (await canLaunchUrl(browserUri)) {
          await launchUrl(browserUri, mode: LaunchMode.externalApplication);
        } else {
          if (!mounted) return;

          // Show error with store links
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Could not open WhatsApp. Make sure WhatsApp is installed on your device.',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              action: SnackBarAction(
                label: 'Install',
                textColor: Colors.white,
                onPressed: () async {
                  final storeUrl = Platform.isAndroid
                      ? 'market://details?id=com.whatsapp'
                      : 'https://apps.apple.com/app/whatsapp-messenger/id310633997';
                  final storeUri = Uri.parse(storeUrl);

                  if (await canLaunchUrl(storeUri)) {
                    await launchUrl(storeUri,
                        mode: LaunchMode.externalApplication);
                  } else {
                    // Fallback to web URLs if market URLs don't work
                    final webStoreUrl = Platform.isAndroid
                        ? 'https://play.google.com/store/apps/details?id=com.whatsapp'
                        : 'https://apps.apple.com/app/whatsapp-messenger/id310633997';
                    await launchUrl(Uri.parse(webStoreUrl),
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error opening WhatsApp group. Please try again.',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Bus Icon
          Row(
            children: [
              AnimatedBuilder(
                animation: _busAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_busAnimation.value, 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Iconsax.bus,
                        size: 32,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transportation',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Connect with fellow students for shared rides',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Description Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Join your regional transportation group to coordinate rides, share costs, and make your commute easier',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Governorate Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: governorates.length,
            itemBuilder: (context, index) {
              final governorate = governorates[index];
              final color = governorate['color'] as MaterialColor;
              final IconData icon = governorate['icon'] as IconData;

              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredIndex = index),
                onExit: (_) => setState(() => _hoveredIndex = null),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _launchWhatsAppGroup(
                      governorate['whatsappLink'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.shade300,
                          color.shade500,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: color.shade200
                              .withOpacity(_hoveredIndex == index ? 0.5 : 0.3),
                          blurRadius: _hoveredIndex == index ? 12 : 8,
                          offset: Offset(0, _hoveredIndex == index ? 6 : 4),
                        ),
                      ],
                    ),
                    transform: Matrix4.identity()
                      ..scale(_hoveredIndex == index ? 1.05 : 1.0),
                    child: Stack(
                      children: [
                        if (_hoveredIndex == index)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: FaIcon(
                              FontAwesomeIcons.whatsapp,
                              color: Colors.white.withOpacity(0.3),
                              size: 20,
                            ),
                          ),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icon,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                governorate['name'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
