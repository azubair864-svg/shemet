import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';

import 'user_search_screen.dart';
import 'rankings_screen.dart';
import '../../widgets/common/random_chat_popup.dart';
import '../calls/random_call_screen.dart';
import 'host_live_preview_screen.dart';
import '../profile/user_profile_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with TickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  late TabController _tabController;
  int _currentTab = 1;

  // Filter states
  String _selectedCountry = 'All';
  String _selectedLanguage = 'All';
  final String _selectedGender = 'Female';
  final double _minAge = 18;
  final double _maxAge = 100;

  List<UserModel> _users = [];
  bool _isLoading = true;
  UserModel? _currentUser;
  StreamSubscription<List<UserModel>>? _usersSubscription;
  
  // Animation for LIVE pulse
  late AnimationController _pulseController;

  final List<String> _languages = [
    'All', 'English', 'Sinhala', 'Tamil', 'Hindi', 'Arabic', 'Spanish', 'French', 'German', 'Chinese', 'Japanese', 'Korean', 'Russian', 'Portuguese', 'Bengali', 'Punjabi', 'Telugu', 'Marathi', 'Vietnamese', 'Urdu', 'Turkish', 'Italian', 'Thai', 'Gujarati', 'Farsi', 'Polish', 'Pashto', 'Kannada', 'Malayalam', 'Sundanese', 'Hausa', 'Oriya', 'Burmese', 'Hakka', 'Ukrainian', 'Bhojpuri', 'Tagalog', 'Yoruba', 'Maithili', 'Uzbek', 'Sindhi', 'Amharic', 'Fula', 'Romanian', 'Oromo', 'Igbo', 'Azerbaijani', 'Dutch', 'Kurdish', 'Nepali', 'Khmer', 'Somali'
  ];

  final List<String> _countries = [
    'All', 'Afghanistan', 'Albania', 'Algeria', 'American Samoa', 'Andorra', 'Angola', 'Anguilla', 'Antigua and Barbuda', 'Argentina', 'Armenia', 'Aruba', 'Australia', 'Austria', 'Azerbaijan',
    'Bahamas', 'Bahrain', 'Bangladesh', 'Barbados', 'Belarus', 'Belgium', 'Belize', 'Benin', 'Bermuda', 'Bhutan', 'Bolivia', 'Bosnia and Herzegovina', 'Botswana', 'Brazil', 'British Virgin Islands', 'Brunei', 'Bulgaria', 'Burkina Faso', 'Burundi',
    'Cabo Verde', 'Cambodia', 'Cameroon', 'Canada', 'Cayman Islands', 'Central African Republic', 'Chad', 'Chile', 'China', 'Colombia', 'Comoros', 'Congo', 'Cook Islands', 'Costa Rica', 'Croatia', 'Cuba', 'Curaçao', 'Cyprus', 'Czech Republic',
    'Denmark', 'Djibouti', 'Dominica', 'Dominican Republic', 'Ecuador', 'Egypt', 'El Salvador', 'Equatorial Guinea', 'Eritrea', 'Estonia', 'Eswatini', 'Ethiopia',
    'Falkland Islands', 'Faroe Islands', 'Fiji', 'Finland', 'France', 'French Guiana', 'French Polynesia', 'Gabon', 'Gambia', 'Georgia', 'Germany', 'Ghana', 'Gibraltar', 'Greece', 'Greenland', 'Grenada', 'Guadeloupe', 'Guam', 'Guatemala', 'Guernsey', 'Guinea', 'Guinea-Bissau', 'Guyana',
    'Haiti', 'Honduras', 'Hong Kong', 'Hungary', 'Iceland', 'India', 'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Isle of Man', 'Israel', 'Italy', 'Ivory Coast',
    'Jamaica', 'Japan', 'Jersey', 'Jordan', 'Kazakhstan', 'Kenya', 'Kiribati', 'Kosovo', 'Kuwait', 'Kyrgyzstan',
    'Laos', 'Latvia', 'Lebanon', 'Lesotho', 'Liberia', 'Libya', 'Liechtenstein', 'Lithuania', 'Luxembourg',
    'Macau', 'Madagascar', 'Malawi', 'Malaysia', 'Maldives', 'Mali', 'Malta', 'Marshall Islands', 'Martinique', 'Mauritania', 'Mauritius', 'Mayotte', 'Mexico', 'Micronesia', 'Moldova', 'Monaco', 'Mongolia', 'Montenegro', 'Montserrat', 'Morocco', 'Mozambique', 'Myanmar',
    'Namibia', 'Nauru', 'Nepal', 'Netherlands', 'New Caledonia', 'New Zealand', 'Nicaragua', 'Niger', 'Nigeria', 'Niue', 'North Korea', 'North Macedonia', 'Northern Mariana Islands', 'Norway',
    'Oman', 'Pakistan', 'Palau', 'Palestine', 'Panama', 'Papua New Guinea', 'Paraguay', 'Peru', 'Philippines', 'Poland', 'Portugal', 'Puerto Rico',
    'Qatar', 'Réunion', 'Romania', 'Russia', 'Rwanda', 'Saint Barthélemy', 'Saint Helena', 'Saint Kitts and Nevis', 'Saint Lucia', 'Saint Martin', 'Saint Pierre and Miquelon', 'Saint Vincent and the Grenadines', 'Samoa', 'San Marino', 'Sao Tome and Principe', 'Saudi Arabia', 'Senegal', 'Serbia', 'Seychelles', 'Sierra Leone', 'Singapore', 'Sint Maarten', 'Slovakia', 'Slovenia', 'Solomon Islands', 'Somalia', 'South Africa', 'South Korea', 'South Sudan', 'Spain', 'Sri Lanka', 'Sudan', 'Suriname', 'Svalbard and Jan Mayen', 'Sweden', 'Switzerland', 'Syria',
    'Taiwan', 'Tajikistan', 'Tanzania', 'Thailand', 'Timor-Leste', 'Togo', 'Tokelau', 'Tonga', 'Trinidad and Tobago', 'Tunisia', 'Turkey', 'Turkmenistan', 'Turks and Caicos Islands', 'Tuvalu',
    'U.S. Virgin Islands', 'Uganda', 'Ukraine', 'United Arab Emirates', 'United Kingdom', 'United States', 'Uruguay', 'Uzbekistan', 'Vanuatu', 'Vatican City', 'Venezuela', 'Vietnam', 'Wallis and Futuna', 'Western Sahara', 'Yemen', 'Zambia', 'Zimbabwe'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
        _loadUsers();
      }
    });
    _loadCurrentUser();
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    _usersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _databaseService.getUserById(_currentUserId);
      if (mounted) setState(() => _currentUser = user);
      final position = await LocationService.getCurrentPosition();
      if (position != null && mounted) {
        final geoPoint = GeoPoint(position.latitude, position.longitude);
        await _databaseService.updateUserLocation(_currentUserId, geoPoint);
      }
    } catch (e) {}
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      await _usersSubscription?.cancel();
      _usersSubscription = null;
      
      List<UserModel> users = [];
      
      if (_currentTab == 3) {
        // Friends - Fetch once
        users = await _databaseService.getFriendsOnce(_currentUserId);
      } else {
        final filterGender = _currentTab == 1 ? 'female' : (_selectedGender == 'All' ? null : _selectedGender);
        final filterIsLive = _currentTab == 1 ? true : null;

        users = await _databaseService.getDiscoverUsers(
          currentUserId: _currentUserId,
          currentUser: _currentUser,
          limit: 50,
          filterCountry: _selectedCountry == 'All' ? null : _selectedCountry,
          filterLanguage: _selectedLanguage == 'All' ? null : _selectedLanguage,
          filterGender: filterGender,
          filterIsLive: filterIsLive,
          minAge: _minAge.round(),
          maxAge: _maxAge.round(),
          maxDistance: _currentTab == 0 ? 100 : null, // 100km radius for Nearby
        );
      }

      if (mounted) {
        // Sorting for "Nearby" tab (Index 0) - Closest first
        if (_currentTab == 0 && _currentUser != null) {
          users.sort((a, b) {
            final dA = _currentUser!.distanceTo(a) ?? double.infinity;
            final dB = _currentUser!.distanceTo(b) ?? double.infinity;
            return dA.compareTo(dB);
          });
        }
        // Sorting for "New" tab (Index 2) - Newest first
        else if (_currentTab == 2) {
          users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
        
        setState(() { 
          _users = users; 
          _isLoading = false; 
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<UserModel> get _filteredUsers {
    return _users;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _buildContentGrid(),
          _buildTopBar(),
          _buildRandomChatFloatingButton(),
        ],
      ),
    );
  }

  Widget _buildContentGrid() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF1493)));
    final displayUsers = _filteredUsers;
    if (displayUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.white.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No users found', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 150, left: 12, right: 12, bottom: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: displayUsers.length,
      itemBuilder: (context, index) => _buildUserGridItem(displayUsers[index]),
    );
  }

  Widget _buildUserGridItem(UserModel user) {
    // 💡 QUALITY UI: Use higher resolution for grid thumbnails if available
    final photoUrl = user.photos.isNotEmpty ? user.photos[0] : 'https://ui-avatars.com/api/?name=${user.name}&background=random&color=fff';
    
    // Calculate distance if Nearby tab
    final distance = _currentTab == 0 && _currentUser != null 
        ? _currentUser!.distanceTo(user) 
        : null;

    return GestureDetector(
      onTap: () {
        if (_currentTab == 1) {
          // ✅ Discovery Tab: Keep existing Chamet-style live preview flow
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HostLivePreviewScreen(host: user),
            ),
          );
        } else {
          // ✅ Nearby, New, and Friends Tabs: Go directly to Profile
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileDetailScreen(user: user),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // 🖼️ SHARP PROFILE IMAGE
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.white10),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
              
              // 🌑 BOTTOM GRADIENT FOR CONTRAST
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.5, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // 🏷️ TOP ROW: LIVE or NEW Badge
              Positioned(
                top: 10,
                left: 10,
                child: Row(
                  children: [
                    if (user.isLive == true)
                      _buildLivePulseBadge()
                    else if (_isLoading == false && (user.createdAt.difference(DateTime.now()).inDays.abs()) < 3)
                      _buildNewBadge(),
                  ],
                ),
              ),

              // 🆔 BOTTOM ROW: Name, Location, Level, Flag
              Positioned(
                bottom: 12,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Name
                        Expanded(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.2,
                              shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Country Flag (Emoji fallback for simplicity)
                        Text(_getCountryEmoji(user.country), style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Level Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Lv.${user.level ?? 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Distance or Location
                        Expanded(
                          child: Text(
                            distance != null 
                              ? '${distance.toStringAsFixed(1)} km away' 
                              : (user.country ?? 'Discovery'),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 🔊 AUDIO INDICATOR (Optional visual fluff)
              if (user.isLive == true)
                Positioned(
                  bottom: 12,
                  right: 10,
                  child: Icon(Icons.equalizer, color: Colors.white.withOpacity(0.8), size: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivePulseBadge() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF1493).withOpacity(0.8 + (0.2 * _pulseController.value)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF1493).withOpacity(0.5 * _pulseController.value),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam, color: Colors.white, size: 12),
              const SizedBox(width: 4),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _getCountryEmoji(String? countryName) {
    if (countryName == null) return '🌍';
    // Simplified emoji mapping for demonstration
    final Map<String, String> flagMap = {
      'Sri Lanka': '🇱🇰', 'India': '🇮🇳', 'USA': '🇺🇸', 'United Kingdom': '🇬🇧', 
      'Canada': '🇨🇦', 'Australia': '🇦🇺', 'Japan': '🇯🇵', 'Korea': '🇰🇷',
      'Russia': '🇷🇺', 'China': '🇨🇳', 'Pakistan': '🇵🇰', 'Bangladesh': '🇧🇩',
    };
    return flagMap[countryName] ?? '🌍';
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Filters & Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Country Pill (Premium Selector)
                  Expanded(
                    flex: 2,
                    child: _buildSelectorPill(
                      label: _selectedCountry,
                      icon: Icons.public,
                      onTap: _showCountryPicker,
                    ),
                  ),
                  const SizedBox(width: 5),
                  // Language Pill
                  Expanded(
                    flex: 2,
                    child: _buildSelectorPill(
                      label: _selectedLanguage, 
                      icon: Icons.language,
                      onTap: _showLanguagePicker,
                    ),
                  ),
                  const SizedBox(width: 5),
                  // Search Button
                  _buildCircularActionButton(Icons.search, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UserSearchScreen()),
                    );
                  }),
                  const SizedBox(width: 5),
                  // Rank/Trophy Button
                  _buildCircularActionButton(Icons.emoji_events, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RankingsScreen()),
                    );
                  }, iconColor: Colors.amber),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Row 2: Unified Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.6),
                ),
                child: Row(
                  children: [
                    _buildCustomTabItem('Nearby', 0),
                    _buildCustomTabItem('Discovery', 1),
                    _buildCustomTabItem('New', 2),
                    _buildCustomTabItem('Friends', 3),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorPill({required String label, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  void _showCountryPicker() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredCountries = _countries.where((c) => c.toLowerCase().contains(searchQuery.toLowerCase())).toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: const Color(0xFF161616), // Solid performant background
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                // Handle
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                const Text('Select Country', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 20),
                // Search Bar (Forced Light Theme for Black Text)
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white, // Solid white for absolute clarity
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Theme(
                    data: ThemeData(primaryColor: Colors.black, textTheme: const TextTheme(displayMedium: TextStyle(color: Colors.black))),
                    child: TextField(
                      onChanged: (val) => setModalState(() => searchQuery = val),
                      style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold), // Black text
                      cursorColor: const Color(0xFFFF1493),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search, color: Color(0xFFFF1493), size: 22), // Pink icon for better visibility
                        hintText: 'Search any country...',
                        hintStyle: TextStyle(color: Colors.black45, fontSize: 15), // Darker hint
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Grid of countries (Optimized for speed)
                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3.2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = filteredCountries[index];
                      final bool isSelected = _selectedCountry == country;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedCountry = country);
                          _loadUsers();
                          Navigator.pop(context);
                        },
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFF1493) : Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.05), width: 0.8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  country,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Colors.white, size: 14),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showLanguagePicker() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredLanguages = _languages.where((l) => l.toLowerCase().contains(searchQuery.toLowerCase())).toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                // Handle
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                const Text('Select Language', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 20),
                // Search Bar (Forced Light Theme for Black Text)
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Theme(
                    data: ThemeData(primaryColor: Colors.black, textTheme: const TextTheme(displayMedium: TextStyle(color: Colors.black))),
                    child: TextField(
                      onChanged: (val) => setModalState(() => searchQuery = val),
                      style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                      cursorColor: const Color(0xFFFF1493),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search, color: Color(0xFFFF1493), size: 22),
                        hintText: 'Search language...',
                        hintStyle: TextStyle(color: Colors.black45, fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Grid of languages
                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3.2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredLanguages.length,
                    itemBuilder: (context, index) {
                      final language = filteredLanguages[index];
                      final bool isSelected = _selectedLanguage == language;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedLanguage = language);
                          _loadUsers();
                          Navigator.pop(context);
                        },
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFF1493) : Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.05), width: 0.8),
                          ),
                          child: Row(
                            children: [
                               Expanded(
                                child: Text(
                                  language,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Colors.white, size: 14),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCircularActionButton(IconData icon, VoidCallback onTap, {Color iconColor = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.6),
        ),
        child: Icon(icon, color: iconColor, size: 16),
      ),
    );
  }

  Widget _buildCustomTabItem(String title, int index) {
    final bool isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() => _currentTab = index);
          _loadUsers();
        },
        child: Container(
          margin: const EdgeInsets.all(3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF353535) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.65),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRandomChatFloatingButton() {
    // Only show if user has free cards or is a new user potential
    final freeCards = _currentUser?.freeTrialCards ?? 0;
    if (freeCards <= 0) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      top: MediaQuery.of(context).size.height * 0.45,
      child: GestureDetector(
        onTap: () {
          RandomChatPopup.show(
            context,
            freeCards: freeCards,
            onStartChat: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RandomCallScreen(
                    startSearchAutomatically: true,
                  ),
                ),
              );
            },
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF5FD3A6),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5FD3A6).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Random Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Free',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
