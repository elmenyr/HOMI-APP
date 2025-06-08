import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iconsax/iconsax.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/reservation_request.dart';
import '../models/working_hours.dart';
import '../models/admin_user.dart';
import '../widgets/admin_drawer.dart';
import 'agents_page.dart';

class ReservationFormPage extends StatefulWidget {
  const ReservationFormPage({super.key});

  @override
  _ReservationFormPageState createState() => _ReservationFormPageState();
}

class _ReservationFormPageState extends State<ReservationFormPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bedsController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedPropertyType = 'Apartment';
  String _selectedGender = 'Male';
  bool _isLoading = false;
  Stream<DocumentSnapshot>? _requestStatusStream;
  String? _currentRequestId;
  late AnimationController _animationController;
  final Logger _logger = Logger('ReservationFormPage');
  bool _isAdmin = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    });
    _loadLastRequestId();
    _checkAdminStatus();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    
    // Show welcome message on first visit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeMessageIfFirstTime();
    });
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await AdminUser.isCurrentUserAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  @override
  void dispose() {
    _currentRequestId = null;
    _nameController.dispose();
    _bedsController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    _logger.info('Submitting reservation request');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final isAvailable = await WorkingHours.isServiceAvailable();
      if (!isAvailable) {
        setState(() => _isLoading = false);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar(AppLocalizations.of(context)!.outsideWorkingHours, Colors.grey[700]!),
        );
        return;
      }

      final existingRequests = await FirebaseFirestore.instance
          .collection('reservationRequests')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'approved']).get();

      if (existingRequests.docs.isNotEmpty) {
        setState(() => _isLoading = false);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar(AppLocalizations.of(context)!.alreadyRequested, Colors.grey[700]!),
        );
        return;
      }

      final request = ReservationRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        name: _nameController.text,
        beds: int.parse(_bedsController.text),
        expectedPrice: double.parse(_priceController.text),
        propertyType: _selectedPropertyType,
        location: _locationController.text,
        tenantPhone: _phoneController.text,
        gender: _selectedGender,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('reservationRequests')
          .doc(request.id)
          .set(request.toFirestore());

      _logger.info('Request submitted: ${request.id}');

      setState(() {
        _currentRequestId = request.id;
        _requestStatusStream = FirebaseFirestore.instance
            .collection('reservationRequests')
            .doc(request.id)
            .snapshots();
        _clearForm();
      });

      await _saveRequestId(request.id);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            AppLocalizations.of(context)!.thankYou,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          content: Text(
            AppLocalizations.of(context)!.requestSubmitted,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppLocalizations.of(context)!.ok,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      _logger.severe('Error submitting request: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Error: ${e.toString()}', Colors.grey[700]!),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLastRequestId() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRequestId = prefs.getString('lastRequestId');
    if (lastRequestId != null) {
      _logger.info('Loaded last request ID: $lastRequestId');
      setState(() {
        _currentRequestId = lastRequestId;
        _requestStatusStream = FirebaseFirestore.instance
            .collection('reservationRequests')
            .doc(lastRequestId)
            .snapshots();
      });
    }
  }

  Future<void> _saveRequestId(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastRequestId', requestId);
    _logger.info('Saved request ID: $requestId');
  }

  void _clearForm() {
    _nameController.clear();
    _bedsController.clear();
    _priceController.clear();
    _locationController.clear();
    _phoneController.clear();
    _selectedPropertyType = 'Apartment';
    _selectedGender = 'Male';
  }

  void _resetForm() {
    setState(() {
      _currentRequestId = null;
      _requestStatusStream = null;
      _clearForm();
    });
    _animationController.reset();
    _animationController.forward();
    _logger.info('Form reset for new request');
  }

  Future<void> _showWelcomeMessageIfFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShownWelcome = prefs.getBool('has_shown_request_welcome') ?? false;
    final l10n = AppLocalizations.of(context)!;
    
    if (!hasShownWelcome && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Iconsax.info_circle, color: Colors.teal[400], size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.requestFormTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.requestDescription,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.contactAgent,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AgentsPage()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.user_tag, size: 20, color: Colors.teal[400]),
                      const SizedBox(width: 12),
                      Text(
                        l10n.agentsPage,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.teal[700],
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                prefs.setBool('has_shown_request_welcome', true);
              },
              child: Text(
                l10n.gotIt,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/req.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                _logger.warning('Failed to load req.png');
                return Icon(
                  Iconsax.house,
                  size: 24,
                  color: Colors.black,
                );
              },
            ),
            const SizedBox(width: 12),
            Text(
              l10n.requestFormTitle,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: _isAdmin
            ? IconButton(
                icon: Icon(Icons.menu, color: Colors.black87),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : null,
      ),
      drawer: _isAdmin ? const AdminDrawer() : null,
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: FadeTransition(
                      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: _currentRequestId != null
                            ? _buildStatusCard()
                            : _buildFormCard(),
                      ),
                    ),
                  ),
                  if (_currentRequestId != null) ...[
                    const SizedBox(height: 24),
                  ],
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _requestStatusStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _logger.severe('Error in status stream: ${snapshot.error}');
          return _buildErrorCard('Error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              strokeWidth: 3,
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          _logger.warning('No request found for ID: $_currentRequestId');
          return _buildErrorCard('No request found');
        }

        final status = snapshot.data!.get('status') as String? ?? 'pending';
        if (status == 'rejected' && mounted) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    title: Text(
                      l10n.rejected,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    content: Text(
                      l10n.statusRejectedMessage,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Future.microtask(() async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('lastRequestId');
                            if (mounted) {
                              setState(() {
                                _currentRequestId = null;
                                _requestStatusStream = null;
                              });
                            }
                          });
                        },
                        child: Text(
                          'OK',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            }
          });
        } else if (status == 'accepted' || status == 'approved') {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    title: Text(
                      l10n.approved,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    content: Text(
                      l10n.statusApprovedMessage,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Future.microtask(() async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('lastRequestId');
                            if (mounted) {
                              setState(() {
                                _currentRequestId = null;
                                _requestStatusStream = null;
                              });
                            }
                          });
                        },
                        child: Text(
                          'OK',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            }
          });
        }

        return _StatusCard(
          status: status,
          onTap: _resetForm,
        );
      },
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Iconsax.warning_2, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again or contact support.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    final l10n = AppLocalizations.of(context)!;
    return _FormCard(
      formKey: _formKey,
      nameController: _nameController,
      bedsController: _bedsController,
      priceController: _priceController,
      locationController: _locationController,
      phoneController: _phoneController,
      selectedPropertyType: _selectedPropertyType,
      selectedGender: _selectedGender,
      isLoading: _isLoading,
      onPropertyTypeChanged: (value) =>
          setState(() => _selectedPropertyType = value),
      onGenderChanged: (value) => setState(() => _selectedGender = value),
      onSubmit: _submitForm,
      context: context,
    );
  }

  SnackBar _buildSnackBar(String message, Color color) {
    return SnackBar(
      content: Text(
        message,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
          letterSpacing: 0.3,
        ),
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      elevation: 4,
      duration: const Duration(seconds: 4),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String status;
  final VoidCallback onTap;

  const _StatusCard({
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Iconsax.document_text,
                  size: 28,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.requestStatus,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.processingRequest,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.currentStatus,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                    _buildStatusBadge(status, l10n),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  getStatusMessage(status, l10n),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onTap,
            icon: Icon(Iconsax.refresh, size: 18, color: Colors.black),
            label: Text(
              l10n.createNewRequest,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String getStatusMessage(String status, AppLocalizations l10n) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'accepted':
        return l10n.statusApprovedMessage;
      case 'rejected':
        return l10n.statusRejectedMessage;
      default:
        return l10n.statusPendingMessage;
    }
  }

  Widget _buildStatusBadge(String status, AppLocalizations l10n) {
    Color? color;
    IconData icon;
    String displayStatus;

    switch (status.toLowerCase()) {
      case 'approved':
      case 'accepted':
        color = Colors.green[600];
        icon = Icons.check_circle_outline;
        displayStatus = l10n.approved;
        break;
      case 'rejected':
        color = Colors.red[600];
        icon = Icons.cancel_outlined;
        displayStatus = l10n.rejected;
        break;
      default:
        color = Colors.amber[600];
        icon = Icons.access_time;
        displayStatus = l10n.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color!.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            displayStatus,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController bedsController;
  final TextEditingController priceController;
  final TextEditingController locationController;
  final TextEditingController phoneController;
  final String selectedPropertyType;
  final String selectedGender;
  final bool isLoading;
  final void Function(String) onPropertyTypeChanged;
  final void Function(String) onGenderChanged;
  final VoidCallback onSubmit;
  final BuildContext context;

  const _FormCard({
    required this.formKey,
    required this.nameController,
    required this.bedsController,
    required this.priceController,
    required this.locationController,
    required this.phoneController,
    required this.selectedPropertyType,
    required this.selectedGender,
    required this.isLoading,
    required this.onPropertyTypeChanged,
    required this.onGenderChanged,
    required this.onSubmit,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(l10n.personalInformation, Iconsax.user),
            _buildTextField(
              nameController,
              l10n.fullName,
              TextInputType.text,
              Iconsax.user,
              hint: l10n.enterFullName,
            ),
            _buildTextField(
              phoneController,
              l10n.phoneNumber,
              TextInputType.phone,
              Iconsax.call,
              hint: l10n.enterPhoneNumber,
            ),
            _buildDropdown(
              'Gender',
              ['Male', 'Female'],
              selectedGender,
              onGenderChanged,
              icon: Iconsax.user,
              itemLabels: {
                'Male': l10n.male,
                'Female': l10n.female,
              },
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(l10n.propertyDetails, Iconsax.building),
            _buildDropdown(
              'Property Type',
              ['Apartment', 'Studio'],
              selectedPropertyType,
              onPropertyTypeChanged,
              icon: Iconsax.home,
              itemLabels: {
                'Apartment': l10n.apartment,
                'Studio': l10n.studio,
              },
            ),
            _buildTextField(
              locationController,
              l10n.preferredLocation,
              TextInputType.text,
              Iconsax.location,
              hint: l10n.whereToLive,
            ),
            _buildTextField(
              bedsController,
              l10n.numberOfBeds,
              TextInputType.number,
              Icons.bed,
              hint: l10n.howManyBeds,
            ),
            _buildTextField(
              priceController,
              l10n.budgetPerMonth,
              const TextInputType.numberWithOptions(decimal: true),
              Iconsax.money,
              hint: l10n.yourMonthlyBudget,
              prefix: l10n.currency,
            ),
            const SizedBox(height: 40),
            Center(child: _buildSubmitButton(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.black),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    TextInputType type,
    IconData icon, {
    String? hint,
    String? prefix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.black54, size: 22),
          prefixText: prefix,
          prefixStyle: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          labelStyle: GoogleFonts.poppins(
            color: Colors.black54,
            fontSize: 16,
            letterSpacing: 0.3,
          ),
          hintStyle: GoogleFonts.poppins(
            color: Colors.black38,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
          filled: true,
          fillColor: Colors.black.withOpacity(0.03),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.black87, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        keyboardType: type,
        style: GoogleFonts.poppins(
          color: Colors.black87,
          fontSize: 16,
          letterSpacing: 0.3,
        ),
        cursorColor: Colors.black87,
        validator: (value) => _validateField(value, label, AppLocalizations.of(context)!),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String value,
    Function(String) onChanged, {
    IconData? icon,
    Map<String, String>? itemLabels,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items[0],
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null
              ? Icon(icon, color: Colors.black54, size: 22)
              : null,
          labelStyle: GoogleFonts.poppins(
            color: Colors.black54,
            fontSize: 16,
            letterSpacing: 0.3,
          ),
          filled: true,
          fillColor: Colors.black.withOpacity(0.03),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.black87, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        style: GoogleFonts.poppins(
          color: Colors.black87,
          fontSize: 16,
          letterSpacing: 0.3,
        ),
        dropdownColor: Colors.white,
        icon: Icon(Icons.keyboard_arrow_down, color: Colors.black54),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    itemLabels?[item] ?? item,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ))
            .toList(),
        onChanged: (newValue) => onChanged(newValue!),
      ),
    );
  }

  Widget _buildSubmitButton(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onSubmit,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.submit,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 3,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Iconsax.send_1,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String? _validateField(String? value, String fieldName, AppLocalizations l10n) {
    if (value == null || value.isEmpty) {
      return l10n.fillAllFields;
    }

    if (fieldName == l10n.numberOfBeds) {
      final beds = int.tryParse(value);
      if (beds == null) return l10n.invalidNumber;
      if (beds <= 0) return l10n.mustBeGreaterThanZero.toString().replaceAll('{field}', fieldName);
    }

    if (fieldName == l10n.budgetPerMonth) {
      final price = double.tryParse(value);
      if (price == null) return l10n.invalidNumber;
      if (price <= 0) return l10n.mustBeGreaterThanZero.toString().replaceAll('{field}', fieldName);
    }

    return null;
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
