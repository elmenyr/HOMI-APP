// ignore_for_file: directives_ordering, omit_local_variable_types, avoid_types_as_parameter_names, cast_nullable_to_non_nullable, lines_longer_than_80_chars

import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:homi/forgot_password_page.dart';
import 'package:homi/login_page.dart';
import 'package:homi/models/admin_user.dart';
import 'package:homi/pages/working_hours_config_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:homi/services/firebase_storage_service.dart';
import 'package:homi/utils/navigation_tour.dart';
import 'package:homi/utils/property_details_tour.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:homi/providers/language_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isImageLoading = false;
  bool _isSignOutLoading = false;
  final user = FirebaseAuth.instance.currentUser;
  bool _isAdmin = false;
  String? _profileImageUrl;
  ImageProvider? _cachedProfileImage;
  bool _hasLoadedImage = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    if (!_hasLoadedImage) {
      _loadProfileImage();
    }
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await AdminUser.isCurrentUserAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  Future<void> _loadProfileImage() async {
    if (_hasLoadedImage) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();

      if (mounted && userDoc.exists) {
        final imageUrl = userDoc.data()?['profileImageUrl'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          // Preload the image to ensure it's cached
          await precacheImage(
            CachedNetworkImageProvider(imageUrl, cacheManager: DefaultCacheManager()),
            context,
            onError: (exception, stackTrace) {
              debugPrint('Error preloading profile image: $exception');
            },
          );
          if (mounted) {
            setState(() {
              _profileImageUrl = imageUrl;
              _cachedProfileImage = CachedNetworkImageProvider(
                imageUrl,
                cacheManager: DefaultCacheManager(),
                errorListener: (error) {
                  debugPrint('Error loading profile image from cache: $error');
                  setState(() => _cachedProfileImage = null);
                },
              );
              _hasLoadedImage = true;
            });
          }
        } else {
          if (mounted) {
            setState(() => _hasLoadedImage = true);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading profile image: $e');
      if (mounted) {
        setState(() => _hasLoadedImage = true); // Prevent retrying on error
      }
    }
  }

  Future<void> _updateProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isImageLoading = true);

      final imageUrl = await FirebaseStorageService.uploadImage(
        File(image.path),
        folder: 'profiles',
      );

      if (imageUrl != null && user != null) {
        // Delete old image from storage and invalidate cache
        if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
          await FirebaseStorageService.deleteImage(_profileImageUrl!);
          await DefaultCacheManager().removeFile(_profileImageUrl!);
        }

        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .set({'profileImageUrl': imageUrl}, SetOptions(merge: true));

        // Preload new image
        await precacheImage(
          CachedNetworkImageProvider(imageUrl, cacheManager: DefaultCacheManager()),
          context,
          onError: (exception, stackTrace) {
            debugPrint('Error preloading new profile image: $exception');
          },
        );

        if (mounted) {
          setState(() {
            _profileImageUrl = imageUrl;
            _cachedProfileImage = CachedNetworkImageProvider(
              imageUrl,
              cacheManager: DefaultCacheManager(),
              errorListener: (error) {
                debugPrint('Error loading new profile image from cache: $error');
                setState(() => _cachedProfileImage = null);
              },
            );
            _isImageLoading = false;
            _hasLoadedImage = true;
          });

          _showSnackBar('Profile picture updated successfully');
        }
      } else {
        if (mounted) {
          setState(() => _isImageLoading = false);
          _showSnackBar('Failed to update profile picture', isError: true);
        }
      }
    } catch (e) {
      debugPrint('Error updating profile picture: $e');
      if (mounted) {
        setState(() => _isImageLoading = false);
        _showSnackBar('Error updating profile picture: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _launchCall() async {
    final l10n = AppLocalizations.of(context)!;
    const phoneNumber = '01019928049'; // Replace with your actual support number
    final url = 'tel:$phoneNumber';
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.couldNotInitiateCall),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Directionality(
      // Force LTR layout for consistent element positioning
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            l10n.settings,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: 'Montserrat',
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Card
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _isImageLoading ? null : _updateProfileImage,
                              child: Stack(
                                children: [
                                  _buildProfileImage(),
                                  if (_isImageLoading)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (!_isImageLoading)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.shade300,
                                              offset: const Offset(0, 1),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Iconsax.camera,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.displayName ?? l10n.user,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.email ?? l10n.noEmail,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                  if (_isAdmin) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade900.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade800,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        l10n.admin,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Section Header - Account
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    l10n.account,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      fontFamily: 'Montserrat',
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // Account Settings Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: Iconsax.lock,
                        title: l10n.changePassword,
                        subtitle: l10n.updatePassword,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordPage(),
                            ),
                          );
                        },
                      ),
                      if (_isAdmin)
                        const Divider(height: 1, indent: 56, endIndent: 16),
                      if (_isAdmin)
                        _buildSettingsTile(
                          icon: Iconsax.timer_1,
                          title: l10n.workingHours,
                          subtitle: l10n.configureHours,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WorkingHoursConfigPage(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Section Header - Info
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    l10n.information,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      fontFamily: 'Montserrat',
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // About Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: Iconsax.information,
                        title: l10n.appVersion,
                        subtitle: '1.0.0',
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      Consumer<LanguageProvider>(
                        builder: (context, languageProvider, child) {
                          return _buildSettingsTile(
                            icon: Iconsax.language_square,
                            title: l10n.language,
                            subtitle: languageProvider.isArabic ? l10n.arabic : l10n.english,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) => Container(
                                  height: MediaQuery.of(context).size.height * 0.35,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, -5),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Handle bar
                                      Container(
                                        margin: const EdgeInsets.only(top: 12),
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      // Title
                                      Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Iconsax.language_square,
                                                color: Colors.grey.shade800,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              l10n.language,
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                                fontFamily: 'Montserrat',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Language options
                                      Expanded(
                                        child: SingleChildScrollView(
                                          physics: const BouncingScrollPhysics(),
                                          child: Column(
                                            children: [
                                              _buildLanguageOption(
                                                context: context,
                                                languageProvider: languageProvider,
                                                languageCode: 'en',
                                                languageName: l10n.english,
                                                flagEmoji: '🇺🇸',
                                              ),
                                              _buildLanguageOption(
                                                context: context,
                                                languageProvider: languageProvider,
                                                languageCode: 'ar',
                                                languageName: l10n.arabic,
                                                flagEmoji: '🇪🇬',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Bottom padding
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _buildSettingsTile(
                        icon: Iconsax.shield,
                        title: l10n.privacyPolicy,
                        subtitle: l10n.readPrivacy,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                l10n.privacyPolicy,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              content: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${l10n.lastUpdated}\n\n${l10n.privacyText}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                        fontFamily: 'Montserrat',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey.shade800,
                                  ),
                                  child: Text(
                                    l10n.close,
                                    style: const TextStyle(fontFamily: 'Montserrat'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _buildSettingsTile(
                        icon: Iconsax.message,
                        title: l10n.contactUs,
                        subtitle: l10n.getSupport,
                        onTap: _launchCall,
                      ),
                    ],
                  ),
                ),

                // Section Header - Help & Support
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    l10n.helpAndSupport,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      fontFamily: 'Montserrat',
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // Help & Support Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: Iconsax.info_circle,
                        title: l10n.resetNavTour,
                        subtitle: l10n.showNavExplanation,
                        onTap: () {
                          NavigationTour.resetAndShowTour(context, _isAdmin);
                        },
                      ),
                    ],
                  ),
                ),

                // Sign Out Button
                Container(
                  margin: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _isSignOutLoading ? null : _enhancedSignOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade600,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.red.shade200,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 55),
                    ),
                    child: _isSignOutLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade300),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Iconsax.logout,
                                color: Colors.red.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.signOut,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade600,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                // Footer space
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.grey.shade800, size: 18),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enhancedSignOut() async {
    final l10n = AppLocalizations.of(context)!;
    
    // Get confirmation from user
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.signOut,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'Montserrat',
          ),
        ),
        content: Text(
          l10n.signOutConfirm,
          style: TextStyle(color: Colors.grey.shade800, fontFamily: 'Montserrat'),
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade800),
            child: Text(
              l10n.cancel,
              style: const TextStyle(fontFamily: 'Montserrat'),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              l10n.signOut,
              style: const TextStyle(fontFamily: 'Montserrat'),
            ),
          ),
        ],
      ),
    );

    if (shouldSignOut != true) return;

    setState(() => _isSignOutLoading = true);

    try {
      // Simple sign out without clearing local data
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Navigate to login page
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
            opacity: animation,
            child: const LoginPage(),
          ),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Error signing out: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error signing out. Please try again.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSignOutLoading = false);
      }
    }
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required LanguageProvider languageProvider,
    required String languageCode,
    required String languageName,
    required String flagEmoji,
  }) {
    final isSelected = languageProvider.currentLocale.languageCode == languageCode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            languageProvider.changeLanguage(languageCode);
            Navigator.pop(context);

            // Show feedback
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Text('Language changed to $languageName'),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.blue.shade200 : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Flag and Language Name
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        flagEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        languageName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                ),
                // Selection indicator
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.blue.shade700,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    if (_profileImageUrl == null || _profileImageUrl!.isEmpty || _cachedProfileImage == null) {
      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey.shade200,
        child: Text(
          user?.email?.substring(0, 1).toUpperCase() ?? 'U',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
            fontFamily: 'Montserrat',
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: _cachedProfileImage,
      child: _cachedProfileImage == null
          ? Icon(
              Icons.error_outline,
              color: Colors.grey.shade400,
              size: 30,
            )
          : null,
    );
  }
}