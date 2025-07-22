import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _formData = {};
  final Map<String, String?> _fieldErrors = {
    'username': null,
    'email_id': null,
    'phone_number': null,
  };

  bool _showPassword = false;

  final RegExp _nameRegex = RegExp(r'^[a-zA-Z]+$', unicode: true);
  final RegExp _phoneRegex = RegExp(r'^[0-9]+$');
  final RegExp _emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
  final TextEditingController _passwordController = TextEditingController();
  String _password = '';

  Future<void> _submitForm() async {
    setState(() => _fieldErrors.updateAll((key, value) => null));

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final response = await http.post(
        Uri.parse('$baseUrl/add_user'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(_formData),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User added successfully!')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else if (response.statusCode == 409) {
        final res = jsonDecode(response.body);
        setState(() => _fieldErrors[res['field']] = res['error']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add user.')),
        );
      }
    }
  }

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
        errorText: _fieldErrors[key],
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

  Widget _buildPasswordRule(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            met ? Icons.check_circle : Icons.info_outline,
            color: met ? Colors.green : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildValidatedField(
                  label: 'First Name',
                  key: 'first_name',
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (!_nameRegex.hasMatch(value)) return 'Only letters allowed';
                    return null;
                  },
                ),
                _buildValidatedField(
                  label: 'Middle Name (optional)',
                  key: 'middle_name',
                  validator: (_) => null,
                ),
                _buildValidatedField(
                  label: 'Last Name',
                  key: 'last_name',
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (!_nameRegex.hasMatch(value)) return 'Only letters allowed';
                    return null;
                  },
                ),
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
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  onChanged: (value) => setState(() => _password = value),
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
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
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
                      _buildPasswordRule('Minimum number of characters: 8', _password.length >= 8),
                      _buildPasswordRule('Minimum number of uppercase characters: 1', RegExp(r'[A-Z]').hasMatch(_password)),
                      _buildPasswordRule('Minimum number of numeric characters: 1', RegExp(r'[0-9]').hasMatch(_password)),
                      _buildPasswordRule('Minimum number of special characters: 1', RegExp(r'[!@#\$&*~]').hasMatch(_password)),
                    ],
                  ),
                ),
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
                      backgroundColor: Color(0xFFFF6D00),
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
    );
  }
}
