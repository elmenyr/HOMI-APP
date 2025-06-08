// ignore_for_file: directives_ordering, use_super_parameters, library_private_types_in_public_api, noop_primitive_operations, join_return_with_assignment

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:homi/models/reservation_request.dart';

class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage({Key? key}) : super(key: key);

  @override
  _AdminRequestsPageState createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  String _statusFilter = 'all';
  String _sortBy = 'createdAt';
  bool _sortAscending = false;

  Future<void> _deleteRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.blue[800])),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await FirebaseFirestore.instance
            .collection('reservationRequests')
            .doc(requestId)
            .delete();
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Request deleted successfully', Colors.blue[800]!),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Error: ${e.toString()}', Colors.red),
        );
      }
    }
  }

  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('reservationRequests')
          .doc(requestId)
          .update({'status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Request $newStatus successfully', Colors.blue[800]!),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Error: ${e.toString()}', Colors.red),
      );
    }
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('reservationRequests');
    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }
    return query.orderBy(_sortBy, descending: !_sortAscending);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        title: const Text(
          'Reservation Requestts',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          _buildFilterMenu(),
          _buildSortMenu(),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data!.docs;
          if (requests.isEmpty) {
            return const Center(child: Text('No requests found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final data = requests[index].data()! as Map<String, dynamic>;
              final request = ReservationRequest.fromFirestore(data);
              return _buildRequestCard(request);
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterMenu() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.filter_list, color: Colors.white),
      onSelected: (value) => setState(() => _statusFilter = value),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'all', child: Text('All Requests')),
        const PopupMenuItem(value: 'pending', child: Text('Pending')),
        const PopupMenuItem(value: 'approved', child: Text('Approved')),
        const PopupMenuItem(value: 'rejected', child: Text('Rejected')),
      ],
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.sort, color: Colors.white),
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
        const PopupMenuItem(value: 'createdAt', child: Text('Date')),
        const PopupMenuItem(value: 'expectedPrice', child: Text('Price')),
        const PopupMenuItem(value: 'beds', child: Text('Beds')),
      ],
    );
  }

  Widget _buildRequestCard(ReservationRequest request) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(
          'Request #${request.id.substring(0, 8)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${request.propertyType} - ${request.beds} beds - ${request.status}',
          style: TextStyle(color: _getStatusColor(request.status)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Price:', '\$${request.expectedPrice}'),
                _buildDetailRow('Location:', request.location),
                _buildDetailRow('Phone:', request.tenantPhone),
                _buildDetailRow('Gender:', request.gender),
                _buildDetailRow('Created:', request.createdAt.toString().substring(0, 16)),
                const SizedBox(height: 12),
                _buildActionButtons(request),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ReservationRequest request) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (request.status == 'pending') ...[
          _buildActionButton(
            'Approve',
            Colors.green,
            () => _updateRequestStatus(request.id, 'approved'),
          ),
          _buildActionButton(
            'Reject',
            Colors.red,
            () => _updateRequestStatus(request.id, 'rejected'),
          ),
        ],
        IconButton(
          onPressed: () => _deleteRequest(request.id),
          icon: Icon(Icons.delete, color: Colors.red),
          tooltip: 'Delete Request',
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  SnackBar _buildSnackBar(String message, Color color) {
    return SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blue[800]!;
    }
  }
}