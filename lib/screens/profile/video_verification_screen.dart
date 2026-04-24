import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/verification_service.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';

class VideoVerificationScreen extends StatefulWidget {
  const VideoVerificationScreen({super.key});

  @override
  State<VideoVerificationScreen> createState() => _VideoVerificationScreenState();
}

class _VideoVerificationScreenState extends State<VideoVerificationScreen>
    with TickerProviderStateMixin {
  final VerificationService _verificationService = VerificationService();
  final DatabaseService _databaseService = DatabaseService();
  final ImagePicker _imagePicker = ImagePicker();

  // User data
  String? _currentUserId;
  UserModel? _currentUser;

  // Verification state
  String _verificationStatus = 'not_started'; 
  Map<String, dynamic>? _existingVerification;

  // Current step
  int _currentStep = 0; // 0: intro, 1: video, 2: selfie, 3: id_document, 4: review, 5: submitted

  // Captured files
  String? _videoPath;
  String? _selfiePath;
  String? _idDocumentPath;
  Uint8List? _videoBytes;
  Uint8List? _selfieBytes;
  Uint8List? _idDocumentBytes;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Loading
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadUserAndStatus();
  }

  Future<void> _loadUserAndStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _currentUserId = user.uid;

    // Load user data
    _databaseService.getUserStream(_currentUserId!).listen((userModel) {
      if (mounted && userModel != null) {
        setState(() {
          _currentUser = userModel;
        });
      }
    });

    // Load verification status
    _verificationService.streamVerificationStatus(_currentUserId!).listen((status) {
      if (mounted) {
        setState(() {
          _existingVerification = status;
          if (status != null) {
            _verificationStatus = status['status'] as String? ?? 'not_started';
            if (_verificationStatus == 'pending') {
              _currentStep = 5; 
            }
          }
        });
      }
    });
  }

  Future<void> _recordVideo() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (!cameraStatus.isGranted || !micStatus.isGranted) {
      _showPermissionDeniedDialog();
      return;
    }

    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 15),
        preferredCameraDevice: CameraDevice.front,
      );

      if (video != null) {
        if (kIsWeb) {
          final bytes = await video.readAsBytes();
          setState(() {
            _videoPath = video.path;
            _videoBytes = bytes;
            _currentStep = 2;
          });
        } else {
          setState(() {
            _videoPath = video.path;
            _currentStep = 2;
          });
        }
      }
    } catch (e) {
      _showErrorSnackbar('Failed to record video. Please try again.');
    }
  }

  Future<void> _captureSelfie() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      _showPermissionDeniedDialog();
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selfiePath = image.path;
            _selfieBytes = bytes;
            _currentStep = 3;
          });
        } else {
          setState(() {
            _selfiePath = image.path;
            _currentStep = 3;
          });
        }
      }
    } catch (e) {
      _showErrorSnackbar('Failed to capture selfie. Please try again.');
    }
  }

  Future<void> _takeIdPhoto() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      _showPermissionDeniedDialog();
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _idDocumentPath = image.path;
            _idDocumentBytes = bytes;
            _currentStep = 4;
          });
        } else {
          setState(() {
            _idDocumentPath = image.path;
            _currentStep = 4;
          });
        }
      }
    } catch (e) {
      _showErrorSnackbar('Failed to capture photo. Please try again.');
    }
  }

  Future<void> _uploadIdDocument() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _idDocumentPath = image.path;
            _idDocumentBytes = bytes;
            _currentStep = 4;
          });
        } else {
          setState(() {
            _idDocumentPath = image.path;
            _currentStep = 4;
          });
        }
      }
    } catch (e) {
      _showErrorSnackbar('Failed to upload document. Please try again.');
    }
  }

  Future<void> _submitVerification() async {
    if (_videoPath == null) {
      _showErrorSnackbar('Please record a verification video');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final verificationId = await _verificationService.submitVerificationRequest(
        userId: _currentUserId!,
        userName: _currentUser?.name ?? 'User',
        videoPath: _videoPath!,
        selfieImagePath: _selfiePath,
        idDocumentPath: _idDocumentPath,
        videoBytes: _videoBytes,
        selfieBytes: _selfieBytes,
        idDocumentBytes: _idDocumentBytes,
      );

      if (verificationId != null) {
        setState(() {
          _currentStep = 5;
          _verificationStatus = 'pending';
        });
      } else {
        _showErrorSnackbar('Failed to submit verification. Please try again.');
      }
    } catch (e) {
      _showErrorSnackbar('An error occurred. Please try again.');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _resetVerification() {
    setState(() {
      _currentStep = 0;
      _videoPath = null;
      _selfiePath = null;
      _idDocumentPath = null;
      _verificationStatus = 'not_started';
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Verification Center',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.7, -0.6),
                radius: 1.5,
                colors: [Color(0xFF1F1235), Colors.black],
              ),
            ),
          ),
          SafeArea(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_verificationStatus == 'approved') return _buildApprovedState();
    if (_verificationStatus == 'pending' || _currentStep == 5) return _buildPendingState();
    if (_verificationStatus == 'rejected') return _buildRejectedState();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _getCurrentStepWidget(),
    );
  }

  Widget _getCurrentStepWidget() {
    switch (_currentStep) {
      case 0: return _buildIntroStep();
      case 1: return _buildVideoStep();
      case 2: return _buildSelfieStep();
      case 3: return _buildIdDocumentStep();
      case 4: return _buildReviewStep();
      default: return _buildIntroStep();
    }
  }

  Widget _buildIntroStep() {
    final guidelines = _verificationService.getVerificationGuidelines();
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.1),
                    boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 30, spreadRadius: 10)],
                  ),
                ),
                Container(
                  width: 100, height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF00B4DB), Color(0xFF0083B0)]),
                  ),
                  child: const Icon(Icons.verified_rounded, color: Colors.white, size: 52),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text('Verified Account', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Complete these steps to earn your blue badge and unlock exclusive features.', 
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.w500), 
              textAlign: TextAlign.center),
          ),
          const SizedBox(height: 48),
          _buildEliteInfoCard(icon: Icons.auto_awesome_rounded, title: 'Increased Account Authority', subtitle: 'Verified accounts appear first in search results.', color: Colors.amber),
          const SizedBox(height: 12),
          _buildEliteInfoCard(icon: Icons.shield_rounded, title: 'Identity Protection', subtitle: 'Prevents others from impersonating you.', color: Colors.blueAccent),
          const SizedBox(height: 12),
          _buildEliteInfoCard(icon: Icons.videocam_rounded, title: 'Broadcaster Access', subtitle: 'Required for high-level streaming rooms.', color: const Color(0xFFFF1493)),
          const SizedBox(height: 40),
          Container(
            width: double.infinity, height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [Color(0xFF00B4DB), Color(0xFF0083B0)]),
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: ElevatedButton(
              onPressed: () => setState(() => _currentStep = 1),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: const Text('Verify Now', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Text('Usually approved within ${guidelines['processingTime']}', style: const TextStyle(color: Colors.white30, fontSize: 13, fontWeight: FontWeight.w500))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVideoStep() {
    final prompts = _verificationService.getVerificationPrompts();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildStepHeader(1, 4, 'Identity Check', 'Record a 5-15 second video selfie to confirm your identity.'),
          const Spacer(),
          if (_videoPath != null) _buildVideoPreview() else _buildRecordButton(),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.03))),
            child: Column(
              children: [
                const Text('DURING RECORDING:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
                const SizedBox(height: 16),
                ...prompts.take(3).map((prompt) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [const Icon(Icons.star_rounded, color: Colors.blueAccent, size: 14), const SizedBox(width: 12), Expanded(child: Text(prompt, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500)))]),
                )),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildStepNavigation(_videoPath != null, () => setState(() => _currentStep = 0), () => setState(() => _currentStep = 2)),
        ],
      ),
    );
  }

  Widget _buildSelfieStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildStepHeader(2, 4, 'Face Audit', 'Please take a clear front-facing selfie photo.'),
          const Spacer(),
          if (_selfiePath != null) _buildImagePreview(_selfiePath!, () => setState(() => _selfiePath = null)) else _buildCaptureButton(Icons.face_retouching_natural_rounded, 'Open Camera', _captureSelfie),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
            child: const Column(
              children: [
                _TipItem(icon: Icons.light_mode_rounded, text: 'Ensure lighting is bright & even'),
                SizedBox(height: 12),
                _TipItem(icon: Icons.face_rounded, text: 'Remove hats or sunglasses'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildStepNavigation(_selfiePath != null, () => setState(() => _currentStep = 1), () => setState(() => _currentStep = 3)),
        ],
      ),
    );
  }

  Widget _buildIdDocumentStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildStepHeader(3, 4, 'ID Document', 'Upload a photo of your ID (Optional but recommended).'),
          const Spacer(),
          if (_idDocumentPath != null) _buildImagePreview(_idDocumentPath!, () => setState(() => _idDocumentPath = null)) 
          else Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildModernIconAction(Icons.camera_alt_rounded, 'Take Photo', _takeIdPhoto),
              _buildModernIconAction(Icons.photo_library_rounded, 'Gallery', _uploadIdDocument),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
            child: const Column(
              children: [
                _TipItem(icon: Icons.badge_rounded, text: 'National ID, Passport or License'),
                SizedBox(height: 12),
                _TipItem(icon: Icons.check_circle_outline, text: 'Text must be clearly readable'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildStepNavigation(true, () => setState(() => _currentStep = 2), () => setState(() => _currentStep = 4)),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildStepHeader(4, 4, 'Final Review', 'Almost there! Review your materials before submitting.'),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              children: [
                _buildReviewTile('Video Selfie', _videoPath != null, Icons.videocam_rounded, true),
                _buildReviewTile('Selfie Photo', _selfiePath != null, Icons.face_rounded, true),
                _buildReviewTile('ID Document', _idDocumentPath != null, Icons.badge_rounded, false),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity, height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [Color(0xFF00F260), Color(0xFF0575E6)]),
            ),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitVerification,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: _isSubmitting 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text('Submit Verification', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: () => setState(() => _currentStep = 0), child: const Text('Start Over', style: TextStyle(color: Colors.white30))),
        ],
      ),
    );
  }

  Widget _buildReviewTile(String title, bool isProvided, IconData icon, bool isRequired) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isProvided ? Colors.green.withOpacity(0.3) : Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: isProvided ? Colors.green : Colors.white24),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          if (isProvided) const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)
          else Text(isRequired ? 'REQUIRED' : 'OPTIONAL', style: TextStyle(color: isRequired ? Colors.redAccent : Colors.white24, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildStepHeader(int step, int total, String title, String subtitle) {
    return Column(
      children: [
        _buildProgressIndicator(step, total),
        const SizedBox(height: 24),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildStepNavigation(bool canContinue, VoidCallback onBack, VoidCallback onNext) {
    return Row(
      children: [
        Expanded(child: OutlinedButton(onPressed: onBack, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: const Text('Back', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)))),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: canContinue ? const LinearGradient(colors: [Color(0xFF00B4DB), Color(0xFF0083B0)]) : null, color: canContinue ? null : Colors.white10), child: ElevatedButton(onPressed: canContinue ? onNext : null, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))))),
      ],
    );
  }

  Widget _buildProgressIndicator(int current, int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isActive = index < current;
        final isLast = index == total - 1;
        return Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? Colors.blue : Colors.white10, border: Border.all(color: isActive ? Colors.blueAccent : Colors.white24)),
              child: Center(child: Text('${index + 1}', style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))),
            ),
            if (!isLast) Container(width: 20, height: 2, color: isActive ? Colors.blue : Colors.white10),
          ],
        );
      }),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _recordVideo,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            width: 140, height: 140,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withOpacity(0.1), border: Border.all(color: Colors.red.withOpacity(0.2), width: 1)),
            child: Center(
              child: Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Colors.red, Color(0xFF8B0000)]), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)]),
                  child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 40),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Column(
      children: [
        Container(
          width: 140, height: 140,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.green.withOpacity(0.1), border: Border.all(color: Colors.green.withOpacity(0.3), width: 4)),
          child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 70),
        ),
        const SizedBox(height: 24),
        TextButton.icon(onPressed: () => setState(() => _videoPath = null), icon: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 18), label: const Text('Retake Video', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildCaptureButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140, height: 140,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.blueAccent, size: 40), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  Widget _buildModernIconAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
        child: Column(children: [Icon(icon, color: Colors.blueAccent, size: 30), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  Widget _buildImagePreview(String path, VoidCallback onClear) {
    return Column(
      children: [
        Container(
          width: 180, height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.blue.withOpacity(0.3), width: 4),
            image: DecorationImage(
              image: kIsWeb 
                ? (_currentStep == 2 ? MemoryImage(_selfieBytes!) : MemoryImage(_idDocumentBytes!))
                : FileImage(File(path)) as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(onPressed: onClear, icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18), label: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildApprovedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.green.withOpacity(0.2)), child: const Icon(Icons.verified, color: Colors.green, size: 60)),
            const SizedBox(height: 24),
            const Text('You\'re Verified!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Congratulations! Your profile has been verified.\nYou now have a verified badge.', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Done', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.withOpacity(0.2)), child: const Icon(Icons.hourglass_empty, color: Colors.orange, size: 60)),
            const SizedBox(height: 24),
            const Text('Verification Pending', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Your verification is being reviewed.\nThis usually takes 24-48 hours.', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), side: const BorderSide(color: Colors.white54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Go Back', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedState() {
    final reason = _existingVerification?['rejectionReason'] as String? ?? 'Incomplete or unclear documentation.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withOpacity(0.2)), child: const Icon(Icons.error_outline, color: Colors.red, size: 60)),
            const SizedBox(height: 24),
            const Text('Verification Rejected', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(reason, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _resetVerification, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Try Again', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _buildEliteInfoCard({required IconData icon, required String title, required String subtitle, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.03))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12))])),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showPermissionDeniedDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1A1A2E), title: const Text('Permission Required', style: TextStyle(color: Colors.white)), content: const Text('Camera and microphone permissions are required for verification. Please enable them in settings.', style: TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () {Navigator.pop(context); openAppSettings();}, child: const Text('Open Settings'))]));
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 16),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13))),
      ],
    );
  }
}
