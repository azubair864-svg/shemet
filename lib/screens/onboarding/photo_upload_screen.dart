import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../home/main_screen.dart';

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  File? _imageFile;
  Uint8List? _webImageBytes; // For Flutter Web support
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF9B6FD7), Color(0xFFE8B4F5)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(height: 40),
                  Text(
                    'Add Your Photo',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Upload a profile picture',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 60),

                  // Photo Circle
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: (_imageFile != null || _webImageBytes != null)
                          ? ClipOval(
                        child: kIsWeb
                            ? Image.memory(
                          _webImageBytes!,
                          fit: BoxFit.cover,
                        )
                            : Image.file(
                          _imageFile!,
                          fit: BoxFit.cover,
                        ),
                      )
                          : Icon(
                        Icons.add_a_photo,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  SizedBox(height: 20),
                  Text(
                    'Tap to upload photo',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),

                  Spacer(),
                  
                  // Continue Button (if photo selected)
                  if (_imageFile != null || _webImageBytes != null)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _uploadAndContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: _isUploading
                            ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF9B6FD7),
                          ),
                        )
                            : Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9B6FD7),
                          ),
                        ),
                      ),
                    ),

                  if (_imageFile != null) SizedBox(height: 10),

                  // Skip Button
                  TextButton(
                    onPressed: _isUploading ? null : _skip,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _webImageBytes = bytes;
          });
        } else {
          setState(() => _imageFile = File(image.path));
        }
        
      } else {
        
      }
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<String> _uploadPhotoToStorage() async {
    

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('No user ID');
    }

    

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('user_photos')
        .child(userId)
        .child('photo_0.jpg');

    

    final metadata = SettableMetadata(contentType: 'image/jpeg');

    if (kIsWeb) {
      await storageRef.putData(_webImageBytes!, metadata);
    } else {
      await storageRef.putFile(_imageFile!, metadata);
    }
    
    final downloadUrl = await storageRef.getDownloadURL();

    return downloadUrl;
  }

  Future<void> _uploadAndContinue() async {
    if (_imageFile == null && _webImageBytes == null) return;

    
    setState(() => _isUploading = true);

    try {
      // Upload photo
      final photoUrl = await _uploadPhotoToStorage();
      

      // Update Firestore
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('No user ID');
      }

      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'photos': [photoUrl],
        'profileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      
      

      if (!mounted) return;

      _navigateToMain();
    } catch (e) {
      
      
      
      

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isUploading = false);
    }
  }

  Future<void> _skip() async {
    

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('No user ID');
      }

      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'photos': [],
        'profileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      
      

      if (!mounted) return;

      _navigateToMain();
    } catch (e) {
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _navigateToMain() {
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainScreen()),
          (route) => false,
    );
    
  }
}