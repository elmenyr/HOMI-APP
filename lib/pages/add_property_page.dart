import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:homi/models/property.dart';
import 'package:homi/models/admin_user.dart';
import 'package:homi/services/firebase_storage_service.dart';
import 'package:homi/widgets/property_image_upload_widget.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/scheduler.dart';

class AddPropertyPage extends StatefulWidget {
  final Property? property;
  const AddPropertyPage({super.key, this.property});

  @override
  State<AddPropertyPage> createState() => _AddPropertyPageState();
}

class _AddPropertyPageState extends State<AddPropertyPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  File? _coverImage;
  List<Map<String, dynamic>> _propertyImages = [];
  final _descriptionController = TextEditingController();
  final _agentPhoneController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _vrTourUrlController = TextEditingController();
  final _insuranceController = TextEditingController();
  final _videoUrlController = TextEditingController();

  String _selectedType = 'Apartment';
  String _selectedGender = 'Any';
  String _selectedPlan = 'Free';
  int _bedrooms = 1;
  int _bathrooms = 1;
  bool _isLoading = false;

  final ValueNotifier<bool> _hasAirCond = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _hasWifi = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isAvailable = ValueNotifier<bool>(true);

  late Future<bool> _adminCheckFuture;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _agentPhoneController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _vrTourUrlController.dispose();
    _insuranceController.dispose();
    _videoUrlController.dispose();
    _hasAirCond.dispose();
    _hasWifi.dispose();
    _isAvailable.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _adminCheckFuture = _checkAdminAccess();
    _initializeFormWithProperty();
  }

  Future<bool> _checkAdminAccess() async {
    final isAdmin = await AdminUser.isCurrentUserAdmin();
    if (!mounted) return false;
    if (!isAdmin) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only admin users can add properties',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      });
    }
    return isAdmin;
  }

  void _initializeFormWithProperty() {
    if (widget.property != null) {
      final property = widget.property!;
      _titleController.text = property.title;
      _priceController.text = property.price.toString();
      _locationController.text = property.location;
      _descriptionController.text = property.description;
      _agentPhoneController.text = property.agentPhone;
      _latitudeController.text = property.latitude.toString();
      _longitudeController.text = property.longitude.toString();
      _vrTourUrlController.text = property.vrTourUrl ?? '';
      _videoUrlController.text = property.videoUrl ?? '';
      _insuranceController.text = property.hasInsurance.toString();
      _selectedType = property.type;
      _selectedGender = property.gender;
      _selectedPlan = property.plan ?? 'Free';
      _bedrooms = property.bedrooms;
      _bathrooms = property.bathrooms;
      _hasAirCond.value = property.airCond;
      _hasWifi.value = property.hasWifi;
      _isAvailable.value = property.isAvailable;

      if (property.labeledPhotos.isNotEmpty) {
        _propertyImages.addAll(property.labeledPhotos.map((photo) =>
            {'url': photo['url'] ?? '', 'name': photo['label'] ?? ''}));
      }
    }
  }

  Future<void> _submitProperty() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final isAdmin = await _adminCheckFuture;
      if (!isAdmin) throw Exception('Only admin users can add properties');

      final property = Property(
        id: widget.property?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        price: double.parse(_priceController.text),
        location: _locationController.text,
        imageUrl: '',
        photos: [],
        labeledPhotos: [],
        bedrooms: _bedrooms,
        bathrooms: _bathrooms,
        airCond: _hasAirCond.value,
        description: _descriptionController.text,
        type: _selectedType,
        gender: _selectedGender,
        plan: _selectedPlan,
        createdAt: DateTime.now(),
        agentPhone: _agentPhoneController.text,
        latitude: double.parse(_latitudeController.text),
        longitude: double.parse(_longitudeController.text),
        isAvailable: _isAvailable.value,
        hasWifi: _hasWifi.value,
        hasInsurance: int.tryParse(_insuranceController.text) ?? 0,
        vrTourUrl: _vrTourUrlController.text.isNotEmpty
            ? _vrTourUrlController.text
            : null,
        videoUrl: _videoUrlController.text.isNotEmpty
            ? _videoUrlController.text
            : null,
      );

      String? coverImageUrl;
      if (_coverImage != null) {
        coverImageUrl = await FirebaseStorageService.uploadImage(_coverImage!);
        if (coverImageUrl == null)
          throw Exception('Failed to upload cover image to Firebase Storage');
      }

      final labeledPhotos = _propertyImages
          .map((image) => {
                'url': image['url'] as String,
                'name': image['name'] as String,
              })
          .toList();

      final photos =
          _propertyImages.map((image) => image['url'] as String).toList();

      final updatedProperty = Property(
        id: property.id,
        title: property.title,
        price: property.price,
        location: property.location,
        imageUrl: coverImageUrl ?? property.imageUrl,
        photos: photos,
        labeledPhotos: labeledPhotos,
        bedrooms: property.bedrooms,
        bathrooms: property.bathrooms,
        airCond: property.airCond,
        description: property.description,
        type: property.type,
        gender: property.gender,
        plan: property.plan,
        createdAt: property.createdAt,
        agentPhone: property.agentPhone,
        latitude: property.latitude,
        longitude: property.longitude,
        isAvailable: property.isAvailable,
        hasWifi: property.hasWifi,
        hasInsurance: property.hasInsurance,
        vrTourUrl: property.vrTourUrl,
        videoUrl: property.videoUrl,
      );

      await FirebaseFirestore.instance
          .collection('properties')
          .doc(property.id)
          .set(updatedProperty.toFirestore());

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.property != null
                ? 'Property updated successfully'
                : 'Property added successfully',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error adding property: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _adminCheckFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              color: Colors.grey.shade100,
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.black)),
            ),
          );
        }

        if (snapshot.data == false) {
          return const SizedBox.shrink();
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: _buildAppBar(),
          ),
          body: Container(
            color: Colors.grey.shade100,
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          widget.property != null
                              ? 'Update Property'
                              : 'Create New Property',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                            _titleController, 'Property Title', Iconsax.home),
                        _buildTextField(
                            _priceController, 'Price', Iconsax.money,
                            keyboardType: TextInputType.number),
                        _buildTextField(
                            _locationController, 'Location', Iconsax.location),
                        PropertyImageUploadWidget(
                          onCoverImageSelected: (image) {
                            setState(() => _coverImage = image);
                          },
                          onImagesSelected: (images) {
                            setState(() => _propertyImages = images);
                          },
                          initialCoverImage: widget.property?.imageUrl,
                          initialImages: widget.property?.labeledPhotos,
                        ),
                        _buildDropdown('Property Type', _selectedType,
                            ['Apartment', 'Studio', 'Villa', 'House'], (value) {
                          setState(() => _selectedType = value!);
                        }),
                        _buildDropdown('Preferred Gender', _selectedGender,
                            ['Male', 'Female', 'Any'], (value) {
                          setState(() => _selectedGender = value!);
                        }),
                        _buildDropdown(
                            'Plan', _selectedPlan, ['Free', 'Premium'],
                            (value) {
                          setState(() => _selectedPlan = value!);
                        }),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdown('Bedrooms', _bedrooms,
                                  List.generate(5, (i) => i + 1), (value) {
                                setState(() => _bedrooms = value!);
                              }),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDropdown('Bathrooms', _bathrooms,
                                  List.generate(3, (i) => i + 1), (value) {
                                setState(() => _bathrooms = value!);
                              }),
                            ),
                          ],
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _hasAirCond,
                          builder: (context, value, child) {
                            return _buildSwitchTile('Air Conditioning', value,
                                (newValue) => _hasAirCond.value = newValue);
                          },
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _hasWifi,
                          builder: (context, value, child) {
                            return _buildSwitchTile('WiFi', value,
                                (newValue) => _hasWifi.value = newValue);
                          },
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _isAvailable,
                          builder: (context, value, child) {
                            return _buildSwitchTile('Available', value,
                                (newValue) => _isAvailable.value = newValue);
                          },
                        ),
                        _buildTextField(
                            _insuranceController, 'Insurance', Iconsax.shield,
                            keyboardType: TextInputType.number),
                        _buildTextField(
                            _descriptionController, 'Description', Iconsax.text,
                            maxLines: 3),
                        _buildTextField(
                            _agentPhoneController, 'Agent Phone', Iconsax.call,
                            keyboardType: TextInputType.phone),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                  _latitudeController, 'Latitude', Iconsax.map,
                                  keyboardType: TextInputType.number),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(_longitudeController,
                                  'Longitude', Iconsax.map,
                                  keyboardType: TextInputType.number),
                            ),
                          ],
                        ),
                        _buildTextField(_vrTourUrlController,
                            'VR Tour URL (Optional)', Iconsax.video),
                        _buildTextField(_videoUrlController,
                            'Video URL (Optional)', Iconsax.video_play),
                        const SizedBox(height: 32),
                        _buildSubmitButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return AppBar(
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
      title: Text(
        'Add Property',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType, int? maxLines}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
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
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(icon, color: Colors.grey.shade600),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
          ),
          style: GoogleFonts.poppins(color: Colors.black),
          keyboardType: keyboardType ?? TextInputType.text,
          maxLines: maxLines ?? 1,
          validator: (v) =>
              (v?.isEmpty ?? true) && label != 'VR Tour URL (Optional)'
                  ? 'Required'
                  : null,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>(
      String label, T value, List<T> items, Function(T?) onChanged,
      {String Function(T)? displayText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
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
        child: DropdownButtonFormField<T>(
          value: value,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
          ),
          style: GoogleFonts.poppins(color: Colors.black),
          dropdownColor: Colors.white,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      displayText != null ? displayText(item) : item.toString(),
                      style: GoogleFonts.poppins(color: Colors.black),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
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
        child: SwitchListTile(
          title: Text(
            title,
            style: GoogleFonts.poppins(
                color: Colors.black, fontWeight: FontWeight.w500),
          ),
          value: value,
          activeColor: Colors.black,
          onChanged: onChanged,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          secondary: Icon(
            title == 'Air Conditioning'
                ? Iconsax.wind
                : title == 'WiFi'
                    ? Iconsax.wifi
                    : Iconsax.tick_circle,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _submitProperty,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    Text(
                      widget.property != null
                          ? 'Update Property'
                          : 'Add Property',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  if (!_isLoading) ...[
                    const SizedBox(width: 8),
                    const Icon(Iconsax.send_1, color: Colors.white, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
