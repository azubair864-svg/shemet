import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/database_service.dart';
import '../../services/agora_service.dart';
import '../../providers/user_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/party_room/beauty_effects_panel.dart';
import '../../widgets/party_room/theme_background.dart';
import '../../widgets/party_room/sticker_panel.dart';

class CreatePartyRoomScreen extends StatefulWidget {
  const CreatePartyRoomScreen({super.key});

  @override
  State<CreatePartyRoomScreen> createState() => _CreatePartyRoomScreenState();
}

class _CreatePartyRoomScreenState extends State<CreatePartyRoomScreen> {
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  final AgoraService _agoraService = AgoraService();

  String _selectedCategory = 'Chat';
  int _selectedSeats = 8;
  String _selectedTheme = 'purple';
  final bool _isPasswordEnabled = false;
  bool _isLoading = false;
  String _activeMode = 'Video'; // Video, Audio, Game
  String _selectedGameId = 'dice'; // Default game
  File? _coverImageFile;

  final List<Map<String, String>> _games = [
    {
      'id': 'dice',
      'name': 'Royal Dice',
      'icon': 'assets/images/games/royal_dice.png',
    },
    {
      'id': 'racing',
      'name': 'Car Racing',
      'icon': 'assets/images/games/race_game.png',
    },
    {
      'id': 'aviator',
      'name': 'Aviator',
      'icon': 'assets/images/games/aviator.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('[DEBUG_UI] 🚀 CreatePartyRoomScreen Initialized. Default Mode: $_activeMode');
    _initCamera();
  }

  Future<void> _initCamera() async {
    await _agoraService.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showBeautyPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const BeautyEffectsPanel(),
    );
  }

  void _showStickerPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const StickerPanel(),
    );
  }

  Future<void> _createRoom() async {
    if (_roomNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter room name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;

      if (currentUser == null) throw Exception('User not found');

      debugPrint('[DEBUG_PARTY] 🚀 Creating room with type: ${_activeMode.toLowerCase()}');
      if (_activeMode == 'Game') debugPrint('[DEBUG_PARTY] 🎮 Selected Game ID: $_selectedGameId');

      String uploadedCoverUrl = '';
      if (_coverImageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('party_room_covers/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(_coverImageFile!);
        uploadedCoverUrl = await storageRef.getDownloadURL();
      }

      final roomId = await _databaseService.createPartyRoom(
        hostId: currentUser.uid,
        hostName: currentUser.name,
        hostPhoto: currentUser.photos.isNotEmpty ? currentUser.photos[0] : '',
        roomName: _roomNameController.text.trim(),
        category: _selectedCategory,
        country: currentUser.country ?? 'Unknown',
        countryFlag: currentUser.countryFlag ?? '🌍',
        hostLevel: currentUser.level,
        maxSeats: _selectedSeats,
        coverPhoto: uploadedCoverUrl,
        backgroundTheme: _selectedTheme,
        password: _isPasswordEnabled ? _passwordController.text.trim() : '',
        roomType: _activeMode.toLowerCase(),
        gameId: _activeMode == 'Game' ? _selectedGameId : null,
        backgroundImage: _generateBackgroundImage(), // Pass the selected background
      );

      debugPrint('[DEBUG_PARTY] ✅ Room created successfully. ID: $roomId');

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/party_room',
          arguments: {'roomId': roomId},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _generateBackgroundImage() {
    final random = math.Random();
    final isOption1 = random.nextBool();
    final suffix = isOption1 ? '_1.png' : '_2.png';

    String prefix = 'chat_bg';
    switch (_selectedCategory.toLowerCase()) {
      case 'gaming':
        prefix = 'gamming_bg';
        break;
      case 'music':
        prefix = 'music_bg';
        break;
      case 'dating':
      case 'romantic':
        prefix = 'romantic_bg';
        break;
      case 'pk':
        prefix = 'pk_bg';
        break;
      case 'chat':
        prefix = 'chat_bg';
        break;
    }

    return 'assets/images/$prefix$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Background
          _activeMode == 'Video' 
            ? _buildCameraPreview() 
            : ThemeBackground(themeName: _selectedTheme),

          // 2. Overlay Gradients
          if (_activeMode == 'Video') _buildBackdropGradients(),

          // 3. Top Controls
          _buildTopBar(),

          // 4. Mode Specific Preview
          if (_activeMode == 'Audio') _buildAudioModePreview(),
          if (_activeMode == 'Game') _buildGameModePreview(),

          // 5. Bottom Hub
          _buildBottomHub(),

          // 6. Loading Overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_agoraService.isInitialized) {
      return Container(color: Colors.black, child: const Center(child: CircularProgressIndicator()));
    }
    if (_agoraService.engine != null) {
      _agoraService.engine!.startPreview();
      return SizedBox.expand(
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _agoraService.engine!,
            canvas: const VideoCanvas(
              uid: 0,
              renderMode: RenderModeType.renderModeFit, // Prevents zooming/cropping
            ),
          ),
        ),
      );
    }
    return Container(color: Colors.black);
  }

  Future<void> _pickCoverImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() => _coverImageFile = File(image.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  // --- AUDIO MODE UI ---
  Widget _buildAudioModePreview() {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;

    return Positioned.fill(
      top: 60,
      child: Column(
        children: [
          _buildHostArea(currentUser),
          const SizedBox(height: 10),
          Expanded(child: _buildSeatGrid()),
        ],
      ),
    );
  }

  // --- GAME MODE UI ---
  Widget _buildGameModePreview() {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;

    return Positioned.fill(
      top: 60,
      child: Column(
        children: [
          _buildGameSeatGrid(currentUser),
          const Spacer(),
          _buildGameSelector(),
          const SizedBox(height: 160), // Moved back down
        ],
      ),
    );
  }

  Widget _buildGameSeatGrid(dynamic user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 1.0,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Host Seat (Top Left)
          _buildGameSeat(user, isHost: true),
          // Empty Seat (Top Right)
          _buildGameSeat(null),
          // Empty Seat (Bottom Left)
          _buildGameSeat(null),
          // Empty Seat (Bottom Right)
          _buildGameSeat(null),
        ],
      ),
    );
  }

  Widget _buildGameSeat(dynamic user, {bool isHost = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isHost && user != null)
             ClipRect(child: user.photos.isNotEmpty 
                ? Image.network(user.photos[0], fit: BoxFit.cover, width: double.infinity, height: double.infinity) 
                : const Icon(Icons.person, color: Colors.white24, size: 50))
          else
            const Icon(Icons.chair, color: Colors.white12, size: 40),
          
          if (isHost)
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                child: const Text('Rising Star', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameSelector() {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _games.length,
        itemBuilder: (context, index) {
          final game = _games[index];
          final isSelected = _selectedGameId == game['id'];
          return GestureDetector(
            onTap: () => setState(() => _selectedGameId = game['id']!),
            child: Container(
              width: 90,
              margin: const EdgeInsets.only(right: 15),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 10)] : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset(
                        game['icon']!,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          color: Colors.black26,
                          child: const Icon(Icons.videogame_asset, color: Colors.white38),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    game['name']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isSelected) 
                    Container(margin: const EdgeInsets.only(top: 4), width: 20, height: 2, color: AppColors.primary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHostArea(dynamic user) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 65, height: 65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: ClipOval(
                child: user?.photos.isNotEmpty == true
                    ? Image.network(user!.photos[0], fit: BoxFit.cover)
                    : const Icon(Icons.person, size: 35, color: Colors.white24),
              ),
            ),
            Positioned(
              top: 0, left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.orange, Colors.red]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Rising Star', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(user?.name ?? 'Host', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(_selectedCategory, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
      ],
    );
  }

  Widget _buildSeatGrid() {
    int guestCount = _selectedSeats - 1;
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 0),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, 
        crossAxisSpacing: 20, 
        mainAxisSpacing: 15,
        childAspectRatio: 1.1,
      ),
      itemCount: guestCount,
      itemBuilder: (context, index) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 40, 
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08), 
              shape: BoxShape.circle, 
              border: Border.all(color: Colors.white12, width: 1)
            ),
            child: const Center(child: Icon(Icons.chair, color: Colors.white24, size: 16)),
          ),
          const SizedBox(height: 2),
          Text('${index + 2}', style: const TextStyle(color: Colors.white24, fontSize: 8)),
        ],
      ),
    );
  }

  Widget _buildBackdropGradients() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.4),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
            stops: const [0.0, 0.2, 0.75, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
            const Text(
              'Party Settings',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomHub() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Column(
        children: [
          if (_activeMode != 'Game') _buildRoomSettingsSummary(),
          const SizedBox(height: 25),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_activeMode == 'Video' || _activeMode == 'Game')
                  _buildSideButton(Icons.auto_fix_high, _showBeautyPanel),
                const Spacer(),
                _buildCreateButton(),
                const Spacer(),
                if (_activeMode == 'Video' || _activeMode == 'Game')
                  _buildSideButton(Icons.emoji_emotions, () => _showStickerPanel(context)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildModeSelector(),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  Widget _buildSideButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildCreateButton() {
    IconData btnIcon = Icons.videocam;
    if (_activeMode == 'Audio') btnIcon = Icons.mic;
    if (_activeMode == 'Game') btnIcon = Icons.sports_esports;

    return GestureDetector(
      onTap: _createRoom,
      child: Container(
        width: 180, height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF9C27B0)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(btnIcon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text('Let\'s Party', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomSettingsSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
      child: Column(
        children: [
          TextField(
            controller: _roomNameController,
            style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Add a room name...',
              filled: true, fillColor: Colors.white.withOpacity(0.7),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickCoverImage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, color: _coverImageFile != null ? Colors.green : Colors.white54, size: 16),
                  const SizedBox(width: 6),
                  Text(_coverImageFile != null ? 'Cover Photo Selected' : 'Add Custom Cover Photo (Optional)', style: TextStyle(color: _coverImageFile != null ? Colors.green : Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSettingItem(Icons.category, _selectedCategory, () => _showSelectionSheet('Category', ['Chat', 'Music', 'Gaming', 'Dating', 'PK'])),
              _buildSettingItem(Icons.group, '$_selectedSeats Seats', () => _showSelectionSheet('Seats', ['4', '8', '12', '15'])),
              _buildSettingItem(Icons.palette, _selectedTheme, () => _showSelectionSheet('Theme', ['Purple', 'Blue', 'Gold', 'Romantic', 'Cyber'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [Icon(icon, color: Colors.white54, size: 12), const SizedBox(width: 3), Text(text, style: const TextStyle(color: Colors.white, fontSize: 11))]),
      ),
    );
  }

  void _showSelectionSheet(String title, List<String> options) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Color(0xFF1A1A1A), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Select $title', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ...options.map((option) => ListTile(
              title: Text(option, style: const TextStyle(color: Colors.white70)),
              onTap: () {
                setState(() {
                  if (title == 'Category') _selectedCategory = option;
                  if (title == 'Seats') _selectedSeats = int.parse(option);
                  if (title == 'Theme') _selectedTheme = option.toLowerCase();
                });
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ['Video', 'Audio', 'Game'].map((mode) {
        final isSelected = _activeMode == mode;
        return GestureDetector(
          onTap: () {
            debugPrint('[DEBUG_UI] 🔘 Mode Button Tapped: $mode');
            setState(() => _activeMode = mode);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(mode, style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ),
        );
      }).toList(),
    );
  }
}