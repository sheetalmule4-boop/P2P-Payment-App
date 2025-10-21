import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'dart:io';

/// UserFormScreen provides a comprehensive user registration form
/// with validation, password strength indicators, and error handling
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  
  // Map to store form data for API submission
  final Map<String, String> _formData = {};
  
  // Map to store server-side validation errors for specific fields
  final Map<String, String?> _fieldErrors = {
    'username': null,
    'email_id': null,
    'phone_number': null,
  };

  // Toggle for password visibility
  bool _showPassword = false;

  // Regular expressions for input validation
  final RegExp _nameRegex = RegExp(r'^[a-zA-Z]+$', unicode: true); // Only letters
  final RegExp _phoneRegex = RegExp(r'^[0-9]+$'); // Only numbers
  final RegExp _emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$'); // Email format
  
  // Password controller and state for real-time validation display
  final TextEditingController _passwordController = TextEditingController();
  String _password = '';

  /// Submits the form data to the server after validation
  /// Handles success, conflict (409), and error responses
  Future<void> _submitForm() async {
    // Clear previous field errors
    setState(() => _fieldErrors.updateAll((key, value) => null));

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Send POST request to add user endpoint
      final response = await http.post(
        Uri.parse('$baseUrl/add_user'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(_formData),
      );

      if (response.statusCode == 201) {
        // Success - user created successfully
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User added successfully!')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else if (response.statusCode == 409) {
        // Conflict - field already exists (username/email/phone taken)
        final res = jsonDecode(response.body);
        setState(() => _fieldErrors[res['field']] = res['error']);
      } else {
        // Other errors
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add user.')),
        );
      }
    }
  }

  /// Builds a validated text form field with consistent styling
  /// Includes server-side error display and custom validation
  Widget _buildValidatedField({
    required String label,
    required String key,
    required String? Function(String?) validator,
    bool obscure = false,
  }) {
    return TextFormField(
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        errorText: _fieldErrors[key], // Display server-side errors
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.brown),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.deepOrange, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.brown),
      ),
      obscureText: obscure,
      validator: validator,
      onSaved: (value) => _formData[key] = value!.trim(),
    );
  }

  /// Builds individual password requirement indicator
  /// Shows check icon when requirement is met, info icon when not
  Widget _buildPasswordRule(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic icon based on requirement status
          Icon(
            met ? Icons.check_circle : Icons.info_outline,
            color: met ? Colors.green : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
          // Requirement text with dynamic color
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: met ? Colors.green : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // App bar with registration title
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'User Registration',
          style: TextStyle(
            color: Colors.deepOrange,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            // Platform-specific width for better desktop experience
            width: Platform.isMacOS ? 500 : double.infinity,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // First Name field - required, letters only
                    _buildValidatedField(
                      label: 'First Name',
                      key: 'first_name',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (!_nameRegex.hasMatch(value)) return 'Only characters allowed';
                        return null;
                      },
                    ),
                    // Middle Name field - optional
                    _buildValidatedField(
                      label: 'Middle Name (optional)',
                      key: 'middle_name',
                      validator: (_) => null,
                    ),
                    // Last Name field - required, letters only
                    _buildValidatedField(
                      label: 'Last Name',
                      key: 'last_name',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (!_nameRegex.hasMatch(value)) return 'Only characters allowed';
                        return null;
                      },
                    ),
                    // Phone Number field - required, exactly 10 digits
                    _buildValidatedField(
                      label: 'Phone Number',
                      key: 'phone_number',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (!_phoneRegex.hasMatch(value)) return 'Only numbers allowed';
                        if (value.length != 10) return 'Phone number must be exactly 10 digits';
                        return null;
                      },
                    ),
                    // Email field - required, valid email format
                    _buildValidatedField(
                      label: 'Email ID',
                      key: 'email_id',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (!_emailRegex.hasMatch(value)) return 'Invalid email format';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Password field with visibility toggle and real-time validation
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      onChanged: (value) => setState(() => _password = value), // Update state for real-time validation
                      decoration: InputDecoration(
                        labelText: 'Password',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.brown),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.deepOrange, width: 2),
                        ),
                        labelStyle: const TextStyle(color: Colors.brown),
                        // Toggle password visibility
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      // Comprehensive password validation
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (value.length < 8) return 'Must be at least 8 characters';
                        if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Include a uppercase letter';
                        if (!RegExp(r'[0-9]').hasMatch(value)) return 'Include a number';
                        if (!RegExp(r'[!@#\$&*~]').hasMatch(value)) return 'Include a special character';
                        return null;
                      },
                      onSaved: (value) => _formData['password'] = value!.trim(),
                    ),
                    const SizedBox(height: 10),
                    // Password requirements indicator box
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Real-time password requirement indicators
                          _buildPasswordRule('Minimum number of characters: 8', _password.length >= 8),
                          _buildPasswordRule('Minimum number of uppercase characters: 1', RegExp(r'[A-Z]').hasMatch(_password)),
                          _buildPasswordRule('Minimum number of numeric characters: 1', RegExp(r'[0-9]').hasMatch(_password)),
                          _buildPasswordRule('Minimum number of special characters: 1', RegExp(r'[!@#\$&*~]').hasMatch(_password)),
                        ],
                      ),
                    ),
                    // Username field - required, no spaces allowed
                    _buildValidatedField(
                      label: 'Username',
                      key: 'username',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (value.contains(' ')) return 'Username cannot contain spaces';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Submit button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _submitForm,
                        icon: const Icon(Icons.person_add, color: Colors.white),
                        label: const Text(
                          'Add User',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6D00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}