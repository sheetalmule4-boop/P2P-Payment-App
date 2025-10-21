import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'dart:io';

// Login Screen for the User Management App
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameOrEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;

  // Handles the login process, checking for empty fields and making the API call
  Future<void> _handleLogin() async {
    final userInput = _usernameOrEmailController.text.trim();
    final password = _passwordController.text.trim();

    if (userInput.isEmpty || password.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Missing Information'),
          content: Text(
            userInput.isEmpty && password.isEmpty
                ? 'Please enter username/email and password'
                : userInput.isEmpty
                    ? 'Please enter username or email'
                    : 'Please enter password',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('$baseUrl//login_user'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'user_input': userInput,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final res = jsonDecode(response.body);
      final userId = res['user_id'];

      if (userId != null && userId is int) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', userId);
        print("Saved user_id: $userId");
        Navigator.pushReplacementNamed(context, '/feed');
      } else {
        print('Login succeeded but user_id missing or invalid');
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Login Error"),
            content: const Text("Login successful, but user ID is missing."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } else {
      final res = jsonDecode(response.body);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Login Failed'),
          content: Text(res['error'] ?? 'Login failed'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // Handles the visibility toggle for the password field
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Image.asset(
                'assets/omni_logo.png',
                height: 90,
              ),
              const SizedBox(height: 8),
              const Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: Platform.isMacOS ? 400 : double.infinity,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: EdgeInsets.symmetric(horizontal: Platform.isMacOS ? 0 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _usernameOrEmailController,
                        style: TextStyle(fontSize: Platform.isMacOS ? 14 : 16),
                        decoration: const InputDecoration(labelText: 'Username or Email'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        style: TextStyle(fontSize: Platform.isMacOS ? 14 : 16),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6D00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                          ),
                          child: const Text('Log In'),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/register'),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: Color(0xFFEA1C7E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/reset');
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.grey,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
