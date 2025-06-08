import 'package:flutter/material.dart';
import 'package:homi/models/property.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';

class PropertyPhotosPage extends StatefulWidget {
  final Property property;

  const PropertyPhotosPage({
    Key? key,
    required this.property,
  }) : super(key: key);

  @override
  State<PropertyPhotosPage> createState() => _PropertyPhotosPageState();
}

class _PropertyPhotosPageState extends State<PropertyPhotosPage> with SingleTickerProviderStateMixin {
  List<Map<String, String>> _labeledPhotos = [];
  int _currentIndex = 0;
  PageController? _pageController;
  bool _isInfoVisible = true;
  bool _isGridView = false;
  bool _isPageViewReady = false;
  late AnimationController _animationController;
  late Animation<double> _infoAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _infoAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _pageController = PageController(initialPage: _currentIndex);
    _loadPhotos();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _labeledPhotos = widget.property.labeledPhotos
          .map((photo) => {
                'url': photo['url'] ?? '',
                'label': photo['label'] ?? '',
              })
          .toList();
      _isPageViewReady = true;
    });
  }

  void _toggleInfoVisibility() {
    setState(() {
      _isInfoVisible = !_isInfoVisible;
    });
  }

  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
      
      // When returning to page view, ensure current index is maintained
      if (!_isGridView && _pageController != null && _pageController!.hasClients) {
        _pageController!.jumpToPage(_currentIndex);
      }
    });
  }

  void _handleGridItemTap(int index) {
    setState(() {
      _currentIndex = index;
      _isGridView = false;
      
      // Ensure PageView shows the selected image
      if (_pageController != null && _pageController!.hasClients) {
        _pageController!.jumpToPage(index);
      }
    });
  }

  String _processImageUrl(String url) {
    if (url.isEmpty) return '';
    
    // Handle Cloudinary URLs to ensure best quality
    if (url.contains('cloudinary.com')) {
      // Remove any existing transformations and add high quality parameters
      final regex = RegExp(r'\/upload\/(?:v\d+\/)?(.+)');
      final match = regex.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        final path = match.group(1);
        return url.replaceAll(regex, '/upload/q_auto,f_auto/$path');
      }
    }
    
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _labeledPhotos.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : _isGridView
              ? _buildGridView()
              : _buildFullScreenGallery(),
    );
  }

  Widget _buildGridView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemCount: _labeledPhotos.length,
          itemBuilder: (context, index) {
            final photo = _labeledPhotos[index];
            final imageUrl = _processImageUrl(photo['url'] ?? '');
            
            return FadeIn(
              delay: Duration(milliseconds: 50 * index),
              duration: const Duration(milliseconds: 300),
              child: GestureDetector(
                onTap: () => _handleGridItemTap(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.error, color: Colors.white),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            photo['label'] ?? 'Unlabeled',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFullScreenGallery() {
    // If no page controller or no photos, show error
    if (_pageController == null || _labeledPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.gallery_slash, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No photos available to display',
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Go Back',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Stack(
      children: [
        // Main gallery
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
              _isPageViewReady = true;
            });
          },
          itemCount: _labeledPhotos.length,
          itemBuilder: (context, index) {
            final photo = _labeledPhotos[index];
            final imageUrl = _processImageUrl(photo['url'] ?? '');
            
            return GestureDetector(
              onTap: _toggleInfoVisibility,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    print('Error loading image: $error for URL: $url');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.image, size: 64, color: Colors.grey.shade600),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          if (url.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'URL: $url',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        
        // Top controls
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {}, // Prevent tap from being passed to PageView
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Iconsax.arrow_left_2, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _toggleViewMode,
                          icon: Icon(
                            _isGridView ? Iconsax.gallery : Iconsax.grid_1,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Bottom photo indicator and label - only show when info visible and not in grid view
        if (!_isGridView)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _isInfoVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: GestureDetector(
                onTap: () {}, // Prevent tap from being passed to PageView
                child: Container(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 32,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Photo label if available
                        if (_labeledPhotos.isNotEmpty &&
                            _currentIndex < _labeledPhotos.length &&
                            _labeledPhotos[_currentIndex]['label'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _labeledPhotos[_currentIndex]['label'] ?? '',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          
                        // Photo indicators
                        if (_labeledPhotos.length > 1)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _labeledPhotos.length,
                              (i) => GestureDetector(
                                onTap: () {
                                  if (_pageController != null && _pageController!.hasClients) {
                                    _pageController!.animateToPage(
                                      i,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                },
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentIndex == i
                                        ? const Color(0xFF00E5FF)
                                        : Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
        // Grid view if enabled
        if (_isGridView)
          Container(
            color: Colors.black,
            child: SafeArea(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _labeledPhotos.length,
                itemBuilder: (context, index) {
                  final photo = _labeledPhotos[index];
                  final imageUrl = _processImageUrl(photo['url'] ?? '');
                  
                  return GestureDetector(
                    onTap: () => _handleGridItemTap(index),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[900],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[900],
                              child: const Icon(Iconsax.image, color: Colors.grey),
                            ),
                          ),
                        ),
                        
                        // Selected indicator
                        if (_currentIndex == index)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF00E5FF),
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _FullScreenPhoto extends StatelessWidget {
  final String photoUrl;
  final String photoLabel;
  final int index;
  final int totalPhotos;

  const _FullScreenPhoto({
    required this.photoUrl,
    required this.photoLabel,
    required this.index,
    required this.totalPhotos,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              photoLabel,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${index + 1} of $totalPhotos)',
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Hero(
          tag: 'photo_$index',
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              photoUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    color: Colors.white,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}