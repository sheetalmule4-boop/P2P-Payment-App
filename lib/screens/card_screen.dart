import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class CardScreen extends StatefulWidget {
  const CardScreen({super.key});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

// This screen displays the user's saved cards and allows them to add or delete cards.
class _CardScreenState extends State<CardScreen> {
  final List<Map<String, dynamic>> _cards = [];
  final List<Map<String, dynamic>> _banks = [];

  final List<List<Color>> cardGradients = [
    [Color(0xFF1e3c72), Color(0xFF2a5298)], // Blue
    [Color(0xFFff6b6b), Color(0xFFee5a52)], // Red
    [Color(0xFF43cea2), Color(0xFF185a9d)], // Green-Blue
    [Color(0xFF614385), Color(0xFF516395)], // Purple
  ];

  // Deletes a card by its ID
  Future<void> _deleteCard(String cardId) async {
    final response = await http.delete(Uri.parse('$baseUrl//delete_card/$cardId'));

    if (response.statusCode == 200) {
      setState(() {
        _cards.removeWhere((card) => card['id'] == cardId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card deleted successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete card.')),
      );
    }
  }

  // Shows a confirmation dialog before deleting a card
  void _showDeleteConfirmation(String cardId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Card', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        content: const Text('Are you sure you want to delete this card?', style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCard(cardId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6D00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchUserCards();
  }

  // Fetches the user's saved cards from the server
  Future<void> _fetchUserCards() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) return;

    final response = await http.get(Uri.parse('$baseUrl//get_user_cards/$userId'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        _cards.clear();
        for (int i = 0; i < data.length; i++) {
          final card = data[i];
          final gradient = cardGradients[i % cardGradients.length];
          _cards.add({
            'id': card['id'].toString(),
            'type': 'Debit Card',
            'brand': 'VISA',
            'lastFour': card['card_number'],
            'holderName': card['name_on_card'].toString().toUpperCase(),
            'expiry': '${card['expiry_month']}/${card['expiry_year'].substring(2)}',
            'gradient': gradient,
          });
        }
      });
    }
  }

  // Fetches the user's connected banks from the server
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Cards and Banks', style: TextStyle(color: Colors.deepOrange, fontSize: 30, fontWeight: FontWeight.bold)),
        centerTitle: true,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddCardScreen()),
                    ).then((value) {
                      if (value == true) _fetchUserCards();
                    });
                  },
                  icon: const Icon(Icons.credit_card, size: 20, color: Colors.white),
                  label: const Text('Add Card', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/add-bank');
                  },
                  icon: const Icon(Icons.account_balance, size: 20, color: Colors.white),
                  label: const Text('Add Bank', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0077B6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (_cards.isNotEmpty) ...[
              const Text('Your Cards', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 16),
              ..._cards.map((card) => _buildCardItem(card)),
              const SizedBox(height: 32),
            ],
            if (_banks.isNotEmpty) ...[
              const Text('Connected Banks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 16),
              ..._banks.map((bank) => _buildBankItem(bank)),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  // Builds a card item widget
  Widget _buildCardItem(Map<String, dynamic> card) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: card['gradient'],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(card['type'], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Text(card['brand'], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showDeleteConfirmation(card['id']),
                    child: const Icon(Icons.delete, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('•••• •••• •••• ${card['lastFour']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 2, fontFamily: 'monospace')),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(card['holderName'], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              Text(card['expiry'], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
  // Builds a bank item widget
  Widget _buildBankItem(Map<String, dynamic> bank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bank['color'],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(bank['initial'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bank['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 4),
                Text('${bank['accountType']} ••••${bank['lastFour']}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text('\$${bank['balance'].toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }
}


// This screen allows users to add a new card to their account.
class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}
class _AddCardScreenState extends State<AddCardScreen> {
  final _cardFormKey = GlobalKey<FormState>();
  final Map<String, String> _cardData = {};

  final cardController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _cvvController = TextEditingController();

  bool _cardValid = true;
  List<String> _months = [];
  List<String> _years = [];
  String? _selectedMonth;
  String? _selectedYear;
  List<String> _states = [];
  String? _selectedState;
  int? userId;
  

  @override
  void initState() {
    super.initState();
    _fetchExpirationData();
    _fetchStates();
    _loadUserId();
  }

  // Fetches the list of states from the server
  Future<void> _fetchStates() async {
    final response = await http.get(Uri.parse('$baseUrl/get_states'));
    if (response.statusCode == 200) {
      setState(() => _states = List<String>.from(jsonDecode(response.body)));
    }
  }

  // Fetches the expiration months and years from the server
  Future<void> _fetchExpirationData() async {
    final monthRes = await http.get(Uri.parse('$baseUrl//get_expiration_months'));
    final yearRes = await http.get(Uri.parse('$baseUrl//get_expiration_years'));

    if (monthRes.statusCode == 200 && yearRes.statusCode == 200) {
      setState(() {
        _months = List<String>.from(jsonDecode(monthRes.body));
        _years = List<String>.from(jsonDecode(yearRes.body));
      });
    }
  }

  // Loads the user ID from shared preferences
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getInt('user_id');
    });
  }


  // Validates the card number using Luhn's algorithm, commented for now for demonstration purposes
  // This function can be uncommented and used to validate card numbers.

  // bool isValidCardNumber(String input) {
  //   input = input.replaceAll(' ', '');
  //   if (input.isEmpty || input.length < 13) return false;
  //   int sum = 0;
  //   bool alternate = false;
  //   for (int i = input.length - 1; i >= 0; i--) {
  //     int n = int.tryParse(input[i]) ?? -1;
  //     if (n == -1) return false;
  //     if (alternate) {
  //       n *= 2;
  //       if (n > 9) n -= 9;
  //     }
  //     sum += n;
  //     alternate = !alternate;
  //   }
  //   return sum % 10 == 0;
  // }


  // Handles the form submission to add a new card
  Future<void> _handleSubmit() async {
    if (!_cardFormKey.currentState!.validate()) return;
    _cardFormKey.currentState!.save();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in.')),
      );
      return;
    }

    _cardData['user_id'] = userId.toString(); 
    final response = await http.post(
      Uri.parse('$baseUrl//add_card'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(_cardData),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card added successfully!')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add card.')),
      );
    }
  }

  // Builds a form field for card details
  Widget _buildCardField({
    required String label,
    required String key,
    TextEditingController? controller,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.brown),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.deepOrange, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.brown),
      ),
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
      validator: validator,
      onSaved: (value) => _cardData[key] = value!.trim(),
    );
  }

  // Builds a form field for the card number with validation
  Widget _buildCardNumberField() {
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          final cardNumber = cardController.text.trim();
          // setState(() => _cardValid = isValidCardNumber(cardNumber)); //commented out due to validation function being commented
          setState(() => _cardValid = true);

        }
      },
      child: TextFormField(
        controller: cardController,
        decoration: InputDecoration(
          labelText: 'Card Number',
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.brown),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.deepOrange, width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.brown),
          // suffixIcon: !_cardValid
          //     ? IconButton(
          //         icon: const Icon(Icons.error, color: Colors.red),
          //         onPressed: _showInvalidCardDialog,
          //       )
          //     : null,
        ),
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Required';
          // if (!isValidCardNumber(value)) return 'Invalid card number';
          return null;
        },
        onSaved: (value) => _cardData['card_number'] = value!.trim(),
        keyboardType: TextInputType.number,
      ),
    );
  }

  // Shows a dialog if the card number is invalid, currently not used for demonstration purposes
  void _showInvalidCardDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Invalid Card Number',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Please enter a valid credit card number.',
          style: TextStyle(
            color: Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Builds the main UI for adding a card
  @override
  Widget build(BuildContext context) {
    final spacing = const SizedBox(height: 16);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Add Card', style: TextStyle(color: Colors.deepOrange, fontSize: 30, fontWeight: FontWeight.bold)),
        centerTitle: true,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _cardFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardNumberField(),
              spacing,
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedMonth,
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        labelStyle: TextStyle(color: Colors.brown),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.brown)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.deepOrange, width: 2)),
                      ),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
                      items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (value) => setState(() => _selectedMonth = value),
                      onSaved: (value) => _cardData['expiry_month'] = value!,
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        labelStyle: TextStyle(color: Colors.brown),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.brown)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.deepOrange, width: 2)),
                      ),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
                      items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                      onChanged: (value) => setState(() => _selectedYear = value),
                      onSaved: (value) => _cardData['expiry_year'] = value!,
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              spacing,
              _buildCardField(label: 'CVV', key: 'cvv', controller: _cvvController, validator: (v) => v == null || v.length != 3 ? 'CVV must be 3 digits' : null),
              spacing,
              _buildCardField(label: 'Name on Card', key: 'name_on_card', controller: _nameController, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              spacing,
              _buildCardField(label: 'Address', key: 'address', controller: _addressController, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              spacing,
              _buildCardField(label: 'City', key: 'city', controller: _cityController, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              spacing,
              DropdownButtonFormField<String>(
                value: _selectedState,
                decoration: const InputDecoration(
                  labelText: 'State',
                  labelStyle: TextStyle(color: Colors.brown),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.brown)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.deepOrange, width: 2)),
                ),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
                items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (value) => setState(() => _selectedState = value),
                onSaved: (value) => _cardData['state'] = value!,
                validator: (value) => value == null ? 'Required' : null,
              ),
              spacing,
              _buildCardField(label: 'Zip Code', key: 'zip', controller: _zipController, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              spacing,
              Center(
                child: ElevatedButton.icon(
                  onPressed: _handleSubmit,
                  icon: const Icon(Icons.add_card, color: Colors.white),
                  label: const Text('Add Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00),
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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