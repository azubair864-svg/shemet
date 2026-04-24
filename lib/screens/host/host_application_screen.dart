import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/host_application_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';

/// ⭐⭐⭐ PRODUCTION-READY HOST APPLICATION SCREEN ⭐⭐⭐
/// Complete host application with category, photo upload, age verification
class HostApplicationScreen extends StatefulWidget {
  const HostApplicationScreen({super.key});

  @override
  State<HostApplicationScreen> createState() => _HostApplicationScreenState();
}

class _HostApplicationScreenState extends State<HostApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final ImagePicker _imagePicker = ImagePicker();

  // Form controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _socialLink1Controller = TextEditingController();
  final TextEditingController _socialLink2Controller = TextEditingController();
  final TextEditingController _socialLink3Controller = TextEditingController();

  bool _isLoading = false;
  bool _isUploading = false;
  UserModel? _currentUser;
  HostApplicationModel? _existingApplication;
  String _selectedExperience = 'beginner';
  int _selectedHoursPerWeek = 5;

  // ⭐ NEW: Category selection
  String? _selectedCategory;
  final List<Map<String, String>> _categories = [
    {'id': 'gaming', 'name': '🎮 Gaming', 'desc': 'Play games and entertain'},
    {'id': 'music', 'name': '🎵 Music', 'desc': 'Sing, play instruments, DJ'},
    {'id': 'dance', 'name': '💃 Dance', 'desc': 'Dance performances'},
    {
      'id': 'talk_show',
      'name': '🎙️ Talk Show',
      'desc': 'Chat and discussions',
    },
    {
      'id': 'education',
      'name': '📚 Education',
      'desc': 'Teaching and tutorials',
    },
    {'id': 'lifestyle', 'name': '✨ Lifestyle', 'desc': 'Daily life, vlogs'},
    {
      'id': 'cooking',
      'name': '🍳 Cooking',
      'desc': 'Cooking shows and recipes',
    },
    {'id': 'fitness', 'name': '💪 Fitness', 'desc': 'Workouts and health'},
    {'id': 'art', 'name': '🎨 Art', 'desc': 'Drawing, painting, crafts'},
    {'id': 'other', 'name': '📌 Other', 'desc': 'Other content types'},
  ];

  // ⭐ NEW: Photo verification
  final List<File> _verificationPhotos = [];
  final List<Uint8List> _webVerificationPhotos = [];
  File? _idDocument;
  Uint8List? _webIdDocument;
  List<String> _uploadedPhotoUrls = [];
  String? _uploadedIdUrl;

  // ⭐ NEW: Age verification
  DateTime? _dateOfBirth;
  int? _calculatedAge;

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load current user

      _currentUser = await _databaseService.getUserById(_currentUserId);

      // Check if user already has an application

      final snapshot = await FirebaseFirestore.instance
          .collection('host_applications')
          .where('userId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _existingApplication = HostApplicationModel.fromSnapshot(
          snapshot.docs.first,
        );
      } else {}

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ⭐ NEW: Pick verification photos
  Future<void> _pickVerificationPhoto() async {
    if (_verificationPhotos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 3 photos allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _webVerificationPhotos.add(bytes);
            _verificationPhotos.add(File('web')); // Placeholder
          });
        } else {
          setState(() {
            _verificationPhotos.add(File(image.path));
          });
        }
      }
    } catch (e) {}
  }

  // ⭐ NEW: Pick ID document
  Future<void> _pickIdDocument() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _webIdDocument = bytes;
            _idDocument = File('web'); // Placeholder
          });
        } else {
          setState(() {
            _idDocument = File(image.path);
          });
        }
      }
    } catch (e) {}
  }

  // ⭐ NEW: Upload photos to Firebase Storage
  Future<List<String>> _uploadPhotos() async {
    final List<String> urls = [];

    for (int i = 0; i < _verificationPhotos.length; i++) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('host_applications')
          .child(_currentUserId)
          .child(
            'verification_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          );

      if (kIsWeb) {
        await ref.putData(_webVerificationPhotos[i]);
      } else {
        await ref.putFile(_verificationPhotos[i]);
      }
      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  // ⭐ NEW: Upload ID document
  Future<String?> _uploadIdDocument() async {
    if (_idDocument == null) {
      return null;
    }

    final ref = FirebaseStorage.instance
        .ref()
        .child('host_applications')
        .child(_currentUserId)
        .child('id_document_${DateTime.now().millisecondsSinceEpoch}.jpg');

    if (kIsWeb) {
      await ref.putData(_webIdDocument!);
    } else {
      await ref.putFile(_idDocument!);
    }
    final url = await ref.getDownloadURL();

    return url;
  }

  // ⭐ NEW: Select date of birth
  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      helpText: 'Select your date of birth',
    );

    if (picked != null) {
      final age = DateTime.now().difference(picked).inDays ~/ 365;

      setState(() {
        _dateOfBirth = picked;
        _calculatedAge = age;
      });
    }
  }

  Future<void> _submitApplication() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate category
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate photos
    if (_verificationPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one verification photo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate age
    if (_dateOfBirth == null ||
        _calculatedAge == null ||
        _calculatedAge! < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be at least 18 years old to become a host'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = true;
    });

    try {
      // Upload photos

      _uploadedPhotoUrls = await _uploadPhotos();

      // Upload ID document

      _uploadedIdUrl = await _uploadIdDocument();

      setState(() => _isUploading = false);

      // Collect social links

      final socialLinks = <String>[];
      if (_socialLink1Controller.text.trim().isNotEmpty) {
        socialLinks.add(_socialLink1Controller.text.trim());
      }
      if (_socialLink2Controller.text.trim().isNotEmpty) {
        socialLinks.add(_socialLink2Controller.text.trim());
      }
      if (_socialLink3Controller.text.trim().isNotEmpty) {
        socialLinks.add(_socialLink3Controller.text.trim());
      }

      // Create application model

      final applicationId = FirebaseFirestore.instance
          .collection('host_applications')
          .doc()
          .id;

      final application = HostApplicationModel(
        applicationId: applicationId,
        userId: _currentUserId,
        userName: _currentUser?.name ?? 'Unknown',
        email: _currentUser?.email ?? '',
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
        reason: _reasonController.text.trim(),
        socialLinks: socialLinks,
        expectedHoursPerWeek: _selectedHoursPerWeek,
        experienceLevel: _selectedExperience,
        status: 'pending',
        submittedAt: DateTime.now(),
        // New fields
        category: _selectedCategory,
        verificationPhotos: _uploadedPhotoUrls,
        idDocumentUrl: _uploadedIdUrl,
        age: _calculatedAge,
        dateOfBirth: _dateOfBirth,
        ageVerified: _calculatedAge != null && _calculatedAge! >= 18,
        idVerified: false, // Will be verified by admin
      );

      // Save to Firestore

      await FirebaseFirestore.instance
          .collection('host_applications')
          .doc(applicationId)
          .set(application.toMap());

      // Update user document

      await _databaseService.updateUser(_currentUserId, {
        'hasAppliedForHost': true,
        'hostApplicationStatus': 'pending',
        'hostApplicationDate': Timestamp.now(),
        'hostCategory': _selectedCategory,
      });

      setState(() => _isLoading = false);

      // Show success dialog
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit application: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Application Submitted!'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your host application has been submitted successfully.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Our team will review your application and get back to you within 1-3 business days.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              'You will receive a notification once your application is reviewed.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close application screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.purple)),
      );
    }

    // ⭐ NEW: Gender Eligibility Check
    if (_currentUser != null && _currentUser!.gender != 'Female') {
      return _buildNotEligibleView();
    }

    // If user already has a pending application
    if (_existingApplication != null &&
        _existingApplication!.status == 'pending') {
      return _buildPendingApplicationView();
    }

    // If user was rejected
    if (_existingApplication != null &&
        _existingApplication!.status == 'rejected') {
      return _buildRejectedApplicationView();
    }

    // If user is already approved
    if (_existingApplication != null &&
        _existingApplication!.status == 'approved') {
      return _buildAlreadyHostView();
    }

    // Show application form
    return _buildApplicationForm();
  }

  Widget _buildNotEligibleView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Not Eligible'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Not Eligible for Hosting',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'We are currently only accepting Female accounts for our agency host program. If you believe this is an error, please contact support.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Return to Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationForm() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Host'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.purple),
                  const SizedBox(height: 16),
                  Text(
                    _isUploading ? 'Uploading photos...' : 'Processing...',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 24),

                    // ⭐ NEW: Category Selection
                    _buildCategorySection(),
                    const SizedBox(height: 24),

                    // ⭐ NEW: Age Verification
                    _buildAgeVerificationSection(),
                    const SizedBox(height: 24),

                    // ⭐ NEW: Photo Verification
                    _buildPhotoVerificationSection(),
                    const SizedBox(height: 24),

                    // ⭐ NEW: ID Document Upload
                    _buildIdDocumentSection(),
                    const SizedBox(height: 24),

                    // Phone number
                    _buildPhoneField(),
                    const SizedBox(height: 16),

                    // Bio
                    _buildBioField(),
                    const SizedBox(height: 16),

                    // Reason
                    _buildReasonField(),
                    const SizedBox(height: 16),

                    // Social links
                    _buildSocialLinksSection(),
                    const SizedBox(height: 16),

                    // Experience level
                    _buildExperienceSection(),
                    const SizedBox(height: 16),

                    // Hours per week
                    _buildHoursSection(),
                    const SizedBox(height: 24),

                    // Submit button
                    _buildSubmitButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.purple, Colors.deepPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Text(
                'Become a Host',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Start live streaming and earn diamonds!\nShare your talents with the world.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ⭐ NEW: Category Selection Widget
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.category, color: Colors.purple),
            SizedBox(width: 8),
            Text(
              'Select Your Category *',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose the category that best describes your content',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategory == category['id'];

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = category['id'];
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.purple.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.purple : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category['name']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.purple : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ⭐ NEW: Age Verification Widget
  Widget _buildAgeVerificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.cake, color: Colors.purple),
            SizedBox(width: 8),
            Text(
              'Age Verification *',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'You must be at least 18 years old to become a host',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _selectDateOfBirth,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _dateOfBirth != null
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _dateOfBirth != null
                    ? Colors.green
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _dateOfBirth != null
                      ? Icons.check_circle
                      : Icons.calendar_today,
                  color: _dateOfBirth != null ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dateOfBirth != null
                            ? 'Date of Birth: ${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                            : 'Tap to select your date of birth',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _dateOfBirth != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _dateOfBirth != null
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                      if (_calculatedAge != null)
                        Text(
                          'Age: $_calculatedAge years old',
                          style: TextStyle(
                            fontSize: 14,
                            color: _calculatedAge! >= 18
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (_calculatedAge != null && _calculatedAge! < 18)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You must be at least 18 years old to become a host',
                    style: TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ⭐ NEW: Photo Verification Widget
  Widget _buildPhotoVerificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.photo_camera, color: Colors.purple),
            SizedBox(width: 8),
            Text(
              'Verification Photos *',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Upload 1-3 clear photos of yourself for verification',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Existing photos
              ..._verificationPhotos.asMap().entries.map((entry) {
                return Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 2),
                    image: DecorationImage(
                      image: kIsWeb
                          ? MemoryImage(_webVerificationPhotos[entry.key])
                          : FileImage(entry.value) as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _verificationPhotos.removeAt(entry.key);
                              if (kIsWeb) _webVerificationPhotos.removeAt(entry.key);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // Add photo button
              if (_verificationPhotos.length < 3)
                InkWell(
                  onTap: _pickVerificationPhoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, color: Colors.purple, size: 32),
                        SizedBox(height: 8),
                        Text(
                          'Add Photo',
                          style: TextStyle(color: Colors.purple, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_verificationPhotos.length}/3 photos added',
          style: TextStyle(
            color: _verificationPhotos.isNotEmpty ? Colors.green : Colors.grey,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ⭐ NEW: ID Document Widget
  Widget _buildIdDocumentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.badge, color: Colors.purple),
            SizedBox(width: 8),
            Text(
              'ID Document (Optional)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Upload a government-issued ID for faster verification',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickIdDocument,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _idDocument != null
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _idDocument != null
                    ? Colors.green
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                if (_idDocument != null)
                  Container(
                    width: 60,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: kIsWeb
                            ? MemoryImage(_webIdDocument!)
                            : FileImage(_idDocument!) as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.upload_file, color: Colors.grey, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _idDocument != null
                        ? 'ID document uploaded'
                        : 'Tap to upload ID document',
                    style: TextStyle(
                      fontSize: 16,
                      color: _idDocument != null ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
                if (_idDocument != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _idDocument = null;
                        if (kIsWeb) _webIdDocument = null;
                      });
                    },
                  )
                else
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Phone Number (Optional)',
        hintText: 'Enter your phone number',
        prefixIcon: const Icon(Icons.phone),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          if (value.length < 10) {
            return 'Phone number must be at least 10 digits';
          }
        }
        return null;
      },
    );
  }

  Widget _buildBioField() {
    return TextFormField(
      controller: _bioController,
      maxLines: 3,
      maxLength: 200,
      decoration: InputDecoration(
        labelText: 'Bio (Optional)',
        hintText: 'Tell us about yourself',
        prefixIcon: const Icon(Icons.person),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildReasonField() {
    return TextFormField(
      controller: _reasonController,
      maxLines: 4,
      maxLength: 500,
      decoration: InputDecoration(
        labelText: 'Why do you want to become a host? *',
        hintText: 'Share your motivation...',
        prefixIcon: const Icon(Icons.lightbulb),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please tell us why you want to become a host';
        }
        if (value.trim().length < 50) {
          return 'Please provide at least 50 characters';
        }
        return null;
      },
    );
  }

  Widget _buildSocialLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Social Media Links (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add your social media profiles to help us learn more about you',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _socialLink1Controller,
          decoration: InputDecoration(
            labelText: 'Instagram / TikTok / YouTube',
            hintText: 'https://...',
            prefixIcon: const Icon(Icons.link),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _socialLink2Controller,
          decoration: InputDecoration(
            labelText: 'Additional Link',
            hintText: 'https://...',
            prefixIcon: const Icon(Icons.link),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _socialLink3Controller,
          decoration: InputDecoration(
            labelText: 'Additional Link',
            hintText: 'https://...',
            prefixIcon: const Icon(Icons.link),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Experience Level *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'beginner',
              label: Text('Beginner'),
              icon: Icon(Icons.star_border),
            ),
            ButtonSegment(
              value: 'intermediate',
              label: Text('Intermediate'),
              icon: Icon(Icons.star_half),
            ),
            ButtonSegment(
              value: 'professional',
              label: Text('Professional'),
              icon: Icon(Icons.star),
            ),
          ],
          selected: {_selectedExperience},
          onSelectionChanged: (Set<String> selected) {
            setState(() {
              _selectedExperience = selected.first;
            });
          },
        ),
      ],
    );
  }

  Widget _buildHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expected Hours Per Week: $_selectedHoursPerWeek hours',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Slider(
          value: _selectedHoursPerWeek.toDouble(),
          min: 1,
          max: 40,
          divisions: 39,
          label: '$_selectedHoursPerWeek hours',
          activeColor: Colors.purple,
          onChanged: (value) {
            setState(() {
              _selectedHoursPerWeek = value.toInt();
            });
          },
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1 hour', style: TextStyle(color: Colors.grey)),
            Text('40 hours', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final bool canSubmit =
        _selectedCategory != null &&
        _verificationPhotos.isNotEmpty &&
        _calculatedAge != null &&
        _calculatedAge! >= 18;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (_isLoading || !canSubmit) ? null : _submitApplication,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Submit Application',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildPendingApplicationView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Application'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pending, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              const Text(
                'Application Pending',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Submitted: ${_existingApplication!.submittedAt.toString().split('.')[0]}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              if (_existingApplication!.category != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Category: ${_existingApplication!.categoryDisplayName}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Your application is currently under review. Our team will get back to you within 1-3 business days.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedApplicationView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Application'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Application Declined',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_existingApplication!.rejectionReason != null) ...[
                const Text(
                  'Reason:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _existingApplication!.rejectionReason!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 32),
              const Text(
                'You can submit a new application after addressing the feedback.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  // Delete old application
                  await FirebaseFirestore.instance
                      .collection('host_applications')
                      .doc(_existingApplication!.applicationId)
                      .delete();

                  setState(() {
                    _existingApplication = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Apply Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlreadyHostView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Status'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'You\'re a Host!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Congratulations! You are already an approved host.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bioController.dispose();
    _reasonController.dispose();
    _socialLink1Controller.dispose();
    _socialLink2Controller.dispose();
    _socialLink3Controller.dispose();
    super.dispose();
  }
}
