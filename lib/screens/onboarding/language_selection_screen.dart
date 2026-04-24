import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'basic_info_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selectedLanguage;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _languages = [
    // Most spoken languages
    {'name': 'English', 'icon': '🇬🇧'},
    {'name': 'Chinese', 'icon': '🇨🇳'},
    {'name': 'Hindi', 'icon': '🇮🇳'},
    {'name': 'Spanish', 'icon': '🇪🇸'},
    {'name': 'French', 'icon': '🇫🇷'},
    {'name': 'Arabic', 'icon': '🇸🇦'},
    {'name': 'Bengali', 'icon': '🇧🇩'},
    {'name': 'Russian', 'icon': '🇷🇺'},
    {'name': 'Portuguese', 'icon': '🇵🇹'},
    {'name': 'Urdu', 'icon': '🇵🇰'},

    // Asian languages
    {'name': 'Indonesian', 'icon': '🇮🇩'},
    {'name': 'Japanese', 'icon': '🇯🇵'},
    {'name': 'Korean', 'icon': '🇰🇷'},
    {'name': 'Vietnamese', 'icon': '🇻🇳'},
    {'name': 'Telugu', 'icon': '🇮🇳'},
    {'name': 'Marathi', 'icon': '🇮🇳'},
    {'name': 'Tamil', 'icon': '🇮🇳'},
    {'name': 'Turkish', 'icon': '🇹🇷'},
    {'name': 'Persian', 'icon': '🇮🇷'},
    {'name': 'Thai', 'icon': '🇹🇭'},
    {'name': 'Burmese', 'icon': '🇲🇲'},
    {'name': 'Khmer', 'icon': '🇰🇭'},
    {'name': 'Lao', 'icon': '🇱🇦'},
    {'name': 'Tagalog', 'icon': '🇵🇭'},
    {'name': 'Malay', 'icon': '🇲🇾'},
    {'name': 'Sinhala', 'icon': '🇱🇰'},

    // European languages
    {'name': 'German', 'icon': '🇩🇪'},
    {'name': 'Italian', 'icon': '🇮🇹'},
    {'name': 'Polish', 'icon': '🇵🇱'},
    {'name': 'Ukrainian', 'icon': '🇺🇦'},
    {'name': 'Dutch', 'icon': '🇳🇱'},
    {'name': 'Greek', 'icon': '🇬🇷'},
    {'name': 'Czech', 'icon': '🇨🇿'},
    {'name': 'Swedish', 'icon': '🇸🇪'},
    {'name': 'Romanian', 'icon': '🇷🇴'},
    {'name': 'Hungarian', 'icon': '🇭🇺'},
    {'name': 'Serbian', 'icon': '🇷🇸'},
    {'name': 'Bulgarian', 'icon': '🇧🇬'},
    {'name': 'Danish', 'icon': '🇩🇰'},
    {'name': 'Finnish', 'icon': '🇫🇮'},
    {'name': 'Norwegian', 'icon': '🇳🇴'},

    // African languages
    {'name': 'Swahili', 'icon': '🇰🇪'},
    {'name': 'Amharic', 'icon': '🇪🇹'},
    {'name': 'Yoruba', 'icon': '🇳🇬'},
    {'name': 'Hausa', 'icon': '🇳🇬'},
    {'name': 'Zulu', 'icon': '🇿🇦'},
    {'name': 'Somali', 'icon': '🇸🇴'},

    // Americas
    {'name': 'Portuguese (Brazil)', 'icon': '🇧🇷'},
    {'name': 'Quechua', 'icon': '🇵🇪'},

    // Middle East
    {'name': 'Hebrew', 'icon': '🇮🇱'},
    {'name': 'Kurdish', 'icon': '🇮🇶'},

    // Others
    {'name': 'Other', 'icon': '🌐'},
  ];

  @override
  void initState() {
    super.initState();
    
    
    
    
  }

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
            child: Column(
              children: [
                SizedBox(height: 40),
                Text(
                  'My Language',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Select your most spoken native language',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 30),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _languages.length,
                    itemBuilder: (context, index) {
                      final lang = _languages[index];
                      bool isSelected = _selectedLanguage == lang['name'];
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: _buildLanguageCard(
                          lang['name'],
                          lang['icon'],
                          isSelected,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selectedLanguage == null || _isLoading
                          ? null
                          : _confirmLanguage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF9B6FD7),
                        ),
                      )
                          : Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9B6FD7),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard(String language, String icon, bool isSelected) {
    return GestureDetector(
      onTap: () {
        
        setState(() => _selectedLanguage = language);
        
      },
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Color(0xFF9B6FD7) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 20),
            Text(
              icon,
              style: TextStyle(fontSize: 32),
            ),
            SizedBox(width: 20),
            Text(
              language,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isSelected ? Color(0xFF9B6FD7) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLanguage() async {
    
    

    if (_selectedLanguage == null) {
      
      return;
    }

    setState(() => _isLoading = true);
    

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        
        throw Exception('No user ID found');
      }

      
      

      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'language': _selectedLanguage,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      

      // Verify update
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      

      await Future.delayed(Duration(milliseconds: 100));

      if (!mounted) {
        
        return;
      }

      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BasicInfoScreen()),
      );

      
    } catch (e) {
      
      
      
      

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    
    
    super.dispose();
  }
}