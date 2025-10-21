import 'package:flutter/material.dart';
// Screen imports for all app screens
import 'screens/login_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/send_request_screen.dart';
import 'screens/user_form_screen.dart';
import 'screens/card_screen.dart';
import 'screens/more_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/reset_password_screen.dart';

/// Main entry point for the User Management Flutter application
/// Initializes the app with routing and theme configuration
void main() {
  // Initialize Flutter binding before running the app
  // This ensures all Flutter services are properly set up
  WidgetsFlutterBinding.ensureInitialized();
  
  // Launch the main application widget
  runApp(const MyApp());
}

/// Root application widget that configures the MaterialApp
/// Sets up routing, theming, and initial screen
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Application title shown in system UI
      title: 'User Management',
      
      // App theme configuration
      theme: ThemeData(
        // Color scheme based on deep orange brand color
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
        
        // Use InkRipple instead of InkSparkle for better performance
        // and to avoid shader compilation issues
        splashFactory: InkRipple.splashFactory,
      ),
      
      // Set login screen as the initial route when app launches
      initialRoute: '/login',
      
      // Define all application routes and their corresponding screens
      routes: {
        '/': (context) => const LoginScreen(),                    // Root route - Login
        '/login': (context) => const LoginScreen(),               // User authentication screen
        '/register': (context) => const UserFormScreen(),         // New user registration form
        '/feed': (context) => const CourtBookingScreen(),          // Main court booking interface
        '/send': (context) => const SendRequestScreen(),          // Send friend/booking requests
        '/card': (context) => const CardScreen(),                 // Payment methods management
        '/more': (context) => const MoreScreen(),                 // Account settings and more options
        '/bookings': (context) => const BookingScreen(),          // View user's booking history
        '/reset': (context) => const ResetPasswordScreen(),       // Password reset functionality
      },
    );
  }
}