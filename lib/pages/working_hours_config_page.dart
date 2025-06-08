import 'package:flutter/material.dart';
import 'package:homi/models/working_hours.dart';
import 'package:google_fonts/google_fonts.dart';

/// Configuration page for managing working hours with a modern design
class WorkingHoursConfigPage extends StatefulWidget {
  const WorkingHoursConfigPage({super.key});

  @override
  State<WorkingHoursConfigPage> createState() => _WorkingHoursConfigPageState();
}

class _WorkingHoursConfigPageState extends State<WorkingHoursConfigPage> {
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  /// Loads the current working hours configuration from storage
  Future<void> _loadCurrentConfig() async {
    try {
      final config = await WorkingHours.getCurrentConfig();
      if (mounted && config != null) {
        setState(() {
          _startTime = config.startTime;
          _endTime = config.endTime;
          _isEnabled = config.isEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      _handleError('Failed to load settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Displays a time picker dialog and updates the selected time
  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.grey.shade600,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  /// Saves the current configuration to storage
  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);

    try {
      final config = WorkingHours(
        id: 'working_hours',
        startTime: _startTime,
        endTime: _endTime,
        isEnabled: _isEnabled,
      );

      await config.save();
      if (mounted) {
        _showSnackBar('Working hours saved successfully', isSuccess: true);
      }
    } catch (e) {
      _handleError('Failed to save working hours: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Handles errors by displaying a snackbar and logging the error
  void _handleError(String message) {
    debugPrint(message);
    if (mounted) {
      _showSnackBar('An error occurred', isSuccess: false);
    }
  }

  /// Displays a snackbar with success or error styling
  void _showSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: isSuccess ? Colors.green.shade600 : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          'Working Hours Settings',
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
      ),
      body: _isLoading ? _buildLoading() : _buildContent(),
    );
  }

  /// Builds the loading state widget
  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
      ),
    );
  }

  /// Builds the main content widget
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSwitchTile(),
          const SizedBox(height: 24),
          _buildTimePicker('Start Time', _startTime, true),
          const SizedBox(height: 16),
          _buildTimePicker('End Time', _endTime, false),
          const Spacer(),
          _buildSaveButton(),
        ],
      ),
    );
  }

  /// Builds the enabled/disabled switch tile
  Widget _buildSwitchTile() {
    return Container(
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
          'Enable Working Hours',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        value: _isEnabled,
        onChanged: (value) => setState(() => _isEnabled = value),
        activeColor: Colors.black,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  /// Builds a time picker tile
  Widget _buildTimePicker(String title, TimeOfDay time, bool isStart) {
    return Container(
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
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        trailing: Text(
          time.format(context),
          style: GoogleFonts.poppins(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () => _selectTime(context, isStart),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  /// Builds the save button with modern styling
  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveConfig,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              'Save Changes',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
    );
  }
}