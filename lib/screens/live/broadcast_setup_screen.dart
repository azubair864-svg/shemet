import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:ui' as android;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../services/agora_service.dart';

class BroadcastSetupScreen extends StatefulWidget {
  const BroadcastSetupScreen({super.key});

  @override
  State<BroadcastSetupScreen> createState() => _BroadcastSetupScreenState();
}

class _BroadcastSetupScreenState extends State<BroadcastSetupScreen> {
  final TextEditingController _titleController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  final AgoraService _agoraService = AgoraService();
  final ImagePicker _picker = ImagePicker();

  String _selectedTag = 'Chat';
  bool _isCreating = false;
  File? _coverImageFile; // Local file for preview
  Uint8List? _webCoverImageBytes; // For web compatibility
  bool _isCameraInitialized = false;

  // Beauty Settings
  bool _beautyEnabled = false;
  double _smoothness = 0.5;
  double _lightening = 0.5;
  double _redness = 0.1;

  bool _isCameraOn = true; // Default to camera on
  final List<String> _tags = ['Chat', 'Chill', 'Music', 'Dance', 'Dating', 'Game'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserProvider>().currentUser;
      if (user?.gender == 'Male') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broadcasting is currently restricted for male accounts.')),
        );
        Navigator.pop(context);
        return;
      }
      _initializeCamera();
    });
  }
  
  Future<void> _initializeCamera() async {
    // Check if permissions are already granted
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;

    if (!cameraStatus.isGranted || !micStatus.isGranted) {
      // Show Prominent Disclosure Dialog for Play Store Compliance
      if (mounted) {
        final bool? shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Camera & Microphone Access', style: TextStyle(color: Colors.white)),
            content: const Text(
              'To broadcast live video and interact with your audience, Shemet needs access to your camera and microphone. This allows others to see and hear you during the live stream.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue', style: TextStyle(color: Color(0xFFFF1493), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (shouldRequest != true) {
          // User declined
          if (mounted) Navigator.pop(context); // Close broadcast screen
          return;
        }
      }
    }

    await [Permission.camera, Permission.microphone].request();
    await _agoraService.initialize();
    await _agoraService.requestCameraControl(CameraOwner.agora);
    
    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    // Do NOT dispose AgoraService here when navigating to Live Room
    super.dispose();
  }



  Future<void> _pickCoverImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _webCoverImageBytes = bytes;
          _coverImageFile = File('web');
        });
      } else {
        setState(() {
          _coverImageFile = File(image.path);
        });
      }
    }
  }

  Future<void> _startLive() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room title')),
      );
      return;
    }

    int entryFee = 0;

    setState(() => _isCreating = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;

    if (user != null) {
      String coverImageUrl = user.photos.isNotEmpty ? user.photos[0] : '';
      
      if (_coverImageFile != null) {
        final url = await _databaseService.uploadChatImage(
          'covers/${user.uid}', 
          _coverImageFile!.path,
          webBytes: _webCoverImageBytes,
        );
        if (url != null) coverImageUrl = url;
      }

      final streamId = await _databaseService.createLiveStream(
        hostId: user.uid,
        hostName: user.name,
        hostPhoto: user.photos.isNotEmpty ? user.photos[0] : '',
        title: title,
        coverImage: coverImageUrl,
        tags: [_selectedTag],
        isPremium: false,
        entryFee: 0,
        premiumMode: 'none',
      );

      if (mounted) {
        setState(() => _isCreating = false);
        if (streamId != null) {
           Navigator.pushReplacementNamed(
            context, 
            '/live_room_view_v2',
            arguments: {
              'streamId': streamId,
              'isBroadcaster': true,
            }
          );
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create room')),
          );
        }
      }
    }
  }
  
  void _toggleCamera() {
    _agoraService.switchCamera();
  }

  void _showBeautySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Beauty Studio', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Switch(
                      value: _beautyEnabled,
                      activeThumbColor: const Color(0xFFFF1493),
                      onChanged: (val) {
                        setSheetState(() => _beautyEnabled = val);
                        setState(() => _beautyEnabled = val);
                        _updateBeautyEffect();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSlider('Smoothness', _smoothness, (val) {
                   setSheetState(() => _smoothness = val);
                   setState(() => _smoothness = val);
                   _updateBeautyEffect();
                }),
                _buildSlider('Whitening', _lightening, (val) {
                   setSheetState(() => _lightening = val);
                   setState(() => _lightening = val);
                   _updateBeautyEffect();
                }),
                _buildSlider('Redness', _redness, (val) {
                   setSheetState(() => _redness = val);
                   setState(() => _redness = val);
                   _updateBeautyEffect();
                }),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }

  void _updateBeautyEffect() {
    _agoraService.setBeautyEffectOptions(
      enabled: _beautyEnabled,
      options: BeautyOptions(
        lighteningLevel: _lightening,
        smoothnessLevel: _smoothness,
        rednessLevel: _redness,
        sharpnessLevel: 0.5,
      ),
    );
  }
  
  Widget _buildSlider(String label, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Slider(
          value: value,
          min: 0.0,
          max: 1.0,
          activeColor: const Color(0xFFFF1493),
          inactiveColor: Colors.grey.shade800,
          onChanged: _beautyEnabled ? onChanged : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get user photo for fallback
    final user = context.watch<UserProvider>().currentUser;
    final photoUrl = user?.photos.isNotEmpty == true ? user!.photos[0] : null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isCameraInitialized && _agoraService.engine != null && _isCameraOn)
            AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _agoraService.engine!,
                canvas: const VideoCanvas(
                  uid: 0,
                  renderMode: RenderModeType.renderModeHidden,
                ), // Local user
              ),
            )
          else if (photoUrl != null)
            Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
                ),
                Container(
                  color: Colors.black.withOpacity(0.6),
                ),
                BackdropFilter(
                  filter: android.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.transparent),
                ),
              ],
            )
          else
            Container(color: Colors.black),
            
          // 2. Gradient Overlay for Text Readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // 3. UI Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Bar: Close, Camera Toggle, Flip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isCameraOn ? Icons.videocam : Icons.videocam_off, 
                              color: Colors.white, 
                              size: 28
                            ),
                            onPressed: () {
                              setState(() => _isCameraOn = !_isCameraOn);
                            },
                          ),
                          const SizedBox(width: 8),
                          if (_isCameraOn)
                            IconButton(
                              icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                              onPressed: _toggleCamera,
                            ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Cover Image & Title Input with Glassmorphism
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: android.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: _pickCoverImage,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade800,
                                      borderRadius: BorderRadius.circular(18),
                                      image: _coverImageFile != null
                                          ? DecorationImage(
                                              image: kIsWeb
                                                  ? MemoryImage(_webCoverImageBytes!)
                                                  : FileImage(_coverImageFile!) as ImageProvider,
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    child: _coverImageFile == null 
                                        ? (photoUrl != null 
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(18),
                                                child: Image.network(
                                                  photoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white70, size: 28),
                                                ),
                                              )
                                            : const Icon(Icons.add_a_photo_outlined, color: Colors.white70, size: 28))
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF1493),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.edit, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Room Title',
                                    style: TextStyle(
                                      color: Colors.white70, 
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Theme(
                                    data: ThemeData.dark(), // 🛠️ Fix: Forces white composing text/cursor
                                    child: TextField(
                                      controller: _titleController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                      cursorColor: const Color(0xFFFF1493),
                                      decoration: InputDecoration(
                                        hintText: 'What are you doing today?',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 16,
                                          fontWeight: FontWeight.normal,
                                        ),
                                        border: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        filled: false, // Ensure transparent bg
                                      ),
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),
                  
                  // Tags Selection
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 4.0),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         const Text('Select Mode', style: TextStyle(
                           color: Colors.white, 
                           fontSize: 16, 
                           fontWeight: FontWeight.bold,
                           letterSpacing: 0.5,
                         )),
                         Text('See All >', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                       ],
                     ),
                   ),
                   const SizedBox(height: 16),
                    SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                     child: Row(
                      children: _tags.map((tag) {
                        final isSelected = _selectedTag == tag;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTag = tag),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isSelected 
                                ? const LinearGradient(colors: [Color(0xFFFF1493), Color(0xFFFF69B4)])
                                : LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.15),
                                width: 1,
                              ),
                              boxShadow: isSelected 
                                ? [BoxShadow(color: const Color(0xFFFF1493).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                                : null,
                            ),
                            child: Text(
                              tag, 
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 13,
                              )
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                   ),

                  const SizedBox(height: 40),

                  const SizedBox(height: 30),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(Icons.face_retouching_natural_rounded, 'Beauty', _showBeautySheet),
                      _buildActionButton(Icons.share_rounded, 'Share', () {
                         Share.share('Check out my live stream on Shemet!');
                      }),
                      _buildActionButton(Icons.settings_rounded, 'Settings', () {}),
                    ],
                  ),
                  
                  const SizedBox(height: 30),

                  // Go Live Button
                  Center(
                    child: GestureDetector(
                      onTap: _isCreating ? null : _startLive,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF1493), Color(0xFFFE2C55)], // Stronger Tik-Tok like gradient
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF1493).withOpacity(0.6),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _isCreating 
                          ? const SizedBox(
                              height: 24, 
                              width: 24, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            )
                          : const Text(
                              'GO LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
