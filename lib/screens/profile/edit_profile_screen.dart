import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../utils/country_utils.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            
            // 1. My Avatar Section
            _buildSectionContainer([
              _buildAvatarRow(user),
            ]),

            const SizedBox(height: 12),

            // 2. Primary Attributes Section
            _buildSectionContainer([
              _buildInfoRow('ID', user.id ?? user.uid, isCopyable: true),
              _buildDivider(),
              _buildInfoRow('Nickname', user.displayName, hasArrow: true, onTap: () => _editNickname(user)),
              _buildDivider(),
              _buildInfoRow('Gender', (user.gender != null && user.gender!.isNotEmpty) 
                  ? '${user.gender![0].toUpperCase()}${user.gender!.substring(1)}' 
                  : 'Select', isEditable: false),
              _buildDivider(),
              _buildInfoRow('Age', '${user.age ?? 'Select'}', hasArrow: true, onTap: () => _editBirthday(user)),
              _buildDivider(),
              _buildInfoRow('Regions', user.country ?? 'Select', hasArrow: true, trailingWidget: Text(user.countryFlag, style: const TextStyle(fontSize: 18)), onTap: () => _editRegion(user)),
              _buildDivider(),
              _buildInfoRow('Location', user.city ?? 'Hidden', hasArrow: true, onTap: () => _editLocation(user)),
              _buildDivider(),
              _buildInfoRow('Language', user.language ?? 'Select', hasArrow: true, onTap: () => _editLanguage(user)),
              _buildDivider(),
              _buildInfoRow('Second Language', user.secondLanguage ?? 'Select', hasArrow: true, onTap: () => _editSecondLanguage(user)),
              _buildDivider(),
              _buildInfoRow('Tags', user.interests.isEmpty ? 'Select' : user.interests.join(', '), hasArrow: true, onTap: () => _editTags(user)),
              _buildDivider(),
              _buildInfoRow('Self-introduction', user.bio?.isNotEmpty == true ? 'Edit' : 'Select', hasArrow: true, onTap: () => _editBio(user)),
              _buildDivider(),
              _buildInfoRow('Cosmetics', user.isVip == true ? 'VIP Frame' : 'Select', hasArrow: true, trailingWidget: _buildCosmeticIcon(), onTap: () => _editCosmetics(user)),
            ]),

            const SizedBox(height: 12),

            // 3. Account Binding Section
            _buildSectionContainer([
              _buildInfoRow('Google', user.name, hasArrow: true, isEditable: false),
              _buildDivider(),
              _buildInfoRow('Phone', user.phoneNumber ?? 'Not bound', hasArrow: true, onTap: () => _bindPhone(user)),
              _buildDivider(),
              _buildInfoRow('Gmail', user.email, hasArrow: true, isEditable: false),
              _buildDivider(),
              _buildInfoRow('Password', 'Reset', hasArrow: true, onTap: () => _resetPassword(user)),
            ]),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildAvatarRow(UserModel user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'My Avatar',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
          GestureDetector(
            onTap: () => _updateAvatar(user),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey.shade100,
                  backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                  child: user.photoURL == null ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black26, size: 14),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {
    bool hasArrow = false,
    bool isCopyable = false,
    bool isEditable = true,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: isEditable ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
            const Spacer(),
            if (trailingWidget != null) ...[
              trailingWidget,
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: isEditable ? (value == 'Select' || value == 'Reset' ? Colors.black26 : Colors.black45) : Colors.black26,
                  fontWeight: (value == 'Reset') ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isCopyable) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID copied to clipboard')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    'Copy',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ),
            ],
            if (hasArrow) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black26, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      height: 0.5,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildCosmeticIcon() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
    );
  }

  // --- Edit Logic ---

  Future<void> _updateAvatar(UserModel user) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text('Photo Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(user, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.purple),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(user, ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(UserModel user, ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      if (!mounted) return;
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.purple),
            ),
          ),
        ),
      );

      final File file = File(pickedFile.path);
      final String? downloadUrl = await _databaseService.uploadProfileImage(user.uid, file);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (downloadUrl != null) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        
        // Fix: Update both photoURL and the first item in photos list to keep UI in sync
        final List<String> updatedPhotos = List<String>.from(user.photos);
        if (updatedPhotos.isEmpty) {
          updatedPhotos.add(downloadUrl);
        } else {
          updatedPhotos[0] = downloadUrl;
        }

        final success = await userProvider.updateUser({
          'photoURL': downloadUrl,
          'photos': updatedPhotos,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Avatar updated successfully!' : 'Failed to update user profile'),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context); // Close loading if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _editNickname(UserModel user) {
    _showEditDialog('Edit Nickname', user.name, (val) async {
       if (val.length < 3) return 'Nickname too short';
       await _databaseService.updateUser(user.uid, {'name': val});
       return null;
    });
  }

  Future<void> _editBirthday(UserModel user) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: user.birthday ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.purple),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final age = UserModel.calculateAge(picked);
      await _databaseService.updateUser(user.uid, {
        'birthday': picked.toIso8601String(),
        'age': age,
      });
    }
  }

  void _editRegion(UserModel user) {
    final allCountries = CountryUtils.allCountries;
    final icons = CountryUtils.countryFlags;

    _showPickerModal(
      'Select Region',
      allCountries,
      icons: icons,
      currentValue: user.country,
      onSelect: (val) async {
        await _databaseService.updateUser(user.uid, {'country': val});
      },
    );
  }

  void _editLanguage(UserModel user) {
    final allLanguages = List<String>.from(CountryUtils.allLanguages)..sort();
    _showPickerModal('Primary Language', allLanguages, currentValue: user.language, onSelect: (val) async {
      await _databaseService.updateUser(user.uid, {'language': val});
    });
  }

  void _editSecondLanguage(UserModel user) {
    final allLanguages = ['None'] + (List<String>.from(CountryUtils.allLanguages)..sort());
    _showPickerModal('Second Language', allLanguages, currentValue: user.secondLanguage ?? 'None', onSelect: (val) async {
      await _databaseService.updateUser(user.uid, {'secondLanguage': val == 'None' ? null : val});
    });
  }

  void _editLocation(UserModel user) {
    _showEditDialog('Edit City', user.city ?? '', (val) async {
      await _databaseService.updateUser(user.uid, {'city': val});
      return null;
    });
  }

  void _editCosmetics(UserModel user) {
    final cosmetics = ['None', 'VIP Frame', 'Glow Active'];
    _showPickerModal('Profile Cosmetics', cosmetics, currentValue: user.isVip == true ? 'VIP Frame' : 'None', onSelect: (val) async {
      await _databaseService.updateUser(user.uid, {
        'isVip': val != 'None',
      });
    });
  }

  void _editBio(UserModel user) {
    _showEditDialog('Self-introduction', user.bio ?? '', (val) async {
      await _databaseService.updateUser(user.uid, {'bio': val});
      return null;
    }, maxLines: 5);
  }

  void _editTags(UserModel user) {
    final availableInterests = ['Music', 'Travel', 'Sports', 'Gaming', 'Food', 'Movies', 'Dancing', 'Pets'];
    _showMultiSelectModal('Select Tags', availableInterests, user.interests, (selected) async {
      await _databaseService.updateUser(user.uid, {'interests': selected});
    });
  }

  Future<void> _resetPassword(UserModel user) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Password Reset'),
            content: Text('A password reset link has been sent to ${user.email}. Please check your inbox.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _bindPhone(UserModel user) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phone binding logic would navigate to SMS verification')),
    );
  }

  // --- UI Helpers ---

  void _showEditDialog(String title, String initialValue, Future<String?> Function(String) onSave, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter your $title',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final error = await onSave(controller.text.trim());
              if (error == null) {
                if (mounted) Navigator.pop(context);
              } else {
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPickerModal(
    String title,
    List<String> options, {
    Map<String, String>? icons,
    String? currentValue,
    required Function(String) onSelect,
  }) {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredOptions = options
              .where((o) => o.toLowerCase().contains(searchQuery.toLowerCase()))
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // 🔍 Search Bar
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setModalState(() => searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredOptions.length,
                    itemBuilder: (context, index) {
                      final option = filteredOptions[index];
                      return ListTile(
                        leading: icons != null
                            ? Text(icons[option]!, style: const TextStyle(fontSize: 24))
                            : null,
                        title: Text(option),
                        trailing: option == currentValue
                            ? const Icon(Icons.check, color: Colors.purple)
                            : null,
                        onTap: () {
                          onSelect(option);
                          Navigator.pop(context);
                        },
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

  void _showMultiSelectModal(String title, List<String> options, List<String> currentValues, Function(List<String>) onSave) {
    List<String> tempSelected = List.from(currentValues);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      onSave(tempSelected);
                      Navigator.pop(context);
                    },
                    child: const Text('Done', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: options.map((option) {
                  final isSelected = tempSelected.contains(option);
                  return FilterChip(
                    label: Text(option),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        if (selected) {
                          tempSelected.add(option);
                        } else {
                          tempSelected.remove(option);
                        }
                      });
                    },
                    selectedColor: Colors.purple.withOpacity(0.2),
                    checkmarkColor: Colors.purple,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
