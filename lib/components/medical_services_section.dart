import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pages/add_medical_service_page.dart';
import '../pages/medical_service_details_page.dart';

class MedicalServicesSection extends StatefulWidget {
  final bool isAdmin;
  const MedicalServicesSection({super.key, required this.isAdmin});

  @override
  State<MedicalServicesSection> createState() => _MedicalServicesSectionState();
}

class _MedicalServicesSectionState extends State<MedicalServicesSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Medical Services',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              if (widget.isAdmin)
                IconButton(
                  icon: const Icon(Iconsax.add_circle, color: Colors.red),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddMedicalServicePage(),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          labelColor: Colors.red.shade700,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.red.shade400,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Iconsax.hospital), text: 'Hospitals'),
            Tab(icon: Icon(Iconsax.health), text: 'Pharmacies'),
            Tab(icon: Icon(Iconsax.profile_circle), text: 'Doctors'),
          ],
        ),
        SizedBox(
          height: 400, // Adjust height as needed
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildServiceList('hospital'),
              _buildServiceList('pharmacy'),
              _buildServiceList('doctor'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceList(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medical_services')
          .where('type', isEqualTo: type)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.red));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No ${type}s found yet.',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          );
        }

        final services = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index].data() as Map<String, dynamic>;
            service['id'] = services[index].id;
            return MedicalServiceCard(
                service: service, isAdmin: widget.isAdmin);
          },
        );
      },
    );
  }
}

class MedicalServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final bool isAdmin;

  const MedicalServiceCard(
      {super.key, required this.service, required this.isAdmin});

  IconData _getIcon(String type) {
    switch (type) {
      case 'hospital':
        return Iconsax.hospital;
      case 'pharmacy':
        return Iconsax.health;
      case 'doctor':
        return Iconsax.profile_circle;
      default:
        return Iconsax.activity;
    }
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = service['type'] as String;
    final name = service['name'] as String;
    final address = service['address'] as String;
    final phone = service['phone'] as String?;
    final whatsapp = service['whatsapp'] as String?;
    final location = service['location'] as GeoPoint?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.red.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MedicalServiceDetailsPage(service: service),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(_getIcon(type), color: Colors.red.shade400, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (location != null)
                IconButton(
                  icon: Icon(Iconsax.map_1, color: Colors.blue.shade600),
                  onPressed: () => _launchUrl(
                      'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}'),
                ),
              if (whatsapp != null)
                IconButton(
                  icon: const Icon(Iconsax.message, color: Colors.green),
                  onPressed: () => _launchUrl('https://wa.me/$whatsapp'),
                ),
              if (isAdmin)
                IconButton(
                  icon: Icon(Iconsax.edit, color: Colors.grey.shade700),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddMedicalServicePage(service: service),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
