import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:homi/services/firebase_storage_service.dart';

class PropertyImageUploadWidget extends StatefulWidget {
  final Function(File coverImage) onCoverImageSelected;
  final Function(List<Map<String, String>> images) onImagesSelected;
  final String? initialCoverImage;
  final List<Map<String, String>>? initialImages;

  const PropertyImageUploadWidget({
    Key? key,
    required this.onCoverImageSelected,
    required this.onImagesSelected,
    this.initialCoverImage,
    this.initialImages,
  }) : super(key: key);

  @override
  State<PropertyImageUploadWidget> createState() => _PropertyImageUploadWidgetState();
}

class _PropertyImageUploadWidgetState extends State<PropertyImageUploadWidget> {
  final ImagePicker _picker = ImagePicker();
  File? _coverImage;
  String? _coverImageUrl;
  final List<Map<String, dynamic>> _propertyImages = [];
  bool _isUploadingCover = false;
  bool _isUploadingProperty = false;
  bool _isProcessing = false;
  double _coverUploadProgress = 0.0;
  double _propertyUploadProgress = 0.0;
  final List<String> _predefinedLabels = [
    'Bedroom',
    'Bathroom',
    'Kitchen',
    'Living Room',
    'Balcony',
    'Exterior',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _coverImageUrl = widget.initialCoverImage;
    if (widget.initialImages != null) {
      _propertyImages.addAll(widget.initialImages!.map((image) => {
        'url': image['url']!,
        'name': image['name'] ?? 'Image ${_propertyImages.length + 1}',
        'label': image['label'] ?? 'Other'
      }));
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        setState(() {
          _coverImage = imageFile;
          _isUploadingCover = true;
          _coverUploadProgress = 0.0;
        });

        final imageUrl = await FirebaseStorageService.uploadImage(
          imageFile,
          onProgress: (progress) {
            setState(() {
              _coverUploadProgress = progress;
            });
          },
        );

        if (imageUrl != null) {
          setState(() {
            _coverImageUrl = imageUrl;
          });
          widget.onCoverImageSelected(imageFile);
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to pick/upload cover image: $e');
    } finally {
      setState(() {
        _isUploadingCover = false;
        _coverUploadProgress = 0.0;
      });
    }
  }

  Future<void> _addPropertyImage() async {
    if (_isProcessing) return;
    try {
      setState(() => _isProcessing = true);
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _isUploadingProperty = true;
          _propertyUploadProgress = 0.0;
        });

        final imageFile = File(pickedFile.path);
        final imageUrl = await FirebaseStorageService.uploadImage(
          imageFile,
          onProgress: (progress) {
            setState(() {
              _propertyUploadProgress = progress;
            });
          },
        );

        if (imageUrl != null) {
          if (!mounted) return;
          final selectedLabel = await _showLabelSelectionDialog();
          if (selectedLabel != null) {
            final imageData = {
              'url': imageUrl,
              'name': selectedLabel,
              'label': selectedLabel,
            };
            setState(() {
              _propertyImages.add(imageData);
            });
            widget.onImagesSelected(_propertyImages.map((image) => {
              'url': image['url'] as String,
              'name': image['name'] as String,
              'label': image['label'] as String,
            }).toList());
          }
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to pick/upload image: $e');
    } finally {
      setState(() {
        _isUploadingProperty = false;
        _propertyUploadProgress = 0.0;
        _isProcessing = false;
      });
    }
  }

  Future<String?> _showLabelSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Image Type',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _predefinedLabels.map((label) => ListTile(
                leading: Icon(
                  label == 'Bedroom' ? Iconsax.box
                  : label == 'Bathroom' ? Iconsax.mirror
                  : label == 'Kitchen' ? Iconsax.cup
                  : label == 'Living Room' ? Iconsax.home
                  : label == 'Balcony' ? Iconsax.gallery
                  : label == 'Exterior' ? Iconsax.building
                  : Iconsax.image,
                  color: Colors.grey[700],
                ),
                title: Text(
                  label,
                  style: GoogleFonts.poppins(),
                ),
                onTap: () => Navigator.of(context).pop(label),
              )).toList(),
            ),
          ),
        );
      },
    );
  }

  void _removePropertyImage(int index) {
    final imageUrl = _propertyImages[index]['url'] as String;
    if (imageUrl.isNotEmpty) {
      FirebaseStorageService.deleteImage(imageUrl);
    }
    
    setState(() {
      _propertyImages.removeAt(index);
    });
    widget.onImagesSelected(_propertyImages.map((image) => {
      'url': image['url'] as String,
      'name': image['name'] as String,
      'label': image['label'] as String,
    }).toList());
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildCoverImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cover Image',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isUploadingCover ? null : _pickCoverImage,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: _isUploadingCover
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: _coverUploadProgress,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${(_coverUploadProgress * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : (_coverImage != null || _coverImageUrl != null)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _coverImage != null
                                ? Image.file(
                                    _coverImage!,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    _coverImageUrl!,
                                    fit: BoxFit.cover,
                                  ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            Center(
                              child: Icon(
                                Iconsax.edit,
                                size: 32,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Iconsax.gallery_add,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Click to add cover image',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Property Images',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: _propertyImages.length + 1,
          itemBuilder: (context, index) {
            if (index == _propertyImages.length) {
              return GestureDetector(
                onTap: _isUploadingProperty ? null : _addPropertyImage,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: _isUploadingProperty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: _propertyUploadProgress,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${(_propertyUploadProgress * 100).toStringAsFixed(0)}%',
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.gallery_add,
                              size: 32,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add Image',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              );
            }

            final image = _propertyImages[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      image['url'] as String,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Text(
                      image['label'] as String,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _removePropertyImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCoverImageSection(),
        const SizedBox(height: 32),
        _buildPropertyImagesSection(),
        if (_isUploadingCover || _isUploadingProperty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: _coverUploadProgress,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                ),
                const SizedBox(height: 8),
                Text(
                  'Uploading: ${(_coverUploadProgress * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}