import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:homi/app.dart';
import 'package:homi/app_data.dart';
import 'package:homi/services/firebase_storage_service.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _universityController = TextEditingController();
  String? _selectedCollege;

  String? _selectedGovernorate;
  bool _isSmoker = false;
  File? _profileImage;
  bool _isLoading = false;
  final _selectedHobbies = <String>{};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _colleges = [
    'Pharmacy',
    'Dentistry',
    'Engineering',
    'Mass Communication',
    'Business',
    'Computer Science',
    'Information Technology',
  ];

  final List<String> _hobbies = [
    'Gaming',
    'Gym',
    'Reading',
    'Football',
    'Cooking',
    'Movies',
    'Music',
    'Travel',
    'Photography',
    'Art'
  ];

  // Add Egyptian governorates list
  final List<String> _egyptianGovernorates = [
    'Alexandria',
    'Aswan',
    'Asyut',
    'Beheira',
    'Beni Suef',
    'Cairo',
    'Dakahlia',
    'Damietta',
    'Faiyum',
    'Gharbia',
    'Giza',
    'Ismailia',
    'Kafr El Sheikh',
    'Luxor',
    'Matruh',
    'Minya',
    'Monufia',
    'New Valley',
    'North Sinai',
    'Port Said',
    'Qalyubia',
    'Qena',
    'Red Sea',
    'Sharqia',
    'Sohag',
    'South Sinai',
    'Suez'
  ];

  @override
  void initState() {
    super.initState();
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();

    // Pre-fill name if available
    final user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        user.displayName != null &&
        user.displayName!.isNotEmpty) {
      _fullNameController.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fullNameController.dispose();
    _universityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        setState(() {
          _profileImage = File(pickedImage.path);
        });
      }
    } catch (e) {
      _showErrorMessage('Error picking image: $e');
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Iconsax.camera,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Iconsax.gallery,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade100, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.grey.shade900, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade900,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _skipProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FeatureDiscovery(
            child: App(data: AppData(), isFirstLogin: true),
          ),
        ),
      );
    } catch (e) {
      _showErrorMessage('Error skipping profile: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      String? profileImageUrl;
      if (_profileImage != null) {
        profileImageUrl = await FirebaseStorageService.uploadImage(
          _profileImage,
          folder: 'profiles',
          onProgress: (progress) {},
        );
      }

      final fullName = _fullNameController.text.trim();
      if (fullName.isNotEmpty) {
        await user.updateDisplayName(fullName);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fullName': fullName,
        'university': _universityController.text.trim(),
        'college': _selectedCollege,
        'governorate': _selectedGovernorate,
        'isSmoker': _isSmoker,
        'hobbies': _selectedHobbies.toList(),
        'profileCompleted': true,
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Profile completed successfully!',
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          backgroundColor: Colors.green.shade400,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FeatureDiscovery(
            child: App(data: AppData(), isFirstLogin: true),
          ),
        ),
      );
    } catch (e) {
      _showErrorMessage('Error saving profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Complete Your Profile',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                          TextButton(
                            onPressed: _skipProfile,
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.blue.shade600,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Let us know more about you!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Profile Image
                      Center(
                        child: GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                  image: _profileImage != null
                                      ? DecorationImage(
                                          image: FileImage(_profileImage!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  color: Colors.grey.shade200,
                                ),
                                child: _profileImage == null
                                    ? Icon(
                                        Iconsax.user,
                                        size: 50,
                                        color: Colors.grey.shade500,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade400,
                                        Colors.blue.shade600
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Iconsax.camera,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Full Name
                      _buildTextField(
                        controller: _fullNameController,
                        label: 'Full Name (Optional)',
                        hint: 'Enter your full name',
                        icon: Iconsax.user,
                      ),
                      const SizedBox(height: 16),
                      // University
                      _buildTextField(
                        controller: _universityController,
                        label: 'University',
                        hint: 'Enter your university',
                        icon: Iconsax.building,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter your university'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      // Add Governorate Dropdown after University field
                      _buildCard(
                        child: DropdownButtonFormField<String>(
                          value: _selectedGovernorate,
                          decoration: InputDecoration(
                            labelText: 'Governorate',
                            prefixIcon: Icon(Iconsax.location,
                                color: Colors.blue.shade600),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 20),
                            labelStyle: TextStyle(color: Colors.grey.shade700),
                          ),
                          items: _egyptianGovernorates.map((governorate) {
                            return DropdownMenuItem<String>(
                              value: governorate,
                              child: Text(
                                governorate,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedGovernorate = value);
                          },
                          validator: (value) => value == null
                              ? 'Please select your governorate'
                              : null,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Montserrat',
                            color: Colors.black87,
                          ),
                          dropdownColor: Colors.white,
                          icon: Icon(Icons.arrow_drop_down,
                              color: Colors.blue.shade600),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // College Dropdown
                      _buildCard(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCollege,
                          decoration: InputDecoration(
                            labelText: 'College',
                            prefixIcon:
                                Icon(Iconsax.book, color: Colors.blue.shade600),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 20),
                            labelStyle: TextStyle(color: Colors.grey.shade700),
                          ),
                          items: _colleges.map((college) {
                            return DropdownMenuItem<String>(
                              value: college,
                              child: Text(
                                college,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedCollege = value);
                          },
                          validator: (value) => value == null
                              ? 'Please select your college'
                              : null,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Montserrat',
                            color: Colors.black87,
                          ),
                          dropdownColor: Colors.white,
                          icon: Icon(Icons.arrow_drop_down,
                              color: Colors.blue.shade600),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Smoker Status
                      _buildCard(
                        child: Row(
                          children: [
                            Icon(Iconsax.health, color: Colors.blue.shade600),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Are you a smoker?',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade900,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ),
                            Switch(
                              value: _isSmoker,
                              onChanged: (value) =>
                                  setState(() => _isSmoker = value),
                              activeColor: Colors.blue.shade400,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Hobbies
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Iconsax.activity,
                                    color: Colors.blue.shade600),
                                const SizedBox(width: 16),
                                Text(
                                  'Your Hobbies',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _hobbies.map((hobby) {
                                final isSelected =
                                    _selectedHobbies.contains(hobby);
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedHobbies.remove(hobby);
                                      } else {
                                        _selectedHobbies.add(hobby);
                                      }
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue.shade50
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue.shade400
                                            : Colors.grey.shade300,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: Colors.blue.shade200
                                                    .withOpacity(0.3),
                                                blurRadius: 5,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Text(
                                      hobby,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isSelected
                                            ? Colors.blue.shade600
                                            : Colors.grey.shade800,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        fontFamily: 'Montserrat',
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Save Button
                      ScaleTransition(
                        scale: _fadeAnimation,
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade400,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                              shadowColor: Colors.blue.shade200,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    'Save Profile',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return _buildCard(
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.blue.shade600),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          labelStyle: TextStyle(color: Colors.grey.shade700),
        ),
        validator: validator,
        style: const TextStyle(fontSize: 16, fontFamily: 'Montserrat'),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}
