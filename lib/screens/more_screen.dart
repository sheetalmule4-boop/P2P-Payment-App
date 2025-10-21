import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

/// MoreScreen for the User Management App - Account Settings page
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Current user's email and name information
  String? fullName = "Loading...";
  String? email = "";

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserInfo();
  }

  /// Initializes the screen animations
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  /// Loads current user's email and name from the API
  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      print('DEBUG: userId from SharedPreferences → $userId');

      if (userId != null) {
        final response = await http.get(Uri.parse('$baseUrl/user/$userId'));
        print('DEBUG: response.statusCode → ${response.statusCode}');
        print('DEBUG: response.body → ${response.body}');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            // Display current user's email and name
            fullName = '${data['first_name']} ${data['last_name']}';
            email = data['email_id'];
          });
        }
      }
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Sign out function - returns user to login screen
  void _handleLogout() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Logout',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        content: const Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Return to login screen and clear navigation stack
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6D00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildAnimatedBody(),
    );
  }

  /// Builds the app bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: true,
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: Colors.black,
      centerTitle: true,
      title: const Text(
        'Account Settings',
        style: TextStyle(
          color: Colors.deepOrange,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Builds the animated body content
  Widget _buildAnimatedBody() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildUserInfoCard(),
              const SizedBox(height: 32),
              _buildAccountSection(),
              const SizedBox(height: 24),
              _buildPreferencesSection(),
              const SizedBox(height: 24),
              _buildSupportSection(),
              const SizedBox(height: 40),
              _buildSignOutButton(),
              const SizedBox(height: 20),
              _buildVersionText(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the user info card containing current user's email and name
  Widget _buildUserInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.deepOrange.shade100,
            child: const Icon(Icons.person, size: 40, color: Colors.deepOrange),
          ),
          const SizedBox(height: 12),
          // Current user's name
          Text(
            fullName ?? '',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          // Current user's email
          Text(
            email ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the Account settings section
  Widget _buildAccountSection() {
    return _buildSettingsSection('Account', [
      _buildSettingsItem(
        Icons.person_outline,
        'Profile & Settings',
        'Manage your account details',
        Colors.blue,
        onTap: () {
          // TODO: Navigate to profile settings
        },
      ),
      _buildSettingsItem(
        Icons.security,
        'Security & Privacy',
        'PIN, biometrics, and privacy',
        Colors.green,
        onTap: () {
          // TODO: Navigate to security settings
        },
      ),
      _buildSettingsItem(
        Icons.credit_card,
        'Payment Methods',
        'Manage cards and bank accounts',
        Colors.purple,
        // Payment method takes you to the card_screen
        onTap: () => Navigator.pushNamed(context, '/card'),
      ),
    ]);
  }

  /// Builds the Preferences settings section
  Widget _buildPreferencesSection() {
    return _buildSettingsSection('Preferences', [
      _buildSettingsItem(
        Icons.notifications_outlined,
        'Notifications',
        'Manage notification preferences',
        Colors.orange,
        onTap: () {
          // TODO: Navigate to notification settings
        },
      ),
      _buildSettingsItem(
        Icons.palette_outlined,
        'Appearance',
        'Themes and display options',
        Colors.indigo,
        onTap: () {
          // TODO: Navigate to appearance settings
        },
      ),
      _buildSettingsItem(
        Icons.language,
        'Language & Region',
        'Change app language',
        Colors.teal,
        onTap: () {
          // TODO: Navigate to language settings
        },
      ),
    ]);
  }

  /// Builds the Support settings section
  Widget _buildSupportSection() {
    return _buildSettingsSection('Support', [
      _buildSettingsItem(
        Icons.help_outline,
        'Help & Support',
        'Get help with your account',
        Colors.amber,
        onTap: () {
          // TODO: Navigate to help & support
        },
      ),
      _buildSettingsItem(
        Icons.info_outline,
        'About',
        'App version and information',
        Colors.grey,
        onTap: () {
          // TODO: Navigate to about page
        },
      ),
    ]);
  }

  /// Builds the sign out button
  Widget _buildSignOutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFF6D00),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6D00).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        // Sign out function to return to login
        onPressed: _handleLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.logout, color: Colors.white, size: 24),
        label: const Text(
          'Sign Out',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Builds the version text
  Widget _buildVersionText() {
    return Text(
      'v1.0.0',
      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
    );
  }

  /// Builds a settings section with title and items
  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  /// Builds an individual settings item
  Widget _buildSettingsItem(
    IconData icon,
    String title,
    String subtitle,
    Color iconColor, {
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: () {
          HapticFeedback.lightImpact();
          if (onTap != null) onTap();
        },
      ),
    );
  }
}