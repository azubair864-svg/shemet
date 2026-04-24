import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AutoVerificationScreen extends StatefulWidget {
  const AutoVerificationScreen({super.key});

  @override
  State<AutoVerificationScreen> createState() => _AutoVerificationScreenState();
}

class _AutoVerificationScreenState extends State<AutoVerificationScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isInitializing = true;
  bool _isProcessing = false;
  String _statusMessage = 'Place your face in the oval';
  
  bool _faceDetected = false;
  bool _blinkDetected = false;
  double _verificationProgress = 0.0;
  
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    debugPrint('[FACE_VERIFY] 🚀 initState: Starting Face Verification Flow');
    _initializeCamera();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      debugPrint('[FACE_VERIFY] 📷 Searching for cameras...');
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      debugPrint('[FACE_VERIFY] 📷 Initializing camera: ${frontCamera.name}');
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        debugPrint('[FACE_VERIFY] ✅ Camera initialized successfully.');
        setState(() => _isInitializing = false);
        _startFaceDetection();
      }
    } catch (e) {
      debugPrint('[FACE_VERIFY] ❌ Camera Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  void _startFaceDetection() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      debugPrint('[FACE_VERIFY] ⚠️ Cannot start detection: Controller not ready.');
      return;
    }

    debugPrint('[FACE_VERIFY] 🎞️ Starting Image Stream for Face Detection.');
    _cameraController!.startImageStream((CameraImage image) {
      if (_isProcessing) return;
      _processImage(image);
    });
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isProcessing || _cameraController == null) return;
    _isProcessing = true;
    
    try {
      final width = image.width;
      final height = image.height;
      
      // Robust NV21 Construction (Grayscale Y + Neutral UV)
      // This is the most stable way for Android 14
      final yPlane = image.planes[0];
      final yBuffer = yPlane.bytes;
      final yBytesPerRow = yPlane.bytesPerRow;
      
      final Uint8List nv21Bytes = Uint8List(width * height * 3 ~/ 2);
      
      // 1. Copy Y Plane row by row (removing padding)
      for (int row = 0; row < height; row++) {
        final int srcStart = row * yBytesPerRow;
        final int destStart = row * width;
        final int copyLength = math.min(width, yBuffer.length - srcStart);
        if (copyLength > 0) {
          nv21Bytes.setRange(destStart, destStart + copyLength, yBuffer.getRange(srcStart, srcStart + copyLength));
        }
      }
      
      // 2. Fill UV Plane with neutral gray (128)
      // Face detection works perfectly on grayscale
      nv21Bytes.fillRange(width * height, nv21Bytes.length, 128);

      final InputImageRotation rotation = InputImageRotationValue.fromRawValue(
        _cameraController!.description.sensorOrientation
      ) ?? InputImageRotation.rotation0deg;

      final InputImage inputImage = InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21, // Always NV21 now
          bytesPerRow: width,
        ),
      );

      final faces = await _faceDetector!.processImage(inputImage);
      
      if (mounted) {
        _handleDetectedFaces(faces);
      }
    } catch (e) {
      debugPrint('[FACE_VERIFY] ⚠️ Processing Critical Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _handleDetectedFaces(List<Face> faces) {
    if (faces.isEmpty) {
      if (_faceDetected) {
        debugPrint('[FACE_VERIFY] 🔍 Status: No faces found (Lost tracking).');
      }
      setState(() {
        _faceDetected = false;
        _statusMessage = 'Place your face in the oval';
        _verificationProgress = 0.0;
      });
      return;
    }

    final face = faces.first;
    
    if (!_faceDetected) {
      debugPrint('[FACE_VERIFY] 👤 Face Detected! Starting liveness check.');
    }

    setState(() {
      _faceDetected = true;
      if (!_blinkDetected) {
        _statusMessage = 'Now, blink your eyes twice';
        _verificationProgress = 0.4;
      }
    });

    if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
      // debugPrint('[FACE_VERIFY] 👀 Eyes: L=${face.leftEyeOpenProbability!.toStringAsFixed(2)}, R=${face.rightEyeOpenProbability!.toStringAsFixed(2)}');
      if (face.leftEyeOpenProbability! < 0.25 && face.rightEyeOpenProbability! < 0.25) {
        if (!_blinkDetected) {
          debugPrint('[FACE_VERIFY] ✨ Blink Detected! Verification threshold reached.');
          setState(() {
            _blinkDetected = true;
            _verificationProgress = 1.0;
            _statusMessage = 'Verified!';
          });
          _completeVerification();
        }
      }
    }
  }

  Future<void> _completeVerification() async {
    debugPrint('[FACE_VERIFY] 🏁 Finishing verification process...');
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (currentUser == null) {
      debugPrint('[FACE_VERIFY] ❌ Error: Current user is null in Provider.');
      return;
    }

    debugPrint('[FACE_VERIFY] 🛰️ Updating Firestore for user: ${currentUser.uid}');
    final success = await _databaseService.updateUser(currentUser.uid, {
      'isVerified': true,
      'verifiedAt': FieldValue.serverTimestamp(),
      'verificationStatus': 'verified',
    });

    if (success && mounted) {
      debugPrint('[FACE_VERIFY] ✅ SUCCESS: User is now verified.');
      _showSuccessDialog();
    } else {
      debugPrint('[FACE_VERIFY] ❌ FAILED: Could not update Firestore user document.');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(
          child: Icon(Icons.verified, color: Colors.greenAccent, size: 60),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Identity Verified!',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Your profile has been automatically verified. You now have the verified badge.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context); 
                Navigator.pop(context); 
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('[FACE_VERIFY] 🛑 Disposing AutoVerificationScreen Cleanup.');
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (!_isInitializing && _cameraController != null)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.pink)),

          Center(
            child: Container(
              width: 250,
              height: 350,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _faceDetected ? Colors.greenAccent : Colors.white24,
                  width: 3,
                ),
                borderRadius: const BorderRadius.all(Radius.elliptical(125, 175)),
              ),
            ),
          ),

          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Column(
              children: [
                const Text(
                  'Auto-Verification',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _faceDetected ? Colors.greenAccent : Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _verificationProgress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                  minHeight: 6,
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
