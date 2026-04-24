import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0;
  bool _isLoading = false;

  // Photo Management
  final List<File?> _photos = List.filled(6, null);
  final List<Uint8List?> _webPhotos = List.filled(6, null); // For Web support
  final ImagePicker _picker = ImagePicker();

  // Interests (CLIENT: Keep only interests - remove other fields)
  final List<String> _availableInterests = [
    'Music',
    'Travel',
    'Sports',
    'Gaming',
    'Food',
    'Movies',
    'Reading',
    'Photography',
    'Dancing',
    'Fitness',
    'Art',
    'Cooking',
    'Fashion',
    'Technology',
    'Nature',
    'Pets',
  ];
  final List<String> _selectedInterests = [];

  @override
  void initState() {
    super.initState();
    
    
    
    
  }

  @override
  void dispose() {
    
    
    super.dispose();
  }

  // Image Picker Functions
  Future<void> _pickImage(int index, ImageSource source) async {
    

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _webPhotos[index] = bytes;
          });
        } else {
          setState(() {
            _photos[index] = File(image.path);
          });
        }
        
      } else {
        
      }
    } catch (e) {
      
      
      
      _showSnackBar('Error picking image: $e');
    }
  }

  void _showImageSourceDialog(int index) {
    

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.purple),
              title: const Text('Camera'),
              onTap: () {
                
                Navigator.pop(context);
                _pickImage(index, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text('Gallery'),
              onTap: () {
                
                Navigator.pop(context);
                _pickImage(index, ImageSource.gallery);
              },
            ),
            if (_photos[index] != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo'),
                onTap: () {
                  
                  Navigator.pop(context);
                  setState(() {
                    _photos[index] = null;
                    _webPhotos[index] = null;
                  });
                  
                },
              ),
          ],
        ),
      ),
    );
  }

  // Compress Photo
  Future<File?> _compressPhoto(File file) async {
    
    

    try {
      final originalSize = await file.length();
      

      final compressedBytes = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
      );

      if (compressedBytes == null) {
        
        return file;
      }

      
      final reduction = ((1 - (compressedBytes.length / originalSize)) * 100).toStringAsFixed(1);
      

      // Write compressed bytes to new file
      final compressedPath = file.path.replaceAll('.jpg', '_compressed.jpg');
      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressedBytes);

      
      

      return compressedFile;
    } catch (e) {
      
      
      
      
      return file;
    }
  }

  // Upload Photos to Firebase Storage
  Future<List<String>> _uploadPhotos() async {
    List<String> photoUrls = [];
    final userId = FirebaseAuth.instance.currentUser!.uid;
    

    int uploadCount = _photos.where((p) => p != null).length;
    
    for (int i = 0; i < _photos.length; i++) {
      if (_photos[i] != null || _webPhotos[i] != null) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('user_photos')
              .child(userId)
              .child('photo_$i.jpg');

          final metadata = SettableMetadata(contentType: 'image/jpeg');

          if (kIsWeb) {
            final uploadTask = await ref.putData(_webPhotos[i]!, metadata);
            final url = await uploadTask.ref.getDownloadURL();
            photoUrls.add(url);
          } else {
            // Compress photo first
            final compressedFile = await _compressPhoto(_photos[i]!);
            if (compressedFile == null) continue;

            final uploadTask = await ref.putFile(compressedFile, metadata);
            final url = await uploadTask.ref.getDownloadURL();
            photoUrls.add(url);

            // Clean up compressed file
            try {
              if (compressedFile.path != _photos[i]!.path) {
                await compressedFile.delete();
              }
            } catch (e) {}
          }
        } catch (e) {
          debugPrint("Error uploading photo $i: $e");
        }
      }
    }

    
    
    return photoUrls;
  }

  void _showSnackBar(String message) {
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Step Navigation
  void _nextStep() {
    
    

    if (_currentStep < 1) { // CLIENT: Only 2 steps now (0=Photos, 1=Interests)
      setState(() {
        _currentStep++;
      });
      
    } else {
      
    }
  }

  void _previousStep() {
    
    

    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      
    } else {
      
    }
  }
  // Save Profile to Firestore (CLIENT: Simplified - only photos + interests)
  Future<void> _saveProfile() async {
    

    // Validation: At least 1 photo
    if (_photos[0] == null && _webPhotos[0] == null) {
      
      _showSnackBar('Please add at least one profile photo');
      return;
    }

    // Validation: At least 3 interests
    if (_selectedInterests.length < 3) {
      
      _showSnackBar('Please select at least 3 interests');
      return;
    }

    
    
    

    setState(() => _isLoading = true);
    

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      

      // Upload photos
      
      final photoUrls = await _uploadPhotos();
      
      

      // CLIENT: Only update photos and interests (other fields already saved in onboarding)
      final profileData = {
        'photos': photoUrls,
        'interests': _selectedInterests,
        'profileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      
      
      
      

      // Save to Firestore
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(profileData, SetOptions(merge: true));

      

      // Update Auth profile photo
      
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && !currentUser.isAnonymous) {
          if (photoUrls.isNotEmpty) {
            await currentUser.updatePhotoURL(photoUrls[0]);
            
          }
        } else {
          
        }
      } catch (e) {
        
        // Continue anyway - data is in Firestore
      }

      // Verify data was saved
      
      final savedDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (savedDoc.exists) {
        
        
      } else {
        
      }

      

      if (!mounted) {
        
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
      

    } catch (e) {
      
      
      
      

      if (mounted) {
        _showSnackBar('Error saving profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    
    
    
    

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _previousStep,
        )
            : null,
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Saving your profile...'),
          ],
        ),
      )
          : Column(
        children: [
          // Progress Indicator (CLIENT: Only 2 steps now)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: List.generate(2, (index) { // CLIENT: Changed from 4 to 2
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < 1 ? 8 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= _currentStep
                          ? Colors.purple
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Step Content
          Expanded(
            child: Form(key: _formKey, child: _buildStepContent()),
          ),

          // Bottom Button
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _currentStep == 1 ? _saveProfile : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentStep == 1 ? 'Complete Profile' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    

    switch (_currentStep) {
      case 0:
        return _buildPhotoStep();
      case 1:
        return _buildInterestsStep();
      default:
        return _buildPhotoStep();
    }
  }
  // Step 1: Photos (CLIENT: Keep photos step)
  Widget _buildPhotoStep() {
    

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Add Your Photos',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add at least 1 photo. More photos increase your chances!',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),

        // Main Photo (Large)
        GestureDetector(
          onTap: () {
            
            _showImageSourceDialog(0);
          },
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _photos[0] != null
                    ? Colors.purple
                    : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: (_photos[0] != null || _webPhotos[0] != null)
                ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: kIsWeb
                  ? Image.memory(_webPhotos[0]!, fit: BoxFit.cover)
                  : Image.file(_photos[0]!, fit: BoxFit.cover),
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate,
                  size: 60,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add Main Photo',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Additional Photos Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: 5,
          itemBuilder: (context, index) {
            final photoIndex = index + 1;
            return GestureDetector(
              onTap: () {
                
                _showImageSourceDialog(photoIndex);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _photos[photoIndex] != null
                        ? Colors.purple
                        : Colors.grey.shade300,
                  ),
                ),
                child: (_photos[photoIndex] != null || _webPhotos[photoIndex] != null)
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: kIsWeb
                      ? Image.memory(
                    _webPhotos[photoIndex]!,
                    fit: BoxFit.cover,
                  )
                      : Image.file(
                    _photos[photoIndex]!,
                    fit: BoxFit.cover,
                  ),
                )
                    : Icon(Icons.add, color: Colors.grey.shade400, size: 32),
              ),
            );
          },
        ),
      ],
    );
  }

  // Step 2: Interests (CLIENT: Keep only interests step)
  Widget _buildInterestsStep() {
    
    
    

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Your Interests',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select at least 3 interests',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _availableInterests.map((interest) {
            final isSelected = _selectedInterests.contains(interest);
            return GestureDetector(
              onTap: () {
                
                setState(() {
                  if (isSelected) {
                    _selectedInterests.remove(interest);
                    
                  } else {
                    _selectedInterests.add(interest);
                    
                  }
                });
                
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.purple : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? Colors.purple : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Text(
                  interest,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.purple.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Selected: ${_selectedInterests.length} / 3 minimum',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}