import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'feed_screen.dart';
import 'booking_detail_screen.dart';
import '../constants.dart';

class CheckoutScreen extends StatefulWidget {
  final String timeSlot;
  final VoidCallback? onReserve;
  final DateTime? selectedDate;

  const CheckoutScreen({Key? key, required this.timeSlot, this.onReserve, this.selectedDate}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  String? _currentUsername;

  String _selectedCourt = 'Auto selection';
  String _selectedGroupSize = '1 player';
  String _selectedPaymentMethod = '';

  List<String> _userCards = [];
  int? _userId;

  final _promoController = TextEditingController();
  final _userSearchController = TextEditingController();

  double _discount = 0.0;
  static const double _price = 25.00;
  static const double _taxRate = 0.0825;

  List<Map<String, dynamic>> _suggestedUsers = [];
  List<Map<String, dynamic>> _selectedUsers = [];

  // Store the actual available courts from API
  List<String> _availableCourts = ['Auto selection', 'Court 1', 'Court 2'];

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadAvailableCourts(); // Load available courts from API
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadAvailableCourts() async {
    if (widget.selectedDate == null) return;
    
    // Use consistent date formatting
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_bookings_by_date?date=$selectedDateStr'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as List;
        final reservedCourts = <String>{};

        // Find courts already reserved for this time slot
        for (var booking in decoded) {
          if (booking['time'] == widget.timeSlot) {
            reservedCourts.add(booking['court']);
          }
        }

        final allCourts = ['Court 1', 'Court 2'];
        final available = allCourts.where((court) => !reservedCourts.contains(court)).toList();
        
        setState(() {
          _availableCourts = ['Auto selection', ...available];
        });
        
        print('Available courts for ${widget.timeSlot} on $selectedDateStr: $available');
      }
    } catch (e) {
      print('Error loading available courts: $e');
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getInt('user_id');

    if (storedUserId != null) {
      final response = await http.get(Uri.parse('$baseUrl/user/$storedUserId'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final username = data['username'];
        final displayName = '${data['first_name']} ${data['last_name']}';

        setState(() {
          _userId = storedUserId;
          _currentUsername = username;
          _selectedUsers = [
            {
              'username': username,
              'displayName': displayName,
              'card': _userCards.isNotEmpty ? _userCards[0] : null
            }
          ];
        });

        _fetchUserCards(storedUserId);
      } else {
        debugPrint("Failed to load user profile from server.");
      }
    } else {
      debugPrint("User ID not found in SharedPreferences.");
    }
  }

  Future<void> _fetchUserCards(int userId) async {
    final uri = Uri.parse('$baseUrl/get_user_cards/$userId');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body);
      setState(() {
        _userCards = data.map<String>((card) {
          final last4 = card['card_number'];
          final name = card['name_on_card'];
          final exp = '${card["expiry_month"]}/${card["expiry_year"]}';
          return '$name - **** $last4 ($exp)';
        }).toList();
        _selectedPaymentMethod = _userCards.isNotEmpty ? _userCards[0] : '';
      });
    }
  }

  List<String> _getAvailableCourts() {
    return _availableCourts;
  }

  // Helper method to get the actual court to reserve
  String _getActualCourtToReserve() {
    if (_selectedCourt == 'Auto selection') {
      // Find the first available court
      final availableCourtNames = _availableCourts.where((court) => court != 'Auto selection').toList();
      return availableCourtNames.isNotEmpty ? availableCourtNames.first : 'Court 1';
    }
    return _selectedCourt;
  }

  int _getGroupSizeLimit() => int.parse(_selectedGroupSize.split(' ')[0]);

  double _calculateTotal() => (_price - _discount) * (1 + _taxRate);

  @override
  void dispose() {
    _promoController.dispose();
    _userSearchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _applyPromoCode() {
    final code = _promoController.text.trim();
    if (code.toUpperCase() == 'SAVE10') {
      setState(() => _discount = 2.5);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo code accepted!'), backgroundColor: Colors.green),
      );
    } else {
      setState(() => _discount = 0.0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid promo code.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) return;
    final uri = Uri.parse('$baseUrl/search_users?query=$query');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(json.decode(res.body));
      setState(() => _suggestedUsers = data);
    }
  }

  Widget _buildCardRow({required IconData icon, required String label, required String trailing, VoidCallback? onTap, Widget? customTrailing}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Icon(icon, color: Colors.orange),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            customTrailing ?? Text(trailing, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildCourtCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: Icon(Icons.sports_tennis, color: Colors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Court', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                DropdownButton<String>(
                  value: _selectedCourt,
                  isExpanded: true,
                  underline: Container(),
                  items: _getAvailableCourts().map((court) => DropdownMenuItem(value: court, child: Text(court))).toList(),
                  onChanged: (value) => setState(() => _selectedCourt = value!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSizeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: Icon(Icons.group, color: Colors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Group Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                DropdownButton<String>(
                  value: _selectedGroupSize,
                  isExpanded: true,
                  underline: Container(),
                  items: ['1 player', '2 players', '3 players', '4 players']
                      .map((size) => DropdownMenuItem(value: size, child: Text(size)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedGroupSize = value!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    if (_userCards.isEmpty) return Container();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: Icon(Icons.credit_card, color: Colors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                DropdownButton<String>(
                  value: _selectedPaymentMethod.isNotEmpty ? _selectedPaymentMethod : null,
                  isExpanded: true,
                  underline: Container(),
                  items: _userCards.map((card) => DropdownMenuItem(value: card, child: Text(card))).toList(),
                  onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter promo code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          TextField(
            controller: _promoController,
            decoration: const InputDecoration(border: UnderlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _applyPromoCode,
              child: const Text('Apply', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _submitBooking() async {
  if (_userId == null || widget.selectedDate == null) return;

  // Check if all users are filled for group bookings
  final groupSize = _getGroupSizeLimit();

  // For solo booking, we already have the user loaded
  final allUsersFilled = groupSize == 1 ||
    (_selectedUsers.length == groupSize &&
    _selectedUsers.every((user) => user['username'] != null));

  if (!allUsersFilled) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter all usernames before checking out.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final selectedDateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
  final courtName = _getActualCourtToReserve();
  final perUser = _calculateTotal() / _selectedUsers.length;
  
  // Filter out users with null usernames and create proper maps
  final validUsers = _selectedUsers.where((user) => user['username'] != null).toList();
  
  final payload = {
    'user_id': _userId,
    'date': selectedDateStr,
    'time': widget.timeSlot,
    'court': courtName,
    'participants': validUsers.map((u) => u['username'] as String).toList(),
    'amount_paid': {
      for (var u in validUsers)
        u['username'] as String: perUser.toStringAsFixed(2)
    },
    'card_used': {
      for (var u in validUsers)
        u['username'] as String: {
          'last4': RegExp(r'\*\*\*\* (\d{4})').firstMatch(_selectedPaymentMethod)?.group(1) ?? '0000'
        }
    },
    'promo_code': _promoController.text.trim(),
  };

  print('📤 Booking payload: ${jsonEncode(payload)}');

  final res = await http.post(
    Uri.parse('$baseUrl/add_booking'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );

  if (res.statusCode == 201) {
    print('Booking saved to backend');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CourtBookingScreen(
          showConfirmation: true,
          confirmationMessage:
              'You have reserved $courtName for ${widget.timeSlot} on ${DateFormat('M/d/yyyy').format(widget.selectedDate!)}.',
          newlyReservedDate: selectedDateStr,
          newlyReservedTimeSlot: widget.timeSlot,
          newlyReservedCourt: courtName,
        ),
      ),
    );
  } else {
    print('Failed to save booking');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to save booking'), backgroundColor: Colors.red),
    );
  }
}

  void _showReservationConfirmation() {
    final formattedDate = DateFormat.yMMMMEEEEd().format(widget.selectedDate!);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Booking Confirmed'),
        content: Text('Your court has been reserved for $formattedDate at ${widget.timeSlot}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  List<Widget> _buildUserInputs() {
    final groupSize = _getGroupSizeLimit();

    while (_selectedUsers.length < groupSize) {
      _selectedUsers.add({'username': null, 'displayName': null});
    }
    _selectedUsers = _selectedUsers.sublist(0, groupSize);

    return List.generate(groupSize, (index) {
      if (index == 0) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: Icon(Icons.person, color: Colors.orange),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text('${_selectedUsers[0]['displayName'] ?? 'Me'} (@$_currentUsername)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        );
      }

      final selectedUsername = _selectedUsers[index]['username'];

      if (selectedUsername != null) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: Icon(Icons.person, color: Colors.orange),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${_selectedUsers[index]['displayName']} (@$selectedUsername)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _selectedUsers[index]['username'] = null;
                    _selectedUsers[index]['displayName'] = null;
                  });
                },
              ),
            ],
          ),
        );
      }

      final controller = TextEditingController();

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Icon(Icons.person_add, color: Colors.orange),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Enter User ${index + 1} Username',
                  border: UnderlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final typedUsername = controller.text.trim();
                if (typedUsername.isEmpty) return;

                final uri = Uri.parse('$baseUrl/validate_username/$typedUsername');
                final res = await http.get(uri);

                if (res.statusCode == 200) {
                  final data = json.decode(res.body);
                  final exists = data['exists'] == true;
                  if (exists) {
                    final alreadyAdded = _selectedUsers.any((user) => user['username'] == typedUsername);

                    if (alreadyAdded) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('This user has already been added.'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    // Get the full name using the search endpoint
                    String? displayName;
                    try {
                      final searchUri = Uri.parse('$baseUrl/search_users?query=$typedUsername');
                      final searchRes = await http.get(searchUri);
                      
                      if (searchRes.statusCode == 200) {
                        final searchData = json.decode(searchRes.body) as List;
                        
                        // Find exact username match
                        final userMatch = searchData.cast<Map<String, dynamic>>().firstWhere(
                          (user) => user['username'] == typedUsername,
                          orElse: () => {},
                        );
                        
                        if (userMatch.isNotEmpty && userMatch['name'] != null) {
                          displayName = userMatch['name'];
                        }
                      } else {
                        print('DEBUG: Search API failed with status ${searchRes.statusCode}');
                      }
                    } catch (e) {
                      print('DEBUG: Search failed, using username as fallback: $e');
                    }
                    
                    // If we couldn't get the display name, use a formatted version of the username
                    if (displayName == null) {
                      // Capitalize first letter and format the username nicely
                      displayName = typedUsername.substring(0, 1).toUpperCase() + typedUsername.substring(1);
                    }

                    setState(() {
                      _selectedUsers[index]['username'] = typedUsername;
                      _selectedUsers[index]['displayName'] = displayName;
                    });
                    
                    print('DEBUG: Final displayName set to: $displayName');
                    print('DEBUG: Selected users after update: ${_selectedUsers[index]}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Username added!'), backgroundColor: Colors.green),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Username not found.'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEE, MMMM d').format(widget.selectedDate ?? DateTime.now());
    final subtotal = _price - _discount;
    final tax = subtotal * _taxRate;
    final total = _calculateTotal();
    final perUser = _getGroupSizeLimit() > 1 ? (total / _getGroupSizeLimit()) : total;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Order Summary', style: TextStyle(color: Colors.deepOrange, fontSize: 28, fontWeight: FontWeight.bold)),
        centerTitle: true,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and time info
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Downtown | Standard Courts', style: TextStyle(fontSize: 16, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formattedDate, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(widget.timeSlot, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                        ],
                      ),
                      Text('\$${_price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            // Court selection
            _buildCourtCard(),

            // Coach card
            _buildCardRow(icon: Icons.local_offer_outlined, label: 'Coach', trailing: 'No coaches available'),

            // Group size selection
            _buildGroupSizeCard(),

            // Payment method
            _buildPaymentMethodCard(),

            // User inputs for group bookings
            if (_getGroupSizeLimit() > 1) ...[
              const SizedBox(height: 16),
              const Text('Players', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ..._buildUserInputs(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Each user pays: \$${perUser.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],

            // Promo code
            _buildPromoCard(),

            // Tax and total
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tax (8.25%)', style: TextStyle(fontSize: 16)),
                Text('\$${tax.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {},
              child: const Text('+ Add more time', style: TextStyle(fontSize: 16, decoration: TextDecoration.underline, color: Colors.orange)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),

            // Reserve button
            Center(
              child: ElevatedButton.icon(
                onPressed: _submitBooking,
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: Text(
                  _getGroupSizeLimit() > 1
                      ? 'Split → ${_getGroupSizeLimit()} users / \$${(_calculateTotal() / _getGroupSizeLimit()).toStringAsFixed(2)}'
                      : 'Reserve → 1 hr / \$${_calculateTotal().toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
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
    );
  }
}