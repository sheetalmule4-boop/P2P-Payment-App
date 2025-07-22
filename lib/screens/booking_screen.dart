import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'booking_detail_screen.dart';
import '../constants.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<Map<String, dynamic>> _futureBookings = [];
  List<Map<String, dynamic>> _pastBookings = [];
  bool _isLoading = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndBookings();
  }

  Future<void> _loadUserIdAndBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId != null) {
      setState(() {
        _userId = userId;
      });
      await _loadBookings();
    } else {
      setState(() {
        _isLoading = false;
      });
      print('No user ID found in SharedPreferences');
    }
  }

  Future<void> _loadBookings() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final List<Map<String, dynamic>> allBookings = [];

      final userResponse = await http.get(
        Uri.parse('$baseUrl/user/$_userId'),
      );

      String? currentUsername;
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        currentUsername = userData['username'];
        print('Current username: $currentUsername');
      } else {
        print('Failed to get user data: ${userResponse.statusCode}');
      }

      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 7));
      final endDate = now.add(const Duration(days: 30));

      print('Searching bookings from ${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}');

      for (int i = 0; i <= 37; i++) {
        final checkDate = startDate.add(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(checkDate);

        try {
          final response = await http.get(
            Uri.parse('$baseUrl/get_bookings_by_date?date=$dateKey'),
          );

          if (response.statusCode == 200) {
            final List<dynamic> dayBookings = jsonDecode(response.body);

            for (var booking in dayBookings) {
              final participants = booking['participants'];

              bool isUserParticipant = false;
              if (participants is List) {
                isUserParticipant = participants.contains(currentUsername);
              } else if (participants is String) {
                try {
                  final List<dynamic> participantsList = jsonDecode(participants);
                  isUserParticipant = participantsList.contains(currentUsername);
                } catch (e) {
                  print('Error parsing participants string: $e');
                }
              }

              final bookingUserId = booking['user_id'];
              if (bookingUserId != null && bookingUserId.toString() == _userId.toString()) {
                isUserParticipant = true;
              }

              if (isUserParticipant) {
                allBookings.add(Map<String, dynamic>.from(booking));
              }
            }
          }
        } catch (e) {
          print('Error fetching bookings for $dateKey: $e');
        }
      }

      allBookings.sort((a, b) => _parseDateTime(a).compareTo(_parseDateTime(b)));

      final past = <Map<String, dynamic>>[];
      final future = <Map<String, dynamic>>[];

      for (var booking in allBookings) {
        final endTime = _parseEndDateTime(booking);
        if (endTime.isBefore(now)) {
          past.add(booking);
        } else {
          future.add(booking);
        }
      }

      setState(() {
        _pastBookings = past;
        _futureBookings = future;
        _isLoading = false;
      });

      print('Loaded ${allBookings.length} bookings (${future.length} upcoming, ${past.length} past)');
    } catch (e) {
      print('Error loading bookings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeBookingFromList(String date, String time, String court) {
    print("Removing booking: $date $time $court");
    setState(() {
      _futureBookings.removeWhere((booking) => 
        booking['date'] == date && 
        booking['time'] == time && 
        booking['court'] == court
      );

      _pastBookings.removeWhere((booking) => 
        booking['date'] == date && 
        booking['time'] == time && 
        booking['court'] == court
      );
    });
  }

  DateTime _parseDateTime(Map<String, dynamic> booking) {
    final date = booking['date'] as String;
    final timeStr = booking['time'] as String;
    final startTimeStr = timeStr.split(' - ')[0];
    final dateParts = date.split('-');
    final time = _parseTimeString(startTimeStr);

    return DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      time.hour,
      time.minute,
    );
  }

  DateTime _parseEndDateTime(Map<String, dynamic> booking) {
    final date = booking['date'] as String;
    final timeStr = booking['time'] as String;
    final endTimeStr = timeStr.split(' - ')[1];
    final dateParts = date.split('-');
    final time = _parseTimeString(endTimeStr);

    return DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      time.hour,
      time.minute,
    );
  }

  TimeOfDay _parseTimeString(String timeStr) {
    final isPM = timeStr.toLowerCase().contains('pm');
    final isAM = timeStr.toLowerCase().contains('am');

    final cleaned = timeStr.trim().toLowerCase().replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = cleaned.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);

    if (isPM && hour != 12) hour += 12;
    if (isAM && hour == 12) hour = 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatDisplayDate(String apiDate) {
    final parts = apiDate.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]).toString();
    final day = int.parse(parts[2]).toString();
    return '$year-$month-$day';
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
          'My Bookings',
          style: TextStyle(
            color: Color(0xFFFF6D00),
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6D00),
              ),
            )
          : (_futureBookings.isEmpty && _pastBookings.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'No Bookings Created yet.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBookings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6D00),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Refresh',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFFF6D00),
                  onRefresh: _loadBookings,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_futureBookings.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Upcoming Reservations',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_futureBookings.length}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFFFF6D00),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._futureBookings.map((booking) => _buildBookingCard(booking, isUpcoming: true)),
                          const SizedBox(height: 24),
                        ],
                        if (_pastBookings.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Past Reservations',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_pastBookings.length}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._pastBookings.map((booking) => _buildBookingCard(booking, isUpcoming: false)),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, {required bool isUpcoming}) {
    final date = booking['date'] as String;
    final time = booking['time'] as String;
    final court = booking['court'] as String;
    final participants = booking['participants'] as List<dynamic>?;
    final amountPaid = booking['amount_paid'] as Map<String, dynamic>?;
    final cardUsed = booking['card_used'] as Map<String, dynamic>?;
    final totalCost = double.tryParse(booking['total_cost']?.toString() ?? '') ?? 0.0;
    final tax = double.tryParse(booking['tax']?.toString() ?? '') ?? 0.0;
    final discount = double.tryParse(booking['discount']?.toString() ?? '') ?? 0.0;
    final basePrice = totalCost - tax + discount;
    final promoCode = booking['promo_code'] ?? '';

    double totalAmount = 0.0;
    if (amountPaid != null) {
      for (var amount in amountPaid.values) {
        totalAmount += double.tryParse(amount.toString()) ?? 0.0;
      }
    }

    final displayDate = _formatDisplayDate(date);

    final cardContent = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$displayDate at $time',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Court: $court',
            style: const TextStyle(fontSize: 14),
          ),
          if (participants != null && participants.length > 1) ...[
            const SizedBox(height: 4),
            Text(
              'Players: ${participants.join(', ')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isUpcoming
            ? ()  async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingDetailScreen(
                      date: date,
                      time: time,
                      court: court,
                      users: jsonEncode(booking['participants']),
                      amountPaid: jsonEncode(booking['amount_paid']),
                      cardUsed: jsonEncode(booking['card_used']),
                      totalDue: totalAmount.toStringAsFixed(2),
                      promoCode: booking['promo_code'],
                      basePrice: basePrice,
                      discount: discount,
                      taxRate: tax,
                      totalCost: totalCost,
                      onCancel: () {
                        _removeBookingFromList(date, time, court);
                        _loadBookings();
                      },
                    ),
                  ),
                );
                if (result == true) {
                  Navigator.pop(context, true);
                }
              }
            : null,
        child: cardContent,
      ),
    );
  }
}
