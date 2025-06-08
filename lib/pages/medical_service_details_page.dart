import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

class MedicalServiceDetailsPage extends StatelessWidget {
  final Map<String, dynamic> service;

  const MedicalServiceDetailsPage({super.key, required this.service});

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = service['name'] as String;
    final address = service['address'] as String;
    final phone = service['phone'] as String?;
    final location = service['location'] as GeoPoint?;
    final type = service['type'] as String;
    final specialty = service['specialty'] as String?; // for doctors
    final is247 = service['is247'] as bool?; // for pharmacies

    return Scaffold(
      appBar: AppBar(
        title: Text(name, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red.shade50,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: GoogleFonts.poppins(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (type == 'doctor' && specialty != null)
              Text(specialty,
                  style: GoogleFonts.poppins(
                      fontSize: 18, color: Colors.grey.shade700)),
            if (type == 'pharmacy' && is247 == true)
              Chip(
                  label: const Text('Open 24/7'),
                  backgroundColor: Colors.green.shade100),
            const SizedBox(height: 24),
            _buildDetailRow(Iconsax.location, 'Address', address),
            if (phone != null) _buildDetailRow(Iconsax.call, 'Phone', phone),
            const SizedBox(height: 32),
            if (location != null)
              ElevatedButton.icon(
                onPressed: () => _launchUrl(
                    'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}'),
                icon: const Icon(Iconsax.map),
                label: const Text('View on Google Maps'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  textStyle: GoogleFonts.poppins(fontSize: 16),
                ),
              ),
            const SizedBox(height: 16),
            if (phone != null)
              ElevatedButton.icon(
                onPressed: () => _launchUrl('tel:$phone'),
                icon: const Icon(Iconsax.call),
                label: const Text('Call Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                  textStyle: GoogleFonts.poppins(fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.red.shade400),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.poppins(fontSize: 16)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
