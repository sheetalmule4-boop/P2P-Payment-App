import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// ReservationGraphScreen displays a visual overview of the user's bookings
/// with statistics cards and an animated pie chart showing the distribution
/// of past and future reservations
class ReservationGraphScreen extends StatefulWidget {
  final List<Map<String, dynamic>> pastBookings;
  final List<Map<String, dynamic>> futureBookings;

  const ReservationGraphScreen({
    Key? key,
    required this.pastBookings,
    required this.futureBookings,
  }) : super(key: key);

  @override
  State<ReservationGraphScreen> createState() => _ReservationGraphScreenState();
}

class _ReservationGraphScreenState extends State<ReservationGraphScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int touchedIndex = -1; // Tracks which pie chart section is being touched

  @override
  void initState() {
    super.initState();
    // Initialize animation controller for pie chart entrance animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate booking counts for statistics
    final pastCount = widget.pastBookings.length;
    final futureCount = widget.futureBookings.length;
    final total = pastCount + futureCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Overview',
          style: TextStyle(
            color: Color(0xFFFF6D00),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        foregroundColor: Colors.black,
        actions: [
          // Refresh button to restart the chart animation
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF6D00)),
            onPressed: () {
              _animationController.reset();
              _animationController.forward();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Statistics Cards Row - displays total, upcoming, and completed bookings
              _buildStatsCards(pastCount, futureCount, total),
              const SizedBox(height: 32),
              
              // Chart Section - displays animated pie chart with booking distribution
              _buildChartSection(pastCount, futureCount, total),
            ],
          ),
        ),
      ),
      // Floating action button to navigate to new booking creation
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/feed');
        },
        backgroundColor: const Color(0xFFFF6D00),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Booking',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Builds the row of statistics cards showing booking counts
  Widget _buildStatsCards(int pastCount, int futureCount, int total) {
    return Row(
      children: [
        // Total bookings card
        Expanded(
          child: _buildStatCard(
            title: 'Total Bookings',
            value: total.toString(),
            icon: Icons.event_note,
            color: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        // Upcoming bookings card
        Expanded(
          child: _buildStatCard(
            title: 'Upcoming',
            value: futureCount.toString(),
            icon: Icons.schedule,
            color: const Color(0xFFFF6D00),
          ),
        ),
        const SizedBox(width: 12),
        // Completed bookings card
        Expanded(
          child: _buildStatCard(
            title: 'Completed',
            value: pastCount.toString(),
            icon: Icons.check_circle,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// Builds an individual statistics card with icon, value, and title
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon container with colored background
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          // Main value display
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          // Title label
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the main chart section containing the animated pie chart
  Widget _buildChartSection(int pastCount, int futureCount, int total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chart header with title and time period indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Booking Distribution",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'This Year',
                  style: TextStyle(
                    color: Color(0xFFFF6D00),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Animated pie chart
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 50,
                    sectionsSpace: 3,
                    // Handle touch interactions for chart sections
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            touchedIndex = -1;
                            return;
                          }
                          touchedIndex = pieTouchResponse
                              .touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sections: [
                      // Future bookings section (orange)
                      PieChartSectionData(
                        value: (futureCount.toDouble() * _animation.value),
                        color: const Color(0xFFFF6D00),
                        title: total > 0 ? '${((futureCount / total) * 100).toStringAsFixed(1)}%' : '0%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        radius: touchedIndex == 0 ? 70 : 65, // Expand when touched
                        titlePositionPercentageOffset: 0.55,
                      ),
                      // Past bookings section (grey)
                      PieChartSectionData(
                        value: (pastCount.toDouble() * _animation.value),
                        color: Colors.grey.shade400,
                        title: total > 0 ? '${((pastCount / total) * 100).toStringAsFixed(1)}%' : '0%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        radius: touchedIndex == 1 ? 70 : 65, // Expand when touched
                        titlePositionPercentageOffset: 0.55,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Legend showing color meanings and counts
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                color: const Color(0xFFFF6D00),
                label: "Upcoming",
                count: futureCount,
              ),
              const SizedBox(width: 32),
              _buildLegendItem(
                color: Colors.grey.shade400,
                label: "Past",
                count: pastCount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a legend item with colored circle, label, and count
  Widget _buildLegendItem({
    required Color color,
    required String label,
    required int count,
  }) {
    return Row(
      children: [
        // Colored circle indicator
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Label and count text
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$count bookings',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}