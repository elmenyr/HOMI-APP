import 'package:flutter/material.dart';

class ServiceUnavailableWidget extends StatelessWidget {
  const ServiceUnavailableWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.access_time,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'عذراً، نحن خارج ساعات العمل حالياً',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[800],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'يرجى العودة خلال ساعات العمل',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}