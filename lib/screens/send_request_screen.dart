import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

/// SendRequestScreen allows users to search for other users and send requests
/// Features a search bar in the app bar and displays filtered user results
class SendRequestScreen extends StatefulWidget {
  const SendRequestScreen({super.key});

  @override
  State<SendRequestScreen> createState() => _SendRequestScreenState();
}

class _SendRequestScreenState extends State<SendRequestScreen> {
  // Controller for the username search input field
  final TextEditingController _searchController = TextEditingController();
  
  // List to store filtered user search results
  List<Map<String, String>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    // Add listener to search controller to trigger search on text changes
    _searchController.addListener(() {
      final input = _searchController.text.trim();
      if (input.isNotEmpty) {
        _searchUsers(input); // Search users when input is provided
      } else {
        setState(() => _filteredUsers = []); // Clear results when input is empty
      }
    });
  }

  /// Searches for users based on the provided query string
  /// Makes API call to search_users endpoint and updates filtered results
  Future<void> _searchUsers(String query) async {
    final url = Uri.parse('$baseUrl//search_users?query=$query');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            // Map API response to user objects with name and username
            _filteredUsers = results.map((e) => {
              'name': e['name'].toString(),
              'username': e['username'].toString(),
            }).toList();
          });
        }
      } else {
        // Clear results if API call fails
        if (mounted) {
          setState(() => _filteredUsers = []);
        }
      }
    } catch (e) {
      // Handle errors and show error message to user
      if (mounted) {
        setState(() => _filteredUsers = []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF4F4),
      // Custom app bar with search functionality
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // Custom back button
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            // App logo in the app bar
            Image.asset(
              'assets/omni_logo_symbol.jpg',
              height: 24,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            // Search input field integrated in app bar
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Enter username',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          // QR code scanner button (functionality not implemented)
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              child: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () {
                  // TODO: Implement QR code scanning functionality
                },
              ),
            ),
          ),
        ],
      ),
      // Body displays the list of filtered user search results
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: _filteredUsers.length,
          itemBuilder: (context, index) {
            final user = _filteredUsers[index];
            return ListTile(
              // User avatar with first letter of name
              leading: CircleAvatar(
                backgroundColor: Colors.deepOrange,
                child: Text(user['name']![0].toUpperCase(), style: const TextStyle(color: Colors.white)),
              ),
              // User's display name
              title: Text(user['name'] ?? ''),
              // User's username
              subtitle: Text(user['username'] ?? ''),
              onTap: () {
                // TODO: Implement user selection and request sending functionality
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up the search controller when screen is disposed
    _searchController.dispose();
    super.dispose();
  }
}