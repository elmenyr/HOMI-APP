import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import '../models/admin_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class AddServicePage extends StatefulWidget {
  final String? serviceId;
  final Map<String, dynamic>? serviceData;

  const AddServicePage({
    super.key,
    this.serviceId,
    this.serviceData,
  });

  @override
  State<AddServicePage> createState() => _AddServicePageState();
}

class _AddServicePageState extends State<AddServicePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _workingHoursController = TextEditingController();
  bool _isLoading = false;
  bool _isAdmin = false;
  File? _selectedImage;
  String? _selectedUniversity;
  String? _selectedCategory;
  List<String> _universities = [];
  List<String> _categories = [];

  Future<void> _loadUniversitiesAndCategories() async {
    try {
      final universitiesSnapshot = await FirebaseFirestore.instance
          .collection('universities')
          .orderBy('name')
          .get();
      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('categories')
          .orderBy('name')
          .get();

      if (mounted) {
        setState(() {
          _universities = universitiesSnapshot.docs
              .map((doc) => doc['name'] as String)
              .toList();
          _categories = categoriesSnapshot.docs
              .map((doc) => doc['name'] as String)
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading data: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _loadUniversitiesAndCategories();
    if (widget.serviceData != null) {
      _nameController.text = widget.serviceData!['name'] as String;
      _descriptionController.text = widget.serviceData!['description'] as String? ?? '';
      _phoneController.text = widget.serviceData!['phone'] as String;
      _locationController.text = widget.serviceData!['location'] as String;
      _workingHoursController.text = widget.serviceData!['workingHours'] as String? ?? '';
      _selectedUniversity = widget.serviceData!['university'] as String?;
      _selectedCategory = widget.serviceData!['category'] as String?;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _workingHoursController.dispose();
    // Controllers disposed
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _isAdmin = docSnapshot.exists;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    setState(() => _isLoading = true);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error picking image: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String> _uploadImageToFirebaseStorage(File imageFile) async {
    try {
      // Create a unique filename
      String fileName = 'services/${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      
      // Create a reference to the Firebase Storage location
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      
      // Show upload progress
      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      // Wait for the upload to complete and get the download URL
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('Image uploaded to Firebase Storage: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading image to Firebase Storage: $e');
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        try {
          // Show loading indicator for image upload
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(width: 16),
                  Text(
                    'Uploading image...',
                    style: GoogleFonts.poppins(),
                  ),
                ],
              ),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.black87,
            ),
          );

          imageUrl = await _uploadImageToFirebaseStorage(_selectedImage!);
        } catch (e) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error uploading image: ${e.toString()}',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      if (_selectedUniversity == null || _selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select both university and category',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'workingHours': _workingHoursController.text.trim(),
        'university': _selectedUniversity,
        'category': _selectedCategory,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (imageUrl != null) {
        data['photoUrl'] = imageUrl;
      }

      if (widget.serviceId != null) {
        // Update existing service
        await FirebaseFirestore.instance
            .collection('services')
            .doc(widget.serviceId)
            .update(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Service updated successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Add new service
        data['createdAt'] = FieldValue.serverTimestamp();
        data['rating'] = 0.0;
        
        await FirebaseFirestore.instance
            .collection('services')
            .add(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Service added successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error ${widget.serviceId != null ? 'updating' : 'adding'} service: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Function to validate URL
  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          widget.serviceId != null ? 'Edit Service' : 'Add Service',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Selection
              Stack(
                children: [
                  GestureDetector(
                    onTap: _isLoading ? null : _pickImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: FileImage(_selectedImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _selectedImage == null && _isAdmin
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Iconsax.image,
                                  size: 48,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to select image',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                  if (_selectedImage != null && _isAdmin)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedImage = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Name Field
              TextFormField(
                controller: _nameController,
                enabled: _isAdmin,
                decoration: InputDecoration(
                  labelText: 'Service Name',
                  hintText: 'Enter service name',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
                  prefixIcon: Icon(Iconsax.shop, color: Colors.grey.shade600),
                  border: InputBorder.none,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.poppins(color: Colors.black),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter service name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                enabled: _isAdmin,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter service description',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
                  prefixIcon: Icon(Iconsax.document_text, color: Colors.grey.shade600),
                  border: InputBorder.none,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.poppins(color: Colors.black),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter service description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Location Field (Updated to accept URL)
              TextFormField(
                controller: _locationController,
                enabled: _isAdmin,
                decoration: InputDecoration(
                  labelText: 'Location URL',
                  hintText: 'Enter location URL (e.g., https://maps.google.com/...)',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
                  prefixIcon: Icon(Iconsax.link, color: Colors.grey.shade600), // Changed icon to a link icon
                  border: InputBorder.none,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.poppins(color: Colors.black),
                keyboardType: TextInputType.url, // Set keyboard type to URL
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a location URL';
                  }
                  if (!_isValidUrl(value)) {
                    return 'Please enter a valid URL (e.g., https://...)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // University Dropdown
              TextFormField(
                controller: TextEditingController(text: _selectedUniversity),
                enabled: _isAdmin,
                decoration: InputDecoration(
                  labelText: 'University',
                  hintText: 'Enter university name',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
                  prefixIcon: Icon(Iconsax.building, color: Colors.grey.shade600),
                  border: InputBorder.none,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.poppins(color: Colors.black),
                onChanged: _isAdmin
                    ? (String newValue) {
                        setState(() {
                          _selectedUniversity = newValue;
                        });
                      }
                    : null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a university';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              TextFormField(
                controller: TextEditingController(text: _selectedCategory),
                enabled: _isAdmin,
                decoration: InputDecoration(
                  labelText: 'Category',
                  hintText: 'Enter category name',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
                  prefixIcon: Icon(Iconsax.category, color: Colors.grey.shade600),
                  border: InputBorder.none,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.poppins(color: Colors.black),
                onChanged: _isAdmin
                    ? (String newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      }
                    : null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Number Field
              TextFormField(
                controller: _phoneController,
                enabled: _isAdmin,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter phone number',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
                  prefixIcon: Icon(Iconsax.call, color: Colors.grey.shade600),
                  border: InputBorder.none,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.poppins(color: Colors.black),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  // Basic phone number validation
                  if (!RegExp(r'^[+]?[0-9-]+$').hasMatch(value)) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Working Hours Field
              TextFormField(
                controller: _workingHoursController,
                enabled: _isAdmin,
                decoration: InputDecoration(
                  labelText: 'Working Hours',
                  hintText: 'Enter working hours (e.g., 9 AM - 6 PM)',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
                  prefixIcon: Icon(Iconsax.clock, color: Colors.grey.shade600),
                  border: InputBorder.none,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.poppins(color: Colors.black),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter working hours';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              if (_isAdmin)
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Add Service',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}