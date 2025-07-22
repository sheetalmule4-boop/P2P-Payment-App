
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';


class SendRequestScreen extends StatefulWidget {
  const SendRequestScreen({super.key});

  @override
  State<SendRequestScreen> createState() => _SendRequestScreenState();
}

class _SendRequestScreenState extends State<SendRequestScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final input = _searchController.text.trim();
      if (input.isNotEmpty) {
        _searchUsers(input);
      } else {
        setState(() => _filteredUsers = []);
      }
    });
  }

  Future<void> _searchUsers(String query) async {
    final url = Uri.parse('$baseUrl//search_users?query=$query');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _filteredUsers = results.map((e) => {
              'name': e['name'].toString(),
              'username': e['username'].toString(),
            }).toList();
          });
        }
      } else {
        if (mounted) {
          setState(() => _filteredUsers = []);
        }
      }
    } catch (e) {
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Image.asset(
              'assets/omni_logo_symbol.jpg',
              height: 24,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
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
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              child: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: _filteredUsers.length,
          itemBuilder: (context, index) {
            final user = _filteredUsers[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepOrange,
                child: Text(user['name']![0].toUpperCase(), style: const TextStyle(color: Colors.white)),
              ),
              title: Text(user['name'] ?? ''),
              subtitle: Text(user['username'] ?? ''),
              onTap: () {},
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
