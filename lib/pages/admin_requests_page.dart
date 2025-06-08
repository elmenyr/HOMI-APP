// ignore_for_file: directives_ordering, use_super_parameters, library_private_types_in_public_api, noop_primitive_operations, join_return_with_assignment

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:homi/models/reservation_request.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homi/widgets/admin_drawer.dart';
import 'package:homi/services/notification_service.dart';

class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage({Key? key}) : super(key: key);

  @override
  _AdminRequestsPageState createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  String _statusFilter = 'all';
  String _sortBy = 'createdAt';
  bool _sortAscending = false;

  // Pagination variables
  static const int _pageSize = 25; // Increased from 10 to 25 requests per load
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final List<DocumentSnapshot> _requests = [];

  // Add scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _requests.clear();
      _lastDocument = null;
      _hasMoreData = true;
    });
    await _loadMoreData();
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      Query<Map<String, dynamic>> query = _buildQuery();

      // Apply pagination
      query = query.limit(_pageSize);
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
        return;
      }

      setState(() {
        _requests.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.last;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      _showErrorSnackBar('Error loading requests: $e');
    }
  }

  void _showErrorSnackBar(String message) {
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

  Future<void> _deleteRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Confirm Delete',
            style: GoogleFonts.poppins(
                color: Colors.black, fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete this request?',
            style: GoogleFonts.poppins(color: Colors.grey.shade600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    color: Colors.black, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete',
                style: GoogleFonts.poppins(
                    color: Colors.red.shade600, fontWeight: FontWeight.w500)),
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
          _buildSnackBar('Request deleted successfully', Colors.black),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Error: ${e.toString()}', Colors.red.shade600),
        );
      }
    }
  }

  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      final requestRef = FirebaseFirestore.instance
          .collection('reservationRequests')
          .doc(requestId);

      final requestSnapshot = await requestRef.get();
      final request = ReservationRequest.fromFirestore(requestSnapshot.data()!);
      final requestData = requestSnapshot.data() as Map<String, dynamic>;

      // Create a batch to perform multiple operations atomically
      final batch = FirebaseFirestore.instance.batch();

      // Update the request status
      batch.update(requestRef, {'status': newStatus});

      // If approved, add the user to the property's tenants array
      if (newStatus == 'approved') {
        final propertyId = requestData['propertyId'] as String?;
        final propertyTitle =
            requestData['propertyTitle'] as String? ?? 'Property';

        // Skip adding to property tenants if propertyId is not available
        // This handles general reservation requests not tied to a specific property
        if (propertyId != null && propertyId.isNotEmpty) {
          final propertyRef = FirebaseFirestore.instance
              .collection('properties')
              .doc(propertyId);

          // Create tenant object
          final tenant = {
            'userId': request.userId,
            'type': request.beds > 1 ? 'room' : 'bed',
            'startDate': FieldValue.serverTimestamp(),
          };

          // Add tenant to the property's tenants array
          // Using arrayUnion to avoid duplicates
          batch.update(propertyRef, {
            'tenants': FieldValue.arrayUnion([tenant])
          });
        }

        // Send notification to the user about the approval
        _sendApprovalNotification(request.userId, propertyId, propertyTitle);
      }

      // Commit the batch
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Request $newStatus successfully', Colors.black),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Error: ${e.toString()}', Colors.red.shade600),
      );
    }
  }

  Future<void> _sendApprovalNotification(
      String userId, String? propertyId, String propertyTitle) async {
    try {
      // Get the user's device token from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final deviceToken = userData['deviceToken'] as String?;

        if (deviceToken != null && deviceToken.isNotEmpty) {
          // Import at the top of the file: import '../services/notification_service.dart';
          await NotificationService.sendNotification(
            deviceToken,
            'Booking Request Approved',
            'Your booking request for $propertyTitle has been approved! You are now a tenant.',
            propertyId: propertyId,
          );
        }

        // Also save a notification in the user's notifications collection
        final notificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc();

        await notificationRef.set({
          'title': 'Booking Request Approved',
          'body':
              'Your booking request for $propertyTitle has been approved! You are now a tenant.',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'propertyId': propertyId ?? '',
        });
      }
    } catch (e) {
      print('Error sending approval notification: $e');
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

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  // Update the filter and sort methods to refresh data
  void _updateFilter(String value) {
    setState(() => _statusFilter = value);
    _refreshData();
  }

  void _updateSort(String value) {
    setState(() {
      if (_sortBy == value) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = value;
        _sortAscending = true;
      }
    });
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Requests'),
      ),
      drawer: const AdminDrawer(),
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildFilterSortSection(),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                child: _requests.isEmpty && !_isLoadingMore
                    ? const Center(child: Text('No requests found'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        itemCount: _requests.length + (_hasMoreData ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _requests.length) {
                            return _buildLoadingIndicator();
                          }

                          final data =
                              _requests[index].data()! as Map<String, dynamic>;
                          final request =
                              ReservationRequest.fromFirestore(data);
                          return _buildRequestCard(request);
                        },
                      ),
              ),
            ),
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
        'Admin - Reservation Requests',
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
      onSelected: _updateFilter,
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
      onSelected: _updateSort,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'createdAt',
          child: Text('Date', style: GoogleFonts.poppins()),
        ),
        PopupMenuItem(
          value: 'expectedPrice',
          child: Text('Price', style: GoogleFonts.poppins()),
        ),
        PopupMenuItem(
          value: 'beds',
          child: Text('Beds', style: GoogleFonts.poppins()),
        ),
      ],
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildRequestCard(ReservationRequest request) {
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
          'Request #${request.id.substring(0, 8)}',
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
                _buildDetailRow('Name:', request.name),
                _buildDetailRow('Price:', '${request.expectedPrice} EGP'),
                _buildDetailRow('Property Type:', request.propertyType),
                _buildDetailRow('Beds:', '${request.beds}'),
                _buildDetailRow('Status:', request.status,
                    valueColor: _getStatusColor(request.status)),
                GestureDetector(
                  onTap: () async {
                    final phoneNumber =
                        request.tenantPhone.replaceAll(RegExp(r'[^0-9]'), '');
                    final url = 'tel:$phoneNumber';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        _buildSnackBar(
                            'Could not launch phone app', Colors.red.shade600),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      Text('Phone: ',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      Text(
                        request.tenantPhone,
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
                _buildDetailRow('Location:', request.location),
                _buildDetailRow('Gender:', request.gender),
                _buildDetailRow(
                    'Created:', request.createdAt.toString().substring(0, 16)),
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
              style: GoogleFonts.poppins(
                  color: valueColor ?? Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ReservationRequest request) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        if (request.status == 'pending') ...[
          _buildActionButton(
            'Approve',
            Colors.green.shade600,
            () => _updateRequestStatus(request.id, 'approved'),
          ),
          _buildActionButton(
            'Reject',
            Colors.red.shade600,
            () => _updateRequestStatus(request.id, 'rejected'),
          ),
        ],
        Container(
          height: 40,
          child: IconButton(
            onPressed: () => _deleteRequest(request.id),
            icon: Icon(Icons.delete, color: Colors.red.shade600),
            tooltip: 'Delete Request',
          ),
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
}
