import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/ip_location_service.dart';
import 'basic_info_screen.dart';

class CountrySelectionScreen extends StatefulWidget {
  const CountrySelectionScreen({super.key});

  @override
  State<CountrySelectionScreen> createState() => _CountrySelectionScreenState();
}

class _CountrySelectionScreenState extends State<CountrySelectionScreen> {
  String? _selectedCountry;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, String>> _countries = [
    {'flag': '🇱🇰', 'name': 'Sri Lanka'},
    {'flag': '🇮🇳', 'name': 'India'},
    {'flag': '🇵🇰', 'name': 'Pakistan'},
    {'flag': '🇧🇩', 'name': 'Bangladesh'},
    {'flag': '🇵🇭', 'name': 'Philippines'},
    {'flag': '🇻🇳', 'name': 'Vietnam'},
    {'flag': '🇮🇩', 'name': 'Indonesia'},
    {'flag': '🇹🇭', 'name': 'Thailand'},
    {'flag': '🇲🇾', 'name': 'Malaysia'},
    {'flag': '🇸🇬', 'name': 'Singapore'},
    {'flag': '🇦🇪', 'name': 'UAE'},
    {'flag': '🇸🇦', 'name': 'Saudi Arabia'},
    {'flag': '🇹🇷', 'name': 'Turkey'},
    {'flag': '🇪🇬', 'name': 'Egypt'},
    {'flag': '🇳🇬', 'name': 'Nigeria'},
    {'flag': '🇿🇦', 'name': 'South Africa'},
    {'flag': '🇺🇸', 'name': 'United States'},
    {'flag': '🇬🇧', 'name': 'United Kingdom'},
    {'flag': '🇨🇦', 'name': 'Canada'},
    {'flag': '🇦🇺', 'name': 'Australia'},
    {'flag': '🇧🇷', 'name': 'Brazil'},
    {'flag': '🇲🇽', 'name': 'Mexico'},
    {'flag': '🇨🇴', 'name': 'Colombia'},
    {'flag': '🇻🇪', 'name': 'Venezuela'},
    {'flag': '🇯🇵', 'name': 'Japan'},
    {'flag': '🇰🇷', 'name': 'South Korea'},
    {'flag': '🇨🇳', 'name': 'China'},
  ];

  @override
  void initState() {
    super.initState();
    _detectCountry();
  }

  Future<void> _detectCountry() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    // Try phone number first
    if (currentUser?.phoneNumber != null) {
      final countryDetails = IpLocationService.getCountryFromPrefix(currentUser!.phoneNumber!);
      if (countryDetails != null) {
        setState(() {
          _selectedCountry = countryDetails['name'];
          _isLoading = false;
        });
        
        // Auto-confirm if detected from phone (per client request to remove manual step)
        _confirmCountry();
        return;
      }
    }

    // Fallback to IP detection
    final countryDetails = await IpLocationService.detectCountryDetails();
    final countryName = countryDetails['name'];

    setState(() {
      if (countryName != null && countryName != 'Unknown') {
        _selectedCountry = countryName;
      }
      _isLoading = false;
    });

    // Auto-confirm if detected successfully from IP
    if (_selectedCountry != null) {
      _confirmCountry();
    }
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
            child: _isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Detecting your location...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            )
                : Column(
              children: [
                SizedBox(height: 40),
                Text(
                  'Select Your Country',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'You can change if detection is wrong',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 30),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _countries.length,
                    itemBuilder: (context, index) {
                      final country = _countries[index];
                      final isSelected = _selectedCountry == country['name'];

                      return Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCountry = country['name'];
                            });
                          },
                          child: Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: isSelected
                                    ? Color(0xFF9B6FD7)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 20),
                                Text(
                                  country['flag']!,
                                  style: TextStyle(fontSize: 32),
                                ),
                                SizedBox(width: 20),
                                Text(
                                  country['name']!,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Color(0xFF9B6FD7)
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '⚠️ Cannot be modified after confirmation',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _selectedCountry == null || _isSaving
                              ? null
                              : _confirmCountry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: _isSaving
                              ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCountry() async {
    if (_selectedCountry == null) return;

    setState(() => _isSaving = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'country': _selectedCountry}, SetOptions(merge: true));

      

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BasicInfoScreen()),
      );
    } catch (e) {
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => _isSaving = false);
    }
  }
}