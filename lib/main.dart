import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/send_request_screen.dart';
import 'screens/user_form_screen.dart';
import 'screens/card_screen.dart';
import 'screens/more_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/booking_screen.dart';


void main() {
  // Disable InkSparkle shader compilation
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force the use of InkWell instead of InkSparkle
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User Management',
      theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
        // Disable InkSparkle at theme level
        splashFactory: InkRipple.splashFactory,
      ),
      initialRoute: '/login',
      routes: {
        '/': (context) => const LoginScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const UserFormScreen(),
        '/feed': (context) => const CourtBookingScreen(),
        '/send': (context) => const SendRequestScreen(),
        '/card': (context) => const CardScreen(),
        '/more': (context) => const MoreScreen(),
        '/bookings': (context) => const BookingScreen(),
      },
    );
  }
}
