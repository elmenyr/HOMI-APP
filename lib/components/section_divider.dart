import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SectionDivider extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? color;

  const SectionDivider({
    super.key,
    required this.title,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: color ?? Colors.grey.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
              ],
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (color ?? Colors.grey.shade300).withOpacity(0.5),
                        (color ?? Colors.grey.shade300).withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
