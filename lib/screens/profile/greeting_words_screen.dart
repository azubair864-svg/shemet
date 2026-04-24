import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../models/greeting_model.dart';

class GreetingWordsScreen extends StatefulWidget {
  const GreetingWordsScreen({super.key});

  @override
  State<GreetingWordsScreen> createState() => _GreetingWordsScreenState();
}

class _GreetingWordsScreenState extends State<GreetingWordsScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Audio Recording & Playback
  FlutterSoundPlayer? _player;

  @override
  void initState() {
    super.initState();
    _checkGender();
    _initAudio();
  }

  Future<void> _checkGender() async {
    final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
    if (userDoc.exists) {
      final gender = userDoc.data()?['gender'];
      if (gender == 'Male') {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              title: const Text('Access Denied', style: TextStyle(color: Colors.white)),
              content: const Text(
                'Greeting words are only available for female accounts to engage with visitors.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _initAudio() async {
    try {
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
    } catch (e) {
      debugPrint('Error initializing Audio Player: $e');
      _player = null;
    }
  }

  @override
  void dispose() {
    try {
      if (_player != null) {
        _player!.closePlayer();
      }
    } catch (e) {
      debugPrint('Error disposing Audio Player: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.5,
                  colors: [
                    Color(0xFF1A1A2E),
                    const Color(0xFF0A0A12),
                  ],
                ),
              ),
            ),
          ),

          CustomScrollView(
            slivers: [
              _buildAppBar(),
              _buildStatsHeader(),
              _buildGreetingList(),
            ],
          ),
          
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      expandedHeight: 120,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'GREETING WORDS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.white70),
          onPressed: () => _showHelpDialog(),
        ),
      ],
    );
  }

  Widget _buildStatsHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('ACTIVE', '3'),
                  _buildStatItem('PLAYS', '124'),
                  _buildStatItem('TYPE', 'Premium'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildGreetingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('greetings')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final String errorMsg = snapshot.error.toString();
          // Check for Permission Denied or missing index
          if (errorMsg.contains('permission-denied')) {
             return SliverToBoxAdapter(
              child: _buildErrorState(
                'Access Denied. ⛔\n\n'
                '1. Please run: firebase deploy --only firestore:rules\n'
                '2. Check if your Firebase project has greetings collection rules.'
              ),
            );
          }
          return SliverToBoxAdapter(child: Center(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Error: $errorMsg', style: const TextStyle(color: Colors.white54, fontSize: 10)),
          )));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        }

        final greetings = snapshot.data?.docs
            .map((doc) => GreetingModel.fromDocument(doc))
            .toList() ?? [];

        if (greetings.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyState());
        }

        return SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildGreetingCard(greetings[index]),
              childCount: greetings.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGreetingCard(GreetingModel greeting) {
    final bool isAudio = greeting.audioUrl != null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.01),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isAudio ? Colors.blue : Colors.pink).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAudio ? Icons.mic_rounded : Icons.chat_bubble_outline_rounded,
                        color: isAudio ? Colors.blueAccent : Colors.pinkAccent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isAudio ? 'Voice Greeting' : 'Text Greeting',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    _buildMoreButton(greeting),
                  ],
                ),
                const SizedBox(height: 12),
                if (greeting.text.isNotEmpty)
                  Text(
                    greeting.text,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                  ),
                if (isAudio) ...[
                  const SizedBox(height: 12),
                  _buildAudioPlayer(greeting.audioUrl!),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMM dd, hh:mm a').format(greeting.createdAt),
                      style: const TextStyle(color: Colors.white30, fontSize: 10),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye_outlined, color: Colors.white30, size: 12),
                        const SizedBox(width: 4),
                        const Text('0', style: TextStyle(color: Colors.white30, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(String url) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            onPressed: () => _playAudio(url),
          ),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(1),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.3, // Mock progress
                child: Container(color: Colors.blueAccent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text('0:05', style: TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Positioned(
      bottom: 30,
      right: 20,
      left: 20,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.pinkAccent.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => _showAddGreetingSheet(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF1493), Color(0xFF9822C2)],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Container(
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'NEW GREETING',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddGreetingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddGreetingBottomSheet(
        onSaved: (text, audioPath, imageFile) => _saveGreeting(text, audioPath, imageFile),
      ),
    );
  }

  Future<void> _saveGreeting(String text, String? audioPath, File? imageFile) async {
    Navigator.pop(context); // Close sheet
    
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving Elite Greeting...')),
    );

    try {
      String? imageUrl;
      String? audioUrl;

      // Upload Image
      if (imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('greetings/$_currentUserId/img_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(imageFile);
        imageUrl = await storageRef.getDownloadURL();
      }

      // Upload Audio
      if (audioPath != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('greetings/$_currentUserId/audio_${DateTime.now().millisecondsSinceEpoch}.aac');
        await storageRef.putFile(File(audioPath));
        audioUrl = await storageRef.getDownloadURL();
      }

      // Save to Firestore
      final docRef = _firestore.collection('greetings').doc();
      final greeting = GreetingModel(
        id: docRef.id,
        userId: _currentUserId,
        text: text,
        imageUrl: imageUrl,
        audioUrl: audioUrl,
        audioDuration: 0, // Should calculate real duration
        createdAt: DateTime.now(),
      );

      await docRef.set(greeting.toMap());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elite Greeting Saved! ✨')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _playAudio(String url) async {
    if (_player == null) return;
    try {
      await _player!.startPlayer(fromURI: url);
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 100),
          Icon(Icons.auto_awesome, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 20),
          const Text(
            'NO GREETINGS YET',
            style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first Elite greeting to welcome fans.',
            style: TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 50),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreButton(GreetingModel greeting) {
    return PopupMenuButton(
      icon: const Icon(Icons.more_horiz, color: Colors.white54),
      color: const Color(0xFF1A1A2E),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 'delete') _deleteGreeting(greeting.id);
      },
    );
  }

  void _deleteGreeting(String id) async {
    await _firestore.collection('greetings').doc(id).delete();
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Greeting Words', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Greeting words are automatically sent to your new fans or profile visitors to initiate conversation. Use Voice Greetings for 3x higher engagement!',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('GOT IT')),
        ],
      ),
    );
  }
}

class _AddGreetingBottomSheet extends StatefulWidget {
  final Function(String text, String? audioPath, File? imageFile) onSaved;
  const _AddGreetingBottomSheet({required this.onSaved});

  @override
  State<_AddGreetingBottomSheet> createState() => _AddGreetingBottomSheetState();
}

class _AddGreetingBottomSheetState extends State<_AddGreetingBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String? _recordedPath;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    try {
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
    } catch (e) {
      debugPrint('Error initializing Audio Recorder: $e');
      _recorder = null;
    }
  }

  @override
  void dispose() {
    try {
      _recorder?.closeRecorder();
    } catch (e) {
      debugPrint('Error closing recorder: $e');
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_recorder == null) return;
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/greeting_${DateTime.now().millisecondsSinceEpoch}.aac';
      
      await _recorder!.startRecorder(toFile: path);
      setState(() {
        _isRecording = true;
        _recordedPath = path;
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_recorder == null) return;
    try {
      await _recorder!.stopRecorder();
    } catch (e) {
      debugPrint('Error stopping Audio Recorder: $e');
    }
    setState(() => _isRecording = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: ListView(
          controller: controller,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'NEW ELITE GREETING',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            const Text(
              'Record your voice or write a warm message for your fans.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 24),
            
            // Text Input
            TextField(
              controller: _textController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Audio Recording Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isRecording ? Colors.pinkAccent.withOpacity(0.3) : Colors.white12),
              ),
              child: Column(
                children: [
                  if (_recordedPath != null && !_isRecording)
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                        const SizedBox(width: 8),
                        const Text('Voice recorded successfully', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _recordedPath = null),
                          child: const Text('RE-RECORD', style: TextStyle(color: Colors.pinkAccent, fontSize: 10)),
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onLongPress: _startRecording,
                      onLongPressUp: _stopRecording,
                      child: Column(
                        children: [
                          Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isRecording 
                                  ? [Colors.pinkAccent, Colors.orangeAccent]
                                  : [Colors.blueAccent, Colors.purpleAccent],
                              ),
                            ),
                            child: Icon(
                              _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isRecording ? 'RELEASE TO STOP' : 'HOLD TO RECORD VOICE',
                            style: TextStyle(
                              color: _isRecording ? Colors.pinkAccent : Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Image Picker
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                    if (image != null) setState(() => _imageFile = File(image.path));
                  },
                  icon: const Icon(Icons.image_outlined, size: 20),
                  label: const Text('PHOTO'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_imageFile != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_imageFile!, width: 40, height: 40, fit: BoxFit.cover),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Save Button
            ElevatedButton(
              onPressed: () => widget.onSaved(_textController.text, _recordedPath, _imageFile),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('SAVE GREETING', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}