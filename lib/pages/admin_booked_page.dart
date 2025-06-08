// ignore_for_file: use_super_parameters, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:homi/widgets/admin_drawer.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:homi/models/working_hours.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminBookedPage extends StatefulWidget {
  const AdminBookedPage({Key? key}) : super(key: key);

  @override
  _AdminBookedPageState createState() => _AdminBookedPageState();
}

class _AdminBookedPageState extends State<AdminBookedPage> {
  String _statusFilter = 'all';
  String _sortBy = 'createdAt';
  bool _sortAscending = false;

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('propertyBookings');
    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }
    return query.orderBy(_sortBy, descending: !_sortAscending);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Booked Properties'),
      ),
      drawer: const AdminDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildFilterSortSection(),
            const SizedBox(height: 16),
            _buildRequestsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Text(
        'Admin - Property Booking Requests',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFilterSortSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildFilterMenu(),
          _buildSortMenu(),
        ],
      ),
    );
  }

  Widget _buildFilterMenu() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.filter_list, color: Colors.grey.shade600),
      onSelected: (value) => setState(() => _statusFilter = value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'all',
          child: Text('All Requests', style: GoogleFonts.poppins()),
        ),
        PopupMenuItem(
          value: 'pending',
          child: Text('Pending', style: GoogleFonts.poppins()),
        ),
        PopupMenuItem(
          value: 'approved',
          child: Text('Approved', style: GoogleFonts.poppins()),
        ),
        PopupMenuItem(
          value: 'rejected',
          child: Text('Rejected', style: GoogleFonts.poppins()),
        ),
      ],
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.sort, color: Colors.grey.shade600),
      onSelected: (value) {
        setState(() {
          if (_sortBy == value) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = true;
          }
        });
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'createdAt',
          child: Text('Date', style: GoogleFonts.poppins()),
        ),
      ],
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildRequestsList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _buildQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading requests',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          final requests = snapshot.data!.docs;
          if (requests.isEmpty) {
            return Center(
              child: Text('No requests found',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final data = requests[index].data()! as Map<String, dynamic>;
              data['id'] = requests[index].id;
              return _buildRequestCard(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final createdAt = (request['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM d, yyyy').format(createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
      child: ExpansionTile(
        title: Text(
          'Request #${request['id'].substring(0, 8)}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Property:', request['propertyTitle']?.toString() ?? 'N/A'),
                Row(
                  children: [
                    Text('Property ID: ',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                    Expanded(
                      child: Text(
                        request['propertyId']?.toString() ?? 'N/A',
                        style: GoogleFonts.poppins(color: Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: request['propertyId']?.toString() ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          _buildSnackBar('Property ID copied to clipboard', Colors.black),
                        );
                      },
                      child: Icon(Icons.copy, size: 16, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                _buildDetailRow('User:', request['userName']?.toString() ?? 'N/A'),
                GestureDetector(
                  onTap: () async {
                    final phoneNumber = request['userPhone']?.toString() ?? '';
                    final uri = Uri.parse('tel:$phoneNumber');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        _buildSnackBar('Could not launch phone app', Colors.red.shade600),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      Text('Phone: ',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      Text(
                        request['userPhone']?.toString() ?? 'N/A',
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                    ],
                  ),
                ),
                _buildDetailRow('Status:', request['status']?.toString() ?? 'N/A',
                    valueColor: _getStatusColor(request['status']?.toString() ?? '')),
                _buildDetailRow('Created:', formattedDate),
                const SizedBox(height: 12),
                _buildActionButtons(request),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
                color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(color: valueColor ?? Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> request) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        if (request['status'] == 'pending') ...[
          _buildActionButton(
            'Approve',
            Colors.green.shade600,
            () => _updateRequestStatus(request['id'] as String, 'approved'),
          ),
          _buildActionButton(
            'Reject',
            Colors.red.shade600,
            () => _updateRequestStatus(request['id'] as String, 'rejected'),
          ),
        ],
        IconButton(
          onPressed: () => _deleteRequest(request['id'] as String),
          icon: Icon(Icons.delete, color: Colors.red.shade600),
          tooltip: 'Delete Request',
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  SnackBar _buildSnackBar(String message, Color color) {
    return SnackBar(
      content: Text(
        message,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 2),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade600;
      case 'rejected':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('propertyBookings')
          .doc(requestId)
          .update({'status': newStatus});

      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Request $newStatus successfully', Colors.black),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Error: ${e.toString()}', Colors.red.shade600),
      );
    }
  }

  Future<void> _deleteRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Confirm Delete',
            style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete this booking request?',
            style: GoogleFonts.poppins(color: Colors.grey.shade600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete',
                style: GoogleFonts.poppins(color: Colors.red.shade600, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await FirebaseFirestore.instance
            .collection('propertyBookings')
            .doc(requestId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Request deleted successfully', Colors.black),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Error: ${e.toString()}', Colors.red.shade600),
        );
      }
    }
  }
}