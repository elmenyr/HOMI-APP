import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

class AddMedicalServicePage extends StatefulWidget {
  final Map<String, dynamic>? service;

  const AddMedicalServicePage({super.key, this.service});

  @override
  State<AddMedicalServicePage> createState() => _AddMedicalServicePageState();
}

class _AddMedicalServicePageState extends State<AddMedicalServicePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _whatsappController;
  late TextEditingController _specialtyController;
  late TextEditingController _latController;
  late TextEditingController _lonController;

  String _selectedType = 'hospital';
  bool _is247 = false;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    _nameController = TextEditingController(text: service?['name'] as String?);
    _addressController =
        TextEditingController(text: service?['address'] as String?);
    _phoneController =
        TextEditingController(text: service?['phone'] as String?);
    _whatsappController =
        TextEditingController(text: service?['whatsapp'] as String?);
    _specialtyController =
        TextEditingController(text: service?['specialty'] as String?);
    final location = service?['location'] as GeoPoint?;
    _latController = TextEditingController(text: location?.latitude.toString());
    _lonController =
        TextEditingController(text: location?.longitude.toString());
    _selectedType = service?['type'] as String? ?? 'hospital';
    _is247 = service?['is247'] as bool? ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _specialtyController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
        'whatsapp': _whatsappController.text,
        'type': _selectedType,
        'specialty':
            _selectedType == 'doctor' ? _specialtyController.text : null,
        'is247': _selectedType == 'pharmacy' ? _is247 : null,
        'location':
            (_latController.text.isNotEmpty && _lonController.text.isNotEmpty)
                ? GeoPoint(double.parse(_latController.text),
                    double.parse(_lonController.text))
                : null,
      };

      if (widget.service != null) {
        // Update
        await FirebaseFirestore.instance
            .collection('medical_services')
            .doc(widget.service!['id'] as String)
            .update(data);
      } else {
        // Create
        await FirebaseFirestore.instance
            .collection('medical_services')
            .add(data);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.service == null
            ? 'Add Medical Service'
            : 'Edit Medical Service'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: ['hospital', 'pharmacy', 'doctor']
                    .map((type) =>
                        DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedType = value!),
                decoration: const InputDecoration(labelText: 'Service Type'),
              ),
              _buildTextField(_nameController, 'Name', Iconsax.text),
              _buildTextField(_addressController, 'Address', Iconsax.location),
              _buildTextField(_phoneController, 'Phone', Iconsax.call),
              _buildTextField(_whatsappController,
                  'WhatsApp (with country code)', Iconsax.message),
              if (_selectedType == 'doctor')
                _buildTextField(
                    _specialtyController, 'Specialty', Iconsax.health),
              if (_selectedType == 'pharmacy')
                SwitchListTile(
                  title: const Text('Open 24/7'),
                  value: _is247,
                  onChanged: (value) => setState(() => _is247 = value),
                ),
              _buildTextField(_latController, 'Latitude', Iconsax.map),
              _buildTextField(_lonController, 'Longitude', Iconsax.map),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveService,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Save Service'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (label != 'WhatsApp (with country code)' &&
              (value == null || value.isEmpty)) {
            return 'Please enter a $label';
          }
          return null;
        },
      ),
    );
  }
}
