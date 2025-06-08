// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WorkingHours {
  final String id;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isEnabled;

  WorkingHours({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.isEnabled = true,
  });

  factory WorkingHours.fromMap(Map<String, dynamic> map, String id) {
    return WorkingHours(
      id: id,
      startTime: _timeFromString(map['startTime'] as String),
      endTime: _timeFromString(map['endTime'] as String),
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': '${startTime.hour}:${startTime.minute}',
      'endTime': '${endTime.hour}:${endTime.minute}',
      'isEnabled': isEnabled,
    };
  }

  static TimeOfDay _timeFromString(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static Future<WorkingHours?> getCurrentConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('working_hours')
          .get();

      if (doc.exists) {
        return WorkingHours.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting working hours: $e');
      return null;
    }
  }

  static Future<bool> isServiceAvailable() async {
    final config = await getCurrentConfig();
    if (config == null) return true; // Default to available if no config
    
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = config.startTime.hour * 60 + config.startTime.minute;
    final endMinutes = config.endTime.hour * 60 + config.endTime.minute;
    
    if (!config.isEnabled) return false;
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  Future<void> save() async {
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('working_hours')
          .set(toMap());
    } catch (e) {
      print('Error saving working hours: $e');
      rethrow;
    }
  }
}