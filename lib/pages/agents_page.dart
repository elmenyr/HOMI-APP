// ignore_for_file: directives_ordering, unawaited_futures, omit_local_variable_types

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:logging/logging.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'agent_details_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// For agent profile image upload using Cloudinary
// import 'package:homi/services/cloudinary_service.dart';

class AgentsPage extends StatefulWidget {
  const AgentsPage({super.key});

  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage> {
  static const int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  List<Map<String, dynamic>> _agents = [];
  final ValueNotifier<bool> _isInitialLoad = ValueNotifier<bool>(true);
  final Logger _logger = Logger('AgentsPage');

  @override
  void initState() {
    super.initState();
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    });
    _loadMoreAgents();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _isInitialLoad.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        _hasMore) {
      _loadMoreAgents();
    }
  }

  Future<void> _loadMoreAgents() async {
    if (_isLoading || !mounted) return;

    setState(() => _isLoading = true);
    _logger.info('Fetching agents, lastDocument: $_lastDocument');

    try {
      Query query = FirebaseFirestore.instance
          .collection('agents')
          .limit(_pageSize)
          .orderBy('name');
      
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final QuerySnapshot snapshot = await query.get();

      if (!mounted) return;

      _logger.info('Fetched ${snapshot.docs.length} agents');

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _agents.addAll(snapshot.docs.map((doc) => {
              'id': doc.id,
              ...doc.data()! as Map<String, dynamic>,
            }).toList());
        _lastDocument = snapshot.docs.last;
        _isLoading = false;
        if (_isInitialLoad.value) _isInitialLoad.value = false;
      });
      _logger.info('Total agents loaded: ${_agents.length}');
    } catch (e) {
      if (!mounted) return;

      _logger.severe('Error loading agents: $e');
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load agents');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _refreshAgents() async {
    if (!mounted) return;

    setState(() {
      _agents.clear();
      _lastDocument = null;
      _hasMore = true;
      _isInitialLoad.value = true;
    });
    await _loadMoreAgents();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/agent.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                _logger.warning('Failed to load agent.png');
                return Icon(
                  Iconsax.people,
                  size: 24,
                  color: Colors.black,
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              l10n.propertyAgents,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAgents,
        color: Colors.black,
        backgroundColor: Colors.white,
        child: ValueListenableBuilder<bool>(
          valueListenable: _isInitialLoad,
          builder: (context, isInitial, child) {
            if (isInitial && _isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  strokeWidth: 2,
                ),
              );
            }
            
            if (_agents.isEmpty && !_isLoading) {
              return _buildEmptyState();
            }

            return _buildAgentList();
          },
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Iconsax.people,
            size: 54,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noAgentsAvailable,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.checkBackAgents,
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
  
  Widget _buildAgentList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _agents.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _agents.length) {
          return _buildLoadingIndicator();
        }
        return _buildAgentCard(index);
      },
    );
  }
  
  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        strokeWidth: 2,
      ),
    );
  }
  
  Widget _buildAgentCard(int index) {
    final l10n = AppLocalizations.of(context)!;
    final agent = _agents[index];
    final specialization = agent['specialization'] as String? ?? l10n.realEstate;
    final name = (agent['name'] as String?) ?? l10n.unnamedAgent;
    final phone = agent['phone']?.toString() ?? l10n.noPhone;
    final imageUrl = agent['imageUrl'] as String?;
    final experience = agent['experience'] as int? ?? 0;
    final email = agent['email'] as String? ?? '';
    
    // Get specialty badge color based on specialization
    Color badgeColor;
    switch (specialization) {
      case 'Real Estate':
        badgeColor = Colors.blue.shade100;
        break;
      case 'Insurance':
        badgeColor = Colors.orange.shade100;
        break;
      default:
        badgeColor = Colors.green.shade100;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            offset: const Offset(0, 2),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AgentDetailsPage(
                  agentId: agent['id'] as String,
                  agentData: agent,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile image with specialty indicator
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                                  ),
                                ),
                                errorWidget: (context, url, error) => _buildAvatarFallback(name),
                              )
                            : _buildAvatarFallback(name),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          specialization.split(' ')[0],
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(width: 16),
                
                // Agent details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Name with verification badge if applicable
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (experience >= 5)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.verified,
                                      size: 16,
                                      color: Colors.blue[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          // Experience badge
                          if (experience > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.yearsExperience(experience),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Contact details with icons
                      Row(
                        children: [
                          Icon(Iconsax.call, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              phone,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Iconsax.sms, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                email,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 8),
                      
                      // Contact buttons
                      Row(
                        children: [
                          _buildContactButton(
                            icon: Iconsax.call,
                            label: l10n.call,
                            color: Colors.green.shade100,
                            iconColor: Colors.green.shade700,
                            onTap: () {
                              _makePhoneCall(phone);
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildContactButton(
                            icon: Iconsax.user,
                            label: l10n.profile,
                            color: Colors.grey.shade100,
                            iconColor: Colors.grey.shade700,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AgentDetailsPage(
                                    agentId: agent['id'] as String,
                                    agentData: agent,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAvatarFallback(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'A',
        style: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final l10n = AppLocalizations.of(context)!;
    // Format phone number if needed
    final phoneNumber = phone.replaceAll(RegExp(r'\s+'), '');
    
    // Check if the phone number is not empty
    if (phoneNumber.isEmpty || phoneNumber == l10n.noPhone) {
      _showErrorSnackBar(l10n.phoneNumberNotAvailable);
      return;
    }
    
    // Create the tel: URI
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    
    try {
      // Try to launch the phone app
      HapticFeedback.lightImpact();
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // If launching failed, show error
        if (mounted) {
          _showErrorSnackBar(l10n.couldNotInitiateCall);
        }
      }
    } catch (e) {
      _logger.severe('Error making phone call: $e');
      if (mounted) {
        _showErrorSnackBar(l10n.errorInitiatingCall);
      }
    }
  }
}

// Add this comment to indicate where a new function would be placed (near other functions in the class)
// Future<void> _uploadAgentProfileImage(String agentId, File imageFile) async {
//   try {
//     final imageUrl = await CloudinaryService.uploadImage(imageFile);
//     if (imageUrl != null) {
//       await FirebaseFirestore.instance
//           .collection('agents')
//           .doc(agentId)
//           .update({'imageUrl': imageUrl});
//       
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Profile image updated successfully',
//               style: GoogleFonts.poppins(color: Colors.white)),
//           backgroundColor: Colors.black,
//         ),
//       );
//     }
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Failed to update profile image: $e',
//             style: GoogleFonts.poppins(color: Colors.white)),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }
// }