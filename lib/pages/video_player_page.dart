// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../models/property.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({required this.videoUrl, required this.property, super.key});

  final String videoUrl;
  final Property property;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isControlsVisible = true;
  bool _isFullScreen = false;
  Timer? _controlsTimer;
  double _playbackSpeed = 1.0;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _initializeVideoPlayer() async {
    _controller = VideoPlayerController.network(widget.videoUrl);
    
    // Listen for buffering status
    _controller.addListener(() {
      final newBuffering = _controller.value.isBuffering;
      if (_isBuffering != newBuffering) {
        setState(() {
          _isBuffering = newBuffering;
        });
      }
    });
    
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
        _startControlsTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (_isControlsVisible && _controller.value.isPlaying) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() {
            _isControlsVisible = false;
          });
        }
      });
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
        _startControlsTimer();
      }
    });
  }

  void _setPlaybackSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
      _controller.setPlaybackSpeed(speed);
    });
    _startControlsTimer();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    return duration.inHours > 0 
        ? '$hours:$minutes:$seconds' 
        : '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _isFullScreen 
          ? null 
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                widget.property.title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      body: GestureDetector(
        onTap: () {
          setState(() {
            _isControlsVisible = !_isControlsVisible;
            if (_isControlsVisible) {
              _startControlsTimer();
            }
          });
        },
        child: Stack(
          children: [
            // Main Video
            Center(
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
            ),
            
            // Buffering Indicator
            if (_isBuffering && _isInitialized)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              ),
            
            // Controls Overlay
            if (_isControlsVisible && _isInitialized)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.2, 0.8, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Controls (Header Info)
                    _isFullScreen
                        ? SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                                    onPressed: () {
                                      if (_isFullScreen) {
                                        _toggleFullScreen();
                                      } else {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      widget.property.title,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox(height: 50),
                    
                    // Center Play Button
                    IconButton(
                      icon: Icon(
                        _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        color: Colors.white,
                        size: 68,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                    
                    // Bottom Controls (Progress Bar, Play/Pause, etc)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Progress Bar
                          ValueListenableBuilder(
                            valueListenable: _controller,
                            builder: (context, VideoPlayerValue value, child) {
                              return Column(
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: const Color(0xFF00E5FF),
                                      inactiveTrackColor: Colors.grey[600],
                                      thumbColor: Colors.white,
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                    ),
                                    child: Slider(
                                      value: value.position.inMilliseconds.toDouble(),
                                      min: 0,
                                      max: value.duration.inMilliseconds.toDouble(),
                                      onChanged: (newPosition) {
                                        _controller.seekTo(Duration(milliseconds: newPosition.round()));
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(value.position),
                                          style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(value.duration),
                                          style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Control Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Rewind 10 seconds
                              IconButton(
                                icon: const Icon(Iconsax.backward, color: Colors.white),
                                onPressed: () {
                                  final newPosition = _controller.value.position - const Duration(seconds: 10);
                                  _controller.seekTo(newPosition);
                                  _startControlsTimer();
                                },
                              ),
                              
                              // Play/Pause
                              IconButton(
                                icon: Icon(
                                  _controller.value.isPlaying ? Iconsax.pause : Iconsax.play,
                                  color: Colors.white,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                              
                              // Forward 10 seconds
                              IconButton(
                                icon: const Icon(Iconsax.forward, color: Colors.white),
                                onPressed: () {
                                  final newPosition = _controller.value.position + const Duration(seconds: 10);
                                  _controller.seekTo(newPosition);
                                  _startControlsTimer();
                                },
                              ),
                              
                              // Playback Speed
                              PopupMenuButton<double>(
                                color: Colors.grey[900],
                                icon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${_playbackSpeed}x',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: Colors.white),
                                  ],
                                ),
                                onSelected: _setPlaybackSpeed,
                                itemBuilder: (context) => [
                                  _buildSpeedMenuItem(0.5),
                                  _buildSpeedMenuItem(0.75),
                                  _buildSpeedMenuItem(1.0),
                                  _buildSpeedMenuItem(1.25),
                                  _buildSpeedMenuItem(1.5),
                                  _buildSpeedMenuItem(2.0),
                                ],
                              ),
                              
                              // Full Screen Toggle
                              IconButton(
                                icon: Icon(
                                  _isFullScreen ? Iconsax.screenmirroring : Iconsax.maximize,
                                  color: Colors.white,
                                ),
                                onPressed: _toggleFullScreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  PopupMenuItem<double> _buildSpeedMenuItem(double speed) {
    return PopupMenuItem<double>(
      value: speed,
      child: Row(
        children: [
          if (_playbackSpeed == speed)
            const Icon(Icons.check, color: Color(0xFF00E5FF), size: 16),
          if (_playbackSpeed == speed)
            const SizedBox(width: 8),
          Text(
            '${speed}x',
            style: GoogleFonts.poppins(
              color: _playbackSpeed == speed ? const Color(0xFF00E5FF) : Colors.white,
              fontWeight: _playbackSpeed == speed ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}