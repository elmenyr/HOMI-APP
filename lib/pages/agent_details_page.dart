// ignore_for_file: directives_ordering, omit_local_variable_types, avoid_types_as_parameter_names, cast_nullable_to_non_nullable, lines_longer_than_80_chars

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:homi/models/admin_user.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:homi/services/firebase_storage_service.dart';

class AgentDetailsPage extends StatefulWidget {
  const AgentDetailsPage({
    super.key,
    required this.agentId,
    required this.agentData,
  });

  final String agentId;
  final Map<String, dynamic> agentData;

  @override
  State<AgentDetailsPage> createState() => _AgentDetailsPageState();
}

class _AgentDetailsPageState extends State<AgentDetailsPage> {
  late Stream<QuerySnapshot> _reviewsStream;
  final _reviewController = TextEditingController();
  double _rating = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _reviewsStream = FirebaseFirestore.instance
        .collection('agents')
        .doc(widget.agentId)
        .collection('reviews')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _checkAdminStatus() async {
    _isAdmin = await AdminUser.isCurrentUserAdmin();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (!mounted) return;
      _showSnackBar('Could not launch phone call', isError: true);
    }
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final formattedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '').replaceAll(RegExp(r'^0+'), '');
    if (formattedNumber.isEmpty) {
      _showSnackBar('Phone number not available', isError: true);
      return;
    }

    final url = 'https://wa.me/20$formattedNumber';
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      _showSnackBar('Could not open WhatsApp', isError: true);
    }
  }

  Future<void> _submitReview() async {
    if (_reviewController.text.trim().isEmpty || _rating == 0) {
      _showSnackBar('Please provide a rating and review', isError: true);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('agents')
          .doc(widget.agentId)
          .collection('reviews')
          .add({
        'text': _reviewController.text.trim(),
        'rating': _rating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _reviewController.clear();
      setState(() => _rating = 0);
      _showSnackBar('Review submitted successfully');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error submitting review', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _updateAgentProfileImage() async {
    if (!_isAdmin) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image == null) return;

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Uploading image...', style: GoogleFonts.poppins()),
              ],
            ),
            backgroundColor: Colors.black,
            duration: const Duration(seconds: 60),
          ),
        );
      }

      // Upload image to Firebase Storage
      final imageUrl = await FirebaseStorageService.uploadImage(
        File(image.path),
        folder: 'agents',
      );

      if (imageUrl != null) {
        // Delete old image if it exists
        final oldImageUrl = widget.agentData['imageUrl'] as String?;
        if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
          await FirebaseStorageService.deleteImage(oldImageUrl);
        }

        // Update agent document
        await FirebaseFirestore.instance
            .collection('agents')
            .doc(widget.agentId)
            .update({'imageUrl': imageUrl});

        // Update local data
        if (mounted) {
          setState(() {
            final updatedData = Map<String, dynamic>.from(widget.agentData);
            updatedData['imageUrl'] = imageUrl;
            widget.agentData.update('imageUrl', (_) => imageUrl, ifAbsent: () => imageUrl);
          });
        }
      }

      // Dismiss any open snackbars and show success message
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile image updated successfully', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile image: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = widget.agentData;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.grey.shade200,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        agent['imageUrl'] != null && agent['imageUrl'].toString().isNotEmpty
                            ? Image.network(
                                agent['imageUrl'] as String,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.person_outline,
                                  size: 120,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : Icon(
                                Icons.person_outline,
                                size: 120,
                                color: Colors.grey.shade600,
                              ),
                        if (_isAdmin)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: GestureDetector(
                              onTap: _updateAgentProfileImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          agent['name']?.toString() ?? 'Unknown Agent',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (agent['specialization'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              agent['specialization'].toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (agent['bio'] != null)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              agent['bio'].toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => agent['phone'] != null
                              ? _makePhoneCall(agent['phone'].toString())
                              : _showSnackBar('Phone number not available', isError: true),
                          icon: const Icon(Iconsax.call, size: 20),
                          label: Text(
                            'Call Agent',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => agent['phone'] != null
                              ? _launchWhatsApp(agent['phone'].toString())
                              : _showSnackBar('Phone number not available', isError: true),
                          icon: const Icon(FontAwesomeIcons.whatsapp, size: 20),
                          label: Text(
                            'WhatsApp',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reviews',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: _reviewsStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final reviews = snapshot.data!.docs;
                          final averageRating = reviews.isEmpty
                              ? 0.0
                              : reviews.fold<double>(
                                    0,
                                    (sum, doc) => sum + ((doc.data() as Map<String, dynamic>)['rating'] as num? ?? 0),
                                  ) /
                                  reviews.length;
                          return Row(
                            children: [
                              Icon(Iconsax.star1, color: Colors.amber.shade600, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                averageRating.toStringAsFixed(1),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                ' (${reviews.length})',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Review',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          RatingBar.builder(
                            initialRating: _rating,
                            minRating: 1,
                            direction: Axis.horizontal,
                            allowHalfRating: false,
                            itemCount: 5,
                            itemSize: 32,
                            itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                            itemBuilder: (context, _) => Icon(
                              Iconsax.star1,
                              color: Colors.amber.shade600,
                            ),
                            onRatingUpdate: (rating) => setState(() => _rating = rating),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _reviewController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Share your thoughts...',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: InputBorder.none,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.black, width: 2),
                              ),
                              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
                            ),
                            style: GoogleFonts.poppins(color: Colors.black),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitReview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text(
                                'Submit Review',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: StreamBuilder<QuerySnapshot>(
              stream: _reviewsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        'Error loading reviews',
                        style: GoogleFonts.poppins(
                          color: Colors.red.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final reviews = snapshot.data!.docs;

                if (reviews.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        'No reviews yet',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final review = reviews[index].data() as Map<String, dynamic>;
                      final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
                      final timestamp = review['timestamp'] as Timestamp?;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  RatingBarIndicator(
                                    rating: rating,
                                    itemBuilder: (context, index) => Icon(
                                      Iconsax.star1,
                                      color: Colors.amber.shade600,
                                    ),
                                    itemCount: 5,
                                    itemSize: 20,
                                    unratedColor: Colors.grey.shade200,
                                  ),
                                  if (_isAdmin)
                                    IconButton(
                                      icon: Icon(Iconsax.trash, color: Colors.red.shade600),
                                      onPressed: () async {
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('agents')
                                              .doc(widget.agentId)
                                              .collection('reviews')
                                              .doc(reviews[index].id)
                                              .delete();
                                          if (!mounted) return;
                                          _showSnackBar('Review deleted successfully');
                                        } catch (e) {
                                          if (!mounted) return;
                                          _showSnackBar('Error deleting review', isError: true);
                                        }
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                review['text']?.toString() ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (timestamp != null)
                                Text(
                                  _formatDate(timestamp),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: reviews.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) return '${difference.inMinutes} min ago';
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }
}