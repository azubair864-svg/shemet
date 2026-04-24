import 'package:flutter/material.dart';

class AppLanguageScreen extends StatefulWidget {
  const AppLanguageScreen({super.key});

  @override
  State<AppLanguageScreen> createState() => _AppLanguageScreenState();
}

class _AppLanguageScreenState extends State<AppLanguageScreen> {
  String _selectedLanguage = 'Automatic';

  final List<Map<String, String>> _languages = [
    {'name': 'Automatic', 'code': 'auto'},
    {'name': 'English(English)', 'code': 'en'},
    {'name': 'Hindi(हिन्दी)', 'code': 'hi'},
    {'name': 'Urdu(اردو)', 'code': 'ur'},
    {'name': 'Arabic(اللغة العربية)', 'code': 'ar'},
    {'name': 'Spanish(español)', 'code': 'es'},
    {'name': 'Portuguese(Português)', 'code': 'pt'},
    {'name': 'Bengali(বাংলা)', 'code': 'bn'},
    {'name': 'French(Français)', 'code': 'fr'},
    {'name': 'Russian(Русский)', 'code': 'ru'},
    {'name': 'Indonesian(bahasa Indonesia)', 'code': 'id'},
    {'name': 'Vietnamese(Tiếng Việt)', 'code': 'vi'},
    {'name': 'Thai(ภาษาไทย)', 'code': 'th'},
    {'name': 'Chinese Traditional(繁體中文)', 'code': 'zh-TW'},
    {'name': 'Chinese Simplified(简体中文)', 'code': 'zh-CN'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'App Language',
          style: TextStyle(
            color: Color(0xFF2D1B69),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.content_copy, color: Colors.grey.shade400),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final language = _languages[index];
          final isSelected = _selectedLanguage == language['name'];

          return ListTile(
            title: Text(
              language['name']!,
              style: TextStyle(
                fontSize: 16,
                color: isSelected ? const Color(0xFF9B6FD7) : Colors.black87,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Color(0xFF9B6FD7))
                : null,
            onTap: () {
              setState(() {
                _selectedLanguage = language['name']!;
              });
            },
          );
        },
      ),
    );
  }
}
