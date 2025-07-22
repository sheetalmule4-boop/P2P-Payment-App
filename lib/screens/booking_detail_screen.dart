import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

class BookingDetailScreen extends StatefulWidget {
  final String date, time, court, users, amountPaid, cardUsed;
  final String? totalDue;
  final double? basePrice, discount, taxRate, totalCost;
  final String? promoCode;
  final VoidCallback onCancel;

  const BookingDetailScreen({
    super.key,
    required this.date,
    required this.time,
    required this.court,
    required this.users,
    required this.amountPaid,
    required this.cardUsed,
    this.totalDue,
    this.basePrice,
    this.discount,
    this.taxRate,
    this.totalCost,
    this.promoCode,
    required this.onCancel,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  String? currentUsername;
  Map<String, dynamic> userDisplayNames = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  // API Methods
  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId != null) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/user/$userId'),
        );

        if (response.statusCode == 200) {
          final userData = jsonDecode(response.body);
          setState(() {
            currentUsername = userData['username'];
          });

          await _loadParticipantNames();
          await _fetchBookingParticipants();
        }
      } catch (e) {
        print('Error loading current user: $e');
      }
    }
  }

  Future<void> _fetchBookingParticipants() async {
    if (widget.users.isNotEmpty && widget.users != '[]') {
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_bookings_by_date?date=${widget.date}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> bookings = jsonDecode(response.body);

        final matchingBooking = bookings.firstWhere(
          (booking) => booking['time'] == widget.time && booking['court'] == widget.court,
          orElse: () => null,
        );

        if (matchingBooking != null && matchingBooking['participants'] != null) {
          final participants = matchingBooking['participants'] as List<dynamic>;

          for (String username in participants.cast<String>()) {
            if (!userDisplayNames.containsKey(username)) {
              await _fetchUserDisplayName(username);
            }
          }

          setState(() {});
        }
      }
    } catch (e) {
      print('Error fetching booking participants: $e');
    }
  }

  Future<void> _loadParticipantNames() async {
    try {
      if (widget.users.isNotEmpty && widget.users != '[]') {
        final decodedUsers = jsonDecode(widget.users);
        if (decodedUsers is List) {
          final List<String> userList = List<String>.from(decodedUsers);

          for (String username in userList) {
            await _fetchUserDisplayName(username);
          }

          setState(() {});
        }
      }
    } catch (e) {
      print('Error loading participant names: $e');
    }
  }

  Future<void> _fetchUserDisplayName(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/search_users?query=$username'),
      );

      if (response.statusCode == 200) {
        final searchData = jsonDecode(response.body) as List;
        final userMatch = searchData.cast<Map<String, dynamic>>().firstWhere(
          (user) => user['username'] == username,
          orElse: () => {},
        );

        if (userMatch.isNotEmpty && userMatch['name'] != null) {
          userDisplayNames[username] = userMatch['name'];
        } else {
          userDisplayNames[username] = _capitalizeUsername(username);
        }
      }
    } catch (e) {
      userDisplayNames[username] = _capitalizeUsername(username);
    }
  }

  // Data Processing Methods
  Map<String, dynamic> _parseBookingData() {
    List<String> userList = [];
    Map<String, dynamic> paidMap = {};
    Map<String, dynamic> cardMap = {};

    try {
      if (widget.users.isNotEmpty && widget.users != '[]') {
        final decodedUsers = jsonDecode(widget.users);
        if (decodedUsers is List) {
          userList = List<String>.from(decodedUsers);
        }
      }

      if (widget.amountPaid.isNotEmpty && widget.amountPaid != '{}') {
        final decodedPaid = jsonDecode(widget.amountPaid);
        if (decodedPaid is Map) {
          paidMap = Map<String, dynamic>.from(decodedPaid);
        }
      }

      if (widget.cardUsed.isNotEmpty && widget.cardUsed != '{}') {
        final decodedCards = jsonDecode(widget.cardUsed);
        if (decodedCards is Map) {
          cardMap = Map<String, dynamic>.from(decodedCards);
        }
      }
    } catch (e) {
      debugPrint('Error parsing booking details: $e');
    }

    // If userList is empty but we have display names (from API fetch), use those
    if (userList.isEmpty && userDisplayNames.isNotEmpty) {
      userList = userDisplayNames.keys.toList();
    }

    return {
      'userList': userList,
      'paidMap': paidMap,
      'cardMap': cardMap,
    };
  }

  double _calculateTotalAmount(Map<String, dynamic> paidMap) {
    if (paidMap.isNotEmpty) {
      double total = 0.0;
      for (var amount in paidMap.values) {
        total += double.tryParse(amount.toString()) ?? 0.0;
      }
      return total;
    }
    return widget.totalCost ?? 27.06; // fallback
  }

  double _calculateMyAmount(List<String> userList, Map<String, dynamic> paidMap, double totalAmount) {
    if (currentUsername != null && paidMap.containsKey(currentUsername)) {
      return double.tryParse(paidMap[currentUsername].toString()) ?? 0.0;
    } else if (userList.isEmpty && currentUsername != null) {
      return totalAmount;
    } else if (userList.length == 1 && totalAmount > 0) {
      return totalAmount;
    } else if (userList.length > 1 && totalAmount > 0) {
      return totalAmount / userList.length;
    }
    return 0.0;
  }

  String _getMyCard(Map<String, dynamic> cardMap) {
    if (currentUsername != null && cardMap.containsKey(currentUsername)) {
      final cardEntry = cardMap[currentUsername];
      if (cardEntry is Map && cardEntry.containsKey('last4')) {
        return cardEntry['last4'];
      } else if (cardEntry is String) {
        return cardEntry;
      }
    }
    return 'N/A';
  }

  // Utility Methods
  String _capitalizeUsername(String username) {
    return username.substring(0, 1).toUpperCase() + username.substring(1);
  }

  String _formatDisplayDate(String apiDate) {
    try {
      final parts = apiDate.split('-');
      final year = parts[0];
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${monthNames[month - 1]} $day, $year';
    } catch (e) {
      return apiDate;
    }
  }

  DateTime _getBookingDateTime() {
    try {
      final dateParts = widget.date.split('-');
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      final timeParts = widget.time.toLowerCase().replaceAll(' ', '').split('-');
      final startTime = timeParts.first;
      final match = RegExp(r'(\d+):(\d+)(am|pm)').firstMatch(startTime);

      int hour = int.parse(match?.group(1) ?? '0');
      int minute = int.parse(match?.group(2) ?? '0');
      final period = match?.group(3);

      if (period == 'pm' && hour != 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      print('Error parsing booking datetime: $e');
      return DateTime.now();
    }
  }

  // Main Build Method
  @override
  Widget build(BuildContext context) {
    final bookingData = _parseBookingData();
    final userList = bookingData['userList'] as List<String>;
    final paidMap = bookingData['paidMap'] as Map<String, dynamic>;
    final cardMap = bookingData['cardMap'] as Map<String, dynamic>;

    final totalAmount = _calculateTotalAmount(paidMap);
    final myAmount = _calculateMyAmount(userList, paidMap, totalAmount);
    final myCard = _getMyCard(cardMap);
    final otherPlayers = userList.where((u) => u != currentUsername).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(totalAmount, myAmount),
            const SizedBox(height: 16),
            _buildCourtInfo(),
            const SizedBox(height: 16),
            if (currentUsername != null) ...[
              _buildCurrentUserSection(myAmount, myCard),
              const SizedBox(height: 16),
            ],
            if (otherPlayers.isNotEmpty) ...[
              _buildOtherPlayersSection(otherPlayers, paidMap, totalAmount, userList.length),
              const SizedBox(height: 16),
            ],
            _buildPricingBreakdown(totalAmount, userList.length),
            const SizedBox(height: 40),
            _buildCancelButton(),
          ],
        ),
      ),
    );
  }

  // UI Component Methods
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Booking Details',
        style: TextStyle(
          color: Colors.deepOrange,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
    );
  }

  Widget _buildHeader(double totalAmount, double myAmount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Downtown | Standard Courts',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDisplayDate(widget.date),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.time,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total: \$${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    Text(
                      'You paid: \$${myAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourtInfo() {
    return _buildInfoCard(
      icon: Icons.sports_tennis,
      title: 'Court',
      content: widget.court,
    );
  }

  Widget _buildCurrentUserSection(double myAmount, String myCard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'You',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildInfoCard(
          icon: Icons.person,
          title: userDisplayNames[currentUsername] ?? currentUsername!,
          content: '@$currentUsername\nPaid: \$${myAmount.toStringAsFixed(2)}',
        ),
        if (myCard != 'N/A')
          _buildInfoCard(
            icon: Icons.credit_card,
            title: 'Your Payment Method',
            content: 'Card ending in $myCard',
          ),
      ],
    );
  }

  Widget _buildOtherPlayersSection(
    List<String> otherPlayers,
    Map<String, dynamic> paidMap,
    double totalAmount,
    int totalPlayers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          otherPlayers.length == 1 ? 'Other Player' : 'Other Players',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...otherPlayers.map((user) {
          final amount = paidMap.containsKey(user)
              ? double.tryParse(paidMap[user].toString())?.toStringAsFixed(2)
              : (totalAmount / totalPlayers).toStringAsFixed(2);

          return _buildInfoCard(
            icon: Icons.person_outline,
            title: userDisplayNames[user] ?? user,
            content: '@$user\nPaid: \$$amount',
          );
        }),
      ],
    );
  }

Widget _buildPricingBreakdown(double totalAmount, int playerCount) {
  const basePrice = 25.00;
  const taxRate = 0.0825;
  final tax = basePrice * taxRate; // $2.06
  final expectedTotal = basePrice + tax; // $27.06

  final hasPromo = (expectedTotal - totalAmount).abs() > 0.01;
  final promoDiscount = hasPromo ? (expectedTotal - totalAmount) : 0.0;

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pricing Breakdown',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildPriceRow('Base Price (per hour)', basePrice),
        _buildPriceRow('Tax (${(taxRate * 100).toStringAsFixed(2)}%)', tax),
        if (hasPromo)
          _buildPriceRow('Promo Discount', -promoDiscount, isDiscount: true),
        const Divider(),
        _buildPriceRow('Total Cost', totalAmount, isBold: true),
        if (hasPromo) ...[
          const SizedBox(height: 6),
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Promo Code Applied',
                  style: TextStyle(fontSize: 14, color: Colors.green),
                ),
              ),
              Text(
                'SAVE10', // You can also use: widget.promoCode ?? 'SAVE10'
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
        if (playerCount > 1) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Split between $playerCount players',
                  style: const TextStyle(fontSize: 14, color: Colors.blue),
                ),
              ),
              Text(
                '\$${(totalAmount / playerCount).toStringAsFixed(2)} each',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

  Widget _buildPriceRow(String label, double amount, {bool isBold = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : null,
            ),
          ),
          Text(
            '${amount >= 0 ? '\$' : '-\$'}${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () => _confirmCancel(context),
        icon: const Icon(Icons.cancel, color: Colors.white),
        label: const Text(
          'Cancel Reservation',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(
            horizontal: 50,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: Icon(icon, color: Colors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  // Cancellation Methods
  void _confirmCancel(BuildContext context) {
    final now = DateTime.now();
    final bookingDateTime = _getBookingDateTime();
    final Duration difference = bookingDateTime.difference(now);

    String refundPolicyMessage;
    if (difference.inHours >= 24) {
      refundPolicyMessage = 'You will receive a full refund for this cancellation.';
    } else if (bookingDateTime.day == now.day &&
        bookingDateTime.month == now.month &&
        bookingDateTime.year == now.year) {
      refundPolicyMessage = 'Same-day cancellations are non-refundable. You will be charged the full fee.';
    } else {
      refundPolicyMessage = 'Cancellations within 24 hours are non-refundable.';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Reservation?'),
        content: Text(
          'Are you sure you want to cancel this reservation?\n\n$refundPolicyMessage',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Keep Reservation',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelReservation();
            },
            child: const Text(
              'Cancel Reservation',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelReservation() async {
    try {
      _showLoadingSnackBar();

      final endpoints = [
        _buildDeleteWithQueryParams,
        _buildPostWithBody,
        _buildDeleteWithBody,
      ];

      http.Response? response;
      for (final endpoint in endpoints) {
        try {
          response = await endpoint();
          if (response.statusCode == 200) break;
        } catch (e) {
          print('Endpoint failed: $e');
          continue;
        }
      }

      if (response != null && response.statusCode == 200) {
        _showSuccessDialog();
      } else {
        await _removeFromLocalStorage();
        _showOfflineDialog();
      }
    } catch (e) {
      print('Error cancelling reservation: $e');
      _showErrorDialog();
    }
  }

  Future<http.Response> _buildDeleteWithQueryParams() {
    return http.delete(
      Uri.parse('$baseUrl/cancel_booking?date=${widget.date}&time=${widget.time}&court=${widget.court}'),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<http.Response> _buildPostWithBody() {
    return http.post(
      Uri.parse('$baseUrl/cancel_booking'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'date': widget.date,
        'time': widget.time,
        'court': widget.court,
      }),
    );
  }

  Future<http.Response> _buildDeleteWithBody() {
    return http.delete(
      Uri.parse('$baseUrl/delete_booking'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'date': widget.date,
        'time': widget.time,
        'court': widget.court,
      }),
    );
  }

  void _showLoadingSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cancelling reservation...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancellation Successful'),
        content: const Text('Your reservation has been cancelled.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onCancel(); // Notify BookingScreen
              Navigator.pop(context, true); // Pass true to previous screen for refresh (feed)
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showOfflineDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Offline Cancellation'),
        content: const Text(
          'The reservation was removed from your device, but the server could not be reached. Please contact support if this issue continues.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onCancel();
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Error'),
        content: const Text('Network error. Please try again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFromLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('reserved_slots');
    if (stored == null) return;

    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      final ts = decoded[widget.date] as Map<String, dynamic>?;
      if (ts == null || !ts.containsKey(widget.time)) return;

      final courts = ts[widget.time] as Map<String, dynamic>;
      courts.remove(widget.court);

      if (courts.isEmpty) {
        ts.remove(widget.time);
      } else {
        ts[widget.time] = courts;
      }

      if (ts.isEmpty) {
        decoded.remove(widget.date);
      } else {
        decoded[widget.date] = ts;
      }

      await prefs.setString('reserved_slots', jsonEncode(decoded));
    } catch (e) {
      print('Error updating SharedPreferences: $e');
    }
  }
}