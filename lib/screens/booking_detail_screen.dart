import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

/// BookingDetailScreen shows comprehensive information about a specific booking
/// Includes participant details, payment breakdown, pricing, and cancellation functionality
/// Widget that shows detailed booking information
class BookingDetailScreen extends StatefulWidget {
  // Required booking information passed from parent screen
  final String date, time, court, users, amountPaid, cardUsed;
  final String? totalDue;
  final double? basePrice, discount, taxRate, totalCost;
  final String? promoCode;
  final VoidCallback onCancel; // Callback to notify parent of cancellation

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
  String? currentUsername; // Current logged-in user's username
  Map<String, dynamic> userDisplayNames = {}; // Maps usernames to display names

  @override
  void initState() {
    super.initState();
    _loadCurrentUser(); // Fetch current user details on screen load
  }

  /// Fetch the currently logged-in user from storage and then fetch participant data
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

          // Load participant names and fetch additional booking data
          await _loadParticipantNames();
          await _fetchBookingParticipants();
        }
      } catch (e) {
        print('Error loading current user: $e');
      }
    }
  }

  /// Fetches participants from backend if `users` field is empty
  /// Used as fallback when participant data isn't provided directly
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

        // Find the matching booking by time and court
        final matchingBooking = bookings.firstWhere(
          (booking) => booking['time'] == widget.time && booking['court'] == widget.court,
          orElse: () => null,
        );

        if (matchingBooking != null && matchingBooking['participants'] != null) {
          final participants = matchingBooking['participants'] as List<dynamic>;

          // Load display names for each participant
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

  /// Loads participant display names based on users field if available
  Future<void> _loadParticipantNames() async {
    try {
      if (widget.users.isNotEmpty && widget.users != '[]') {
        final decodedUsers = jsonDecode(widget.users);
        if (decodedUsers is List) {
          final List<String> userList = List<String>.from(decodedUsers);

          // Fetch display name for each user
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

  /// Calls API to get the full name of a user based on their username
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

        // Store display name or fallback to capitalized username
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

  /// Parses stringified JSON fields: `users`, `amountPaid`, `cardUsed`
  /// Returns a map containing parsed data for display
  Map<String, dynamic> _parseBookingData() {
    List<String> userList = [];
    Map<String, dynamic> paidMap = {};
    Map<String, dynamic> cardMap = {};

    try {
      // Parse users list from JSON string
      if (widget.users.isNotEmpty && widget.users != '[]') {
        final decodedUsers = jsonDecode(widget.users);
        if (decodedUsers is List) {
          userList = List<String>.from(decodedUsers);
        }
      }

      // Parse amount paid mapping from JSON string
      if (widget.amountPaid.isNotEmpty && widget.amountPaid != '{}') {
        final decodedPaid = jsonDecode(widget.amountPaid);
        if (decodedPaid is Map) {
          paidMap = Map<String, dynamic>.from(decodedPaid);
        }
      }

      // Parse card used mapping from JSON string
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

  /// Calculates the total amount paid by all users
  double _calculateTotalAmount(Map<String, dynamic> paidMap) {
    if (paidMap.isNotEmpty) {
      double total = 0.0;
      for (var amount in paidMap.values) {
        total += double.tryParse(amount.toString()) ?? 0.0;
      }
      return total;
    }
    return widget.totalCost ?? 27.06; // Fallback to default total
  }

  /// Determines how much the current user paid for this booking
  double _calculateMyAmount(List<String> userList, Map<String, dynamic> paidMap, double totalAmount) {
    if (currentUsername != null && paidMap.containsKey(currentUsername)) {
      // User has specific payment recorded
      return double.tryParse(paidMap[currentUsername].toString()) ?? 0.0;
    } else if (userList.isEmpty && currentUsername != null) {
      // Solo booking - user pays full amount
      return totalAmount;
    } else if (userList.length == 1 && totalAmount > 0) {
      // Single user booking
      return totalAmount;
    } else if (userList.length > 1 && totalAmount > 0) {
      // Split evenly among all participants
      return totalAmount / userList.length;
    }
    return 0.0;
  }

  /// Gets last 4 digits of card used by current user
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

  /// Capitalizes first letter of username for display
  String _capitalizeUsername(String username) {
    return username.substring(0, 1).toUpperCase() + username.substring(1);
  }

  /// Formats date from API format (YYYY-MM-DD) to readable format (MMM DD, YYYY)
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

  /// Gets the booking date and time as a DateTime object for calculations
  DateTime _getBookingDateTime() {
    try {
      final dateParts = widget.date.split('-');
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      // Parse time from format like "2:00 PM - 3:00 PM"
      final timeParts = widget.time.toLowerCase().replaceAll(' ', '').split('-');
      final startTime = timeParts.first;
      final match = RegExp(r'(\d+):(\d+)(am|pm)').firstMatch(startTime);

      int hour = int.parse(match?.group(1) ?? '0');
      int minute = int.parse(match?.group(2) ?? '0');
      final period = match?.group(3);

      // Convert to 24-hour format
      if (period == 'pm' && hour != 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      print('Error parsing booking datetime: $e');
      return DateTime.now();
    }
  }

  /// Builds the main UI for the booking detail screen
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
            // Main booking header with date, time, and amounts
            _buildHeader(totalAmount, myAmount),
            const SizedBox(height: 16),
            // Court information section
            _buildCourtInfo(),
            const SizedBox(height: 16),
            // Current user's details section
            if (currentUsername != null) ...[
              _buildCurrentUserSection(myAmount, myCard),
              const SizedBox(height: 16),
            ],
            // Other players section
            if (otherPlayers.isNotEmpty) ...[
              _buildOtherPlayersSection(otherPlayers, paidMap, totalAmount, userList.length),
              const SizedBox(height: 16),
            ],
            // Detailed pricing breakdown
            _buildPricingBreakdown(totalAmount, userList.length),
            const SizedBox(height: 40),
            // Cancel and calendar buttons
            _buildCancelButton(),
          ],
        ),
      ),
    );
  }

  /// Builds the app bar with title and styling
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

  /// Builds the header section with booking date, time, and total amounts
  Widget _buildHeader(double totalAmount, double myAmount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location information
          const Text(
            'Downtown | Standard Courts',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Date and time section
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
              // Amount information section
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

  /// Builds the court information section
  Widget _buildCourtInfo() {
    return _buildInfoCard(
      icon: Icons.sports_tennis,
      title: 'Court',
      content: widget.court,
    );
  }

  /// Builds the current user's section with their payment details
  Widget _buildCurrentUserSection(double myAmount, String myCard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'You',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // User information card
        _buildInfoCard(
          icon: Icons.person,
          title: userDisplayNames[currentUsername] ?? currentUsername!,
          content: '@$currentUsername\nPaid: \$${myAmount.toStringAsFixed(2)}',
        ),
        // Payment method card (if available)
        if (myCard != 'N/A')
          _buildInfoCard(
            icon: Icons.credit_card,
            title: 'Your Payment Method',
            content: 'Card ending in $myCard',
          ),
      ],
    );
  }

  /// Builds the section for other players in the booking
  Widget _buildOtherPlayersSection(
    List<String> otherPlayers,
    Map<String, dynamic> paidMap,
    double totalAmount,
    int totalPlayers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title (singular/plural based on count)
        Text(
          otherPlayers.length == 1 ? 'Other Player' : 'Other Players',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // List of other players with their payment info
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

  /// Builds the pricing breakdown section with base price, tax, discounts
  Widget _buildPricingBreakdown(double totalAmount, int playerCount) {
    const basePrice = 25.00;
    const taxRate = 0.0825;
    final tax = basePrice * taxRate; // $2.06
    final expectedTotal = basePrice + tax; // $27.06

    // Check if promo code was applied
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
          // Price breakdown rows
          _buildPriceRow('Base Price (per hour)', basePrice),
          _buildPriceRow('Tax (${(taxRate * 100).toStringAsFixed(2)}%)', tax),
          if (hasPromo)
            _buildPriceRow('Promo Discount', -promoDiscount, isDiscount: true),
          const Divider(),
          _buildPriceRow('Total Cost', totalAmount, isBold: true),
          // Promo code information
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
          // Split cost information for multiple players
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

  /// Builds a row for displaying price information in the breakdown
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

  /// Builds the cancel and calendar buttons with confirmation dialog
  Widget _buildCancelButton() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      // Cancel reservation button
      ElevatedButton.icon(
        onPressed: () => _confirmCancel(context),
        icon: const Icon(Icons.cancel, color: Colors.white),
        label: const Text(
          'Cancel Reservation',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      // Add to calendar button (functionality not implemented)
      ElevatedButton.icon(
        onPressed: () {
          // TODO: Add calendar functionality
        },
        icon: const Icon(Icons.calendar_today, color: Colors.white),
        label: const Text(
          'Add to Calendar',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    ],
  );
}

  /// Builds a reusable info card with icon, title, and content
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
          // Icon in circular avatar
          CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: Icon(icon, color: Colors.orange),
          ),
          const SizedBox(width: 16),
          // Title and content text
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

  /// Returns consistent BoxDecoration for info cards
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

  /// Shows cancellation confirmation dialog with refund policy information
  void _confirmCancel(BuildContext context) {
    final now = DateTime.now();
    final bookingDateTime = _getBookingDateTime();
    final Duration difference = bookingDateTime.difference(now);

    // Determine refund policy message based on timing
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

  /// Handles the cancellation logic, including API calls and local storage updates
  Future<void> _cancelReservation() async {
    try {
      _showLoadingSnackBar();

      // Try multiple API endpoints for cancellation
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

      // Handle response based on success/failure
      if (response != null && response.statusCode == 200) {
        _showSuccessDialog();
      } else {
        // Fallback to local storage removal if server fails
        await _removeFromLocalStorage();
        _showOfflineDialog();
      }
    } catch (e) {
      print('Error cancelling reservation: $e');
      _showErrorDialog();
    }
  }

  /// Builds the API call to delete booking with query parameters
  Future<http.Response> _buildDeleteWithQueryParams() {
    return http.delete(
      Uri.parse('$baseUrl/cancel_booking?date=${widget.date}&time=${widget.time}&court=${widget.court}'),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Builds the API call to cancel booking with POST and body
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

  /// Builds the API call to delete booking with DELETE and body
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

  /// Shows a loading SnackBar while cancelling the reservation
  void _showLoadingSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cancelling reservation...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  /// Shows a success dialog after successful cancellation
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

  /// Shows an offline dialog if the server could not be reached
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

  // Shows an error dialog if there was a network error
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
  // Removes the booking from local storage if it exists
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