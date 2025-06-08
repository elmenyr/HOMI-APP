import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';

enum UnitType {
  entireApartment,
  privateRoom,
  sharedBed,
}

class UnitTypeSelector extends StatefulWidget {
  final void Function(UnitType) onTypeSelected;
  final UnitType? initialValue;

  const UnitTypeSelector({
    super.key,
    required this.onTypeSelected,
    this.initialValue,
  });

  @override
  State<UnitTypeSelector> createState() => _UnitTypeSelectorState();
}

class _UnitTypeSelectorState extends State<UnitTypeSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  UnitType? _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialValue;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  final Map<UnitType, Map<String, dynamic>> _unitTypeData = {
    UnitType.entireApartment: {
      'title': 'Entire Apartment',
      'icon': Iconsax.building_4,
      'description': 'Have the whole place to yourself',
      'color': Colors.blue,
      'gradient': [Colors.blue.shade400, Colors.blue.shade600],
      'features': ['Private kitchen', 'Private bathroom', 'Full privacy'],
    },
    UnitType.privateRoom: {
      'title': 'Private Room',
      'icon': Iconsax.home,
      'description': 'Your own room, shared common spaces',
      'color': Colors.purple,
      'gradient': [Colors.purple.shade400, Colors.purple.shade600],
      'features': ['Private bedroom', 'Shared kitchen', 'Shared bathroom'],
    },
    UnitType.sharedBed: {
      'title': 'Shared Bed',
      'icon': Iconsax.home_2,
      'description': 'Share a room with others',
      'color': Colors.teal,
      'gradient': [Colors.teal.shade400, Colors.teal.shade600],
      'features': ['Shared bedroom', 'Shared kitchen', 'Shared bathroom'],
    },
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Unit Type',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to book the property',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth > 600;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: UnitType.values.map((type) {
                final data = _unitTypeData[type]!;
                final isSelected = _selectedType == type;
                final color = data['color'] as MaterialColor;
                final features = data['features'] as List<String>;

                return ScaleTransition(
                  scale: _scaleAnimation,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedType = type);
                      widget.onTypeSelected(type);
                      _controller.reset();
                      _controller.forward();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: isWideScreen
                          ? (constraints.maxWidth - 32) / 3
                          : constraints.maxWidth,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isSelected
                              ? (data['gradient'] as List<Color>)
                              : [Colors.white, Colors.white],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : Colors.grey.shade200,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? color.shade400.withOpacity(0.3)
                                : Colors.grey.shade100,
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.2)
                                      : color.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  data['icon'] as IconData,
                                  size: 28,
                                  color: isSelected
                                      ? Colors.white
                                      : color.shade600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['title'] as String,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['description'] as String,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.9)
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ...features
                              .map((feature) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 18,
                                          color: isSelected
                                              ? Colors.white
                                              : color.shade400,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          feature,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
