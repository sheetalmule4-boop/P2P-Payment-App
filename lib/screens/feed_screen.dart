import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'checkout_screen.dart';
import '../constants.dart';

class CourtBookingScreen extends StatefulWidget {
  final bool showConfirmation;
  final String? confirmationMessage;
  final String? newlyReservedDate;
  final String? newlyReservedTimeSlot;
  final String? newlyReservedCourt;

  const CourtBookingScreen({
    super.key, 
    this.showConfirmation = false, 
    this.confirmationMessage,
    this.newlyReservedDate,
    this.newlyReservedTimeSlot,
    this.newlyReservedCourt,
  });

  @override
  State<CourtBookingScreen> createState() => _CourtBookingScreenState();
}

class _CourtBookingScreenState extends State<CourtBookingScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  int _selectedDayIndex = 0;
  int _dayOffset = 0;
  String? _selectedTimeSlot;
  String? _selectedCourt;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  Map<String, Map<String, Set<String>>> _dailyReservedSlots = {};
  
  Map<String, Map<String, List<String>>> courtReservations = {};
  bool _hasLoadedInitialData = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    if (widget.newlyReservedDate != null &&
        widget.newlyReservedTimeSlot != null &&
        widget.newlyReservedCourt != null) {
      
      print('Adding new reservation: ${widget.newlyReservedCourt} for ${widget.newlyReservedTimeSlot} on ${widget.newlyReservedDate}');
      
      final dateKey = widget.newlyReservedDate!;
      
      _dailyReservedSlots.putIfAbsent(dateKey, () => {});
      _dailyReservedSlots[dateKey]!.putIfAbsent(widget.newlyReservedTimeSlot!, () => <String>{});
      _dailyReservedSlots[dateKey]![widget.newlyReservedTimeSlot!]!.add(widget.newlyReservedCourt!);
      
      _loadReservationsWithDelay();
    }
    
    if (widget.showConfirmation && widget.confirmationMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Court Reserved',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              widget.confirmationMessage!,
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Color(0xFFEA1C7E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedInitialData && widget.newlyReservedDate == null) {
      _loadReservations();
    }
  }

  Future<void> _loadReservationsWithDelay() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadReservations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadReservations() async {
    final List<Map<String, dynamic>> weekDates = _generateWeekDates();
    Map<String, Map<String, Set<String>>> allReserved = {};

    for (var day in weekDates) {
      final date = day['fullDate'] as DateTime;
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final displayDateKey = '${date.year}-${date.month}-${date.day}';

      try {
        final response = await http.get(
          Uri.parse('http://10.0.0.68:1601/get_bookings_by_date?date=$dateKey'),
        );

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as List;
          final reservedMap = <String, Set<String>>{};

          for (var booking in decoded) {
            final time = booking['time'];
            final court = booking['court'];
            reservedMap.putIfAbsent(time, () => <String>{}).add(court);
          }

          allReserved[dateKey] = reservedMap;
          allReserved[displayDateKey] = reservedMap;
        } else {
          print('Failed to fetch for $dateKey: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching reservations for $dateKey: $e');
      }
    }

    if (mounted) {
      setState(() {
        _dailyReservedSlots = allReserved;
        _hasLoadedInitialData = true;
      });
      print('Loaded reservations: $_dailyReservedSlots');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      Navigator.pushNamed(context, '/card').then((_) {
        setState(() {
          _selectedIndex = 0;
        });
      });
    } else if (index == 2) {
      final selectedSlot = _selectedTimeSlot;
      final selectedDate = _generateWeekDates()[_selectedDayIndex]['fullDate'] as DateTime;
      if (selectedSlot != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CheckoutScreen(
              timeSlot: selectedSlot,
              selectedDate: selectedDate,
              onReserve: () {
                _loadReservations();
              },
            ),
          ),
        ).then((result) {
          setState(() {
            _selectedIndex = 0;
            _selectedTimeSlot = null;
          });
          
          if (result != null && result['success'] == true) {
            _loadReservations();
            _showReservationConfirmation(
              result['timeSlot'] as String, 
              result['court'] as String, 
              result['date'] as DateTime
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a time'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _selectedIndex = 0;
        });
      }
    } else if (index == 4) {
      Navigator.pushNamed(context, '/more').then((_) {
        setState(() {
          _selectedIndex = 0;
        });
      });
    }
  }

  void _navigateDays(int direction) {
    _animationController.forward().then((_) {
      setState(() {
        _dayOffset += direction * 2;
        _selectedDayIndex = 0;
      });
      _animationController.reverse();
    });
  }

  List<Map<String, dynamic>> _generateWeekDates() {
    final now = DateTime.now();
    final baseDate = now.add(Duration(days: _dayOffset));

    return List.generate(7, (index) {
      final date = baseDate.add(Duration(days: index));
      final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
      return {
        'day': _getDayName(date.weekday),
        'date': '${date.month}/${date.day}',
        'fullDate': date,
        'isToday': isToday,
      };
    });
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  List<Map<String, dynamic>> _getTimeSlots() {
    final List<Map<String, dynamic>> slots = [];

    final selectedDate =
        _generateWeekDates()[_selectedDayIndex]['fullDate'] as DateTime;
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    final reservedMap = _dailyReservedSlots[dateKey] ?? {};

    final DateTime now = DateTime.now();

    final bool entireDayInPast =
        selectedDate.isBefore(DateTime(now.year, now.month, now.day));

    DateTime start = DateTime(selectedDate.year, selectedDate.month,
        selectedDate.day, 8, 0);

    for (int i = 0; i < 14; i++) {
      final DateTime end = start.add(const Duration(hours: 1));
      final String formattedTime =
          '${_formatTime(start)} - ${_formatTime(end)}';

      final bool slotInPast = entireDayInPast ||
          (selectedDate.year == now.year &&
              selectedDate.month == now.month &&
              selectedDate.day == now.day &&
              !end.isAfter(now));

      if (slotInPast) {
        slots.add({
          'time': formattedTime,
          'available': false,
          'message': 'Court unavailable, time has already passed',
        });
      } else {
        final reservedCourts = reservedMap[formattedTime] ?? <String>{};
        final remainingCourts = 2 - reservedCourts.length;

        if (remainingCourts == 0) {
          slots.add({
            'time': formattedTime,
            'available': false,
            'message': 'No courts available',
          });
        } else {
          slots.add({
            'time': formattedTime,
            'available': true,
            'courtCount': remainingCourts,
            'courtNames': ['Court 1', 'Court 2']
                .where((c) => !reservedCourts.contains(c))
                .toList(),
          });
        }
      }

      // Advance to the next one-hour block
      start = end;
    }

    return slots;
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour == 0 ? 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute$period';
  }

  void _showReservationConfirmation(String reservedTime, String court, [DateTime? reservationDate]) {
    final selectedDate = reservationDate ?? _generateWeekDates()[_selectedDayIndex]['fullDate'] as DateTime;
    final formattedDate = '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}';
    
    courtReservations[formattedDate] ??= {};
    courtReservations[formattedDate]![reservedTime] ??= [];
    courtReservations[formattedDate]![reservedTime]!.add(court);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Court Reserved',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 18,
            ),
          ),
          content: Text(
            'You have reserved $court for $reservedTime on $formattedDate.',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFFFF6D00),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? const Color(0xFFE61C65) : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFE61C65) : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = _generateWeekDates();
    final timeSlots = _getTimeSlots();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
        title: Image.asset('assets/omni_logo.png', height: 32),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  onPressed: () => _navigateDays(-1),
                ),
                const Text(
                  'Downtown | Standard Courts',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  onPressed: () => _navigateDays(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_slideAnimation.value * 20 - 10, 0),
                  child: Opacity(
                    opacity: 1.0 - _slideAnimation.value * 0.3,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: weekDates.length,
                      itemBuilder: (context, index) {
                        final dateInfo = weekDates[index];
                        final isSelected = _selectedDayIndex == index;
                        final isToday = dateInfo['isToday'];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDayIndex = index;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFF6D00) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isToday && !isSelected ? Border.all(color: const Color(0xFFFF6D00)) : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isToday ? 'Today' : dateInfo['day'],
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : (isToday ? const Color(0xFFFF6D00) : Colors.black54),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateInfo['date'],
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : (isToday ? const Color(0xFFFF6D00) : Colors.black),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFFFF6D00),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                Text(
                  'Book Courts',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: timeSlots.length,
              separatorBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  color: const Color(0xFFFF6D00).withOpacity(0.6),
                  thickness: 1,
                  height: 32,
                ),
              ),
              itemBuilder: (context, index) {
                final slot = timeSlots[index];
                final isAvailable = slot['available'];

                if (!isAvailable) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            slot['time'],
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            slot['message'],
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTimeSlot = slot['time'];
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedTimeSlot == slot['time'] ? Colors.orange.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedTimeSlot == slot['time'] ? const Color(0xFFFF6D00) : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  slot['time'],
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Builder(
                                  builder: (context) {
                                    // Use consistent date formatting
                                    final selectedDate = weekDates[_selectedDayIndex]['fullDate'] as DateTime;
                                    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

                                    final reservedCourts =
                                        _dailyReservedSlots[selectedDateStr]?[slot['time']] ?? <String>{};

                                    final allCourts = ['Court 1', 'Court 2'];
                                    final remainingCourts = allCourts.where((court) => !reservedCourts.contains(court)).toList();
                                    
                                    return Text(
                                      "${remainingCourts.length} court(s) available (${remainingCourts.join(', ')})",
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Radio<String>(
                            value: slot['time'],
                            groupValue: _selectedTimeSlot,
                            onChanged: (value) {
                              setState(() {
                                _selectedTimeSlot = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedTimeSlot == null ? null : () => _onItemTapped(2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6D00),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Checkout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _buildNavItem(Icons.home, 'Home', 0),
                  _buildNavItem(Icons.credit_card, 'Cards', 1),
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.pushNamed(context, '/bookings');
                      if (result == true) {
                          _loadReservations();  // Refresh feed screen if a booking was cancelled
                          }
                    },
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, color: Colors.grey),
                        SizedBox(height: 4),
                        Text(
                          'My Bookings',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildNavItem(Icons.person, 'Me', 3),
                  _buildNavItem(Icons.more_horiz, 'More', 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}