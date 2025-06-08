import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../providers/language_provider.dart';
import 'services_page.dart';

class ServiceDetailsPage extends StatefulWidget {
  final String serviceId;
  final Map<String, dynamic> serviceData;

  const ServiceDetailsPage({
    super.key,
    required this.serviceId,
    required this.serviceData,
  });

  @override
  State<ServiceDetailsPage> createState() => _ServiceDetailsPageState();
}

class _ServiceDetailsPageState extends State<ServiceDetailsPage> {
  final _commentController = TextEditingController();
  double _userRating = 0;
  bool _isSubmittingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please sign in to comment', style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a comment', style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() => _isSubmittingComment = true);

    try {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .collection('comments')
          .add({
        'text': _commentController.text.trim(),
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous User',
        'rating': _userRating,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update service average rating
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .collection('comments')
          .get();

      double totalRating = 0;
      for (var doc in commentsSnapshot.docs) {
        totalRating += (doc.data()['rating'] as num).toDouble();
      }

      final averageRating = commentsSnapshot.size > 0 ? totalRating / commentsSnapshot.size : 0.0;

      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .update({'rating': averageRating});

      if (mounted) {
        _commentController.clear();
        setState(() {
          _userRating = 0;
          _isSubmittingComment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting comment: $e', style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  // Function to validate and launch URL
  Future<void> _launchLocationUrl(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No location URL provided', style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid location URL', style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open the location URL', style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final isRTL = languageProvider.isArabic;
    
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Colors.grey.shade100,
          body: CustomScrollView(
            slivers: [
              // App Bar with Image
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: Colors.white,
                automaticallyImplyLeading: false,
                leading: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: CachedNetworkImage(
                    imageUrl: (widget.serviceData['photoUrl'] as String?) ?? 
                        'https://via.placeholder.com/400x200?text=No+Image',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator(color: Colors.black)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade200,
                      child: Icon(Icons.error, color: Colors.red.shade600),
                    ),
                  ),
                ),
              ),

              // Service Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Service Name
                      Text(
                        (widget.serviceData['name'] as String?) ?? 'Service Name',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Rating Display
                      Row(
                        mainAxisAlignment: isRTL ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${(widget.serviceData['rating'] as num?)?.toStringAsFixed(1) ?? '0.0'}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Phone Number
                      if (widget.serviceData['phone'] != null)
                        GestureDetector(
                          onTap: () async {
                            final phoneNumber = widget.serviceData['phone'];
                            final uri = Uri.parse('tel:$phoneNumber');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                            child: Row(
                              children: [
                                Icon(Iconsax.call, color: Colors.grey.shade600),
                                const SizedBox(width: 12),
                                Text(
                                  (widget.serviceData['phone'] as String?) ?? 'No phone number',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Location
                      Row(
                        children: [
                          Icon(Iconsax.location, size: 20, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                final locationUrl = widget.serviceData['location'] as String?;
                                _launchLocationUrl(locationUrl);
                              },
                              child: Text(
                                widget.serviceData['location'] as String? ?? 'No location provided',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: widget.serviceData['location'] != null ? Colors.blue : Colors.grey.shade600,
                                  decoration: widget.serviceData['location'] != null
                                      ? TextDecoration.underline
                                      : TextDecoration.none,
                                  decorationColor: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // University and Category
                      Row(
                        mainAxisAlignment: isRTL ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Icon(Iconsax.building, size: 20, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            widget.serviceData['university'] as String? ?? 'Unknown University',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Iconsax.category, size: 20, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            widget.serviceData['category'] as String? ?? 'Unknown Category',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Rating Input
                      Text(
                        isRTL ? 'قيم هذه الخدمة:' : 'Rate this service:',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: isRTL ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < _userRating ? Icons.star : Icons.star_border,
                              color: Colors.amber.shade600,
                            ),
                            onPressed: () {
                              setState(() => _userRating = index + 1.0);
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Comment Input
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
                        child: TextField(
                          controller: _commentController,
                          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                          textAlign: isRTL ? TextAlign.right : TextAlign.left,
                          decoration: InputDecoration(
                            hintText: isRTL ? 'اكتب تعليقاً...' : 'Write a comment...',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            suffixIcon: isRTL ? null : IconButton(
                              icon: _isSubmittingComment
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
                                    )
                                  : Icon(Icons.send, color: Colors.grey.shade600),
                              onPressed: _isSubmittingComment ? null : _submitComment,
                            ),
                            prefixIcon: isRTL ? IconButton(
                              icon: _isSubmittingComment
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
                                    )
                                  : Transform.scale(
                                      scaleX: -1,
                                      child: Icon(Icons.send, color: Colors.grey.shade600),
                                    ),
                              onPressed: _isSubmittingComment ? null : _submitComment,
                            ) : null,
                          ),
                          style: GoogleFonts.poppins(color: Colors.black),
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Comments Section
                      Text(
                        isRTL ? 'التعليقات' : 'Comments',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Comments List
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('services')
                    .doc(widget.serviceId)
                    .collection('comments')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          isRTL ? 'خطأ: ${snapshot.error}' : 'Error: ${snapshot.error}',
                          style: GoogleFonts.poppins(color: Colors.red.shade600),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator(color: Colors.black)),
                    );
                  }

                  final comments = snapshot.data!.docs;

                  if (comments.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Center(
                          child: Text(
                            isRTL ? 'لا توجد تعليقات' : 'No comments yet',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final comment = comments[index].data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                              crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      comment['userName'] as String? ?? (isRTL ? 'مستخدم مجهول' : 'Anonymous User'),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(
                                        5,
                                        (i) => Icon(
                                          i < (comment['rating'] as num? ?? 0) ? Icons.star : Icons.star_border,
                                          size: 16,
                                          color: Colors.amber.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  comment['text'] as String? ?? (isRTL ? 'لا يوجد تعليق' : 'No comment text'),
                                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                                  textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                                  textAlign: isRTL ? TextAlign.right : TextAlign.left,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: comments.length,
                    ),
                  );
                },
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
            ],
          ),
        ),
      ),
    );
  }
}